import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/gst_certificate_data.dart';

bool _isTestEnvironment() {
  if (kIsWeb) return false;
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

/// A draft of a GST verification review saved locally on the device before submission.
class GstDraft {
  final String companyId;
  final String userId;
  final Map<GstField, String> values;
  final String? imagePath;
  final DateTime savedAt;
  final Set<GstField> editedFields;

  const GstDraft({
    required this.companyId,
    required this.userId,
    required this.values,
    this.imagePath,
    required this.savedAt,
    this.editedFields = const {},
  });

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'userId': userId,
    'values': {for (final e in values.entries) e.key.name: e.value},
    'imagePath': imagePath,
    'savedAt': savedAt.toIso8601String(),
    'editedFields': [for (final f in editedFields) f.name],
  };

  factory GstDraft.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'] as Map? ?? {};
    final values = <GstField, String>{};
    for (final f in GstField.values) {
      if (rawValues.containsKey(f.name)) {
        values[f] = rawValues[f.name]?.toString() ?? '';
      }
    }
    final rawEdited = json['editedFields'] as List? ?? [];
    final editedFields = <GstField>{};
    for (final e in rawEdited) {
      final match = GstField.values.where((f) => f.name == e.toString()).firstOrNull;
      if (match != null) editedFields.add(match);
    }

    return GstDraft(
      companyId: json['companyId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      values: values,
      imagePath: json['imagePath'] as String?,
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      editedFields: editedFields,
    );
  }
}

/// Abstract storage contract for persisting GST drafts.
abstract class GstDraftStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// In-memory storage for unit tests or transient fallback.
class InMemoryGstDraftStorage implements GstDraftStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// Secure persistent storage using [FlutterSecureStorage].
class SecureGstDraftStorage implements GstDraftStorage {
  final FlutterSecureStorage _storage;

  SecureGstDraftStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureGstDraftStorage read error: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureGstDraftStorage write error: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureGstDraftStorage delete error: $e');
    }
  }
}

/// Repository for managing local GST verification drafts.
/// Keyed per company and user so one account cannot see another account's draft.
class GstDraftRepository {
  final GstDraftStorage _storage;

  GstDraftRepository({GstDraftStorage? storage})
      : _storage = storage ??
            (_isTestEnvironment()
                ? InMemoryGstDraftStorage()
                : SecureGstDraftStorage());

  static String _key(String companyId, String userId) =>
      'gst_draft_${companyId}_$userId';

  Future<void> saveDraft(GstDraft draft) async {
    final key = _key(draft.companyId, draft.userId);
    final raw = jsonEncode(draft.toJson());
    await _storage.write(key, raw);
  }

  Future<GstDraft?> getDraft({
    required String companyId,
    required String userId,
  }) async {
    if (companyId.isEmpty || userId.isEmpty) return null;
    final key = _key(companyId, userId);
    final raw = await _storage.read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return GstDraft.fromJson(json);
    } catch (e) {
      debugPrint('Failed to parse GST draft JSON: $e');
      return null;
    }
  }

  Future<void> clearDraft({
    required String companyId,
    required String userId,
  }) async {
    if (companyId.isEmpty || userId.isEmpty) return;
    final key = _key(companyId, userId);
    await _storage.delete(key);
  }

  Future<bool> hasDraft({
    required String companyId,
    required String userId,
  }) async {
    final draft = await getDraft(companyId: companyId, userId: userId);
    return draft != null;
  }
}

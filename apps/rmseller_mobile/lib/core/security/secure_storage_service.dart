import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service wrapping encrypted local keychain/keystore.
/// Safely persists authentication tokens, user identity, and organization data.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  // In-memory fallback for testing or non-mobile platforms
  final Map<String, String> _memoryStorage = {};
  bool _useMemoryFallback = false;

  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserFullName = 'user_full_name';
  static const String _keyCompanyId = 'company_id';
  static const String _keyCompanyName = 'company_name';
  static const String _keyCompanyGst = 'company_gst';

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Enable in-memory mode for unit testing
  void enableMemoryFallbackForTesting() {
    _useMemoryFallback = true;
  }

  Future<void> saveToken(String token) async {
    if (_useMemoryFallback) {
      _memoryStorage[_keyToken] = token;
      return;
    }
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    if (_useMemoryFallback) return _memoryStorage[_keyToken];
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRefreshToken(String token) async {
    if (_useMemoryFallback) {
      _memoryStorage[_keyRefreshToken] = token;
      return;
    }
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    if (_useMemoryFallback) return _memoryStorage[_keyRefreshToken];
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String email,
    required String fullName,
    String? companyId,
    String? companyName,
    String? companyGst,
  }) async {
    if (_useMemoryFallback) {
      _memoryStorage[_keyUserId] = id;
      _memoryStorage[_keyUserRole] = role;
      _memoryStorage[_keyUserEmail] = email;
      _memoryStorage[_keyUserFullName] = fullName;
      if (companyId != null) _memoryStorage[_keyCompanyId] = companyId;
      if (companyName != null) _memoryStorage[_keyCompanyName] = companyName;
      if (companyGst != null) _memoryStorage[_keyCompanyGst] = companyGst;
      return;
    }

    await Future.wait([
      _storage.write(key: _keyUserId, value: id),
      _storage.write(key: _keyUserRole, value: role),
      _storage.write(key: _keyUserEmail, value: email),
      _storage.write(key: _keyUserFullName, value: fullName),
      if (companyId != null) _storage.write(key: _keyCompanyId, value: companyId),
      if (companyName != null) _storage.write(key: _keyCompanyName, value: companyName),
      if (companyGst != null) _storage.write(key: _keyCompanyGst, value: companyGst),
    ]);
  }

  Future<String?> getUserId() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserId];
    return await _storage.read(key: _keyUserId);
  }

  Future<String?> getUserRole() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserRole];
    return await _storage.read(key: _keyUserRole);
  }

  Future<String?> getUserEmail() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserEmail];
    return await _storage.read(key: _keyUserEmail);
  }

  Future<String?> getUserFullName() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserFullName];
    return await _storage.read(key: _keyUserFullName);
  }

  Future<String?> getCompanyId() async {
    if (_useMemoryFallback) return _memoryStorage[_keyCompanyId];
    return await _storage.read(key: _keyCompanyId);
  }

  Future<String?> getCompanyName() async {
    if (_useMemoryFallback) return _memoryStorage[_keyCompanyName];
    return await _storage.read(key: _keyCompanyName);
  }

  Future<String?> getCompanyGst() async {
    if (_useMemoryFallback) return _memoryStorage[_keyCompanyGst];
    return await _storage.read(key: _keyCompanyGst);
  }

  Future<void> clearAll() async {
    if (_useMemoryFallback) {
      _memoryStorage.clear();
      return;
    }
    await _storage.deleteAll();
  }
}

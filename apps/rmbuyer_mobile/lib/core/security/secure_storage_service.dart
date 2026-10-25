import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service using encrypted OS keychain / keystore.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const String _keyToken = 'rmbuyer_access_token';
  static const String _keyRefreshToken = 'rmbuyer_refresh_token';
  static const String _keyUserId = 'rmbuyer_user_id';
  static const String _keyUserRole = 'rmbuyer_user_role';
  static const String _keyUserEmail = 'rmbuyer_user_email';
  static const String _keyUserName = 'rmbuyer_user_name';
  static const String _keyCompanyId = 'rmbuyer_company_id';
  static const String _keyCompanyName = 'rmbuyer_company_name';

  Future<void> saveToken(String token) async =>
      _storage.write(key: _keyToken, value: token);

  Future<String?> getToken() async => _storage.read(key: _keyToken);

  Future<void> saveRefreshToken(String token) async =>
      _storage.write(key: _keyRefreshToken, value: token);

  Future<String?> getRefreshToken() async =>
      _storage.read(key: _keyRefreshToken);

  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String email,
    required String fullName,
    String? companyId,
    String? companyName,
  }) async {
    await _storage.write(key: _keyUserId, value: id);
    await _storage.write(key: _keyUserRole, value: role);
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserName, value: fullName);
    if (companyId != null) {
      await _storage.write(key: _keyCompanyId, value: companyId);
    }
    if (companyName != null) {
      await _storage.write(key: _keyCompanyName, value: companyName);
    }
  }

  Future<void> saveUserName(String fullName) async =>
      _storage.write(key: _keyUserName, value: fullName);

  Future<String?> getUserId() async => _storage.read(key: _keyUserId);
  Future<String?> getUserRole() async => _storage.read(key: _keyUserRole);
  Future<String?> getUserEmail() async => _storage.read(key: _keyUserEmail);
  Future<String?> getUserName() async => _storage.read(key: _keyUserName);
  Future<String?> getCompanyId() async => _storage.read(key: _keyCompanyId);
  Future<String?> getCompanyName() async => _storage.read(key: _keyCompanyName);

  // In-memory fallback for testing or non-mobile platforms
  static final Map<String, String> _memoryStorage = {};
  static bool _useMemoryFallback = false;

  void enableMemoryFallbackForTesting() {
    _useMemoryFallback = true;
  }

  Future<void> savePreference(String key, String value) async {
    if (_useMemoryFallback) {
      _memoryStorage[key] = value;
      return;
    }
    await _storage.write(key: key, value: value);
  }

  Future<String?> getPreference(String key) async {
    if (_useMemoryFallback) return _memoryStorage[key];
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    if (_useMemoryFallback) {
      _memoryStorage.clear();
      return;
    }
    await _storage.deleteAll();
  }
}

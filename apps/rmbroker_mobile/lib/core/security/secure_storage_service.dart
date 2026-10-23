import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token & session persistence service using Android Keystore / iOS Keychain.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const String _keyToken = 'rmbroker_access_token';
  static const String _keyRefreshToken = 'rmbroker_refresh_token';
  static const String _keyUserRole = 'rmbroker_user_role';
  static const String _keyUserId = 'rmbroker_user_id';
  static const String _keyUserEmail = 'rmbroker_user_email';
  static const String _keyUserName = 'rmbroker_user_name';

  Future<void> saveToken(String token) async {
    if (_useMemoryFallback) {
      _memoryStorage[_keyToken] = token;
      return;
    }
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    if (_useMemoryFallback) return _memoryStorage[_keyToken];
    return await _storage.read(key: _keyToken);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    if (_useMemoryFallback) {
      _memoryStorage[_keyRefreshToken] = refreshToken;
      return;
    }
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getRefreshToken() async {
    if (_useMemoryFallback) return _memoryStorage[_keyRefreshToken];
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveUserInfo({
    required String id,
    required String role,
    String? email,
    String? fullName,
  }) async {
    if (_useMemoryFallback) {
      _memoryStorage[_keyUserId] = id;
      _memoryStorage[_keyUserRole] = role;
      if (email != null) _memoryStorage[_keyUserEmail] = email;
      if (fullName != null) _memoryStorage[_keyUserName] = fullName;
      return;
    }
    await _storage.write(key: _keyUserId, value: id);
    await _storage.write(key: _keyUserRole, value: role);
    if (email != null) {
      await _storage.write(key: _keyUserEmail, value: email);
    }
    if (fullName != null) {
      await _storage.write(key: _keyUserName, value: fullName);
    }
  }

  Future<String?> getUserRole() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserRole];
    return await _storage.read(key: _keyUserRole);
  }

  Future<String?> getUserId() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserId];
    return await _storage.read(key: _keyUserId);
  }

  Future<String?> getUserEmail() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserEmail];
    return await _storage.read(key: _keyUserEmail);
  }

  Future<String?> getUserName() async {
    if (_useMemoryFallback) return _memoryStorage[_keyUserName];
    return await _storage.read(key: _keyUserName);
  }

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

  Future<String?> read({required String key}) async {
    if (_useMemoryFallback) return _memoryStorage[key];
    return await _storage.read(key: key);
  }

  Future<void> write({required String key, required String value}) async {
    if (_useMemoryFallback) {
      _memoryStorage[key] = value;
      return;
    }
    await _storage.write(key: key, value: value);
  }

  Future<void> delete({required String key}) async {
    if (_useMemoryFallback) {
      _memoryStorage.remove(key);
      return;
    }
    await _storage.delete(key: key);
  }

  Future<void> clearAll() async {
    if (_useMemoryFallback) {
      _memoryStorage.clear();
      return;
    }
    await _storage.deleteAll();
  }
}

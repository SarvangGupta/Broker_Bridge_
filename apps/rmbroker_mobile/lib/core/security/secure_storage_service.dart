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
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveUserInfo({
    required String id,
    required String role,
    String? email,
    String? fullName,
  }) async {
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
    return await _storage.read(key: _keyUserRole);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: _keyUserName);
  }

  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

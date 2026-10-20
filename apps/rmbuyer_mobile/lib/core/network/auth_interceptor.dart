import 'package:dio/dio.dart';
import '../security/secure_storage_service.dart';

/// Injects Bearer token into outgoing HTTP requests and handles auth challenges.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  AuthInterceptor({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      options.headers['X-Client-App'] = 'RMBuyer-Mobile';
      options.headers['Accept'] = 'application/json';
    } catch (_) {
      // Continue request even if secure storage access fails
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid session
    }
    handler.next(err);
  }
}

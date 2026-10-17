import 'package:dio/dio.dart';

import '../errors/app_exceptions.dart';
import '../security/secure_storage_service.dart';

/// Interceptor that attaches Bearer tokens and translates Dio errors into typed AppExceptions.
class AuthInterceptor extends Interceptor {
  final SecureStorageService storage;
  final void Function()? onSessionExpired;

  AuthInterceptor({required this.storage, this.onSessionExpired});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppException exception;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        exception = NetworkException(
          message:
              'Network connection failed: ${err.message ?? "Server unreachable"}',
        );
        break;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final responseData = err.response?.data;
        String errorMessage = 'Unexpected server response ($statusCode)';

        if (responseData is Map && responseData['error'] != null) {
          errorMessage = responseData['error'].toString();
        } else if (responseData is String && responseData.isNotEmpty) {
          errorMessage = responseData;
        }

        if (statusCode == 401) {
          storage.clearAll();
          onSessionExpired?.call();
          exception = UnauthorizedException(message: errorMessage);
        } else if (statusCode == 403) {
          exception = ForbiddenException(message: errorMessage);
        } else if (statusCode == 404) {
          exception = NotFoundException(message: errorMessage);
        } else if (statusCode == 400 || statusCode == 422) {
          exception = ValidationException(
            message: errorMessage,
            details: responseData,
          );
        } else {
          exception = ServerException(
            message: errorMessage,
            code: 'HTTP_$statusCode',
          );
        }
        break;

      case DioExceptionType.cancel:
        exception = const NetworkException(message: 'Request was cancelled');
        break;

      default:
        exception = NetworkException(
          message: err.message ?? 'Unknown network failure',
        );
        break;
    }

    return handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
      ),
    );
  }
}

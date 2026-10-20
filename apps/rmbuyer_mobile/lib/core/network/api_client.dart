import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'auth_interceptor.dart';

/// Centralized Dio API Client for RMBuyer REST API interactions.
class ApiClient {
  late final Dio _dio;

  ApiClient({Dio? customDio}) {
    _dio = customDio ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _dio.interceptors.add(AuthInterceptor());
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final message = error.response?.data is Map
            ? (error.response?.data['error'] ?? error.response?.data['message'] ?? 'Request failed')
            : 'Request failed with status $status';
        if (status == 401 || status == 403) {
          return AccessDeniedException(message: message.toString());
        }
        return ServerException(message: message.toString(), code: status?.toString());
      default:
        return ServerException(message: error.message ?? 'An unexpected error occurred');
    }
  }
}

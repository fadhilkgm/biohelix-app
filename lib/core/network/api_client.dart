import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({required AppConfig config, Logger? logger})
    : _logger = logger ?? Logger(),
      _config = config,
      _dio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.i('REQ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.i(
            'RES ${response.statusCode} ${response.requestOptions.uri}',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e(
            'ERR ${error.response?.statusCode} ${error.requestOptions.uri}',
            error: error.message,
          );
          handler.next(error);
        },
      ),
    );
  }

  final AppConfig _config;
  final Dio _dio;
  final Logger _logger;

  String get baseUrl => _config.apiBaseUrl;

  void updateAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
      return;
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data?.toString() ?? error.message ?? 'Request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data?.toString() ?? error.message ?? 'Request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? data}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data?.toString() ?? error.message ?? 'Request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> deleteJson(String path, {Object? data}) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(path, data: data);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data?.toString() ?? error.message ?? 'Request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data?.toString() ?? error.message ?? 'Request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _config.healthEndpoint,
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data?.toString() ?? error.message ?? 'Request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }
}

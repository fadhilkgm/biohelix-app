import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required AppConfig config,
    Logger? logger,
    HttpClientAdapter? httpClientAdapter,
  })
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
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.i('REQ ${options.method} ${options.uri}');
          if (options.queryParameters.isNotEmpty) {
            _logger.i('REQ QUERY ${_stringify(options.queryParameters)}');
          }
          if (options.data != null) {
            _logger.i('REQ BODY ${_stringify(options.data)}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.i(
            'RES ${response.statusCode} ${response.requestOptions.uri}',
          );
          if (response.data != null) {
            _logger.i('RES BODY ${_stringify(response.data)}');
          }
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e(
            'ERR ${error.response?.statusCode} ${error.requestOptions.uri}',
            error: error.message,
          );
          if (error.requestOptions.data != null) {
            _logger.e('ERR REQ BODY ${_stringify(error.requestOptions.data)}');
          }
          if (error.response?.data != null) {
            _logger.e('ERR RES BODY ${_stringify(error.response?.data)}');
          }
          handler.next(error);
        },
      ),
    );
  }

  final AppConfig _config;
  final Dio _dio;
  final Logger _logger;
  static const int _maxLogLength = 1200;

  static String _stringify(Object? data) {
    final raw = data?.toString() ?? 'null';
    if (raw.length <= _maxLogLength) return raw;
    return '${raw.substring(0, _maxLogLength)}... [truncated ${raw.length - _maxLogLength} chars]';
  }

  static String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      return data['error']?.toString() ??
          data['message']?.toString() ??
          error.message ??
          'Request failed';
    }
    return data?.toString() ?? error.message ?? 'Request failed';
  }

  String get baseUrl => _config.apiBaseUrl;

  void updateAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
      return;
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  String authenticatedMediaUrl(String url) {
    // Private R2 media URLs are signed by the API before reaching the app.
    return url;
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
        _errorMessage(error),
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
        _errorMessage(error),
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
        _errorMessage(error),
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
        _errorMessage(error),
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
        _errorMessage(error),
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
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }
}

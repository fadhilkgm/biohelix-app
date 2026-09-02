import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required AppConfig config,
    Logger? logger,
    HttpClientAdapter? httpClientAdapter,
    VoidCallback? onUnauthorized,
  }) : _logger = logger ?? Logger(),
       _config = config,
       _onUnauthorized = onUnauthorized,
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
          // Release builds must not leak request URLs/bodies (chat content) to
          // device logs.
          if (kDebugMode) {
            _logger.i('REQ ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            _logger.i(
              'RES ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;
          if (kDebugMode) {
            final summary =
                'ERR $status ${error.requestOptions.uri}: ${_errorMessage(error)}';
            if (status == 503) {
              _logger.w(summary);
            } else {
              _logger.e(summary);
            }
          }
          if (error.response?.statusCode == 401) {
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final AppConfig _config;
  final Dio _dio;
  final Logger _logger;
  VoidCallback? _onUnauthorized;

  void setOnUnauthorized(VoidCallback? callback) {
    _onUnauthorized = callback;
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

  Future<String> postSdp(String path, {required String sdp}) async {
    try {
      final response = await _dio.post<String>(
        path,
        data: sdp,
        options: Options(
          contentType: 'application/sdp',
          responseType: ResponseType.plain,
          headers: const {'Accept': 'application/sdp'},
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return response.data ?? '';
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
    Duration? receiveTimeout,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: receiveTimeout == null && headers == null
            ? null
            : Options(receiveTimeout: receiveTimeout, headers: headers),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(
        _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// POSTs [data] and yields the JSON payload of every `data:` line of a
  /// `text/event-stream` response.
  ///
  /// Blank lines, comment lines (`:` prefixed) and non-`data:` fields are
  /// ignored. Chunk boundaries that split a line are handled by the line
  /// splitter, so a payload is only emitted once its line is complete.
  /// Non-2xx responses surface as [ApiException] before the first payload,
  /// which lets callers fall back to a non-streaming endpoint.
  Stream<String> postEventStream(
    String path, {
    Object? data,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) async* {
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 120),
        ),
      );
    } on DioException catch (error) {
      throw ApiException(
        _streamErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }

    final body = response.data;
    if (body == null) {
      throw ApiException(
        'The assistant stream returned no data.',
        statusCode: response.statusCode,
      );
    }

    final lines = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        if (line.isEmpty || line.startsWith(':')) continue;
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        yield payload;
      }
    } on DioException catch (error) {
      throw ApiException(
        _streamErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  static String _streamErrorMessage(DioException error) {
    // Stream responses carry a ResponseBody, not a decoded map, so the generic
    // extractor would stringify a handle instead of a message.
    if (error.response?.data is ResponseBody) {
      return error.message ?? 'Request failed';
    }
    return _errorMessage(error);
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
      final response = await _dio.delete<Map<String, dynamic>>(
        path,
        data: data,
      );
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
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      );
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

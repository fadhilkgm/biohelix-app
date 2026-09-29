import 'package:dio/dio.dart';

/// Browsers manage connection reuse themselves.
HttpClientAdapter? createKeepAliveHttpClientAdapter() => null;

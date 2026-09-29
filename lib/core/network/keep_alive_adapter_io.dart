import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// dart:io drops idle sockets after 15s by default, so a live-voice turn that
/// follows a long spoken answer paid a fresh TCP + TLS handshake before its
/// context lookup. Keeping the socket for a minute makes those lookups (and
/// the reward heartbeats) reuse one warm connection.
HttpClientAdapter? createKeepAliveHttpClientAdapter() {
  return IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()..idleTimeout = const Duration(seconds: 60),
  );
}

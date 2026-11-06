import 'dart:convert';
import 'dart:io';

import 'package:biohelix_app/patient_portal/ai_checkup/services/ai_checkup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late int status;
  late String contentType;
  late String body;
  late AiCheckupService service;

  setUp(() async {
    status = 200;
    contentType = 'application/json';
    body = '';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    service = AiCheckupService(
      apiBaseUrl: 'http://${server.address.address}:${server.port}/api/v1',
      authToken: '',
    );
    server.listen((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = status
        ..headers.set(HttpHeaders.contentTypeHeader, contentType)
        ..write(body);
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Future<Object> startFailure() async {
    try {
      await service.startVoiceAssessment();
    } catch (error) {
      return error;
    }
    fail('Expected startVoiceAssessment to throw.');
  }

  test('an empty Cloudflare 525 is reported as unavailable', () async {
    status = 525;

    final error = await startFailure();

    expect(
      error,
      isA<AiCheckupUnavailableException>().having(
        (e) => e.statusCode,
        'statusCode',
        525,
      ),
    );
  });

  test('an HTML proxy error page is reported as unavailable', () async {
    status = 502;
    contentType = 'text/html';
    body = '<html><body>Bad gateway</body></html>';

    expect(await startFailure(), isA<AiCheckupUnavailableException>());
  });

  test('a JSON 5xx message is not shown to patients', () async {
    status = 500;
    body = jsonEncode({'message': 'SQLSTATE[HY000] connection refused'});

    expect(await startFailure(), isA<AiCheckupUnavailableException>());
  });

  test('a JSON 4xx message is passed through', () async {
    status = 422;
    body = jsonEncode({'message': 'This session has expired.'});

    expect(
      (await startFailure()).toString(),
      'Exception: This session has expired.',
    );
  });

  test('a 4xx HTML page is reported as unavailable', () async {
    status = 404;
    contentType = 'text/html';
    body = '<html><body>Not found</body></html>';

    expect(await startFailure(), isA<AiCheckupUnavailableException>());
  });

  test('a refused connection is reported as unavailable', () async {
    await server.close(force: true);

    expect(await startFailure(), isA<AiCheckupUnavailableException>());
  });
}

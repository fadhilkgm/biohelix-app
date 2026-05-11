import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sendChatMessage includes analyzed PDF summary context in the backend payload',
    () async {
      final repository = _FakePatientRepository();
      final provider = PatientPortalProvider(
        repository: repository,
        sessionProvider: SessionProvider(),
      );

      provider.documentAnalyses[42] = const DocumentAnalysisResult(
        summary:
            'HbA1c is elevated and fasting glucose is above the reference range.',
      );

      await provider.sendChatMessage(
        'What should I do next?',
        attachments: const [
          ChatAttachment(
            name: 'lab-report.pdf',
            url: 'https://signed.example/report.pdf',
            mimeType: 'application/pdf',
            documentId: 42,
          ),
        ],
      );

      expect(repository.lastSentMessage, contains('What should I do next?'));
      expect(repository.lastSentMessage, contains('lab-report.pdf'));
      expect(
        repository.lastSentMessage,
        contains(
          'HbA1c is elevated and fasting glucose is above the reference range.',
        ),
      );
    },
  );
}

class _FakePatientRepository extends PatientRepository {
  _FakePatientRepository() : super(apiClient: throw UnimplementedError());

  String? lastSentMessage;

  @override
  Future<ChatThreadSummary> createGlobalChatThread({String? title}) async {
    return const ChatThreadSummary(id: 'thread-1', title: 'New chat');
  }

  @override
  Future<ChatMessage> sendGlobalChatMessage({
    required String threadId,
    required String message,
    String? language,
    String? mode,
  }) async {
    lastSentMessage = message;
    return const ChatMessage(role: 'ai', content: 'ok');
  }
}

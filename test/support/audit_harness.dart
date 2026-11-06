import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:biohelix_app/patient_portal/fitness/models/fitness_activity_models.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

final auditConfig = AppConfig(
  appName: 'BHRC Test',
  apiBaseUrl: 'https://example.test/api',
  healthEndpoint: '/health',
  showDevOtp: true,
);

const auditPatient = PatientIdentity(
  id: 1,
  name: 'Audit Patient',
  phone: '+919998887777',
  registrationNumber: 'BHRC-1',
  uuid: 'patient-1',
  legalConsentAcceptedAt: '2026-10-02T00:00:00Z',
);

const auditLabTest = LabTestItem(
  id: 11,
  testName: 'CBC',
  categoryId: 1,
  categoryName: 'Hematology',
  status: true,
  basePrice: 250,
);

PatientIdentity auditPatientFor(int id, {String? name}) =>
    PatientIdentity.fromJson({
      ...auditPatient.toJson(),
      'id': id,
      'name': name ?? 'Patient $id',
    });

class AuditAdapter implements HttpClientAdapter {
  AuditAdapter({this.respond});

  final Future<ResponseBody> Function(RequestOptions)? respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond != null ? respond!(options) : jsonResponse({});
  }

  static ResponseBody jsonResponse(Object body, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

ApiClient auditClient({
  AuditAdapter? adapter,
  void Function()? onUnauthorized,
}) => ApiClient(
  config: auditConfig,
  httpClientAdapter: adapter ?? AuditAdapter(),
  logger: Logger(level: Level.off),
  onUnauthorized: onUnauthorized,
);

class AuditRepository extends PatientRepository {
  factory AuditRepository({ApiClient? client}) =>
      AuditRepository._(client ?? auditClient());

  AuditRepository._(this.client) : super(apiClient: client);

  final ApiClient client;
  PatientIdentity patient = auditPatient;
  Future<PatientIdentity> Function()? currentPatient;
  Future<void> Function()? logoutRequest;
  Future<List<FamilyMember>> Function()? familyRequest;
  Future<List<ChatThreadSummary>> Function()? threadsRequest;
  Future<ChatThreadSummary> Function()? createThreadRequest;
  Future<PatientIdentity> Function()? profileRequest;
  Future<ChatMessage> Function()? documentReply;
  Future<LabOrderQuote> Function()? quoteRequest;
  Future<FitnessActivitySummary> Function()? fitnessRequest;
  List<DoctorListing> doctorItems = [];
  List<LabTestItem> labTestItems = [];
  List<String> slots = [];
  List<AiSuggestionItem> suggestions = [];
  int logoutCalls = 0;
  int orderCalls = 0;
  int createThreadCalls = 0;
  int fitnessSyncCalls = 0;
  String? otpRequestPhone;

  SessionProvider session() => SessionProvider(
    authStorage: AuthStorage(),
    apiClient: client,
    patientRepository: this,
  );

  @override
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    otpRequestPhone = phone;
    return const OtpSendResult(devOtp: '123456');
  }

  @override
  Future<OtpSendResult> signUp({
    required String phone,
    required String name,
    required String dob,
    required String place,
    String? email,
    String? gender,
    String? referralCode,
  }) async => const OtpSendResult(devOtp: '123456');

  @override
  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async => OtpSession(token: 'token-${patient.id}', patient: patient);

  @override
  Future<PatientIdentity> getCurrentPatient() async =>
      currentPatient != null ? currentPatient!() : patient;

  @override
  Future<void> logout() async {
    logoutCalls++;
    await logoutRequest?.call();
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers() async =>
      familyRequest != null ? familyRequest!() : [];

  @override
  Future<PatientIdentity> updatePatientProfile(PatientIdentity input) async =>
      profileRequest != null ? profileRequest!() : input;

  @override
  Future<List<ChatThreadSummary>> getGlobalChatThreads() async =>
      threadsRequest != null ? threadsRequest!() : [];

  @override
  Future<ChatThreadSummary> createGlobalChatThread({String? title}) async {
    createThreadCalls++;
    return createThreadRequest != null
        ? createThreadRequest!()
        : ChatThreadSummary(
            id: 'thread-${patient.id}',
            title: title ?? 'New chat',
          );
  }

  @override
  Future<List<ChatMessage>> getGlobalChatHistory(String threadId) async => [];

  @override
  Future<ChatMessage> sendDocumentChatMessage({
    required int documentId,
    required String message,
  }) async => documentReply != null
      ? documentReply!()
      : const ChatMessage(role: 'ai', content: 'Reply');

  @override
  Future<List<DoctorListing>> getDoctors() async => doctorItems;

  @override
  Future<List<LabTestItem>> getLabTests() async => labTestItems;

  @override
  Future<PatientDashboard> getDashboard() async =>
      PatientDashboard.fromJson({'patient': patient.toJson()});

  @override
  Future<List<String>> getDoctorAvailableSlots({
    required int doctorId,
    required String date,
  }) async => slots;

  @override
  Future<List<DoctorSlotAvailability>> getDoctorSlotAvailability({
    required int doctorId,
    required String date,
  }) async => slots.map(DoctorSlotAvailability.available).toList();

  @override
  Future<List<AiSuggestionItem>> getAiSuggestions() async => suggestions;

  @override
  Future<AiSuggestionItem> acceptAiSuggestion(int suggestionId) async =>
      AiSuggestionItem(
        id: suggestionId,
        recommendationType: 'test',
        reason: 'Follow up',
        score: 0.8,
        isAccepted: true,
      );

  @override
  Future<LabOrderQuote> quoteLabOrder({
    required List<int> labTestIds,
    required String collectionType,
  }) async => quoteRequest != null
      ? quoteRequest!()
      : const LabOrderQuote(subtotal: 250, collectionFee: 99, amount: 349);

  @override
  Future<BookingConfirmation> createLabOrder({
    int? labTestId,
    List<int>? labTestIds,
    int? doctorId,
    required String date,
    String? slot,
    String collectionType = 'home',
    String? address,
    double? amount,
    String paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? patientPhoneSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
    String? sourceAssessmentToken,
    String? idempotencyKey,
  }) async {
    orderCalls++;
    return const BookingConfirmation(reference: 'LAB-1');
  }

  @override
  Future<FitnessActivitySummary> getFitnessActivity() async =>
      fitnessRequest != null
      ? fitnessRequest!()
      : const FitnessActivitySummary();

  @override
  Future<FitnessActivitySummary> syncFitnessActivity({
    required List<DailyFitnessActivity> days,
    required String timezone,
  }) async {
    fitnessSyncCalls++;
    return FitnessActivitySummary(today: days.firstOrNull);
  }
}

Future<PatientPortalProvider> authenticatedAuditPortal(
  AuditRepository repository,
  SessionProvider session,
) async {
  await session.sendOtp(phone: '9998887777');
  await session.verifyOtp(otp: '123456');
  final portal = PatientPortalProvider(
    repository: repository,
    sessionProvider: session,
  );
  await portal.loadPortal();
  return portal;
}

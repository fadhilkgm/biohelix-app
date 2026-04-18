import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/home_feed_models.dart';
import '../models/patient_models.dart';

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _resolveApiMediaUrl(String raw, String apiBaseUrl) {
  final value = raw.trim();
  if (value.isEmpty) return '';

  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) {
    return value;
  }

  final base = Uri.parse(apiBaseUrl);
  final origin = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
  );

  if (value.startsWith('/')) {
    return origin.resolve(value).toString();
  }

  return base.resolve(value).toString();
}

class OtpSession {
  const OtpSession({required this.token, required this.patient});

  final String token;
  final PatientIdentity patient;
}

class VitalInput {
  const VitalInput({
    this.height,
    this.weight,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.bodyTemperature,
    this.oxygenSaturation,
    this.respiratoryRate,
    this.notes,
  });

  final double? height;
  final double? weight;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;
  final double? bodyTemperature;
  final int? oxygenSaturation;
  final int? respiratoryRate;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'weight': weight,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'heartRate': heartRate,
      'bodyTemperature': bodyTemperature,
      'oxygenSaturation': oxygenSaturation,
      'respiratoryRate': respiratoryRate,
      'notes': notes,
    }..removeWhere((key, value) => value == null);
  }
}

class PatientRepository {
  PatientRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<String?> sendOtp({
    required String phone,
    required String mrn,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/otp/send',
      data: {'phone': phone, 'mrn': mrn},
    );
    return response['dev_otp']?.toString();
  }

  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/otp/verify',
      data: {
        'phone': phone,
        'otp': otp,
      },
    );

    return OtpSession(
      token: response['token'] as String? ?? '',
      patient: PatientIdentity.fromJson(_map(response['patient'])),
    );
  }

  Future<PatientIdentity> getCurrentPatient() async {
    final response = await _apiClient.getJson('/patients/me');
    return PatientIdentity.fromJson(_map(response['patient']));
  }

  Future<PatientIdentity> updatePatientProfile(PatientIdentity patient) async {
    final response = await _apiClient.patchJson(
      '/patients/me',
      data: patient.toProfilePayload(),
    );
    return PatientIdentity.fromJson(_map(response['patient']));
  }

  Future<PatientDashboard> getDashboard() async {
    final response = await _apiClient.getJson('/patients/me/dashboard');
    return PatientDashboard.fromJson(response);
  }

  Future<List<HomeBannerItem>> getHomeBanners() async {
    final response = await _apiClient.getJson('/home-banners');
    final banners = response['banners'] as List<dynamic>? ?? const [];
    return banners
        .map((item) {
          final json = _map(item);
          final rawImage =
              json['imageUrl'] as String? ?? json['image_url'] as String? ?? '';
          json['imageUrl'] = _resolveApiMediaUrl(rawImage, _apiClient.baseUrl);
          return HomeBannerItem.fromJson(json);
        })
        .where((banner) => banner.imageUrl.isNotEmpty)
        .toList();
  }

  Future<List<TickerMessageItem>> getTickerMessages() async {
    final response = await _apiClient.getJson('/home-ticker-messages');
    final messages = response['messages'] as List<dynamic>? ?? const [];
    return messages
        .map((item) => TickerMessageItem.fromJson(_map(item)))
        .toList();
  }

  Future<List<HomeOfferItem>> getHomeOffers() async {
    final response = await _apiClient.getJson('/home-offers');
    final offers = response['offers'] as List<dynamic>? ?? const [];
    return offers
        .map((item) => HomeOfferItem.fromJson(_map(item)))
        .toList();
  }

  Future<List<BookingItem>> getBookings() async {
    final response = await _apiClient.getJson('/patients/bookings');
    final bookings = response['bookings'] as List<dynamic>? ?? const [];
    return bookings.map((item) => BookingItem.fromJson(_map(item))).toList();
  }

  Future<List<PrescriptionRecord>> getPrescriptions() async {
    final response = await _apiClient.getJson('/patients/me/prescriptions');
    final prescriptions =
        response['prescriptions'] as List<dynamic>? ?? const [];
    return prescriptions
        .map((item) => PrescriptionRecord.fromJson(_map(item)))
        .toList();
  }

  Future<List<MedicalRecordItem>> getMedicalRecords() async {
    final response = await _apiClient.getJson('/medical-records/me');
    final records = response['records'] as List<dynamic>? ?? const [];
    return records.map((item) {
      final json = _map(item);
      final rawPath = json['documentPath'] as String? ?? '';
      if (rawPath.trim().isNotEmpty) {
        json['documentPath'] = _resolveApiMediaUrl(rawPath, _apiClient.baseUrl);
      }
      return MedicalRecordItem.fromJson(json);
    }).toList();
  }

  Future<List<DocumentRecord>> getDocuments() async {
    final response = await _apiClient.getJson('/patients/documents');
    final documents = response['documents'] as List<dynamic>? ?? const [];
    return documents.map((item) {
      final json = _map(item);
      final analysis = _map(json['analysis']);
      final summaryFromAnalysis = analysis['summary'] as String?;
      if (summaryFromAnalysis != null &&
          summaryFromAnalysis.trim().isNotEmpty) {
        json['summary'] = summaryFromAnalysis;
        json['hasAnalysis'] = true;
      } else {
        json['hasAnalysis'] = json['hasAnalysis'] as bool? ?? false;
      }

      final rawPath = json['documentPath'] as String? ?? '';
      if (rawPath.trim().isNotEmpty) {
        json['documentPath'] = _resolveApiMediaUrl(rawPath, _apiClient.baseUrl);
      }

      return DocumentRecord.fromJson(json);
    }).toList();
  }

  Future<List<SummaryRecord>> getSummaries() async {
    final response = await _apiClient.getJson('/patients/me/summaries');
    final summaries = response['summaries'] as List<dynamic>? ?? const [];
    return summaries.map((item) => SummaryRecord.fromJson(_map(item))).toList();
  }

  Future<MyClubSummary> getMyClub() async {
    final response = await _apiClient.getJson('/patients/me/myclub');
    return MyClubSummary.fromJson(_map(response['myClub']));
  }

  Future<List<VitalRecord>> getVitalTrend() async {
    final response = await _apiClient.getJson('/patients/me/vitals');
    final trend = response['trend'] as List<dynamic>? ?? const [];
    return trend.map((item) => VitalRecord.fromJson(_map(item))).toList();
  }

  Future<VitalRecord> saveVitals(VitalInput input) async {
    final response = await _apiClient.postJson(
      '/patients/me/vitals',
      data: input.toJson(),
    );
    return VitalRecord.fromJson(_map(response['vitals']));
  }

  Future<List<DoctorListing>> getDoctors() async {
    final response = await _apiClient.getJson('/doctors');
    final doctors = response['doctors'] as List<dynamic>? ?? const [];
    return doctors.map((item) => DoctorListing.fromJson(_map(item))).toList();
  }

  Future<void> createBooking({
    required PatientIdentity patient,
    required int doctorId,
    required String bookingDate,
    required String timeslot,
  }) async {
    await _apiClient.postJson(
      '/bookings',
      data: {
        'name': patient.name,
        'phone': patient.phone,
        'dob': patient.dob,
        'place': patient.address,
        'doctorId': doctorId,
        'bookingDate': bookingDate,
        'timeslot': timeslot,
      },
    );
  }

  Future<void> cancelBooking(int bookingId) async {
    await _apiClient.patchJson('/patients/bookings/$bookingId/cancel');
  }

  Future<void> checkInBooking(int bookingId) async {
    await _apiClient.patchJson('/patients/bookings/$bookingId/check-in');
  }

  Future<void> rescheduleBooking({
    required int bookingId,
    required String bookingDate,
    required String timeslot,
  }) async {
    await _apiClient.patchJson(
      '/patients/bookings/$bookingId/reschedule',
      data: {'bookingDate': bookingDate, 'timeslot': timeslot},
    );
  }

  Future<List<String>> getDoctorAvailableSlots({
    required int doctorId,
    required String date,
  }) async {
    final response = await _apiClient.getJson(
      '/doctors/$doctorId/available-slots?date=$date',
    );
    final slots = response['availableSlots'] as List<dynamic>? ?? const [];
    return slots.map((item) => item.toString()).toList();
  }

  Future<List<ChatThreadSummary>> getGlobalChatThreads() async {
    final response = await _apiClient.getJson('/patients/chat/global/threads');
    final threads = response['threads'] as List<dynamic>? ?? const [];
    return threads
        .map((item) => ChatThreadSummary.fromJson(_map(item)))
        .toList();
  }

  Future<ChatThreadSummary> createGlobalChatThread({String? title}) async {
    final response = await _apiClient.postJson(
      '/patients/chat/global/threads',
      data: {if ((title ?? '').trim().isNotEmpty) 'title': title!.trim()},
    );
    final thread = response['thread'];
    return ChatThreadSummary.fromJson(_map(thread));
  }

  Future<List<ChatMessage>> getGlobalChatHistory(String threadId) async {
    final response = await _apiClient.getJson(
      '/patients/chat/global/threads/$threadId',
    );
    final history = response['history'] as List<dynamic>? ?? const [];
    return history.map((item) => ChatMessage.fromJson(_map(item))).toList();
  }

  Future<List<LabTestItem>> getLabTests() async {
    final response = await _apiClient.getJson('/patient/lab-tests');
    final tests = response['tests'] as List<dynamic>? ?? const [];
    return tests.map((item) {
      final json = _map(item);
      final rawImage =
          json['imageUrl'] as String? ?? json['image_url'] as String? ?? '';
      if (rawImage.trim().isNotEmpty) {
        json['imageUrl'] = _resolveApiMediaUrl(rawImage, _apiClient.baseUrl);
      }
      return LabTestItem.fromJson(json);
    }).toList();
  }

  Future<List<LabOrderItem>> getLabOrders() async {
    final response = await _apiClient.getJson('/patient/lab-orders');
    final orders = response['orders'] as List<dynamic>? ?? const [];
    return orders.map((item) => LabOrderItem.fromJson(_map(item))).toList();
  }

  Future<List<LabPackageItem>> getLabPackages() async {
    final response = await _apiClient.getJson('/patient/lab-packages');
    final packages = response['packages'] as List<dynamic>? ?? const [];
    return packages.map((item) {
      final json = _map(item);
      final rawImage =
          json['imageUrl'] as String? ?? json['image_url'] as String? ?? '';
      if (rawImage.trim().isNotEmpty) {
        json['imageUrl'] = _resolveApiMediaUrl(rawImage, _apiClient.baseUrl);
      }
      return LabPackageItem.fromJson(json);
    }).toList();
  }

  Future<List<LabPackageOrderItem>> getLabPackageOrders() async {
    final response = await _apiClient.getJson('/patient/lab-package-orders');
    final orders = response['orders'] as List<dynamic>? ?? const [];
    return orders
        .map((item) => LabPackageOrderItem.fromJson(_map(item)))
        .toList();
  }

  Future<void> createLabOrder({
    required int labTestId,
    required int doctorId,
    required String date,
    String? slot,
    String collectionType = 'home',
    String? address,
    double? amount,
    String paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
  }) async {
    final trimmedSlot = slot?.trim();
    final trimmedAddress = address?.trim();
    final trimmedPatientName = patientNameSnapshot?.trim();
    final trimmedPatientGender = patientGenderSnapshot?.trim();
    final trimmedBookingRef = bookingRef?.trim();
    final trimmedNotes = notes?.trim();

    await _apiClient.postJson(
      '/patient/lab-orders',
      data: {
        'labTestId': labTestId,
        'doctorId': doctorId,
        'date': date,
        if ((trimmedSlot ?? '').isNotEmpty) 'slot': trimmedSlot,
        'collectionType': collectionType,
        if ((trimmedAddress ?? '').isNotEmpty) 'address': trimmedAddress,
        if (amount != null) 'amount': amount.round(),
        'paymentStatus': paymentStatus,
        if ((trimmedPatientName ?? '').isNotEmpty)
          'patientNameSnapshot': trimmedPatientName,
        ...?patientAgeSnapshot == null
            ? null
            : {'patientAgeSnapshot': patientAgeSnapshot},
        if ((trimmedPatientGender ?? '').isNotEmpty)
          'patientGenderSnapshot': trimmedPatientGender,
        if ((trimmedBookingRef ?? '').isNotEmpty)
          'bookingRef': trimmedBookingRef,
        'urgency': urgency,
        if ((trimmedNotes ?? '').isNotEmpty) 'notes': trimmedNotes,
      },
    );
  }

  Future<void> cancelLabOrder(int orderId) async {
    await _apiClient.patchJson(
      '/patient/lab-orders/$orderId',
      data: {'status': 'cancelled'},
    );
  }

  Future<void> createLabPackageOrder({
    required int labPackageId,
    required int doctorId,
    required String date,
    String? slot,
    String collectionType = 'home',
    String? address,
    double? amount,
    String paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
  }) async {
    final trimmedSlot = slot?.trim();
    final trimmedAddress = address?.trim();
    final trimmedPatientName = patientNameSnapshot?.trim();
    final trimmedPatientGender = patientGenderSnapshot?.trim();
    final trimmedBookingRef = bookingRef?.trim();
    final trimmedNotes = notes?.trim();

    await _apiClient.postJson(
      '/patient/lab-package-orders',
      data: {
        'labPackageId': labPackageId,
        'doctorId': doctorId,
        'date': date,
        if ((trimmedSlot ?? '').isNotEmpty) 'slot': trimmedSlot,
        'collectionType': collectionType,
        if ((trimmedAddress ?? '').isNotEmpty) 'address': trimmedAddress,
        if (amount != null) 'amount': amount.round(),
        'paymentStatus': paymentStatus,
        if ((trimmedPatientName ?? '').isNotEmpty)
          'patientNameSnapshot': trimmedPatientName,
        ...?patientAgeSnapshot == null
            ? null
            : {'patientAgeSnapshot': patientAgeSnapshot},
        if ((trimmedPatientGender ?? '').isNotEmpty)
          'patientGenderSnapshot': trimmedPatientGender,
        if ((trimmedBookingRef ?? '').isNotEmpty)
          'bookingRef': trimmedBookingRef,
        'urgency': urgency,
        if ((trimmedNotes ?? '').isNotEmpty) 'notes': trimmedNotes,
      },
    );
  }

  Future<void> cancelLabPackageOrder(int orderId) async {
    await _apiClient.patchJson(
      '/patient/lab-package-orders/$orderId',
      data: {'status': 'cancelled'},
    );
  }

  Future<DocumentRecord> uploadDocument(String filePath) async {
    final normalized = filePath.trim();
    final fileName = normalized.split(RegExp(r'[\\/]')).last;

    final response = await _apiClient.postMultipart(
      '/patients/documents',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          File(normalized).path,
          filename: fileName,
        ),
      }),
    );

    final json = _map(response['document']);
    final rawPath = json['documentPath'] as String? ?? '';
    if (rawPath.trim().isNotEmpty) {
      json['documentPath'] = _resolveApiMediaUrl(rawPath, _apiClient.baseUrl);
    }
    return DocumentRecord.fromJson(json);
  }

  Future<DocumentAnalysisResult> analyzeDocument(int documentId) async {
    final response = await _apiClient.postJson(
      '/patients/documents/$documentId/analyze',
    );
    return DocumentAnalysisResult.fromJson(response);
  }

  Future<void> deleteDocument(int documentId) async {
    await _apiClient.deleteJson('/patients/documents/$documentId');
  }

  Future<List<ChatMessage>> getDocumentChatHistory(int documentId) async {
    final response = await _apiClient.getJson(
      '/patients/documents/$documentId/chat',
    );
    final history = response['history'] as List<dynamic>? ?? const [];
    return history.map((item) => ChatMessage.fromJson(_map(item))).toList();
  }

  Future<ChatMessage> sendDocumentChatMessage({
    required int documentId,
    required String message,
  }) async {
    final response = await _apiClient.postJson(
      '/patients/documents/$documentId/chat',
      data: {'message': message},
    );
    return ChatMessage(
      role: 'ai',
      content: response['reply'] as String? ?? 'No response',
    );
  }

  Future<ChatMessage> sendGlobalChatMessage({
    required String threadId,
    required String message,
  }) async {
    final response = await _apiClient.postJson(
      '/patients/chat/global/threads/$threadId/messages',
      data: {'message': message},
    );
    return ChatMessage(
      role: 'ai',
      content: response['reply'] as String? ?? 'No response',
    );
  }

  Future<ChatThreadSummary> renameGlobalChatThread({
    required String threadId,
    required String title,
  }) async {
    final response = await _apiClient.patchJson(
      '/patients/chat/global/threads/$threadId',
      data: {'title': title},
    );
    return ChatThreadSummary.fromJson(_map(response['thread']));
  }

  Future<void> deleteGlobalChatThread(String threadId) async {
    await _apiClient.deleteJson('/patients/chat/global/threads/$threadId');
  }
}

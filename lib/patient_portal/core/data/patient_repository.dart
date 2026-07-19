import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/phone_utils.dart';
import '../models/home_feed_models.dart';
import '../models/patient_models.dart';

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _voiceUploadContentType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
  if (lower.endsWith('.webm')) return 'audio/webm';
  if (lower.endsWith('.3gp') || lower.endsWith('.3gpp')) return 'audio/3gpp';
  // AAC-LC from the device recorder is stored as .m4a / .mp4.
  return 'audio/mp4';
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

String _resolveDocumentMediaUrl(
  String raw,
  String apiBaseUrl,
  ApiClient apiClient,
) {
  String resolveOne(String value) {
    final resolved = _resolveApiMediaUrl(value, apiBaseUrl);
    return apiClient.authenticatedMediaUrl(resolved);
  }

  final trimmed = raw.trim();
  if (trimmed.startsWith('[')) {
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is List) {
        return jsonEncode(
          parsed
              .whereType<String>()
              .map(resolveOne)
              .where((value) => value.isNotEmpty)
              .toList(),
        );
      }
    } catch (_) {
      // Fall through to resolving the raw value.
    }
  }

  return resolveOne(raw);
}

class OtpSession {
  const OtpSession({required this.token, required this.patient});

  final String token;
  final PatientIdentity patient;
}

class OtpSendResult {
  const OtpSendResult({this.devOtp, this.message = 'OTP sent successfully'});

  final String? devOtp;
  final String message;

  factory OtpSendResult.fromJson(Map<String, dynamic> json) {
    return OtpSendResult(
      devOtp: json['dev_otp']?.toString(),
      message:
          json['message'] as String? ??
          (json['success'] == true
              ? 'OTP sent to your WhatsApp'
              : 'OTP sent successfully'),
    );
  }
}

class PatientAuthSession {
  const PatientAuthSession({required this.token, required this.patient});

  final String token;
  final PatientIdentity patient;
}

class BookingConfirmation {
  const BookingConfirmation({
    required this.reference,
    this.id,
    this.batchId,
    this.raw = const <String, dynamic>{},
  });

  final String reference;
  final int? id;
  final String? batchId;
  final Map<String, dynamic> raw;

  factory BookingConfirmation.fromBookingResponse(Map<String, dynamic> json) {
    // Mobile API returns bookingId (camelCase); legacy API returns id + booking_number
    final id =
        (json['bookingId'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt();
    final bookingNumber = json['booking_number']?.toString();
    return BookingConfirmation(
      reference: bookingNumber ?? (id == null ? 'BKG-PENDING' : 'BKG-$id'),
      id: id,
      raw: json,
    );
  }

  factory BookingConfirmation.fromTestBatchResponse(Map<String, dynamic> json) {
    // Mobile API returns batchId (camelCase); legacy API returns batch_id + bookings[]
    final batchId = json['batchId']?.toString() ?? json['batch_id']?.toString();
    final bookings = json['bookings'] as List<dynamic>? ?? const [];
    final first = bookings.isNotEmpty ? _map(bookings.first) : null;
    final bookingNumber = first?['booking_number']?.toString();
    final id = (first?['id'] as num?)?.toInt();
    return BookingConfirmation(
      reference:
          batchId ?? bookingNumber ?? (id == null ? 'LAB-PENDING' : 'LAB-$id'),
      id: id,
      batchId: batchId,
      raw: json,
    );
  }
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

/// Manual health-snapshot entry ("add/update today's readings"). All fields
/// are optional per the API contract — a patient can submit just one field.
class HealthSnapshotInput {
  const HealthSnapshotInput({
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.bloodSugar,
    this.cholesterol,
    this.weight,
    this.otherConditions,
  });

  /// 50–300.
  final int? bloodPressureSystolic;

  /// 30–200.
  final int? bloodPressureDiastolic;

  /// 0–1000 mg/dL.
  final double? bloodSugar;

  /// 0–1000 mg/dL.
  final double? cholesterol;

  /// 1–500 (kg).
  final double? weight;

  /// Max 1000 chars.
  final String? otherConditions;

  Map<String, dynamic> toJson() {
    return {
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'bloodSugar': bloodSugar,
      'cholesterol': cholesterol,
      'weight': weight,
      'otherConditions': otherConditions,
    }..removeWhere((key, value) => value == null);
  }
}

class PatientRepository {
  PatientRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    final response = await _apiClient.postJson(
      '/auth/otp/send',
      data: {
        'phone': normalizePatientPhone(phone),
        if ((mrn ?? '').trim().isNotEmpty) 'mrn': mrn!.trim(),
      },
    );
    if (response['success'] == false) {
      throw ApiException(
        response['message']?.toString() ?? 'Failed to send OTP.',
      );
    }
    return OtpSendResult.fromJson(response);
  }

  Future<PatientAuthSession> registerPatient({
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    required String lastName,
    String? gender,
    String? email,
    String? dateOfBirth,
    String? bloodGroup,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/register',
      data: {
        'phone': normalizePatientPhone(phone),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        if ((gender ?? '').trim().isNotEmpty) 'gender': gender!.trim(),
        if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
        if ((dateOfBirth ?? '').trim().isNotEmpty)
          'date_of_birth': dateOfBirth!.trim(),
        if ((bloodGroup ?? '').trim().isNotEmpty)
          'blood_group': bloodGroup!.trim(),
      },
    );

    return _authSessionFromResponse(response);
  }

  PatientAuthSession _authSessionFromResponse(Map<String, dynamic> response) {
    final token = response['token'] as String? ?? '';
    if (token.trim().isEmpty) {
      throw ApiException('Authentication token missing from server response.');
    }
    return PatientAuthSession(
      token: token,
      patient: PatientIdentity.fromJson(_map(response['patient'])),
    );
  }

  Future<PatientAuthSession> loginPatient({
    required String phone,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      data: {'phone': normalizePatientPhone(phone), 'password': password},
    );

    return _authSessionFromResponse(response);
  }

  Future<OtpSendResult> signUp({
    required String phone,
    required String name,
    required String dob,
    required String place,
    String? email,
    String? gender,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/signup',
      data: {
        'phone': normalizePatientPhone(phone),
        'name': name.trim(),
        'dob': dob.trim(),
        'place': place.trim(),
        if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
        if ((gender ?? '').trim().isNotEmpty) 'gender': gender!.trim(),
      },
    );
    if (response['success'] == false) {
      throw ApiException(
        response['message']?.toString() ?? 'Failed to send signup OTP.',
      );
    }
    return OtpSendResult.fromJson(response);
  }

  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/otp/verify',
      data: {'phone': normalizePatientPhone(phone), 'otp': otp.trim()},
    );

    final token = response['token'] as String? ?? '';
    if (token.trim().isEmpty) {
      throw ApiException('Authentication token missing from server response.');
    }
    return OtpSession(
      token: token,
      patient: PatientIdentity.fromJson(_map(response['patient'])),
    );
  }

  Future<PatientIdentity> getCurrentPatient() async {
    try {
      final response = await _apiClient.getJson('/patients/me');
      final patientJson = response.containsKey('patient')
          ? _map(response['patient'])
          : response;
      if (patientJson.isNotEmpty) {
        return PatientIdentity.fromJson(patientJson);
      }
    } catch (_) {
      // Fall back to legacy profile endpoint.
    }

    final response = await _apiClient.getJson('/auth/profile');
    return PatientIdentity.fromJson(
      response.containsKey('patient') ? _map(response['patient']) : response,
    );
  }

  Future<void> sendVerification() async {
    await _apiClient.postJson('/auth/verification/send');
  }

  Future<void> verifyEmailOtp(String otp) async {
    await _apiClient.postJson(
      '/auth/verification/otp',
      data: {'otp': otp.trim()},
    );
  }

  Future<void> logout() async {
    await _apiClient.postJson('/auth/logout');
  }

  Future<PatientIdentity> updatePatientProfile(PatientIdentity patient) async {
    final response = await _apiClient.patchJson(
      '/patients/me',
      data: patient.toProfilePayload(),
    );
    return PatientIdentity.fromJson(_map(response['patient']));
  }

  /// Most recent health-profile snapshot containing clinical data (falls back
  /// to the latest snapshot of any kind). Returns null when none exist yet.
  Future<HealthProfileSnapshot?> getHealthProfile() async {
    final response = await _apiClient.getJson('/patients/me/health-profile');
    final data = response['data'];
    if (data is Map) {
      return HealthProfileSnapshot.fromJson(_map(data));
    }
    return null;
  }

  /// Creates a new (timestamped) health-profile snapshot. Existing snapshots are
  /// not overwritten. All fields are optional.
  Future<HealthProfileSnapshot> saveHealthProfile({
    List<String>? chronicConditions,
    List<String>? currentMedications,
    List<String>? allergies,
    String? symptoms,
    String? lifestyleNotes,
    String source = 'self_reported',
  }) async {
    final trimmedSymptoms = symptoms?.trim();
    final trimmedLifestyle = lifestyleNotes?.trim();
    final response = await _apiClient.postJson(
      '/patients/me/health-profile',
      data: {
        'chronic_conditions': ?chronicConditions,
        'current_medications': ?currentMedications,
        'allergies': ?allergies,
        if ((trimmedSymptoms ?? '').isNotEmpty) 'symptoms': trimmedSymptoms,
        if ((trimmedLifestyle ?? '').isNotEmpty)
          'lifestyle_notes': trimmedLifestyle,
        'source': source,
      },
    );
    return HealthProfileSnapshot.fromJson(_map(response['data']));
  }

  /// Paginated list of all snapshots, newest first (self-reported plus
  /// auto-generated assessment/document derived entries).
  Future<List<HealthProfileSnapshot>> getHealthProfileHistory() async {
    final response = await _apiClient.getJson(
      '/patients/me/health-profile/history',
    );
    final data = response['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => HealthProfileSnapshot.fromJson(_map(item)))
        .toList();
  }

  Future<PatientDashboard> getDashboard() async {
    final response = await _apiClient.getJson('/patients/me/dashboard');
    return PatientDashboard.fromJson(response);
  }

  Future<List<HomeBannerItem>> getHomeBanners() async {
    final response = await _apiClient.getJson(
      '/home-banners',
      queryParameters: {'target': 'mobile'},
    );
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
    return offers.map((item) {
      final json = _map(item);
      // Offers don't have images in current schema but if they did we'd resolve here
      return HomeOfferItem.fromJson(json);
    }).toList();
  }

  Future<List<BookingItem>> getBookings() async {
    final response = await _apiClient.getJson('/patients/bookings');
    final bookings =
        response['bookings'] as List<dynamic>? ??
        response['data'] as List<dynamic>? ??
        const [];
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
        json['documentPath'] = _resolveDocumentMediaUrl(
          rawPath,
          _apiClient.baseUrl,
          _apiClient,
        );
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
        json['documentPath'] = _resolveDocumentMediaUrl(
          rawPath,
          _apiClient.baseUrl,
          _apiClient,
        );
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
    if (response.containsKey('myClub')) {
      return MyClubSummary.fromJson(_map(response['myClub']));
    }
    return MyClubSummary.fromJson(_map(response));
  }

  Future<List<FamilyMember>> getFamilyMembers() async {
    final response = await _apiClient.getJson('/patients/me/family-members');
    final members = response['members'] as List<dynamic>? ?? const [];
    return members.map((item) => FamilyMember.fromJson(_map(item))).toList();
  }

  Future<FamilyMember> addFamilyMember({
    required String firstName,
    required String relationship,
    String? lastName,
    String? phone,
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    String? email,
  }) async {
    final response = await _apiClient.postJson(
      '/patients/me/family-members',
      data: {
        'first_name': firstName.trim(),
        if ((lastName ?? '').trim().isNotEmpty) 'last_name': lastName!.trim(),
        'relationship': relationship,
        if ((phone ?? '').trim().isNotEmpty)
          'phone': normalizePatientPhone(phone!),
        if ((gender ?? '').trim().isNotEmpty) 'gender': gender!.trim(),
        if ((dateOfBirth ?? '').trim().isNotEmpty)
          'date_of_birth': dateOfBirth!.trim(),
        if ((bloodGroup ?? '').trim().isNotEmpty)
          'blood_group': bloodGroup!.trim(),
        if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
      },
    );
    return FamilyMember.fromJson(_map(response['member']));
  }

  Future<List<HomeCareServiceItem>> getHomeCareServices() async {
    final response = await _apiClient.getJson('/home-care/services');
    final services = response['services'] as List<dynamic>? ?? const [];
    return services
        .map((item) => HomeCareServiceItem.fromJson(_map(item)))
        .toList();
  }

  Future<List<HomeCareBookingItem>> getHomeCareBookings({
    int? patientId,
  }) async {
    final response = await _apiClient.getJson(
      '/home-care/bookings',
      queryParameters: patientId == null ? null : {'patient_id': patientId},
    );
    final bookings = response['bookings'] as List<dynamic>? ?? const [];
    return bookings
        .map((item) => HomeCareBookingItem.fromJson(_map(item)))
        .toList();
  }

  Future<HomeCareBookingItem> createHomeCareBooking(
    HomeCareBookingInput input,
  ) async {
    final response = await _apiClient.postJson(
      '/home-care/bookings',
      data: input.toJson(),
    );
    return HomeCareBookingItem.fromJson(_map(response['booking']));
  }

  Future<void> cancelHomeCareBooking(int bookingId, {int? patientId}) async {
    await _apiClient.patchJson(
      '/home-care/bookings/$bookingId/cancel',
      data: patientId == null ? null : {'patient_id': patientId},
    );
  }

  Future<HealthSnapshot?> getHealthSnapshot() async {
    final response = await _apiClient.getJson('/patients/me/health-snapshot');
    final snapshot = HealthSnapshot.fromJson(response);
    if (snapshot.isEmpty) {
      return null;
    }
    return snapshot;
  }

  Future<HealthSnapshot> refreshHealthSnapshot() async {
    final response = await _apiClient.postJson(
      '/patients/me/health-snapshot/refresh',
    );
    return HealthSnapshot.fromJson(response);
  }

  /// Manual entry ("add" button) — upserts today's snapshot row. Calling
  /// this again on the same day overwrites today's entry.
  Future<HealthSnapshot> submitHealthSnapshot(HealthSnapshotInput input) async {
    final response = await _apiClient.postJson(
      '/patients/me/health-snapshot',
      data: input.toJson(),
    );
    return HealthSnapshot.fromJson(response);
  }

  /// Paginated list of past snapshots ("history" button), newest first, one
  /// entry per day.
  Future<HealthSnapshotHistoryPage> getHealthSnapshotHistory({
    int page = 1,
  }) async {
    final response = await _apiClient.getJson(
      '/patients/me/health-snapshot/history',
      queryParameters: {'page': page},
    );
    return HealthSnapshotHistoryPage.fromJson(response);
  }

  Future<List<AiSuggestionItem>> getAiSuggestions() async {
    final response = await _apiClient.getJson('/patients/me/ai-suggestions');
    final suggestions =
        response['suggestions'] as List<dynamic>? ??
        response['data'] as List<dynamic>? ??
        const [];
    return suggestions
        .map((item) => AiSuggestionItem.fromJson(_map(item)))
        .toList();
  }

  Future<AiSuggestionItem> acceptAiSuggestion(int suggestionId) async {
    final response = await _apiClient.patchJson(
      '/patients/me/ai-suggestions/$suggestionId/accept',
    );
    final suggestion = response['suggestion'] ?? response['data'] ?? response;
    return AiSuggestionItem.fromJson(_map(suggestion));
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
    // Documented response wraps the saved record under the singular `vital` key.
    return VitalRecord.fromJson(_map(response['vital'] ?? response['vitals']));
  }

  Future<List<DoctorListing>> getDoctors() async {
    final response = await _apiClient.getJson('/doctors');
    final doctors =
        response['doctors'] as List<dynamic>? ??
        response['data'] as List<dynamic>? ??
        const [];
    return doctors.map((item) {
      final json = _map(item);
      final rawImage =
          json['imageUrl'] as String? ?? json['image_url'] as String? ?? '';
      if (rawImage.trim().isNotEmpty) {
        json['imageUrl'] = _resolveApiMediaUrl(rawImage, _apiClient.baseUrl);
      }
      return DoctorListing.fromJson(json);
    }).toList();
  }

  Future<List<DepartmentItem>> getDepartments() async {
    final response = await _apiClient.getJson('/departments');
    final departments = response['departments'] as List<dynamic>? ?? const [];
    return departments.map((item) {
      final json = _map(item);
      final rawImage =
          json['imageUrl'] as String? ?? json['image_url'] as String? ?? '';
      if (rawImage.trim().isNotEmpty) {
        json['imageUrl'] = _resolveApiMediaUrl(rawImage, _apiClient.baseUrl);
      }
      return DepartmentItem.fromJson(json);
    }).toList();
  }

  Future<BookingConfirmation> createBooking({
    required int doctorId,
    required String bookingDate,
    required String timeslot,
    String? notes,
  }) async {
    final response = await _apiClient.postJson(
      '/bookings',
      data: {
        'doctorId': doctorId,
        'bookingDate': bookingDate,
        'timeslot': timeslot,
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      },
    );
    return BookingConfirmation.fromBookingResponse(response);
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
    // Documented "Show Thread" response returns the message list under `messages`.
    final history =
        response['messages'] as List<dynamic>? ??
        response['history'] as List<dynamic>? ??
        const [];
    return history.map((item) => ChatMessage.fromJson(_map(item))).toList();
  }

  Future<List<LabTestItem>> getLabTests() async {
    final response = await _apiClient.getJson('/patient/lab-tests');
    final tests =
        response['tests'] as List<dynamic>? ??
        response['data'] as List<dynamic>? ??
        const [];
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

  Future<List<BodyPointItem>> getBodyPoints() async {
    final response = await _apiClient.getJson('/body-points');
    final points = response['bodyPoints'] as List<dynamic>? ?? const [];
    return points.map((item) => BodyPointItem.fromJson(_map(item))).toList();
  }

  Future<List<LabOrderItem>> getLabOrders() async {
    final response = await _apiClient.getJson('/patient/lab-orders');
    final orders = response['orders'] as List<dynamic>? ?? const [];
    return orders.map((item) {
      final json = _map(item);
      final rawImage =
          json['imageUrl'] as String? ?? json['image_url'] as String? ?? '';
      if (rawImage.trim().isNotEmpty) {
        json['imageUrl'] = _resolveApiMediaUrl(rawImage, _apiClient.baseUrl);
      }
      return LabOrderItem.fromJson(json);
    }).toList();
  }

  Future<List<LabPackageItem>> getLabPackages() async {
    final response = await _apiClient.getJson('/patient/lab-packages');
    final packages =
        response['packages'] as List<dynamic>? ??
        response['data'] as List<dynamic>? ??
        const [];
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
  }) async {
    final trimmedSlot = slot?.trim();
    final trimmedNotes = notes?.trim();
    final resolvedTestIds = labTestIds != null && labTestIds.isNotEmpty
        ? labTestIds
        : <int>[?labTestId];

    if (resolvedTestIds.isEmpty) {
      throw StateError('Select at least one lab test.');
    }

    final trimmedAddress = address?.trim();
    final trimmedBookingRef = bookingRef?.trim();
    final response = await _apiClient.postJson(
      '/patient/lab-orders',
      data: {
        'labTestIds': resolvedTestIds,
        'date': date,
        'doctorId': ?doctorId,
        if ((trimmedSlot ?? '').isNotEmpty) 'slot': trimmedSlot,
        'paymentStatus': paymentStatus,
        'collectionType': collectionType,
        if ((trimmedAddress ?? '').isNotEmpty) 'address': trimmedAddress,
        'amount': ?amount,
        if ((patientNameSnapshot ?? '').trim().isNotEmpty)
          'patientNameSnapshot': patientNameSnapshot!.trim(),
        'patientAgeSnapshot': ?patientAgeSnapshot,
        if ((patientGenderSnapshot ?? '').trim().isNotEmpty)
          'patientGenderSnapshot': patientGenderSnapshot!.trim(),
        if ((patientPhoneSnapshot ?? '').trim().isNotEmpty)
          'patientPhoneSnapshot': patientPhoneSnapshot!.trim(),
        if ((trimmedBookingRef ?? '').isNotEmpty)
          'bookingRef': trimmedBookingRef,
        'urgency': urgency,
        if ((trimmedNotes ?? '').isNotEmpty) 'notes': trimmedNotes,
      },
    );
    return BookingConfirmation.fromTestBatchResponse(response);
  }

  Future<void> cancelLabOrder(int orderId) async {
    await _apiClient.patchJson(
      '/patient/lab-orders/$orderId',
      data: {'status': 'cancelled'},
    );
  }

  Future<void> rescheduleLabOrder({
    required int orderId,
    required String date,
    String? slot,
  }) async {
    await _apiClient.patchJson(
      '/patient/lab-orders/$orderId',
      data: {
        'date': date,
        if (slot != null && slot.trim().isNotEmpty) 'slot': slot.trim(),
      },
    );
  }

  Future<BookingConfirmation> createLabPackageOrder({
    required int labPackageId,
    int? doctorId,
    required String date,
    String? slot,
    String? collectionType = 'home',
    String? address,
    double? amount,
    String? paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? patientPhoneSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
  }) async {
    final trimmedSlot = slot?.trim();
    final trimmedNotes = notes?.trim();
    final trimmedAddress = address?.trim();
    final trimmedBookingRef = bookingRef?.trim();

    final data = {
      'packageId': labPackageId,
      'date': date,
      'doctorId': ?doctorId,
      if ((trimmedSlot ?? '').isNotEmpty) 'slot': trimmedSlot,
      if ((paymentStatus ?? '').trim().isNotEmpty)
        'paymentStatus': paymentStatus!.trim(),
      if ((collectionType ?? '').trim().isNotEmpty)
        'collectionType': collectionType!.trim(),
      if ((trimmedAddress ?? '').isNotEmpty) 'address': trimmedAddress,
      'amount': ?amount,
      if ((patientNameSnapshot ?? '').trim().isNotEmpty)
        'patientNameSnapshot': patientNameSnapshot!.trim(),
      'patientAgeSnapshot': ?patientAgeSnapshot,
      if ((patientGenderSnapshot ?? '').trim().isNotEmpty)
        'patientGenderSnapshot': patientGenderSnapshot!.trim(),
      if ((patientPhoneSnapshot ?? '').trim().isNotEmpty)
        'patientPhoneSnapshot': patientPhoneSnapshot!.trim(),
      if ((trimmedBookingRef ?? '').isNotEmpty) 'bookingRef': trimmedBookingRef,
      'urgency': urgency,
      if ((trimmedNotes ?? '').isNotEmpty) 'notes': trimmedNotes,
    };

    try {
      final response = await _apiClient.postJson(
        '/patient/lab-package-orders',
        data: data,
      );
      return BookingConfirmation.fromBookingResponse(response);
    } catch (e) {
      debugPrint('[PatientRepository] Error creating lab package order: $e');
      rethrow;
    }
  }

  Future<void> cancelLabPackageOrder(int orderId) async {
    await _apiClient.patchJson(
      '/patient/lab-package-orders/$orderId',
      data: {'status': 'cancelled'},
    );
  }

  Future<void> rescheduleLabPackageOrder({
    required int orderId,
    required String date,
    String? slot,
  }) async {
    await _apiClient.patchJson(
      '/patient/lab-package-orders/$orderId',
      data: {
        'date': date,
        if (slot != null && slot.trim().isNotEmpty) 'slot': slot.trim(),
      },
    );
  }

  Future<DocumentRecord> uploadDocument(
    String filePath, {
    String? fileName,
  }) async {
    final normalized = filePath.trim();
    final uploadFileName = (fileName ?? '').trim().isNotEmpty
        ? fileName!.trim()
        : normalized.split(RegExp(r'[\\/]')).last;

    final response = await _apiClient.postMultipart(
      '/patients/documents',
      data: FormData.fromMap({
        'document': await MultipartFile.fromFile(
          File(normalized).path,
          filename: uploadFileName,
        ),
      }),
    );

    final json = _map(response['document']);
    final rawPath = json['documentPath'] as String? ?? '';
    if (rawPath.trim().isNotEmpty) {
      json['documentPath'] = _resolveDocumentMediaUrl(
        rawPath,
        _apiClient.baseUrl,
        _apiClient,
      );
    }
    return DocumentRecord.fromJson(json);
  }

  Future<DocumentAnalysisResult> analyzeDocument(
    int documentId, {
    String language = 'en',
  }) async {
    final response = await _apiClient.postJson(
      '/patients/documents/$documentId/analyze',
      data: {'language': language},
    );
    if (response['success'] == false) {
      if (response['status']?.toString() == 'processing' ||
          response['status']?.toString() == 'queued') {
        return DocumentAnalysisResult.fromJson(response);
      }
      throw ApiException(response['error']?.toString() ?? 'Analysis failed.');
    }
    return DocumentAnalysisResult.fromJson(response);
  }

  Future<void> deleteDocument(int documentId) async {
    await _apiClient.deleteJson('/patients/documents/$documentId');
  }

  Future<List<ChatMessage>> getDocumentChatHistory(int documentId) async {
    final response = await _apiClient.getJson(
      '/patients/documents/$documentId/chat',
    );
    // Documented response returns the message list under `messages`.
    final history =
        response['messages'] as List<dynamic>? ??
        response['history'] as List<dynamic>? ??
        const [];
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
    final pkgsRaw = response['suggestedPackages'] as List<dynamic>? ?? const [];
    final suggestedPackages = pkgsRaw
        .map((item) => LabPackageItem.fromJson(_map(item)))
        .toList();
    final testsRaw = response['suggestedTests'] as List<dynamic>? ?? const [];
    final suggestedTests = testsRaw
        .map((item) => LabTestItem.fromJson(_map(item)))
        .toList();
    return ChatMessage(
      role: 'ai',
      content:
          response['reply'] as String? ??
          response['content'] as String? ??
          'No response',
      suggestedPackages: suggestedPackages,
      suggestedTests: suggestedTests,
    );
  }

  Future<ChatMessage> sendGlobalChatMessage({
    required String threadId,
    required String message,
    String? language,
    String? mode,
  }) async {
    final normalizedLanguage = (language ?? '').trim().toLowerCase();
    final normalizedMode = (mode ?? '').trim().toLowerCase();
    final response = await _apiClient.postJson(
      '/patients/chat/global/threads/$threadId/messages',
      receiveTimeout: const Duration(seconds: 75),
      data: {
        'message': message,
        if (normalizedLanguage == 'en' || normalizedLanguage == 'ml')
          'language': normalizedLanguage,
        if (normalizedMode == 'voice' || normalizedMode == 'text')
          'mode': normalizedMode,
      },
    );
    final pkgsRaw = response['suggestedPackages'] as List<dynamic>? ?? const [];
    final suggestedPackages = pkgsRaw
        .map(
          (item) => LabPackageItem.fromJson(
            item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final testsRaw = response['suggestedTests'] as List<dynamic>? ?? const [];
    final suggestedTests = testsRaw
        .map(
          (item) => LabTestItem.fromJson(
            item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final messagePayload = _map(response['message']);

    return ChatMessage(
      id: (messagePayload['id'] as num?)?.toInt(),
      role: messagePayload['role'] as String? ?? 'ai',
      content:
          messagePayload['content'] as String? ??
          response['reply'] as String? ??
          'No response',
      createdAt:
          messagePayload['createdAt'] as String? ??
          messagePayload['created_at'] as String?,
      suggestedPackages: suggestedPackages,
      suggestedTests: suggestedTests,
    );
  }

  /// Push-to-talk voice turn. Uploads a recorded audio clip; the server runs
  /// STT → LLM → TTS and returns the transcript, the AI reply, and an optional
  /// signed URL to a spoken rendering of the reply.
  Future<GlobalChatVoiceReply> sendGlobalChatVoiceMessage({
    required String threadId,
    required String audioFilePath,
    String? language,
  }) async {
    final normalizedLanguage = (language ?? '').trim().toLowerCase();
    final fileName = audioFilePath.split(RegExp(r'[\\/]')).last;
    final response = await _apiClient.postMultipart(
      '/patients/chat/global/threads/$threadId/voice',
      receiveTimeout: const Duration(seconds: 120),
      data: FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          File(audioFilePath).path,
          filename: fileName,
          contentType: DioMediaType.parse(_voiceUploadContentType(fileName)),
        ),
        if (normalizedLanguage == 'en' || normalizedLanguage == 'ml')
          'language': normalizedLanguage,
        'synthesize_audio': '1',
      }),
    );

    final pkgsRaw = response['suggestedPackages'] as List<dynamic>? ?? const [];
    final suggestedPackages = pkgsRaw
        .map((item) => LabPackageItem.fromJson(_map(item)))
        .toList();
    final testsRaw = response['suggestedTests'] as List<dynamic>? ?? const [];
    final suggestedTests = testsRaw
        .map((item) => LabTestItem.fromJson(_map(item)))
        .toList();

    final rawAudioUrl = (response['audio_url'] as String? ?? '').trim();
    final resolvedAudioUrl = rawAudioUrl.isEmpty
        ? null
        : _resolveApiMediaUrl(rawAudioUrl, _apiClient.baseUrl);
    final messagePayload = _map(response['message']);

    return GlobalChatVoiceReply(
      transcript: (response['transcript'] as String? ?? '').trim(),
      audioUrl: resolvedAudioUrl,
      reply: ChatMessage(
        id: (messagePayload['id'] as num?)?.toInt(),
        role: messagePayload['role'] as String? ?? 'ai',
        content:
            messagePayload['content'] as String? ??
            response['reply'] as String? ??
            response['content'] as String? ??
            'No response',
        createdAt:
            messagePayload['createdAt'] as String? ??
            messagePayload['created_at'] as String?,
        suggestedPackages: suggestedPackages,
        suggestedTests: suggestedTests,
      ),
    );
  }

  Future<VoiceProviderConfig> getVoiceProviderConfig() async {
    final response = await _apiClient.getJson('/patients/chat/voice-config');
    return VoiceProviderConfig.fromJson(response);
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

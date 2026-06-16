import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
    final id = (json['id'] as num?)?.toInt();
    final bookingNumber = json['booking_number']?.toString();
    return BookingConfirmation(
      reference: (bookingNumber ?? (id == null ? 'BKG-PENDING' : 'BKG-$id')),
      id: id,
      raw: json,
    );
  }

  factory BookingConfirmation.fromTestBatchResponse(Map<String, dynamic> json) {
    final batchId = json['batch_id']?.toString();
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

String _normalizeBookingTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;

  final firstPart = trimmed.split('-').first.trim();
  final periodMatch = RegExp(
    r'\b(am|pm)\b',
    caseSensitive: false,
  ).firstMatch(trimmed);
  final period = periodMatch?.group(1)?.toUpperCase();
  final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(firstPart);
  if (timeMatch == null) return trimmed;

  var hour = int.tryParse(timeMatch.group(1) ?? '');
  final minute = int.tryParse(timeMatch.group(2) ?? '');
  if (hour == null || minute == null) return trimmed;

  if (period == 'PM' && hour < 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;

  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
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

  Future<String?> sendOtp({required String phone, String? mrn}) async {
    final response = await _apiClient.postJson(
      '/auth/otp/send',
      data: {'phone': phone, 'mrn': mrn},
    );
    return response['dev_otp']?.toString();
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
        'phone': phone.trim(),
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

    return PatientAuthSession(
      token: response['token'] as String? ?? '',
      patient: PatientIdentity.fromJson(_map(response['patient'])),
    );
  }

  Future<PatientAuthSession> loginPatient({
    required String phone,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      data: {'phone': phone.trim(), 'password': password},
    );

    return PatientAuthSession(
      token: response['token'] as String? ?? '',
      patient: PatientIdentity.fromJson(_map(response['patient'])),
    );
  }

  Future<String?> signUp({
    required String phone,
    required String name,
    required String dob,
    required String place,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/signup',
      data: {'phone': phone, 'name': name, 'dob': dob, 'place': place},
    );
    return response['dev_otp']?.toString();
  }

  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/otp/verify',
      data: {'phone': phone, 'otp': otp},
    );

    return OtpSession(
      token: response['token'] as String? ?? '',
      patient: PatientIdentity.fromJson(_map(response['patient'])),
    );
  }

  Future<PatientIdentity> getCurrentPatient() async {
    final response = await _apiClient.getJson('/auth/profile');
    return PatientIdentity.fromJson(
      response.containsKey('patient') ? _map(response['patient']) : response,
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
    required int scheduleId,
    required String bookingDate,
    required String timeslot,
    String? notes,
  }) async {
    final response = await _apiClient.postJson(
      '/bookings/doctors',
      data: {
        'doctor_id': doctorId,
        'schedule_id': scheduleId,
        'booking_date': bookingDate,
        'booking_time': _normalizeBookingTime(timeslot),
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      },
    );
    return BookingConfirmation.fromBookingResponse(response);
  }

  Future<void> cancelBooking(int bookingId) async {
    await _apiClient.patchJson('/bookings/doctors/$bookingId/cancel');
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
    final response = await _apiClient.getJson('/lab/tests');
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
    final response = await _apiClient.getJson('/lab/packages');
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

    final response = await _apiClient.postJson(
      '/bookings/tests',
      data: {
        'test_ids': resolvedTestIds,
        'booking_date': date,
        if ((trimmedSlot ?? '').isNotEmpty)
          'booking_time': _normalizeBookingTime(trimmedSlot!),
        if ((trimmedNotes ?? '').isNotEmpty) 'notes': trimmedNotes,
      },
    );
    return BookingConfirmation.fromTestBatchResponse(response);
  }

  Future<void> cancelLabOrder(int orderId) async {
    await _apiClient.patchJson('/bookings/tests/$orderId/cancel');
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

    final data = {
      'package_id': labPackageId,
      'booking_date': date,
      if ((trimmedSlot ?? '').isNotEmpty)
        'booking_time': _normalizeBookingTime(trimmedSlot!),
      if ((trimmedNotes ?? '').isNotEmpty) 'notes': trimmedNotes,
    };

    try {
      final response = await _apiClient.postJson(
        '/bookings/packages',
        data: data,
      );
      return BookingConfirmation.fromBookingResponse(response);
    } catch (e) {
      debugPrint('[PatientRepository] Error creating lab package order: $e');
      rethrow;
    }
  }

  Future<void> cancelLabPackageOrder(int orderId) async {
    await _apiClient.patchJson('/bookings/packages/$orderId/cancel');
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
      json['documentPath'] = _resolveDocumentMediaUrl(
        rawPath,
        _apiClient.baseUrl,
        _apiClient,
      );
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
    String? language,
    String? mode,
  }) async {
    final normalizedLanguage = (language ?? '').trim().toLowerCase();
    final normalizedMode = (mode ?? '').trim().toLowerCase();
    final response = await _apiClient.postJson(
      '/patients/chat/global/threads/$threadId/messages',
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
    return ChatMessage(
      role: 'ai',
      content: response['reply'] as String? ?? 'No response',
      suggestedPackages: suggestedPackages,
      suggestedTests: suggestedTests,
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

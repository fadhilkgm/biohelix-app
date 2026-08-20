import 'dart:convert';

double? _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? _intValue(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value.trim())?.toInt();
  return null;
}

class PatientIdentity {
  const PatientIdentity({
    required this.id,
    required this.name,
    required this.phone,
    required this.registrationNumber,
    required this.uuid,
    this.dob,
    this.gender,
    this.age,
    this.address,
    this.email,
    this.bloodGroup,
    this.allergies,
    this.chronicConditions,
    this.legalConsentAcceptedAt,
    this.hasCompletedInitialHealthAssessment = true,
  });

  final int id;
  final String name;
  final String phone;
  final String registrationNumber;
  final String uuid;
  final String? dob;
  final String? gender;
  final int? age;
  final String? address;
  final String? email;
  final String? bloodGroup;
  final String? allergies;
  final String? chronicConditions;
  final String? legalConsentAcceptedAt;
  final bool hasCompletedInitialHealthAssessment;
  bool get hasAcceptedLegalConsent =>
      (legalConsentAcceptedAt ?? '').trim().isNotEmpty;

  factory PatientIdentity.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] as String?;
    final lastName = json['last_name'] as String?;
    final joinedName = [
      firstName,
      lastName,
    ].where((value) => (value ?? '').trim().isNotEmpty).join(' ');
    return PatientIdentity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name:
          json['name'] as String? ??
          json['full_name'] as String? ??
          (joinedName.isNotEmpty ? joinedName : 'Patient'),
      phone: json['phone'] as String? ?? '',
      registrationNumber:
          json['registrationNumber'] as String? ??
          json['registration_number'] as String? ??
          json['patient_number'] as String? ??
          json['patient_card_number'] as String? ??
          'BHRC',
      uuid: json['uuid'] as String? ?? '',
      dob: json['dob'] as String? ?? json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      age: (json['age'] as num?)?.toInt(),
      address: json['address'] as String?,
      email: json['email'] as String?,
      bloodGroup:
          json['bloodGroup'] as String? ?? json['blood_group'] as String?,
      allergies: _nullableText(json['allergies']),
      chronicConditions: _nullableText(
        json['chronicConditions'] ?? json['chronic_conditions'],
      ),
      legalConsentAcceptedAt:
          json['legalConsentAcceptedAt'] as String? ??
          json['legal_consent_accepted_at'] as String?,
      hasCompletedInitialHealthAssessment:
          json['hasCompletedInitialHealthAssessment'] as bool? ??
          json['has_completed_initial_health_assessment'] as bool? ??
          (json['initialHealthAssessmentCompletedAt'] != null ||
              json['initial_health_assessment_completed_at'] != null),
    );
  }

  Map<String, dynamic> toProfilePayload() {
    return {
      'name': name,
      'dob': dob,
      'gender': gender,
      'age': age,
      'address': address,
      'email': email,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'registrationNumber': registrationNumber,
      'uuid': uuid,
      'dob': dob,
      'gender': gender,
      'age': age,
      'address': address,
      'email': email,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'legalConsentAcceptedAt': legalConsentAcceptedAt,
      'hasCompletedInitialHealthAssessment':
          hasCompletedInitialHealthAssessment,
    }..removeWhere((key, value) => value == null);
  }

  PatientIdentity copyWith({
    String? name,
    String? dob,
    String? gender,
    int? age,
    String? address,
    String? email,
    String? bloodGroup,
    String? allergies,
    String? chronicConditions,
    String? legalConsentAcceptedAt,
    bool? hasCompletedInitialHealthAssessment,
  }) {
    return PatientIdentity(
      id: id,
      name: name ?? this.name,
      phone: phone,
      registrationNumber: registrationNumber,
      uuid: uuid,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      address: address ?? this.address,
      email: email ?? this.email,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      legalConsentAcceptedAt:
          legalConsentAcceptedAt ?? this.legalConsentAcceptedAt,
      hasCompletedInitialHealthAssessment:
          hasCompletedInitialHealthAssessment ??
          this.hasCompletedInitialHealthAssessment,
    );
  }
}

class SavedPatientProfile {
  const SavedPatientProfile({
    required this.token,
    required this.patient,
    required this.lastUsedAt,
  });

  final String token;
  final PatientIdentity patient;
  final String lastUsedAt;

  factory SavedPatientProfile.fromJson(Map<String, dynamic> json) {
    return SavedPatientProfile(
      token: json['token'] as String? ?? '',
      patient: PatientIdentity.fromJson(_map(json['patient'])),
      lastUsedAt: json['lastUsedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'patient': patient.toJson(),
      'lastUsedAt': lastUsedAt,
    };
  }

  SavedPatientProfile copyWith({
    String? token,
    PatientIdentity? patient,
    String? lastUsedAt,
  }) {
    return SavedPatientProfile(
      token: token ?? this.token,
      patient: patient ?? this.patient,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// Patient profile fields are strings in older API responses, while newer
/// responses can expose JSON-array health data. Keep the UI's text-based model
/// compatible with both shapes.
String? _nullableText(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  if (value is Iterable) {
    final text = value
        .where((item) => item != null)
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .join(', ');
    return text.isEmpty ? null : text;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

class PortalMetrics {
  const PortalMetrics({
    required this.totalRecords,
    required this.availableRecords,
    required this.processingRecords,
    required this.showingRecords,
    required this.upcomingBookings,
  });

  final int totalRecords;
  final int availableRecords;
  final int processingRecords;
  final int showingRecords;
  final int upcomingBookings;

  factory PortalMetrics.fromJson(Map<String, dynamic> json) {
    return PortalMetrics(
      totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
      availableRecords: (json['availableRecords'] as num?)?.toInt() ?? 0,
      processingRecords: (json['processingRecords'] as num?)?.toInt() ?? 0,
      showingRecords: (json['showingRecords'] as num?)?.toInt() ?? 0,
      upcomingBookings: (json['upcomingBookings'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookingItem {
  const BookingItem({
    required this.id,
    required this.bookingDate,
    required this.timeslot,
    required this.status,
    required this.doctorId,
    required this.doctorName,
    this.tokenNumber,
    this.doctorSpecialization,
    this.doctorImageUrl,
    this.bookingType,
    this.testName,
    this.packageName,
  });

  final int id;
  final String bookingDate;
  final String timeslot;
  final String status;
  final int doctorId;
  final String doctorName;
  final int? tokenNumber;
  final String? doctorSpecialization;
  final String? doctorImageUrl;
  final String? bookingType;
  final String? testName;
  final String? packageName;

  bool get isDoctorAppointment {
    final type = (bookingType ?? '').trim().toLowerCase();
    if (type == 'test' || type == 'package' || type == 'lab') {
      return false;
    }
    if (type == 'doctor') {
      return true;
    }
    if ((testName ?? '').trim().isNotEmpty) return false;
    if ((packageName ?? '').trim().isNotEmpty) return false;
    return true;
  }

  String effectiveStatus({DateTime? now}) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'no_show' || normalized == 'no-show') {
      return 'missed';
    }
    if (_closedStatuses.contains(normalized)) {
      return status;
    }
    return hasEnded(now: now) ? 'missed' : status;
  }

  bool hasEnded({DateTime? now}) {
    final date = _parseBookingDate(bookingDate);
    if (date == null) return false;

    final current = now ?? DateTime.now();
    final appointmentEnd = _appointmentEnd(date, timeslot);
    if (appointmentEnd != null) {
      return !current.isBefore(appointmentEnd);
    }

    final nextDay = DateTime(date.year, date.month, date.day + 1);
    return !current.isBefore(nextDay);
  }

  static const _closedStatuses = {
    'cancelled',
    'canceled',
    'completed',
    'complete',
    'checked_in',
    'checked-in',
    'done',
    'expired',
    'missed',
  };

  static DateTime? _parseBookingDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;

    final direct = DateTime.tryParse(normalized);
    if (direct != null) {
      return DateTime(direct.year, direct.month, direct.day);
    }

    final parts = normalized.split(RegExp(r'[-/]'));
    if (parts.length != 3) return null;
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) return null;

    try {
      return first > 999
          ? DateTime(first, second, third)
          : DateTime(third, second, first);
    } on ArgumentError {
      return null;
    }
  }

  static DateTime? _appointmentEnd(DateTime date, String rawTimeslot) {
    final matches = RegExp(
      r'(\d{1,2}):(\d{2})(?:\s*([ap]m))?',
      caseSensitive: false,
    ).allMatches(rawTimeslot).toList(growable: false);
    if (matches.isEmpty) return null;

    int? minutesFromMidnight(RegExpMatch match) {
      var hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '');
      if (hour == null || minute == null || minute > 59) return null;

      final meridiem = match.group(3)?.toLowerCase();
      if (meridiem != null) {
        if (hour < 1 || hour > 12) return null;
        hour %= 12;
        if (meridiem == 'pm') hour += 12;
      } else if (hour > 23) {
        return null;
      }
      return (hour * 60) + minute;
    }

    final startMinutes = minutesFromMidnight(matches.first);
    final parsedEndMinutes = minutesFromMidnight(matches.last);
    if (parsedEndMinutes == null) return null;

    var endMinutes = parsedEndMinutes;
    if (matches.length == 1) {
      endMinutes += 15;
    } else if (startMinutes != null && endMinutes <= startMinutes) {
      endMinutes += const Duration(days: 1).inMinutes;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: endMinutes));
  }

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    final doctor = _map(json['doctor']);
    final test = _map(json['test']);
    final package = _map(json['package']);
    final bookingType =
        json['booking_type'] as String? ?? json['type'] as String?;
    final testName =
        json['testName'] as String? ?? test['test_name'] as String?;
    final packageName =
        json['packageName'] as String? ?? package['package_name'] as String?;
    final nameFromRelation =
        doctor['name'] as String? ?? testName ?? packageName;
    return BookingItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bookingDate:
          json['bookingDate'] as String? ??
          json['booking_date'] as String? ??
          '',
      timeslot:
          json['timeslot'] as String? ?? json['booking_time'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      doctorId:
          (json['doctorId'] as num?)?.toInt() ??
          (json['doctor_id'] as num?)?.toInt() ??
          0,
      tokenNumber:
          (json['tokenNumber'] as num?)?.toInt() ??
          (json['token_number'] as num?)?.toInt(),
      doctorName:
          json['doctorName'] as String? ??
          nameFromRelation ??
          (bookingType == 'test'
              ? 'Lab test'
              : bookingType == 'package'
              ? 'Health package'
              : 'BHRC Doctor'),
      doctorSpecialization:
          json['doctorSpecialization'] as String? ??
          doctor['specialization'] as String?,
      doctorImageUrl:
          json['doctorImageUrl'] as String? ??
          json['doctor_image_url'] as String? ??
          doctor['imageUrl'] as String? ??
          doctor['profile_photo_url'] as String?,
      bookingType: bookingType,
      testName: testName,
      packageName: packageName,
    );
  }
}

class MedicineItem {
  const MedicineItem({
    required this.id,
    required this.medicineName,
    this.dosage,
    this.frequency,
    this.duration,
    this.instructions,
  });

  final int id;
  final String medicineName;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? instructions;

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      medicineName: json['medicineName'] as String? ?? 'Medicine',
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      duration: json['duration'] as String?,
      instructions: json['instructions'] as String?,
    );
  }
}

class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.date,
    required this.time,
    required this.doctorName,
    this.diagnosis,
    this.followUpDate,
    this.notes,
    this.medicines = const [],
  });

  final int id;
  final String date;
  final String time;
  final String doctorName;
  final String? diagnosis;
  final String? followUpDate;
  final String? notes;
  final List<MedicineItem> medicines;

  factory PrescriptionRecord.fromJson(Map<String, dynamic> json) {
    final medicinesJson = json['medicines'] as List<dynamic>? ?? const [];
    return PrescriptionRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? 'BHRC Doctor',
      diagnosis: json['diagnosis'] as String?,
      followUpDate: json['followUpDate'] as String?,
      notes: json['notes'] as String?,
      medicines: medicinesJson
          .map((item) => MedicineItem.fromJson(_map(item)))
          .toList(),
    );
  }
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.date,
    required this.documentType,
    required this.documentPath,
    required this.hasAnalysis,
    this.time,
    this.summary,
  });

  final int id;
  final String date;
  final String documentType;
  final String documentPath;
  final bool hasAnalysis;
  final String? time;
  final String? summary;

  factory DocumentRecord.fromJson(Map<String, dynamic> json) {
    return DocumentRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      documentType: json['documentType'] as String? ?? 'document',
      documentPath: json['documentPath'] as String? ?? '',
      hasAnalysis: json['hasAnalysis'] as bool? ?? false,
      time: json['time'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class SummaryRecord {
  const SummaryRecord({
    required this.id,
    required this.date,
    required this.type,
    required this.summary,
  });

  final int id;
  final String date;
  final String type;
  final String summary;

  factory SummaryRecord.fromJson(Map<String, dynamic> json) {
    return SummaryRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date:
          json['date'] as String? ??
          json['createdAt'] as String? ??
          json['created_at'] as String? ??
          '',
      type: json['type'] as String? ?? json['title'] as String? ?? 'summary',
      summary: json['summary'] as String? ?? '',
    );
  }
}

class MedicalRecordItem {
  const MedicalRecordItem({
    required this.id,
    required this.sourceType,
    required this.category,
    required this.recordType,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
    required this.kindLabel,
    this.time,
    this.summary,
    this.doctorName,
    this.documentPath,
    this.hasAnalysis = false,
    this.medicines = const [],
  });

  final String id;
  final String sourceType;
  final String category;
  final String recordType;
  final String title;
  final String subtitle;
  final String status;
  final String date;
  final String kindLabel;
  final String? time;
  final String? summary;
  final String? doctorName;
  final String? documentPath;
  final bool hasAnalysis;
  final List<MedicineItem> medicines;

  factory MedicalRecordItem.fromJson(Map<String, dynamic> json) {
    final medicinesJson = json['medicines'] as List<dynamic>? ?? const [];
    final data = _map(json['data']);
    final apiType = json['type'] as String? ?? data['type'] as String?;
    final category = json['category'] as String? ?? apiType ?? 'lab';
    final documentPath =
        json['documentPath'] as String? ??
        data['fileUrl'] as String? ??
        data['file_url'] as String? ??
        data['documentPath'] as String?;

    return MedicalRecordItem(
      id: json['id']?.toString() ?? '',
      sourceType: json['sourceType'] as String? ?? apiType ?? 'document',
      category: category,
      recordType: json['recordType'] as String? ?? apiType ?? 'Record',
      title: json['title'] as String? ?? 'Medical Record',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      date: json['date'] as String? ?? '',
      kindLabel: json['kindLabel'] as String? ?? apiType ?? 'Record',
      time: json['time'] as String?,
      summary: json['summary'] as String?,
      doctorName: json['doctorName'] as String?,
      documentPath: documentPath,
      hasAnalysis: json['hasAnalysis'] as bool? ?? false,
      medicines: medicinesJson
          .map((item) => MedicineItem.fromJson(_map(item)))
          .toList(),
    );
  }
}

class VitalRecord {
  const VitalRecord({
    required this.id,
    required this.recordedAt,
    this.height,
    this.weight,
    this.bmi,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.bodyTemperature,
    this.oxygenSaturation,
    this.respiratoryRate,
    this.notes,
  });

  final int id;
  final String recordedAt;
  final double? height;
  final double? weight;
  final double? bmi;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;
  final double? bodyTemperature;
  final int? oxygenSaturation;
  final int? respiratoryRate;
  final String? notes;

  factory VitalRecord.fromJson(Map<String, dynamic> json) {
    return VitalRecord(
      id: _intValue(json['id']) ?? 0,
      recordedAt:
          json['recordedAt'] as String? ?? json['recorded_at'] as String? ?? '',
      height: _doubleValue(json['height']),
      weight: _doubleValue(json['weight']),
      bmi: _doubleValue(json['bmi']),
      bloodPressureSystolic:
          _intValue(json['bloodPressureSystolic']) ??
          _intValue(json['bp_systolic']),
      bloodPressureDiastolic:
          _intValue(json['bloodPressureDiastolic']) ??
          _intValue(json['bp_diastolic']),
      heartRate: _intValue(json['heartRate']) ?? _intValue(json['heart_rate']),
      bodyTemperature:
          _doubleValue(json['bodyTemperature']) ??
          _doubleValue(json['body_temperature']),
      oxygenSaturation:
          _intValue(json['oxygenSaturation']) ?? _intValue(json['spo2']),
      respiratoryRate:
          _intValue(json['respiratoryRate']) ??
          _intValue(json['respiratory_rate']),
      notes: json['notes'] as String?,
    );
  }

  /// Parses the compact `latest_vitals` shape embedded in a health-snapshot
  /// payload, which differs from the regular vitals endpoint: BP is a single
  /// combined `"128/82"` string and some keys use different names
  /// (`temperature`, `oxygen_saturation`) than the vitals API
  /// (`body_temperature`, `spo2`).
  factory VitalRecord.fromSnapshotJson(Map<String, dynamic> json) {
    int? systolic;
    int? diastolic;
    final bpValue = json['bp'] ?? json['blood_pressure'];
    final bpRaw = bpValue?.toString();
    if (bpRaw != null && bpRaw.contains('/')) {
      final parts = bpRaw.split('/');
      systolic = int.tryParse(parts[0].trim());
      if (parts.length > 1) {
        diastolic = int.tryParse(parts[1].trim());
      }
    } else if (bpRaw != null) {
      systolic = int.tryParse(bpRaw.trim());
    }
    systolic ??=
        _intValue(json['bp_systolic']) ??
        _intValue(json['bloodPressureSystolic']);
    diastolic ??=
        _intValue(json['bp_diastolic']) ??
        _intValue(json['bloodPressureDiastolic']);

    return VitalRecord(
      id: _intValue(json['id']) ?? 0,
      recordedAt:
          json['recorded_at'] as String? ?? json['recordedAt'] as String? ?? '',
      height: _doubleValue(json['height']),
      weight: _doubleValue(json['weight']),
      bmi: _doubleValue(json['bmi']),
      bloodPressureSystolic: systolic,
      bloodPressureDiastolic: diastolic,
      heartRate: _intValue(json['heart_rate']) ?? _intValue(json['heartRate']),
      bodyTemperature:
          _doubleValue(json['temperature']) ??
          _doubleValue(json['body_temperature']),
      oxygenSaturation:
          _intValue(json['oxygen_saturation']) ?? _intValue(json['spo2']),
      respiratoryRate:
          _intValue(json['respiratory_rate']) ??
          _intValue(json['respiratoryRate']),
      notes: json['notes'] as String?,
    );
  }
}

class MyClubTransaction {
  const MyClubTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.points,
    required this.type,
    this.referenceType,
    this.referenceId,
  });

  final int id;
  final String date;
  final String description;
  final int points;
  final String type;
  final String? referenceType;
  final String? referenceId;

  factory MyClubTransaction.fromJson(Map<String, dynamic> json) {
    return MyClubTransaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      description: json['description'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'earn',
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
    );
  }
}

class ReferralRelationship {
  const ReferralRelationship({
    required this.id,
    required this.patientId,
    required this.name,
    required this.patientNumber,
    required this.status,
    this.attributedAt,
    this.verifiedAt,
    this.qualifiedAt,
    this.rewardedAt,
  });

  final int id;
  final int patientId;
  final String name;
  final String patientNumber;
  final String status;
  final String? attributedAt;
  final String? verifiedAt;
  final String? qualifiedAt;
  final String? rewardedAt;

  factory ReferralRelationship.fromJson(Map<String, dynamic> json) {
    return ReferralRelationship(
      id: (json['id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'BHRC Patient',
      patientNumber: json['patient_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'attributed',
      attributedAt: json['attributed_at']?.toString(),
      verifiedAt: json['verified_at']?.toString(),
      qualifiedAt: json['qualified_at']?.toString(),
      rewardedAt: json['rewarded_at']?.toString(),
    );
  }
}

class ReferralStats {
  const ReferralStats({
    this.invited = 0,
    this.verified = 0,
    this.rewarded = 0,
    this.pointsEarned = 0,
  });

  final int invited;
  final int verified;
  final int rewarded;
  final int pointsEarned;

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      invited: (json['invited'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      rewarded: (json['rewarded'] as num?)?.toInt() ?? 0,
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReferralRewardTerms {
  const ReferralRewardTerms({
    this.referrerPoints = 0,
    this.newPatientPoints = 0,
    this.qualification = '',
  });

  final int referrerPoints;
  final int newPatientPoints;
  final String qualification;

  factory ReferralRewardTerms.fromJson(Map<String, dynamic> json) {
    return ReferralRewardTerms(
      referrerPoints: (json['referrer_points'] as num?)?.toInt() ?? 0,
      newPatientPoints: (json['new_patient_points'] as num?)?.toInt() ?? 0,
      qualification: json['qualification']?.toString() ?? '',
    );
  }
}

class ReferralSummary {
  const ReferralSummary({
    this.code = '',
    this.shareUrl = '',
    this.invitedBy,
    this.invitedUsers = const [],
    this.stats = const ReferralStats(),
    this.rewardTerms = const ReferralRewardTerms(),
  });

  final String code;
  final String shareUrl;
  final ReferralRelationship? invitedBy;
  final List<ReferralRelationship> invitedUsers;
  final ReferralStats stats;
  final ReferralRewardTerms rewardTerms;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final invitedBy = json['invited_by'];
    final invitedUsers = json['invited_users'] as List<dynamic>? ?? const [];
    return ReferralSummary(
      code: json['code']?.toString() ?? '',
      shareUrl: json['share_url']?.toString() ?? '',
      invitedBy: invitedBy is Map
          ? ReferralRelationship.fromJson(Map<String, dynamic>.from(invitedBy))
          : null,
      invitedUsers: invitedUsers
          .whereType<Map>()
          .map(
            (item) =>
                ReferralRelationship.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      stats: ReferralStats.fromJson(_map(json['stats'])),
      rewardTerms: ReferralRewardTerms.fromJson(_map(json['reward_terms'])),
    );
  }
}

class ReferralCodeResolution {
  const ReferralCodeResolution({
    required this.code,
    required this.inviterName,
    required this.inviterPatientNumber,
  });

  final String code;
  final String inviterName;
  final String inviterPatientNumber;

  factory ReferralCodeResolution.fromJson(Map<String, dynamic> json) {
    final inviter = _map(json['inviter']);
    return ReferralCodeResolution(
      code: json['code']?.toString() ?? '',
      inviterName: inviter['name']?.toString() ?? 'BHRC Patient',
      inviterPatientNumber: inviter['patient_number']?.toString() ?? '',
    );
  }
}

class MyClubLeaderboardEntry {
  const MyClubLeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.lifetimePoints,
    required this.level,
    required this.levelColor,
    required this.isCurrentPatient,
  });

  final int rank;
  final String displayName;
  final int lifetimePoints;
  final String level;
  final String levelColor;
  final bool isCurrentPatient;

  factory MyClubLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return MyClubLeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      displayName: json['display_name']?.toString() ?? 'BHRC Member',
      lifetimePoints: (json['lifetime_points'] as num?)?.toInt() ?? 0,
      level: json['level']?.toString() ?? 'Member',
      levelColor: json['level_color']?.toString() ?? '#64748B',
      isCurrentPatient: json['is_current_patient'] == true,
    );
  }
}

class MyClubSummary {
  const MyClubSummary({
    required this.patientId,
    required this.points,
    required this.currencyValue,
    required this.tier,
    required this.transactions,
    this.nextTierName,
    this.pointsToNextTier = 0,
    this.progressPercent = 0,
    this.redemptionEnabled = false,
    this.redemptionRatePoints = 100,
    this.redemptionRateCurrency = 10,
    this.pointsExpiryMonths = 0,
    this.benefits = const [],
    this.levelName = 'Member',
    this.levelColor = '#64748B',
    this.lifetimePoints = 0,
    this.leaderboardRank = 0,
    this.leaderboard = const [],
    this.currentLeaderboardEntry,
    this.leaderboardPrivacyNote = '',
    this.referrals = const ReferralSummary(),
  });

  final int patientId;
  final int points;
  final double currencyValue;
  final String tier;
  final List<MyClubTransaction> transactions;
  final String? nextTierName;
  final int pointsToNextTier;
  final int progressPercent;
  final bool redemptionEnabled;
  final int redemptionRatePoints;
  final int redemptionRateCurrency;
  final int pointsExpiryMonths;
  final List<String> benefits;
  final String levelName;
  final String levelColor;
  final int lifetimePoints;
  final int leaderboardRank;
  final List<MyClubLeaderboardEntry> leaderboard;
  final MyClubLeaderboardEntry? currentLeaderboardEntry;
  final String leaderboardPrivacyNote;
  final ReferralSummary referrals;

  factory MyClubSummary.fromJson(Map<String, dynamic> json) {
    final membership = _map(json['membership']);
    final gamification = _map(json['gamification']);
    final level = _map(gamification['level']);
    final transactionJson = json['transactions'] as List<dynamic>? ?? const [];
    final benefitsJson = json['benefits'] as List<dynamic>? ?? const [];
    final leaderboardJson =
        gamification['leaderboard'] as List<dynamic>? ?? const [];
    final currentLeaderboard = gamification['current_patient'];
    final pointsBalance = json['pointsBalance'] ?? json['points_balance'];
    return MyClubSummary(
      patientId:
          (json['patientId'] as num?)?.toInt() ??
          (membership['patientId'] as num?)?.toInt() ??
          (membership['patient_id'] as num?)?.toInt() ??
          0,
      points:
          (json['points'] as num?)?.toInt() ??
          (pointsBalance as num?)?.toInt() ??
          0,
      currencyValue:
          (json['currencyValue'] as num?)?.toDouble() ??
          (json['currency_value'] as num?)?.toDouble() ??
          0,
      tier:
          json['tier'] as String? ??
          membership['tier'] as String? ??
          membership['name'] as String? ??
          'Classic',
      nextTierName: json['nextTierName'] as String?,
      pointsToNextTier: (json['pointsToNextTier'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      redemptionEnabled: json['redemptionEnabled'] as bool? ?? false,
      redemptionRatePoints:
          (json['redemptionRatePoints'] as num?)?.toInt() ?? 100,
      redemptionRateCurrency:
          (json['redemptionRateCurrency'] as num?)?.toInt() ?? 10,
      pointsExpiryMonths: (json['pointsExpiryMonths'] as num?)?.toInt() ?? 0,
      transactions: transactionJson
          .map((item) => MyClubTransaction.fromJson(_map(item)))
          .toList(),
      benefits: benefitsJson.map((item) => item.toString()).toList(),
      levelName:
          level['name']?.toString() ??
          json['levelName']?.toString() ??
          'Member',
      levelColor: level['color']?.toString() ?? '#64748B',
      lifetimePoints:
          (gamification['lifetime_points'] as num?)?.toInt() ??
          (json['lifetimePoints'] as num?)?.toInt() ??
          0,
      leaderboardRank:
          (gamification['rank'] as num?)?.toInt() ??
          (json['leaderboardRank'] as num?)?.toInt() ??
          0,
      leaderboard: leaderboardJson
          .whereType<Map>()
          .map(
            (item) => MyClubLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      currentLeaderboardEntry: currentLeaderboard is Map
          ? MyClubLeaderboardEntry.fromJson(
              Map<String, dynamic>.from(currentLeaderboard),
            )
          : null,
      leaderboardPrivacyNote: gamification['privacy_note']?.toString() ?? '',
      referrals: ReferralSummary.fromJson(_map(json['referrals'])),
    );
  }
}

class FamilyMember {
  const FamilyMember({
    required this.linkId,
    required this.patientId,
    required this.name,
    required this.relationship,
    required this.canBookAppointments,
    this.gender,
    this.dateOfBirth,
    this.age,
    this.cardNumber,
    this.status = 'active',
  });

  final int linkId;
  final int patientId;
  final String name;
  final String relationship;
  final bool canBookAppointments;
  final String? gender;
  final String? dateOfBirth;
  final int? age;
  final String? cardNumber;
  final String status;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final permissions = _map(json['permissions']);
    return FamilyMember(
      linkId: (json['link_id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Family member',
      relationship: json['relationship'] as String? ?? 'family',
      canBookAppointments:
          permissions['book_appointments'] as bool? ??
          json['can_book_appointments'] as bool? ??
          true,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      age: (json['age'] as num?)?.toInt(),
      cardNumber: json['card_number'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }
}

class HomeCareServiceItem {
  const HomeCareServiceItem({
    required this.id,
    required this.name,
    required this.basePrice,
    this.code,
    this.description,
    this.durationMinutes,
    this.requiresAddress = true,
  });

  final int id;
  final String name;
  final double basePrice;
  final String? code;
  final String? description;
  final int? durationMinutes;
  final bool requiresAddress;

  factory HomeCareServiceItem.fromJson(Map<String, dynamic> json) {
    return HomeCareServiceItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name:
          json['name'] as String? ??
          json['service_name'] as String? ??
          'Home care',
      code: json['code'] as String? ?? json['service_code'] as String?,
      description: json['description'] as String?,
      basePrice:
          (json['base_price'] as num?)?.toDouble() ??
          double.tryParse(json['base_price']?.toString() ?? '') ??
          0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      requiresAddress: json['requires_address'] as bool? ?? true,
    );
  }
}

class HomeCareBookingItem {
  const HomeCareBookingItem({
    required this.id,
    required this.bookingNumber,
    required this.serviceName,
    required this.preferredDate,
    required this.status,
    this.timeSlot,
    this.notes,
    this.paymentStatus,
    this.createdAt,
  });

  final int id;
  final String bookingNumber;
  final String serviceName;
  final String preferredDate;
  final String status;
  final String? timeSlot;
  final String? notes;
  final String? paymentStatus;
  final String? createdAt;

  factory HomeCareBookingItem.fromJson(Map<String, dynamic> json) {
    return HomeCareBookingItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bookingNumber: json['booking_number'] as String? ?? 'HCB',
      serviceName: json['service'] as String? ?? 'Home care',
      preferredDate: json['preferred_date'] as String? ?? '',
      timeSlot: json['time_slot'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['payment_status'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class HomeCareBookingInput {
  const HomeCareBookingInput({
    required this.serviceId,
    required this.preferredDate,
    this.patientId,
    this.timeSlot,
    this.addressLine,
    this.landmark,
    this.notes,
  });

  final int serviceId;
  final String preferredDate;
  final int? patientId;
  final String? timeSlot;
  final String? addressLine;
  final String? landmark;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'service_id': serviceId,
      if (patientId != null) 'patient_id': patientId,
      'preferred_date': preferredDate,
      if ((timeSlot ?? '').trim().isNotEmpty)
        'preferred_time_slot': timeSlot!.trim(),
      if ((addressLine ?? '').trim().isNotEmpty)
        'address': {
          'line1': addressLine!.trim(),
          if ((landmark ?? '').trim().isNotEmpty) 'landmark': landmark!.trim(),
        },
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

class IdCardInfo {
  const IdCardInfo({
    required this.registrationNumber,
    required this.patientName,
    required this.membershipTier,
    required this.qrValue,
    this.bloodGroup,
    this.barcodeValue = '',
    this.memberSince,
    this.counterHint =
        'Show this card at the hospital counter for faster check-in.',
  });

  final String registrationNumber;
  final String patientName;
  final String membershipTier;
  final String qrValue;
  final String? bloodGroup;
  final String barcodeValue;
  final String? memberSince;
  final String counterHint;

  factory IdCardInfo.fromJson(Map<String, dynamic> json) {
    return IdCardInfo(
      registrationNumber: json['registrationNumber'] as String? ?? 'BHRC',
      patientName: json['patientName'] as String? ?? 'Patient',
      membershipTier: json['membershipTier'] as String? ?? 'Classic',
      qrValue: json['qrValue'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String?,
      barcodeValue: json['barcodeValue'] as String? ?? '',
      memberSince: json['memberSince'] as String?,
      counterHint:
          json['counterHint'] as String? ??
          'Show this card at the hospital counter for faster check-in.',
    );
  }
}

class EmergencyContact {
  const EmergencyContact({required this.name, required this.number});

  final String name;
  final String number;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String? ?? 'Contact',
      number: json['number'] as String? ?? '',
    );
  }
}

class HomeBannerItem {
  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.ctaLabel,
    this.ctaTarget,
    this.sortOrder = 0,
    this.isActive = true,
    this.placement = 'home_carousel',
  });

  final int id;
  final String title;
  final String imageUrl;
  final String? subtitle;
  final String? ctaLabel;
  final String? ctaTarget;
  final int sortOrder;
  final bool isActive;
  final String placement;

  bool get isMobilePromoPopup => placement == 'mobile_promo_popup';

  factory HomeBannerItem.fromJson(Map<String, dynamic> json) {
    return HomeBannerItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Health update',
      imageUrl:
          json['imageUrl'] as String? ?? json['image_url'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      ctaLabel: json['ctaLabel'] as String? ?? json['cta_label'] as String?,
      ctaTarget: json['ctaTarget'] as String? ?? json['cta_target'] as String?,
      sortOrder:
          (json['sortOrder'] as num?)?.toInt() ??
          (json['sort_order'] as num?)?.toInt() ??
          0,
      isActive:
          json['isActive'] as bool? ??
          json['is_active'] == 1 || json['is_active'] == true,
      placement:
          json['placement'] as String? ??
          json['bannerPlacement'] as String? ??
          json['banner_placement'] as String? ??
          'home_carousel',
    );
  }
}

class DoctorSchedule {
  const DoctorSchedule({
    required this.id,
    required this.dayOfWeek,
    required this.sessionName,
    required this.startTime,
    required this.endTime,
  });

  final int id;
  final String dayOfWeek;
  final String sessionName;
  final String startTime;
  final String endTime;

  factory DoctorSchedule.fromJson(Map<String, dynamic> json) {
    return DoctorSchedule(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dayOfWeek: json['day_of_week'] as String? ?? '',
      sessionName: json['session_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
    );
  }
}

class DoctorSlotAvailability {
  const DoctorSlotAvailability({
    required this.slot,
    required this.bookedCount,
    required this.capacity,
    required this.remainingCapacity,
    required this.isAvailable,
  });

  final String slot;
  final int bookedCount;
  final int capacity;
  final int remainingCapacity;
  final bool isAvailable;

  factory DoctorSlotAvailability.fromJson(Map<String, dynamic> json) {
    final capacity = (json['capacity'] as num?)?.toInt() ?? 2;
    final bookedCount = (json['bookedCount'] as num?)?.toInt() ?? 0;
    return DoctorSlotAvailability(
      slot: json['slot'] as String? ?? '',
      bookedCount: bookedCount,
      capacity: capacity,
      remainingCapacity:
          (json['remainingCapacity'] as num?)?.toInt() ??
          (capacity - bookedCount).clamp(0, capacity),
      isAvailable: json['isAvailable'] as bool? ?? bookedCount < capacity,
    );
  }

  factory DoctorSlotAvailability.available(String slot, {int capacity = 2}) {
    return DoctorSlotAvailability(
      slot: slot,
      bookedCount: 0,
      capacity: capacity,
      remainingCapacity: capacity,
      isAvailable: true,
    );
  }
}

class DoctorListing {
  const DoctorListing({
    required this.id,
    required this.name,
    required this.specialization,
    this.qualifications,
    this.availableTime,
    this.availableDates,
    this.workingDays,
    this.workStartTime,
    this.workEndTime,
    this.slotDurationMinutes,
    this.departmentName,
    this.email,
    this.phone,
    this.registrationNumber,
    this.imageUrl,
    this.description,
    this.consultationFee,
    this.schedules = const [],
  });

  final int id;
  final String name;
  final String specialization;
  final String? qualifications;
  final String? availableTime;
  final String? availableDates;
  final String? workingDays;
  final String? workStartTime;
  final String? workEndTime;
  final int? slotDurationMinutes;
  final String? departmentName;
  final String? email;
  final String? phone;
  final String? registrationNumber;
  final String? imageUrl;
  final String? description;
  final int? consultationFee;
  final List<DoctorSchedule> schedules;

  factory DoctorListing.fromJson(Map<String, dynamic> json) {
    final schedulesRaw = json['schedules'] as List<dynamic>? ?? const [];
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      if (v is String) return double.tryParse(v)?.round();
      return null;
    }

    return DoctorListing(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Doctor',
      specialization: json['specialization'] as String? ?? 'General',
      qualifications:
          json['qualifications'] as String? ?? json['qualification'] as String?,
      availableTime:
          json['availableTime'] as String? ?? json['available_time'] as String?,
      availableDates: json['availableDates'] as String?,
      workingDays: json['workingDays'] as String?,
      workStartTime: json['workStartTime'] as String?,
      workEndTime: json['workEndTime'] as String?,
      slotDurationMinutes: (json['slotDurationMinutes'] as num?)?.toInt(),
      departmentName:
          json['departmentName'] as String? ??
          json['department_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      registrationNumber:
          json['registrationNumber'] as String? ??
          json['registration_number'] as String?,
      imageUrl:
          json['imageUrl'] as String? ??
          json['image_url'] as String? ??
          json['profile_photo_url'] as String?,
      description: json['description'] as String?,
      consultationFee:
          (json['consultationFee'] as num?)?.toInt() ??
          parseInt(json['consultation_fee']),
      schedules: schedulesRaw
          .map((item) => DoctorSchedule.fromJson(_map(item)))
          .toList(),
    );
  }

  String get availabilityWindowLabel {
    final start = workStartTime?.trim();
    final end = workEndTime?.trim();
    if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
      return '${formatTimeLabel(start)} - ${formatTimeLabel(end)}';
    }

    final fallback = availableTime?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;

    if (schedules.isNotEmpty) {
      final first = schedules.first;
      return '${formatTimeLabel(first.startTime)} - ${formatTimeLabel(first.endTime)}';
    }

    return 'Contact hospital for timings';
  }

  static String formatTimeLabel(String value) {
    if (value.toLowerCase().contains('am') ||
        value.toLowerCase().contains('pm')) {
      return value;
    }

    final parts = value.split(':');
    if (parts.length < 2) return value;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;

    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}

class DepartmentItem {
  const DepartmentItem({required this.id, required this.name, this.imageUrl});

  final int id;
  final String name;
  final String? imageUrl;

  factory DepartmentItem.fromJson(Map<String, dynamic> json) {
    return DepartmentItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.id,
    this.createdAt,
    this.attachments = const [],
    this.suggestedPackages = const [],
    this.suggestedTests = const [],
    this.action,
  });

  final int? id;
  final String role;
  final String content;
  final String? createdAt;
  final List<ChatAttachment> attachments;
  final List<LabPackageItem> suggestedPackages;
  final List<LabTestItem> suggestedTests;
  final ChatAssistantAction? action;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Documented chat endpoints expose the body under `message`; older payloads
    // (and locally-built messages) use `content`.
    final rawContent =
        json['content'] as String? ?? json['message'] as String? ?? '';
    final parsed = ChatMessageCodec.decode(rawContent);
    final pkgsRaw = json['suggestedPackages'] as List<dynamic>? ?? const [];
    final testsRaw = json['suggestedTests'] as List<dynamic>? ?? const [];
    final actionRaw = json['action'];
    return ChatMessage(
      id: (json['id'] as num?)?.toInt(),
      role: json['role'] as String? ?? 'assistant',
      content: parsed.content,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      attachments: parsed.attachments,
      suggestedPackages: pkgsRaw
          .map(
            (item) => LabPackageItem.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      suggestedTests: testsRaw
          .map(
            (item) => LabTestItem.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      action: actionRaw is Map
          ? ChatAssistantAction.fromJson(_map(actionRaw))
          : null,
    );
  }

  String toWireContent() {
    return ChatMessageCodec.encode(content: content, attachments: attachments);
  }
}

class ChatAssistantAction {
  const ChatAssistantAction({
    required this.intent,
    required this.state,
    required this.urgency,
    required this.outcome,
    this.sourceSessionToken,
    this.supportRequired = false,
    this.bookingCreated = false,
    this.bookingId,
    this.bookingNumber,
    this.recommendedDoctors = const [],
    this.customPackage,
  });

  final String intent;
  final String state;
  final String urgency;
  final String outcome;
  final String? sourceSessionToken;
  final bool supportRequired;
  final bool bookingCreated;
  final int? bookingId;
  final String? bookingNumber;
  final List<ChatDoctorRecommendation> recommendedDoctors;
  final ChatCustomPackage? customPackage;

  bool get isAdviceOnly =>
      intent == 'advice' && urgency != 'emergency' && !supportRequired;

  factory ChatAssistantAction.fromJson(Map<String, dynamic> json) {
    final doctors = json['recommended_doctors'] as List<dynamic>? ?? const [];
    final custom = json['custom_package'];
    return ChatAssistantAction(
      intent: json['intent']?.toString() ?? 'advice',
      state: json['state']?.toString() ?? 'completed',
      urgency: json['urgency']?.toString() ?? 'routine',
      outcome: json['outcome']?.toString() ?? 'advice_only',
      sourceSessionToken: json['source_session_token']?.toString(),
      supportRequired: json['support_required'] as bool? ?? false,
      bookingCreated: json['booking_created'] as bool? ?? false,
      bookingId: (json['booking_id'] as num?)?.toInt(),
      bookingNumber: json['booking_number']?.toString(),
      recommendedDoctors: doctors
          .map((item) => ChatDoctorRecommendation.fromJson(_map(item)))
          .toList(),
      customPackage: custom is Map
          ? ChatCustomPackage.fromJson(_map(custom))
          : null,
    );
  }
}

class ChatDoctorRecommendation {
  const ChatDoctorRecommendation({
    required this.id,
    required this.name,
    this.specialization,
    this.consultationFee,
    this.reason,
  });

  final int id;
  final String name;
  final String? specialization;
  final String? consultationFee;
  final String? reason;

  factory ChatDoctorRecommendation.fromJson(Map<String, dynamic> json) {
    return ChatDoctorRecommendation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Doctor',
      specialization: json['specialization']?.toString(),
      consultationFee: json['consultation_fee']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

class ChatCustomPackage {
  const ChatCustomPackage({
    required this.name,
    required this.testIds,
    this.id,
    this.draftToken,
    this.reason,
    this.price,
    this.status = 'draft',
    this.validUntil,
  });

  final int? id;
  final String? draftToken;
  final String name;
  final String? reason;
  final String? price;
  final String status;
  final DateTime? validUntil;
  final List<int> testIds;

  factory ChatCustomPackage.fromJson(Map<String, dynamic> json) {
    final tests = json['tests'] as List<dynamic>? ?? const [];
    return ChatCustomPackage(
      id: (json['id'] as num?)?.toInt(),
      draftToken: json['draft_token']?.toString(),
      name: json['name']?.toString() ?? 'Custom health package',
      reason: json['reason']?.toString(),
      price: json['price']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      validUntil: DateTime.tryParse(json['valid_until']?.toString() ?? ''),
      testIds: tests
          .map((item) => (_map(item)['id'] as num?)?.toInt() ?? 0)
          .where((id) => id > 0)
          .toList(),
    );
  }
}

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.url,
    this.mimeType,
    this.sizeBytes,
  });

  final String name;
  final String url;
  final String? mimeType;
  final int? sizeBytes;

  bool get isImage {
    final byType = (mimeType ?? '').toLowerCase();
    if (byType.startsWith('image/')) return true;

    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      if ((mimeType ?? '').isNotEmpty) 'mimeType': mimeType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
    };
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      name: json['name'] as String? ?? 'Attachment',
      url: json['url'] as String? ?? '',
      mimeType: json['mimeType'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    );
  }
}

class ChatMessagePayload {
  const ChatMessagePayload({required this.content, required this.attachments});

  final String content;
  final List<ChatAttachment> attachments;
}

class ChatMessageCodec {
  static const _prefix = '[[BHX_ATTACHMENT:';
  static const _suffix = ':BHX_ATTACHMENT]]';

  static String encode({
    required String content,
    List<ChatAttachment> attachments = const [],
  }) {
    final trimmed = content.trim();
    if (attachments.isEmpty) return trimmed;

    final payload = jsonEncode({
      'attachments': attachments.map((item) => item.toJson()).toList(),
    });
    final encoded = base64UrlEncode(utf8.encode(payload));
    return '$_prefix$encoded$_suffix\n$trimmed';
  }

  static ChatMessagePayload decode(String raw) {
    final text = raw.trim();
    if (!text.startsWith(_prefix)) {
      return ChatMessagePayload(content: raw, attachments: const []);
    }

    final suffixIndex = text.indexOf(_suffix);
    if (suffixIndex < 0) {
      return ChatMessagePayload(content: raw, attachments: const []);
    }

    final encoded = text.substring(_prefix.length, suffixIndex);
    try {
      final decoded = utf8.decode(base64Url.decode(encoded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final list = json['attachments'] as List<dynamic>? ?? const [];
      final attachments = list
          .map((item) => ChatAttachment.fromJson(_map(item)))
          .toList();
      final content = text.substring(suffixIndex + _suffix.length).trim();
      return ChatMessagePayload(content: content, attachments: attachments);
    } catch (_) {
      return ChatMessagePayload(content: raw, attachments: const []);
    }
  }
}

class ChatThreadSummary {
  const ChatThreadSummary({
    required this.id,
    required this.title,
    this.messageCount = 0,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final int messageCount;
  final String? lastMessagePreview;
  final String? lastMessageAt;
  final String? createdAt;
  final String? updatedAt;

  factory ChatThreadSummary.fromJson(Map<String, dynamic> json) {
    return ChatThreadSummary(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'New chat',
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      lastMessagePreview:
          json['lastMessagePreview'] as String? ??
          json['last_message_preview'] as String?,
      lastMessageAt:
          json['lastMessageAt'] as String? ??
          json['last_message_at'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      updatedAt: json['updatedAt'] as String? ?? json['updated_at'] as String?,
    );
  }
}

class BodyPointItem {
  const BodyPointItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageX,
    required this.imageY,
    required this.status,
  });

  final int id;
  final String name;
  final String slug;
  final int imageX;
  final int imageY;
  final bool status;

  factory BodyPointItem.fromJson(Map<String, dynamic> json) {
    return BodyPointItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      imageX:
          (json['imageX'] as num?)?.toInt() ??
          (json['image_x'] as num?)?.toInt() ??
          0,
      imageY:
          (json['imageY'] as num?)?.toInt() ??
          (json['image_y'] as num?)?.toInt() ??
          0,
      status: json['status'] == 1 || json['status'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'imageX': imageX,
      'imageY': imageY,
      'status': status,
    };
  }
}

class LabTestItem {
  const LabTestItem({
    required this.id,
    required this.testName,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    required this.basePrice,
    this.bodyPoints = const [],
    this.discountedPrice,
    this.uuid,
    this.imageUrl,
    this.instructions,
    this.resultEta,
  });

  final int id;
  final String testName;
  final int categoryId;
  final String categoryName;
  final bool status;
  final double basePrice;
  final List<BodyPointItem> bodyPoints;
  final double? discountedPrice;
  final String? uuid;
  final String? imageUrl;
  final String? instructions;
  final String? resultEta;

  factory LabTestItem.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final bodyPointsRaw = json['bodyPoints'] as List<dynamic>? ?? const [];
    bool parseStatus(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final normalized = v.trim().toLowerCase();
        return normalized == 'active' ||
            normalized == 'true' ||
            normalized == '1';
      }
      return true;
    }

    final bodyPointsList = bodyPointsRaw
        .map(
          (item) => BodyPointItem.fromJson(
            item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    return LabTestItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      testName:
          json['testName'] as String? ??
          json['test_name'] as String? ??
          'Lab test',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      categoryName:
          json['categoryName'] as String? ??
          json['category'] as String? ??
          'General',
      status: parseStatus(json['status']),
      basePrice: parseDbl(
        json['basePrice'] ?? json['base_price'] ?? json['price'],
      ),
      bodyPoints: bodyPointsList,
      discountedPrice:
          json['discountedPrice'] != null || json['discounted_price'] != null
          ? parseDbl(json['discountedPrice'] ?? json['discounted_price'])
          : null,
      uuid: json['uuid'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      instructions:
          json['instructions'] as String? ?? json['description'] as String?,
      resultEta: json['resultEta'] as String? ?? json['result_eta'] as String?,
    );
  }
}

class LabOrderItem {
  const LabOrderItem({
    required this.id,
    required this.date,
    required this.status,
    required this.testId,
    required this.testName,
    required this.doctorId,
    required this.doctorName,
    this.bookingRef,
    this.slot,
    this.collectionType,
    this.address,
    this.amount,
    this.paymentStatus,
    this.patientName,
    this.patientPhone,
    this.patientAge,
    this.patientGender,
    this.testInstructions,
    this.resultEta,
    this.urgency,
    this.notes,
    this.categoryName,
    this.createdAt,
  });

  final int id;
  final String date;
  final String status;
  final int testId;
  final String testName;
  final int doctorId;
  final String doctorName;
  final String? bookingRef;
  final String? slot;
  final String? collectionType;
  final String? address;
  final double? amount;
  final String? paymentStatus;
  final String? patientName;
  final String? patientPhone;
  final int? patientAge;
  final String? patientGender;
  final String? testInstructions;
  final String? resultEta;
  final String? urgency;
  final String? notes;
  final String? categoryName;
  final String? createdAt;

  factory LabOrderItem.fromJson(Map<String, dynamic> json) {
    return LabOrderItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      testId: (json['testId'] as num?)?.toInt() ?? 0,
      testName: json['testName'] as String? ?? 'Lab test',
      doctorId: (json['doctorId'] as num?)?.toInt() ?? 0,
      doctorName: json['doctorName'] as String? ?? 'BHRC Doctor',
      bookingRef:
          json['bookingRef'] as String? ?? json['booking_ref'] as String?,
      slot: json['slot'] as String?,
      collectionType:
          json['collectionType'] as String? ??
          json['collection_type'] as String?,
      address: json['address'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      paymentStatus:
          json['paymentStatus'] as String? ?? json['payment_status'] as String?,
      patientName:
          json['patientNameSnapshot'] as String? ??
          json['patient_name_snapshot'] as String? ??
          json['patientName'] as String? ??
          json['patient_name'] as String?,
      patientPhone:
          json['patientPhoneSnapshot'] as String? ??
          json['patient_phone_snapshot'] as String? ??
          json['patientPhone'] as String? ??
          json['patient_phone'] as String?,
      patientAge:
          (json['patientAgeSnapshot'] as num?)?.toInt() ??
          (json['patient_age_snapshot'] as num?)?.toInt(),
      patientGender:
          json['patientGenderSnapshot'] as String? ??
          json['patient_gender_snapshot'] as String?,
      testInstructions:
          json['testInstructions'] as String? ??
          json['test_instructions'] as String?,
      resultEta: json['resultEta'] as String? ?? json['result_eta'] as String?,
      urgency: json['urgency'] as String?,
      notes: json['notes'] as String?,
      categoryName: json['categoryName'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

class LabPackageItem {
  const LabPackageItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.basePrice,
    this.packageCode,
    this.description,
    this.category,
    this.imageUrl,
    this.instructions,
    this.resultEta,
    this.totalTests,
    this.discountedPrice,
    this.includedTests = const [],
  });

  final int id;
  final String name;
  final String slug;
  final String? packageCode;
  final bool status;
  final int basePrice;
  final String? description;
  final String? category;
  final String? imageUrl;
  final String? instructions;
  final String? resultEta;
  final int? totalTests;
  final int? discountedPrice;
  final List<String> includedTests;

  bool matchesTarget(String rawTarget) {
    final target = rawTarget.trim().toLowerCase();
    if (target.isEmpty) return false;

    return slug.trim().toLowerCase() == target ||
        (packageCode ?? '').trim().toLowerCase() == target ||
        id.toString() == target ||
        name.trim().toLowerCase() == target;
  }

  factory LabPackageItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return double.tryParse(v)?.round() ?? 0;
      return 0;
    }

    bool parseStatus(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final normalized = v.trim().toLowerCase();
        return normalized == 'active' ||
            normalized == 'true' ||
            normalized == '1';
      }
      return true;
    }

    final includedRaw =
        json['includedTests'] as List<dynamic>? ??
        json['tests'] as List<dynamic>? ??
        const [];
    final rawStatus = json['status'];
    return LabPackageItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name:
          json['name'] as String? ??
          json['package_name'] as String? ??
          'Health package',
      slug: json['slug'] as String? ?? json['package_code'] as String? ?? '',
      packageCode:
          json['packageCode'] as String? ?? json['package_code'] as String?,
      status: parseStatus(rawStatus),
      basePrice: parseInt(
        json['basePrice'] ?? json['base_price'] ?? json['price'],
      ),
      description: json['description'] as String?,
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      instructions: json['instructions'] as String?,
      resultEta: json['resultEta'] as String? ?? json['result_eta'] as String?,
      totalTests:
          (json['totalTests'] as num?)?.toInt() ??
          (json['test_count'] as num?)?.toInt(),
      discountedPrice:
          json['discountedPrice'] != null || json['discounted_price'] != null
          ? parseInt(json['discountedPrice'] ?? json['discounted_price'])
          : null,
      includedTests: includedRaw
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item['testName'] as String? ??
                  item['test_name'] as String? ??
                  '';
            }
            if (item is Map) {
              return item['testName']?.toString() ??
                  item['test_name']?.toString() ??
                  '';
            }
            return item.toString();
          })
          .where((name) => name.trim().isNotEmpty)
          .toList(),
    );
  }
}

class LabPackageOrderItem {
  const LabPackageOrderItem({
    required this.id,
    required this.date,
    required this.status,
    required this.packageId,
    required this.packageName,
    required this.doctorId,
    required this.doctorName,
    this.bookingRef,
    this.slot,
    this.collectionType,
    this.address,
    this.amount,
    this.paymentStatus,
    this.patientName,
    this.patientPhone,
    this.patientAge,
    this.patientGender,
    this.packageResultEta,
    this.urgency,
    this.notes,
    this.packageCategory,
    this.createdAt,
  });

  final int id;
  final String date;
  final String status;
  final int packageId;
  final String packageName;
  final int doctorId;
  final String doctorName;
  final String? bookingRef;
  final String? slot;
  final String? collectionType;
  final String? address;
  final double? amount;
  final String? paymentStatus;
  final String? patientName;
  final String? patientPhone;
  final int? patientAge;
  final String? patientGender;
  final String? packageResultEta;
  final String? urgency;
  final String? notes;
  final String? packageCategory;
  final String? createdAt;

  factory LabPackageOrderItem.fromJson(Map<String, dynamic> json) {
    return LabPackageOrderItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      packageId: (json['packageId'] as num?)?.toInt() ?? 0,
      packageName: json['packageName'] as String? ?? 'Health package',
      doctorId: (json['doctorId'] as num?)?.toInt() ?? 0,
      doctorName: json['doctorName'] as String? ?? 'BHRC Doctor',
      bookingRef:
          json['bookingRef'] as String? ?? json['booking_ref'] as String?,
      slot: json['slot'] as String?,
      collectionType:
          json['collectionType'] as String? ??
          json['collection_type'] as String?,
      address: json['address'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      paymentStatus:
          json['paymentStatus'] as String? ?? json['payment_status'] as String?,
      patientName:
          json['patientNameSnapshot'] as String? ??
          json['patient_name_snapshot'] as String? ??
          json['patientName'] as String? ??
          json['patient_name'] as String?,
      patientPhone:
          json['patientPhoneSnapshot'] as String? ??
          json['patient_phone_snapshot'] as String? ??
          json['patientPhone'] as String? ??
          json['patient_phone'] as String?,
      patientAge:
          (json['patientAgeSnapshot'] as num?)?.toInt() ??
          (json['patient_age_snapshot'] as num?)?.toInt(),
      patientGender:
          json['patientGenderSnapshot'] as String? ??
          json['patient_gender_snapshot'] as String?,
      packageResultEta:
          json['packageResultEta'] as String? ??
          json['package_result_eta'] as String?,
      urgency: json['urgency'] as String?,
      notes: json['notes'] as String?,
      packageCategory: json['packageCategory'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

class DocumentAnalysisResult {
  const DocumentAnalysisResult({
    required this.success,
    required this.summary,
    required this.texts,
    this.status,
    this.analysisId,
    this.riskLevel,
    this.riskReason,
    this.findings = const [],
    this.recommendations = const [],
    this.cached = false,
  });

  final bool success;
  final String summary;
  final List<String> texts;
  final String? status;
  final int? analysisId;
  final String? riskLevel;
  final String? riskReason;
  final List<String> findings;
  final List<String> recommendations;
  final bool cached;

  factory DocumentAnalysisResult.fromJson(Map<String, dynamic> json) {
    final texts = _stringList(json['texts']);
    final findings = _findingList(json['findings']);
    final recommendations = _stringList(json['recommendations']);
    return DocumentAnalysisResult(
      success: json['success'] as bool? ?? true,
      summary: json['summary'] as String? ?? '',
      texts: texts,
      status: json['status']?.toString(),
      analysisId: (json['analysisId'] as num?)?.toInt(),
      riskLevel: json['riskLevel'] as String? ?? json['risk_level'] as String?,
      riskReason:
          json['riskReason'] as String? ?? json['risk_reason'] as String?,
      findings: findings,
      recommendations: recommendations,
      cached: json['cached'] as bool? ?? false,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _findingList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString().trim() ?? '';
            final value = item['value']?.toString().trim() ?? '';
            final status = item['status']?.toString().trim() ?? '';
            return [
              if (name.isNotEmpty) name,
              if (value.isNotEmpty) value,
              if (status.isNotEmpty) '($status)',
            ].join(' ');
          }
          return item?.toString().trim() ?? '';
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

/// A single timestamped health-profile snapshot.
///
/// Mirrors the `/patients/me/health-profile` API contract. The API exposes
/// snake_case fields; camelCase fallbacks are kept for resilience.
class HealthProfileSnapshot {
  const HealthProfileSnapshot({
    required this.id,
    required this.recordedAt,
    required this.source,
    this.chronicConditions = const [],
    this.currentMedications = const [],
    this.allergies = const [],
    this.symptoms,
    this.lifestyleNotes,
    this.notes,
  });

  final int id;
  final String recordedAt;

  /// `self_reported`, `assessment_derived`, or `document_derived`.
  final String source;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final List<String> allergies;
  final String? symptoms;
  final String? lifestyleNotes;
  final String? notes;

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item?.toString() ?? '')
          .where((value) => value.trim().isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }
    return const [];
  }

  factory HealthProfileSnapshot.fromJson(Map<String, dynamic> json) {
    return HealthProfileSnapshot(
      id: (json['id'] as num?)?.toInt() ?? 0,
      recordedAt:
          json['recorded_at'] as String? ?? json['recordedAt'] as String? ?? '',
      source:
          json['source'] as String? ??
          json['sourceType'] as String? ??
          'self_reported',
      chronicConditions: _stringList(
        json['chronic_conditions'] ?? json['chronicConditions'],
      ),
      currentMedications: _stringList(
        json['current_medications'] ?? json['currentMedications'],
      ),
      allergies: _stringList(json['allergies']),
      symptoms: json['symptoms'] as String?,
      lifestyleNotes:
          json['lifestyle_notes'] as String? ??
          json['lifestyleNotes'] as String?,
      notes: json['notes'] as String?,
    );
  }

  bool get hasClinicalData =>
      chronicConditions.isNotEmpty ||
      currentMedications.isNotEmpty ||
      allergies.isNotEmpty;
}

class HealthSnapshot {
  const HealthSnapshot({
    this.snapshotDate,
    this.bmi,
    this.healthScore,
    this.riskScore,
    this.bloodSugar,
    this.bloodSugarContext,
    this.cholesterol,
    this.otherConditions,
    this.aiSummary,
    this.generatedAt,
    this.updatedByName,
    this.latestVitals,
    this.latestResults,
  });

  /// One row per patient per day (`YYYY-MM-DD`), upserted on the backend.
  final String? snapshotDate;
  final double? bmi;
  // API may return either an int or a decimal(5,2); always parsed as double.
  final double? healthScore;
  final double? riskScore;
  // Manual-entry only fields (mg/dL).
  final double? bloodSugar;
  final String? bloodSugarContext;
  final double? cholesterol;
  final String? otherConditions;
  final String? aiSummary;
  final String? generatedAt;
  final String? updatedByName;
  final VitalRecord? latestVitals;

  /// Reserved for lab results; currently always `null` per the API contract.
  /// Kept as `dynamic` and parsed defensively since its shape isn't defined.
  final dynamic latestResults;

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = _map(json['snapshot'] ?? json['data'] ?? json);
    final vitalsRaw = snapshot['latest_vitals'] ?? snapshot['latestVitals'];
    final updatedBy = _map(snapshot['updated_by'] ?? snapshot['updatedBy']);
    return HealthSnapshot(
      snapshotDate:
          snapshot['snapshot_date'] as String? ??
          snapshot['snapshotDate'] as String?,
      bmi: _doubleValue(snapshot['bmi']),
      healthScore:
          _doubleValue(snapshot['health_score']) ??
          _doubleValue(snapshot['healthScore']),
      riskScore:
          _doubleValue(snapshot['risk_score']) ??
          _doubleValue(snapshot['riskScore']),
      bloodSugar:
          _doubleValue(snapshot['blood_sugar']) ??
          _doubleValue(snapshot['bloodSugar']),
      bloodSugarContext:
          snapshot['blood_sugar_context'] as String? ??
          snapshot['bloodSugarContext'] as String?,
      cholesterol: _doubleValue(snapshot['cholesterol']),
      otherConditions:
          snapshot['other_conditions'] as String? ??
          snapshot['otherConditions'] as String?,
      aiSummary:
          snapshot['ai_summary'] as String? ?? snapshot['aiSummary'] as String?,
      generatedAt:
          snapshot['generated_at'] as String? ??
          snapshot['generatedAt'] as String?,
      updatedByName: updatedBy['name'] as String?,
      latestVitals: vitalsRaw is Map
          ? VitalRecord.fromSnapshotJson(_map(vitalsRaw))
          : null,
      latestResults: snapshot['latest_results'] ?? snapshot['latestResults'],
    );
  }

  /// True when the snapshot carries no meaningful data yet (e.g. a brand new
  /// patient with no clinical vitals and no manual entries).
  bool get isEmpty =>
      (snapshotDate ?? '').trim().isEmpty &&
      healthScore == null &&
      riskScore == null &&
      bmi == null &&
      bloodSugar == null &&
      cholesterol == null &&
      (otherConditions ?? '').trim().isEmpty &&
      (aiSummary ?? '').trim().isEmpty;

  bool get hasClinicalData =>
      healthScore != null ||
      riskScore != null ||
      bmi != null ||
      bloodSugar != null ||
      cholesterol != null ||
      latestVitals != null ||
      latestResults != null ||
      (otherConditions ?? '').trim().isNotEmpty ||
      (aiSummary ?? '').trim().isNotEmpty;
}

/// One page of `GET /patients/me/health-snapshot/history` results.
class HealthSnapshotHistoryPage {
  const HealthSnapshotHistoryPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<HealthSnapshot> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory HealthSnapshotHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawItems =
        json['snapshots'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    final meta = _map(json['meta']);
    return HealthSnapshotHistoryPage(
      items: rawItems
          .map((item) => HealthSnapshot.fromJson(_map(item)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? rawItems.length,
    );
  }
}

class AiSuggestionItem {
  const AiSuggestionItem({
    required this.id,
    required this.recommendationType,
    required this.reason,
    required this.score,
    required this.isAccepted,
    this.itemType,
    this.itemName,
    this.labTestId,
    this.packageId,
  });

  final int id;
  final String recommendationType;
  final String reason;
  final double score;
  final bool isAccepted;
  final String? itemType;
  final String? itemName;
  final int? labTestId;
  final int? packageId;

  bool get isLabTest => itemType == 'lab_test';
  bool get isLabPackage => itemType == 'lab_package';

  factory AiSuggestionItem.fromJson(Map<String, dynamic> json) {
    final item = _map(json['item']);
    final itemType = item['type'] as String?;
    return AiSuggestionItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      recommendationType:
          json['recommendation_type'] as String? ??
          json['recommendationType'] as String? ??
          '',
      reason: json['reason'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      isAccepted:
          json['is_accepted'] as bool? ?? json['isAccepted'] as bool? ?? false,
      itemType: itemType,
      itemName:
          item['test_name'] as String? ??
          item['testName'] as String? ??
          item['package_name'] as String? ??
          item['packageName'] as String? ??
          item['name'] as String?,
      labTestId:
          (item['lab_test_id'] as num?)?.toInt() ??
          (item['labTestId'] as num?)?.toInt() ??
          (item['id'] as num?)?.toInt(),
      packageId:
          (item['package_id'] as num?)?.toInt() ??
          (item['packageId'] as num?)?.toInt() ??
          (itemType == 'lab_package' ? item['id'] as num? : null)?.toInt(),
    );
  }
}

class PatientDashboard {
  const PatientDashboard({
    required this.patient,
    required this.metrics,
    required this.recentBookings,
    required this.recentPrescriptions,
    required this.recentDocuments,
    required this.recentSummaries,
    required this.idCard,
    required this.myClub,
    required this.emergencyContacts,
    this.latestVitals,
  });

  final PatientIdentity patient;
  final PortalMetrics metrics;
  final List<BookingItem> recentBookings;
  final List<PrescriptionRecord> recentPrescriptions;
  final List<DocumentRecord> recentDocuments;
  final List<SummaryRecord> recentSummaries;
  final IdCardInfo idCard;
  final MyClubSummary myClub;
  final List<EmergencyContact> emergencyContacts;
  final VitalRecord? latestVitals;

  factory PatientDashboard.fromJson(Map<String, dynamic> json) {
    final bookingsJson = json['recentBookings'] as List<dynamic>? ?? const [];
    final prescriptionsJson =
        json['recentPrescriptions'] as List<dynamic>? ?? const [];
    final documentsJson = json['recentDocuments'] as List<dynamic>? ?? const [];
    final summariesJson = json['recentSummaries'] as List<dynamic>? ?? const [];
    final contactsJson =
        json['emergencyContacts'] as List<dynamic>? ?? const [];

    return PatientDashboard(
      patient: PatientIdentity.fromJson(_map(json['patient'])),
      metrics: PortalMetrics.fromJson(_map(json['metrics'])),
      recentBookings: bookingsJson
          .map((item) => BookingItem.fromJson(_map(item)))
          .toList(),
      recentPrescriptions: prescriptionsJson
          .map((item) => PrescriptionRecord.fromJson(_map(item)))
          .toList(),
      recentDocuments: documentsJson
          .map((item) => DocumentRecord.fromJson(_map(item)))
          .toList(),
      recentSummaries: summariesJson
          .map((item) => SummaryRecord.fromJson(_map(item)))
          .toList(),
      idCard: IdCardInfo.fromJson(_map(json['idCard'])),
      myClub: MyClubSummary.fromJson(_map(json['myClub'])),
      emergencyContacts: contactsJson
          .map((item) => EmergencyContact.fromJson(_map(item)))
          .toList(),
      latestVitals: json['latestVitals'] is Map
          ? VitalRecord.fromJson(_map(json['latestVitals']))
          : null,
    );
  }
}

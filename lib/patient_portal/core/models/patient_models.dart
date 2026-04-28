import 'dart:convert';

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

  factory PatientIdentity.fromJson(Map<String, dynamic> json) {
    return PatientIdentity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Patient',
      phone: json['phone'] as String? ?? '',
      registrationNumber:
          json['registrationNumber'] as String? ??
          json['registration_number'] as String? ??
          'BHRC',
      uuid: json['uuid'] as String? ?? '',
      dob: json['dob'] as String?,
      gender: json['gender'] as String?,
      age: (json['age'] as num?)?.toInt(),
      address: json['address'] as String?,
      email: json['email'] as String?,
      bloodGroup:
          json['bloodGroup'] as String? ?? json['blood_group'] as String?,
      allergies: json['allergies'] as String?,
      chronicConditions:
          json['chronicConditions'] as String? ??
          json['chronic_conditions'] as String?,
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
    this.doctorSpecialization,
  });

  final int id;
  final String bookingDate;
  final String timeslot;
  final String status;
  final int doctorId;
  final String doctorName;
  final String? doctorSpecialization;

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bookingDate: json['bookingDate'] as String? ?? '',
      timeslot: json['timeslot'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      doctorId: (json['doctorId'] as num?)?.toInt() ?? 0,
      doctorName: json['doctorName'] as String? ?? 'BHRC Doctor',
      doctorSpecialization: json['doctorSpecialization'] as String?,
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
      date: json['date'] as String? ?? '',
      type: json['type'] as String? ?? 'summary',
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

    return MedicalRecordItem(
      id: json['id'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'document',
      category: json['category'] as String? ?? 'lab',
      recordType: json['recordType'] as String? ?? 'Record',
      title: json['title'] as String? ?? 'Medical Record',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      date: json['date'] as String? ?? '',
      kindLabel: json['kindLabel'] as String? ?? 'Record',
      time: json['time'] as String?,
      summary: json['summary'] as String?,
      doctorName: json['doctorName'] as String?,
      documentPath: json['documentPath'] as String?,
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      recordedAt:
          json['recordedAt'] as String? ?? json['recorded_at'] as String? ?? '',
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      bloodPressureSystolic:
          (json['bloodPressureSystolic'] as num?)?.toInt() ??
          (json['bp_systolic'] as num?)?.toInt(),
      bloodPressureDiastolic:
          (json['bloodPressureDiastolic'] as num?)?.toInt() ??
          (json['bp_diastolic'] as num?)?.toInt(),
      heartRate:
          (json['heartRate'] as num?)?.toInt() ??
          (json['heart_rate'] as num?)?.toInt(),
      bodyTemperature:
          (json['bodyTemperature'] as num?)?.toDouble() ??
          (json['body_temperature'] as num?)?.toDouble(),
      oxygenSaturation:
          (json['oxygenSaturation'] as num?)?.toInt() ??
          (json['spo2'] as num?)?.toInt(),
      respiratoryRate:
          (json['respiratoryRate'] as num?)?.toInt() ??
          (json['respiratory_rate'] as num?)?.toInt(),
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

  factory MyClubSummary.fromJson(Map<String, dynamic> json) {
    final transactionJson = json['transactions'] as List<dynamic>? ?? const [];
    final benefitsJson = json['benefits'] as List<dynamic>? ?? const [];
    return MyClubSummary(
      patientId: (json['patientId'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      currencyValue: (json['currencyValue'] as num?)?.toDouble() ?? 0,
      tier: json['tier'] as String? ?? 'Classic',
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
    );
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
  });

  final int id;
  final String title;
  final String imageUrl;
  final String? subtitle;
  final String? ctaLabel;
  final String? ctaTarget;
  final int sortOrder;
  final bool isActive;

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
    this.breakStartTime,
    this.breakEndTime,
    this.slotDurationMinutes,
    this.globalSchedule,
    this.departmentName,
    this.email,
    this.phone,
    this.registrationNumber,
    this.imageUrl,
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
  final String? breakStartTime;
  final String? breakEndTime;
  final int? slotDurationMinutes;
  final String? globalSchedule;
  final String? departmentName;
  final String? email;
  final String? phone;
  final String? registrationNumber;
  final String? imageUrl;

  factory DoctorListing.fromJson(Map<String, dynamic> json) {
    return DoctorListing(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Doctor',
      specialization: json['specialization'] as String? ?? 'General',
      qualifications: json['qualifications'] as String?,
      availableTime: json['availableTime'] as String?,
      availableDates: json['availableDates'] as String?,
      workingDays: json['workingDays'] as String?,
      workStartTime: json['workStartTime'] as String?,
      workEndTime: json['workEndTime'] as String?,
      breakStartTime: json['breakStartTime'] as String?,
      breakEndTime: json['breakEndTime'] as String?,
      slotDurationMinutes: (json['slotDurationMinutes'] as num?)?.toInt(),
      globalSchedule: json['globalSchedule'] as String?,
      departmentName:
          json['departmentName'] as String? ??
          json['department_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      registrationNumber:
          json['registrationNumber'] as String? ??
          json['registration_number'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
    );
  }
}

class DepartmentItem {
  const DepartmentItem({
    required this.id,
    required this.name,
    this.imageUrl,
  });

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
    this.createdAt,
    this.attachments = const [],
  });

  final String role;
  final String content;
  final String? createdAt;
  final List<ChatAttachment> attachments;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final parsed = ChatMessageCodec.decode(json['content'] as String? ?? '');
    return ChatMessage(
      role: json['role'] as String? ?? 'assistant',
      content: parsed.content,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      attachments: parsed.attachments,
    );
  }

  String toWireContent() {
    return ChatMessageCodec.encode(content: content, attachments: attachments);
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
      id: json['id'] as String? ?? '',
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

class LabTestItem {
  const LabTestItem({
    required this.id,
    required this.testName,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    required this.basePrice,
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

    return LabTestItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      testName: json['testName'] as String? ?? 'Lab test',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      categoryName: json['categoryName'] as String? ?? 'General',
      status: json['status'] as bool? ?? true,
      basePrice: parseDbl(json['basePrice'] ?? json['base_price']),
      discountedPrice: json['discountedPrice'] != null || json['discounted_price'] != null
          ? parseDbl(json['discountedPrice'] ?? json['discounted_price'])
          : null,
      uuid: json['uuid'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      instructions: json['instructions'] as String?,
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
          json['patientPhone'] as String? ?? json['patient_phone'] as String?,
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

  factory LabPackageItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final includedRaw = json['includedTests'] as List<dynamic>? ?? const [];
    return LabPackageItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Health package',
      slug: json['slug'] as String? ?? '',
      status: json['status'] as bool? ?? true,
      basePrice: parseInt(json['basePrice'] ?? json['base_price']),
      description: json['description'] as String?,
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      instructions: json['instructions'] as String?,
      resultEta: json['resultEta'] as String? ?? json['result_eta'] as String?,
      totalTests: (json['totalTests'] as num?)?.toInt(),
      discountedPrice: json['discountedPrice'] != null || json['discounted_price'] != null
          ? parseInt(json['discountedPrice'] ?? json['discounted_price'])
          : null,
      includedTests: includedRaw
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item['testName'] as String? ?? '';
            }
            if (item is Map) {
              return item['testName']?.toString() ?? '';
            }
            return '';
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
          json['patientPhone'] as String? ?? json['patient_phone'] as String?,
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
    this.cached = false,
  });

  final bool success;
  final String summary;
  final List<String> texts;
  final bool cached;

  factory DocumentAnalysisResult.fromJson(Map<String, dynamic> json) {
    final texts = json['texts'] as List<dynamic>? ?? const [];
    return DocumentAnalysisResult(
      success: json['success'] as bool? ?? true,
      summary: json['summary'] as String? ?? '',
      texts: texts.map((item) => item.toString()).toList(),
      cached: json['cached'] as bool? ?? false,
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

import 'package:flutter/material.dart';

import '../../core/models/patient_models.dart';

class EmergencyTipData {
  const EmergencyTipData({required this.icon, required this.message});

  final IconData icon;
  final String message;
}

class EmergencyHospitalInfo {
  const EmergencyHospitalInfo({
    required this.name,
    required this.lines,
    required this.pinCode,
  });

  final String name;
  final List<String> lines;
  final String pinCode;
}

class EmergencyContactCardData {
  const EmergencyContactCardData({
    required this.title,
    required this.number,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.surfaceColor,
    required this.badgeLabel,
  });

  final String title;
  final String number;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color surfaceColor;
  final String badgeLabel;
}

const emergencyHospitalInfo = EmergencyHospitalInfo(
  name: 'BHRC Hospital Location',
  lines: [
    'Biohelix Health & Research Center',
    'Medical College Road, Thiruvananthapuram',
  ],
  pinCode: 'Kerala - 695011',
);

const _fallbackContacts = [
  EmergencyContact(name: 'BHRC Emergency', number: '+91 7510210222'),
  EmergencyContact(name: 'Hospital Reception', number: '+91 7510210224'),
  EmergencyContact(name: 'Emergency Helpline', number: '108'),
];

List<EmergencyTipData> buildEmergencyTips(String? bloodGroup) {
  final tips = <EmergencyTipData>[
    const EmergencyTipData(
      icon: Icons.favorite_rounded,
      message: 'Chest pain or shortness of breath - call ambulance immediately',
    ),
    const EmergencyTipData(
      icon: Icons.bolt_rounded,
      message: 'Stroke symptoms: face drooping, arm weakness, speech difficulty',
    ),
    const EmergencyTipData(
      icon: Icons.water_drop_rounded,
      message: 'Severe bleeding - apply firm pressure and call emergency services',
    ),
  ];

  final normalizedBloodGroup = (bloodGroup ?? '').trim();
  if (normalizedBloodGroup.isNotEmpty) {
    tips.add(
      EmergencyTipData(
        icon: Icons.medical_information_rounded,
        message:
            'Your blood group is $normalizedBloodGroup - inform emergency staff',
      ),
    );
  }

  return tips;
}

EmergencyContactCardData buildPrimaryEmergencyContact(
  List<EmergencyContact> contacts,
) {
  final resolvedContacts = _resolveContacts(contacts);
  final primaryContact = resolvedContacts.firstWhere(
    (contact) => _normalizedNumber(contact.number) == '108',
    orElse: () => resolvedContacts.first,
  );

  return _buildCardData(primaryContact, emphasized: true);
}

List<EmergencyContactCardData> buildEmergencyContactCards(
  List<EmergencyContact> contacts,
) {
  final resolvedContacts = _resolveContacts(contacts);
  return resolvedContacts.map(_buildCardData).toList(growable: false);
}

List<EmergencyContact> _resolveContacts(List<EmergencyContact> contacts) {
  final resolved = contacts.isEmpty ? _fallbackContacts : contacts;
  final seenKeys = <String>{};
  final unique = <EmergencyContact>[];

  for (final contact in resolved) {
    final key = '${contact.name.toLowerCase()}|${_normalizedNumber(contact.number)}';
    if (seenKeys.add(key)) {
      unique.add(contact);
    }
  }

  if (!unique.any((contact) => _normalizedNumber(contact.number) == '108')) {
    unique.add(const EmergencyContact(name: 'Emergency Helpline', number: '108'));
  }

  return unique;
}

EmergencyContactCardData _buildCardData(
  EmergencyContact contact, {
  bool emphasized = false,
}) {
  final name = contact.name.trim();
  final normalizedName = name.toLowerCase();
  final isEmergency = normalizedName.contains('emergency');
  final isAmbulance = normalizedName.contains('ambulance');
  final isReception = normalizedName.contains('reception');
  final isHelpline = normalizedName.contains('helpline');
  final icon = isHelpline
      ? Icons.support_agent_rounded
      : isReception
      ? Icons.local_hospital_rounded
      : Icons.call_rounded;

  final surfaceColor = emphasized
      ? const Color(0xFFFFF6F6)
      : isEmergency || isAmbulance
      ? const Color(0xFFFFF2F2)
      : const Color(0xFFFFFFFF);

  final iconColor = isEmergency || isAmbulance
      ? const Color(0xFFE53935)
      : isHelpline
      ? const Color(0xFF1D4ED8)
      : const Color(0xFF234996);

  final subtitle = isAmbulance
      ? 'Immediate ambulance assistance'
      : isReception
      ? 'Hospital front desk and triage support'
      : isHelpline
      ? 'Urgent patient support and guidance'
      : 'Emergency contact support';

  final badgeLabel = isEmergency || isAmbulance ? '24/7' : 'Tap to call';

  return EmergencyContactCardData(
    title: name.isEmpty ? 'Emergency contact' : name,
    number: contact.number,
    subtitle: subtitle,
    icon: icon,
    iconColor: iconColor,
    surfaceColor: surfaceColor,
    badgeLabel: badgeLabel,
  );
}

String _normalizedNumber(String value) {
  final buffer = StringBuffer();

  for (final rune in value.runes) {
    if (rune >= 48 && rune <= 57) {
      buffer.writeCharCode(rune);
    }
  }

  return buffer.toString();
}
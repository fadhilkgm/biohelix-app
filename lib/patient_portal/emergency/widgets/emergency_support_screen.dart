import 'package:flutter/material.dart';

import '../../core/models/patient_models.dart';
import 'emergency_call_launcher.dart';
import 'emergency_support_content.dart';
import 'widgets/emergency_contact_tile.dart';
import 'widgets/emergency_header_panel.dart';
import 'widgets/emergency_location_card.dart';
import 'widgets/emergency_primary_call_card.dart';
import 'widgets/emergency_tip_tile.dart';

class EmergencySupportScreen extends StatelessWidget {
  const EmergencySupportScreen({
    super.key,
    required this.patientName,
    required this.contacts,
    this.bloodGroup,
  });

  final String patientName;
  final String? bloodGroup;
  final List<EmergencyContact> contacts;

  @override
  Widget build(BuildContext context) {
    final primaryContact = buildPrimaryEmergencyContact(contacts);
    final contactCards = buildEmergencyContactCards(contacts);
    final tips = buildEmergencyTips(bloodGroup);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  EmergencyHeaderPanel(
                    patientName: patientName,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: -42,
                    child: EmergencyPrimaryCallCard(
                      title: 'Call Ambulance',
                      number: primaryContact.number,
                      onTap: () => _handleCall(context, primaryContact.number),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 58, 12, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Hospital Contacts'),
                    const SizedBox(height: 12),
                    for (final contact in contactCards) ...[
                      EmergencyContactTile(
                        contact: contact,
                        onTap: () => _handleCall(context, contact.number),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                    const _SectionTitle('Emergency Tips'),
                    const SizedBox(height: 12),
                    for (final tip in tips) ...[
                      EmergencyTipTile(tip: tip),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                    EmergencyLocationCard(info: emergencyHospitalInfo),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCall(BuildContext context, String phoneNumber) async {
    final launched = await EmergencyCallLauncher.call(phoneNumber);
    if (launched || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not start a call to $phoneNumber.')),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
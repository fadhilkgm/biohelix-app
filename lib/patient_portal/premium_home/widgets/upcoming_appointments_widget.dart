import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/models/patient_models.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';

class UpcomingAppointmentsWidget extends StatelessWidget {
  const UpcomingAppointmentsWidget({
    super.key,
    required this.bookings,
    required this.onSeeAllAppointments,
  });

  final List<BookingItem> bookings;
  final VoidCallback onSeeAllAppointments;

  @override
  Widget build(BuildContext context) {
    final upcoming = bookings.take(2).toList(growable: false);
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.upcomingAppointments,
                style: AppTextStyles.sectionTitle(context),
              ),
            ),
            TextButton(
              onPressed: onSeeAllAppointments,
              child: Text(strings.seeAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (upcoming.isEmpty)
          _NoAppointmentCard(message: strings.noUpcomingAppointments)
        else
          Column(
            children: upcoming
                .map(
                  (booking) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AppointmentCard(booking: booking),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final specialization = (booking.doctorSpecialization ?? '').trim().isEmpty
        ? 'General Medicine'
        : booking.doctorSpecialization!.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.section),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: Color(0xFF0B3A82),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.doctorName,
                  style: AppTextStyles.sectionTitle(context),
                ),
                Text(specialization, style: AppTextStyles.subText(context)),
                const SizedBox(height: 4),
                Text(
                  '${booking.bookingDate} at ${booking.timeslot}',
                  style: AppTextStyles.subText(context).copyWith(
                    color: const Color(0xFF8A94A3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(label: _statusLabel(booking.status)),
        ],
      ),
    );
  }

  String _statusLabel(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    if (status.isEmpty) return 'Confirmed';
    return status[0].toUpperCase() + status.substring(1);
  }
}

class _NoAppointmentCard extends StatelessWidget {
  const _NoAppointmentCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.section),
      ),
      padding: const EdgeInsets.all(14),
      child: Text(message, style: AppTextStyles.subText(context)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD9FBEA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.subText(
          context,
        ).copyWith(color: const Color(0xFF16A34A), fontWeight: FontWeight.w700),
      ),
    );
  }
}

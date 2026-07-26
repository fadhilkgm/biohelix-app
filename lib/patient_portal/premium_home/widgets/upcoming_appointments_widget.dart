import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/models/patient_models.dart';
import '../../core/widgets/booking_success_screen.dart';
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
    final upcoming = bookings
        .where((booking) {
          final status = booking.status.trim().toLowerCase();
          return booking.isDoctorAppointment &&
              status != 'completed' &&
              status != 'complete' &&
              status != 'done';
        })
        .take(2)
        .toList(growable: false);
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
                    child: _AppointmentCard(
                      booking: booking,
                      onTap: () => _openAppointment(context, booking),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  void _openAppointment(BuildContext context, BookingItem booking) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingSuccessScreen(
          bookingId: booking.id.toString(),
          tokenNumber: booking.tokenNumber,
          showMedicalSuccessIcon: true,
          popToRootOnBack: false,
          title: 'Upcoming Appointment',
          subtitle:
              'Your appointment is scheduled. Keep your token number ready when you arrive.',
          doctorName: booking.doctorName,
          doctorSpecialization: booking.doctorSpecialization,
          doctorImageUrl: booking.doctorImageUrl,
          bookingDate: booking.bookingDate,
          bookingTime: booking.timeslot,
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.booking, required this.onTap});

  final BookingItem booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final specialization = (booking.doctorSpecialization ?? '').trim().isEmpty
        ? 'General Medicine'
        : booking.doctorSpecialization!.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.section),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.section),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.doctorName,
                      style: AppTextStyles.sectionTitle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      specialization,
                      style: AppTextStyles.subText(
                        context,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    _AppointmentDateTimeBadge(
                      date: booking.bookingDate,
                      time: booking.timeslot,
                    ),
                  ],
                ),
              ),
              _StatusPill(label: _statusLabel(booking.status)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A94A3)),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    if (status.isEmpty) return 'Confirmed';
    return status[0].toUpperCase() + status.substring(1);
  }
}

class _AppointmentDateTimeBadge extends StatelessWidget {
  const _AppointmentDateTimeBadge({required this.date, required this.time});

  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 15,
            color: Color(0xFF315D91),
          ),
          const SizedBox(width: 5),
          Text(
            '$date  •  $time',
            style: AppTextStyles.subText(context).copyWith(
              color: const Color(0xFF315D91),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
        ).copyWith(color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
      ),
    );
  }
}

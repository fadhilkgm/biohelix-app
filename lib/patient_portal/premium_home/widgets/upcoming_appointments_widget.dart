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

  static const _closedStatuses = {
    'completed',
    'complete',
    'done',
    'cancelled',
    'canceled',
    'missed',
    'expired',
  };

  static bool hasUpcoming(List<BookingItem> bookings) {
    return bookings.any(_isUpcoming);
  }

  static bool _isUpcoming(BookingItem booking) {
    final status = booking.effectiveStatus().trim().toLowerCase();
    return booking.isDoctorAppointment && !_closedStatuses.contains(status);
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = bookings
        .where(_isUpcoming)
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

  String _getInitials(String name) {
    final clean = name
        .replaceAll(RegExp(r'^(Dr\.|Dr)\s*', caseSensitive: false), '')
        .trim();
    if (clean.isEmpty) return 'D';
    final parts = clean.split(' ');
    if (parts.length > 1) {
      final firstLetter = parts[0].isNotEmpty ? parts[0][0] : '';
      final secondLetter = parts[1].isNotEmpty ? parts[1][0] : '';
      return (firstLetter + secondLetter).toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'D';
  }

  @override
  Widget build(BuildContext context) {
    final specialization = (booking.doctorSpecialization ?? '').trim().isEmpty
        ? 'General Medicine'
        : booking.doctorSpecialization!.trim();

    final hasImage =
        booking.doctorImageUrl != null &&
        booking.doctorImageUrl!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.section),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.section),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Doctor Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2EAF8), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: hasImage
                      ? Image.network(
                          booking.doctorImageUrl!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) =>
                              _buildFallbackAvatar(),
                        )
                      : _buildFallbackAvatar(),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialization,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subText(context).copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _AppointmentDateTimeBadge(
                      date: booking.bookingDate,
                      time: booking.timeslot,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status and token
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusPill(status: booking.effectiveStatus()),
                  if (booking.tokenNumber != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Token #${booking.tokenNumber}',
                      style: const TextStyle(
                        color: Color(0xFF173B63),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Center(
      child: Text(
        _getInitials(booking.doctorName),
        style: const TextStyle(
          color: Color(0xFF06489B),
          fontWeight: FontWeight.w700,
          fontSize: 16,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }
}

class _AppointmentDateTimeBadge extends StatelessWidget {
  const _AppointmentDateTimeBadge({required this.date, required this.time});

  final String date;
  final String time;

  String get _formattedTime {
    final parts = time.split('-').map((part) => part.trim()).toList();
    if (parts.length != 2) return DoctorListing.formatTimeLabel(time);

    final start = DoctorListing.formatTimeLabel(parts.first);
    final end = DoctorListing.formatTimeLabel(parts.last);
    final startPeriod = RegExp(r'\b(AM|PM)$').firstMatch(start)?.group(1);
    final endPeriod = RegExp(r'\b(AM|PM)$').firstMatch(end)?.group(1);

    if (startPeriod != null && startPeriod == endPeriod) {
      return '${start.replaceFirst(RegExp(r'\s+(AM|PM)$'), '')} - $end';
    }
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final detailStyle = AppTextStyles.subText(context).copyWith(
      color: const Color(0xFF6B7280),
      fontWeight: FontWeight.w800,
      fontSize: 11,
    );

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 13,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 4),
            Text(date, style: detailStyle),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 13,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 4),
            Text(_formattedTime, style: detailStyle),
          ],
        ),
      ],
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
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cleanStatus = status.trim().toLowerCase();

    Color textColor;
    Color bgColor;
    String label;

    switch (cleanStatus) {
      case 'pending':
        textColor = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
        label = 'Pending';
        break;
      case 'confirmed':
      case 'approved':
      case 'active':
        textColor = const Color(0xFF16A34A);
        bgColor = const Color(0xFFD9FBEA);
        label = 'Confirmed';
        break;
      case 'cancelled':
      case 'rejected':
        textColor = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEE2E2);
        label = 'Cancelled';
        break;
      case 'missed':
      case 'no_show':
      case 'no-show':
        textColor = const Color(0xFFC2410C);
        bgColor = const Color(0xFFFFEDD5);
        label = 'Missed';
        break;
      default:
        textColor = const Color(0xFF06489B);
        bgColor = const Color(0xFFEAF2FC);
        label = status.isEmpty
            ? 'Confirmed'
            : status[0].toUpperCase() + status.substring(1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.subText(
          context,
        ).copyWith(color: textColor, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

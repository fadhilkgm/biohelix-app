import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookingSuccessDetail {
  const BookingSuccessDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.bookingId,
    this.title = 'Booking Confirmed!',
    this.subtitle =
        'Your booking has been successfully placed. You can track your status in the bookings tab.',
    this.imagePath = 'assets/images/appoiment-success.png',
    this.summaryTitle,
    this.summarySubtitle,
    this.summaryImageUrl,
    this.summaryImageAsset,
    this.details = const [],
    this.doctorName,
    this.doctorSpecialization,
    this.doctorImageUrl,
    this.bookingDate,
    this.bookingTime,
  });

  final String bookingId;
  final String title;
  final String subtitle;
  final String imagePath;
  final String? summaryTitle;
  final String? summarySubtitle;
  final String? summaryImageUrl;
  final String? summaryImageAsset;
  final List<BookingSuccessDetail> details;
  final String? doctorName;
  final String? doctorSpecialization;
  final String? doctorImageUrl;
  final String? bookingDate;
  final String? bookingTime;

  String get _resolvedSummaryTitle {
    final value = summaryTitle?.trim();
    if (value != null && value.isNotEmpty) return value;
    return doctorName?.trim() ?? '';
  }

  String get _resolvedSummarySubtitle {
    final value = summarySubtitle?.trim();
    if (value != null && value.isNotEmpty) return value;
    return doctorSpecialization?.trim() ?? '';
  }

  String get _resolvedSummaryImageUrl {
    final value = summaryImageUrl?.trim();
    if (value != null && value.isNotEmpty) return value;
    return doctorImageUrl?.trim() ?? '';
  }

  List<BookingSuccessDetail> get _resolvedDetails {
    if (details.isNotEmpty) return details;
    return [
      if ((bookingDate ?? '').trim().isNotEmpty)
        BookingSuccessDetail(
          icon: Icons.calendar_today_rounded,
          label: 'Date',
          value: bookingDate!.trim(),
        ),
      if ((bookingTime ?? '').trim().isNotEmpty)
        BookingSuccessDetail(
          icon: Icons.access_time_rounded,
          label: 'Time',
          value: bookingTime!.trim(),
        ),
    ];
  }

  bool get _hasSummary {
    return _resolvedSummaryTitle.isNotEmpty ||
        _resolvedSummarySubtitle.isNotEmpty ||
        _resolvedSummaryImageUrl.isNotEmpty ||
        (summaryImageAsset ?? '').trim().isNotEmpty ||
        _resolvedDetails.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final detailItems = _resolvedDetails;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    Image.asset(
                      imagePath,
                      height: _hasSummary ? 180 : 320,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF192233),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        color: const Color(0xFF192233).withValues(alpha: 0.6),
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_hasSummary) ...[
                      const SizedBox(height: 24),
                      _BookingSummaryCard(
                        title: _resolvedSummaryTitle,
                        subtitle: _resolvedSummarySubtitle,
                        imageUrl: _resolvedSummaryImageUrl,
                        imageAsset: summaryImageAsset,
                        details: detailItems,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Reference: $bookingId',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: const Color(0xFF5A88F1),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A88F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.details,
    this.imageAsset,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String? imageAsset;
  final List<BookingSuccessDetail> details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EDFA)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: _BookingSummaryImage(
                    imageUrl: imageUrl,
                    imageAsset: imageAsset,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF192233),
                        ),
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5A88F1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: details
                      .where((item) => item.value.trim().isNotEmpty)
                      .map(
                        (item) => SizedBox(
                          width: tileWidth,
                          child: _BookingDetailTile(detail: item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingSummaryImage extends StatelessWidget {
  const _BookingSummaryImage({required this.imageUrl, this.imageAsset});

  final String imageUrl;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final cleanAsset = imageAsset?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _BookingFallbackImage(imageAsset: cleanAsset),
      );
    }
    return _BookingFallbackImage(imageAsset: cleanAsset);
  }
}

class _BookingDetailTile extends StatelessWidget {
  const _BookingDetailTile({required this.detail});

  final BookingSuccessDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(detail.icon, size: 18, color: const Color(0xFF5A88F1)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  detail.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF192233).withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF192233),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingFallbackImage extends StatelessWidget {
  const _BookingFallbackImage({required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF0FF),
      child: Image.asset(
        imageAsset.isNotEmpty ? imageAsset : 'assets/images/doctor-vector.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

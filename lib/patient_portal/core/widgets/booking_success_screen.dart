import 'package:flutter/material.dart';

import '../../../core/widgets/app_chevron_back_button.dart';
import '../../../core/widgets/app_logo.dart';

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
    this.tokenNumber,
    this.showMedicalSuccessIcon = false,
    this.popToRootOnBack = true,
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
  final int? tokenNumber;
  final bool showMedicalSuccessIcon;
  final bool popToRootOnBack;

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

  void _goBack(BuildContext context) {
    if (popToRootOnBack) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailItems = _resolvedDetails;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: AppChevronBackButton(onPressed: () => _goBack(context)),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _goBack(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06489B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Back',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 640;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: isCompact ? 4 : 20),
                    if (showMedicalSuccessIcon)
                      _MedicalSuccessIcon(size: isCompact ? 112 : 140)
                    else
                      Image.asset(
                        imagePath,
                        height: _hasSummary
                            ? (isCompact ? 120 : 160)
                            : (isCompact ? 220 : 280),
                        fit: BoxFit.contain,
                      ),
                    SizedBox(height: isCompact ? 16 : 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: isCompact ? 24 : 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF192233),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: isCompact ? 8 : 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: isCompact ? 14 : 16,
                        color: const Color(0xFF192233).withValues(alpha: 0.6),
                        height: isCompact ? 1.35 : 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_hasSummary) ...[
                      SizedBox(height: isCompact ? 16 : 20),
                      _BookingSummaryCard(
                        title: _resolvedSummaryTitle,
                        subtitle: _resolvedSummarySubtitle,
                        imageUrl: _resolvedSummaryImageUrl,
                        imageAsset: summaryImageAsset,
                        details: detailItems,
                        tokenNumber: showMedicalSuccessIcon
                            ? tokenNumber
                            : null,
                      ),
                    ],
                    if (!showMedicalSuccessIcon) ...[
                      SizedBox(height: isCompact ? 16 : 20),
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
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: Color(0xFF06489B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: isCompact ? 16 : 24),
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

class _MedicalSuccessIcon extends StatelessWidget {
  const _MedicalSuccessIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scale = size / 150;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 138 * scale,
            height: 138 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB9D8F7), width: 2),
            ),
            child: Icon(
              Icons.medical_services_outlined,
              color: const Color(0xFF06489B),
              size: 62 * scale,
            ),
          ),
          Positioned(
            right: 4 * scale,
            bottom: 12 * scale,
            child: Container(
              width: 48 * scale,
              height: 48 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFF1F9A6D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4 * scale),
              ),
              child: Icon(
                Icons.check_rounded,
                color: const Color(0xFFFFFFFF),
                size: 28 * scale,
              ),
            ),
          ),
        ],
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
    this.tokenNumber,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String? imageAsset;
  final List<BookingSuccessDetail> details;
  final int? tokenNumber;

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
                        style: TextStyle(
                          fontFamily: 'Manrope',
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
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF06489B),
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
          if (tokenNumber != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB9D8F7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Token Number',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      color: Color(0xFF345A7D),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '#$tokenNumber',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 32,
                      height: 1,
                      color: Color(0xFF06489B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
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
          Icon(detail.icon, size: 18, color: const Color(0xFF06489B)),
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
                  style: TextStyle(
                    fontFamily: 'Manrope',
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
                  style: TextStyle(
                    fontFamily: 'Manrope',
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
      child: imageAsset.isNotEmpty
          ? Image.asset(imageAsset, fit: BoxFit.contain)
          : const AppLogo(fit: BoxFit.contain),
    );
  }
}

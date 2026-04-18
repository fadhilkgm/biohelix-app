import 'dart:async';
import 'package:google_fonts/google_fonts.dart';


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/models/home_feed_models.dart';
import '../../core/models/patient_models.dart';

import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import 'upcoming_appointments_widget.dart';

Color _parseHexColor(String hex, Color fallback) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse('FF$cleaned', radix: 16);
  return value != null ? Color(value) : fallback;
}

class OffersAndAppointmentsSectionWidget extends StatelessWidget {
  const OffersAndAppointmentsSectionWidget({
    super.key,
    required this.bookings,
    required this.onSeeAllAppointments,
    required this.onOfferTap,
    this.homeOffers = const [],
  });

  final List<BookingItem> bookings;
  final VoidCallback onSeeAllAppointments;
  final Future<void> Function(HomeOfferItem item) onOfferTap;
  final List<HomeOfferItem> homeOffers;

  static const _fallbackOffers = [
    _OfferItem(
      title: 'Health Checkup\nPackage',
      subtitle: '20% off on Annual\npackages',
      colors: [Color(0xFF0C2C6D), Color(0xFF1A6EAA)],
      buttonBorder: Color(0xFF05B3E6),
      buttonLabel: 'View Offer',
      target: null,
      source: HomeOfferItem(
        id: 0,
        title: 'Health Checkup Package',
        subtitle: '20% off on Annual packages',
        gradientFrom: '#0C2C6D',
        gradientTo: '#1A6EAA',
        buttonBorderColor: '#05B3E6',
        ctaLabel: 'View Offer',
      ),
    ),
    _OfferItem(
      title: 'Lab Test Combo',
      subtitle: 'Free Vitamin D with any\npackage',
      colors: [Color(0xFF6A38F2), Color(0xFF9B56F8)],
      buttonBorder: Color(0xFFAF91F9),
      buttonLabel: 'View Offer',
      target: null,
      source: HomeOfferItem(
        id: 0,
        title: 'Lab Test Combo',
        subtitle: 'Free Vitamin D with any package',
        gradientFrom: '#6A38F2',
        gradientTo: '#9B56F8',
        buttonBorderColor: '#AF91F9',
        ctaLabel: 'View Offer',
      ),
    ),
  ];

  List<_OfferItem> _resolvedOffers(LocalizedStrings strings) {
    if (homeOffers.isEmpty) return _fallbackOffers;
    return homeOffers
        .map(
          (offer) => _OfferItem(
            title: offer.title,
            subtitle: offer.subtitle ?? '',
            colors: [
              _parseHexColor(offer.gradientFrom, const Color(0xFF0C2C6D)),
              _parseHexColor(offer.gradientTo, const Color(0xFF1A6EAA)),
            ],
            buttonBorder: _parseHexColor(
              offer.buttonBorderColor,
              const Color(0xFF05B3E6),
            ),
            buttonLabel: offer.ctaLabel ?? strings.viewOffer,
            target: offer.ctaTarget,
            source: offer,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final offers = _resolvedOffers(strings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.specialOffers, style: AppTextStyles.sectionTitle(context)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _AutoScrollingOfferListState.cardHeight,
          child: _AutoScrollingOfferList(
            offers: offers,
            onOfferTap: (offer) => onOfferTap(offer.source),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        UpcomingAppointmentsWidget(
          bookings: bookings,
          onSeeAllAppointments: onSeeAllAppointments,
        ),
      ],
    );
  }
}

class _AutoScrollingOfferList extends StatefulWidget {
  const _AutoScrollingOfferList({
    required this.offers,
    required this.onOfferTap,
  });

  final List<_OfferItem> offers;
  final ValueChanged<_OfferItem> onOfferTap;

  @override
  State<_AutoScrollingOfferList> createState() =>
      _AutoScrollingOfferListState();
}

class _AutoScrollingOfferListState extends State<_AutoScrollingOfferList> {
  static const cardHeight = 160.0;
  static const _interval = Duration(seconds: 4);
  static const _animationDuration = Duration(milliseconds: 550);

  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _scheduleAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingOfferList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      _currentIndex = 0;
      _scheduleAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleAutoScroll() {
    _timer?.cancel();
    if (widget.offers.length <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer.periodic(_interval, (_) => _advance());
    });
  }

  Future<void> _advance() async {
    if (!_pageController.hasClients || widget.offers.length <= 1) return;

    final nextIndex = (_currentIndex + 1) % widget.offers.length;
    await _pageController.animateToPage(
      nextIndex,
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.offers.length,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemBuilder: (context, index) {
        return _OfferCard(
          item: widget.offers[index],
          onTap: () => widget.onOfferTap(widget.offers[index]),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.item, required this.onTap});

  final _OfferItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.colors.first.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.buttonLabel,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferItem {
  const _OfferItem({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.buttonBorder,
    required this.buttonLabel,
    required this.target,
    required this.source,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color buttonBorder;
  final String buttonLabel;
  final String? target;
  final HomeOfferItem source;
}

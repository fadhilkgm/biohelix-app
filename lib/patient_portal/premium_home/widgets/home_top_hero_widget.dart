import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/language_provider.dart';
import '../../core/models/home_feed_models.dart';
import '../../core/models/patient_models.dart';
import '../utils/home_header_content_mapper.dart';
import '../design/app_spacing.dart';
import 'home_announcement_ticker_widget.dart';
import 'home_health_alert_widget.dart';
import 'home_hero_header_widget.dart';
import 'home_membership_card_widget.dart';

class HomeTopHeroWidget extends StatelessWidget {
  const HomeTopHeroWidget({
    super.key,
    required this.patientName,
    required this.registrationNumber,
    required this.banners,
    required this.onViewProfile,
    this.tickerMessages = const [],
    required this.onTickerTap,
  });

  final String patientName;
  final String registrationNumber;
  final VoidCallback onViewProfile;
  final List<HomeBannerItem> banners;
  final List<TickerMessageItem> tickerMessages;
  final Future<void> Function(TickerMessageItem item) onTickerTap;

  @override
  Widget build(BuildContext context) {
    final statusBarTop = MediaQuery.of(context).viewPadding.top;
    final language = context.watch<LanguageProvider>().language;
    final content = HomeHeaderContentMapper.build(
      patientName: patientName,
      banners: banners,
      tickerMessages: tickerMessages,
      language: language,
    );

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
                image: const DecorationImage(
                  image: AssetImage('assets/images/wellness_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                padding: EdgeInsets.fromLTRB(16, statusBarTop + 12, 16, 80),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF114784).withOpacity(0.85),
                      const Color(0xFF12A0C7).withOpacity(0.65),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeroHeaderWidget(
                      greeting: content.greeting,
                      patientName: content.displayName,
                    ),
                    const SizedBox(height: 20),
                    HomeHealthAlertWidget(
                      title: content.healthTipTitle,
                      message: content.healthTipMessage,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -17,
              child: HomeAnnouncementTickerWidget(
                items: tickerMessages,
                fallbackText: content.announcement,
                onItemTap: onTickerTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HomeMembershipCardWidget(
            patientName: patientName,
            registrationNumber: registrationNumber,
            onViewProfile: onViewProfile,
          ),
        ),
      ],
    );
  }
}

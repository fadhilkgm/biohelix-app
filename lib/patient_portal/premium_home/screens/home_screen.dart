import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:biohelix_app/core/l10n/app_strings.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/patient_portal/core/models/home_feed_models.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/premium_home/design/app_spacing.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/banner_carousel_widget.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/doctor_card_widget.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/home_top_hero_widget.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/lab_card_widget.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/offers_and_appointments_section_widget.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/quick_actions_grid_widget.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/section_header_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.banners,
    required this.doctors,
    required this.labTests,
    required this.labPackages,
    required this.apiBaseUrl,
    required this.onDoctorTap,
    required this.onLabTap,
    required this.onPackageTap,
    required this.onViewAllDoctors,
    required this.onViewAllLabTests,
    required this.onViewAllPackages,
    required this.onBannerTap,
    required this.patientName,
    required this.registrationNumber,
    required this.bookings,
    required this.onSeeAllAppointments,
    this.tickerMessages = const [],
    this.homeOffers = const [],
    required this.onTickerTap,
    required this.onOfferTap,
    required this.onActionTap,
  });

  final List<HomeBannerItem> banners;
  final List<DoctorListing> doctors;
  final List<LabTestItem> labTests;
  final List<LabPackageItem> labPackages;
  final String apiBaseUrl;
  final ValueChanged<DoctorListing> onDoctorTap;
  final ValueChanged<LabTestItem> onLabTap;
  final ValueChanged<LabPackageItem> onPackageTap;
  final VoidCallback onViewAllDoctors;
  final VoidCallback onViewAllLabTests;
  final VoidCallback onViewAllPackages;
  final ValueChanged<HomeBannerItem> onBannerTap;
  final String patientName;
  final String registrationNumber;
  final List<BookingItem> bookings;
  final VoidCallback onSeeAllAppointments;
  final List<TickerMessageItem> tickerMessages;
  final List<HomeOfferItem> homeOffers;
  final Future<void> Function(TickerMessageItem item) onTickerTap;
  final Future<void> Function(HomeOfferItem item) onOfferTap;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);

    return Column(
      children: [
        HomeTopHeroWidget(
          patientName: patientName,
          registrationNumber: registrationNumber,
          banners: banners,
          onViewProfile: () => onActionTap('profile'),
          tickerMessages: tickerMessages,
          onTickerTap: onTickerTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, AppSpacing.sectionGap, 16, 0),
          child: QuickActionsGridWidget(
            title: strings.quickActions,
            onActionTap: onActionTap,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, AppSpacing.sectionGap, 16, 0),
          child: Column(
            children: [
              BannerCarouselWidget(
                banners: banners,
                onFallbackTap: onViewAllDoctors,
                onBannerTap: onBannerTap,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeaderWidget(
                title: strings.featuredDoctors,
                subtitle: strings.bookAppointments,
                onViewAll: onViewAllDoctors,
                viewAllLabel: strings.viewAll,
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 340,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: doctors.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.listItemGap),
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    return SizedBox(
                      width: 216,
                      child: DoctorCardWidget(
                        doctor: doctor,
                        imageUrl: _resolveUrl(doctor.imageUrl),
                        onTap: () => onDoctorTap(doctor),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeaderWidget(
                title: strings.popularLabTests,
                subtitle: strings.accurateResults,
                onViewAll: onViewAllLabTests,
                viewAllLabel: strings.viewAll,
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: labTests.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.listItemGap),
                  itemBuilder: (context, index) {
                    final test = labTests[index];
                    return LabCardWidget(
                      title: test.testName,
                      category: test.categoryName,
                      imageUrl: _resolveUrl(test.imageUrl),
                      onTap: () => onLabTap(test),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeaderWidget(
                title: strings.popularPackages,
                subtitle: strings.curatedBundles,
                onViewAll: onViewAllPackages,
                viewAllLabel: strings.viewAll,
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: labPackages.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.listItemGap),
                  itemBuilder: (context, index) {
                    final package = labPackages[index];
                    return LabCardWidget(
                      title: package.name,
                      category: package.category ?? 'Package',
                      imageUrl: _resolveUrl(package.imageUrl),
                      onTap: () => onPackageTap(package),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              OffersAndAppointmentsSectionWidget(
                bookings: bookings,
                homeOffers: homeOffers,
                onOfferTap: onOfferTap,
                onSeeAllAppointments: onSeeAllAppointments,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final normalized = url.startsWith('/') ? url.substring(1) : url;
    return '$apiBaseUrl/$normalized';
  }
}

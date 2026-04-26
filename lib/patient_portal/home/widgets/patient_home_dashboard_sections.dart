part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _DashboardDiscoverySections extends StatelessWidget {
  const _DashboardDiscoverySections({
    required this.patientName,
    required this.registrationNumber,
    required this.membershipTier,
    required this.bloodGroup,
    required this.points,
    required this.banners,
    required this.doctors,
    required this.labTests,
    required this.labPackages,
    required this.bookings,
    required this.tickerMessages,
    required this.homeOffers,
    required this.onBannerTap,
    required this.onTickerTap,
    required this.onOfferTap,
    required this.onViewAllDoctors,
    required this.onViewAllLabTests,
    required this.onViewAllPackages,
    required this.onPackageTap,
    required this.onSeeAllAppointments,
    required this.onQuickActionTap,
    this.isLoading = false,
  });

  final String patientName;
  final String registrationNumber;
  final String membershipTier;
  final String? bloodGroup;
  final int points;
  final List<HomeBannerItem> banners;
  final List<DoctorListing> doctors;
  final List<LabTestItem> labTests;
  final List<LabPackageItem> labPackages;
  final List<BookingItem> bookings;
  final List<TickerMessageItem> tickerMessages;
  final List<HomeOfferItem> homeOffers;
  final Future<void> Function(HomeBannerItem banner) onBannerTap;
  final Future<void> Function(TickerMessageItem item) onTickerTap;
  final Future<void> Function(HomeOfferItem item) onOfferTap;
  final VoidCallback onViewAllDoctors;
  final VoidCallback onViewAllLabTests;
  final VoidCallback onViewAllPackages;
  final ValueChanged<LabPackageItem> onPackageTap;
  final VoidCallback onSeeAllAppointments;
  final ValueChanged<String> onQuickActionTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    return premium_home.HomeScreen(
      patientName: patientName,
      registrationNumber: registrationNumber,
      banners: banners,
      doctors: doctors,
      labTests: labTests,
      labPackages: labPackages,
      bookings: bookings,
      tickerMessages: tickerMessages,
      homeOffers: homeOffers,
      onTickerTap: onTickerTap,
      onOfferTap: onOfferTap,
      onActionTap: onQuickActionTap,
      apiBaseUrl: apiBase,
      isLoading: isLoading,
      onDoctorTap: (doctor) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _DoctorDetailPage(doctor: doctor),
          ),
        );
      },
      onLabTap: (test) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _LabTestDetailPage(test: test),
          ),
        );
      },
      onPackageTap: onPackageTap,
      onBannerTap: onBannerTap,
      onViewAllDoctors: onViewAllDoctors,
      onViewAllLabTests: onViewAllLabTests,
      onViewAllPackages: onViewAllPackages,
      onSeeAllAppointments: onSeeAllAppointments,
    );
  }
}

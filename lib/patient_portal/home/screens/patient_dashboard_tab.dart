part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.onNavigate,
    required this.onOpenDoctorsDirectory,
    required this.onOpenLabTestsDirectory,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenDoctorsDirectory;
  final VoidCallback onOpenLabTestsDirectory;

  List<DoctorListing> _resolveHomeDoctors(
    PatientPortalProvider portal,
    PatientDashboard dashboard,
  ) {
    if (portal.doctors.isNotEmpty) {
      return portal.doctors;
    }

    final sourceBookings = portal.bookings.isNotEmpty
        ? portal.bookings
        : dashboard.recentBookings;
    final doctorById = <int, DoctorListing>{};

    for (final booking in sourceBookings) {
      doctorById.putIfAbsent(
        booking.doctorId,
        () => DoctorListing(
          id: booking.doctorId,
          name: booking.doctorName,
          specialization: (booking.doctorSpecialization ?? '').isNotEmpty
              ? booking.doctorSpecialization!
              : 'General Consultation',
          availableTime: 'Contact hospital for timings',
        ),
      );
    }

    return doctorById.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SessionProvider, PatientPortalProvider>(
      builder: (context, session, portal, _) {
        final dashboard =
            portal.dashboard ?? _fallbackDashboard(session.patient);
        final homeDoctors = _resolveHomeDoctors(portal, dashboard);
        final targetHandler = _HomeFeedTargetHandler(
          context: context,
          portal: portal,
          homeDoctors: homeDoctors,
          onOpenDoctorsDirectory: onOpenDoctorsDirectory,
          onOpenLabTestsDirectory: onOpenLabTestsDirectory,
          onOpenPackageLandingPage: (packageTarget, isSpecific) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _BannerPackageLandingPage(
                  packageTarget: packageTarget,
                  isSpecific: isSpecific,
                ),
              ),
            );
          },
        );
        final quickActionHandler = _HomeQuickActionHandler(
          context: context,
          dashboard: dashboard,
          portal: portal,
          onOpenAssistant: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _AssistantPage()),
            );
          },
          onOpenRecords: (filter) =>
              PatientAppShell.of(context).openRecords(filter),
          onOpenBookings: () => onNavigate(2),
          onOpenDoctorsDirectory: onOpenDoctorsDirectory,
          onOpenLabOrder: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => LabBookingController(
                    patientName: dashboard.idCard.patientName,
                    tests: portal.labTests,
                  ),
                  child: const TestListScreen(),
                ),
              ),
            );
          },
          onOpenProfile: () => onNavigate(4),
        );

        return _DashboardDiscoverySections(
          patientName: dashboard.idCard.patientName,
          registrationNumber: dashboard.idCard.registrationNumber,
          membershipTier: dashboard.idCard.membershipTier,
          bloodGroup: dashboard.idCard.bloodGroup,
          points: dashboard.myClub.points,
          banners: portal.homeBanners,
          doctors: homeDoctors,
          labTests: portal.labTests,
          labPackages: portal.labPackages,
          bookings: dashboard.recentBookings,
          tickerMessages: portal.tickerMessages,
          homeOffers: portal.homeOffers,
          onBannerTap: targetHandler.openBanner,
          onTickerTap: targetHandler.openTickerMessage,
          onOfferTap: targetHandler.openOffer,
          onViewAllDoctors: onOpenDoctorsDirectory,
          onViewAllLabTests: onOpenLabTestsDirectory,
          onViewAllPackages: () {
            targetHandler.openPackageLanding();
          },
          onPackageTap: (package) {
            targetHandler.openPackageLanding(package.slug, true);
          },
          onSeeAllAppointments: () => onNavigate(2),
          onQuickActionTap: quickActionHandler.open,
        );
      },
    );
  }
}

class _BannerPackageLandingPage extends StatelessWidget {
  const _BannerPackageLandingPage({
    required this.packageTarget,
    required this.isSpecific,
  });

  final String? packageTarget;
  final bool isSpecific;



  @override
  Widget build(BuildContext context) {
    final target = (packageTarget ?? '').trim();

    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final normalizedTarget = target.toLowerCase();
        final packages = portal.labPackages.where((package) {
          if (!isSpecific || normalizedTarget.isEmpty) return true;
          return package.slug.toLowerCase() == normalizedTarget ||
              package.name.toLowerCase().contains(normalizedTarget);
        }).toList();

        // If specific package view and found exactly one, show detailed view
        if (isSpecific && packages.length == 1) {
          final package = packages.first;
          final imageUrl = (package.imageUrl ?? '').trim();
          
          return Scaffold(
            backgroundColor: Colors.white,
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 380,
                  pinned: true,
                  stretch: true,
                  backgroundColor: const Color(0xFF5A88F1),
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: Color(0xFF192233),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _fallbackHeroImage(),
                              )
                            : _fallbackHeroImage(),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    package.name,
                                    style: GoogleFonts.manrope(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF192233),
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F7FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${package.totalTests ?? package.includedTests.length} Tests Available',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        color: const Color(0xFF5A88F1),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${package.discountedPrice ?? package.basePrice}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF5A88F1),
                                  ),
                                ),
                                if (package.discountedPrice != null && package.discountedPrice! < package.basePrice)
                                  Text(
                                    '₹${package.basePrice}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      decoration: TextDecoration.lineThrough,
                                      color: const Color(0xFF192233).withOpacity(0.3),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Description',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF192233),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          package.description ?? 'This comprehensive health package is designed to provide a complete overview of your health status with multiple diagnostic parameters.',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            color: const Color(0xFF192233).withOpacity(0.6),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (package.includedTests.isNotEmpty) ...[
                          Text(
                            'Tests Included (${package.includedTests.length})',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF192233),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...package.includedTests.map((testName) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5E9F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: Color(0xFF5A88F1),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        testName,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF192233).withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                        const SizedBox(height: 120), // Bottom padding for button
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomSheet: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: portal.isCreatingLabOrder
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PackageBookingScreen(package: package),
                            ),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A88F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Book This Package',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Fallback for list of packages (the old view but with new colors)
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: const Text('Health Packages'),
            backgroundColor: const Color(0xFFF8F9FB),
            elevation: 0,
            centerTitle: true,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final package = packages[index];
              final adminImageUrl = (package.imageUrl ?? '').trim();

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: adminImageUrl.isNotEmpty
                            ? Image.network(
                                adminImageUrl,
                                fit: BoxFit.cover,
                              )
                            : _fallbackHeroImage(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  package.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF192233),
                                  ),
                                ),
                              ),
                              Text(
                                '₹${package.discountedPrice ?? package.basePrice}',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF5A88F1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${package.totalTests ?? package.includedTests.length} Tests Included',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: const Color(0xFF192233).withOpacity(0.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: portal.isCreatingLabOrder
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PackageBookingScreen(
                                                package: package,
                                              ),
                                        ),
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5A88F1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'View & Book',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _fallbackHeroImage() {
    return Container(
      color: const Color(0xFFF4F7FF),
      child: Center(
        child: Icon(
          Icons.health_and_safety_outlined,
          size: 80,
          color: const Color(0xFF5A88F1).withOpacity(0.2),
        ),
      ),
    );
  }
}

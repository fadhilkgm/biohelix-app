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

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            _DashboardDiscoverySections(
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
            ),
          ],
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

  Future<void> _openBookSheet(
    BuildContext context,
    PatientPortalProvider portal,
    LabPackageItem package,
  ) async {
    final doctorId = portal.doctors.isNotEmpty ? portal.doctors.first.id : null;
    if (doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No doctors are available right now. Try again later.'),
        ),
      );
      return;
    }

    String date = DateTime.now().toIso8601String().split('T').first;
    String slot = '';
    String collectionType = 'home';
    String address = portal.dashboard?.patient.address ?? '';
    List<String> slots = const [];
    bool loadingSlots = false;
    bool submitting = false;

    Future<void> loadSlots(StateSetter setModalState) async {
      if (date.isEmpty) {
        setModalState(() {
          slots = const [];
          slot = '';
        });
        return;
      }

      setModalState(() {
        loadingSlots = true;
      });

      try {
        final result = await portal.getDoctorAvailableSlots(
          doctorId: doctorId,
          date: date,
        );
        if (!context.mounted) return;
        setModalState(() {
          slots = result;
          if (!slots.contains(slot)) {
            slot = slots.isNotEmpty ? slots.first : '';
          }
        });
      } catch (_) {
        if (!context.mounted) return;
      } finally {
        if (!context.mounted) return;
        setModalState(() {
          loadingSlots = false;
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (slots.isEmpty && !loadingSlots) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  loadSlots(setModalState);
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Book ${package.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Quick package booking with auto-assigned clinician.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: date,
                        decoration: const InputDecoration(
                          labelText: 'Date (YYYY-MM-DD)',
                        ),
                        onChanged: (value) {
                          date = value.trim();
                          loadSlots(setModalState);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: collectionType,
                        decoration: const InputDecoration(
                          labelText: 'Collection type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'home',
                            child: Text('Home collection'),
                          ),
                          DropdownMenuItem(
                            value: 'lab',
                            child: Text('Lab visit'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => collectionType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      if (loadingSlots)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (slots.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: slot.isNotEmpty ? slot : slots.first,
                          decoration: const InputDecoration(labelText: 'Slot'),
                          items: slots
                              .map(
                                (availableSlot) => DropdownMenuItem(
                                  value: availableSlot,
                                  child: Text(availableSlot),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setModalState(() => slot = value ?? '');
                          },
                        ),
                      const SizedBox(height: 10),
                      if (collectionType == 'home')
                        TextFormField(
                          initialValue: address,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Collection address',
                          ),
                          onChanged: (value) => address = value.trim(),
                        ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  setModalState(() => submitting = true);
                                  try {
                                    await portal.createLabPackageOrder(
                                      labPackageId: package.id,
                                      doctorId: doctorId,
                                      date: date,
                                      slot: slot.isEmpty ? null : slot,
                                      collectionType: collectionType,
                                      address: collectionType == 'home'
                                          ? (address.isEmpty ? null : address)
                                          : null,
                                      amount:
                                          (package.discountedPrice ??
                                                  package.basePrice)
                                              .toDouble(),
                                      paymentStatus: 'pending',
                                    );
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '${package.name} booked successfully.',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(0xFF108E3E),
                                        margin: EdgeInsets.only(
                                          bottom: MediaQuery.of(context).size.height - 160,
                                          left: 20,
                                          right: 20,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(() => submitting = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            submitting ? 'Booking...' : 'Confirm booking',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

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

        const packageImages = <String>[
          'assets/images/1.png',
          'assets/images/2.jpg',
          'assets/images/3.jpg',
          'assets/images/2095622_284409-P6JXHD-940.jpg',
        ];

        String imageForPackage(LabPackageItem package, int index) {
          final slug = package.slug.toLowerCase();
          if (slug.contains('diabetes')) return 'assets/images/2.jpg';
          if (slug.contains('thyroid')) return 'assets/images/3.jpg';
          return packageImages[index % packageImages.length];
        }

        final heroImageUrl = packages
            .map((package) => (package.imageUrl ?? '').trim())
            .firstWhere((url) => url.isNotEmpty, orElse: () => '');

        return Scaffold(
          backgroundColor: const Color(0xFFF1F3F7),
          appBar: AppBar(
            title: const Text('Health Packages'),
            backgroundColor: const Color(0xFFF1F3F7),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F5E56), Color(0xFF178E81)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health Packages',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose a package and schedule sample collection in one flow.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: heroImageUrl.isNotEmpty
                            ? Image.network(
                                heroImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Image.asset(
                                  'assets/images/doctor-looking-clipboard/284409-P6JXHD-940.jpg',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/images/doctor-looking-clipboard/284409-P6JXHD-940.jpg',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (packages.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No active packages are available right now.'),
                  ),
                )
              else
                ...packages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final package = entry.value;
                  final imagePath = imageForPackage(package, index);
                  final adminImageUrl = (package.imageUrl ?? '').trim();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                          child: SizedBox(
                            height: 148,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                adminImageUrl.isNotEmpty
                                    ? Image.network(
                                        adminImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Image.asset(
                                          imagePath,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Image.asset(imagePath, fit: BoxFit.cover),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.05),
                                        Colors.black.withValues(alpha: 0.42),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 12,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          package.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Rs ${package.discountedPrice ?? package.basePrice}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                package.description ??
                                    'Comprehensive preventive package.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(height: 1.35),
                              ),
                              if (package.includedTests.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: package.includedTests
                                      .take(6)
                                      .map(
                                        (testName) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F7FA),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE4E8EE),
                                            ),
                                          ),
                                          child: Text(
                                            testName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F5E56),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: portal.isCreatingLabOrder
                                      ? null
                                      : () => _openBookSheet(
                                          context,
                                          portal,
                                          package,
                                        ),
                                  icon: const Icon(
                                    Icons.shopping_cart_checkout_rounded,
                                  ),
                                  label: const Text('Book package'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

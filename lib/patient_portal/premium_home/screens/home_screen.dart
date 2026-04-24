import 'package:flutter/material.dart';
import 'package:biohelix_app/patient_portal/core/models/home_feed_models.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';

class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedDepartment = 'All';

  List<String> get _departments {
    final depts = widget.doctors.map((d) => d.specialization).toSet().toList();
    depts.sort();
    return ['All', ...depts];
  }

  List<DoctorListing> get _filteredDoctors {
    if (_selectedDepartment == 'All') return widget.doctors;
    return widget.doctors
        .where((d) => d.specialization == _selectedDepartment)
        .toList();
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    
    // Fallback for relative paths
    final base = widget.apiBaseUrl.endsWith('/') 
        ? widget.apiBaseUrl.substring(0, widget.apiBaseUrl.length - 1) 
        : widget.apiBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$base$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // 1. Header (Greeting + Ticker)
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5A88F1), Color(0xFF759BF1)],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(40),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How are you today?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.patientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Ticker Messages (Replacing Banners/Search)
                  if (widget.tickerMessages.isNotEmpty)
                    SizedBox(
                      height: 48,
                      child: PageView.builder(
                        itemCount: widget.tickerMessages.length,
                        itemBuilder: (context, index) {
                          final ticker = widget.tickerMessages[index];
                          return InkWell(
                            onTap: () => widget.onTickerTap(ticker),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.tips_and_updates_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      '"${ticker.message}"',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // 2. Main Content Sections
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banners Carousel (Replacing Upcoming Consultations)
              if (widget.banners.isNotEmpty)
                SizedBox(
                  height: MediaQuery.of(context).size.width > 600 ? 320 : 200,
                  child: PageView.builder(
                    itemCount: widget.banners.length,
                    itemBuilder: (context, index) {
                      final banner = widget.banners[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Background Image
                              Image.network(
                                _resolveImageUrl(banner.imageUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF0F5E56), Color(0xFF178E81)],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.medical_services_outlined,
                                        color: Colors.white.withOpacity(0.2),
                                        size: 80,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Gradient Overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.1),
                                      Colors.black.withOpacity(0.75),
                                    ],
                                  ),
                                ),
                              ),
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      banner.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (banner.subtitle != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        banner.subtitle!,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    if (banner.ctaLabel != null) ...[
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () => widget.onBannerTap(banner),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF5A88F1),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          banner.ctaLabel!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 32),
              // Find Doctors Section
              const Text(
                'Find Doctors',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF192233),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _departments.map((dept) {
                    return _CategoryChip(
                      label: dept,
                      isActive: _selectedDepartment == dept,
                      onTap: () => setState(() => _selectedDepartment = dept),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              // Doctors Carousel
              if (_filteredDoctors.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('No doctors found in this department.'),
                  ),
                )
              else
                SizedBox(
                  height: 380,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredDoctors[index];
                      return _DoctorCard(
                        doc: doc,
                        onTap: () => widget.onDoctorTap(doc),
                        resolvedImageUrl: _resolveImageUrl(doc.imageUrl ?? ''),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorListing doc;
  final VoidCallback onTap;
  final String resolvedImageUrl;

  const _DoctorCard({
    required this.doc, 
    required this.onTap,
    required this.resolvedImageUrl,
  });

  IconData _getSpecialtyIcon(String spec) {
    final s = spec.toLowerCase();
    if (s.contains('cardio')) return Icons.monitor_heart_outlined;
    if (s.contains('derma')) return Icons.face_outlined;
    if (s.contains('gyne')) return Icons.supervised_user_circle_outlined;
    if (s.contains('pedi')) return Icons.child_care_outlined;
    if (s.contains('dentist')) return Icons.medical_services_outlined;
    if (s.contains('neuro')) return Icons.psychology_outlined;
    return Icons.medical_information_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFFE5E9F0),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(31)),
              child: SizedBox(
                height: 240, // Increased room for text below
                width: double.infinity,
                child: resolvedImageUrl.isNotEmpty
                    ? Image.network(
                        resolvedImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackImage(),
                      )
                    : _fallbackImage(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Info Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF192233),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _getSpecialtyIcon(doc.specialization),
                              size: 13,
                              color: const Color(0xFF192233).withOpacity(0.4),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                doc.specialization,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF192233).withOpacity(0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Button Section
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A88F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month_outlined, size: 16),
                        label: const Text(
                          'Book Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: double.infinity,
      height: 240,
      color: Colors.white,
      child: Image.asset(
        'assets/images/doctor-vector.png',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5A88F1) : const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF192233).withOpacity(0.6),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

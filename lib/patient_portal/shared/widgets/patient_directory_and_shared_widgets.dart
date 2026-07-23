part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _DoctorsDirectoryPage extends StatefulWidget {
  const _DoctorsDirectoryPage();

  @override
  State<_DoctorsDirectoryPage> createState() => _DoctorsDirectoryPageState();
}

class _DoctorsDirectoryPageState extends State<_DoctorsDirectoryPage> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Our Specialists',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF192233),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: Color(0xFF192233),
            size: 30,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<PatientPortalProvider>(
        builder: (context, portal, _) {
          final doctors = portal.doctors;

          // Filter doctors based on search query
          final filteredDoctors = _searchQuery.isEmpty
              ? doctors
              : doctors.where((doctor) {
                  final name = doctor.name.toLowerCase();
                  final specialization = doctor.specialization.toLowerCase();
                  final department = (doctor.departmentName ?? '')
                      .toLowerCase();
                  return name.contains(_searchQuery) ||
                      specialization.contains(_searchQuery) ||
                      department.contains(_searchQuery);
                }).toList();

          final doctorsByDepartment = <String, List<DoctorListing>>{};
          for (final doctor in filteredDoctors) {
            final department = (doctor.departmentName ?? '').trim().isEmpty
                ? 'General'
                : doctor.departmentName!.trim();
            doctorsByDepartment
                .putIfAbsent(department, () => <DoctorListing>[])
                .add(doctor);
          }
          final sortedDepartments = doctorsByDepartment.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          if (portal.isLoading && doctors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: portal.refresh,
            notificationPredicate: (_) => false,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF192233),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search for doctors...',
                      hintStyle: GoogleFonts.manrope(
                        color: const Color(0xFF192233).withValues(alpha: 0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F7),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF192233),
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Color(0xFF192233),
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF5A88F1),
                          width: 1.5,
                        ),
                      ),
                    ),
                    cursorColor: const Color(0xFF192233),
                  ),
                ),
                const SizedBox(height: 32),
                if (filteredDoctors.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No doctors available right now.'
                            : 'No doctors found matching "$_searchQuery"',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: const Color(0xFF192233).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                else
                  ...sortedDepartments.map((department) {
                    final departmentDoctors = doctorsByDepartment[department]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5A88F1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  department,
                                  style: GoogleFonts.manrope(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF192233),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${departmentDoctors.length} Doctors',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF5A88F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...departmentDoctors.map((doc) {
                            return _DoctorShortCard(
                              doc: doc,
                              apiBaseUrl: apiBase,
                            );
                          }),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DoctorShortCard extends StatelessWidget {
  final DoctorListing doc;
  final String apiBaseUrl;

  const _DoctorShortCard({required this.doc, required this.apiBaseUrl});

  @override
  Widget build(BuildContext context) {
    String resolveUrl(String? path) {
      if (path == null || path.isEmpty) return '';
      if (path.startsWith('http')) return path;
      final base = apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl;
      final normalizedPath = path.startsWith('/') ? path : '/$path';
      return '$base$normalizedPath';
    }

    final imageUrl = resolveUrl(doc.imageUrl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E9F0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _DoctorDetailPage(doctor: doc),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Doctor Image
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFF4F7FF),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                ),
                const SizedBox(width: 16),
                // Doctor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name,
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF192233),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doc.specialization,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5A88F1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: const Color(
                              0xFF192233,
                            ).withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              doc.availabilityWindowLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(
                                  0xFF192233,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Button
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF5A88F1),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFFF4F7FF),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: 50,
          color: const Color(0xFF5A88F1),
        ),
      ),
    );
  }
}

class _LabTestsDirectoryPage extends StatelessWidget {
  const _LabTestsDirectoryPage();

  @override
  Widget build(BuildContext context) {
    return const LabTestHomeScreen();
  }
}

part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _DoctorsDirectoryPage extends StatelessWidget {
  const _DoctorsDirectoryPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        title: const Text('View All Doctors'),
        backgroundColor: const Color(0xFFF4F7F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer<PatientPortalProvider>(
        builder: (context, portal, _) {
          final doctors = portal.doctors;
          final doctorsByDepartment = <String, List<DoctorListing>>{};
          for (final doctor in doctors) {
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2A7CCF), Color(0xFF1E9D8B)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find your specialist',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Book consultations with experienced doctors grouped by department.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (doctors.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No doctors available right now.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.builder(
                      itemCount: sortedDepartments.length,
                      itemBuilder: (context, index) {
                        final department = sortedDepartments[index];
                        final departmentDoctors =
                            doctorsByDepartment[department] ??
                            const <DoctorListing>[];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                department,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: departmentDoctors.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.72,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                    ),
                                itemBuilder: (context, doctorIndex) {
                                  return _DoctorCompactCard(
                                    doctor: departmentDoctors[doctorIndex],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LabTestsDirectoryPage extends StatelessWidget {
  const _LabTestsDirectoryPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        if (portal.isLoading && portal.labTests.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final patientName = portal.dashboard?.patient.name ?? 'Patient';
        return ChangeNotifierProvider(
          create: (_) => LabBookingController(
            patientName: patientName,
            tests: portal.labTests,
          ),
          child: Builder(
            builder: (context) {
              return TestListScreen(
                onTestTap: (bookableTest) {
                  final labTestItem = portal.labTests.firstWhere(
                    (lt) => lt.id == bookableTest.id,
                  );
                  final controller = context.read<LabBookingController>();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LabTestDetailPage(
                        test: labTestItem,
                        controller: controller,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}



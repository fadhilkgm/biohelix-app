part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

typedef _OpenPackageLandingPage =
    void Function(String? packageTarget, bool isSpecific);

class _HomeFeedTargetHandler {
  const _HomeFeedTargetHandler({
    required this.context,
    required this.portal,
    required this.homeDoctors,
    required this.onOpenDoctorsDirectory,
    required this.onOpenLabTestsDirectory,
    required this.onOpenPackageLandingPage,
  });

  final BuildContext context;
  final PatientPortalProvider portal;
  final List<DoctorListing> homeDoctors;
  final VoidCallback onOpenDoctorsDirectory;
  final VoidCallback onOpenLabTestsDirectory;
  final _OpenPackageLandingPage onOpenPackageLandingPage;

  void openPackageLanding([String? packageTarget, bool isSpecific = false]) {
    onOpenPackageLandingPage(packageTarget, isSpecific);
  }

  Future<void> openBanner(HomeBannerItem banner) {
    final target = (banner.ctaTarget ?? '').trim();
    if (target.isEmpty) {
      onOpenDoctorsDirectory();
      return Future.value();
    }
    return openTarget(target);
  }

  Future<void> openTickerMessage(TickerMessageItem item) {
    return openTarget(item.ctaTarget ?? '');
  }

  Future<void> openOffer(HomeOfferItem item) {
    return openTarget(item.ctaTarget ?? '');
  }

  Future<void> openTarget(String rawTarget) async {
    final raw = rawTarget.trim();
    if (raw.isEmpty) {
      _showMessage('No link configured for this item.');
      return;
    }

    final normalized = raw.toLowerCase();
    if (_openDirectoryTarget(normalized)) return;
    if (await _openExternalTarget(raw, normalized)) return;
    if (_openDoctorTarget(raw)) return;
    if (_openLabTestTarget(raw)) return;
    if (_openPackageTarget(raw, normalized)) return;
    if (raw.startsWith('/')) {
      _showMessage(
        'Web route targets are not supported in mobile. Use doctors, lab-tests, packages, or a full URL.',
      );
      return;
    }

    _showMessage(
      'Unknown target "$raw". Supported: doctors, lab-tests, doctor:id, test:id, packages, package:key, or https://...',
    );
  }

  bool _openDirectoryTarget(String normalized) {
    if (normalized == 'doctors' || normalized == 'doctor-list') {
      onOpenDoctorsDirectory();
      return true;
    }
    if (normalized == 'lab-tests' ||
        normalized == 'tests' ||
        normalized == 'test-list' ||
        normalized == 'labs') {
      onOpenLabTestsDirectory();
      return true;
    }
    if (normalized == 'packages' || normalized == 'package-list') {
      openPackageLanding();
      return true;
    }
    return false;
  }

  bool _openDoctorTarget(String raw) {
    final match = RegExp(
      r'^doctor[:/](\d+)$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return false;

    final id = int.tryParse(match.group(1) ?? '');
    if (id == null) {
      onOpenDoctorsDirectory();
      return true;
    }

    final doctor = _findDoctorById(
      portal.doctors.isNotEmpty ? portal.doctors : homeDoctors,
      id,
    );
    if (doctor == null) {
      _showMessage('Selected doctor is not available. Showing doctors list.');
      onOpenDoctorsDirectory();
      return true;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DoctorDetailPage(doctor: doctor),
      ),
    );
    return true;
  }

  bool _openLabTestTarget(String raw) {
    final match = RegExp(
      r'^(?:test|lab|lab-test)[:/](\d+)$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return false;

    final id = int.tryParse(match.group(1) ?? '');
    if (id == null) {
      onOpenLabTestsDirectory();
      return true;
    }

    final test = _findLabTestById(portal.labTests, id);
    if (test == null) {
      _showMessage('Selected lab test is not available. Showing tests list.');
      onOpenLabTestsDirectory();
      return true;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LabTestDetailPage(test: test)),
    );
    return true;
  }

  bool _openPackageTarget(String raw, String normalized) {
    if (normalized == 'packages' || normalized == 'package-list') {
      openPackageLanding();
      return true;
    }

    final match = RegExp(
      r'^package[:/](.+)$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return false;
    openPackageLanding(match.group(1), true);
    return true;
  }

  Future<bool> _openExternalTarget(String raw, String normalized) async {
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      return false;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      _showMessage('Invalid external URL: $raw');
      return true;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _showMessage('Unable to open link: $raw');
    }
    return true;
  }

  DoctorListing? _findDoctorById(List<DoctorListing> doctors, int id) {
    for (final doctor in doctors) {
      if (doctor.id == id) return doctor;
    }
    return null;
  }

  LabTestItem? _findLabTestById(List<LabTestItem> tests, int id) {
    for (final test in tests) {
      if (test.id == id) return test;
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

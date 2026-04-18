part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _HomeQuickActionHandler {
  const _HomeQuickActionHandler({
    required this.context,
    required this.dashboard,
    required this.portal,
    required this.onOpenAssistant,
    required this.onOpenRecords,
    required this.onOpenBookings,
    required this.onOpenDoctorsDirectory,
    required this.onOpenLabOrder,
    required this.onOpenProfile,
  });

  final BuildContext context;
  final PatientDashboard dashboard;
  final PatientPortalProvider portal;
  final VoidCallback onOpenAssistant;
  final ValueChanged<String> onOpenRecords;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenDoctorsDirectory;
  final VoidCallback onOpenLabOrder;
  final VoidCallback onOpenProfile;

  Future<void> open(String actionId) async {
    switch (actionId) {
      case 'ai_assistant':
        onOpenAssistant();
        return;
      case 'lab_reports':
        onOpenRecords('lab');
        return;
      case 'prescriptions':
        onOpenRecords('prescription');
        return;
      case 'discharge':
        onOpenRecords('summary');
        return;
      case 'id_card':
      case 'my_club':
        _openRewardsWallet();
        return;
      case 'ai_trend_analysis':
        _push(const _HealthTrendsPage(showAiInsights: true));
        return;
      case 'ai_package_design':
        _push(const _AiPackageDesignPage());
        return;

      case 'health_trends':
        _push(const _HealthTrendsPage(showAiInsights: false));
        return;
      case 'lab_test_order':
        onOpenLabOrder();
        return;
      case 'book_appointment':
        onOpenDoctorsDirectory();
        return;
      case 'profile':
        onOpenProfile();
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown quick action: $actionId')),
        );
    }
  }

  void _openRewardsWallet() {
    _push(
      PatientLoyaltyDetailsPage(
        idCard: dashboard.idCard,
        myClub: dashboard.myClub,
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

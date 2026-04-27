import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/custom_bottom_bar.dart';
import '../../core/widgets/custom_button.dart';
import '../../features/session/providers/session_provider.dart';
import '../core/data/patient_repository.dart';
import '../core/models/patient_models.dart';
import '../core/models/home_feed_models.dart';
import '../core/providers/patient_portal_provider.dart';
import '../lab_booking/models/lab_booking_models.dart' show BookableLabTest;
import '../lab_booking/screens/cart_screen.dart' show CartScreen;
import '../lab_booking/screens/test_list_screen.dart';
import '../lab_booking/state/lab_booking_controller.dart'
    show LabBookingController;
import '../premium_home/screens/home_screen.dart' as premium_home;
import 'widgets/bottom_nav_bar_widget.dart';
import '../my_club/screens/patient_loyalty_panel.dart';

part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_attachment_widget.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_chat_header.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_chat_input.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_chat_sidebar.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_design_system.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_helpers.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_message_bubble.dart';
part 'package:biohelix_app/patient_portal/assistant/screens/patient_assistant_tab.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_typing_indicator.dart';
part 'package:biohelix_app/patient_portal/bookings/actions/patient_bookings_actions.dart';
part 'package:biohelix_app/patient_portal/bookings/actions/patient_bookings_actions_reschedule.dart';
part 'package:biohelix_app/patient_portal/bookings/widgets/patient_bookings_actions_sheets.dart';
part 'package:biohelix_app/patient_portal/bookings/screens/patient_bookings_tab.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_banner.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_doctors.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_labs.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_widgets.dart';
part 'package:biohelix_app/patient_portal/doctors/screens/patient_dashboard_doctor_pages.dart';
part 'package:biohelix_app/patient_portal/labs/screens/patient_dashboard_lab_pages.dart';
part 'package:biohelix_app/patient_portal/home/actions/patient_home_feed_target_handler.dart';
part 'package:biohelix_app/patient_portal/shared/widgets/patient_dashboard_planner_models.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_shared_cards.dart';
part 'package:biohelix_app/patient_portal/home/screens/patient_dashboard_tab.dart';
part 'package:biohelix_app/patient_portal/shared/widgets/patient_directory_and_shared_widgets.dart';
part 'package:biohelix_app/patient_portal/profile/screens/patient_profile_redesign.dart';
part 'package:biohelix_app/patient_portal/profile/screens/patient_profile_redesign_sections.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_home_dashboard_sections.dart';
part 'package:biohelix_app/patient_portal/home/actions/patient_home_quick_action_handler.dart';
part 'package:biohelix_app/patient_portal/home/screens/patient_home_quick_action_pages.dart';
part 'package:biohelix_app/patient_portal/profile/screens/patient_profile_tab.dart';
part 'package:biohelix_app/patient_portal/records/screens/patient_records_tab.dart';
part 'package:biohelix_app/patient_portal/tests/screens/patient_tests_detail_widgets.dart';
part 'package:biohelix_app/patient_portal/tests/screens/patient_tests_tab.dart';

abstract class PatientAppShellController {
  void openRecords([String filter = 'all']);
  void goHome();
}

class PatientAppShell extends StatefulWidget {
  const PatientAppShell({super.key});

  static PatientAppShellController of(BuildContext context) {
    final state = context.findAncestorStateOfType<_PatientAppShellState>();
    assert(state != null, 'PatientAppShell state is not available.');
    return state!;
  }

  @override
  State<PatientAppShell> createState() => _PatientAppShellState();
}

class _PatientAppShellState extends State<PatientAppShell>
    implements PatientAppShellController {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_RecordsTabState> _recordsTabKey =
      GlobalKey<_RecordsTabState>();

  static const _navItems = [
    BottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    BottomNavItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      label: 'Records',
    ),
    BottomNavItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: 'Bookings',
    ),
    BottomNavItem(
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      label: 'My Club',
    ),
    BottomNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardTab(
        onNavigate: _setIndex,
        onOpenDoctorsDirectory: _openDoctorsDirectory,
        onOpenLabTestsDirectory: _openLabTestsDirectory,
      ),
      _RecordsTab(key: _recordsTabKey),
      const _BookingsTab(),
      const _MyClubTab(),
      _ProfileTab(onOpenTestsHub: _openTestsHub),
    ];

    return Consumer2<SessionProvider, PatientPortalProvider>(
      builder: (context, session, portal, _) {

        final statusStyle = _selectedIndex == 0
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: statusStyle,
          child: PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) {
                return;
              }
              await _handleBackPress();
            },
            child: Scaffold(
              key: _scaffoldKey,
              extendBodyBehindAppBar: _selectedIndex == 0,
              body: portal.isLoading && portal.dashboard == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: portal.refresh,
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: pages,
                      ),
                    ),
              bottomNavigationBar: BottomNavBarWidget(
                selectedIndex: _selectedIndex,
                onTap: _setIndex,
                items: _navItems,
              ),
            ),
          ),
        );
      },
    );
  }

  void _setIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleBackPress() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return;
    }

    if (_selectedIndex != 0) {
      _setIndex(0);
      return;
    }

    final shouldExit = await _showExitConfirmation();
    if (shouldExit && mounted) {
      await SystemNavigator.pop();
    }
  }

  Future<bool> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit BioHelix?'),
        content: const Text(
          'Press Stay to keep using the app, or Exit to close it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  @override
  void openRecords([String filter = 'all']) {
    _setIndex(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordsTabKey.currentState?.setFilter(filter);
    });
  }
  
  @override
  void goHome() {
    _setIndex(0);
  }

  void _openDoctorsDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _DoctorsDirectoryPage()),
    );
  }

  void _openLabTestsDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _LabTestsDirectoryPage()),
    );
  }

  void _openTestsHub() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _TestsHubPage()));
  }
}

class _TestsHubPage extends StatelessWidget {
  const _TestsHubPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tests')),
      body: const _TestsTab(),
    );
  }
}

PatientDashboard _fallbackDashboard(PatientIdentity? patient) {
  final identity =
      patient ??
      const PatientIdentity(
        id: 0,
        name: 'BHRC Patient',
        phone: '',
        registrationNumber: 'BHRC',
        uuid: '',
      );

  return PatientDashboard(
    patient: identity,
    metrics: const PortalMetrics(
      totalRecords: 0,
      availableRecords: 0,
      processingRecords: 0,
      showingRecords: 0,
      upcomingBookings: 0,
    ),
    recentBookings: const [],
    recentPrescriptions: const [],
    recentDocuments: const [],
    recentSummaries: const [],
    idCard: IdCardInfo(
      registrationNumber: identity.registrationNumber,
      patientName: identity.name,
      membershipTier: 'Classic',
      qrValue: identity.uuid,
      bloodGroup: identity.bloodGroup,
    ),
    myClub: MyClubSummary(
      patientId: identity.id,
      points: 0,
      currencyValue: 0,
      tier: 'Classic',
      transactions: const [],
    ),
    emergencyContacts: const [
      EmergencyContact(name: 'BHRC Ambulance', number: '+91 7510210222'),
      EmergencyContact(name: 'Hospital Reception', number: '+91 7510210224'),
      EmergencyContact(name: 'Emergency Helpline', number: '108'),
    ],
    latestVitals: null,
  );
}

class _AssistantPage extends StatelessWidget {
  const _AssistantPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health AI')),
      body: const _AssistantTab(),
    );
  }
}

class _MyClubTab extends StatelessWidget {
  const _MyClubTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<SessionProvider, PatientPortalProvider>(
      builder: (context, session, portal, _) {
        final dashboard =
            portal.dashboard ?? _fallbackDashboard(session.patient);

        return Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Club',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Rewards, benefits, and redemption history',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PatientLoyaltyDetailsContent(
                idCard: dashboard.idCard,
                myClub: dashboard.myClub,
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../assistant/voice/inworld_signaling_api.dart';
import '../assistant/voice/live_voice_conversation.dart';
import '../assistant/voice/live_voice_controller.dart';
import '../assistant/voice/live_voice_state.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/app_chevron_back_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/custom_bottom_bar.dart';
import '../../core/widgets/custom_button.dart';
import '../../features/session/providers/session_provider.dart';
import '../../features/onboarding/models/legal_content.dart';
import '../core/data/patient_repository.dart';
import '../core/models/patient_models.dart';
import '../core/models/home_feed_models.dart';
import '../core/providers/patient_portal_provider.dart';

import '../lab_booking/screens/package_booking_screen.dart';
import '../lab_booking/screens/lab_test_home_screen.dart';
import '../lab_booking/screens/test_booking_screen.dart';
import '../lab_booking/state/lab_booking_controller.dart';
import '../lab_booking/models/lab_booking_models.dart';
import '../labs/screens/lab_test_detail_page.dart';
import '../core/widgets/booking_success_screen.dart';
import '../premium_home/screens/home_screen.dart' as premium_home;
import '../records/screens/in_app_document_viewer.dart';
import '../shared/widgets/promotional_banner_dialog.dart';
import 'widgets/bottom_nav_bar_widget.dart';
import '../ai_checkup/screens/ai_checkup_tab.dart';
import '../ai_checkup/services/ai_checkup_service.dart';
import '../emergency/widgets/emergency_support_screen.dart';
import '../health_profile/screens/health_profile_screen.dart';
import '../health_profile/screens/health_status_tab.dart';
import '../my_club/screens/patient_loyalty_panel.dart';

part 'package:biohelix_app/patient_portal/home_care/screens/home_care_screen.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_attachment_widget.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_chat_header.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_chat_input.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_chat_sidebar.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_design_system.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_helpers.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_message_bubble.dart';
part 'package:biohelix_app/patient_portal/assistant/screens/patient_assistant_tab.dart';
part 'package:biohelix_app/patient_portal/assistant/widgets/patient_assistant_typing_indicator.dart';
part 'package:biohelix_app/patient_portal/bookings/actions/bookings_actions.dart';
part 'package:biohelix_app/patient_portal/bookings/actions/bookings_actions_reschedule.dart';
part 'package:biohelix_app/patient_portal/bookings/widgets/bookings_actions_sheets.dart';
part 'package:biohelix_app/patient_portal/bookings/screens/bookings_tab.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_banner.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_doctors.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_labs.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_discovery_widgets.dart';
part 'package:biohelix_app/patient_portal/doctors/screens/doctor_details_page.dart';
part 'package:biohelix_app/patient_portal/home/actions/patient_home_feed_target_handler.dart';
part 'package:biohelix_app/patient_portal/shared/widgets/patient_dashboard_planner_models.dart';
part 'package:biohelix_app/patient_portal/home/widgets/patient_dashboard_shared_cards.dart';
part 'package:biohelix_app/patient_portal/home/screens/patient_dashboard_tab.dart';
part 'package:biohelix_app/patient_portal/shared/widgets/patient_directory_and_shared_widgets.dart';
part 'package:biohelix_app/patient_portal/profile/screens/patient_profile_redesign.dart';
part 'package:biohelix_app/patient_portal/profile/screens/patient_profile_redesign_sections.dart';
part 'package:biohelix_app/patient_portal/profile/screens/family_members_screen.dart';
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
  void openAssistant();
  void openAiCheckup();
  void openBookings();
  void openPackages([String? packageTarget]);
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

  static List<BottomNavItem> _navItems(LocalizedStrings strings) => [
    BottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: strings.navHome,
    ),
    BottomNavItem(
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart_rounded,
      label: strings.navHealthStatus,
    ),
    BottomNavItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      label: strings.navRecords,
    ),
    BottomNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: strings.navProfile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final pages = [
      _DashboardTab(
        onNavigate: _setIndex,
        onOpenBookings: openBookings,
        onOpenDoctorsDirectory: _openDoctorsDirectory,
        onOpenLabTestsDirectory: _openLabTestsDirectory,
        onOpenHomeCare: _openHomeCare,
      ),
      HealthStatusTab(onBack: goHome),
      _RecordsTab(key: _recordsTabKey),
      _ProfileTab(onOpenTestsHub: _openTestsHub),
    ];

    return Consumer2<SessionProvider, PatientPortalProvider>(
      builder: (context, session, portal, _) {
        if (!portal.isLoading && portal.promotionalHomeBanners.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            PromotionalBannerLaunchGate.showOnce(
              context,
              portal.promotionalHomeBanners,
              onTap: _handlePromotionBannerTap,
            );
          });
        }

        const homeStatusBarColor = Color(0xFF06489B);
        final statusStyle = _selectedIndex == 0
            ? const SystemUiOverlayStyle(
                statusBarColor: homeStatusBarColor,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle(
                statusBarColor: Theme.of(context).scaffoldBackgroundColor,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              );

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
              body: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.paddingOf(context).top,
                    child: ColoredBox(
                      color: _selectedIndex == 0
                          ? homeStatusBarColor
                          : Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: portal.isLoading && portal.dashboard == null
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: portal.refresh,
                            notificationPredicate: (_) => false,
                            child: IndexedStack(
                              index: _selectedIndex,
                              children: pages,
                            ),
                          ),
                  ),
                ],
              ),
              bottomNavigationBar: BottomNavBarWidget(
                selectedIndex: _selectedIndex,
                onTap: _setIndex,
                items: _navItems(strings),
              ),
              floatingActionButton: _selectedIndex == 0
                  ? _AssistantFab(onTap: _openAssistant)
                  : null,
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

  // Public entry point used by child widgets (e.g. package suggestion cards)
  void setTab(int index) => _setIndex(index);

  void _handlePromotionBannerTap(HomeBannerItem banner) {
    final portal = context.read<PatientPortalProvider>();
    final targetHandler = _HomeFeedTargetHandler(
      context: context,
      portal: portal,
      homeDoctors: portal.doctors,
      onOpenDoctorsDirectory: _openDoctorsDirectory,
      onOpenLabTestsDirectory: _openLabTestsDirectory,
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
    targetHandler.openBanner(banner);
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
    final strings = AppStrings.of(context.read<LanguageProvider>().language);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.exitAppTitle),
        content: Text(strings.exitAppMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.stay),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.exitApp),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  @override
  void openRecords([String filter = 'all']) {
    _setIndex(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordsTabKey.currentState?.setFilter(filter);
    });
  }

  @override
  void goHome() {
    _setIndex(0);
  }

  @override
  void openAssistant() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _AssistantTabView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void openAiCheckup() {
    if (!context.read<AppConfig>().aiCheckupEnabled) {
      AppToast.show(
        context,
        message: 'AI Checkup is not available for this account yet.',
        type: AppToastType.info,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiCheckupTab(
          onOpenPackage: openPackages,
          onOpenDoctor: _openAiCheckupDoctor,
          onOpenTests: _openAiCheckupTests,
          onOpenEmergency: _openAiCheckupEmergency,
          onOpenSupport: _openAiCheckupSupport,
        ),
      ),
    );
  }

  void _openAiCheckupDoctor(
    AssessmentRecommendedDoctor recommendation,
    String? sourceAssessmentToken,
  ) {
    final doctors = context.read<PatientPortalProvider>().doctors;
    DoctorListing? doctor;
    for (final candidate in doctors) {
      if (candidate.id == recommendation.id) {
        doctor = candidate;
        break;
      }
    }

    if (doctor == null) {
      AppToast.show(
        context,
        message:
            'This doctor is no longer available. Please choose another specialist.',
        type: AppToastType.warning,
      );
      _openDoctorsDirectory();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DoctorDetailPage(
          doctor: doctor!,
          sourceAssessmentToken: sourceAssessmentToken,
        ),
      ),
    );
  }

  void _openAiCheckupTests(
    List<AssessmentRecommendedTest> recommendations,
    String? sourceAssessmentToken,
  ) {
    final recommendedIds = recommendations
        .map((test) => test.id)
        .where((id) => id > 0)
        .toSet();
    final ids = context
        .read<PatientPortalProvider>()
        .labTests
        .where((test) => test.status && recommendedIds.contains(test.id))
        .map((test) => test.id)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) {
      AppToast.show(
        context,
        message:
            'These tests are no longer available. Please review the current lab catalogue.',
        type: AppToastType.warning,
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabTestHomeScreen(
          initialTestIds: ids,
          sourceAssessmentToken: sourceAssessmentToken,
        ),
      ),
    );
  }

  void _openAiCheckupEmergency() {
    final dashboard = context.read<PatientPortalProvider>().dashboard;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencySupportScreen(
          patientName: dashboard?.patient.name ?? 'Patient',
          contacts: dashboard?.emergencyContacts ?? const [],
        ),
      ),
    );
  }

  void _openAiCheckupSupport() {
    const receptionNumber = '+91 7510210224';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hospital support',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'BHRC reception can review your request and guide you to an available doctor, test, or service.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 16),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.support_agent_rounded),
                title: Text(
                  'Hospital Reception',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(receptionNumber),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final launched = await launchUrl(
                      Uri(scheme: 'tel', path: receptionNumber),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!launched && sheetContext.mounted) {
                      AppToast.show(
                        sheetContext,
                        message: 'Please call $receptionNumber.',
                        type: AppToastType.info,
                      );
                    }
                  },
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call reception'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void openPackages([String? packageTarget]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BannerPackageLandingPage(
          packageTarget: packageTarget,
          isSpecific: packageTarget != null && packageTarget.trim().isNotEmpty,
        ),
      ),
    );
  }

  void _openAssistant() => openAssistant();

  @override
  void openBookings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BookingsTab(onBack: () => Navigator.of(context).pop()),
      ),
    );
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

  void _openHomeCare() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _HomeCareScreen()));
  }

  void _openTestsHub() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _TestsHubPage()));
  }
}

class _AssistantFab extends StatefulWidget {
  const _AssistantFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AssistantFab> createState() => _AssistantFabState();
}

class _AssistantFabState extends State<_AssistantFab>
    with SingleTickerProviderStateMixin {
  bool _hasPreloadedChat = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasPreloadedChat) return;
    _hasPreloadedChat = true;
    unawaited(context.read<PatientPortalProvider>().initializeChatThreads());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return Tooltip(
      message: strings.assistantTitle,
      child: Semantics(
        button: true,
        label: strings.assistantTitle,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06489B).withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final phase = _controller.value * math.pi * 2;
                  final bodyFloat = math.sin(phase) * 3;
                  final headLook = math.cos(phase);
                  final leftArmFloat = math.sin(phase + 0.8) * 4;
                  final rightArmFloat = math.sin(phase + math.pi + 0.8) * 4;

                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Transform.translate(
                        offset: Offset(headLook * 1.5, bodyFloat),
                        child: Transform.rotate(
                          angle: headLook * 0.075,
                          child: _mascotLayer('body'),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(-1, bodyFloat + leftArmFloat),
                        child: _mascotLayer('arm-left'),
                      ),
                      Transform.translate(
                        offset: Offset(1, bodyFloat + rightArmFloat),
                        child: _mascotLayer('arm-right'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mascotLayer(String name) {
    return Image.asset(
      'assets/images/health-ai/health-ai-mascot-$name.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _TestsHubPage extends StatelessWidget {
  const _TestsHubPage();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return Scaffold(
      appBar: AppBar(title: Text(strings.testsTitle)),
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

/// AI Assistant embedded as a bottom-nav tab (Home · Bookings · Reports ·
/// AI Assistant · Profile). Reuses the shared assistant chat surface.
class _AssistantTabView extends StatelessWidget {
  const _AssistantTabView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AiChatColors.background,
      body: _AssistantTab(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/patient_auth_flow.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../../patient_portal/shell/patient_app_shell.dart';
import '../../../patient_portal/core/providers/patient_portal_provider.dart';
import '../../../core/referrals/referral_link_provider.dart';
import '../../session/providers/session_provider.dart';
import '../../../patient_portal/ai_checkup/screens/initial_health_assessment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _loadedPatientId;
  bool _hasFinishedOnboardingThisLaunch = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _completeOnboarding() async {
    if (!mounted) return;
    setState(() {
      _hasFinishedOnboardingThisLaunch = true;
    });
  }

  void _resetOnboarding() {
    setState(() {
      _hasFinishedOnboardingThisLaunch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SessionProvider, PatientPortalProvider>(
      builder: (context, session, portal, _) {
        final hasPendingReferral =
            context.watch<ReferralLinkProvider?>()?.hasPendingReferral ?? false;
        final activePatientId = session.patient?.id;
        final hasAcceptedLegalConsent =
            session.patient?.hasAcceptedLegalConsent ?? false;
        final hasCompletedInitialHealthAssessment =
            session.patient?.hasCompletedInitialHealthAssessment ?? false;
        final shouldShowInitialHealthAssessment =
            session.shouldOfferInitialHealthAssessment &&
            !hasCompletedInitialHealthAssessment;

        if (session.isAuthenticated &&
            hasAcceptedLegalConsent &&
            !shouldShowInitialHealthAssessment &&
            activePatientId != null &&
            _loadedPatientId != activePatientId &&
            !portal.isLoading) {
          _loadedPatientId = activePatientId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<PatientPortalProvider>().loadPortal(
                waitForDeferred: false,
              );
            }
          });
        }

        if (!session.isAuthenticated) {
          _loadedPatientId = null;
        }

        if (session.isBootstrapping) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!session.isAuthenticated &&
            !_hasFinishedOnboardingThisLaunch &&
            !hasPendingReferral) {
          return OnboardingScreen(onCompleted: _completeOnboarding);
        }

        if (!session.isAuthenticated) {
          return PatientAuthFlow(onBackToOnboarding: _resetOnboarding);
        }

        if (!hasAcceptedLegalConsent) {
          return OnboardingScreen(
            consentOnly: true,
            onCompleted: session.acceptLegalConsent,
          );
        }

        if (shouldShowInitialHealthAssessment) {
          return const InitialHealthAssessmentScreen();
        }

        return PatientAppShell(key: ValueKey(session.patient?.id));
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/phone_utils.dart';
import '../../session/providers/session_provider.dart';
import 'login_page.dart';
import 'otp_page.dart';

// Routes between LoginPage and OtpPage based on session state.
class PatientAuthFlow extends StatefulWidget {
  const PatientAuthFlow({super.key, this.onBackToOnboarding});

  final VoidCallback? onBackToOnboarding;

  @override
  State<PatientAuthFlow> createState() => _PatientAuthFlowState();
}

class _PatientAuthFlowState extends State<PatientAuthFlow> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        final pendingPhone = session.pendingPhone?.trim() ?? '';
        final showOtp = pendingPhone.isNotEmpty;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: showOtp
              ? OtpPage(
                  key: ValueKey('otp_$pendingPhone'),
                  maskedPhone: maskPatientPhone(pendingPhone),
                  onBack: session.cancelPendingOtp,
                )
              : LoginPage(
                  key: const ValueKey('login_page'),
                  onBack: widget.onBackToOnboarding,
                ),
        );
      },
    );
  }
}

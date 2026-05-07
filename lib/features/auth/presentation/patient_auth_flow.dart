import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../session/providers/session_provider.dart';
import 'login_page.dart';
import 'otp_page.dart';

// Routes between LoginPage and OtpPage based on session state.
// Shows LoginPage when no OTP is pending; OtpPage after OTP is sent.
class PatientAuthFlow extends StatefulWidget {
  const PatientAuthFlow({super.key, this.onBackToOnboarding});

  final VoidCallback? onBackToOnboarding;

  @override
  State<PatientAuthFlow> createState() => _PatientAuthFlowState();
}

class _PatientAuthFlowState extends State<PatientAuthFlow> {
  String _maskedPhone = '';

  void _onOtpSent(String maskedPhone) {
    setState(() => _maskedPhone = maskedPhone);
  }

  void _onBack() {
    context.read<SessionProvider>().cancelPendingOtp();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        final otpPending = (session.pendingPhone ?? '').isNotEmpty;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: otpPending
              ? OtpPage(
                  key: const ValueKey('otp_page'),
                  maskedPhone: _maskedPhone,
                  onBack: _onBack,
                )
              : LoginPage(
                  key: const ValueKey('login_page'),
                  onOtpSent: _onOtpSent,
                  onBack: widget.onBackToOnboarding,
                ),
        );
      },
    );
  }
}

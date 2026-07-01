import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../session/providers/session_provider.dart';
import 'widgets/auth_form_widgets.dart';
import 'widgets/otp_input.dart';

// OTP verification screen with 6-box input.
class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.maskedPhone, required this.onBack});

  final String maskedPhone;
  final VoidCallback onBack;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  String _otp = '';

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    await context.read<SessionProvider>().verifyOtp(otp: _otp);
  }

  Future<void> _resend() async {
    final session = context.read<SessionProvider>();
    final strings = AppStrings.of(context.read<LanguageProvider>().language);
    if ((session.pendingPhone ?? '').isEmpty) return;
    await session.resendPendingOtp();
    if (!mounted) return;
    final message = session.otpStatusMessage ?? strings.otpResentDefault;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDevOtp = context.read<AppConfig>().showDevOtp;
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0F4FF), Colors.white],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Consumer<SessionProvider>(
              builder: (context, session, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 100, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            strings.otpVerifyTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF192233),
                              height: 1.1,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(
                                  0xFF192233,
                                ).withValues(alpha: 0.6),
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(text: strings.otpSentPrefix),
                                TextSpan(
                                  text: widget.maskedPhone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF192233),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 50),
                          Text(
                            strings.otpEnterLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Color(0xFF192233),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OtpInput(
                            onChanged: (v) => setState(() => _otp = v),
                            onCompleted: (v) {
                              setState(() => _otp = v);
                              _verify();
                            },
                          ),
                          if (showDevOtp && (session.devOtp ?? '').isNotEmpty) ...[
                            const SizedBox(height: 32),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    strings.otpDevLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    session.devOtp!,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 8,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if ((session.errorMessage ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            AuthErrorText(message: session.errorMessage!),
                          ],
                          const SizedBox(height: 54),
                          SizedBox(
                            width: double.infinity,
                            child: AuthPrimaryButton(
                              label: strings.otpVerifyButton,
                              isLoading: session.isVerifyingOtp,
                              onPressed: _verify,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                strings.otpDidntReceive,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: const Color(
                                    0xFF192233,
                                  ).withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: session.isSendingOtp ? null : _resend,
                                child: Text(
                                  strings.otpResend,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF537DE8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../session/providers/session_provider.dart';
import 'widgets/auth_gradient_scaffold.dart';
import 'widgets/auth_header.dart';
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
    final phone = session.pendingPhone ?? '';
    final mrn = session.pendingMrn ?? '';
    if (phone.isEmpty || mrn.isEmpty) return;
    await session.sendOtp(phone: phone, mrn: mrn);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OTP resent')));
  }

  @override
  Widget build(BuildContext context) {
    final showDevOtp = context.read<AppConfig>().showDevOtp;

    return AuthGradientScaffold(
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(compact: true),
          Consumer<SessionProvider>(
            builder: (context, session, _) {
              return AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify OTP',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        children: [
                          const TextSpan(
                            text: 'A 6-digit code has been sent to\n',
                          ),
                          TextSpan(
                            text: widget.maskedPhone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ENTER OTP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OtpInput(
                      onChanged: (v) => setState(() => _otp = v),
                      onCompleted: (v) {
                        setState(() => _otp = v);
                        _verify();
                      },
                    ),
                    if (showDevOtp && (session.devOtp ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'DEVELOPMENT OTP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: Color(0xFF047857),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              session.devOtp!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if ((session.errorMessage ?? '').isNotEmpty) ...[
                      AuthErrorText(message: session.errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Verify OTP',
                      isLoading: session.isVerifyingOtp,
                      onPressed: _verify,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't receive? ",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        GestureDetector(
                          onTap: session.isSendingOtp ? null : _resend,
                          child: const Text(
                            'Resend OTP',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B2867),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

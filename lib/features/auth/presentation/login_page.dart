import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../session/providers/session_provider.dart';
import 'widgets/auth_gradient_scaffold.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_form_widgets.dart';

// Login screen: mobile number + MRN → triggers OTP send.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onOtpSent});

  final void Function(String maskedPhone) onOtpSent;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _mrnController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _mrnController.dispose();
    super.dispose();
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '****';
    return '****${digits.substring(digits.length - 4)}';
  }

  Future<void> _submit() async {
    final session = context.read<SessionProvider>();
    await session.sendOtp(
      phone: _phoneController.text,
      mrn: _mrnController.text,
    );
    if (!mounted) return;
    if (session.errorMessage == null && session.pendingPhone != null) {
      widget.onOtpSent(_maskPhone(_phoneController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGradientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(),
          AuthCard(
            child: Consumer<SessionProvider>(
              builder: (context, session, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to access your health records',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: _phoneController,
                      label: 'Mobile Number',
                      hint: 'Enter your mobile number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _mrnController,
                      label: 'MRN Number',
                      hint: 'e.g. BH000001',
                    ),
                    if ((session.errorMessage ?? '').isNotEmpty) ...[
                      AuthErrorText(message: session.errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Send OTP',
                      isLoading: session.isSendingOtp,
                      onPressed: _submit,
                    ),
                    const AuthDemoHint(
                      text: 'Demo: Any number + MRN BH000001',
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          _BrandFooter(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Biohelix Health & Research Center',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        SizedBox(height: 2),
        Text(
          'Thiruvananthapuram, Kerala',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

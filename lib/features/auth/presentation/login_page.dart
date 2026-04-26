import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../session/providers/session_provider.dart';
import 'widgets/auth_form_widgets.dart';

// Login screen: mobile number + MRN → triggers OTP send.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onOtpSent, this.onBack});

  final void Function(String maskedPhone) onOtpSent;
  final VoidCallback? onBack;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
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
    );
    if (!mounted) return;
    if (session.errorMessage == null && session.pendingPhone != null) {
      widget.onOtpSent(_maskPhone(_phoneController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient
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

          // Main Scrollable Content
          SafeArea(
            child: Consumer<SessionProvider>(
              builder: (context, session, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 80, 28, 40), // 2rem top space
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center, // Centered header
                    children: [
                      // Fixed Logo Styling
                      SizedBox(
                        width: 180,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset(
                            'assets/images/bhrc-logo.jpg',
                            fit: BoxFit.contain, // Prevent cropping
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Brand Name
                      const Text(
                        'Biohelix',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF192233),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Health And Research Center\nPonnani, Malappuram',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Login Section (Left aligned)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF192233),
                                height: 1.1,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enter your mobile number to access your health records and book appointments.',
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(0xFF192233).withOpacity(0.6),
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 40),
                            AuthTextField(
                              controller: _phoneController,
                              label: 'Mobile Number',
                              hint: 'Enter your mobile number',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_android_rounded,
                            ),
                            if ((session.errorMessage ?? '').isNotEmpty) ...[
                              AuthErrorText(message: session.errorMessage!),
                            ],
                            const SizedBox(height: 40),
                            AuthPrimaryButton(
                              label: 'Continue',
                              isLoading: session.isSendingOtp,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 20),
                            const AuthDemoHint(
                              text: 'Demo: Enter any mobile number',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.maybePop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left_rounded, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



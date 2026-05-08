import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../session/providers/session_provider.dart';
import 'widgets/auth_form_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onOtpSent, this.onBack});

  final void Function(String maskedPhone) onOtpSent;
  final VoidCallback? onBack;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _placeController = TextEditingController();
  bool _isSignup = false;
  bool _didPrefillDevLogin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrefillDevLogin) return;

    final showDevOtp = context.read<AppConfig>().showDevOtp;
    if (showDevOtp) {
      _phoneController.text = '7034598461';
    }
    _didPrefillDevLogin = true;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '****';
    return '****${digits.substring(digits.length - 4)}';
  }

  Future<void> _submit() async {
    final session = context.read<SessionProvider>();

    if (_isSignup) {
      await session.signUp(
        phone: _phoneController.text,
        name: _nameController.text,
        dob: _dobController.text,
        place: _placeController.text,
      );
    } else {
      await session.sendOtp(phone: _phoneController.text);
    }

    if (!mounted) return;

    if (_isSignup &&
        (session.errorMessage ?? '').toLowerCase().contains('already')) {
      setState(() => _isSignup = false);
      return;
    }

    if (session.errorMessage == null && session.pendingPhone != null) {
      widget.onOtpSent(_maskPhone(_phoneController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDevOtp = context.read<AppConfig>().showDevOtp;

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
                  padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset(
                            'assets/images/bhrc-logo.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSignup ? 'Sign up' : 'Login',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF192233),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isSignup
                                  ? 'Create your patient account to access appointments and health records.'
                                  : 'Enter your mobile number to access your health records and book appointments.',
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(0xFF192233)
                                    .withValues(alpha: 0.6),
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
                            if (_isSignup) ...[
                              const SizedBox(height: 20),
                              AuthTextField(
                                controller: _nameController,
                                label: 'Name',
                                hint: 'Enter your full name',
                                keyboardType: TextInputType.name,
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 20),
                              AuthTextField(
                                controller: _dobController,
                                label: 'Date of Birth',
                                hint: 'YYYY-MM-DD',
                                keyboardType: TextInputType.datetime,
                                prefixIcon: Icons.calendar_today_rounded,
                              ),
                              const SizedBox(height: 20),
                              AuthTextField(
                                controller: _placeController,
                                label: 'Place',
                                hint: 'Enter your place',
                                keyboardType: TextInputType.streetAddress,
                                prefixIcon: Icons.location_on_outlined,
                              ),
                            ],
                            if ((session.errorMessage ?? '').isNotEmpty) ...[
                              AuthErrorText(message: session.errorMessage!),
                            ],
                            const SizedBox(height: 40),
                            AuthPrimaryButton(
                              label: _isSignup
                                  ? 'Sign up and send OTP'
                                  : 'Continue',
                              isLoading: session.isSendingOtp,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: TextButton(
                                onPressed: session.isSendingOtp
                                    ? null
                                    : () {
                                        context
                                            .read<SessionProvider>()
                                            .cancelPendingOtp();
                                        setState(() => _isSignup = !_isSignup);
                                      },
                                child: Text(
                                  _isSignup
                                      ? 'Already registered? Login'
                                      : 'New patient? Sign up',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF537DE8),
                                  ),
                                ),
                              ),
                            ),
                            AuthDemoHint(
                              text: showDevOtp
                                  ? 'Demo login is prefilled for local testing.'
                                  : 'Use the mobile number registered at the hospital.',
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
                  color: Colors.white.withValues(alpha: 0.8),
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

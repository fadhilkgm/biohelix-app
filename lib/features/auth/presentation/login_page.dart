import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../session/providers/session_provider.dart';
import 'widgets/auth_form_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _genderController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  bool _isSignup = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _genderController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionProvider>();
    if (_isSignup) {
      await session.register(
        phone: _phoneController.text,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
        fullName: _nameController.text,
        dateOfBirth: _dobController.text,
        email: _emailController.text,
        gender: _genderController.text,
        bloodGroup: _bloodGroupController.text,
      );
    } else {
      await session.login(
        phone: _phoneController.text,
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      const SizedBox(height: 48),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSignup ? 'Create account' : 'Login',
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF192233),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isSignup
                                  ? 'Register your patient profile and start booking doctors, lab tests, and health packages.'
                                  : 'Sign in with your mobile number and password to continue.',
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(
                                  0xFF192233,
                                ).withValues(alpha: 0.6),
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (_isSignup) ...[
                              AuthTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                hint: 'Aisha Rahman',
                                keyboardType: TextInputType.name,
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 18),
                            ],
                            AuthTextField(
                              controller: _phoneController,
                              label: 'Mobile Number',
                              hint: '+919876543210',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_android_rounded,
                            ),
                            const SizedBox(height: 18),
                            AuthTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter password',
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            if (_isSignup) ...[
                              const SizedBox(height: 18),
                              AuthTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: 'Re-enter password',
                                obscureText: _obscurePassword,
                                keyboardType: TextInputType.visiblePassword,
                                prefixIcon: Icons.verified_user_outlined,
                              ),
                              const SizedBox(height: 18),
                              AuthTextField(
                                controller: _dobController,
                                label: 'Date of Birth',
                                hint: '1994-04-12',
                                keyboardType: TextInputType.datetime,
                                prefixIcon: Icons.calendar_today_rounded,
                              ),
                              const SizedBox(height: 18),
                              AuthTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'aisha.rahman@example.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: AuthTextField(
                                      controller: _genderController,
                                      label: 'Gender',
                                      hint: 'female',
                                      keyboardType: TextInputType.text,
                                      prefixIcon: Icons.wc_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AuthTextField(
                                      controller: _bloodGroupController,
                                      label: 'Blood Group',
                                      hint: 'O+',
                                      keyboardType: TextInputType.text,
                                      prefixIcon: Icons.bloodtype_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if ((session.errorMessage ?? '').isNotEmpty)
                              AuthErrorText(message: session.errorMessage!),
                            const SizedBox(height: 32),
                            AuthPrimaryButton(
                              label: _isSignup ? 'Register' : 'Login',
                              isLoading: session.isSubmittingAuth,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: TextButton(
                                onPressed: session.isSubmittingAuth
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
                                      : 'New patient? Register',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF537DE8),
                                  ),
                                ),
                              ),
                            ),
                            AuthDemoHint(
                              text: _isSignup
                                  ? 'Registration returns a secure patient token from BHRC.'
                                  : 'Use the phone and password created in the hospital system.',
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../session/providers/session_provider.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_card.dart';

class PatientAuthScreen extends StatefulWidget {
  const PatientAuthScreen({super.key});

  @override
  State<PatientAuthScreen> createState() => _PatientAuthScreenState();
}

class _PatientAuthScreenState extends State<PatientAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showLoginForm = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDevOtp = context.read<AppConfig>().showDevOtp;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<SessionProvider>(
            builder: (context, session, _) {
              final otpRequested = (session.pendingPhone ?? '').isNotEmpty;
              final showLoginForm = _showLoginForm || otpRequested;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.local_hospital_rounded,
                          size: 44,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to BioHelix',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          showLoginForm
                              ? (otpRequested
                                  ? 'Enter the OTP sent to ${session.pendingPhone} to continue.'
                                  : 'Sign in with your mobile number to access your records and appointments.')
                              : 'Track appointments, reports, and prescriptions from one place.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: !showLoginForm
                              ? Container(
                                  key: const ValueKey('welcome_view'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Patient Portal',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Secure mobile access for appointments, records, and prescriptions.',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: CustomButton(
                                          onPressed: () => setState(() {
                                            _showLoginForm = true;
                                          }),
                                          isOutlined: false,
                                          onDark: false,
                                          text: 'Login',
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : CustomCard(
                                  key: const ValueKey('login_form_view'),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!otpRequested)
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _showLoginForm = false;
                                            });
                                          },
                                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                          label: const Text('Back'),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          otpRequested ? 'Step 2 of 2' : 'Step 1 of 2',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: theme.colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      CustomTextField(
                                        controller: _phoneController,
                                        label: 'Mobile number',
                                        hintText: 'Enter mobile number',
                                        prefixIcon: const Icon(Icons.phone_android_rounded),
                                        keyboardType: TextInputType.phone,
                                        readOnly: otpRequested,
                                      ),
                                      if (otpRequested) ...[
                                        CustomTextField(
                                          controller: _otpController,
                                          label: 'OTP',
                                          hintText: 'Enter 6-digit OTP',
                                          prefixIcon: const Icon(Icons.lock_open_rounded),
                                          keyboardType: TextInputType.number,
                                        ),
                                        if (showDevOtp && (session.devOtp ?? '').isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Dev OTP: ${session.devOtp}',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                      if ((session.errorMessage ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          session.errorMessage!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: CustomButton(
                                          onPressed: () async {
                                            final messenger = ScaffoldMessenger.of(context);
                                            try {
                                              if (otpRequested) {
                                                await context.read<SessionProvider>().verifyOtp(
                                                      otp: _otpController.text,
                                                    );
                                              } else {
                                                await context
                                                    .read<SessionProvider>()
                                                    .sendOtp(
                                                      phone: _phoneController.text,
                                                    );
                                                if (context.mounted) {
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        showDevOtp
                                                            ? 'OTP sent. Check the dev OTP banner below.'
                                                            : 'OTP sent successfully.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            } catch (_) {}
                                          },
                                          text: otpRequested ? 'Verify and Sign In' : 'Send OTP',
                                          isLoading: session.isSendingOtp || session.isVerifyingOtp,
                                          icon: Icon(
                                            otpRequested
                                                ? Icons.verified_user_rounded
                                                : Icons.send_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (otpRequested) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: CustomButton(
                                            isOutlined: true,
                                            onPressed: session.isSendingOtp || session.isVerifyingOtp
                                                ? null
                                                : () {
                                                    _otpController.clear();
                                                    _phoneController.clear();
                                                    context.read<SessionProvider>().cancelPendingOtp();
                                                  },
                                            icon: Icon(
                                              Icons.restart_alt_rounded,
                                              color: theme.primaryColor,
                                            ),
                                            text: 'Use a different number',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

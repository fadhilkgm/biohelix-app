import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/app_logo.dart';
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
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _placeController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;
  final Map<String, String> _fieldErrors = {};
  bool _isSignup = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _placeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  List<AuthDropdownOption> _genderOptions(LocalizedStrings strings) {
    final labels = strings.genderOptions;
    return [
      AuthDropdownOption(value: 'female', label: labels[0]),
      AuthDropdownOption(value: 'male', label: labels[1]),
      AuthDropdownOption(value: 'other', label: labels[2]),
    ];
  }

  List<AuthDropdownOption> _bloodGroupOptions(LocalizedStrings strings) {
    return strings.bloodGroupOptions
        .map((group) => AuthDropdownOption(value: group, label: group))
        .toList();
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDateOfBirth(LocalizedStrings strings) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: strings.chooseDateOfBirth,
      cancelText: strings.cancel,
    );
    if (selected == null) return;
    setState(() {
      _dobController.text = _formatDate(selected);
      _fieldErrors.remove('dob');
    });
  }

  bool _validate(LocalizedStrings strings) {
    final errors = <String, String>{};
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (phone.isEmpty) {
      errors['phone'] = strings.fieldRequired;
    }

    if (_isSignup) {
      if (_nameController.text.trim().isEmpty) {
        errors['name'] = strings.fieldRequired;
      }
      if (_dobController.text.trim().isEmpty) {
        errors['dob'] = strings.fieldRequired;
      }
      if (_placeController.text.trim().isEmpty) {
        errors['place'] = strings.fieldRequired;
      }
      if ((_selectedGender ?? '').isEmpty) {
        errors['gender'] = strings.fieldRequired;
      }
      if ((_selectedBloodGroup ?? '').isEmpty) {
        errors['bloodGroup'] = strings.fieldRequired;
      }
      if (email.isNotEmpty && !email.contains('@')) {
        errors['email'] = strings.enterValidEmail;
      }
    }

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
    });

    return errors.isEmpty;
  }

  bool _looksLikeDuplicate(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already') ||
        lower.contains('taken') ||
        lower.contains('exist') ||
        lower.contains('registered');
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context.read<LanguageProvider>().language);
    if (!_validate(strings)) return;

    final session = context.read<SessionProvider>();
    if (_isSignup) {
      await session.signUp(
        phone: _phoneController.text,
        name: _nameController.text,
        dob: _dobController.text,
        place: _placeController.text,
        email: _emailController.text,
        gender: _selectedGender,
        bloodGroup: _selectedBloodGroup,
      );

      final error = session.errorMessage ?? '';
      if (error.isNotEmpty && _looksLikeDuplicate(error)) {
        final lower = error.toLowerCase();
        setState(() {
          if (lower.contains('email')) {
            _fieldErrors['email'] = 'This email is already registered.';
          } else if (lower.contains('phone') || lower.contains('mobile')) {
            _fieldErrors['phone'] = 'This mobile number is already registered.';
          } else {
            _fieldErrors['phone'] = error;
          }
        });
        session.clearError();
      }
      return;
    }

    await session.sendOtp(phone: _phoneController.text);

    final error = session.errorMessage ?? '';
    if (error.isNotEmpty && mounted) {
      final message = _looksLikeDuplicate(error) || error.toLowerCase().contains('not found')
          ? 'This mobile number is not registered. Please register first.'
          : error;
      session.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: EdgeInsets.fromLTRB(28, _isSignup ? 60 : 40, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const AppLogo(
                        width: 180,
                        height: 80,
                        borderRadius: 5,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.biohelix,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF192233),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.hospitalLocation,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isSignup
                                  ? strings.createAccountTitle
                                  : strings.loginTitle,
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
                                  ? strings.registerSubtitle
                                  : strings.loginSubtitle,
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
                                key: const ValueKey('field_name'),
                                controller: _nameController,
                                label: strings.fullName,
                                hint: strings.fullNameHint,
                                keyboardType: TextInputType.name,
                                prefixIcon: Icons.person_outline_rounded,
                                errorText: _fieldErrors['name'],
                              ),
                              const SizedBox(height: 18),
                            ],
                            AuthTextField(
                              key: const ValueKey('field_phone'),
                              controller: _phoneController,
                              label: strings.mobileNumber,
                              hint: strings.mobileNumberHint,
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_android_rounded,
                              errorText: _fieldErrors['phone'],
                            ),
                            if (_isSignup) ...[
                              const SizedBox(height: 18),
                              AuthTextField(
                                key: const ValueKey('field_dob'),
                                controller: _dobController,
                                label: strings.dateOfBirth,
                                hint: strings.dateOfBirthHint,
                                keyboardType: TextInputType.datetime,
                                prefixIcon: Icons.calendar_today_rounded,
                                suffixIcon: const Icon(
                                  Icons.event_available_rounded,
                                  color: Color(0xFF537DE8),
                                ),
                                errorText: _fieldErrors['dob'],
                                readOnly: true,
                                onTap: () => _pickDateOfBirth(strings),
                              ),
                              const SizedBox(height: 18),
                              AuthTextField(
                                key: const ValueKey('field_email'),
                                controller: _emailController,
                                label: strings.email,
                                hint: strings.emailHint,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                errorText: _fieldErrors['email'],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: AuthDropdownField(
                                      key: const ValueKey('field_gender'),
                                      value: _selectedGender,
                                      label: strings.gender,
                                      hint: strings.genderHint,
                                      items: _genderOptions(strings),
                                      prefixIcon: Icons.wc_rounded,
                                      errorText: _fieldErrors['gender'],
                                      onChanged: (value) => setState(() {
                                        _selectedGender = value;
                                        _fieldErrors.remove('gender');
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AuthDropdownField(
                                      key: const ValueKey('field_blood_group'),
                                      value: _selectedBloodGroup,
                                      label: strings.bloodGroup,
                                      hint: strings.bloodGroupHint,
                                      items: _bloodGroupOptions(strings),
                                      prefixIcon: Icons.bloodtype_outlined,
                                      errorText: _fieldErrors['bloodGroup'],
                                      onChanged: (value) => setState(() {
                                        _selectedBloodGroup = value;
                                        _fieldErrors.remove('bloodGroup');
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              AuthTextField(
                                key: const ValueKey('field_place'),
                                controller: _placeController,
                                label: strings.cityLocation,
                                hint: strings.cityLocationHint,
                                keyboardType: TextInputType.streetAddress,
                                prefixIcon: Icons.location_on_outlined,
                                errorText: _fieldErrors['place'],
                              ),
                            ],
                            if (_isSignup && (session.errorMessage ?? '').isNotEmpty)
                              AuthErrorText(message: session.errorMessage!),
                            const SizedBox(height: 32),
                            AuthPrimaryButton(
                              label: _isSignup
                                  ? strings.registerWithWhatsAppOtp
                                  : strings.sendWhatsAppOtp,
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
                                        setState(() {
                                          _isSignup = !_isSignup;
                                          _fieldErrors.clear();
                                        });
                                      },
                                child: Text(
                                  _isSignup
                                      ? strings.alreadyRegisteredLogin
                                      : strings.newPatientRegister,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF537DE8),
                                  ),
                                ),
                              ),
                            ),
                            AuthDemoHint(
                              text: _isSignup
                                  ? strings.registerDemoHint
                                  : strings.loginDemoHint,
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

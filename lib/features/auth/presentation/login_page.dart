import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart' show AppLanguage;
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
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _placeController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;
  final Map<String, String> _fieldErrors = {};
  bool _isSignup = false;
  bool _whatsappSignup = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
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
    final password = _passwordController.text;
    final email = _emailController.text.trim();

    if (phone.isEmpty) {
      errors['phone'] = strings.fieldRequired;
    }
    if (!_whatsappSignup && password.isEmpty) {
      errors['password'] = strings.fieldRequired;
    } else if (_isSignup && !_whatsappSignup && password.length < 8) {
      errors['password'] = strings.passwordMinLength;
    }

    if (_isSignup) {
      if (_nameController.text.trim().isEmpty) {
        errors['name'] = strings.fieldRequired;
      }
      if (_dobController.text.trim().isEmpty) {
        errors['dob'] = strings.fieldRequired;
      }
      if (_whatsappSignup && _placeController.text.trim().isEmpty) {
        errors['place'] = strings.fieldRequired;
      }
      if (!_whatsappSignup) {
        if ((_selectedGender ?? '').isEmpty) {
          errors['gender'] = strings.fieldRequired;
        }
        if ((_selectedBloodGroup ?? '').isEmpty) {
          errors['bloodGroup'] = strings.fieldRequired;
        }
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

  Future<void> _submit() async {
    final strings = AppStrings.of(AppLanguage.en);
    if (!_validate(strings)) return;

    final session = context.read<SessionProvider>();
    if (_isSignup && _whatsappSignup) {
      await session.signUp(
        phone: _phoneController.text,
        name: _nameController.text,
        dob: _dobController.text,
        place: _placeController.text,
        email: _emailController.text,
        gender: _selectedGender,
      );
      return;
    }
    if (_isSignup) {
      await session.register(
        phone: _phoneController.text,
        password: _passwordController.text,
        passwordConfirmation: _passwordController.text,
        fullName: _nameController.text,
        dateOfBirth: _dobController.text,
        email: _emailController.text,
        gender: _selectedGender,
        bloodGroup: _selectedBloodGroup,
      );
    } else {
      await session.login(
        phone: _phoneController.text,
        password: _passwordController.text,
      );
    }
  }

  Future<void> _loginWithOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _fieldErrors['phone'] = AppStrings.of(AppLanguage.en).fieldRequired;
      });
      return;
    }
    await context.read<SessionProvider>().sendOtp(phone: phone);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(AppLanguage.en);

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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              controller: _phoneController,
                              label: strings.mobileNumber,
                              hint: strings.mobileNumberHint,
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_android_rounded,
                              errorText: _fieldErrors['phone'],
                            ),
                            const SizedBox(height: 18),
                            if (!_whatsappSignup) ...[
                              AuthTextField(
                                controller: _passwordController,
                                label: strings.password,
                                hint: strings.passwordHint,
                                obscureText: _obscurePassword,
                                keyboardType: TextInputType.visiblePassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                errorText: _fieldErrors['password'],
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
                            ],
                            if (_isSignup) ...[
                              const SizedBox(height: 18),
                              AuthTextField(
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
                            ],
                            if (_isSignup && _whatsappSignup) ...[
                              const SizedBox(height: 18),
                              AuthTextField(
                                controller: _placeController,
                                label: 'City / Location',
                                hint: 'Ponnani, Kerala',
                                keyboardType: TextInputType.streetAddress,
                                prefixIcon: Icons.location_on_outlined,
                                errorText: _fieldErrors['place'],
                              ),
                            ],
                            if (_isSignup && !_whatsappSignup) ...[
                              AuthTextField(
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
                            ],
                            if ((session.errorMessage ?? '').isNotEmpty)
                              AuthErrorText(message: session.errorMessage!),
                            const SizedBox(height: 32),
                            AuthPrimaryButton(
                              label: _isSignup
                                  ? (_whatsappSignup
                                        ? 'Send WhatsApp OTP'
                                        : strings.register)
                                  : strings.login,
                              isLoading: session.isSubmittingAuth,
                              onPressed: _submit,
                            ),
                            if (!_isSignup) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: session.isSendingOtp
                                      ? null
                                      : _loginWithOtp,
                                  child: const Text(
                                    'Login with WhatsApp OTP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF537DE8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (_isSignup) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: session.isSubmittingAuth
                                      ? null
                                      : () => setState(() {
                                          _whatsappSignup = !_whatsappSignup;
                                          _fieldErrors.clear();
                                        }),
                                  child: Text(
                                    _whatsappSignup
                                        ? 'Register with password instead'
                                        : 'Register with WhatsApp OTP',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF537DE8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                                          _whatsappSignup = false;
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

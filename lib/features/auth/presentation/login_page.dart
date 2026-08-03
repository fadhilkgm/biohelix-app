import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/referrals/referral_link_provider.dart';
import '../../../core/widgets/app_chevron_back_button.dart';
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
  final _referralController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;
  final Map<String, String> _fieldErrors = {};
  bool _isSignup = false;
  bool _isRegistrationPhoneCheck = false;
  bool _registrationPhoneNotFound = false;
  String? _appliedReferralLinkCode;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (!_registrationPhoneNotFound || !mounted) return;
    setState(() => _registrationPhoneNotFound = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pendingCode = context.watch<ReferralLinkProvider?>()?.pendingCode;
    if (pendingCode == null || pendingCode == _appliedReferralLinkCode) return;

    _appliedReferralLinkCode = pendingCode;
    _referralController.text = pendingCode;
    _isSignup = false;
    _isRegistrationPhoneCheck = true;
    _registrationPhoneNotFound = false;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _placeController.dispose();
    _emailController.dispose();
    _referralController.dispose();
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

  bool _isPatientNotFound(String message) =>
      message.toLowerCase().contains('not found');

  void _handleBack() {
    if (_isSignup) {
      setState(() {
        _isSignup = false;
        _isRegistrationPhoneCheck = true;
        _registrationPhoneNotFound = true;
        _fieldErrors.clear();
      });
      return;
    }

    if (_isRegistrationPhoneCheck) {
      setState(() {
        _isRegistrationPhoneCheck = false;
        _registrationPhoneNotFound = false;
        _fieldErrors.clear();
      });
      return;
    }

    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _checkRegistrationPhone() async {
    final session = context.read<SessionProvider>();
    await session.sendOtp(phone: _phoneController.text);

    if (!mounted) return;
    final error = session.errorMessage ?? '';
    if (error.isEmpty) {
      return;
    }

    session.clearError();
    if (_isPatientNotFound(error)) {
      setState(() {
        _registrationPhoneNotFound = true;
        _fieldErrors.clear();
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context.read<LanguageProvider>().language);
    if (!_validate(strings)) return;

    final session = context.read<SessionProvider>();
    if (_isRegistrationPhoneCheck) {
      await _checkRegistrationPhone();
      return;
    }

    if (_isSignup) {
      final submittedReferralCode = _referralController.text;
      await session.signUp(
        phone: _phoneController.text,
        name: _nameController.text,
        dob: _dobController.text,
        place: _placeController.text,
        email: _emailController.text,
        gender: _selectedGender,
        bloodGroup: _selectedBloodGroup,
        referralCode: submittedReferralCode,
      );

      final error = session.errorMessage ?? '';
      if (error.isEmpty && session.isPendingSignupOtp && mounted) {
        await context.read<ReferralLinkProvider?>()?.consume();
      }
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
      final message =
          _looksLikeDuplicate(error) ||
              error.toLowerCase().contains('not found')
          ? 'This mobile number is not registered. Please register first.'
          : error;
      session.clearError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.08),
                    colorScheme.surface,
                  ],
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
                      const AppLogo(width: 180, height: 80, borderRadius: 5),
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
                                  : _isRegistrationPhoneCheck
                                  ? strings.registrationPhoneTitle
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
                                  : _isRegistrationPhoneCheck
                                  ? strings.registrationPhoneSubtitle
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
                              readOnly: _isSignup,
                            ),
                            if (_isRegistrationPhoneCheck &&
                                _registrationPhoneNotFound) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7E8),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFF2D49A),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      color: Color(0xFF9A6412),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        strings.phoneNotRegisteredMessage,
                                        style: const TextStyle(
                                          color: Color(0xFF6F4A10),
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_isSignup) ...[
                              const SizedBox(height: 18),
                              AuthTextField(
                                key: const ValueKey('field_dob'),
                                controller: _dobController,
                                label: '${strings.dateOfBirth} (optional)',
                                hint: strings.dateOfBirthHint,
                                keyboardType: TextInputType.datetime,
                                prefixIcon: Icons.calendar_today_rounded,
                                suffixIcon: Icon(
                                  Icons.event_available_rounded,
                                  color: colorScheme.primary,
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
                              const SizedBox(height: 18),
                              AuthTextField(
                                key: const ValueKey('field_referral_code'),
                                controller: _referralController,
                                label: 'Referral code (optional)',
                                hint: 'Example: BHRC7KQ2',
                                keyboardType: TextInputType.text,
                                prefixIcon: Icons.card_giftcard_rounded,
                                errorText: _fieldErrors['referralCode'],
                              ),
                            ],
                            if (_isSignup &&
                                (session.errorMessage ?? '').isNotEmpty)
                              AuthErrorText(message: session.errorMessage!),
                            const SizedBox(height: 32),
                            if (_isRegistrationPhoneCheck &&
                                _registrationPhoneNotFound) ...[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: session.isSubmittingAuth
                                      ? null
                                      : () {
                                          setState(() {
                                            _registrationPhoneNotFound = false;
                                            _isRegistrationPhoneCheck = false;
                                            _isSignup = true;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 20,
                                  ),
                                  label: Text(strings.register),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    backgroundColor: const Color(0xFFE8F1FF),
                                    foregroundColor: const Color(0xFF06489B),
                                    disabledBackgroundColor: const Color(
                                      0xFFE7EAF0,
                                    ),
                                    disabledForegroundColor: const Color(
                                      0xFF8A94A6,
                                    ),
                                    elevation: 0,
                                    side: const BorderSide(
                                      color: Color(0xFF06489B),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            AuthPrimaryButton(
                              label: _isSignup
                                  ? strings.registerWithWhatsAppOtp
                                  : _isRegistrationPhoneCheck
                                  ? strings.continueRegistration
                                  : strings.sendWhatsAppOtp,
                              isLoading: session.isSubmittingAuth,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 18),
                            if (!_isRegistrationPhoneCheck)
                              Center(
                                child: TextButton(
                                  onPressed: session.isSubmittingAuth
                                      ? null
                                      : () {
                                          context
                                              .read<SessionProvider>()
                                              .cancelPendingOtp();
                                          setState(() {
                                            if (_isSignup) {
                                              _isSignup = false;
                                            } else {
                                              _isRegistrationPhoneCheck = true;
                                            }
                                            _registrationPhoneNotFound = false;
                                            _fieldErrors.clear();
                                          });
                                        },
                                  child: Text(
                                    _isSignup
                                        ? strings.alreadyRegisteredLogin
                                        : strings.newPatientRegister,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            AuthDemoHint(
                              text: _isSignup
                                  ? strings.registerDemoHint
                                  : _isRegistrationPhoneCheck
                                  ? strings.registrationPhoneHint
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
            child: AppChevronBackButton(onPressed: _handleBack),
          ),
        ],
      ),
    );
  }
}

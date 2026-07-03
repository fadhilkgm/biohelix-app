import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../patient_portal/core/data/patient_repository.dart';
import '../../../patient_portal/core/models/patient_models.dart';

enum SessionState {
  bootstrapping,
  signedOut,
  sendingOtp,
  verifyingOtp,
  signedIn,
}

class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required AuthStorage authStorage,
    required ApiClient apiClient,
    required PatientRepository patientRepository,
  }) : _authStorage = authStorage,
       _apiClient = apiClient,
       _patientRepository = patientRepository;

  final AuthStorage _authStorage;
  final ApiClient _apiClient;
  final PatientRepository _patientRepository;

  SessionState _state = SessionState.bootstrapping;
  PatientIdentity? _patient;
  String? _authToken;
  String? _errorMessage;
  String? _pendingPhone;
  String? _pendingMrn;
  String? _pendingSignupName;
  String? _pendingSignupDob;
  String? _pendingSignupPlace;
  String? _pendingSignupEmail;
  String? _pendingSignupGender;
  String? _pendingSignupBloodGroup;
  String? _devOtp;
  String? _otpStatusMessage;
  List<SavedPatientProfile> _familyProfiles = const [];

  SessionState get state => _state;
  PatientIdentity? get patient => _patient;
  String? get authToken => _authToken;
  String? get errorMessage => _errorMessage;
  String? get pendingPhone => _pendingPhone;
  String? get pendingMrn => _pendingMrn;
  String? get devOtp => _devOtp;
  String? get otpStatusMessage => _otpStatusMessage;
  bool get isPendingSignupOtp => (_pendingSignupName ?? '').isNotEmpty;
  List<SavedPatientProfile> get familyProfiles =>
      List.unmodifiable(_familyProfiles);

  bool get isBootstrapping => _state == SessionState.bootstrapping;
  bool get isSendingOtp => _state == SessionState.sendingOtp;
  bool get isVerifyingOtp => _state == SessionState.verifyingOtp;
  bool get isSubmittingAuth =>
      _state == SessionState.sendingOtp || _state == SessionState.verifyingOtp;
  bool get isAuthenticated => (_authToken ?? '').isNotEmpty && _patient != null;

  Future<void> initialize() async {
    _familyProfiles = await _authStorage.readFamilyProfiles();
    _authToken = await _authStorage.readToken();
    if ((_authToken ?? '').isEmpty && _familyProfiles.isNotEmpty) {
      _authToken = _familyProfiles.first.token;
      await _authStorage.writeToken(_authToken!);
    }
    _apiClient.updateAuthToken(_authToken);

    if ((_authToken ?? '').isEmpty) {
      _state = SessionState.signedOut;
      notifyListeners();
      return;
    }

    try {
      _patient = await _patientRepository.getCurrentPatient();
      await _saveFamilyProfile(token: _authToken!, patient: _patient!);
      _state = SessionState.signedIn;
    } catch (error) {
      final recovered = await _recoverFromStoredProfiles();
      if (!recovered) {
        await _authStorage.clearAll();
        _authToken = null;
        _apiClient.updateAuthToken(null);
        _patient = null;
        _familyProfiles = const [];
        _state = SessionState.signedOut;
        _errorMessage = error.toString();
      }
    }

    notifyListeners();
  }

  Future<void> sendOtp({required String phone, String? mrn}) async {
    final wasAuthenticated = isAuthenticated;
    final normalizedPhone = normalizePatientPhone(phone);
    final normalizedMrn = (mrn ?? '').trim();
    if (normalizedPhone.isEmpty) {
      _errorMessage = 'Enter a valid mobile number.';
      notifyListeners();
      return;
    }

    _state = SessionState.sendingOtp;
    _errorMessage = null;
    _otpStatusMessage = null;
    notifyListeners();

    try {
      final result = await _patientRepository.sendOtp(
        phone: normalizedPhone,
        mrn: normalizedMrn.isEmpty ? null : normalizedMrn,
      );
      _devOtp = result.devOtp;
      _otpStatusMessage = result.message;
      _pendingPhone = normalizedPhone;
      _pendingMrn = normalizedMrn.isEmpty ? null : normalizedMrn;
      _clearPendingSignupDetails();
      _state = wasAuthenticated
          ? SessionState.signedIn
          : SessionState.signedOut;
    } catch (error) {
      _errorMessage = error.toString();
      _state = wasAuthenticated
          ? SessionState.signedIn
          : SessionState.signedOut;
    }

    notifyListeners();
  }

  Future<void> signUp({
    required String phone,
    required String name,
    required String dob,
    required String place,
    String? email,
    String? gender,
    String? bloodGroup,
  }) async {
    final normalizedPhone = normalizePatientPhone(phone);
    if (normalizedPhone.isEmpty || name.trim().isEmpty || place.trim().isEmpty) {
      _errorMessage = 'Enter your name, mobile number, and location.';
      notifyListeners();
      return;
    }

    _state = SessionState.sendingOtp;
    _errorMessage = null;
    _otpStatusMessage = null;
    notifyListeners();

    try {
      final result = await _patientRepository.signUp(
        phone: normalizedPhone,
        name: name.trim(),
        dob: dob.trim(),
        place: place.trim(),
        email: email,
        gender: gender,
      );
      _devOtp = result.devOtp;
      _otpStatusMessage = result.message;
      _pendingPhone = normalizedPhone;
      _pendingMrn = null;
      _pendingSignupName = name.trim();
      _pendingSignupDob = dob.trim();
      _pendingSignupPlace = place.trim();
      _pendingSignupEmail = email?.trim();
      _pendingSignupGender = gender?.trim();
      _pendingSignupBloodGroup = bloodGroup?.trim();
      _state = SessionState.signedOut;
    } catch (error) {
      _errorMessage = error.toString();
      _state = SessionState.signedOut;
    }

    notifyListeners();
  }

  Future<void> resendPendingOtp() async {
    final phone = _pendingPhone;
    if ((phone ?? '').isEmpty) {
      _errorMessage = 'Request an OTP first.';
      notifyListeners();
      return;
    }

    if (isPendingSignupOtp) {
      await signUp(
        phone: phone!,
        name: _pendingSignupName!,
        dob: _pendingSignupDob ?? '',
        place: _pendingSignupPlace!,
        email: _pendingSignupEmail,
        gender: _pendingSignupGender,
        bloodGroup: _pendingSignupBloodGroup,
      );
      return;
    }

    await sendOtp(phone: phone!, mrn: _pendingMrn);
  }

  Future<void> sendVerification() async {
    if (!isAuthenticated) return;

    _errorMessage = null;
    notifyListeners();

    try {
      await _patientRepository.sendVerification();
    } catch (error) {
      _errorMessage = error.toString();
    }

    notifyListeners();
  }

  Future<void> verifyEmailOtp(String otp) async {
    if (!isAuthenticated) return;

    _errorMessage = null;
    notifyListeners();

    try {
      await _patientRepository.verifyEmailOtp(otp);
      await refreshPatient();
    } catch (error) {
      _errorMessage = error.toString();
    }

    notifyListeners();
  }

  Future<void> login({required String phone, required String password}) async {
    final normalizedPhone = normalizePatientPhone(phone);
    if (normalizedPhone.isEmpty || password.isEmpty) {
      _errorMessage = 'Enter your phone number and password.';
      notifyListeners();
      return;
    }

    _state = SessionState.verifyingOtp;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _patientRepository.loginPatient(
        phone: normalizedPhone,
        password: password,
      );
      await _applyAuthenticatedSession(session);
    } catch (error) {
      _errorMessage = error.toString();
      _state = SessionState.signedOut;
    }

    notifyListeners();
  }

  Future<void> register({
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String fullName,
    String? gender,
    String? email,
    String? dateOfBirth,
    String? bloodGroup,
  }) async {
    final normalizedPhone = normalizePatientPhone(phone);
    final normalizedName = fullName.trim();
    if (normalizedPhone.isEmpty ||
        password.isEmpty ||
        passwordConfirmation.isEmpty ||
        normalizedName.isEmpty) {
      _errorMessage = 'Enter your name, phone number, and password.';
      notifyListeners();
      return;
    }
    if (password != passwordConfirmation) {
      _errorMessage = 'Password confirmation does not match.';
      notifyListeners();
      return;
    }

    final parts = normalizedName.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '-';

    _state = SessionState.sendingOtp;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _patientRepository.registerPatient(
        phone: normalizedPhone,
        password: password,
        passwordConfirmation: passwordConfirmation,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        email: email,
        dateOfBirth: dateOfBirth,
        bloodGroup: bloodGroup,
      );
      await _applyAuthenticatedSession(session);
    } catch (error) {
      _errorMessage = error.toString();
      _state = SessionState.signedOut;
    }

    notifyListeners();
  }

  void cancelPendingOtp() {
    _pendingPhone = null;
    _pendingMrn = null;
    _devOtp = null;
    _otpStatusMessage = null;
    _errorMessage = null;
    _clearPendingSignupDetails();
    notifyListeners();
  }

  void _clearPendingSignupDetails() {
    _pendingSignupName = null;
    _pendingSignupDob = null;
    _pendingSignupPlace = null;
    _pendingSignupEmail = null;
    _pendingSignupGender = null;
    _pendingSignupBloodGroup = null;
  }

  Future<void> verifyOtp({required String otp}) async {
    final phone = _pendingPhone?.trim();
    if ((phone ?? '').isEmpty) {
      _errorMessage = 'Request an OTP first.';
      notifyListeners();
      return;
    }

    _state = SessionState.verifyingOtp;
    _errorMessage = null;
    notifyListeners();

    try {
      final wasSignup = isPendingSignupOtp;
      final pendingBloodGroup = _pendingSignupBloodGroup;
      final session = await _patientRepository.verifyOtp(
        phone: phone!,
        otp: otp.trim(),
      );
      _authToken = session.token;
      await _authStorage.writeToken(session.token);
      _apiClient.updateAuthToken(session.token);
      _patient = session.patient;
      if (wasSignup && (pendingBloodGroup ?? '').isNotEmpty) {
        _patient = await _patientRepository.updatePatientProfile(
          _patient!.copyWith(bloodGroup: pendingBloodGroup),
        );
      }
      await _saveFamilyProfile(token: session.token, patient: _patient!);
      _state = SessionState.signedIn;
      _devOtp = null;
      _otpStatusMessage = null;
      _pendingPhone = null;
      _pendingMrn = null;
      _clearPendingSignupDetails();
    } catch (error) {
      if (!isAuthenticated) {
        _apiClient.updateAuthToken(null);
      }
      _errorMessage = error.toString();
      _state = isAuthenticated ? SessionState.signedIn : SessionState.signedOut;
    }

    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshPatient() async {
    if ((_authToken ?? '').isEmpty) return;

    try {
      _patient = await _patientRepository.getCurrentPatient();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    }

    notifyListeners();
  }

  void updatePatient(PatientIdentity patient) {
    _patient = patient;
    final token = _authToken;
    if ((token ?? '').isNotEmpty) {
      unawaited(_saveFamilyProfile(token: token!, patient: patient));
    }
    notifyListeners();
  }

  Future<void> switchFamilyProfile(String token) async {
    if (token.trim().isEmpty || token == _authToken) {
      return;
    }

    final existingProfile = _familyProfiles.where(
      (profile) => profile.token == token,
    );
    if (existingProfile.isEmpty) {
      throw StateError('Selected family profile is unavailable.');
    }

    _errorMessage = null;
    _state = SessionState.bootstrapping;
    notifyListeners();

    try {
      _authToken = token;
      await _authStorage.writeToken(token);
      _apiClient.updateAuthToken(token);
      final nextPatient = await _patientRepository.getCurrentPatient();
      _patient = nextPatient;
      await _saveFamilyProfile(token: token, patient: nextPatient);
      _state = SessionState.signedIn;
    } catch (error) {
      _errorMessage = error.toString();
      final fallbackToken = _familyProfiles
          .where((profile) => profile.token != token)
          .map((profile) => profile.token)
          .cast<String?>()
          .firstWhere((value) => (value ?? '').isNotEmpty, orElse: () => null);

      if ((fallbackToken ?? '').isNotEmpty) {
        _authToken = fallbackToken;
        await _authStorage.writeToken(fallbackToken!);
        _apiClient.updateAuthToken(fallbackToken);
        _patient = await _patientRepository.getCurrentPatient();
        _state = SessionState.signedIn;
      } else {
        await _authStorage.clearAll();
        _authToken = null;
        _patient = null;
        _familyProfiles = const [];
        _apiClient.updateAuthToken(null);
        _state = SessionState.signedOut;
      }
    }

    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      if ((_authToken ?? '').isNotEmpty) {
        await _patientRepository.logout();
      }
    } catch (_) {
      // Local sign-out should still complete if the token is already invalid.
    }
    await _authStorage.clearAll();
    _authToken = null;
    _apiClient.updateAuthToken(null);
    _patient = null;
    _familyProfiles = const [];
    _pendingPhone = null;
    _pendingMrn = null;
    _devOtp = null;
    _otpStatusMessage = null;
    _clearPendingSignupDetails();
    _state = SessionState.signedOut;
    notifyListeners();
  }

  Future<void> _applyAuthenticatedSession(PatientAuthSession session) async {
    _authToken = session.token;
    await _authStorage.writeToken(session.token);
    _apiClient.updateAuthToken(session.token);
    _patient = session.patient;
    await _saveFamilyProfile(token: session.token, patient: _patient!);
    _state = SessionState.signedIn;
    _devOtp = null;
    _otpStatusMessage = null;
    _pendingPhone = null;
    _pendingMrn = null;
    _clearPendingSignupDetails();
  }

  Future<bool> _recoverFromStoredProfiles() async {
    final failedToken = _authToken;
    if ((failedToken ?? '').isEmpty) {
      return false;
    }

    _familyProfiles = _familyProfiles
        .where((profile) => profile.token != failedToken)
        .toList();
    await _authStorage.writeFamilyProfiles(_familyProfiles);

    if (_familyProfiles.isEmpty) {
      return false;
    }

    final nextToken = _familyProfiles.first.token;
    _authToken = nextToken;
    await _authStorage.writeToken(nextToken);
    _apiClient.updateAuthToken(nextToken);
    _patient = await _patientRepository.getCurrentPatient();
    await _saveFamilyProfile(token: nextToken, patient: _patient!);
    _state = SessionState.signedIn;
    _errorMessage = null;
    return true;
  }

  Future<void> _saveFamilyProfile({
    required String token,
    required PatientIdentity patient,
  }) async {
    final now = DateTime.now().toIso8601String();
    final nextProfile = SavedPatientProfile(
      token: token,
      patient: patient,
      lastUsedAt: now,
    );

    final profiles = [..._familyProfiles];
    final existingIndex = profiles.indexWhere(
      (profile) => profile.patient.id == patient.id || profile.token == token,
    );

    if (existingIndex >= 0) {
      profiles[existingIndex] = nextProfile;
    } else {
      profiles.add(nextProfile);
    }

    profiles.sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    _familyProfiles = profiles;
    await _authStorage.writeFamilyProfiles(_familyProfiles);
  }
}

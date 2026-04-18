import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
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
  String? _devOtp;
  List<SavedPatientProfile> _familyProfiles = const [];

  SessionState get state => _state;
  PatientIdentity? get patient => _patient;
  String? get authToken => _authToken;
  String? get errorMessage => _errorMessage;
  String? get pendingPhone => _pendingPhone;
  String? get pendingMrn => _pendingMrn;
  String? get devOtp => _devOtp;
  List<SavedPatientProfile> get familyProfiles =>
      List.unmodifiable(_familyProfiles);

  bool get isBootstrapping => _state == SessionState.bootstrapping;
  bool get isSendingOtp => _state == SessionState.sendingOtp;
  bool get isVerifyingOtp => _state == SessionState.verifyingOtp;
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

  Future<void> sendOtp({required String phone, required String mrn}) async {
    final wasAuthenticated = isAuthenticated;
    final normalizedPhone = phone.trim();
    final normalizedMrn = mrn.trim();
    if (normalizedPhone.isEmpty) {
      _errorMessage = 'Enter a valid mobile number.';
      notifyListeners();
      return;
    }
    if (normalizedMrn.isEmpty) {
      _errorMessage = 'Enter your MRN number.';
      notifyListeners();
      return;
    }

    _state = SessionState.sendingOtp;
    _errorMessage = null;
    notifyListeners();

    try {
      _devOtp = await _patientRepository.sendOtp(
        phone: normalizedPhone,
        mrn: normalizedMrn,
      );
      _pendingPhone = normalizedPhone;
      _pendingMrn = normalizedMrn;
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

  void cancelPendingOtp() {
    _pendingPhone = null;
    _pendingMrn = null;
    _devOtp = null;
    _errorMessage = null;
    notifyListeners();
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
      final session = await _patientRepository.verifyOtp(
        phone: phone!,
        otp: otp.trim(),
      );
      _authToken = session.token;
      await _authStorage.writeToken(session.token);
      _apiClient.updateAuthToken(session.token);
      _patient = await _patientRepository.getCurrentPatient();
      await _saveFamilyProfile(token: session.token, patient: _patient!);
      _state = SessionState.signedIn;
      _devOtp = null;
      _pendingPhone = null;
      _pendingMrn = null;
    } catch (error) {
      if (!isAuthenticated) {
        _apiClient.updateAuthToken(null);
      }
      _errorMessage = error.toString();
      _state = isAuthenticated ? SessionState.signedIn : SessionState.signedOut;
    }

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
    await _authStorage.clearAll();
    _authToken = null;
    _apiClient.updateAuthToken(null);
    _patient = null;
    _familyProfiles = const [];
    _pendingPhone = null;
    _pendingMrn = null;
    _devOtp = null;
    _state = SessionState.signedOut;
    notifyListeners();
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

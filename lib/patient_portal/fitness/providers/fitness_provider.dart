import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/session/providers/session_provider.dart';
import '../../core/data/patient_repository.dart';
import '../models/fitness_activity_models.dart';
import '../services/android_fitness_service.dart';

enum FitnessConnectionState {
  loading,
  disconnected,
  connected,
  updateRequired,
  unavailable,
  blockedForDifferentPatient,
  error,
}

class FitnessProvider extends ChangeNotifier {
  FitnessProvider({
    required PatientRepository repository,
    required SessionProvider sessionProvider,
    AndroidFitnessService? service,
    Future<void> Function()? onRewardsChanged,
  }) : _repository = repository,
       _sessionProvider = sessionProvider,
       _service = service ?? AndroidFitnessService(),
       _onRewardsChanged = onRewardsChanged {
    _sessionProvider.addListener(_handleSessionChanged);
  }

  static const _ownerPatientKey = 'fitness_device_owner_patient_id';

  final PatientRepository _repository;
  final SessionProvider _sessionProvider;
  final AndroidFitnessService _service;
  final Future<void> Function()? _onRewardsChanged;

  FitnessConnectionState _state = FitnessConnectionState.loading;
  FitnessPlatformStatus? _platformStatus;
  FitnessActivitySummary _summary = const FitnessActivitySummary();
  int? _deviceOwnerPatientId;
  int? _lastPatientId;
  String? _errorMessage;
  bool _isSyncing = false;
  bool _disposed = false;

  FitnessConnectionState get state => _state;
  FitnessPlatformStatus? get platformStatus => _platformStatus;
  FitnessActivitySummary get summary => _summary;
  DailyFitnessActivity? get today => _summary.today;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _isSyncing;
  bool get isSupportedPlatform => _service.isSupportedPlatform;
  bool get isIOS => _service.isIOS;
  String get platformName => _service.platformName;
  bool get isConnected => _state == FitnessConnectionState.connected;
  bool get hasDeviceOwner => _deviceOwnerPatientId != null;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _deviceOwnerPatientId = preferences.getInt(_ownerPatientKey);
    await _refreshForCurrentPatient(syncDevice: true);
  }

  Future<void> connect() async {
    final patientId = _sessionProvider.patient?.id;
    if (patientId == null || !_sessionProvider.isAuthenticated) return;
    if (_deviceOwnerPatientId != null && _deviceOwnerPatientId != patientId) {
      _setState(FitnessConnectionState.blockedForDifferentPatient);
      return;
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final status = await _service.status();
      _platformStatus = status;
      if (status.requiresUpdate) {
        _setState(FitnessConnectionState.updateRequired);
        return;
      }
      if (!status.isAvailable) {
        _setState(FitnessConnectionState.unavailable);
        return;
      }

      final granted =
          status.permissionsGranted || await _service.requestPermissions();
      if (!granted) {
        _setState(FitnessConnectionState.disconnected);
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_ownerPatientKey, patientId);
      _deviceOwnerPatientId = patientId;
      await refreshAndSync();
    } catch (error) {
      _errorMessage = _friendlyError(error);
      _setState(FitnessConnectionState.error);
    } finally {
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refreshAndSync() async {
    final patientId = _sessionProvider.patient?.id;
    if (patientId == null || patientId != _deviceOwnerPatientId) {
      _setState(
        _deviceOwnerPatientId == null
            ? FitnessConnectionState.disconnected
            : FitnessConnectionState.blockedForDifferentPatient,
      );
      return;
    }

    _isSyncing = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      final status = await _service.status();
      _platformStatus = status;
      if (status.requiresUpdate) {
        _setState(FitnessConnectionState.updateRequired);
        return;
      }
      if (!status.isAvailable) {
        _setState(FitnessConnectionState.unavailable);
        return;
      }
      if (!status.permissionsGranted) {
        _setState(FitnessConnectionState.disconnected);
        return;
      }

      final activity = await _service.readActivity(days: 7);
      _summary = await _repository.syncFitnessActivity(
        days: activity.days,
        timezone: activity.timezone,
      );
      _setState(FitnessConnectionState.connected);
      await _onRewardsChanged?.call();
    } catch (error) {
      _errorMessage = _friendlyError(error);
      _setState(FitnessConnectionState.error);
    } finally {
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> openHealthConnect() => _service.openHealthConnect();

  Future<void> disconnect() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_ownerPatientKey);
    _deviceOwnerPatientId = null;
    _summary = const FitnessActivitySummary();
    _errorMessage = null;
    _setState(FitnessConnectionState.disconnected);
  }

  Future<void> _refreshForCurrentPatient({required bool syncDevice}) async {
    final patientId = _sessionProvider.patient?.id;
    if (!_service.isSupportedPlatform) {
      _setState(FitnessConnectionState.unavailable);
      return;
    }
    if (!_sessionProvider.isAuthenticated || patientId == null) {
      _summary = const FitnessActivitySummary();
      _setState(FitnessConnectionState.disconnected);
      return;
    }

    try {
      _summary = await _repository.getFitnessActivity();
    } catch (_) {
      // Device data can still load if the summary request is temporarily down.
    }

    if (_deviceOwnerPatientId == null) {
      _setState(FitnessConnectionState.disconnected);
      return;
    }
    if (_deviceOwnerPatientId != patientId) {
      _setState(FitnessConnectionState.blockedForDifferentPatient);
      return;
    }
    if (syncDevice) {
      await refreshAndSync();
    }
  }

  void _handleSessionChanged() {
    final patientId = _sessionProvider.patient?.id;
    if (_lastPatientId == patientId) return;
    _lastPatientId = patientId;
    unawaited(_refreshForCurrentPatient(syncDevice: true));
  }

  void _setState(FitnessConnectionState value) {
    _state = value;
    if (!_disposed) notifyListeners();
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('PlatformException(', '');
    return text.length > 220 ? '${text.substring(0, 220)}…' : text;
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionProvider.removeListener(_handleSessionChanged);
    super.dispose();
  }
}

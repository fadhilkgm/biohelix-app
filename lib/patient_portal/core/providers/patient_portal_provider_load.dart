part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalLoadMixin on PatientPortalProvider {
  /// Loads the data needed to render the home screen, then starts the rest of
  /// the portal data in a second phase.
  ///
  /// Existing callers keep the original "everything is ready" contract. The
  /// login flow opts out of waiting so that non-home data does not block the
  /// first useful frame.
  Future<void> loadPortal({bool waitForDeferred = true}) async {
    if (!_sessionProvider.isAuthenticated) return;

    final currentPatientId = _sessionProvider.patient?.id;
    final generation = ++_loadGeneration;
    if (_loadedPatientId != currentPatientId) {
      _resetPatientScopedState();
      _loadedPatientId = currentPatientId;
    }

    _isLoading = true;
    _errorMessage = null;
    _notify();

    final loadErrors = <String>[];
    final results = await Future.wait<dynamic>([
      _safeLoad<PatientDashboard>(_repository.getDashboard, 'dashboard'),
      _safeLoad<List<HomeBannerItem>>(
        _repository.getHomeBanners,
        'home banners',
      ),
      _safeLoad<List<BookingItem>>(_repository.getBookings, 'bookings'),
      _safeLoad<List<DoctorListing>>(
        _repository.getDoctors,
        'doctors',
        errors: loadErrors,
      ),
      _safeLoad<List<LabTestItem>>(
        _repository.getLabTests,
        'lab tests',
        errors: loadErrors,
      ),
      _safeLoad<List<LabPackageItem>>(
        _repository.getLabPackages,
        'lab packages',
        errors: loadErrors,
      ),
      _safeLoad<List<TickerMessageItem>>(
        _repository.getTickerMessages,
        'ticker messages',
      ),
      _safeLoad<List<HomeOfferItem>>(_repository.getHomeOffers, 'home offers'),
      _safeLoad<List<DepartmentItem>>(
        _repository.getDepartments,
        'departments',
      ),
      _safeLoad<MyClubSummary>(_repository.getMyClub, 'my club'),
      _safeLoad<HealthSnapshot?>(
        _repository.getHealthSnapshot,
        'health snapshot',
      ),
      _safeLoad<List<AiSuggestionItem>>(
        _repository.getAiSuggestions,
        'ai suggestions',
      ),
    ]);

    if (!_isCurrentLoad(generation, currentPatientId)) {
      if (generation == _loadGeneration) {
        _isLoading = false;
        _notify();
      }
      return;
    }

    _dashboard = results[0] as PatientDashboard? ?? _buildFallbackDashboard();
    _homeBanners = results[1] as List<HomeBannerItem>? ?? const [];
    _bookings = (results[2] as List<BookingItem>? ?? const [])
        .where((booking) => booking.isDoctorAppointment)
        .toList();
    _doctors = results[3] as List<DoctorListing>? ?? const [];
    _labTests = results[4] as List<LabTestItem>? ?? const [];
    _labPackages = results[5] as List<LabPackageItem>? ?? const [];
    _tickerMessages = results[6] as List<TickerMessageItem>? ?? const [];
    _homeOffers = results[7] as List<HomeOfferItem>? ?? const [];
    _departments = results[8] as List<DepartmentItem>? ?? const [];
    _myClub = results[9] as MyClubSummary?;
    _healthSnapshot = results[10] as HealthSnapshot?;
    _aiSuggestions = results[11] as List<AiSuggestionItem>? ?? const [];
    _mergeMyClubIntoDashboard();

    if (loadErrors.isNotEmpty) {
      _errorMessage = loadErrors.first;
    }
    _isLoading = false;
    _notify();

    final deferred = _loadDeferredPortalData(
      generation: generation,
      patientId: currentPatientId,
    );
    if (waitForDeferred) {
      await deferred;
    } else {
      unawaited(deferred);
    }
  }

  Future<void> _loadDeferredPortalData({
    required int generation,
    required int? patientId,
  }) async {
    _isLoadingDeferred = true;
    _notify();

    final labOrdersRevision = _labOrdersRevision;
    final labPackageOrdersRevision = _labPackageOrdersRevision;
    final results = await Future.wait<dynamic>([
      _safeLoad<List<PrescriptionRecord>>(
        _repository.getPrescriptions,
        'prescriptions',
      ),
      _safeLoad<List<MedicalRecordItem>>(
        _repository.getMedicalRecords,
        'medical records',
      ),
      _safeLoad<List<DocumentRecord>>(_repository.getDocuments, 'documents'),
      _safeLoad<List<SummaryRecord>>(_repository.getSummaries, 'summaries'),
      _safeLoad<List<VitalRecord>>(_repository.getVitalTrend, 'vitals'),
      _safeLoad<List<LabOrderItem>>(_repository.getLabOrders, 'lab orders'),
      _safeLoad<List<LabPackageOrderItem>>(
        _repository.getLabPackageOrders,
        'lab package orders',
      ),
      _safeLoad<List<BodyPointItem>>(_repository.getBodyPoints, 'body points'),
      _safeLoad<List<FamilyMember>>(
        _repository.getFamilyMembers,
        'family members',
      ),
      _safeLoad<List<HomeCareServiceItem>>(
        _repository.getHomeCareServices,
        'home care services',
      ),
      _safeLoad<List<HomeCareBookingItem>>(
        _repository.getHomeCareBookings,
        'home care bookings',
      ),
    ]);

    if (!_isCurrentLoad(generation, patientId)) {
      if (generation == _loadGeneration) {
        _isLoadingDeferred = false;
        _notify();
      }
      return;
    }

    _prescriptions = results[0] as List<PrescriptionRecord>? ?? const [];
    _medicalRecords = results[1] as List<MedicalRecordItem>? ?? const [];
    _documents = results[2] as List<DocumentRecord>? ?? const [];
    _summaries = results[3] as List<SummaryRecord>? ?? const [];
    _vitalTrend = results[4] as List<VitalRecord>? ?? const [];
    if (_labOrdersRevision == labOrdersRevision) {
      _labOrders = results[5] as List<LabOrderItem>? ?? const [];
    }
    if (_labPackageOrdersRevision == labPackageOrdersRevision) {
      _labPackageOrders = results[6] as List<LabPackageOrderItem>? ?? const [];
    }
    _bodyPoints = results[7] as List<BodyPointItem>? ?? const [];
    _familyMembers = results[8] as List<FamilyMember>? ?? const [];
    _homeCareServices = results[9] as List<HomeCareServiceItem>? ?? const [];
    _homeCareBookings = results[10] as List<HomeCareBookingItem>? ?? const [];
    _isLoadingDeferred = false;
    _notify();
  }

  Future<T?> _safeLoad<T>(
    Future<T> Function() loader,
    String label, {
    List<String>? errors,
  }) async {
    try {
      return await loader();
    } catch (error) {
      errors?.add('$label: $error');
      return null;
    }
  }

  bool _isCurrentLoad(int generation, int? patientId) {
    return generation == _loadGeneration &&
        patientId == _loadedPatientId &&
        patientId == _sessionProvider.patient?.id &&
        _sessionProvider.isAuthenticated;
  }

  void _mergeMyClubIntoDashboard() {
    if (_myClub == null || _dashboard == null) return;
    _dashboard = PatientDashboard(
      patient: _dashboard!.patient,
      metrics: _dashboard!.metrics,
      recentBookings: _dashboard!.recentBookings,
      recentPrescriptions: _dashboard!.recentPrescriptions,
      recentDocuments: _dashboard!.recentDocuments,
      recentSummaries: _dashboard!.recentSummaries,
      idCard: _dashboard!.idCard,
      myClub: _myClub!,
      emergencyContacts: _dashboard!.emergencyContacts,
      latestVitals: _dashboard!.latestVitals,
    );
  }

  Future<void> _refreshDoctorBookings() async {
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    final results = await Future.wait<dynamic>([
      _safeLoad<PatientDashboard>(_repository.getDashboard, 'dashboard'),
      _safeLoad<List<BookingItem>>(_repository.getBookings, 'bookings'),
    ]);
    if (!_isCurrentLoad(generation, patientId)) return;
    _dashboard = results[0] as PatientDashboard? ?? _dashboard;
    final bookings = results[1] as List<BookingItem>?;
    if (bookings != null) {
      _bookings = bookings
          .where((booking) => booking.isDoctorAppointment)
          .toList();
    }
    _mergeMyClubIntoDashboard();
    _notify();
  }

  Future<void> _refreshLabOrders() async {
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    final revision = ++_labOrdersRevision;
    final results = await Future.wait<dynamic>([
      _safeLoad<PatientDashboard>(_repository.getDashboard, 'dashboard'),
      _safeLoad<List<LabOrderItem>>(_repository.getLabOrders, 'lab orders'),
    ]);
    if (revision != _labOrdersRevision ||
        !_isCurrentLoad(generation, patientId)) {
      return;
    }
    _dashboard = results[0] as PatientDashboard? ?? _dashboard;
    _labOrders = results[1] as List<LabOrderItem>? ?? _labOrders;
    _mergeMyClubIntoDashboard();
    _notify();
  }

  Future<void> _refreshLabPackageOrders() async {
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    final revision = ++_labPackageOrdersRevision;
    final results = await Future.wait<dynamic>([
      _safeLoad<PatientDashboard>(_repository.getDashboard, 'dashboard'),
      _safeLoad<List<LabPackageOrderItem>>(
        _repository.getLabPackageOrders,
        'lab package orders',
      ),
    ]);
    if (revision != _labPackageOrdersRevision ||
        !_isCurrentLoad(generation, patientId)) {
      return;
    }
    _dashboard = results[0] as PatientDashboard? ?? _dashboard;
    _labPackageOrders =
        results[1] as List<LabPackageOrderItem>? ?? _labPackageOrders;
    _mergeMyClubIntoDashboard();
    _notify();
  }

  PatientDashboard _buildFallbackDashboard() {
    final patient =
        _sessionProvider.patient ??
        const PatientIdentity(
          id: 0,
          name: 'BHRC Patient',
          phone: '',
          registrationNumber: 'BHRC',
          uuid: '',
        );

    return PatientDashboard(
      patient: patient,
      metrics: const PortalMetrics(
        totalRecords: 0,
        availableRecords: 0,
        processingRecords: 0,
        showingRecords: 0,
        upcomingBookings: 0,
      ),
      recentBookings: const [],
      recentPrescriptions: const [],
      recentDocuments: const [],
      recentSummaries: const [],
      idCard: IdCardInfo(
        registrationNumber: patient.registrationNumber,
        patientName: patient.name,
        membershipTier: 'Classic',
        qrValue: patient.uuid,
        bloodGroup: patient.bloodGroup,
      ),
      myClub: MyClubSummary(
        patientId: patient.id,
        points: 0,
        currencyValue: 0,
        tier: 'Classic',
        transactions: const [],
      ),
      emergencyContacts: const [
        EmergencyContact(name: 'BHRC Ambulance', number: '+91 7510210222'),
        EmergencyContact(name: 'Hospital Reception', number: '+91 7510210224'),
        EmergencyContact(name: 'Emergency Helpline', number: '108'),
      ],
      latestVitals: null,
    );
  }

  Future<void> refresh() async {
    await loadPortal();
  }

  Future<void> refreshMyClub() async {
    try {
      _myClub = await _repository.getMyClub();
      _mergeMyClubIntoDashboard();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    }
    _notify();
  }
}

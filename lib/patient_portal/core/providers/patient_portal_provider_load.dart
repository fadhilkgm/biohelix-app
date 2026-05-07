part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalLoadMixin on PatientPortalProvider {
  Future<void> loadPortal() async {
    if (!_sessionProvider.isAuthenticated) return;

    final currentPatientId = _sessionProvider.patient?.id;
    if (_loadedPatientId != currentPatientId) {
      _resetPatientScopedState();
      _loadedPatientId = currentPatientId;
    }

    _isLoading = true;
    _errorMessage = null;
    _notify();

    final loadErrors = <String>[];

    Future<T?> safeLoad<T>(Future<T> Function() loader, String label) async {
      try {
        return await loader();
      } catch (error) {
        loadErrors.add('$label: $error');
        return null;
      }
    }

    final dashboardResult = await safeLoad<PatientDashboard>(
      _repository.getDashboard,
      'dashboard',
    );

    final results = await Future.wait<dynamic>([
      safeLoad<List<HomeBannerItem>>(
        _repository.getHomeBanners,
        'home banners',
      ),
      safeLoad<List<BookingItem>>(_repository.getBookings, 'bookings'),
      safeLoad<List<PrescriptionRecord>>(
        _repository.getPrescriptions,
        'prescriptions',
      ),
      safeLoad<List<MedicalRecordItem>>(
        _repository.getMedicalRecords,
        'medical records',
      ),
      safeLoad<List<DocumentRecord>>(_repository.getDocuments, 'documents'),
      safeLoad<List<SummaryRecord>>(_repository.getSummaries, 'summaries'),
      safeLoad<List<VitalRecord>>(_repository.getVitalTrend, 'vitals'),
      safeLoad<List<DoctorListing>>(_repository.getDoctors, 'doctors'),
      safeLoad<List<LabTestItem>>(_repository.getLabTests, 'lab tests'),
      safeLoad<List<LabOrderItem>>(_repository.getLabOrders, 'lab orders'),
      safeLoad<List<LabPackageItem>>(
        _repository.getLabPackages,
        'lab packages',
      ),
      safeLoad<List<LabPackageOrderItem>>(
        _repository.getLabPackageOrders,
        'lab package orders',
      ),
      safeLoad<List<ChatThreadSummary>>(
        _repository.getGlobalChatThreads,
        'global chat threads',
      ),
      safeLoad<List<TickerMessageItem>>(
        _repository.getTickerMessages,
        'ticker messages',
      ),
      safeLoad<List<HomeOfferItem>>(_repository.getHomeOffers, 'home offers'),
      safeLoad<List<DepartmentItem>>(_repository.getDepartments, 'departments'),
    ]);

    _dashboard = dashboardResult ?? _buildFallbackDashboard();
    _homeBanners = results[0] as List<HomeBannerItem>? ?? const [];
    _bookings = results[1] as List<BookingItem>? ?? const [];
    _prescriptions = results[2] as List<PrescriptionRecord>? ?? const [];
    _medicalRecords = results[3] as List<MedicalRecordItem>? ?? const [];
    _documents = results[4] as List<DocumentRecord>? ?? const [];
    _summaries = results[5] as List<SummaryRecord>? ?? const [];
    _vitalTrend = results[6] as List<VitalRecord>? ?? const [];
    _doctors = results[7] as List<DoctorListing>? ?? const [];
    _labTests = results[8] as List<LabTestItem>? ?? const [];
    _labOrders = results[9] as List<LabOrderItem>? ?? const [];
    _labPackages = results[10] as List<LabPackageItem>? ?? const [];
    _labPackageOrders = results[11] as List<LabPackageOrderItem>? ?? const [];
    _chatThreads = results[12] as List<ChatThreadSummary>? ?? const [];
    _tickerMessages = results[13] as List<TickerMessageItem>? ?? const [];
    _homeOffers = results[14] as List<HomeOfferItem>? ?? const [];
    _departments = results[15] as List<DepartmentItem>? ?? const [];

    if (_chatThreads.isNotEmpty) {
      if (_activeChatThreadId == null ||
          _chatThreads.every((thread) => thread.id != _activeChatThreadId)) {
        _activeChatThreadId = _chatThreads.first.id;
      }
      final threadId = _activeChatThreadId!;
      final history = await safeLoad<List<ChatMessage>>(
        () => _repository.getGlobalChatHistory(threadId),
        'global chat history',
      );
      _chatHistories[threadId] = history ?? const [];
    } else {
      _activeChatThreadId = null;
      _chatHistories.clear();
    }

    if (loadErrors.isNotEmpty) {
      _errorMessage = loadErrors.first;
    }

    _isLoading = false;
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
}

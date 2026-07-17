import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../features/session/providers/session_provider.dart';
import '../data/patient_repository.dart';
import '../models/home_feed_models.dart';
import '../models/patient_models.dart';

part '../../bookings/utils/portal_provider_booking.dart';
part '../../assistant/utils/patient_portal_provider_chat.dart';
part '../../records/utils/patient_portal_provider_documents.dart';
part '../../home_care/utils/patient_portal_provider_home_care.dart';
part 'patient_portal_provider_load.dart';
part '../../profile/utils/patient_portal_provider_profile.dart';
part 'patient_portal_provider_health.dart';

class PatientPortalProvider extends ChangeNotifier {
  PatientPortalProvider({
    required PatientRepository repository,
    required SessionProvider sessionProvider,
  }) : _repository = repository,
       _sessionProvider = sessionProvider;

  final PatientRepository _repository;
  final SessionProvider _sessionProvider;
  int? _loadedPatientId;

  PatientDashboard? _dashboard;
  List<BookingItem> _bookings = const [];
  List<HomeBannerItem> _homeBanners = const [];
  List<TickerMessageItem> _tickerMessages = const [];
  List<HomeOfferItem> _homeOffers = const [];
  List<PrescriptionRecord> _prescriptions = const [];
  List<MedicalRecordItem> _medicalRecords = const [];
  List<DocumentRecord> _documents = const [];
  List<SummaryRecord> _summaries = const [];
  List<VitalRecord> _vitalTrend = const [];
  List<DoctorListing> _doctors = const [];
  List<LabTestItem> _labTests = const [];
  List<BodyPointItem> _bodyPoints = const [];
  List<LabOrderItem> _labOrders = const [];
  List<LabPackageItem> _labPackages = const [];
  List<LabPackageOrderItem> _labPackageOrders = const [];
  List<DepartmentItem> _departments = const [];
  List<FamilyMember> _familyMembers = const [];
  List<HomeCareServiceItem> _homeCareServices = const [];
  List<HomeCareBookingItem> _homeCareBookings = const [];
  HealthSnapshot? _healthSnapshot;
  List<HealthSnapshot> _healthSnapshotHistory = const [];
  int _healthSnapshotHistoryPage = 1;
  int _healthSnapshotHistoryLastPage = 1;
  bool _isLoadingHealthSnapshotHistory = false;
  bool _isLoadingMoreHealthSnapshotHistory = false;
  bool _isSubmittingHealthSnapshot = false;
  List<AiSuggestionItem> _aiSuggestions = const [];
  MyClubSummary? _myClub;
  List<ChatThreadSummary> _chatThreads = const [];
  String? _activeChatThreadId;
  final Map<String, List<ChatMessage>> _chatHistories =
      <String, List<ChatMessage>>{};
  final Map<int, DocumentAnalysisResult> _documentAnalyses =
      <int, DocumentAnalysisResult>{};
  final Map<int, List<ChatMessage>> _documentChats = <int, List<ChatMessage>>{};
  VoiceProviderConfig? _voiceProviderConfig;
  bool _isLoading = false;
  bool _isSavingProfile = false;
  bool _isSavingVitals = false;
  bool _isCreatingBooking = false;
  bool _isCreatingLabOrder = false;
  bool _isCreatingHomeCareBooking = false;
  bool _isUploadingDocument = false;
  int? _analyzingDocumentId;
  bool _isSendingMessage = false;
  int? _loadingDocumentChatId;
  int? _sendingDocumentChatId;
  DocumentAnalysisResult? _lastAnalysisResult;
  String? _errorMessage;

  PatientDashboard? get dashboard => _dashboard;
  List<BookingItem> get bookings => _bookings;
  List<HomeBannerItem> get homeBanners =>
      _homeBanners.where((banner) => !banner.isMobilePromoPopup).toList();
  List<HomeBannerItem> get promotionalHomeBanners =>
      _homeBanners.where((banner) => banner.isMobilePromoPopup).toList();
  VoiceProviderConfig? get voiceProviderConfig => _voiceProviderConfig;
  List<TickerMessageItem> get tickerMessages => _tickerMessages;
  List<HomeOfferItem> get homeOffers => _homeOffers;
  List<PrescriptionRecord> get prescriptions => _prescriptions;
  List<MedicalRecordItem> get medicalRecords => _medicalRecords;
  List<DocumentRecord> get documents => _documents;
  List<SummaryRecord> get summaries => _summaries;
  List<VitalRecord> get vitalTrend => _vitalTrend;
  List<DoctorListing> get doctors => _doctors;
  List<LabTestItem> get labTests => _labTests;
  List<BodyPointItem> get bodyPoints => _bodyPoints;
  List<LabOrderItem> get labOrders => _labOrders;
  List<LabPackageItem> get labPackages => _labPackages;
  List<LabPackageOrderItem> get labPackageOrders => _labPackageOrders;
  List<DepartmentItem> get departments => _departments;
  List<FamilyMember> get familyMembers => _familyMembers;
  List<HomeCareServiceItem> get homeCareServices => _homeCareServices;
  List<HomeCareBookingItem> get homeCareBookings => _homeCareBookings;
  HealthSnapshot? get healthSnapshot => _healthSnapshot;
  List<HealthSnapshot> get healthSnapshotHistory => _healthSnapshotHistory;
  bool get isLoadingHealthSnapshotHistory => _isLoadingHealthSnapshotHistory;
  bool get isLoadingMoreHealthSnapshotHistory =>
      _isLoadingMoreHealthSnapshotHistory;
  bool get hasMoreHealthSnapshotHistory =>
      _healthSnapshotHistoryPage < _healthSnapshotHistoryLastPage;
  bool get isSubmittingHealthSnapshot => _isSubmittingHealthSnapshot;
  List<AiSuggestionItem> get aiSuggestions => _aiSuggestions;
  MyClubSummary? get myClub => _myClub ?? _dashboard?.myClub;
  List<ChatThreadSummary> get chatThreads => _chatThreads;
  String? get activeChatThreadId => _activeChatThreadId;
  List<ChatMessage> get chatMessages {
    final threadId = _activeChatThreadId;
    if (threadId == null) return const [];
    return _chatHistories[threadId] ?? const [];
  }

  ChatThreadSummary? get activeChatThread {
    final threadId = _activeChatThreadId;
    if (threadId == null) return null;
    for (final thread in _chatThreads) {
      if (thread.id == threadId) return thread;
    }
    return null;
  }

  Map<int, DocumentAnalysisResult> get documentAnalyses => _documentAnalyses;
  bool get isLoading => _isLoading;
  bool get isSavingProfile => _isSavingProfile;
  bool get isSavingVitals => _isSavingVitals;
  bool get isCreatingBooking => _isCreatingBooking;
  bool get isCreatingLabOrder => _isCreatingLabOrder;
  bool get isCreatingHomeCareBooking => _isCreatingHomeCareBooking;
  bool get isUploadingDocument => _isUploadingDocument;
  int? get analyzingDocumentId => _analyzingDocumentId;
  bool get isSendingMessage => _isSendingMessage;
  int? get loadingDocumentChatId => _loadingDocumentChatId;
  int? get sendingDocumentChatId => _sendingDocumentChatId;
  DocumentAnalysisResult? get lastAnalysisResult => _lastAnalysisResult;
  String? get errorMessage => _errorMessage;

  List<ChatMessage> documentChatFor(int documentId) {
    return _documentChats[documentId] ?? const [];
  }

  DocumentAnalysisResult? analysisFor(int documentId) {
    return _documentAnalyses[documentId];
  }

  bool isDocumentChatLoading(int documentId) {
    return _loadingDocumentChatId == documentId;
  }

  bool isSendingDocumentChat(int documentId) {
    return _sendingDocumentChatId == documentId;
  }

  List<ChatMessage> chatMessagesFor(String threadId) {
    return _chatHistories[threadId] ?? const [];
  }

  void _notify() {
    notifyListeners();
  }

  void _resetPatientScopedState() {
    _dashboard = null;
    _bookings = const [];
    _homeBanners = const [];
    _tickerMessages = const [];
    _homeOffers = const [];
    _prescriptions = const [];
    _medicalRecords = const [];
    _documents = const [];
    _summaries = const [];
    _vitalTrend = const [];
    _doctors = const [];
    _labTests = const [];
    _bodyPoints = const [];
    _labOrders = const [];
    _labPackages = const [];
    _labPackageOrders = const [];
    _departments = const [];
    _familyMembers = const [];
    _homeCareServices = const [];
    _homeCareBookings = const [];
    _healthSnapshot = null;
    _healthSnapshotHistory = const [];
    _healthSnapshotHistoryPage = 1;
    _healthSnapshotHistoryLastPage = 1;
    _isLoadingHealthSnapshotHistory = false;
    _isLoadingMoreHealthSnapshotHistory = false;
    _isSubmittingHealthSnapshot = false;
    _isCreatingHomeCareBooking = false;
    _aiSuggestions = const [];
    _myClub = null;
    _chatThreads = const [];
    _activeChatThreadId = null;
    _chatHistories.clear();
    _documentAnalyses.clear();
    _documentChats.clear();
    _lastAnalysisResult = null;
    _loadingDocumentChatId = null;
    _sendingDocumentChatId = null;
    _analyzingDocumentId = null;
    _errorMessage = null;
  }
}

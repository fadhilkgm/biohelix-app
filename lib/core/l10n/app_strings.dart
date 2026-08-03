import '../providers/language_provider.dart';

class AppStrings {
  const AppStrings._();

  static const _en = _EnStrings();
  static const _ml = _MlStrings();

  static LocalizedStrings of(AppLanguage lang) {
    return switch (lang) {
      AppLanguage.en => _en,
      AppLanguage.ml => _ml,
    };
  }
}

abstract class LocalizedStrings {
  const LocalizedStrings();

  String get goodDay;
  String get goodMorning;
  String get goodAfternoon;
  String get goodEvening;
  String get goodNight;
  String get featuredDoctors;
  String get bookAppointments;
  String get popularLabTests;
  String get accurateResults;
  String get popularPackages;
  String get curatedBundles;
  String get specialOffers;
  String get viewOffer;
  String get upcomingAppointments;
  String get seeAll;
  String get exploreDoctors;
  String get summerHealthTips;
  String get quickActions;
  String get viewAll;
  String get defaultHealthTipMessage;
  String get defaultAnnouncement;
  String get noUpcomingAppointments;
  String get onboardingTitle;
  String get onboardingDescription;
  String get chooseLanguageTitle;
  String get chooseLanguageDescription;
  String get next;
  String get reviewPoliciesTitle;
  String get reviewPoliciesDescription;
  String get agreementConfirmation;
  String get dataPrivacyNoticeTitle;
  String get dataPrivacyNoticeBody;
  String get privacyPolicy;
  String get termsAndConditions;
  String get legalContentUnavailable;
  String get getStarted;
  String get biohelix;
  String get hospitalLocation;
  String get loginTitle;
  String get createAccountTitle;
  String get registrationPhoneTitle;
  String get loginSubtitle;
  String get registerSubtitle;
  String get registrationPhoneSubtitle;
  String get fullName;
  String get fullNameHint;
  String get mobileNumber;
  String get mobileNumberHint;
  String get password;
  String get passwordHint;
  String get dateOfBirth;
  String get dateOfBirthHint;
  String get email;
  String get emailHint;
  String get gender;
  String get genderHint;
  String get bloodGroup;
  String get bloodGroupHint;
  String get cityLocation;
  String get cityLocationHint;
  String get register;
  String get login;
  String get sendWhatsAppOtp;
  String get continueRegistration;
  String get registerWithWhatsAppOtp;
  String get alreadyRegisteredLogin;
  String get newPatientRegister;
  String get registerDemoHint;
  String get loginDemoHint;
  String get registrationPhoneHint;
  String get phoneNotRegisteredMessage;
  String get chooseDateOfBirth;
  String get cancel;
  String get fieldRequired;
  String get enterNamePhonePassword;
  String get enterPhonePassword;
  String get enterValidEmail;
  String get passwordMinLength;
  List<String> get genderOptions;
  List<String> get bloodGroupOptions;
  String get assistantFabLabel;
  String get assistantTitle;
  String get assistantReady;
  String get assistantListening;
  String get assistantSpeaking;
  String get assistantLiveModeActive;
  String get assistantInputHint;
  String get assistantDisclaimer;
  String get assistantLive;
  String get assistantStop;
  String get assistantRecording;
  String get assistantStartVoiceInput;
  String get assistantStopVoiceInput;
  String get assistantVoiceUnavailable;
  String get assistantLiveVoiceUnavailable;
  String get assistantUnableToListen;
  String get assistantPlayVoice;
  String get assistantStopVoice;
  String get assistantStopAiVoice;
  String get assistantInterruptAi;
  String get assistantPreviousChats;
  String get assistantNewChat;
  String get assistantBack;
  String get assistantRenameChat;
  String get assistantDeleteChat;
  String get assistantUploadingAttachment;
  String assistantUploadingNamedAttachment(String fileName);
  String assistantSummaryReady(String fileName);
  String assistantUploadPending(String fileName);
  String assistantUploadedReady(String fileName);
  List<String> get assistantStarterPrompts;

  // OTP
  String get otpVerifyTitle;
  String get otpSentPrefix;
  String get otpEnterLabel;
  String get otpVerifyButton;
  String get otpDidntReceive;
  String get otpResend;
  String get otpDevLabel;
  String get otpResentDefault;

  // Navigation
  String get navHome;
  String get navHealthStatus;
  String get navRecords;
  String get navReports;
  String get navBookings;
  String get navCheckup;
  String get navAssistant;
  String get navProfile;

  // App shell
  String get exitAppTitle;
  String get exitAppMessage;
  String get stay;
  String get exitApp;
  String get testsTitle;

  // Common actions
  String get save;
  String get delete;
  String get close;
  String get add;
  String get openLabel;
  String get switchProfile;
  String get active;
  String get accept;
  String get back;

  // Bookings
  String get appointmentCancelled;
  String get labBookingCancelled;
  String get packageBookingCancelled;
  String get doctorInfoMissing;
  String get selectTimeSlot;
  String get appointmentRescheduled;
  String get labTestRescheduled;
  String get packageRescheduled;
  String get preferredDate;
  String get routine;
  String get urgent;

  // Profile & reports
  String get reportPreviewUnavailable;
  String get couldNotPreviewImage;
  String get deleteReportTitle;
  String get reportDeleted;
  String get familyMemberAdded;
  String get profileUpdated;
  String get vitalsSaved;
  String get noUploadedReports;
  String get invalidReportLink;
  String get couldNotOpenReport;

  // Health profile
  String get healthProfileSaved;
  String couldNotSave(String error);

  // Home & discovery
  String get noDoctorsInDepartment;
  String couldNotStartCall(String number);
  String get bookConsultationForLovedOne;
  String get healthStatus;
  String forHealthDate(String date);
  String get healthMetric;
  String get riskMetric;
  String healthScoreSummary(String score);
  String updatedHealthAt(String date);
  String get viewHealthHistory;
  String get addTodayReadings;
  String get noHealthReadings;
  String get healthSnapshotReady;
  String get healthStatusSubtitle;
  String get fromDate;
  String get toDate;
  String get healthScoreTrend;
  String get comprehensiveSummary;
  String get latestScore;
  String get averageScore;
  String get scoreChange;
  String get reportsInRange;
  String get recentHealthReport;
  String get noHealthStatusData;
  String get noDataInSelectedRange;
  String get bloodSugarLabel;
  String get cholesterolLabel;

  // Labs & tests
  String get noLabTestsAvailable;
  String get noTestsFoundForFilters;
  String get viewHealthPackages;
  String get noRecordsFound;

  // Lab booking
  String get addNew;
  String get addNewPatient;
  String get addAddress;

  // Loyalty
  String get rewardsWallet;
  String tierLabel(String tier);

  // Quick actions
  String get aiPackageDesign;
  String get browsePackages;
  String bookAmount(String amount);
  String unknownQuickAction(String actionId);

  // AI checkup
  String couldNotLoadResult(String error);
  String analysisFailed(String error);

  // Emergency
  String couldNotStartCallTo(String phoneNumber);

  // Errors & dates
  String errorWithMessage(String error);
  String get today;
  String get yesterday;
}

class _EnStrings extends LocalizedStrings {
  const _EnStrings();

  @override
  String get goodDay => 'Have a good day,';
  @override
  String get goodMorning => 'Good Morning,';
  @override
  String get goodAfternoon => 'Good Afternoon,';
  @override
  String get goodEvening => 'Good Evening,';
  @override
  String get goodNight => 'Good Night,';
  @override
  String get featuredDoctors => 'Featured Doctors';
  @override
  String get bookAppointments => 'Book appointments with specialists';
  @override
  String get popularLabTests => 'Popular Lab Tests';
  @override
  String get accurateResults => 'Accurate results from certified labs';
  @override
  String get popularPackages => 'Popular Packages';
  @override
  String get curatedBundles => 'Curated bundles with better value';
  @override
  String get specialOffers => 'Special Offers';
  @override
  String get viewOffer => 'View Offer';
  @override
  String get upcomingAppointments => 'Upcoming Appointments';
  @override
  String get seeAll => 'See All';
  @override
  String get exploreDoctors => 'Explore doctors';
  @override
  String get summerHealthTips => 'SUMMER HEALTH TIPS';
  @override
  String get quickActions => 'Quick Actions';
  @override
  String get viewAll => 'View All';
  @override
  String get defaultHealthTipMessage =>
      'Take Atorvastatin at night for best effectiveness and avoid grapefruit';
  @override
  String get defaultAnnouncement => 'Eid Mubarak! Happy Onam...';
  @override
  String get noUpcomingAppointments => 'No upcoming appointments right now.';
  @override
  String get onboardingTitle => 'Your Smart Health Partner';
  @override
  String get onboardingDescription =>
      'Connect instantly with trusted doctors, book visits online, and manage your health anytime.';
  @override
  String get chooseLanguageTitle => 'Choose your language';
  @override
  String get chooseLanguageDescription =>
      'Select the language you would like to use throughout the BHRC app.';
  @override
  String get next => 'Next';
  @override
  String get reviewPoliciesTitle => 'Your privacy matters';
  @override
  String get reviewPoliciesDescription =>
      'Please review how we handle your information and the terms for using the app.';
  @override
  String get agreementConfirmation =>
      'I have read and agree to the Privacy Policy and Terms & Conditions.';
  @override
  String get dataPrivacyNoticeTitle => 'Your data and privacy';
  @override
  String get dataPrivacyNoticeBody =>
      'We securely handle your personal and health information to provide care. By continuing, you acknowledge our policies.';
  @override
  String get privacyPolicy => 'Privacy Policy';
  @override
  String get termsAndConditions => 'Terms & Conditions';
  @override
  String get legalContentUnavailable =>
      'This information is temporarily unavailable.';
  @override
  String get getStarted => 'Get Started';
  @override
  String get biohelix => 'BHRC';
  @override
  String get hospitalLocation =>
      'Health And Research Center\nPonnani, Malappuram';
  @override
  String get loginTitle => 'Login';
  @override
  String get createAccountTitle => 'Create account';
  @override
  String get registrationPhoneTitle => 'Check your mobile number';
  @override
  String get loginSubtitle =>
      'Enter your mobile number and we will send a WhatsApp OTP.';
  @override
  String get registerSubtitle =>
      'Complete your patient profile. We will verify your number with a WhatsApp OTP.';
  @override
  String get registrationPhoneSubtitle =>
      'Enter your number first. If an account already exists, we will log you in instead.';
  @override
  String get fullName => 'Full Name';
  @override
  String get fullNameHint => 'Aisha Rahman';
  @override
  String get mobileNumber => 'Mobile Number';
  @override
  String get mobileNumberHint => '+919876543210';
  @override
  String get password => 'Password';
  @override
  String get passwordHint => 'Enter password';
  @override
  String get dateOfBirth => 'Date of Birth';
  @override
  String get dateOfBirthHint => 'Select date';
  @override
  String get email => 'Email';
  @override
  String get emailHint => 'aisha.rahman@example.com';
  @override
  String get gender => 'Gender';
  @override
  String get genderHint => 'Select gender';
  @override
  String get bloodGroup => 'Blood Group';
  @override
  String get bloodGroupHint => 'Select blood group';
  @override
  String get cityLocation => 'City / Location';
  @override
  String get cityLocationHint => 'Ponnani, Kerala';
  @override
  String get register => 'Register';
  @override
  String get login => 'Login';
  @override
  String get sendWhatsAppOtp => 'Send WhatsApp OTP';
  @override
  String get continueRegistration => 'Continue';
  @override
  String get registerWithWhatsAppOtp => 'Register & send WhatsApp OTP';
  @override
  String get alreadyRegisteredLogin => 'Already registered? Login';
  @override
  String get newPatientRegister => 'New patient? Register';
  @override
  String get registerDemoHint =>
      'We will send a WhatsApp OTP to verify your number before creating your account.';
  @override
  String get loginDemoHint =>
      'Existing patients can sign in with a WhatsApp OTP sent to their registered number.';
  @override
  String get registrationPhoneHint =>
      'We check your number before showing the registration form.';
  @override
  String get phoneNotRegisteredMessage =>
      'This mobile number is not registered. You can create a new account.';
  @override
  String get chooseDateOfBirth => 'Choose date of birth';
  @override
  String get cancel => 'Cancel';
  @override
  String get fieldRequired => 'This field is required.';
  @override
  String get enterNamePhonePassword =>
      'Enter your name, phone number, and password.';
  @override
  String get enterPhonePassword => 'Enter your phone number and password.';
  @override
  String get enterValidEmail => 'Enter a valid email address.';
  @override
  String get passwordMinLength => 'Password must be at least 8 characters.';
  @override
  List<String> get genderOptions => const ['Female', 'Male', 'Other'];
  @override
  List<String> get bloodGroupOptions => const [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  @override
  String get assistantFabLabel => 'Health AI';
  @override
  String get assistantTitle => 'Health AI';
  @override
  String get assistantReady => 'Ready';
  @override
  String get assistantListening => 'Listening to you';
  @override
  String get assistantSpeaking => 'AI is talking';
  @override
  String get assistantLiveModeActive => 'Live mode active';
  @override
  String get assistantInputHint => 'Ask about your health';
  @override
  String get assistantDisclaimer =>
      'AI can make mistakes. Consult a doctor before acting.';
  @override
  String get assistantLive => 'Live';
  @override
  String get assistantStop => 'Stop';
  @override
  String get assistantRecording => 'REC';
  @override
  String get assistantStartVoiceInput => 'Start voice input';
  @override
  String get assistantStopVoiceInput => 'Stop voice input';
  @override
  String get assistantVoiceUnavailable =>
      'Voice input unavailable. Please allow microphone permission and enable a speech recognition service.';
  @override
  String get assistantLiveVoiceUnavailable =>
      'Live voice unavailable. Please allow microphone permission and enable a speech recognition service.';
  @override
  String get assistantUnableToListen => 'Unable to start voice listening';
  @override
  String get assistantPlayVoice => 'Play voice';
  @override
  String get assistantStopVoice => 'Stop voice';
  @override
  String get assistantStopAiVoice => 'Stop AI voice';
  @override
  String get assistantInterruptAi => 'Interrupt AI and talk';
  @override
  String get assistantPreviousChats => 'Previous Chats';
  @override
  String get assistantNewChat => 'New chat';
  @override
  String get assistantBack => 'Back';
  @override
  String get assistantRenameChat => 'Rename chat';
  @override
  String get assistantDeleteChat => 'Delete chat';
  @override
  String get assistantUploadingAttachment => 'Uploading attachment...';
  @override
  String assistantUploadingNamedAttachment(String fileName) =>
      'Uploading $fileName...';
  @override
  String assistantSummaryReady(String fileName) =>
      'Summary ready for $fileName in Reports.';
  @override
  String assistantUploadPending(String fileName) =>
      'Uploaded $fileName, but summary generation is still pending.';
  @override
  String assistantUploadedReady(String fileName) =>
      'Uploaded $fileName. You can tap it to preview, then send your message.';
  @override
  List<String> get assistantStarterPrompts => const [
    'Explain my latest lab report',
    'What tests should I consider?',
    'Help me book a health package',
  ];

  // OTP
  @override
  String get otpVerifyTitle => 'Verify WhatsApp OTP';
  @override
  String get otpSentPrefix => 'A 6-digit code has been sent on WhatsApp to ';
  @override
  String get otpEnterLabel => 'ENTER OTP';
  @override
  String get otpVerifyButton => 'Verify OTP';
  @override
  String get otpDidntReceive => "Didn't receive? ";
  @override
  String get otpResend => 'Resend OTP';
  @override
  String get otpDevLabel => 'DEVELOPMENT OTP';
  @override
  String get otpResentDefault => 'OTP resent to your WhatsApp';

  // Navigation
  @override
  String get navHome => 'Home';
  @override
  String get navHealthStatus => 'Health Status';
  @override
  String get navRecords => 'Records';
  @override
  String get navReports => 'Reports';
  @override
  String get navBookings => 'Bookings';
  @override
  String get navCheckup => 'Checkup';
  @override
  String get navAssistant => 'AI Assistant';
  @override
  String get navProfile => 'Profile';

  // App shell
  @override
  String get exitAppTitle => 'Exit BHRC?';
  @override
  String get exitAppMessage =>
      'Press Stay to keep using the app, or Exit to close it.';
  @override
  String get stay => 'Stay';
  @override
  String get exitApp => 'Exit';
  @override
  String get testsTitle => 'Tests';

  // Common actions
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get close => 'Close';
  @override
  String get add => 'Add';
  @override
  String get openLabel => 'Open';
  @override
  String get switchProfile => 'Switch';
  @override
  String get active => 'Active';
  @override
  String get accept => 'Accept';
  @override
  String get back => 'Back';

  // Bookings
  @override
  String get appointmentCancelled => 'Appointment cancelled.';
  @override
  String get labBookingCancelled => 'Lab booking cancelled.';
  @override
  String get packageBookingCancelled => 'Package booking cancelled.';
  @override
  String get doctorInfoMissing =>
      'Doctor information is missing. Please refresh.';
  @override
  String get selectTimeSlot => 'Please select a time slot.';
  @override
  String get appointmentRescheduled => 'Appointment rescheduled successfully.';
  @override
  String get labTestRescheduled => 'Lab test rescheduled successfully.';
  @override
  String get packageRescheduled => 'Package rescheduled successfully.';
  @override
  String get preferredDate => 'Preferred date';
  @override
  String get routine => 'Routine';
  @override
  String get urgent => 'Urgent';

  // Profile & reports
  @override
  String get reportPreviewUnavailable => 'Report preview unavailable.';
  @override
  String get couldNotPreviewImage => 'Could not preview this image.';
  @override
  String get deleteReportTitle => 'Delete report';
  @override
  String get reportDeleted => 'Report deleted.';
  @override
  String get familyMemberAdded => 'Family member added and switched.';
  @override
  String get profileUpdated => 'Profile updated.';
  @override
  String get vitalsSaved => 'Vitals saved.';
  @override
  String get noUploadedReports => 'No uploaded reports yet.';
  @override
  String get invalidReportLink => 'Invalid report link.';
  @override
  String get couldNotOpenReport => 'Could not open report.';

  // Health profile
  @override
  String get healthProfileSaved => 'Health profile saved.';
  @override
  String couldNotSave(String error) => 'Could not save: $error';

  // Home & discovery
  @override
  String get noDoctorsInDepartment => 'No doctors found in this department.';
  @override
  String couldNotStartCall(String number) =>
      'Could not start a call to $number';
  @override
  String get bookConsultationForLovedOne =>
      'Book a consultation for your loved one';
  @override
  String get healthStatus => 'Health Status';
  @override
  String forHealthDate(String date) => 'For $date';
  @override
  String get healthMetric => 'Health';
  @override
  String get riskMetric => 'Risk';
  @override
  String healthScoreSummary(String score) => 'Health score: $score/100.';
  @override
  String updatedHealthAt(String date) => 'Updated $date';
  @override
  String get viewHealthHistory => 'View health history';
  @override
  String get addTodayReadings => "Add today's readings";
  @override
  String get noHealthReadings =>
      "No readings recorded yet — add today's readings to get your score.";
  @override
  String get healthSnapshotReady => 'Your health update is ready.';
  @override
  String get healthStatusSubtitle =>
      'Review recent health trends and summaries for a selected date range.';
  @override
  String get fromDate => 'From';
  @override
  String get toDate => 'To';
  @override
  String get healthScoreTrend => 'Health score trend';
  @override
  String get comprehensiveSummary => 'Comprehensive summary';
  @override
  String get latestScore => 'Latest score';
  @override
  String get averageScore => 'Average score';
  @override
  String get scoreChange => 'Score change';
  @override
  String get reportsInRange => 'Reports in range';
  @override
  String get recentHealthReport => 'Recent health report';
  @override
  String get noHealthStatusData => 'No health data';
  @override
  String get noDataInSelectedRange => 'No scores in the selected date range.';
  @override
  String get bloodSugarLabel => 'Blood sugar';
  @override
  String get cholesterolLabel => 'Cholesterol';

  // Labs & tests
  @override
  String get noLabTestsAvailable => 'No lab tests are available right now.';
  @override
  String get noTestsFoundForFilters =>
      'No tests found for the selected filters.';
  @override
  String get viewHealthPackages => 'View health packages';
  @override
  String get noRecordsFound => 'No records found.';

  // Lab booking
  @override
  String get addNew => 'Add New';
  @override
  String get addNewPatient => 'Add New Patient';
  @override
  String get addAddress => 'Add Address';

  // Loyalty
  @override
  String get rewardsWallet => 'Rewards Wallet';
  @override
  String tierLabel(String tier) => 'Tier: $tier';

  // Quick actions
  @override
  String get aiPackageDesign => 'AI Package Design';
  @override
  String get browsePackages => 'Browse packages';
  @override
  String bookAmount(String amount) => 'Book ₹$amount';
  @override
  String unknownQuickAction(String actionId) =>
      'Unknown quick action: $actionId';

  // AI checkup
  @override
  String couldNotLoadResult(String error) => 'Could not load result: $error';
  @override
  String analysisFailed(String error) => 'Analysis failed: $error';

  // Emergency
  @override
  String couldNotStartCallTo(String phoneNumber) =>
      'Could not start a call to $phoneNumber.';

  // Errors & dates
  @override
  String errorWithMessage(String error) => 'Error: $error';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
}

class _MlStrings extends LocalizedStrings {
  const _MlStrings();

  @override
  String get goodDay => 'നല്ലൊരു ദിവസം ആശംസിക്കുന്നു,';
  @override
  String get goodMorning => 'സുപ്രഭാതം,';
  @override
  String get goodAfternoon => 'ശുഭ ഉച്ചതിരിഞ്ഞ്,';
  @override
  String get goodEvening => 'ശുഭസായാഹ്നം,';
  @override
  String get goodNight => 'ശുഭ രാത്രി,';
  @override
  String get featuredDoctors => 'പ്രമുഖ ഡോക്ടർമാർ';
  @override
  String get bookAppointments =>
      'സ്പെഷ്യലിസ്റ്റുകളുമായി അപ്പോയിന്റ്മെന്റ് ബുക്ക് ചെയ്യുക';
  @override
  String get popularLabTests => 'ജനപ്രിയ ലാബ് ടെസ്റ്റുകൾ';
  @override
  String get accurateResults => 'സർട്ടിഫൈഡ് ലാബുകളിൽ നിന്ന് കൃത്യമായ ഫലങ്ങൾ';
  @override
  String get popularPackages => 'ജനപ്രിയ പാക്കേജുകൾ';
  @override
  String get curatedBundles => 'മികച്ച മൂല്യമുള്ള തിരഞ്ഞെടുത്ത ബണ്ടിലുകൾ';
  @override
  String get specialOffers => 'പ്രത്യേക ഓഫറുകൾ';
  @override
  String get viewOffer => 'ഓഫർ കാണുക';
  @override
  String get upcomingAppointments => 'വരാനിരിക്കുന്ന അപ്പോയിന്റ്മെന്റുകൾ';
  @override
  String get seeAll => 'എല്ലാം കാണുക';
  @override
  String get exploreDoctors => 'ഡോക്ടർമാരെ കണ്ടെത്തുക';
  @override
  String get summerHealthTips => 'വേനൽക്കാല ആരോഗ്യ നിർദ്ദേശങ്ങൾ';
  @override
  String get quickActions => 'ദ്രുത പ്രവർത്തനങ്ങൾ';
  @override
  String get viewAll => 'എല്ലാം കാണുക';
  @override
  String get defaultHealthTipMessage =>
      'മരുന്നുകൾ ഡോക്ടർ നിർദ്ദേശിച്ച സമയത്ത് മാത്രം കഴിക്കുക';
  @override
  String get defaultAnnouncement => 'ഈദ് മുബാറക്! ഓണം ആശംസകൾ...';
  @override
  String get noUpcomingAppointments =>
      'ഇപ്പോൾ വരാനിരിക്കുന്ന അപ്പോയിന്റ്മെന്റുകൾ ഇല്ല.';
  @override
  String get onboardingTitle => 'നിങ്ങളുടെ സ്മാർട്ട് ആരോഗ്യ പങ്കാളി';
  @override
  String get onboardingDescription =>
      'വിശ്വസനീയമായ ഡോക്ടർമാരുമായി ഉടൻ ബന്ധപ്പെടൂ, ഓൺലൈനായി സന്ദർശനം ബുക്ക് ചെയ്യൂ, ആരോഗ്യ വിവരങ്ങൾ എപ്പോൾ വേണമെങ്കിലും നിയന്ത്രിക്കൂ.';
  @override
  String get chooseLanguageTitle => 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക';
  @override
  String get chooseLanguageDescription =>
      'BHRC ആപ്പിൽ ഉപയോഗിക്കാൻ ആഗ്രഹിക്കുന്ന ഭാഷ തിരഞ്ഞെടുക്കുക.';
  @override
  String get next => 'അടുത്തത്';
  @override
  String get reviewPoliciesTitle => 'നിങ്ങളുടെ സ്വകാര്യത പ്രധാനമാണ്';
  @override
  String get reviewPoliciesDescription =>
      'നിങ്ങളുടെ വിവരങ്ങൾ ഞങ്ങൾ എങ്ങനെ കൈകാര്യം ചെയ്യുന്നു എന്നും ആപ്പ് ഉപയോഗിക്കുന്നതിനുള്ള നിബന്ധനകളും ദയവായി വായിക്കുക.';
  @override
  String get agreementConfirmation =>
      'സ്വകാര്യതാ നയവും നിബന്ധനകളും വ്യവസ്ഥകളും ഞാൻ വായിക്കുകയും അംഗീകരിക്കുകയും ചെയ്യുന്നു.';
  @override
  String get dataPrivacyNoticeTitle => 'നിങ്ങളുടെ വിവരങ്ങളും സ്വകാര്യതയും';
  @override
  String get dataPrivacyNoticeBody =>
      'നിങ്ങൾക്ക് ആരോഗ്യ സേവനങ്ങൾ നൽകുന്നതിനായി വ്യക്തിഗതവും ആരോഗ്യവുമായി ബന്ധപ്പെട്ടതുമായ വിവരങ്ങൾ ഞങ്ങൾ സുരക്ഷിതമായി കൈകാര്യം ചെയ്യുന്നു. തുടരുന്നതിലൂടെ ഞങ്ങളുടെ നയങ്ങൾ നിങ്ങൾ അംഗീകരിക്കുന്നു.';
  @override
  String get privacyPolicy => 'സ്വകാര്യതാ നയം';
  @override
  String get termsAndConditions => 'നിബന്ധനകളും വ്യവസ്ഥകളും';
  @override
  String get legalContentUnavailable => 'ഈ വിവരം ഇപ്പോൾ ലഭ്യമല്ല.';
  @override
  String get getStarted => 'തുടങ്ങുക';
  @override
  String get biohelix => 'BHRC';
  @override
  String get hospitalLocation =>
      'ഹെൽത്ത് ആൻഡ് റിസർച്ച് സെന്റർ\nപൊന്നാനി, മലപ്പുറം';
  @override
  String get loginTitle => 'ലോഗിൻ';
  @override
  String get createAccountTitle => 'അക്കൗണ്ട് സൃഷ്ടിക്കുക';
  @override
  String get registrationPhoneTitle => 'നിങ്ങളുടെ മൊബൈൽ നമ്പർ പരിശോധിക്കുക';
  @override
  String get loginSubtitle =>
      'തുടരാൻ നിങ്ങളുടെ മൊബൈൽ നമ്പർ നൽകുക, ഞങ്ങൾ വാട്സ്ആപ്പ് OTP അയയ്ക്കും.';
  @override
  String get registerSubtitle =>
      'നിങ്ങളുടെ രോഗി പ്രൊഫൈൽ പൂർത്തിയാക്കുക. നമ്പർ വാട്സ്ആപ്പ് OTP വഴി സ്ഥിരീകരിക്കും.';
  @override
  String get registrationPhoneSubtitle =>
      'ആദ്യം നിങ്ങളുടെ നമ്പർ നൽകുക. അക്കൗണ്ട് നിലവിലുണ്ടെങ്കിൽ രജിസ്ട്രേഷനു പകരം ലോഗിൻ ചെയ്യാം.';
  @override
  String get fullName => 'പൂർണ്ണ പേര്';
  @override
  String get fullNameHint => 'ആയിഷ റഹ്മാൻ';
  @override
  String get mobileNumber => 'മൊബൈൽ നമ്പർ';
  @override
  String get mobileNumberHint => '+919876543210';
  @override
  String get password => 'പാസ്‌വേഡ്';
  @override
  String get passwordHint => 'പാസ്‌വേഡ് നൽകുക';
  @override
  String get dateOfBirth => 'ജനന തീയതി';
  @override
  String get dateOfBirthHint => 'തീയതി തിരഞ്ഞെടുക്കുക';
  @override
  String get email => 'ഇമെയിൽ';
  @override
  String get emailHint => 'aisha.rahman@example.com';
  @override
  String get gender => 'ലിംഗം';
  @override
  String get genderHint => 'ലിംഗം തിരഞ്ഞെടുക്കുക';
  @override
  String get bloodGroup => 'രക്ത ഗ്രൂപ്പ്';
  @override
  String get bloodGroupHint => 'രക്ത ഗ്രൂപ്പ് തിരഞ്ഞെടുക്കുക';
  @override
  String get cityLocation => 'നഗരം / സ്ഥലം';
  @override
  String get cityLocationHint => 'പൊന്നാനി, കേരളം';
  @override
  String get register => 'രജിസ്റ്റർ';
  @override
  String get login => 'ലോഗിൻ';
  @override
  String get sendWhatsAppOtp => 'വാട്സ്ആപ്പ് OTP അയയ്ക്കുക';
  @override
  String get continueRegistration => 'തുടരുക';
  @override
  String get registerWithWhatsAppOtp =>
      'രജിസ്റ്റർ ചെയ്ത് വാട്സ്ആപ്പ് OTP അയയ്ക്കുക';
  @override
  String get alreadyRegisteredLogin => 'ഇതിനകം രജിസ്റ്റർ ചെയ്തിട്ടുണ്ടോ? ലോഗിൻ';
  @override
  String get newPatientRegister => 'പുതിയ രോഗിയാണോ? രജിസ്റ്റർ';
  @override
  String get registerDemoHint =>
      'അക്കൗണ്ട് സൃഷ്ടിക്കുന്നതിന് മുമ്പ് നിങ്ങളുടെ നമ്പർ സ്ഥിരീകരിക്കാൻ വാട്സ്ആപ്പ് OTP അയയ്ക്കും.';
  @override
  String get loginDemoHint =>
      'രജിസ്റ്റർ ചെയ്ത രോഗികൾക്ക് അവരുടെ നമ്പറിലേക്ക് അയയ്ക്കുന്ന വാട്സ്ആപ്പ് OTP ഉപയോഗിച്ച് സൈൻ ഇൻ ചെയ്യാം.';
  @override
  String get registrationPhoneHint =>
      'രജിസ്ട്രേഷൻ ഫോം കാണിക്കുന്നതിന് മുമ്പ് നിങ്ങളുടെ നമ്പർ പരിശോധിക്കും.';
  @override
  String get phoneNotRegisteredMessage =>
      'ഈ മൊബൈൽ നമ്പർ രജിസ്റ്റർ ചെയ്തിട്ടില്ല. നിങ്ങൾക്ക് പുതിയ അക്കൗണ്ട് സൃഷ്ടിക്കാം.';
  @override
  String get chooseDateOfBirth => 'ജനന തീയതി തിരഞ്ഞെടുക്കുക';
  @override
  String get cancel => 'റദ്ദാക്കുക';
  @override
  String get fieldRequired => 'ഈ ഫീൽഡ് നിർബന്ധമാണ്.';
  @override
  String get enterNamePhonePassword =>
      'നിങ്ങളുടെ പേര്, ഫോൺ നമ്പർ, പാസ്‌വേഡ് എന്നിവ നൽകുക.';
  @override
  String get enterPhonePassword => 'നിങ്ങളുടെ ഫോൺ നമ്പറും പാസ്‌വേഡും നൽകുക.';
  @override
  String get enterValidEmail => 'ശരിയായ ഇമെയിൽ വിലാസം നൽകുക.';
  @override
  String get passwordMinLength => 'പാസ്‌വേഡ് കുറഞ്ഞത് 8 അക്ഷരമെങ്കിലും വേണം.';
  @override
  List<String> get genderOptions => const ['സ്ത്രീ', 'പുരുഷൻ', 'മറ്റുള്ളവ'];
  @override
  List<String> get bloodGroupOptions => const [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  @override
  String get assistantFabLabel => 'ഹെൽത്ത് AI';
  @override
  String get assistantTitle => 'ഹെൽത്ത് AI';
  @override
  String get assistantReady => 'തയ്യാർ';
  @override
  String get assistantListening => 'നിങ്ങളെ കേൾക്കുന്നു';
  @override
  String get assistantSpeaking => 'AI സംസാരിക്കുന്നു';
  @override
  String get assistantLiveModeActive => 'ലൈവ് മോഡ് പ്രവർത്തിക്കുന്നു';
  @override
  String get assistantInputHint => 'ആരോഗ്യം ചോദിക്കൂ';
  @override
  String get assistantDisclaimer =>
      'AI തെറ്റുകൾ ചെയ്യാം. നടപടി എടുക്കുന്നതിന് മുമ്പ് ഡോക്ടറെ സമീപിക്കുക.';
  @override
  String get assistantLive => 'ലൈവ്';
  @override
  String get assistantStop => 'നിർത്തുക';
  @override
  String get assistantRecording => 'REC';
  @override
  String get assistantStartVoiceInput => 'വോയ്സ് ഇൻപുട്ട് ആരംഭിക്കുക';
  @override
  String get assistantStopVoiceInput => 'വോയ്സ് ഇൻപുട്ട് നിർത്തുക';
  @override
  String get assistantVoiceUnavailable =>
      'വോയ്സ് ഇൻപുട്ട് ലഭ്യമല്ല. മൈക്രോഫോൺ അനുമതിയും സ്പീച്ച് റെക്കഗ്നിഷൻ സേവനവും പരിശോധിക്കുക.';
  @override
  String get assistantLiveVoiceUnavailable =>
      'ലൈവ് വോയ്സ് ലഭ്യമല്ല. മൈക്രോഫോൺ അനുമതിയും സ്പീച്ച് റെക്കഗ്നിഷൻ സേവനവും പരിശോധിക്കുക.';
  @override
  String get assistantUnableToListen => 'വോയ്സ് കേൾക്കൽ ആരംഭിക്കാൻ കഴിഞ്ഞില്ല';
  @override
  String get assistantPlayVoice => 'വോയ്സ് പ്ലേ ചെയ്യുക';
  @override
  String get assistantStopVoice => 'വോയ്സ് നിർത്തുക';
  @override
  String get assistantStopAiVoice => 'AI വോയ്സ് നിർത്തുക';
  @override
  String get assistantInterruptAi => 'AI നിർത്തി സംസാരിക്കുക';
  @override
  String get assistantPreviousChats => 'മുൻ ചാറ്റുകൾ';
  @override
  String get assistantNewChat => 'പുതിയ ചാറ്റ്';
  @override
  String get assistantBack => 'പിന്നോട്ട്';
  @override
  String get assistantRenameChat => 'ചാറ്റ് പേര് മാറ്റുക';
  @override
  String get assistantDeleteChat => 'ചാറ്റ് ഇല്ലാതാക്കുക';
  @override
  String get assistantUploadingAttachment =>
      'അറ്റാച്ച്മെന്റ് അപ്ലോഡ് ചെയ്യുന്നു...';
  @override
  String assistantUploadingNamedAttachment(String fileName) =>
      '$fileName അപ്ലോഡ് ചെയ്യുന്നു...';
  @override
  String assistantSummaryReady(String fileName) =>
      '$fileName ന്റെ സംഗ്രഹം Reports-ൽ തയ്യാറാണ്.';
  @override
  String assistantUploadPending(String fileName) =>
      '$fileName അപ്ലോഡ് ചെയ്തു, പക്ഷേ സംഗ്രഹം ഇപ്പോഴും തയ്യാറാകുന്നു.';
  @override
  String assistantUploadedReady(String fileName) =>
      '$fileName അപ്ലോഡ് ചെയ്തു. പ്രിവ്യൂ ചെയ്യാൻ ടാപ്പ് ചെയ്ത് സന്ദേശം അയക്കാം.';
  @override
  List<String> get assistantStarterPrompts => const [
    'എന്റെ പുതിയ ലാബ് റിപ്പോർട്ട് വിശദീകരിക്കൂ',
    'എന്തെല്ലാം ടെസ്റ്റുകൾ പരിഗണിക്കണം?',
    'ഒരു ഹെൽത്ത് പാക്കേജ് ബുക്ക് ചെയ്യാൻ സഹായിക്കൂ',
  ];

  // OTP
  @override
  String get otpVerifyTitle => 'വാട്സ്ആപ്പ് OTP സ്ഥിരീകരിക്കുക';
  @override
  String get otpSentPrefix => 'വാട്സ്ആപ്പിലേക്ക് 6 അക്ക കോഡ് അയച്ചിട്ടുണ്ട് ';
  @override
  String get otpEnterLabel => 'OTP നൽകുക';
  @override
  String get otpVerifyButton => 'OTP സ്ഥിരീകരിക്കുക';
  @override
  String get otpDidntReceive => 'ലഭിച്ചില്ലേ? ';
  @override
  String get otpResend => 'OTP വീണ്ടും അയയ്ക്കുക';
  @override
  String get otpDevLabel => 'ഡെവലപ്മെന്റ് OTP';
  @override
  String get otpResentDefault =>
      'OTP നിങ്ങളുടെ വാട്സ്ആപ്പിലേക്ക് വീണ്ടും അയച്ചു';

  // Navigation
  @override
  String get navHome => 'ഹോം';
  @override
  String get navHealthStatus => 'ആരോഗ്യ നില';
  @override
  String get navRecords => 'റെക്കോർഡുകൾ';
  @override
  String get navReports => 'റിപ്പോർട്ടുകൾ';
  @override
  String get navBookings => 'ബുക്കിംഗുകൾ';
  @override
  String get navCheckup => 'ചെക്കപ്പ്';
  @override
  String get navAssistant => 'AI അസിസ്റ്റന്റ്';
  @override
  String get navProfile => 'പ്രൊഫൈൽ';

  // App shell
  @override
  String get exitAppTitle => 'BHRC അടയ്ക്കണോ?';
  @override
  String get exitAppMessage =>
      'ആപ്പ് തുടരാൻ "തുടരുക" അമർത്തുക, അടയ്ക്കാൻ "അടയ്ക്കുക" അമർത്തുക.';
  @override
  String get stay => 'തുടരുക';
  @override
  String get exitApp => 'അടയ്ക്കുക';
  @override
  String get testsTitle => 'ടെസ്റ്റുകൾ';

  // Common actions
  @override
  String get save => 'സംരക്ഷിക്കുക';
  @override
  String get delete => 'ഇല്ലാതാക്കുക';
  @override
  String get close => 'അടയ്ക്കുക';
  @override
  String get add => 'ചേർക്കുക';
  @override
  String get openLabel => 'തുറക്കുക';
  @override
  String get switchProfile => 'മാറ്റുക';
  @override
  String get active => 'സജീവം';
  @override
  String get accept => 'സ്വീകരിക്കുക';
  @override
  String get back => 'പിന്നോട്ട്';

  // Bookings
  @override
  String get appointmentCancelled => 'അപ്പോയിന്റ്മെന്റ് റദ്ദാക്കി.';
  @override
  String get labBookingCancelled => 'ലാബ് ബുക്കിംഗ് റദ്ദാക്കി.';
  @override
  String get packageBookingCancelled => 'പാക്കേജ് ബുക്കിംഗ് റദ്ദാക്കി.';
  @override
  String get doctorInfoMissing =>
      'ഡോക്ടർ വിവരങ്ങൾ ലഭ്യമല്ല. ദയവായി റിഫ്രഷ് ചെയ്യുക.';
  @override
  String get selectTimeSlot => 'ദയവായി ഒരു സമയ സ്ലോട്ട് തിരഞ്ഞെടുക്കുക.';
  @override
  String get appointmentRescheduled =>
      'അപ്പോയിന്റ്മെന്റ് വിജയകരമായി പുനഃക്രമീകരിച്ചു.';
  @override
  String get labTestRescheduled => 'ലാബ് ടെസ്റ്റ് വിജയകരമായി പുനഃക്രമീകരിച്ചു.';
  @override
  String get packageRescheduled => 'പാക്കേജ് വിജയകരമായി പുനഃക്രമീകരിച്ചു.';
  @override
  String get preferredDate => 'തിരഞ്ഞെടുത്ത തീയതി';
  @override
  String get routine => 'സാധാരണ';
  @override
  String get urgent => 'അടിയന്തര';

  // Profile & reports
  @override
  String get reportPreviewUnavailable => 'റിപ്പോർട്ട് പ്രിവ്യൂ ലഭ്യമല്ല.';
  @override
  String get couldNotPreviewImage => 'ഈ ചിത്രം പ്രിവ്യൂ ചെയ്യാൻ കഴിഞ്ഞില്ല.';
  @override
  String get deleteReportTitle => 'റിപ്പോർട്ട് ഇല്ലാതാക്കുക';
  @override
  String get reportDeleted => 'റിപ്പോർട്ട് ഇല്ലാതാക്കി.';
  @override
  String get familyMemberAdded => 'കുടുംബാംഗത്തെ ചേർത്തു.';
  @override
  String get profileUpdated => 'പ്രൊഫൈൽ പുതുക്കി.';
  @override
  String get vitalsSaved => 'ആരോഗ്യ അളവുകൾ സംരക്ഷിച്ചു.';
  @override
  String get noUploadedReports => 'അപ്ലോഡ് ചെയ്ത റിപ്പോർട്ടുകൾ ഇല്ല.';
  @override
  String get invalidReportLink => 'അസാധുവായ റിപ്പോർട്ട് ലിങ്ക്.';
  @override
  String get couldNotOpenReport => 'റിപ്പോർട്ട് തുറക്കാൻ കഴിഞ്ഞില്ല.';

  // Health profile
  @override
  String get healthProfileSaved => 'ആരോഗ്യ പ്രൊഫൈൽ സംരക്ഷിച്ചു.';
  @override
  String couldNotSave(String error) => 'സംരക്ഷിക്കാൻ കഴിഞ്ഞില്ല: $error';

  // Home & discovery
  @override
  String get noDoctorsInDepartment => 'ഈ വിഭാഗത്തിൽ ഡോക്ടർമാരെ കണ്ടെത്തിയില്ല.';
  @override
  String couldNotStartCall(String number) =>
      '$number എന്ന നമ്പറിലേക്ക് കോൾ ആരംഭിക്കാൻ കഴിഞ്ഞില്ല';
  @override
  String get bookConsultationForLovedOne =>
      'നിങ്ങളുടെ പ്രിയപ്പെട്ടവർക്കായി കൺസൾട്ടേഷൻ ബുക്ക് ചെയ്യൂ.';
  @override
  String get healthStatus => 'ആരോഗ്യ നില';
  @override
  String forHealthDate(String date) => 'തീയതി: $date';
  @override
  String get healthMetric => 'ആരോഗ്യം';
  @override
  String get riskMetric => 'അപകടസാധ്യത';
  @override
  String healthScoreSummary(String score) => 'ആരോഗ്യ സ്കോർ: $score/100.';
  @override
  String updatedHealthAt(String date) => 'അവസാനം പുതുക്കിയത്: $date';
  @override
  String get viewHealthHistory => 'ആരോഗ്യ ചരിത്രം കാണുക';
  @override
  String get addTodayReadings => 'ഇന്നത്തെ അളവുകൾ ചേർക്കുക';
  @override
  String get noHealthReadings =>
      'ഇതുവരെ അളവുകളൊന്നും രേഖപ്പെടുത്തിയിട്ടില്ല — സ്കോർ ലഭിക്കാൻ ഇന്നത്തെ അളവുകൾ ചേർക്കുക.';
  @override
  String get healthSnapshotReady => 'നിങ്ങളുടെ ആരോഗ്യ അപ്ഡേറ്റ് തയ്യാറാണ്.';
  @override
  String get healthStatusSubtitle =>
      'തിരഞ്ഞെടുത്ത തീയതി പരിധിയിലെ സമീപകാല ആരോഗ്യ പ്രവണതകളും സംഗ്രഹവും കാണുക.';
  @override
  String get fromDate => 'മുതൽ';
  @override
  String get toDate => 'വരെ';
  @override
  String get healthScoreTrend => 'ആരോഗ്യ സ്കോർ പ്രവണത';
  @override
  String get comprehensiveSummary => 'സമഗ്ര സംഗ്രഹം';
  @override
  String get latestScore => 'ഏറ്റവും പുതിയ സ്കോർ';
  @override
  String get averageScore => 'ശരാശരി സ്കോർ';
  @override
  String get scoreChange => 'സ്കോർ മാറ്റം';
  @override
  String get reportsInRange => 'പരിധിയിലെ റിപ്പോർട്ടുകൾ';
  @override
  String get recentHealthReport => 'സമീപകാല ആരോഗ്യ റിപ്പോർട്ട്';
  @override
  String get noHealthStatusData => 'ആരോഗ്യ ചരിത്രം ഇതുവരെ ലഭ്യമല്ല.';
  @override
  String get noDataInSelectedRange =>
      'തിരഞ്ഞെടുത്ത തീയതി പരിധിയിൽ സ്കോറുകളില്ല.';
  @override
  String get bloodSugarLabel => 'രക്തത്തിലെ പഞ്ചസാര';
  @override
  String get cholesterolLabel => 'കൊളസ്‌ട്രോൾ';

  // Labs & tests
  @override
  String get noLabTestsAvailable => 'ഇപ്പോൾ ലാബ് ടെസ്റ്റുകൾ ലഭ്യമല്ല.';
  @override
  String get noTestsFoundForFilters =>
      'തിരഞ്ഞെടുത്ത ഫിൽട്ടറുകൾക്ക് ടെസ്റ്റുകൾ കണ്ടെത്തിയില്ല.';
  @override
  String get viewHealthPackages => 'ഹെൽത്ത് പാക്കേജുകൾ കാണുക';
  @override
  String get noRecordsFound => 'റെക്കോർഡുകൾ കണ്ടെത്തിയില്ല.';

  // Lab booking
  @override
  String get addNew => 'പുതിയത് ചേർക്കുക';
  @override
  String get addNewPatient => 'പുതിയ രോഗിയെ ചേർക്കുക';
  @override
  String get addAddress => 'വിലാസം ചേർക്കുക';

  // Loyalty
  @override
  String get rewardsWallet => 'റിവാർഡ്സ് വാലറ്റ്';
  @override
  String tierLabel(String tier) => 'ടിയർ: $tier';

  // Quick actions
  @override
  String get aiPackageDesign => 'AI പാക്കേജ് ഡിസൈൻ';
  @override
  String get browsePackages => 'പാക്കേജുകൾ ബ്രൗസ് ചെയ്യുക';
  @override
  String bookAmount(String amount) => 'ബുക്ക് ₹$amount';
  @override
  String unknownQuickAction(String actionId) =>
      'അജ്ഞാത ദ്രുത പ്രവർത്തനം: $actionId';

  // AI checkup
  @override
  String couldNotLoadResult(String error) =>
      'ഫലം ലോഡ് ചെയ്യാൻ കഴിഞ്ഞില്ല: $error';
  @override
  String analysisFailed(String error) => 'വിശകലനം പരാജയപ്പെട്ടു: $error';

  // Emergency
  @override
  String couldNotStartCallTo(String phoneNumber) =>
      '$phoneNumber എന്ന നമ്പറിലേക്ക് കോൾ ആരംഭിക്കാൻ കഴിഞ്ഞില്ല.';

  // Errors & dates
  @override
  String errorWithMessage(String error) => 'പിശക്: $error';
  @override
  String get today => 'ഇന്ന്';
  @override
  String get yesterday => 'ഇന്നലെ';
}

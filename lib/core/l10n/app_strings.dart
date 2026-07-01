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
  String get getStarted;
  String get biohelix;
  String get hospitalLocation;
  String get loginTitle;
  String get createAccountTitle;
  String get loginSubtitle;
  String get registerSubtitle;
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
  String get registerWithWhatsAppOtp;
  String get alreadyRegisteredLogin;
  String get newPatientRegister;
  String get registerDemoHint;
  String get loginDemoHint;
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
}

class _EnStrings extends LocalizedStrings {
  const _EnStrings();

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
  String get getStarted => 'Get Started';
  @override
  String get biohelix => 'Biohelix';
  @override
  String get hospitalLocation =>
      'Health And Research Center\nPonnani, Malappuram';
  @override
  String get loginTitle => 'Login';
  @override
  String get createAccountTitle => 'Create account';
  @override
  String get loginSubtitle =>
      'Enter your mobile number and we will send a WhatsApp OTP.';
  @override
  String get registerSubtitle =>
      'Complete your patient profile. We will verify your number with a WhatsApp OTP.';
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
  String get assistantTitle => 'Health AI Assistant';
  @override
  String get assistantReady => 'Ready';
  @override
  String get assistantListening => 'Listening to you';
  @override
  String get assistantSpeaking => 'AI is talking';
  @override
  String get assistantLiveModeActive => 'Live mode active';
  @override
  String get assistantInputHint => 'Ask anything about your health report';
  @override
  String get assistantDisclaimer =>
      'AI can make mistakes. Always consult a doctor before taking action.';
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
}

class _MlStrings extends LocalizedStrings {
  const _MlStrings();

  @override
  String get goodMorning => 'സുപ്രഭാതം,';
  @override
  String get goodAfternoon => 'ഉച്ചയ്ക്ക് ശേഷം,';
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
  String get getStarted => 'തുടങ്ങുക';
  @override
  String get biohelix => 'ബയോഹെലിക്സ്';
  @override
  String get hospitalLocation =>
      'ഹെൽത്ത് ആൻഡ് റിസർച്ച് സെന്റർ\nപൊന്നാനി, മലപ്പുറം';
  @override
  String get loginTitle => 'ലോഗിൻ';
  @override
  String get createAccountTitle => 'അക്കൗണ്ട് സൃഷ്ടിക്കുക';
  @override
  String get loginSubtitle =>
      'തുടരാൻ നിങ്ങളുടെ മൊബൈൽ നമ്പർ നൽകുക, ഞങ്ങൾ വാട്സ്ആപ്പ് OTP അയയ്ക്കും.';
  @override
  String get registerSubtitle =>
      'നിങ്ങളുടെ രോഗി പ്രൊഫൈൽ പൂർത്തിയാക്കുക. നമ്പർ വാട്സ്ആപ്പ് OTP വഴി സ്ഥിരീകരിക്കും.';
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
  String get registerWithWhatsAppOtp => 'രജിസ്റ്റർ ചെയ്ത് വാട്സ്ആപ്പ് OTP അയയ്ക്കുക';
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
  String get assistantTitle => 'ഹെൽത്ത് AI അസിസ്റ്റന്റ്';
  @override
  String get assistantReady => 'തയ്യാർ';
  @override
  String get assistantListening => 'നിങ്ങളെ കേൾക്കുന്നു';
  @override
  String get assistantSpeaking => 'AI സംസാരിക്കുന്നു';
  @override
  String get assistantLiveModeActive => 'ലൈവ് മോഡ് പ്രവർത്തിക്കുന്നു';
  @override
  String get assistantInputHint =>
      'നിങ്ങളുടെ ആരോഗ്യ റിപ്പോർട്ടിനെ കുറിച്ച് ചോദിക്കൂ';
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
}

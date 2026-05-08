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

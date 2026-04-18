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
      'Take Atorvastatin at night for best effectiveness — and avoid grapefruit';
  @override
  String get defaultAnnouncement => 'Eid Mubarak! Happy Onam...';
  @override
  String get noUpcomingAppointments => 'No upcoming appointments right now.';
}

class _MlStrings extends LocalizedStrings {
  const _MlStrings();

  @override
  String get goodMorning => 'സുപ്രഭാതം,';
  @override
  String get goodAfternoon => 'ഉച്ചയ്ക്ക് ശേഷം,';
  @override
  String get goodEvening => 'സായംസന്ധ്യ,';
  @override
  String get goodNight => 'ശുഭരാത്രി,';
  @override
  String get featuredDoctors => 'പ്രമുഖ ഡോക്ടർമാർ';
  @override
  String get bookAppointments => 'സ്‌പെഷലിസ്റ്റുകളുമായി അപ്പോയ്ന്റ്മെന്റ്';
  @override
  String get popularLabTests => 'ജനപ്രിയ ലാബ് ടെസ്റ്റുകൾ';
  @override
  String get accurateResults => 'സർട്ടിഫൈഡ് ലാബുകളിൽ നിന്ന് കൃത്യമായ ഫലങ്ങൾ';
  @override
  String get popularPackages => 'ജനപ്രിയ പാക്കേജുകൾ';
  @override
  String get curatedBundles => 'മികച്ച മൂല്യമുള്ള ക്യൂറേറ്റഡ് ബണ്ടിലുകൾ';
  @override
  String get specialOffers => 'പ്രത്യേക ഓഫറുകൾ';
  @override
  String get viewOffer => 'ഓഫർ കാണുക';
  @override
  String get upcomingAppointments => 'വരാനിരിക്കുന്ന അപ്പോയ്ന്റ്മെന്റുകൾ';
  @override
  String get seeAll => 'എല്ലാം കാണുക';
  @override
  String get exploreDoctors => 'ഡോക്ടർമാരെ തിരയുക';
  @override
  String get summerHealthTips => 'വേനൽക്കാല ആരോഗ്യ നുറുങ്ങുകൾ';
  @override
  String get quickActions => 'ദ്രുത പ്രവർത്തനങ്ങൾ';
  @override
  String get viewAll => 'എല്ലാം കാണുക';
  @override
  String get defaultHealthTipMessage =>
      'മികച്ച ഫലത്തിനായി അടോർവാസ്റ്റാറ്റിൻ രാത്രി കഴിക്കുക — ഗ്രേപ്പ്‌ഫ്രൂട്ട് ഒഴിവാക്കുക';
  @override
  String get defaultAnnouncement => 'ഈദ് മുബാറക്! ഹാപ്പി ഓണം...';
  @override
  String get noUpcomingAppointments =>
      'ഇപ്പോൾ വരാനിരിക്കുന്ന അപ്പോയ്ന്റ്മെന്റുകളൊന്നുമില്ല.';
}

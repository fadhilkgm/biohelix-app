import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/models/home_feed_models.dart';
import '../../core/models/patient_models.dart';

class HomeHeaderContent {
  const HomeHeaderContent({
    required this.greeting,
    required this.displayName,
    required this.healthTipTitle,
    required this.healthTipMessage,
    required this.announcement,
  });

  final String greeting;
  final String displayName;
  final String healthTipTitle;
  final String healthTipMessage;
  final String announcement;
}

class HomeHeaderContentMapper {
  const HomeHeaderContentMapper._();

  static HomeHeaderContent build({
    required String patientName,
    required List<HomeBannerItem> banners,
    List<TickerMessageItem> tickerMessages = const [],
    AppLanguage language = AppLanguage.en,
  }) {
    final strings = AppStrings.of(language);
    final displayName = _resolveDisplayName(patientName);
    final healthTipMessage = _resolveHealthTipMessage(banners, strings);
    final announcement = _resolveAnnouncementFromTicker(
      tickerMessages,
      banners,
      strings,
    );

    return HomeHeaderContent(
      greeting: _resolveGreeting(strings),
      displayName: displayName,
      healthTipTitle: strings.summerHealthTips,
      healthTipMessage: healthTipMessage,
      announcement: announcement,
    );
  }

  static String _resolveGreeting(LocalizedStrings strings) {
    final hour = DateTime.now().hour;
    if (hour < 12) return strings.goodMorning;
    if (hour < 17) return strings.goodAfternoon;
    if (hour < 21) return strings.goodEvening;
    return strings.goodNight;
  }

  static String _resolveDisplayName(String patientName) {
    final normalized = patientName.trim();
    if (normalized.isEmpty) return 'Patient';
    return normalized.split(RegExp(r'\s+')).first;
  }

  static String _resolveHealthTipMessage(
    List<HomeBannerItem> banners,
    LocalizedStrings strings,
  ) {
    for (final banner in banners) {
      final subtitle = (banner.subtitle ?? '').trim();
      if (subtitle.isNotEmpty) return subtitle;
      final title = banner.title.trim();
      if (title.isNotEmpty) return title;
    }
    return strings.defaultHealthTipMessage;
  }

  static String _resolveAnnouncementFromTicker(
    List<TickerMessageItem> tickerMessages,
    List<HomeBannerItem> banners,
    LocalizedStrings strings,
  ) {
    if (tickerMessages.isNotEmpty) {
      final items = tickerMessages
          .map((m) => m.message.trim())
          .where((m) => m.isNotEmpty)
          .take(5)
          .toList();
      if (items.isNotEmpty) return items.join(' ✦ ');
    }
    return _resolveAnnouncement(banners, strings);
  }

  static String _resolveAnnouncement(
    List<HomeBannerItem> banners,
    LocalizedStrings strings,
  ) {
    final items = <String>[];
    for (final banner in banners) {
      final title = banner.title.trim();
      if (title.isEmpty) continue;
      items.add(title);
      if (items.length == 3) break;
    }
    if (items.isEmpty) return strings.defaultAnnouncement;
    return items.join(' ✦ ');
  }
}

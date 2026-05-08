import 'package:biohelix_app/core/l10n/app_strings.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/patient_portal/core/models/home_feed_models.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/premium_home/utils/home_header_content_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeHeaderContentMapper', () {
    test('should resolve first name correctly', () {
      final content = HomeHeaderContentMapper.build(
        patientName: 'John Doe',
        banners: [],
      );

      expect(content.displayName, 'John');
    });

    test('should handle empty name', () {
      final content = HomeHeaderContentMapper.build(
        patientName: '  ',
        banners: [],
      );

      expect(content.displayName, 'Patient');
    });

    test('should resolve health tip from banner subtitle', () {
      final banners = [
        const HomeBannerItem(
          id: 1,
          title: 'Title',
          subtitle: 'Health Tip Message',
          imageUrl: '',
        ),
      ];

      final content = HomeHeaderContentMapper.build(
        patientName: 'John',
        banners: banners,
      );

      expect(content.healthTipMessage, 'Health Tip Message');
    });

    test('should fallback to title if subtitle is empty', () {
      final banners = [
        const HomeBannerItem(
          id: 1,
          title: 'Banner Title',
          subtitle: '',
          imageUrl: '',
        ),
      ];

      final content = HomeHeaderContentMapper.build(
        patientName: 'John',
        banners: banners,
      );

      expect(content.healthTipMessage, 'Banner Title');
    });

    test('should resolve announcement from ticker messages', () {
      final tickerMessages = [
        const TickerMessageItem(id: 1, message: 'Message 1'),
        const TickerMessageItem(id: 2, message: 'Message 2'),
      ];

      final content = HomeHeaderContentMapper.build(
        patientName: 'John',
        banners: [],
        tickerMessages: tickerMessages,
      );

      expect(content.announcement, ['Message 1', 'Message 2'].join(' ✦ '));
    });

    test('should handle Malayalam language support', () {
      final content = HomeHeaderContentMapper.build(
        patientName: 'John',
        banners: [],
        language: AppLanguage.ml,
      );
      final strings = AppStrings.of(AppLanguage.ml);

      expect(
        [
          strings.goodMorning,
          strings.goodAfternoon,
          strings.goodEvening,
          strings.goodNight,
        ],
        contains(content.greeting),
      );
    });
  });
}

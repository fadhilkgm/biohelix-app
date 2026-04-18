class TickerMessageItem {
  const TickerMessageItem({
    required this.id,
    required this.message,
    this.ctaTarget,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final int id;
  final String message;
  final String? ctaTarget;
  final int sortOrder;
  final bool isActive;

  factory TickerMessageItem.fromJson(Map<String, dynamic> json) {
    return TickerMessageItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      ctaTarget: json['ctaTarget'] as String? ?? json['cta_target'] as String?,
      sortOrder:
          (json['sortOrder'] as num?)?.toInt() ??
          (json['sort_order'] as num?)?.toInt() ??
          0,
      isActive:
          json['isActive'] as bool? ??
          json['is_active'] == 1 ||
          json['is_active'] == true,
    );
  }
}

class HomeOfferItem {
  const HomeOfferItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.gradientFrom,
    required this.gradientTo,
    required this.buttonBorderColor,
    this.ctaLabel,
    this.ctaTarget,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final int id;
  final String title;
  final String? subtitle;
  final String gradientFrom;
  final String gradientTo;
  final String buttonBorderColor;
  final String? ctaLabel;
  final String? ctaTarget;
  final int sortOrder;
  final bool isActive;

  factory HomeOfferItem.fromJson(Map<String, dynamic> json) {
    return HomeOfferItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      gradientFrom:
          json['gradientFrom'] as String? ??
          json['gradient_from'] as String? ??
          '#0C2C6D',
      gradientTo:
          json['gradientTo'] as String? ??
          json['gradient_to'] as String? ??
          '#1A6EAA',
      buttonBorderColor:
          json['buttonBorderColor'] as String? ??
          json['button_border_color'] as String? ??
          '#05B3E6',
      ctaLabel: json['ctaLabel'] as String? ?? json['cta_label'] as String?,
      ctaTarget: json['ctaTarget'] as String? ?? json['cta_target'] as String?,
      sortOrder:
          (json['sortOrder'] as num?)?.toInt() ??
          (json['sort_order'] as num?)?.toInt() ??
          0,
      isActive:
          json['isActive'] as bool? ??
          json['is_active'] == 1 ||
          json['is_active'] == true,
    );
  }
}

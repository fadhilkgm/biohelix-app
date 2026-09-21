import '../../core/models/patient_models.dart';

enum CollectionType { home, lab }

class BookableLabTest {
  const BookableLabTest({
    required this.id,
    required this.name,
    required this.bodyPoints,
    required this.price,
    required this.basePrice,
    this.categoryName,
    this.preparation,
    this.resultEta,
    this.imageUrl,
    this.originalItem,
  });

  /// Single source of truth for turning a catalogue test into a bookable one.
  /// Only fields the API actually returns are carried across: clinical copy is
  /// never invented here, because this screen is shown to patients.
  factory BookableLabTest.fromLabTest(LabTestItem item) {
    final preparation = (item.instructions ?? '').trim();
    final resultEta = (item.resultEta ?? '').trim();
    final category = item.categoryName.trim();

    return BookableLabTest(
      id: item.id,
      name: item.testName,
      bodyPoints: item.bodyPoints,
      categoryName: category.isEmpty ? null : category,
      preparation: preparation.isEmpty ? null : preparation,
      resultEta: resultEta.isEmpty ? null : resultEta,
      price: (item.discountedPrice ?? item.basePrice).toDouble(),
      basePrice: item.basePrice.toDouble(),
      imageUrl: item.imageUrl,
      originalItem: item,
    );
  }

  final int id;
  final String name;
  final List<BodyPointItem> bodyPoints;
  final double price;
  final double basePrice;
  final String? categoryName;
  final String? preparation;
  final String? resultEta;
  final String? imageUrl;
  final LabTestItem? originalItem;

  bool get isDiscounted => basePrice > price;
}

class CartItem {
  const CartItem({required this.test, required this.quantity});

  final BookableLabTest test;
  final int quantity;

  CartItem copyWith({BookableLabTest? test, int? quantity}) {
    return CartItem(
      test: test ?? this.test,
      quantity: quantity ?? this.quantity,
    );
  }
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.phone,
  });

  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? phone;

  /// "42 yrs • Female", or whichever half is actually known. Returns null when
  /// the record has neither, so callers can hide the line instead of
  /// displaying a placeholder.
  String? get demographicsLabel {
    final parts = <String>[
      if (age != null) '$age yrs',
      if ((gender ?? '').trim().isNotEmpty) gender!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }
}

class AddressProfile {
  const AddressProfile({
    required this.id,
    required this.label,
    required this.fullAddress,
  });

  final String id;
  final String label;
  final String fullAddress;
}

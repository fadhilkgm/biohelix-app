enum CollectionType { home, lab }

enum PaymentMethod { online, atLab }

class BookableLabTest {
  const BookableLabTest({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.preparation,
    required this.parameters,
    required this.price,
    required this.popular,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String category;
  final String description;
  final String preparation;
  final List<String> parameters;
  final double price;
  final bool popular;
  final String? imageUrl;
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
    required this.age,
    required this.gender,
  });

  final String id;
  final String name;
  final int age;
  final String gender;
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

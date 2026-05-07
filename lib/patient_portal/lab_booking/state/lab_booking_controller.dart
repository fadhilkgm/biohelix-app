import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../models/lab_booking_models.dart';

class LabBookingController extends ChangeNotifier {
  LabBookingController({
    required String patientName,
    required List<LabTestItem> tests,
  }) {
    _patients = [
      PatientProfile(id: 'self', name: patientName, age: 29, gender: 'Male'),
    ];
    _tests = tests.map(_mapTest).toList();
  }

  late List<BookableLabTest> _tests;
  final List<CartItem> _cart = [];
  late List<PatientProfile> _patients;
  final List<AddressProfile> _addresses = const [
    AddressProfile(
      id: 'home',
      label: 'Home',
      fullAddress: '24 Green View, Health City',
    ),
    AddressProfile(
      id: 'office',
      label: 'Office',
      fullAddress: '8 Apollo Park, Business Bay',
    ),
  ].toList();
  String _query = '';
  String _category = 'All';
  bool _popularOnly = false;
  double _maxPrice = 2500;
  String _coupon = '';
  CollectionType _collectionType = CollectionType.home;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _slot = '07:00 - 08:00 AM';
  String _selectedPatientId = 'self';
  String _selectedAddressId = 'home';
  PaymentMethod _paymentMethod = PaymentMethod.online;

  List<String> get categories => ['All', 'Blood', 'Scan', 'Urine'];
  List<String> get slots => const [
    '07:00 - 08:00 AM',
    '08:00 - 09:00 AM',
    '09:00 - 10:00 AM',
    '10:00 - 11:00 AM',
  ];
  List<CartItem> get cart => List.unmodifiable(_cart);
  List<PatientProfile> get patients => List.unmodifiable(_patients);
  List<AddressProfile> get addresses => List.unmodifiable(_addresses);
  String get query => _query;
  String get category => _category;
  bool get popularOnly => _popularOnly;
  double get maxPrice => _maxPrice;
  CollectionType get collectionType => _collectionType;
  DateTime get date => _date;
  String? get slot => _slot;
  String get selectedPatientId => _selectedPatientId;
  String get selectedAddressId => _selectedAddressId;
  PaymentMethod get paymentMethod => _paymentMethod;
  String get coupon => _coupon;
  int get cartCount => _cart.fold(0, (sum, e) => sum + e.quantity);

  PatientProfile get selectedPatient =>
      _patients.firstWhere((e) => e.id == _selectedPatientId);
  AddressProfile? get selectedAddress => _collectionType == CollectionType.home
      ? _addresses.firstWhere((e) => e.id == _selectedAddressId)
      : null;
  List<BookableLabTest> get popularTests =>
      filteredTests.where((e) => e.popular).take(6).toList();

  List<BookableLabTest> get filteredTests {
    return _tests.where((BookableLabTest t) {
      final inQuery = t.name.toLowerCase().contains(_query.toLowerCase());
      final inCategory = _category == 'All' || t.category == _category;
      final inPrice = t.price <= _maxPrice;
      final inPopular = !_popularOnly || t.popular;
      return inQuery && inCategory && inPrice && inPopular;
    }).toList();
  }

  double get subtotal {
    double sum = 0.0;
    for (final e in _cart) {
      sum += (e.test.price * e.quantity);
    }
    return sum;
  }

  double get discount {
    if (_coupon.trim().toUpperCase() == 'HEALTH10') {
      return subtotal * 0.10;
    }
    return 0.0;
  }

  double get collectionFee {
    if (_collectionType == CollectionType.home) {
      return 99.0;
    }
    return 0.0;
  }

  double get total {
    return subtotal - discount + collectionFee;
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setCategory(String value) {
    _category = value;
    notifyListeners();
  }

  void setPopularOnly(bool value) {
    _popularOnly = value;
    notifyListeners();
  }

  void setMaxPrice(double value) {
    _maxPrice = value;
    notifyListeners();
  }

  void applyCoupon(String value) {
    _coupon = value;
    notifyListeners();
  }

  void setCollectionType(CollectionType value) {
    _collectionType = value;
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = value;
    notifyListeners();
  }

  void setSlot(String value) {
    if (_slot == value) {
      _slot = null;
    } else {
      _slot = value;
    }
    notifyListeners();
  }

  void setPatient(String id) {
    _selectedPatientId = id;
    notifyListeners();
  }

  void setAddress(String id) {
    _selectedAddressId = id;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod value) {
    _paymentMethod = value;
    notifyListeners();
  }

  void setPrimaryPatient({
    required String name,
    required int age,
    required String gender,
  }) {
    _patients = [
      PatientProfile(id: 'self', name: name, age: age, gender: gender),
    ];
    _selectedPatientId = 'self';
    notifyListeners();
  }

  void addPatient({
    required String name,
    required int age,
    required String gender,
  }) {
    _patients = [
      ..._patients,
      PatientProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        age: age,
        gender: gender,
      ),
    ];
    _selectedPatientId = _patients.last.id;
    notifyListeners();
  }

  void addAddress({required String label, required String fullAddress}) {
    _addresses.add(
      AddressProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        label: label,
        fullAddress: fullAddress,
      ),
    );
    _selectedAddressId = _addresses.last.id;
    notifyListeners();
  }

  bool addToCart(BookableLabTest test) {
    final index = _cart.indexWhere((e) => e.test.id == test.id);
    if (index == -1) {
      _cart.add(CartItem(test: test, quantity: 1));
      notifyListeners();
      return true;
    } else {
      // Keep one entry per test to simplify the booking cart UX.
      _cart[index] = _cart[index].copyWith(quantity: 1);
      notifyListeners();
      return false;
    }
  }

  void updateQty(int testId, int qty) {
    final index = _cart.indexWhere((e) => e.test.id == testId);
    if (index == -1) return;
    if (qty <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = _cart[index].copyWith(quantity: qty);
    }
    notifyListeners();
  }

  Future<String> placeOrder(PatientPortalProvider portal) async {
    if (_cart.isEmpty) throw StateError('Cart is empty');
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final bookingRoot = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(5);
    final selected = selectedPatient;
    final address = selectedAddress?.fullAddress;
    final paymentStatus = _paymentMethod == PaymentMethod.online
        ? 'paid'
        : 'pay_at_collection';

    for (final item in _cart) {
      for (var i = 0; i < item.quantity; i++) {
        await portal.createLabOrder(
          labTestId: item.test.id,
          doctorId: null, // Keep null for direct-to-consumer lab orders
          date: dateStr,
          slot: _slot ?? '',
          collectionType: _collectionType.name,
          address: address,
          amount: item.test.price + collectionFee,
          paymentStatus: paymentStatus,
          patientNameSnapshot: selected.name,
          patientAgeSnapshot: selected.age,
          patientGenderSnapshot: selected.gender,
          bookingRef: 'LB-$bookingRoot-${item.test.id}-$i',
          notes: 'Slot ${_slot ?? "Standard"}, ${selected.name}',
        );
      }
    }
    _cart.clear();
    notifyListeners();
    return 'LB-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  }

  BookableLabTest _mapTest(LabTestItem test) {
    final lower = test.testName.toLowerCase();
    final blood =
        lower.contains('cbc') ||
        lower.contains('thyroid') ||
        lower.contains('fbs');
    final urine = lower.contains('urine');
    final category = urine
        ? 'Urine'
        : (blood
              ? 'Blood'
              : (test.categoryName.toLowerCase().contains('scan')
                    ? 'Scan'
                    : 'Blood'));
    return BookableLabTest(
      id: test.id,
      name: test.testName,
      category: category,
      imageUrl: test.imageUrl,
      description:
          'Advanced ${test.testName} profile with clinically reviewed parameters and fast turnaround.',
      preparation: (test.instructions ?? '').trim().isNotEmpty
          ? test.instructions!.trim()
          : (lower.contains('fbs')
                ? 'Fasting required for 8-10 hours before sample collection.'
                : 'Stay hydrated and follow physician instructions before collection.'),
      parameters: lower.contains('cbc')
          ? ['Hemoglobin', 'WBC', 'RBC', 'Platelets']
          : ['Primary marker', 'Secondary marker', 'Reference range'],
      price: (test.discountedPrice ?? test.basePrice).toDouble(),
      basePrice: test.basePrice.toDouble(),
      popular: test.id % 2 == 0,
      originalItem: test,
    );
  }
}

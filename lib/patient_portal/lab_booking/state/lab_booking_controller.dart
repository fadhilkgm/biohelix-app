import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/patient_models.dart';
import '../../core/data/patient_repository.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../bookings/models/booking_payment_method.dart';
import '../models/lab_booking_models.dart';

class LabBookingController extends ChangeNotifier {
  LabBookingController({
    required String patientName,
    required List<LabTestItem> tests,
    required List<BodyPointItem> bodyPoints,
    String? patientPhone,
    int? patientAge,
    String? patientGender,
    String? patientAddress,
    Iterable<int> initialTestIds = const [],
    this.sourceAssessmentToken,
  }) {
    _patients = [
      PatientProfile(
        id: 'self',
        name: patientName,
        age: patientAge,
        gender: patientGender,
        phone: patientPhone,
      ),
    ];
    final registeredAddress = (patientAddress ?? '').trim();
    if (registeredAddress.isNotEmpty) {
      _addresses.add(
        AddressProfile(
          id: 'registered',
          label: 'Registered address',
          fullAddress: registeredAddress,
        ),
      );
      _selectedAddressId = 'registered';
    }
    _bodyPoints = bodyPoints;
    _tests = tests.map(BookableLabTest.fromLabTest).toList();
    final activeIds = tests.where((test) => test.status).map((test) => test.id);
    final selectedIds = initialTestIds.toSet().intersection(activeIds.toSet());
    _cart.addAll(
      _tests
          .where((test) => selectedIds.contains(test.id))
          .map((test) => CartItem(test: test, quantity: 1)),
    );
    _preselectedCount = _cart.length;
  }

  late List<BookableLabTest> _tests;
  final String? sourceAssessmentToken;
  late final String _idempotencyKey =
      'lab-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  late List<BodyPointItem> _bodyPoints;
  final List<CartItem> _cart = [];
  int _preselectedCount = 0;
  late List<PatientProfile> _patients;

  /// Seeded from the patient's registered address only. Placeholder addresses
  /// must never appear here: a home collection would be sent to the wrong door.
  final List<AddressProfile> _addresses = [];
  String _query = '';
  BodyPointItem? _selectedBodyPoint;
  double _maxPrice = 2500;
  String _coupon = '';
  CollectionType _collectionType = CollectionType.home;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _slot = '07:00 - 08:00 AM';
  String _selectedPatientId = 'self';
  String _selectedAddressId = '';
  BookingPaymentMethod _paymentMethod = BookingPaymentMethod.online;
  LabOrderQuote? _quote;
  bool _quoteLoading = false;
  String? _quoteError;

  List<BodyPointItem> get bodyPoints => List.unmodifiable(_bodyPoints);
  BodyPointItem? get selectedBodyPoint => _selectedBodyPoint;
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
  double get maxPrice => _maxPrice;
  CollectionType get collectionType => _collectionType;
  DateTime get date => _date;
  String? get slot => _slot;
  String get selectedPatientId => _selectedPatientId;
  String get selectedAddressId => _selectedAddressId;
  BookingPaymentMethod get paymentMethod => _paymentMethod;
  String get coupon => _coupon;
  int get cartCount => _cart.fold(0, (sum, e) => sum + e.quantity);
  int get preselectedCount => _preselectedCount;
  bool get quoteLoading => _quoteLoading;
  String? get quoteError => _quoteError;

  PatientProfile get selectedPatient => _patients.firstWhere(
    (e) => e.id == _selectedPatientId,
    orElse: () => _patients.first,
  );
  AddressProfile? get selectedAddress {
    if (_collectionType != CollectionType.home || _addresses.isEmpty) {
      return null;
    }
    for (final address in _addresses) {
      if (address.id == _selectedAddressId) return address;
    }
    return _addresses.first;
  }

  /// Tests shown on the lab home screen. The catalogue carries no popularity
  /// signal, so this is simply the start of the filtered list.
  List<BookableLabTest> get featuredTests {
    if (_selectedBodyPoint != null) {
      return filteredTests;
    }
    return filteredTests.take(10).toList();
  }

  List<BookableLabTest> get filteredTests {
    final query = _query.toLowerCase();
    return _tests.where((BookableLabTest t) {
      final inQuery = t.name.toLowerCase().contains(query);
      final inBodyPoint =
          _selectedBodyPoint == null ||
          t.bodyPoints.any((bp) => bp.id == _selectedBodyPoint!.id);
      final inPrice = t.price <= _maxPrice;
      return inQuery && inBodyPoint && inPrice;
    }).toList();
  }

  double get subtotal {
    if (_quote != null) return _quote!.subtotal;
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
    if (_quote != null) return _quote!.collectionFee;
    if (_collectionType == CollectionType.home) {
      return 99.0;
    }
    return 0.0;
  }

  double get total {
    if (_quote != null) return _quote!.amount;
    return subtotal - discount + collectionFee;
  }

  Future<void> refreshQuote(PatientPortalProvider portal) async {
    if (_cart.isEmpty) return;
    _quoteLoading = true;
    _quoteError = null;
    notifyListeners();
    try {
      _quote = await portal.quoteLabOrder(
        labTestIds: _cart.map((item) => item.test.id).toList(),
        collectionType: _collectionType.name,
      );
    } catch (error) {
      _quote = null;
      _quoteError = error.toString();
    } finally {
      _quoteLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setSelectedBodyPoint(BodyPointItem? value) {
    _selectedBodyPoint = value;
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
    _quote = null;
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

  void setPaymentMethod(BookingPaymentMethod value) {
    _paymentMethod = value;
    notifyListeners();
  }

  void setPrimaryPatient({
    required String name,
    int? age,
    String? gender,
    String? phone,
  }) {
    _patients = [
      PatientProfile(
        id: 'self',
        name: name,
        age: age,
        gender: gender,
        phone: phone,
      ),
    ];
    _selectedPatientId = 'self';
    notifyListeners();
  }

  void addPatient({
    required String name,
    int? age,
    String? gender,
    String? phone,
  }) {
    _patients = [
      ..._patients,
      PatientProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        age: age,
        gender: gender,
        phone: phone,
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
      _quote = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  void updateQty(int testId, int qty) {
    final index = _cart.indexWhere((e) => e.test.id == testId);
    if (index == -1) return;
    if (qty <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = _cart[index].copyWith(quantity: qty);
    }
    _quote = null;
    notifyListeners();
  }

  Future<String> placeOrder(PatientPortalProvider portal) async {
    if (_cart.isEmpty) throw StateError('Cart is empty');
    await refreshQuote(portal);
    if (_quote == null) {
      throw StateError('Unable to verify the current price. Please try again.');
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final bookingRoot = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(5);
    final selected = selectedPatient;
    final address = selectedAddress?.fullAddress;
    final paymentStatus = _paymentMethod.paymentStatus;

    final labTestIds = <int>[
      for (final item in _cart)
        for (var i = 0; i < item.quantity; i++) item.test.id,
    ];

    final confirmation = await portal.createLabOrder(
      labTestIds: labTestIds,
      doctorId: null, // Keep null for direct-to-consumer lab orders
      date: dateStr,
      slot: _slot ?? '',
      collectionType: _collectionType.name,
      address: address,
      amount: total,
      paymentStatus: paymentStatus,
      patientNameSnapshot: selected.name,
      patientAgeSnapshot: selected.age,
      patientGenderSnapshot: selected.gender,
      patientPhoneSnapshot: selected.phone,
      bookingRef: 'LB-$bookingRoot',
      notes: 'Slot ${_slot ?? "Standard"}, ${selected.name}',
      sourceAssessmentToken: sourceAssessmentToken,
      idempotencyKey: _idempotencyKey,
    );

    _cart.clear();
    notifyListeners();
    return confirmation.reference;
  }
}

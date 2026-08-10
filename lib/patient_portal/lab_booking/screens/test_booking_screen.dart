import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../models/lab_booking_models.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/slot_selector_widget.dart';
import 'payment_screen.dart';

class TestBookingScreen extends StatefulWidget {
  const TestBookingScreen({super.key});

  @override
  State<TestBookingScreen> createState() => _TestBookingScreenState();
}

class _TestBookingScreenState extends State<TestBookingScreen> {
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = context.read<LabBookingController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      c.refreshQuote(context.read<PatientPortalProvider>());
    });
    final address = c.selectedAddress;
    if (address != null) {
      _addressController.text = address.fullAddress;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _continueToPayment() {
    final c = context.read<LabBookingController>();
    if (c.slot == null || c.cart.isEmpty) return;

    if (c.collectionType == CollectionType.home) {
      final address = _addressController.text.trim();
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a collection address.')),
        );
        return;
      }
      final existing = c.addresses.firstWhere(
        (item) => item.fullAddress == address,
        orElse: () => const AddressProfile(id: '', label: '', fullAddress: ''),
      );
      if (existing.id.isEmpty) {
        c.addAddress(label: 'Home', fullAddress: address);
      } else {
        c.setAddress(existing.id);
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<LabBookingController>.value(
          value: c,
          child: const PaymentScreen(),
        ),
      ),
    );
  }

  void _showAddPatientDialog() {
    final c = context.read<LabBookingController>();
    final strings = AppStrings.of(context.read<LanguageProvider>().language);
    final loggedInPhone = context.read<SessionProvider>().patient?.phone ?? '';
    final name = TextEditingController();
    final age = TextEditingController();
    final phone = TextEditingController(text: loggedInPhone);
    var useLoggedInPhone = loggedInPhone.trim().isNotEmpty;

    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Add New Member',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: age,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  enabled: !useLoggedInPhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (loggedInPhone.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: useLoggedInPhone,
                    onChanged: (value) {
                      setDialogState(() {
                        useLoggedInPhone = value ?? false;
                        if (useLoggedInPhone) {
                          phone.text = loggedInPhone;
                        }
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Use logged-in phone number',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = int.tryParse(age.text) ?? 0;
                  final memberPhone = phone.text.trim();
                  if (name.text.trim().isNotEmpty &&
                      parsed > 0 &&
                      memberPhone.isNotEmpty) {
                    c.addPatient(
                      name: name.text.trim(),
                      age: parsed,
                      gender: '',
                      phone: memberPhone,
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(strings.save),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      name.dispose();
      age.dispose();
      phone.dispose();
    });
  }

  String _patientSubtitle(PatientProfile patient) {
    final parts = <String>['${patient.age} yrs'];
    if (patient.phone?.trim().isNotEmpty ?? false) {
      parts.add(patient.phone!.trim());
    } else if (patient.gender.trim().isNotEmpty) {
      parts.add(patient.gender.trim());
    }
    return parts.join(' • ');
  }

  // Kept temporarily for compatibility with the legacy in-booking selector.
  // ignore: unused_element
  void _usePrimaryPatient() {
    final session = context.read<SessionProvider>();
    final patient = session.patient;
    if (patient == null) return;
    context.read<LabBookingController>().setPrimaryPatient(
      name: patient.name,
      age: patient.age ?? 29,
      gender: patient.gender ?? 'Male',
      phone: patient.phone,
    );
  }

  // ignore: unused_element
  Future<void> _showSwitchUserSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer<SessionProvider>(
          builder: (sheetContext, session, _) {
            final profiles = session.familyProfiles;
            final activePatientId = session.patient?.id;
            final theme = Theme.of(sheetContext);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F8),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF06489B), Color(0xFF759BF1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Switch User',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select a family member to book this test for.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (profiles.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Text(
                                  'No saved family members yet.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              )
                            else
                              ...profiles.map((profile) {
                                final isActive =
                                    profile.patient.id == activePatientId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: isActive
                                          ? null
                                          : () {
                                              Navigator.of(sheetContext).pop();
                                              final c = context
                                                  .read<LabBookingController>();
                                              c.setPrimaryPatient(
                                                name: profile.patient.name,
                                                age: profile.patient.age ?? 29,
                                                gender:
                                                    profile.patient.gender ??
                                                    'Male',
                                                phone: profile.patient.phone,
                                              );
                                            },
                                      child: Ink(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          border: Border.all(
                                            color: isActive
                                                ? const Color(0xFF06489B)
                                                : const Color(0xFFE5E9F0),
                                            width: isActive ? 1.6 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFF06489B),
                                                    Color(0xFF759BF1),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(16),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                profile.patient.name.isEmpty
                                                    ? 'P'
                                                    : profile
                                                          .patient
                                                          .name
                                                          .characters
                                                          .first
                                                          .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    profile.patient.name,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    profile
                                                        .patient
                                                        .registrationNumber,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: const Color(
                                                            0xFF06489B,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    profile.patient.phone,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: const Color(
                                                            0xFF7E8BA0,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isActive)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF4F7FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: const Text(
                                                  'Active',
                                                  style: TextStyle(
                                                    color: Color(0xFF06489B),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              )
                                            else
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: Color(0xFF8DA0BA),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _showAddPatientDialog();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF06489B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                ),
                                label: const Text(
                                  'Add New Member',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Complete Booking',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test Summary
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Summary',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF192233),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...c.cart.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.test.name,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF192233),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.test.bodyPoints.isNotEmpty
                                      ? item.test.bodyPoints.first.name
                                      : 'Lab test',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12,
                                    color: const Color(
                                      0xFF192233,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\u20B9${item.test.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF06489B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Tests',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF192233).withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '${c.cart.length}',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF192233),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Collection Type
            Text(
              'Sample Collection Mode',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEBEDF2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _CollectionTab(
                    label: 'Home Visit',
                    icon: Icons.home_rounded,
                    selected: c.collectionType == CollectionType.home,
                    onTap: () {
                      c.setCollectionType(CollectionType.home);
                      c.refreshQuote(context.read<PatientPortalProvider>());
                    },
                  ),
                  _CollectionTab(
                    label: 'At Lab',
                    icon: Icons.biotech_rounded,
                    selected: c.collectionType == CollectionType.lab,
                    onTap: () {
                      c.setCollectionType(CollectionType.lab);
                      c.refreshQuote(context.read<PatientPortalProvider>());
                    },
                  ),
                ],
              ),
            ),

            if (c.collectionType == CollectionType.home) ...[
              const SizedBox(height: 24),
              Text(
                'Collection Address',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF192233),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter complete address for sample collection',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Patient
            Text(
              'Patient Details',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF06489B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.selectedPatient.name,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF192233),
                          ),
                        ),
                        Text(
                          _patientSubtitle(c.selectedPatient),
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            color: const Color(
                              0xFF192233,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Date Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Date',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF192233),
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(c.date),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF06489B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HorizontalDatePicker(
              selectedDate: c.date,
              onDateSelected: c.setDate,
            ),

            const SizedBox(height: 32),

            // Slot Selection
            Text(
              'Available Slots',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233),
              ),
            ),
            const SizedBox(height: 16),
            SlotSelectorWidget(
              slots: c.slots,
              selectedSlot: c.slot,
              onSelect: c.setSlot,
            ),

            const SizedBox(height: 32),

            // Price Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _PriceRow(
                    label: 'Subtotal',
                    value: '\u20B9${c.subtotal.toStringAsFixed(0)}',
                  ),
                  _PriceRow(
                    label: 'Discount',
                    value: '- \u20B9${c.discount.toStringAsFixed(0)}',
                    valueColor: const Color(0xFF1F9A6D),
                  ),
                  _PriceRow(
                    label: 'Collection Fee',
                    value: '\u20B9${c.collectionFee.toStringAsFixed(0)}',
                  ),
                  const Divider(height: 24),
                  _PriceRow(
                    label: 'Total',
                    value: '\u20B9${c.total.toStringAsFixed(0)}',
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (c.quoteLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          c.quoteError == null
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: c.quoteError == null
                              ? const Color(0xFF14845D)
                              : const Color(0xFFD17A00),
                        ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          c.quoteLoading
                              ? 'Checking the current server price...'
                              : c.quoteError == null
                              ? 'Current price verified by BHRC'
                              : 'Price will be rechecked before booking',
                          style: const TextStyle(
                            color: Color(0xFF61728A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (c.slot == null || c.cart.isEmpty)
                ? null
                : _continueToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06489B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Review Payment',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xFF06489B)
                    : const Color(0xFF192233).withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF06489B)
                      : const Color(0xFF192233).withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalDatePicker extends StatelessWidget {
  const _HorizontalDatePicker({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dates = List.generate(
      30,
      (index) => now.add(Duration(days: index + 1)),
    );

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateUtils.isSameDay(date, selectedDate);

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF06489B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF192233).withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF192233),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(
                0xFF192233,
              ).withValues(alpha: isBold ? 1 : 0.6),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color:
                  valueColor ??
                  (isBold
                      ? const Color(0xFF192233)
                      : const Color(0xFF192233).withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

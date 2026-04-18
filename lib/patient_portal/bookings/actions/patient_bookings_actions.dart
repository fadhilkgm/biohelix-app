part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

extension _BookingsTabActions on _BookingsTab {
  Future<void> _cancelBooking(
    BuildContext context,
    PatientPortalProvider portal,
    BookingItem booking,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await portal.cancelBooking(booking.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appointment cancelled.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _checkInBooking(
    BuildContext context,
    PatientPortalProvider portal,
    BookingItem booking,
  ) async {
    try {
      await portal.checkInBooking(booking.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checked in successfully.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _cancelLabOrder(
    BuildContext context,
    PatientPortalProvider portal,
    LabOrderItem order,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel lab booking'),
        content: Text('Cancel ${order.testName} scheduled for ${order.date}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await portal.cancelLabOrder(order.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lab booking cancelled.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showLabOrderDetails(
    BuildContext context,
    LabOrderItem order,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LabOrderDetailsPage(order: order),
      ),
    );
  }

  Future<void> _cancelLabPackageOrder(
    BuildContext context,
    PatientPortalProvider portal,
    LabPackageOrderItem order,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel package booking'),
        content: Text(
          'Cancel ${order.packageName} scheduled for ${order.date}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await portal.cancelLabPackageOrder(order.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Package booking cancelled.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showLabPackageOrderDetails(
    BuildContext context,
    LabPackageOrderItem order,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LabPackageOrderDetailsPage(order: order),
      ),
    );
  }
}

class _LabOrderDetailsPage extends StatelessWidget {
  const _LabOrderDetailsPage({required this.order});

  final LabOrderItem order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patientInfo = [
      order.patientName,
      if (order.patientAge != null) '${order.patientAge}y',
      order.patientGender,
    ].where((part) => (part ?? '').trim().isNotEmpty).join(' • ');

    final amountText = order.amount == null
        ? 'Not available'
        : 'Rs ${order.amount!.toStringAsFixed(0)}';
    final paymentText = (order.paymentStatus ?? 'pending')
        .replaceAll('_', ' ')
        .toUpperCase();
    final collectionText = (order.collectionType ?? 'home')
        .replaceAll('_', ' ')
        .toUpperCase();
    final bookingDateTime = (order.slot ?? '').trim().isEmpty
        ? order.date
        : '${order.date} • ${order.slot}';

    return Scaffold(
      appBar: AppBar(title: const Text('Booked Test Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.tertiaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.biotech_outlined)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          order.testName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _StatusBadge(label: order.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricChip(
                        icon: Icons.confirmation_number_outlined,
                        text: order.bookingRef ?? 'LB-${order.id}',
                      ),
                      _MetricChip(
                        icon: Icons.event_available_outlined,
                        text: bookingDateTime,
                      ),
                      _MetricChip(
                        icon: Icons.payments_outlined,
                        text: amountText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DetailSectionCard(
            title: 'Patient & Collection',
            children: [
              _DetailRow(
                label: 'Patient details',
                value: patientInfo.isEmpty ? 'Not available' : patientInfo,
              ),
              _DetailRow(label: 'Collection type', value: collectionText),
              _DetailRow(
                label: 'Collection address',
                value: (order.address ?? '').trim().isEmpty
                    ? 'Not required for lab visit'
                    : order.address!.trim(),
              ),
              _DetailRow(
                label: 'Payment status',
                value: paymentText,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSectionCard(
            title: 'Test Instructions',
            children: [
              _DetailRow(
                label: 'Preparation before test',
                value: (order.testInstructions ?? '').trim().isEmpty
                    ? 'No special preparation required.'
                    : order.testInstructions!.trim(),
              ),
              _DetailRow(
                label: 'Estimated result time',
                value: (order.resultEta ?? '').trim().isEmpty
                    ? 'Within 24 hours'
                    : order.resultEta!.trim(),
              ),
              _DetailRow(
                label: 'Additional booking notes',
                value: (order.notes ?? '').trim().isEmpty
                    ? 'No additional details provided.'
                    : order.notes!.trim(),
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabPackageOrderDetailsPage extends StatelessWidget {
  const _LabPackageOrderDetailsPage({required this.order});

  final LabPackageOrderItem order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patientInfo = [
      order.patientName,
      if (order.patientAge != null) '${order.patientAge}y',
      order.patientGender,
    ].where((part) => (part ?? '').trim().isNotEmpty).join(' • ');

    final amountText = order.amount == null
        ? 'Not available'
        : 'Rs ${order.amount!.toStringAsFixed(0)}';

    final collectionText = (order.collectionType ?? 'home')
        .replaceAll('_', ' ')
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Package Booking Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      order.packageName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusBadge(label: order.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DetailSectionCard(
            title: 'Booking Snapshot',
            children: [
              _DetailRow(
                label: 'Booking ID',
                value: order.bookingRef ?? 'LP-${order.id}',
              ),
              _DetailRow(
                label: 'Patient details',
                value: patientInfo.isEmpty ? 'Not available' : patientInfo,
              ),
              _DetailRow(
                label: 'Date and time',
                value: (order.slot ?? '').trim().isEmpty
                    ? order.date
                    : '${order.date} • ${order.slot}',
              ),
              _DetailRow(label: 'Collection type', value: collectionText),
              _DetailRow(
                label: 'Address',
                value: (order.address ?? '').trim().isEmpty
                    ? 'Not required for lab visit'
                    : order.address!.trim(),
              ),
              _DetailRow(label: 'Amount', value: amountText),
              _DetailRow(
                label: 'Estimated result time',
                value: (order.packageResultEta ?? '').trim().isEmpty
                    ? 'Within 24 hours'
                    : order.packageResultEta!.trim(),
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

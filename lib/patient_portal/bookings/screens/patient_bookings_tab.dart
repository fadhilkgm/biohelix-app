part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

enum _BookingsView { all, appointments, tests }

enum _BookingsTimeline { upcoming, history }

class _BookingsTab extends StatefulWidget {
  const _BookingsTab();

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  _BookingsView _selectedView = _BookingsView.all;
  _BookingsTimeline _selectedTimeline = _BookingsTimeline.upcoming;
  int? _expandedBookingId;

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final theme = Theme.of(context);

        // Data processing logic
        final upcomingBookings = _sortedBookings(
          portal.bookings.where((booking) => !_isPastBooking(booking)).toList(),
          ascending: true,
        );
        final historyBookings = _sortedBookings(
          portal.bookings.where(_isPastBooking).toList(),
          ascending: false,
        );
        final upcomingLabOrders = _sortedLabOrders(
          portal.labOrders
              .where((order) => !_isPastOrder(order.date, order.status))
              .toList(),
          ascending: true,
        );
        final historyLabOrders = _sortedLabOrders(
          portal.labOrders
              .where((order) => _isPastOrder(order.date, order.status))
              .toList(),
          ascending: false,
        );
        final upcomingPackageOrders = _sortedPackageOrders(
          portal.labPackageOrders
              .where((order) => !_isPastOrder(order.date, order.status))
              .toList(),
          ascending: true,
        );
        final historyPackageOrders = _sortedPackageOrders(
          portal.labPackageOrders
              .where((order) => _isPastOrder(order.date, order.status))
              .toList(),
          ascending: false,
        );

        final currentAppointments =
            _selectedTimeline == _BookingsTimeline.upcoming
                ? upcomingBookings
                : historyBookings;
        final currentLabOrders = _selectedTimeline == _BookingsTimeline.upcoming
            ? upcomingLabOrders
            : historyLabOrders;
        final currentPackageOrders =
            _selectedTimeline == _BookingsTimeline.upcoming
                ? upcomingPackageOrders
                : historyPackageOrders;

        final showAppointments = _selectedView == _BookingsView.all ||
            _selectedView == _BookingsView.appointments;
        final showTests = _selectedView == _BookingsView.all ||
            _selectedView == _BookingsView.tests;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Bookings',
                                    style: GoogleFonts.manrope(
                                      textStyle: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage consultations & diagnostics',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _TimelineSwitcher(
                              value: _selectedTimeline,
                              onChanged: (val) =>
                                  setState(() => _selectedTimeline = val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _BookingsFilterChip(
                                label: 'All Activities',
                                selected: _selectedView == _BookingsView.all,
                                icon: Icons.grid_view_rounded,
                                onTap: () => setState(
                                  () => _selectedView = _BookingsView.all,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _BookingsFilterChip(
                                label: 'Book New',
                                selected: false,
                                icon: Icons.add_rounded,
                                color: theme.colorScheme.primary,
                                onTap: portal.isCreatingBooking
                                    ? null
                                    : () =>
                                        widget._showBookingSheet(context, portal),
                              ),
                              const SizedBox(width: 8),
                              _BookingsFilterChip(
                                label: 'Consultations',
                                selected:
                                    _selectedView == _BookingsView.appointments,
                                icon: Icons.medical_services_outlined,
                                onTap: () => setState(
                                  () =>
                                      _selectedView = _BookingsView.appointments,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _BookingsFilterChip(
                                label: 'Lab Tests',
                                selected: _selectedView == _BookingsView.tests,
                                icon: Icons.biotech_outlined,
                                onTap: () => setState(
                                  () => _selectedView = _BookingsView.tests,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ..._buildTimelineContent(
                        context,
                        portal,
                        showAppointments ? currentAppointments : [],
                        showTests ? currentLabOrders : [],
                        showTests ? currentPackageOrders : [],
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTimelineContent(
    BuildContext context,
    PatientPortalProvider portal,
    List<BookingItem> appointments,
    List<LabOrderItem> labOrders,
    List<LabPackageOrderItem> packageOrders,
  ) {
    if (appointments.isEmpty && labOrders.isEmpty && packageOrders.isEmpty) {
      return [
        _EmptyBookingsState(
          title: _selectedTimeline == _BookingsTimeline.upcoming
              ? 'No upcoming plans'
              : 'End of history',
          message: _selectedTimeline == _BookingsTimeline.upcoming
              ? 'Your scheduled consultations and health tests will clear paths here.'
              : 'Records of your completed health activities will stay available here.',
          icon: _selectedTimeline == _BookingsTimeline.upcoming
              ? Icons.calendar_today_outlined
              : Icons.history_rounded,
        ),
      ];
    }

    final List<Widget> items = [];

    if (appointments.isNotEmpty) {
      items.add(
        _TimelineSectionHeader(
          title: 'Medical Consultations',
          count: appointments.length,
          color: AppColors.primary,
        ),
      );
      items.addAll(_buildAppointmentCards(context, portal, appointments));
      items.add(const SizedBox(height: 20));
    }

    if (labOrders.isNotEmpty) {
      items.add(
        _TimelineSectionHeader(
          title: 'Laboratory Tests',
          count: labOrders.length,
          color: const Color(0xFF0EA5E9),
        ),
      );
      items.addAll(_buildLabOrderCards(context, portal, labOrders));
      items.add(const SizedBox(height: 20));
    }

    if (packageOrders.isNotEmpty) {
      items.add(
        _TimelineSectionHeader(
          title: 'Health Packages',
          count: packageOrders.length,
          color: const Color(0xFF8B5CF6),
        ),
      );
      items.addAll(_buildPackageOrderCards(context, portal, packageOrders));
    }

    return items;
  }

  List<Widget> _buildAppointmentCards(
    BuildContext context,
    PatientPortalProvider portal,
    List<BookingItem> bookings,
  ) {
    final theme = Theme.of(context);
    return bookings.map((booking) {
      final canManage =
          _selectedTimeline == _BookingsTimeline.upcoming &&
          _canManageBooking(booking.status);
      final isExpanded = _expandedBookingId == booking.id;
      final accentColor = _appointmentColorFor(booking.doctorSpecialization);
      final iconData = _appointmentIconFor(booking.doctorSpecialization);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: canManage
                ? () {
                    setState(() {
                      _expandedBookingId = isExpanded ? null : booking.id;
                    });
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isExpanded
                      ? theme.colorScheme.primary.withValues(alpha: 0.18)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(iconData, color: accentColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.doctorName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              booking.doctorSpecialization ??
                                  'Doctor consultation',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusBadge(label: _formatStatus(booking.status)),
                          if (canManage) ...[
                            const SizedBox(height: 8),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetaLine(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDisplayDate(booking.bookingDate),
                  ),
                  const SizedBox(height: 6),
                  _MetaLine(
                    icon: Icons.schedule_rounded,
                    text: booking.timeslot.trim().isEmpty
                        ? 'Time to be confirmed'
                        : booking.timeslot,
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 8),
                    Text(
                      isExpanded
                          ? 'Manage this appointment'
                          : 'Tap this card to manage your appointment',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _CompactActionButton(
                                label: 'Reschedule',
                                icon: Icons.schedule_rounded,
                                onTap: portal.isCreatingBooking
                                    ? null
                                    : () => widget._showRescheduleBookingSheet(
                                          context,
                                          portal,
                                          booking,
                                        ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CompactActionButton(
                                label: 'Check in',
                                icon: Icons.how_to_reg_rounded,
                                onTap: portal.isCreatingBooking
                                    ? null
                                    : () => widget._checkInBooking(
                                          context,
                                          portal,
                                          booking,
                                        ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CompactActionButton(
                                label: 'Cancel',
                                icon: Icons.cancel_outlined,
                                isDestructive: true,
                                onTap: portal.isCreatingBooking
                                    ? null
                                    : () => widget._cancelBooking(
                                          context,
                                          portal,
                                          booking,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                    sizeCurve: Curves.easeOutCubic,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildLabOrderCards(
    BuildContext context,
    PatientPortalProvider portal,
    List<LabOrderItem> orders,
  ) {
    final theme = Theme.of(context);
    return orders
        .map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0EA5E9,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.biotech_outlined,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.testName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.categoryName ?? 'Lab test',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(label: _formatStatus(order.status)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetaLine(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDisplayDate(order.date),
                  ),
                  if ((order.slot ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _MetaLine(icon: Icons.schedule_rounded, text: order.slot!),
                  ],
                  const SizedBox(height: 6),
                  _MetaLine(
                    icon: Icons.person_outline_rounded,
                    text: order.doctorName,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget._showLabOrderDetails(context, order),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View details'),
                      ),
                      if (_selectedTimeline == _BookingsTimeline.upcoming &&
                          _canManageLabOrder(order.status))
                        OutlinedButton.icon(
                          onPressed: portal.isCreatingLabOrder
                              ? null
                              : () => widget._cancelLabOrder(
                                  context,
                                  portal,
                                  order,
                                ),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancel booking'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildPackageOrderCards(
    BuildContext context,
    PatientPortalProvider portal,
    List<LabPackageOrderItem> orders,
  ) {
    final theme = Theme.of(context);
    return orders
        .map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8B5CF6,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.packageName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.packageCategory ?? 'Health package',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(label: _formatStatus(order.status)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetaLine(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDisplayDate(order.date),
                  ),
                  if ((order.slot ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _MetaLine(icon: Icons.schedule_rounded, text: order.slot!),
                  ],
                  const SizedBox(height: 6),
                  _MetaLine(
                    icon: Icons.person_outline_rounded,
                    text: order.doctorName,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget._showLabPackageOrderDetails(context, order),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View details'),
                      ),
                      if (_selectedTimeline == _BookingsTimeline.upcoming &&
                          _canManageLabOrder(order.status))
                        OutlinedButton.icon(
                          onPressed: portal.isCreatingLabOrder
                              ? null
                              : () => widget._cancelLabPackageOrder(
                                  context,
                                  portal,
                                  order,
                                ),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancel booking'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  bool _canManageBooking(String status) {
    const allowed = {'pending', 'confirmed', 'rescheduled'};
    return allowed.contains(status.toLowerCase());
  }

  bool _canManageLabOrder(String status) {
    const allowed = {'pending', 'confirmed', 'scheduled'};
    return allowed.contains(status.toLowerCase());
  }

  bool _isPastBooking(BookingItem booking) {
    final normalized = booking.status.toLowerCase();
    if (_isClosedStatus(normalized)) {
      return true;
    }

    final parsedDate = _tryParseDate(booking.bookingDate);
    if (parsedDate == null) {
      return false;
    }

    return parsedDate.isBefore(_startOfToday());
  }

  bool _isPastOrder(String date, String status) {
    final normalized = status.toLowerCase();
    if (_isClosedStatus(normalized)) {
      return true;
    }

    final parsedDate = _tryParseDate(date);
    if (parsedDate == null) {
      return false;
    }

    return parsedDate.isBefore(_startOfToday());
  }

  bool _isClosedStatus(String status) {
    const closed = {
      'cancelled',
      'canceled',
      'completed',
      'checked_in',
      'checked-in',
      'done',
      'expired',
      'missed',
    };
    return closed.contains(status);
  }

  List<BookingItem> _sortedBookings(
    List<BookingItem> items, {
    required bool ascending,
  }) {
    final sorted = [...items];
    sorted.sort(
      (left, right) => _compareDates(
        _tryParseDate(left.bookingDate),
        _tryParseDate(right.bookingDate),
        ascending: ascending,
      ),
    );
    return sorted;
  }

  List<LabOrderItem> _sortedLabOrders(
    List<LabOrderItem> items, {
    required bool ascending,
  }) {
    final sorted = [...items];
    sorted.sort(
      (left, right) => _compareDates(
        _tryParseDate(left.date),
        _tryParseDate(right.date),
        ascending: ascending,
      ),
    );
    return sorted;
  }

  List<LabPackageOrderItem> _sortedPackageOrders(
    List<LabPackageOrderItem> items, {
    required bool ascending,
  }) {
    final sorted = [...items];
    sorted.sort(
      (left, right) => _compareDates(
        _tryParseDate(left.date),
        _tryParseDate(right.date),
        ascending: ascending,
      ),
    );
    return sorted;
  }

  int _compareDates(
    DateTime? left,
    DateTime? right, {
    required bool ascending,
  }) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return ascending ? left.compareTo(right) : right.compareTo(left);
  }

  DateTime? _tryParseDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final direct = DateTime.tryParse(normalized);
    if (direct != null) {
      return DateTime(direct.year, direct.month, direct.day);
    }

    const patterns = ['yyyy-MM-dd', 'dd-MM-yyyy', 'dd/MM/yyyy', 'dd MMM yyyy'];
    for (final pattern in patterns) {
      try {
        final parsed = DateFormat(pattern).parseStrict(normalized);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {}
    }

    return null;
  }

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDisplayDate(String rawDate) {
    final parsed = _tryParseDate(rawDate);
    if (parsed == null) {
      return rawDate;
    }
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  String _formatStatus(String status) {
    if (status.trim().isEmpty) {
      return 'Pending';
    }

    return status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  IconData _appointmentIconFor(String? specialization) {
    final normalized = (specialization ?? '').toLowerCase();
    if (normalized.contains('cardio')) {
      return Icons.favorite_rounded;
    }
    if (normalized.contains('radio')) {
      return Icons.center_focus_strong_rounded;
    }
    if (normalized.contains('endo')) {
      return Icons.science_rounded;
    }
    if (normalized.contains('neuro')) {
      return Icons.psychology_rounded;
    }
    return Icons.medical_services_rounded;
  }

  Color _appointmentColorFor(String? specialization) {
    final normalized = (specialization ?? '').toLowerCase();
    if (normalized.contains('cardio')) {
      return const Color(0xFFEF4444);
    }
    if (normalized.contains('radio')) {
      return const Color(0xFF8B5CF6);
    }
    if (normalized.contains('endo')) {
      return const Color(0xFF0EA5E9);
    }
    if (normalized.contains('neuro')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF1D4ED8);
  }
}

class _TimelineSwitcher extends StatelessWidget {
  const _TimelineSwitcher({required this.value, required this.onChanged});

  final _BookingsTimeline value;
  final ValueChanged<_BookingsTimeline> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpcoming = value == _BookingsTimeline.upcoming;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitcherItem(
            label: 'Upcoming',
            selected: isUpcoming,
            onTap: () => onChanged(_BookingsTimeline.upcoming),
          ),
          _SwitcherItem(
            label: 'History',
            selected: !isUpcoming,
            onTap: () => onChanged(_BookingsTimeline.history),
          ),
        ],
      ),
    );
  }
}

class _SwitcherItem extends StatelessWidget {
  const _SwitcherItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BookingsFilterChip extends StatelessWidget {
  const _BookingsFilterChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? activeColor
                : color != null
                    ? color!.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected || color != null
                  ? activeColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected || color != null
                    ? activeColor
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSectionHeader extends StatelessWidget {
  const _TimelineSectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.25)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBookingsState extends StatelessWidget {
  const _EmptyBookingsState({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}


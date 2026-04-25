part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

enum _BookingsView { all, appointments, tests, packages }

enum _BookingsTimeline { upcoming, history }

class _BookingsTab extends StatefulWidget {
  const _BookingsTab();

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
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
        final showPackages = _selectedView == _BookingsView.all ||
            _selectedView == _BookingsView.packages;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
            ),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Back Button ─────────────────────────────────────
                        IconButton(
                          onPressed: () => PatientAppShell.of(context).goHome(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surface,
                            foregroundColor: theme.colorScheme.onSurface,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ── Header ──────────────────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Bookings',
                                    style: GoogleFonts.manrope(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Consultations & diagnostics',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.35,
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
                        const SizedBox(height: 20),
                        // ── Filter chips ─────────────────────────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: [
                              _BookingsFilterChip(
                                label: 'All',
                                selected: _selectedView == _BookingsView.all,
                                icon: Icons.grid_view_rounded,
                                onTap: () => setState(
                                  () => _selectedView = _BookingsView.all,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _BookingsFilterChip(
                                label: 'Consultations',
                                selected:
                                    _selectedView == _BookingsView.appointments,
                                icon: Icons.medical_services_rounded,
                                onTap: () => setState(
                                  () =>
                                      _selectedView = _BookingsView.appointments,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _BookingsFilterChip(
                                label: 'Lab Tests',
                                selected: _selectedView == _BookingsView.tests,
                                icon: Icons.biotech_rounded,
                                onTap: () => setState(
                                  () => _selectedView = _BookingsView.tests,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _BookingsFilterChip(
                                label: 'Packages',
                                selected: _selectedView == _BookingsView.packages,
                                icon: Icons.inventory_2_rounded,
                                onTap: () => setState(
                                  () => _selectedView = _BookingsView.packages,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                          showPackages ? currentPackageOrders : [],
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
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canManage
                ? () {
                    setState(() {
                      _expandedBookingId = isExpanded ? null : booking.id;
                    });
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.low(
                  dark: theme.brightness == Brightness.dark,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconData, color: accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.doctorName,
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                booking.doctorSpecialization ??
                                    'Doctor consultation',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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
                              const SizedBox(height: 6),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetaLine(
                          icon: Icons.calendar_today_rounded,
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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.touch_app_rounded
                                    : Icons.touch_app_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isExpanded
                                    ? 'Managing this appointment'
                                    : 'Tap to manage',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(height: 16),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 14),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _CompactActionButton(
                                  label: 'Reschedule',
                                  icon: Icons.schedule_rounded,
                                  onTap: portal.isCreatingBooking
                                      ? null
                                      : () =>
                                          widget._showRescheduleBookingSheet(
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
                                  icon: Icons.cancel_rounded,
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
                        ),
                      ],
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
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
    const accentColor = Color(0xFF0EA5E9);

    return orders
        .map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.low(
                  dark: theme.brightness == Brightness.dark,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.biotech_rounded,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.testName,
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                order.categoryName ?? 'Lab test',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(label: _formatStatus(order.status)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetaLine(
                          icon: Icons.calendar_today_rounded,
                          text: _formatDisplayDate(order.date),
                        ),
                        if ((order.slot ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _MetaLine(
                            icon: Icons.schedule_rounded,
                            text: order.slot!,
                          ),
                        ],
                        const SizedBox(height: 6),
                        _MetaLine(
                          icon: Icons.person_rounded,
                          text: order.doctorName,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        if (_selectedTimeline == _BookingsTimeline.upcoming &&
                            _canManageLabOrder(order.status)) ...[
                          Expanded(
                            child: _CompactActionButton(
                              label: 'Reschedule',
                              icon: Icons.schedule_rounded,
                              onTap: () => widget._showRescheduleLabOrderSheet(
                                context,
                                portal,
                                order,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactActionButton(
                              label: 'Cancel',
                              icon: Icons.cancel_rounded,
                              isDestructive: true,
                              onTap: portal.isCreatingLabOrder
                                  ? null
                                  : () => widget._cancelLabOrder(
                                        context,
                                        portal,
                                        order,
                                      ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
    const accentColor = Color(0xFF8B5CF6);

    return orders
        .map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.low(
                  dark: theme.brightness == Brightness.dark,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.packageName,
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                order.packageCategory ?? 'Health package',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(label: _formatStatus(order.status)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetaLine(
                          icon: Icons.calendar_today_rounded,
                          text: _formatDisplayDate(order.date),
                        ),
                        if ((order.slot ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _MetaLine(
                            icon: Icons.schedule_rounded,
                            text: order.slot!,
                          ),
                        ],
                        const SizedBox(height: 6),
                        _MetaLine(
                          icon: Icons.person_rounded,
                          text: order.doctorName,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        if (_selectedTimeline == _BookingsTimeline.upcoming &&
                            _canManageLabOrder(order.status)) ...[
                          Expanded(
                            child: _CompactActionButton(
                              label: 'Reschedule',
                              icon: Icons.schedule_rounded,
                              onTap: () => widget._showRescheduleLabPackageOrderSheet(
                                context,
                                portal,
                                order,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactActionButton(
                              label: 'Cancel',
                              icon: Icons.cancel_rounded,
                              isDestructive: true,
                              onTap: portal.isCreatingLabOrder
                                  ? null
                                  : () => widget._cancelLabPackageOrder(
                                        context,
                                        portal,
                                        order,
                                      ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDisplayDate(String rawDate) {
    final parsed = _tryParseDate(rawDate);
    if (parsed == null) {
      return rawDate;
    }
    return DateFormat('dd MMM, yyyy').format(parsed);
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitcherItem(
            label: 'Upcoming',
            icon: Icons.upcoming_rounded,
            selected: isUpcoming,
            activeColor: const Color(0xFF5A88F1),
            onTap: () => onChanged(_BookingsTimeline.upcoming),
          ),
          _SwitcherItem(
            label: 'History',
            icon: Icons.history_rounded,
            selected: !isUpcoming,
            activeColor: const Color.fromARGB(255, 218, 162, 22),
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
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const activeColor = Color(0xFF5A88F1);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? activeColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
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
    final color = isDestructive ? AppColors.error : AppColors.primary;
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
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
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.7,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.low(
          dark: theme.brightness == Brightness.dark,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}


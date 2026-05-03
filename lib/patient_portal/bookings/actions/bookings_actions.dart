part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

extension _BookingsTabActions on _BookingsTab {
  Future<void> _cancelBooking(
    BuildContext context,
    PatientPortalProvider portal,
    BookingItem booking,
  ) async {
    final confirm = await _showStyledConfirmDialog(
      context: context,
      title: 'Cancel Appointment',
      message: 'Are you sure you want to cancel your appointment with ${booking.doctorName}?',
      confirmLabel: 'Yes, Cancel',
      isDestructive: true,
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



  Future<void> _cancelLabOrder(
    BuildContext context,
    PatientPortalProvider portal,
    LabOrderItem order,
  ) async {
    final confirm = await _showStyledConfirmDialog(
      context: context,
      title: 'Cancel Lab Test',
      message: 'Cancel ${order.testName} scheduled for ${order.date}?',
      confirmLabel: 'Yes, Cancel',
      isDestructive: true,
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


  Future<void> _cancelLabPackageOrder(
    BuildContext context,
    PatientPortalProvider portal,
    LabPackageOrderItem order,
  ) async {
    final confirm = await _showStyledConfirmDialog(
      context: context,
      title: 'Cancel Package',
      message: 'Cancel ${order.packageName} scheduled for ${order.date}?',
      confirmLabel: 'Yes, Cancel',
      isDestructive: true,
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

  Future<bool?> _showStyledConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Back',
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.high(
              dark: theme.brightness == Brightness.dark,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isDestructive ? Colors.red : const Color(0xFF5A88F1))
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive ? Icons.warning_rounded : Icons.info_rounded,
                  color: isDestructive ? Colors.red : const Color(0xFF5A88F1),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(height: 1),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: Text(
                            cancelLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(true),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(28),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: Text(
                            confirmLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDestructive
                                  ? Colors.red
                                  : const Color(0xFF5A88F1),
                            ),
                          ),
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
  }
}

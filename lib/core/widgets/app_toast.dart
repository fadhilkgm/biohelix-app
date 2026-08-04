import 'package:flutter/material.dart';

enum AppToastType { success, info, warning, error }

class AppToast {
  const AppToast._();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final visual = _visualFor(type);
    messenger.hideCurrentSnackBar();

    return messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        elevation: 8,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: visual.color.withValues(alpha: 0.24)),
        ),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: messenger.hideCurrentSnackBar,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF65758B),
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _ToastVisual _visualFor(AppToastType type) {
    return switch (type) {
      AppToastType.success => const _ToastVisual(
        color: Color(0xFF14845D),
        icon: Icons.check_circle_rounded,
      ),
      AppToastType.info => const _ToastVisual(
        color: Color(0xFF06489B),
        icon: Icons.info_rounded,
      ),
      AppToastType.warning => const _ToastVisual(
        color: Color(0xFFD17A00),
        icon: Icons.schedule_rounded,
      ),
      AppToastType.error => const _ToastVisual(
        color: Color(0xFFD14343),
        icon: Icons.error_rounded,
      ),
    };
  }
}

class _ToastVisual {
  const _ToastVisual({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

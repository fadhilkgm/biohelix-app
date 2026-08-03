import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/fitness_provider.dart';

class FitnessActivityCard extends StatelessWidget {
  const FitnessActivityCard({super.key});

  static const _blue = Color(0xFF06489B);

  Future<void> _handleMenuAction(
    BuildContext context,
    FitnessProvider fitness,
    _FitnessMenuAction action,
  ) async {
    switch (action) {
      case _FitnessMenuAction.refresh:
        await fitness.refreshAndSync();
      case _FitnessMenuAction.disconnect:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Disconnect ${fitness.platformName}?'),
            content: const Text(
              'This removes the link between activity data on this phone and '
              'the patient profile. Health data on the phone will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await fitness.disconnect();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fitness.platformName} disconnected.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FitnessProvider>(
      builder: (context, fitness, _) {
        if (!fitness.isSupportedPlatform) return const SizedBox.shrink();

        final action = switch (fitness.state) {
          FitnessConnectionState.disconnected => _ConnectContent(
            isBusy: fitness.isSyncing,
            onConnect: fitness.connect,
            rewardLabel: fitness.summary.rewardProgram.stepRewardLabel,
          ),
          FitnessConnectionState.updateRequired => _MessageContent(
            icon: Icons.system_update_rounded,
            title: 'Update ${fitness.platformName}',
            message:
                'Update ${fitness.platformName} to track activity on this phone.',
            actionLabel: 'Open ${fitness.platformName}',
            actionIcon: Icons.open_in_new_rounded,
            onAction: fitness.openHealthConnect,
          ),
          FitnessConnectionState.unavailable => const _MessageContent(
            icon: Icons.smartphone_rounded,
            title: 'Fitness tracking unavailable',
            message: 'Activity tracking is unavailable on this device.',
          ),
          FitnessConnectionState.blockedForDifferentPatient =>
            const _MessageContent(
              icon: Icons.shield_outlined,
              title: 'Linked to another patient',
              message:
                  'This phone’s activity belongs to the patient who connected it. '
                  'Switch back to that profile to sync steps and rewards.',
            ),
          FitnessConnectionState.error => _MessageContent(
            icon: Icons.error_outline_rounded,
            title: 'Activity sync needs attention',
            message:
                fitness.errorMessage ??
                'Fitness data could not be refreshed right now.',
            actionLabel: 'Try again',
            actionIcon: Icons.refresh_rounded,
            onAction: fitness.refreshAndSync,
          ),
          FitnessConnectionState.connected => _ConnectedContent(
            fitness: fitness,
          ),
          FitnessConnectionState.loading => const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 10),
              Text(
                'Loading activity…',
                style: TextStyle(
                  color: Color(0xFF52708F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF4F9FF), Color(0xFFEEF9F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC9DFEA)),
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFDCEFFF),
                      child: Icon(
                        Icons.directions_walk_rounded,
                        color: _blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Activity Rewards',
                            style: TextStyle(
                              color: Color(0xFF173B63),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Powered by ${fitness.platformName}',
                            style: const TextStyle(
                              color: Color(0xFF52708F),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (fitness.hasDeviceOwner)
                      PopupMenuButton<_FitnessMenuAction>(
                        key: const Key('fitness-more-menu'),
                        enabled: !fitness.isSyncing,
                        tooltip: 'More activity options',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 220,
                          maxWidth: 260,
                        ),
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 6),
                        elevation: 8,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F1FC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFC6DDED)),
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: _blue,
                            size: 21,
                          ),
                        ),
                        onSelected: (action) =>
                            _handleMenuAction(context, fitness, action),
                        itemBuilder: (context) => [
                          if (fitness.state ==
                                  FitnessConnectionState.connected ||
                              fitness.state == FitnessConnectionState.error)
                            const PopupMenuItem(
                              value: _FitnessMenuAction.refresh,
                              height: 52,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: _ActivityMenuTile(
                                icon: Icons.refresh_rounded,
                                label: 'Refresh activity',
                              ),
                            ),
                          if (fitness.state ==
                                  FitnessConnectionState.connected ||
                              fitness.state == FitnessConnectionState.error)
                            const PopupMenuDivider(height: 8),
                          const PopupMenuItem(
                            value: _FitnessMenuAction.disconnect,
                            height: 52,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: _ActivityMenuTile(
                              icon: Icons.link_off_rounded,
                              label: 'Disconnect activity',
                              isDestructive: true,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                action,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectContent extends StatelessWidget {
  const _ConnectContent({
    required this.isBusy,
    required this.onConnect,
    required this.rewardLabel,
  });

  final bool isBusy;
  final Future<void> Function() onConnect;
  final String rewardLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Turn your daily movement into rewards. $rewardLabel',
          style: const TextStyle(
            color: Color(0xFF385A78),
            fontSize: 13,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Only daily totals are securely synced to your BHRC profile.',
          style: TextStyle(color: Color(0xFF627D95), fontSize: 11, height: 1.3),
        ),
        const SizedBox(height: 10),
        _CompactActionButton(
          onPressed: isBusy ? null : onConnect,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.link_rounded, size: 18),
          label: Text(isBusy ? 'Connecting…' : 'Connect activity'),
        ),
      ],
    );
  }
}

class _ConnectedContent extends StatelessWidget {
  const _ConnectedContent({required this.fitness});

  final FitnessProvider fitness;

  @override
  Widget build(BuildContext context) {
    final today = fitness.today;
    final score = today?.activityScore ?? 0;
    final steps = today?.steps ?? 0;
    final calories = today?.activeCalories ?? 0;
    final distanceKm = (today?.distanceMeters ?? 0) / 1000;
    final goal = fitness.summary.rewardProgram.stepGoal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 7,
                    backgroundColor: const Color(0xFFD4E5E8),
                    color: const Color(0xFF147D73),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: SizedBox.square(
                      dimension: 46,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/walk.gif',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          semanticLabel: 'Animated walking activity',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${NumberFormat.decimalPattern().format(steps)} / '
                    '${NumberFormat.decimalPattern().format(goal)} steps',
                    style: const TextStyle(
                      color: Color(0xFF173B63),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: goal == 0 ? 0 : (steps / goal).clamp(0, 1),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF06489B),
                    backgroundColor: const Color(0xFFD4E5F1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${calories.toStringAsFixed(0)} active kcal  •  '
                    '${distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF52708F),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusPill(
              icon: Icons.stars_rounded,
              label: '${today?.rewardPointsAwarded ?? 0} MyClub points today',
            ),
            if (fitness.summary.unlockedOfferTitle != null)
              _StatusPill(
                icon: Icons.local_offer_outlined,
                label: fitness.summary.unlockedOfferTitle!,
              ),
          ],
        ),
        if (!fitness.isIOS &&
            fitness.platformStatus?.nativePhoneStepTracking == false) ...[
          const SizedBox(height: 8),
          const Text(
            'This Android version may need a compatible phone fitness app to '
            'write steps into Health Connect.',
            style: TextStyle(
              color: Color(0xFF7A6438),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        if (fitness.isSyncing) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 8),
        Text(
          fitness.summary.rewardProgram.disclaimer,
          style: const TextStyle(
            color: Color(0xFF71869A),
            fontSize: 10,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

enum _FitnessMenuAction { refresh, disconnect }

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFDCEFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF06489B)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF173B63),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF52708F),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 8),
                _CompactActionButton(
                  onPressed: onAction,
                  icon: Icon(
                    actionIcon ?? Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF2E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF147D73)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF12695F),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMenuTile extends StatelessWidget {
  const _ActivityMenuTile({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foreground = isDestructive
        ? const Color(0xFFC73A48)
        : const Color(0xFF06489B);
    final background = isDestructive
        ? const Color(0xFFFFEFF1)
        : const Color(0xFFF0F6FC);
    final iconBackground = isDestructive
        ? const Color(0xFFFFDDE2)
        : const Color(0xFFDCEBFA);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w800,
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
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: label,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        visualDensity: VisualDensity.compact,
        backgroundColor: const Color(0xFF06489B),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

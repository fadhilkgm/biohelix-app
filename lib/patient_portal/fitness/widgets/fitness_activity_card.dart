import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/fitness_provider.dart';

class FitnessActivityCard extends StatelessWidget {
  const FitnessActivityCard({super.key});

  static const _blue = Color(0xFF06489B);

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
            message: 'Update ${fitness.platformName} to track activity on this phone.',
            actionLabel: 'Open ${fitness.platformName}',
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
            onAction: fitness.refreshAndSync,
          ),
          FitnessConnectionState.connected => _ConnectedContent(
            fitness: fitness,
          ),
          FitnessConnectionState.loading => const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(child: CircularProgressIndicator()),
          ),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0F8FF), Color(0xFFE8F7F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFB9D9E8)),
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFD9EEFF),
                      child: Icon(Icons.directions_walk_rounded, color: _blue),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Activity Rewards',
                            style: TextStyle(
                              color: Color(0xFF173B63),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Powered by ${fitness.platformName}',
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
                const SizedBox(height: 16),
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
          'Use this phone’s steps, active calories and distance to build a '
          'daily wellness score. $rewardLabel',
          style: const TextStyle(color: Color(0xFF385A78), height: 1.4),
        ),
        const SizedBox(height: 8),
        const Text(
          'Only daily totals are sent to your BHRC profile. A watch or band is '
          'not required for compatible phones.',
          style: TextStyle(color: Color(0xFF627D95), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: isBusy ? null : onConnect,
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.link_rounded),
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
              width: 78,
              height: 78,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 9,
                    backgroundColor: const Color(0xFFD4E5E8),
                    color: const Color(0xFF147D73),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      '$score',
                      style: const TextStyle(
                        color: Color(0xFF147D73),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: goal == 0 ? 0 : (steps / goal).clamp(0, 1),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF06489B),
                    backgroundColor: const Color(0xFFD4E5F1),
                  ),
                  const SizedBox(height: 8),
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
        const SizedBox(height: 14),
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
          const SizedBox(height: 12),
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
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: fitness.isSyncing ? null : fitness.refreshAndSync,
              icon: fitness.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            TextButton(
              onPressed: fitness.openHealthConnect,
              child: const Text('Manage access'),
            ),
          ],
        ),
        Text(
          fitness.summary.rewardProgram.disclaimer,
          style: const TextStyle(color: Color(0xFF71869A), fontSize: 11),
        ),
      ],
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF52708F)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF52708F), height: 1.35),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

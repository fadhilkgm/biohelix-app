import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../core/models/patient_models.dart';

class PatientLoyaltyPanel extends StatelessWidget {
  const PatientLoyaltyPanel({
    super.key,
    required this.idCard,
    required this.myClub,
  });

  final IdCardInfo idCard;
  final MyClubSummary myClub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final nextTierLabel = myClub.nextTierName ?? 'Top tier reached';

    return Column(
      children: [
        _MemberCard(idCard: idCard),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BHRC Rewards',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${myClub.points} pts',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.tierLabel(myClub.tier),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LevelBadge(
                      label: myClub.levelName,
                      color: _parseColor(myClub.levelColor),
                    ),
                    if (myClub.leaderboardRank > 0)
                      _LevelBadge(
                        label: 'Leaderboard #${myClub.leaderboardRank}',
                        color: const Color(0xFF7C3AED),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated value: ₹${myClub.currencyValue.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  nextTierLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${myClub.pointsToNextTier} lifetime pts to next level',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: myClub.progressPercent / 100,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                ...myClub.benefits
                    .take(3)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                Text(
                  'Recent points history',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...myClub.transactions
                    .take(4)
                    .map((item) => _TransactionRow(transaction: item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PatientLoyaltyDetailsPage extends StatelessWidget {
  const PatientLoyaltyDetailsPage({
    super.key,
    required this.idCard,
    required this.myClub,
  });

  final IdCardInfo idCard;
  final MyClubSummary myClub;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return Scaffold(
      appBar: AppBar(title: Text(strings.rewardsWallet)),
      body: PatientLoyaltyDetailsContent(idCard: idCard, myClub: myClub),
    );
  }
}

class PatientLoyaltyDetailsContent extends StatelessWidget {
  const PatientLoyaltyDetailsContent({
    super.key,
    required this.idCard,
    required this.myClub,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.showRedemptionSetup = false,
  });

  final IdCardInfo idCard;
  final MyClubSummary myClub;
  final EdgeInsetsGeometry padding;
  final bool showRedemptionSetup;

  List<MyClubTransaction> get _creditTransactions => myClub.transactions
      .where((item) => item.points > 0)
      .toList(growable: false);

  List<MyClubTransaction> get _redemptionTransactions => myClub.transactions
      .where(
        (item) => item.points < 0 || item.type.toLowerCase().contains('redeem'),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: padding,
      children: [
        PatientLoyaltyPanel(idCard: idCard, myClub: myClub),
        const SizedBox(height: 16),
        _ReferralSection(referrals: myClub.referrals),
        const SizedBox(height: 16),
        _LeaderboardSection(myClub: myClub),
        const SizedBox(height: 16),
        if (showRedemptionSetup) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Redemption setup',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WalletStatRow(
                    label: 'Current balance',
                    value: '${myClub.points} pts',
                    icon: Icons.stars_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  _WalletStatRow(
                    label: 'Estimated redemption value',
                    value: '₹${myClub.currencyValue.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF0F766E),
                  ),
                  const SizedBox(height: 10),
                  _WalletStatRow(
                    label: 'Redeem rule',
                    value: myClub.redemptionEnabled
                        ? '${myClub.redemptionRatePoints} pts = ₹${myClub.redemptionRateCurrency}'
                        : 'Redemption not enabled yet',
                    icon: Icons.tune_rounded,
                    color: const Color(0xFFB45309),
                  ),
                  if (myClub.pointsExpiryMonths > 0) ...[
                    const SizedBox(height: 10),
                    _WalletStatRow(
                      label: 'Points expiry',
                      value:
                          '${myClub.pointsExpiryMonths} month validity window',
                      icon: Icons.schedule_outlined,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _HistorySection(
          title: 'Points credit history',
          emptyLabel:
              'No points credits yet. Booking and test activity will appear here.',
          transactions: _creditTransactions,
        ),
        const SizedBox(height: 16),
        _HistorySection(
          title: 'Redemption history',
          emptyLabel:
              'No redemptions yet. Once points are redeemed, entries will appear here.',
          transactions: _redemptionTransactions,
        ),
      ],
    );
  }
}

class _ReferralSection extends StatelessWidget {
  const _ReferralSection({required this.referrals});

  final ReferralSummary referrals;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: referrals.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Referral code copied')));
  }

  Future<void> _share() {
    final terms = referrals.rewardTerms;
    return SharePlus.instance
        .share(
          ShareParams(
            subject: 'Join BHRC',
            text:
                'Join BHRC with my referral code ${referrals.code}. '
                'You can earn ${terms.newPatientPoints} MyClub points after '
                'your first completed paid service. ${referrals.shareUrl}',
          ),
        )
        .then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invitedBy = referrals.invitedBy;

    return Card(
      key: const ValueKey('referral_relationships_card'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Invite friends',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              referrals.rewardTerms.qualification,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR REFERRAL CODE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    referrals.code,
                    key: const ValueKey('referral_code_value'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('copy_referral_code'),
                          onPressed: () => _copyCode(context),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy code'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('share_referral_code'),
                          onPressed: _share,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share invite'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ReferralMetric(
                    label: 'Invited',
                    value: referrals.stats.invited.toString(),
                  ),
                ),
                Expanded(
                  child: _ReferralMetric(
                    label: 'Rewarded',
                    value: referrals.stats.rewarded.toString(),
                  ),
                ),
                Expanded(
                  child: _ReferralMetric(
                    label: 'Points earned',
                    value: referrals.stats.pointsEarned.toString(),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              'Who invited you',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (invitedBy == null)
              Text(
                'You joined without a referral.',
                key: const ValueKey('invited_by_empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              _ReferralPersonTile(
                key: const ValueKey('invited_by_person'),
                relationship: invitedBy,
                leadingIcon: Icons.person_pin_circle_rounded,
              ),
            const SizedBox(height: 18),
            Text(
              'People you invited',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (referrals.invitedUsers.isEmpty)
              Text(
                'No invitations have been accepted yet.',
                key: const ValueKey('invited_users_empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...referrals.invitedUsers.map(
                (relationship) => _ReferralPersonTile(
                  relationship: relationship,
                  leadingIcon: Icons.person_rounded,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferralMetric extends StatelessWidget {
  const _ReferralMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _ReferralPersonTile extends StatelessWidget {
  const _ReferralPersonTile({
    super.key,
    required this.relationship,
    required this.leadingIcon,
  });

  final ReferralRelationship relationship;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final status = relationship.status.replaceAll('_', ' ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(leadingIcon)),
      title: Text(
        relationship.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(relationship.patientNumber),
      trailing: Chip(label: Text(status)),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.myClub});

  final MyClubSummary myClub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = [...myClub.leaderboard];
    final current = myClub.currentLeaderboardEntry;
    if (current != null && !entries.any((entry) => entry.isCurrentPatient)) {
      entries.add(current);
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Text(
                  'MyClub leaderboard',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ranked by lifetime earned points. Redeeming points does not reduce your level.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (entries.isEmpty)
              const Text('No leaderboard activity yet.')
            else
              ...entries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: entry.isCurrentPatient
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: entry.isCurrentPatient
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '#${entry.rank}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              entry.level,
                              style: TextStyle(
                                color: _parseColor(entry.levelColor),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${entry.lifetimePoints} pts',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            if (myClub.leaderboardPrivacyNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                myClub.leaderboardPrivacyNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _parseColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? const Color(0xFF64748B) : Color(0xFF000000 | parsed);
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.idCard});

  final IdCardInfo idCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barcodeValue = idCard.barcodeValue.isEmpty
        ? idCard.registrationNumber
        : idCard.barcodeValue;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BHRC Member Card',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              idCard.counterHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF9A5A08), Color(0xFFE9A11A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Member ID',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          idCard.membershipTier,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    idCard.patientName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    idCard.registrationNumber,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if ((idCard.memberSince ?? '').isNotEmpty)
                    Text(
                      'Member since ${DateFormat('MMM yyyy').format(DateTime.tryParse(idCard.memberSince!) ?? DateTime.now())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BarcodeWidget(
                          data: barcodeValue,
                          barcode: Barcode.code128(),
                          drawText: false,
                          height: 56,
                          color: Colors.black,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          barcodeValue,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final MyClubTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat(
      'dd MMM, hh:mm a',
    ).format(DateTime.tryParse(transaction.date) ?? DateTime.now());
    final pointsLabel = transaction.points >= 0
        ? '+${transaction.points}'
        : '${transaction.points}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            pointsLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: transaction.points >= 0
                  ? AppColors.success
                  : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.emptyLabel,
    required this.transactions,
  });

  final String title;
  final String emptyLabel;
  final List<MyClubTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (transactions.isEmpty)
              Text(
                emptyLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...transactions.map((item) => _TransactionRow(transaction: item)),
          ],
        ),
      ),
    );
  }
}

class _WalletStatRow extends StatelessWidget {
  const _WalletStatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

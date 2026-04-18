import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
                  'BioHelix Rewards',
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
                Text('Tier: ${myClub.tier}', style: theme.textTheme.bodyMedium),
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
                  '${myClub.pointsToNextTier} pts to next tier',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards Wallet')),
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
  });

  final IdCardInfo idCard;
  final MyClubSummary myClub;
  final EdgeInsetsGeometry padding;

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
                    value: '${myClub.pointsExpiryMonths} month validity window',
                    icon: Icons.schedule_outlined,
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
              'BioHelix Member Card',
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

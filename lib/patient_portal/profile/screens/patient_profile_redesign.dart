part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _RedesignedProfileSection extends StatelessWidget {
  const _RedesignedProfileSection({
    required this.patient,
    required this.idCard,
    required this.myClub,
    required this.familyMembers,
    required this.onOpenMembership,
    required this.onManageFamily,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final PatientIdentity patient;
  final IdCardInfo idCard;
  final MyClubSummary myClub;
  final List<FamilyMember> familyMembers;
  final VoidCallback onOpenMembership;
  final VoidCallback onManageFamily;
  final VoidCallback onSignOut;
  final Future<void> Function() onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F7F8), Color(0xFFE8EEF8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeroHeader(patient: patient),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'Membership',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: ProfileMembershipCard(
                    patient: patient,
                    idCard: idCard,
                    myClub: myClub,
                    onTap: onOpenMembership,
                    onInvite: () {
                      unawaited(shareReferralInvite(myClub.referrals));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'Relatives',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _RelativesCard(familyMembers: familyMembers),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: onManageFamily,
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Manage family members'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: const Color(0xFF06489B),
                      side: const BorderSide(color: Color(0xFFB8CAE1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'Health Profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _HealthProfileCard(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'Personal Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _PersonalInfoCard(patient: patient),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _ProfileSettingsCard(onDeleteAccount: onDeleteAccount),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _SignOutButton(onPressed: onSignOut),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Center(
                    child: Text(
                      'BHRC Patient Portal v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A94A6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroHeader extends StatelessWidget {
  const _ProfileHeroHeader({required this.patient});

  final PatientIdentity patient;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    final gender = (patient.gender ?? '').trim();
    final genderLabel = gender.isEmpty
        ? 'Sex not specified'
        : '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}';
    final ageLabel = patient.age == null
        ? 'Age not specified'
        : '${patient.age} years';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 30),
      color: const Color(0xFFF4F7F8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 58),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BHRC Hospital',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF06489B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Biohelix Health and Research Center',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF66758A),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E9F2)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06489B).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  patient.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$ageLabel  •  $genderLabel',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE6EBF2)),
                const SizedBox(height: 18),
                _PatientQrCard(patient: patient),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileMembershipCard extends StatelessWidget {
  const ProfileMembershipCard({
    super.key,
    required this.patient,
    required this.idCard,
    required this.myClub,
    required this.onTap,
    required this.onInvite,
  });

  final PatientIdentity patient;
  final IdCardInfo idCard;
  final MyClubSummary myClub;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final benefits = myClub.benefits
        .where(
          (benefit) =>
              benefit.trim().toLowerCase() != 'start earning myclub rewards',
        )
        .take(2);
    final levelColor = _profileMembershipColor(myClub.levelColor);
    final nextLevel = myClub.nextTierName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Open membership level, points and transactions',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(levelColor, Colors.white, 0.12)!,
                      Color.lerp(levelColor, Colors.black, 0.22)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFE0D5FF),
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'BHRC MEMBERSHIP',
                            style: TextStyle(
                              color: Color(0xFFE0D5FF),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            myClub.levelName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${myClub.levelName} Membership',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${patient.name}  •  ${patient.registrationNumber}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${myClub.lifetimePoints} lifetime points',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (myClub.leaderboardRank > 0)
                          Text(
                            'Rank #${myClub.leaderboardRank}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (nextLevel != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: myClub.progressPercent.clamp(0, 100) / 100,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${myClub.pointsToNextTier} points to $nextLevel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (benefits.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ...benefits.map(
                        (benefit) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFFE0D5FF),
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'View points & transactions',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('profile_invite_friends'),
          onPressed: onInvite,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text('Invite Friends'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFF06489B),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

Color _profileMembershipColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);

  return parsed == null ? const Color(0xFF7B3FF2) : Color(0xFF000000 | parsed);
}

class _PatientQrCard extends StatelessWidget {
  const _PatientQrCard({required this.patient});

  final PatientIdentity patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrData = patient.uuid.isNotEmpty
        ? patient.uuid
        : patient.registrationNumber;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDF1F6)),
            ),
            child: BarcodeWidget(
              data: qrData,
              barcode: Barcode.qrCode(),
              width: 180,
              height: 180,
              drawText: false,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Show this code at the reception or lab counter',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8A94A6),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelativesCard extends StatelessWidget {
  const _RelativesCard({required this.familyMembers});

  final List<FamilyMember> familyMembers;

  @override
  Widget build(BuildContext context) {
    if (familyMembers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6EBF2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: Color(0xFF06489B)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No relatives are linked to this patient yet.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: Column(
        children: familyMembers.indexed.map((entry) {
          final (index, member) = entry;
          return _ProfileInfoTile(
            icon: Icons.family_restroom_rounded,
            label: member.name,
            value: _formatRelationship(member.relationship),
            isLast: index == familyMembers.length - 1,
          );
        }).toList(),
      ),
    );
  }
}

String _formatRelationship(String value) {
  if (value.trim().isEmpty) return 'Family member';
  final normalized = value.trim().replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1);
}

part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.patient});

  final PatientIdentity patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _ProfileInfoTile(
            icon: Icons.person_outline_rounded,
            label: 'Full Name',
            value: patient.name,
          ),
          _ProfileInfoTile(
            icon: Icons.call_outlined,
            label: 'Mobile',
            value: patient.phone,
          ),
          _ProfileInfoTile(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: patient.email ?? 'Not added',
          ),
          _ProfileInfoTile(
            icon: Icons.cake_outlined,
            label: 'Date of Birth',
            value: patient.dob ?? 'Not added',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ProfileSettingsCard extends StatelessWidget {
  const _ProfileSettingsCard({required this.onOpenTestsHub});

  final VoidCallback onOpenTestsHub;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          // const _ProfileInfoTile(
          //   icon: Icons.notifications_none_rounded,
          //   label: 'Notifications',
          //   value: '',
          // ),
          // _ProfileInfoTile(
          //   icon: Icons.science_outlined,
          //   label: 'Tests Explorer',
          //   value: 'Open the previous tests screen',
          //   onTap: onOpenTestsHub,
          // ),
          _ProfileInfoTile(
            icon: Icons.verified_user_outlined,
            label: 'Privacy Policy',
            value: '',
            onTap: () async {
              final url = Uri.parse('https://www.bhrchospital.com/privacy-policy');
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
          // const _ProfileInfoTile(
          //   icon: Icons.translate_rounded,
          //   label: 'Language',
          //   value: '',
          //   isLast: true,
          // ),
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFE5E9F0))),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF5A88F1)),
            const SizedBox(width: 12),
            Expanded(child: _buildContent()),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA6B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (value.isEmpty) {
      return Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8B95A7),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: Color(0xFFF0CBC9)),
        foregroundColor: const Color(0xFFDB4C4C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.logout_rounded),
      label: const Text(
        'Sign Out',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

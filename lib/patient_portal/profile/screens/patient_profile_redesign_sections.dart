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
  const _ProfileSettingsCard({required this.onDeleteAccount});

  final Future<void> Function() onDeleteAccount;

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
            onTap: () => _showLegalDocument(
              context,
              title: 'Privacy Policy',
              selectDocument: (content) => content.privacyPolicy,
            ),
          ),
          _ProfileInfoTile(
            icon: Icons.description_outlined,
            label: 'Terms & Conditions',
            value: '',
            onTap: () => _showLegalDocument(
              context,
              title: 'Terms & Conditions',
              selectDocument: (content) => content.termsAndConditions,
            ),
          ),
          _ProfileInfoTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete my account',
            value: '',
            foregroundColor: const Color(0xFFD94444),
            isLast: true,
            onTap: () => _confirmDeleteAccount(context),
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

  Future<void> _showLegalDocument(
    BuildContext context, {
    required String title,
    required LocalizedLegalDocument Function(LegalContent content)
    selectDocument,
  }) {
    final apiClient = context.read<ApiClient>();
    final language = context.read<LanguageProvider>().language;
    final strings = AppStrings.of(language);
    final contentFuture = apiClient
        .getJson('/legal-content')
        .then(LegalContent.fromJson);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D9E6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: strings.close,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<LegalContent>(
                future: contentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final document = snapshot.hasData
                      ? selectDocument(snapshot.data!).forLanguage(language)
                      : '';
                  final markdown = document.trim().isEmpty
                      ? strings.legalContentUnavailable
                      : document;

                  return Markdown(
                    data: markdown,
                    padding: const EdgeInsets.all(20),
                    selectable: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountConfirmationDialog(),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await onDeleteAccount();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $error')),
      );
    }
  }
}

class _DeleteAccountConfirmationDialog extends StatefulWidget {
  const _DeleteAccountConfirmationDialog();

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends State<_DeleteAccountConfirmationDialog> {
  final TextEditingController _confirmationController = TextEditingController();

  bool get _canDelete => _confirmationController.text.trim() == 'CONFIRM';

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Color(0xFFD94444),
        size: 34,
      ),
      title: const Text('Delete your account?', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This action cannot be undone. You will lose portal access and be '
            'signed out on every device. Clinical records held by BHRC will '
            'be retained for medical and legal requirements.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          const Text(
            'Type CONFIRM to continue',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmationController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'CONFIRM',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canDelete ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD94444),
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete my account'),
        ),
      ],
    );
  }
}

class _HealthProfileCard extends StatelessWidget {
  const _HealthProfileCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: _ProfileInfoTile(
        icon: Icons.favorite_outline_rounded,
        label: 'View Health Profile',
        value: 'Conditions, medications and allergies',
        isLast: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const HealthProfileScreen(),
            ),
          );
        },
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
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isLast;
  final Color? foregroundColor;

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
            Icon(icon, color: foregroundColor ?? const Color(0xFF06489B)),
            const SizedBox(width: 12),
            Expanded(child: _buildContent()),
            Icon(
              Icons.chevron_right_rounded,
              color: foregroundColor ?? const Color(0xFF9CA6B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (value.isEmpty) {
      return Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w600),
      );
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

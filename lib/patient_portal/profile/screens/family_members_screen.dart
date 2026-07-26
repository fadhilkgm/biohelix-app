part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _FamilyMembersScreen extends StatefulWidget {
  const _FamilyMembersScreen();

  @override
  State<_FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<_FamilyMembersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  String _relationship = 'spouse';
  String _gender = 'female';
  bool _isSaving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: Consumer<PatientPortalProvider>(
        builder: (context, portal, _) => ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 14,
            16,
            32,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppChevronBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Family Members',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF192233),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Link a relative once, then book appointments and home care for them.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF617086),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE0E7EF)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add family member',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        'First name',
                        Icons.person_outline_rounded,
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'First name is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        'Last name',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _relationship,
                      decoration: _inputDecoration(
                        'Relationship',
                        Icons.family_restroom_rounded,
                      ),
                      items:
                          const [
                                'father',
                                'mother',
                                'spouse',
                                'son',
                                'daughter',
                                'brother',
                                'sister',
                                'other',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_formatRelationship(value)),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _relationship = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: _inputDecoration('Sex', Icons.wc_rounded),
                      items: const ['male', 'female', 'other']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_formatRelationship(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _gender = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: _inputDecoration(
                        'Phone number',
                        Icons.call_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: _inputDecoration(
                        'Date of birth',
                        Icons.calendar_month_outlined,
                      ),
                      onTap: _pickDateOfBirth,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : () => _save(portal),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: const Color(0xFF06489B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        _isSaving ? 'Adding...' : 'Add family member',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Linked relatives',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            if (portal.familyMembers.isEmpty)
              const _HomeCareEmptyText(
                text: 'No family members are linked yet.',
              )
            else
              ...portal.familyMembers.map(
                (member) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE0E7EF)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE6F0FC),
                        foregroundColor: Color(0xFF06489B),
                        child: Icon(Icons.family_restroom_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _formatRelationship(member.relationship),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF617086),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Future<void> _pickDateOfBirth() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _save(PatientPortalProvider portal) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    try {
      await portal.addLinkedFamilyMember(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        relationship: _relationship,
        gender: _gender,
        phone: _phoneController.text,
        dateOfBirth: _dobController.text,
      );
      if (!mounted) return;
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      _dobController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF14845D),
          behavior: SnackBarBehavior.floating,
          content: Text('Family member added successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

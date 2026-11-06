import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../core/data/patient_repository.dart';

class AiContentReportButton extends StatelessWidget {
  const AiContentReportButton({
    super.key,
    required this.content,
    required this.source,
    this.compact = false,
    this.foregroundColor,
  });

  final String content;
  final String source;
  final bool compact;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.of(
      context.watch<LanguageProvider>().language,
    ).assistantReportResponse;
    void report() =>
        showAiContentReportDialog(context, content: content, source: source);
    if (compact) {
      return IconButton(
        tooltip: label,
        color: foregroundColor,
        icon: const Icon(Icons.flag_outlined, size: 18),
        onPressed: report,
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: foregroundColor),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: Text(label),
      onPressed: report,
    );
  }
}

Future<void> showAiContentReportDialog(
  BuildContext context, {
  required String content,
  required String source,
  String? conversationId,
  int? messageId,
}) {
  final session = context.read<SessionProvider>();
  return showDialog<void>(
    context: context,
    builder: (_) => _AiContentReportDialog(
      content: content,
      source: source,
      conversationId: conversationId,
      messageId: messageId,
      repository: context.read<PatientRepository>(),
      session: session,
      patientId: session.patient?.id,
      isMalayalam: context.read<LanguageProvider>().language == AppLanguage.ml,
    ),
  );
}

class _AiContentReportDialog extends StatefulWidget {
  const _AiContentReportDialog({
    required this.content,
    required this.source,
    required this.repository,
    required this.session,
    required this.patientId,
    required this.isMalayalam,
    this.conversationId,
    this.messageId,
  });

  final String content;
  final String source;
  final String? conversationId;
  final int? messageId;
  final PatientRepository repository;
  final SessionProvider session;
  final int? patientId;
  final bool isMalayalam;

  @override
  State<_AiContentReportDialog> createState() => _AiContentReportDialogState();
}

class _AiContentReportDialogState extends State<_AiContentReportDialog> {
  String _reason = 'unsafe_medical_advice';
  bool _submitting = false;
  String? _error;

  String _text(String english, String malayalam) =>
      widget.isMalayalam ? malayalam : english;

  Future<void> _submit() async {
    if (_submitting) return;
    if (widget.patientId == null ||
        !widget.session.isAuthenticated ||
        widget.session.patient?.id != widget.patientId) {
      setState(() {
        _error = _text(
          'Your profile changed. Close this report and try again.',
          'പ്രൊഫൈൽ മാറിയിരിക്കുന്നു. റിപ്പോർട്ട് അടച്ച് വീണ്ടും ശ്രമിക്കുക.',
        );
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.reportAiContent(
        content: widget.content,
        source: widget.source,
        reason: _reason,
        conversationId: widget.conversationId,
        messageId: widget.messageId,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text('Report received by BHRC.', 'BHRC റിപ്പോർട്ട് സ്വീകരിച്ചു.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _text(
          'The report was not sent. Please try again.',
          'റിപ്പോർട്ട് അയച്ചില്ല. വീണ്ടും ശ്രമിക്കുക.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          _text('Report AI response', 'AI മറുപടി റിപ്പോർട്ട് ചെയ്യുക'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(
                'This sends the selected AI response and your reason to BHRC for review. '
                    'It does not send the rest of your conversation. For urgent medical help, contact a healthcare professional.',
                'തിരഞ്ഞെടുത്ത AI മറുപടിയും കാരണവും പരിശോധനയ്ക്കായി BHRC-ലേക്ക് അയയ്ക്കും. '
                    'ചാറ്റിലെ മറ്റ് സന്ദേശങ്ങൾ അയയ്ക്കില്ല. അടിയന്തര വൈദ്യസഹായത്തിന് ആരോഗ്യ വിദഗ്ധനെ സമീപിക്കുക.',
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.content, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: InputDecoration(labelText: _text('Reason', 'കാരണം')),
              items:
                  [
                        (
                          'unsafe_medical_advice',
                          _text(
                            'Unsafe medical advice',
                            'സുരക്ഷിതമല്ലാത്ത വൈദ്യോപദേശം',
                          ),
                        ),
                        (
                          'offensive_content',
                          _text('Offensive content', 'അനുചിതമായ ഉള്ളടക്കം'),
                        ),
                        (
                          'incorrect_information',
                          _text('Incorrect information', 'തെറ്റായ വിവരം'),
                        ),
                        ('other', _text('Other concern', 'മറ്റൊരു ആശങ്ക')),
                      ]
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.$1,
                          child: Text(item.$2),
                        ),
                      )
                      .toList(),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _reason = value!),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: Text(_text('Cancel', 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            key: const ValueKey('submit_ai_content_report'),
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting
                  ? _text('Sending…', 'അയയ്ക്കുന്നു…')
                  : _text('Send report', 'റിപ്പോർട്ട് അയയ്ക്കുക'),
            ),
          ),
        ],
      ),
    );
  }
}

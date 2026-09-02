part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

String _normalizeAssistantMarkdown(String value) {
  return value.replaceAllMapped(
    RegExp(r'(^|\n)([A-Za-z][^:\n]{0,80}):\*\s*', multiLine: true),
    (match) => '${match.group(1)}**${match.group(2)}:** ',
  );
}

/// `MarkdownStyleSheet.fromTheme` walks the whole text theme, which is far too
/// expensive to redo for every bubble on every frame. Cache one sheet per
/// [ThemeData] identity (an Expando keeps it alive only as long as the theme).
final Expando<MarkdownStyleSheet> _assistantMarkdownStyles =
    Expando<MarkdownStyleSheet>('assistantMarkdownStyleSheet');

MarkdownStyleSheet _assistantMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final cached = _assistantMarkdownStyles[theme];
  if (cached != null) return cached;

  final bubbleAi = AppTextStyles.bubbleAi(context);
  final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: bubbleAi,
    listBullet: bubbleAi,
    blockquote: bubbleAi,
    code: bubbleAi.copyWith(fontFamily: 'monospace'),
  );
  _assistantMarkdownStyles[theme] = sheet;
  return sheet;
}

void _openAssistantMessageActions(BuildContext context, ChatMessage message) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('assistant_copy_message'),
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: message.content));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _MessageBubbleWidget extends StatelessWidget {
  const _MessageBubbleWidget({
    required this.message,
    required this.timeLabel,
    required this.attachments,
    required this.isSpeaking,
    required this.onAttachmentTap,
    this.isStreaming = false,
  });

  final ChatMessage message;
  final String timeLabel;
  final List<_ChatAttachment> attachments;
  final bool isSpeaking;
  final ValueChanged<_ChatAttachment> onAttachmentTap;

  /// True when this is the trailing placeholder currently being streamed into.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    // An empty placeholder reads as a broken bubble; show the typing indicator
    // until the first token lands.
    if (!isUser && isStreaming && message.content.trim().isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: TypingIndicatorWidget(),
      );
    }

    final radius = BorderRadius.only(
      topLeft: Radius.circular(
        isUser ? AppRadius.bubbleTight : AppRadius.bubble,
      ),
      topRight: Radius.circular(
        isUser ? AppRadius.bubble : AppRadius.bubbleTight,
      ),
      bottomLeft: const Radius.circular(AppRadius.bubble),
      bottomRight: const Radius.circular(AppRadius.bubble),
    );

    return GestureDetector(
      onLongPress: isUser
          ? null
          : () => _openAssistantMessageActions(context, message),
      child: Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: AiChatColors.userBubbleGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.all(AppSpacing.s14),
              decoration: BoxDecoration(
                color: isUser ? AiChatColors.userBubble : AiChatColors.bubbleAi,
                border: isUser ? null : Border.all(color: AiChatColors.border),
                borderRadius: radius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message.content,
                      style: AppTextStyles.bubbleUser(context),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: MarkdownBody(
                            data: _normalizeAssistantMarkdown(message.content),
                            selectable: true,
                            styleSheet: _assistantMarkdownStyleSheet(context),
                            onTapLink: (text, href, title) {
                              if ((href ?? '').isEmpty) return;
                              final uri = Uri.tryParse(href!);
                              if (uri == null) return;
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ),
                        if (isStreaming) const _StreamingCaret(),
                      ],
                    ),
                  for (final attachment in attachments)
                    _ChatAttachmentWidget(
                      attachment: attachment,
                      onTap: () => onAttachmentTap(attachment),
                    ),
                  if (!isUser && message.suggestedPackages.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s10),
                    const Divider(thickness: 0.5, height: 1),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      '🧪 Suggested Packages',
                      style: AppTextStyles.bubbleAi(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    for (final pkg in message.suggestedPackages)
                      _PackageSuggestionCard(
                        pkg: pkg,
                        sourceAssessmentToken:
                            message.action?.sourceSessionToken,
                      ),
                  ],
                  if (!isUser && message.suggestedTests.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s10),
                    const Divider(thickness: 0.5, height: 1),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      '🔬 Suggested Tests',
                      style: AppTextStyles.bubbleAi(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    for (final test in message.suggestedTests)
                      _TestSuggestionCard(
                        test: test,
                        sourceAssessmentToken:
                            message.action?.sourceSessionToken,
                      ),
                  ],
                  if (!isUser &&
                      message.action != null &&
                      !message.action!.isAdviceOnly) ...[
                    const SizedBox(height: AppSpacing.s10),
                    _ChatActionPanel(action: message.action!),
                  ],
                  const SizedBox(height: AppSpacing.s8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      timeLabel,
                      style: AppTextStyles.subtitle(context).copyWith(
                        fontSize: 11,
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.9)
                            : AiChatColors.textSecondary,
                      ),
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
}

/// A cheap blinking caret pinned to the tail of a reply while it streams.
/// Deliberately a plain timer + opacity rather than an animation controller:
/// it repaints one glyph, not the bubble.
class _StreamingCaret extends StatefulWidget {
  const _StreamingCaret();

  @override
  State<_StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<_StreamingCaret> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted) return;
      setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: Text('▍', style: AppTextStyles.bubbleAi(context)),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AiChatColors.surfaceTint,
          border: Border.all(color: AiChatColors.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: AppTextStyles.dateSeparator(context)),
      ),
    );
  }
}

class _PackageSuggestionCard extends StatelessWidget {
  const _PackageSuggestionCard({required this.pkg, this.sourceAssessmentToken});

  final LabPackageItem pkg;
  final String? sourceAssessmentToken;

  @override
  Widget build(BuildContext context) {
    final price = pkg.discountedPrice != null && pkg.discountedPrice! > 0
        ? pkg.discountedPrice!
        : pkg.basePrice;
    final hasDiscount =
        pkg.discountedPrice != null &&
        pkg.discountedPrice! > 0 &&
        pkg.discountedPrice! < pkg.basePrice;

    return GestureDetector(
      onTap: () => _openBooking(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        padding: const EdgeInsets.all(AppSpacing.s10),
        decoration: BoxDecoration(
          color: const Color(0xFFEEFAF7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF26A89A).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.science_rounded,
              size: 18,
              color: Color(0xFF26A89A),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.name,
                    style: AppTextStyles.bubbleAi(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((pkg.category ?? '').isNotEmpty)
                    Text(
                      pkg.category!,
                      style: AppTextStyles.bubbleAi(context).copyWith(
                        fontSize: 10,
                        color: AiChatColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDiscount)
                  Text(
                    '₹${pkg.basePrice}',
                    style: AppTextStyles.bubbleAi(context).copyWith(
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      color: AiChatColors.textSecondary,
                    ),
                  ),
                Text(
                  price == 0 ? 'Free' : '₹$price',
                  style: AppTextStyles.bubbleAi(context).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: const Color(0xFF26A89A),
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: () => _openBooking(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF26A89A),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openBooking(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PackageBookingScreen(package: pkg),
      ),
    );
  }
}

class _TestSuggestionCard extends StatelessWidget {
  const _TestSuggestionCard({required this.test, this.sourceAssessmentToken});

  final LabTestItem test;
  final String? sourceAssessmentToken;

  @override
  Widget build(BuildContext context) {
    final price = test.discountedPrice != null && test.discountedPrice! > 0
        ? test.discountedPrice!
        : test.basePrice;
    final hasDiscount =
        test.discountedPrice != null &&
        test.discountedPrice! > 0 &&
        test.discountedPrice! < test.basePrice;

    return GestureDetector(
      onTap: () => _addAndBook(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        padding: const EdgeInsets.all(AppSpacing.s10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF06489B).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.biotech_rounded,
              size: 18,
              color: Color(0xFF06489B),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                test.testName,
                style: AppTextStyles.bubbleAi(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDiscount)
                  Text(
                    '₹${test.basePrice.toStringAsFixed(0)}',
                    style: AppTextStyles.bubbleAi(context).copyWith(
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      color: AiChatColors.textSecondary,
                    ),
                  ),
                Text(
                  price == 0 ? 'Free' : '₹${price.toStringAsFixed(0)}',
                  style: AppTextStyles.bubbleAi(context).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: const Color(0xFF06489B),
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: () => _addAndBook(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF06489B),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '+ Add & Book',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BookableLabTest _toBookable(LabTestItem item) {
    final lower = item.testName.toLowerCase();
    return BookableLabTest(
      id: item.id,
      name: item.testName,
      bodyPoints: item.bodyPoints,
      imageUrl: item.imageUrl,
      description:
          'Advanced ${item.testName} profile with clinically reviewed parameters and fast turnaround.',
      preparation: (item.instructions ?? '').trim().isNotEmpty
          ? item.instructions!.trim()
          : (lower.contains('fbs')
                ? 'Fasting required for 8-10 hours before sample collection.'
                : 'Stay hydrated and follow physician instructions before collection.'),
      parameters: lower.contains('cbc')
          ? const ['Hemoglobin', 'WBC', 'RBC', 'Platelets']
          : const ['Primary marker', 'Secondary marker', 'Reference range'],
      price: (item.discountedPrice ?? item.basePrice).toDouble(),
      basePrice: item.basePrice.toDouble(),
      popular: item.id % 2 == 0,
      originalItem: item,
    );
  }

  void _addAndBook(BuildContext context) {
    final portal = context.read<PatientPortalProvider>();
    final controller = LabBookingController(
      patientName: portal.dashboard?.patient.name ?? 'Patient',
      patientPhone: portal.dashboard?.patient.phone,
      tests: portal.labTests,
      bodyPoints: portal.bodyPoints,
      sourceAssessmentToken: sourceAssessmentToken,
    );
    controller.addToCart(_toBookable(test));

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: const TestBookingScreen(),
        ),
      ),
    );
  }
}

class _ChatActionPanel extends StatelessWidget {
  const _ChatActionPanel({required this.action});

  final ChatAssistantAction action;

  @override
  Widget build(BuildContext context) {
    if (action.urgency == 'emergency') {
      return FilledButton.icon(
        key: const ValueKey('assistant_emergency_action'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC43D4B)),
        onPressed: () => _openEmergency(context),
        icon: const Icon(Icons.emergency_rounded),
        label: const Text('Open emergency contacts'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (action.bookingCreated)
          _ActionNotice(
            key: const ValueKey('assistant_booking_confirmed'),
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF16855B),
            text: action.bookingNumber == null
                ? 'Appointment booked successfully.'
                : 'Appointment booked • ${action.bookingNumber}',
          ),
        if (action.state == 'awaiting_confirmation')
          const _ActionNotice(
            key: ValueKey('assistant_confirmation_required'),
            icon: Icons.help_outline_rounded,
            color: Color(0xFF9A6212),
            text: 'Reply Yes to confirm or No to decline.',
          ),
        for (final doctor in action.recommendedDoctors)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              key: ValueKey('assistant_doctor_${doctor.id}'),
              onPressed: () => _openDoctor(context, doctor),
              icon: const Icon(Icons.medical_services_outlined),
              label: Text(
                [doctor.name, doctor.specialization]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .join(' • '),
              ),
            ),
          ),
        if (action.customPackage != null) ...[
          const SizedBox(height: 8),
          _CustomPackageActionCard(
            package: action.customPackage!,
            sourceAssessmentToken: action.sourceSessionToken,
          ),
        ],
        if (action.supportRequired) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('assistant_hospital_support'),
            onPressed: () => launchUrl(Uri.parse('tel:+917510210224')),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Contact BHRC reception'),
          ),
        ],
      ],
    );
  }

  void _openDoctor(
    BuildContext context,
    ChatDoctorRecommendation recommendation,
  ) {
    final doctors = context.read<PatientPortalProvider>().doctors;
    DoctorListing? match;
    for (final doctor in doctors) {
      if (doctor.id == recommendation.id) {
        match = doctor;
        break;
      }
    }
    if (match == null) {
      AppToast.show(
        context,
        message: 'This doctor is no longer available.',
        type: AppToastType.warning,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DoctorDetailPage(
          doctor: match!,
          sourceAssessmentToken: action.sourceSessionToken,
        ),
      ),
    );
  }

  void _openEmergency(BuildContext context) {
    final portal = context.read<PatientPortalProvider>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencySupportScreen(
          patientName: portal.dashboard?.patient.name ?? 'Patient',
          contacts: portal.dashboard?.emergencyContacts ?? const [],
        ),
      ),
    );
  }
}

class _ActionNotice extends StatelessWidget {
  const _ActionNotice({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _CustomPackageActionCard extends StatelessWidget {
  const _CustomPackageActionCard({
    required this.package,
    required this.sourceAssessmentToken,
  });

  final ChatCustomPackage package;
  final String? sourceAssessmentToken;

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(package.price ?? '');
    return Container(
      key: const ValueKey('assistant_custom_package'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEFAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26A89A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            package.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${package.testIds.length} tests${price == null ? '' : ' • ₹${price.toStringAsFixed(0)}'}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('assistant_custom_package_review'),
            onPressed: package.testIds.isEmpty ? null : () => _review(context),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Review and edit panel'),
          ),
        ],
      ),
    );
  }

  void _review(BuildContext context) {
    final activeIds = context
        .read<PatientPortalProvider>()
        .labTests
        .where((test) => test.status && package.testIds.contains(test.id))
        .map((test) => test.id)
        .toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabTestHomeScreen(
          initialTestIds: activeIds,
          sourceAssessmentToken: sourceAssessmentToken,
        ),
      ),
    );
  }
}

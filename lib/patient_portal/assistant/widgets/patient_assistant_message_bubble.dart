part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _MessageBubbleWidget extends StatelessWidget {
  const _MessageBubbleWidget({
    required this.message,
    required this.timeLabel,
    required this.attachments,
    required this.isSpeaking,
    required this.onSpeakTap,
    required this.onStopTap,
    required this.onAttachmentTap,
  });

  final ChatMessage message;
  final String timeLabel;
  final List<_ChatAttachment> attachments;
  final bool isSpeaking;
  final VoidCallback onSpeakTap;
  final VoidCallback onStopTap;
  final ValueChanged<_ChatAttachment> onAttachmentTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final isUser = message.role == 'user';
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

    return Align(
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
                gradient: isUser ? AiChatColors.userBubbleGradient : null,
                color: isUser ? null : AiChatColors.bubbleAi,
                border: isUser
                    ? null
                    : Border.all(color: AiChatColors.border),
                borderRadius: radius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: onSpeakTap,
                        tooltip: isSpeaking
                            ? strings.assistantStopVoice
                            : strings.assistantPlayVoice,
                        iconSize: 18,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AiChatColors.textSecondary,
                        ),
                        icon: Icon(
                          isSpeaking
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_outlined,
                        ),
                      ),
                    ),
                  if (isUser)
                    Text(
                      message.content,
                      style: AppTextStyles.bubbleUser(context),
                    )
                  else
                    _RevealingMarkdown(
                      data: message.content,
                      animate: isSpeaking,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: AppTextStyles.bubbleAi(context),
                            listBullet: AppTextStyles.bubbleAi(context),
                            blockquote: AppTextStyles.bubbleAi(context),
                            code: AppTextStyles.bubbleAi(
                              context,
                            ).copyWith(fontFamily: 'monospace'),
                          ),
                      onTapLink: (text, href, title) {
                        if ((href ?? '').isEmpty) return;
                        final uri = Uri.tryParse(href!);
                        if (uri == null) return;
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
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
                      _PackageSuggestionCard(pkg: pkg),
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
                      _TestSuggestionCard(test: test),
                  ],
                  if (!isUser && isSpeaking)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s10),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onStopTap,
                          icon: const Icon(Icons.volume_off_rounded),
                          label: Text(strings.assistantStopAiVoice),
                        ),
                      ),
                    ),
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
    );
  }
}

/// Renders an AI reply as markdown, progressively revealing it word-by-word
/// while [animate] is true (i.e. while the reply is being spoken aloud). When
/// [animate] turns false the full text is shown immediately, so the reveal
/// self-corrects to the actual speech duration.
class _RevealingMarkdown extends StatefulWidget {
  const _RevealingMarkdown({
    required this.data,
    required this.animate,
    required this.styleSheet,
    this.onTapLink,
  });

  final String data;
  final bool animate;
  final MarkdownStyleSheet styleSheet;
  final void Function(String text, String? href, String? title)? onTapLink;

  @override
  State<_RevealingMarkdown> createState() => _RevealingMarkdownState();
}

class _RevealingMarkdownState extends State<_RevealingMarkdown> {
  static const Duration _wordInterval = Duration(milliseconds: 190);

  // End offsets of each word in `data`, used to reveal a growing prefix that
  // keeps the original markdown/whitespace intact.
  List<int> _wordEnds = const [];
  int _revealed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _computeWordEnds();
    if (widget.animate) {
      _revealed = 0;
      _startTimer();
    } else {
      _revealed = _wordEnds.length;
    }
  }

  @override
  void didUpdateWidget(covariant _RevealingMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _computeWordEnds();
      _revealed = widget.animate ? 0 : _wordEnds.length;
    }
    if (widget.animate && !oldWidget.animate) {
      _revealed = 0;
      _startTimer();
    } else if (!widget.animate && oldWidget.animate) {
      // Speech ended — snap to the full text.
      _timer?.cancel();
      _revealed = _wordEnds.length;
    }
  }

  void _computeWordEnds() {
    _wordEnds = RegExp(r'\S+')
        .allMatches(widget.data)
        .map((match) => match.end)
        .toList(growable: false);
  }

  void _startTimer() {
    _timer?.cancel();
    if (_wordEnds.isEmpty) return;
    _timer = Timer.periodic(_wordInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_revealed >= _wordEnds.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _revealed++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown =
        (!widget.animate || _revealed >= _wordEnds.length || _wordEnds.isEmpty)
        ? widget.data
        : widget.data.substring(0, _wordEnds[_revealed - 1 < 0 ? 0 : _revealed - 1]);

    return MarkdownBody(
      data: _revealed == 0 && widget.animate ? '' : shown,
      styleSheet: widget.styleSheet,
      onTapLink: widget.onTapLink,
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
  const _PackageSuggestionCard({required this.pkg});

  final LabPackageItem pkg;

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
  const _TestSuggestionCard({required this.test});

  final LabTestItem test;

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
            color: const Color(0xFF5A88F1).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.biotech_rounded,
              size: 18,
              color: Color(0xFF5A88F1),
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
                    color: const Color(0xFF5A88F1),
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: () => _addAndBook(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5A88F1),
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

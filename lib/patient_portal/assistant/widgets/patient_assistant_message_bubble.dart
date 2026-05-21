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
                color: Color(0xFFDDF3EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 16),
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
                borderRadius: radius,
                boxShadow: isUser ? null : AiChatColors.softShadow,
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
                    MarkdownBody(
                      data: message.content,
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
                      style: AppTextStyles.bubbleAi(context).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    for (final pkg in message.suggestedPackages)
                      _PackageSuggestionCard(pkg: pkg),
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

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEF7),
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
    final hasDiscount = pkg.discountedPrice != null &&
        pkg.discountedPrice! > 0 &&
        pkg.discountedPrice! < pkg.basePrice;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const _TestsHubPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        padding: const EdgeInsets.all(AppSpacing.s10),
        decoration: BoxDecoration(
          color: const Color(0xFFEEFAF7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF26A89A).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_rounded, size: 18, color: Color(0xFF26A89A)),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.name,
                    style: AppTextStyles.bubbleAi(context).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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
                Text(
                  'View ›',
                  style: AppTextStyles.bubbleAi(context).copyWith(
                    fontSize: 10,
                    color: const Color(0xFF26A89A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

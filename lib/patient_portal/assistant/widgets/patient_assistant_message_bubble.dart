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
                      data: message.content.replaceAll(RegExp(r'\[\[VIEW_PACKAGE:\d+\]\]'), ''),
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
                  if (!isUser) ...[
                    // Package Button parsing
                    ...RegExp(r'\[\[VIEW_PACKAGE:(\d+)\]\]').allMatches(message.content).map((match) {
                      final packageId = int.tryParse(match.group(1) ?? '');
                      if (packageId == null) return const SizedBox.shrink();
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s12),
                        child: Consumer<PatientPortalProvider>(
                          builder: (context, portal, _) {
                            final pkg = portal.labPackages.firstWhere(
                              (p) => p.id == packageId,
                              orElse: () => const LabPackageItem(id: -1, name: '', slug: '', status: false, basePrice: 0),
                            );
                            
                            if (pkg.id == -1) return const SizedBox.shrink();
                            
                            return SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute(
                                      builder: (_) => PackageBookingScreen(package: pkg),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF5A88F1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                                label: Text('View ${pkg.name}'),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                  for (final attachment in attachments)
                    _ChatAttachmentWidget(
                      attachment: attachment,
                      onTap: () => onAttachmentTap(attachment),
                    ),
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

part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class ChatHeaderWidget extends StatelessWidget {
  const ChatHeaderWidget({
    required this.onToggleThreads,
    required this.showToggleThreads,
    required this.onNewChat,
    required this.isLiveMode,
    required this.isListening,
    required this.isSpeaking,
    required this.onInterruptAi,
    super.key,
  });

  final VoidCallback onToggleThreads;
  final bool showToggleThreads;
  final VoidCallback onNewChat;
  final bool isLiveMode;
  final bool isListening;
  final bool isSpeaking;
  final VoidCallback onInterruptAi;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final subtitle = isSpeaking
        ? strings.assistantSpeaking
        : isListening
        ? strings.assistantListening
        : isLiveMode
        ? strings.assistantLiveModeActive
        : strings.assistantReady;

    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.assistantTitle, style: AppTextStyles.title(context)),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AiChatColors.online,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(subtitle, style: AppTextStyles.subtitle(context)),
                ],
              ),
            ],
          ),
        ),
        if (isSpeaking)
          IconButton.filledTonal(
            onPressed: onInterruptAi,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            tooltip: strings.assistantInterruptAi,
          ),
        if (isSpeaking) const SizedBox(width: AppSpacing.s8),
        if (showToggleThreads)
          IconButton.filledTonal(
            onPressed: onToggleThreads,
            icon: const Icon(Icons.history_rounded, size: 18),
            tooltip: strings.assistantPreviousChats,
          ),
        const SizedBox(width: AppSpacing.s8),
        IconButton.filledTonal(
          onPressed: onNewChat,
          icon: const Icon(Icons.add_comment_rounded, size: 18),
          tooltip: strings.assistantNewChat,
        ),
      ],
    );
  }
}

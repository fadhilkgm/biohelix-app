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
    final subtitle = isSpeaking
        ? 'AI is talking'
        : isListening
        ? 'Listening to you'
        : isLiveMode
        ? 'Live mode active'
        : 'Ready';

    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health AI Assistant', style: AppTextStyles.title(context)),
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
            tooltip: 'Interrupt AI and talk',
          ),
        if (isSpeaking) const SizedBox(width: AppSpacing.s8),
        if (showToggleThreads)
          IconButton.filledTonal(
            onPressed: onToggleThreads,
            icon: const Icon(Icons.history_rounded, size: 18),
            tooltip: 'Previous chats',
          ),
        const SizedBox(width: AppSpacing.s8),
        IconButton.filledTonal(
          onPressed: onNewChat,
          icon: const Icon(Icons.add_comment_rounded, size: 18),
          tooltip: 'New chat',
        ),
      ],
    );
  }
}

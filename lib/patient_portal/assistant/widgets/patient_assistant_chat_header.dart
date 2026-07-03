part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class ChatHeaderWidget extends StatelessWidget {
  const ChatHeaderWidget({
    required this.onBack,
    required this.onToggleThreads,
    required this.showToggleThreads,
    required this.onNewChat,
    required this.isLiveMode,
    required this.isListening,
    required this.isSpeaking,
    required this.onInterruptAi,
    super.key,
  });

  final VoidCallback onBack;
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          _HeaderIconButton(
            onPressed: onBack,
            icon: Icons.arrow_back_rounded,
            tooltip: strings.assistantBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.assistantTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: AiChatColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _HeaderIconButton(
            onPressed: isSpeaking ? onInterruptAi : onNewChat,
            icon: isSpeaking
                ? Icons.stop_circle_outlined
                : Icons.add_comment_outlined,
            tooltip: isSpeaking
                ? strings.assistantInterruptAi
                : strings.assistantNewChat,
          ),
          // History (previous chats) lives at the right end on compact layouts;
          // on wide layouts the threads sidebar is always visible instead.
          if (showToggleThreads) ...[
            const SizedBox(width: 2),
            _HeaderIconButton(
              onPressed: onToggleThreads,
              icon: Icons.history_rounded,
              tooltip: strings.assistantPreviousChats,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 25, color: AiChatColors.primary),
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AiChatColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

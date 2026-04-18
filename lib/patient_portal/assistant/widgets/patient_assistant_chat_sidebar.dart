part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class ChatSidebarWidget extends StatelessWidget {
  const ChatSidebarWidget({
    required this.threads,
    required this.activeThreadId,
    required this.onThreadSelect,
    required this.onRenameThread,
    required this.onDeleteThread,
    required this.onNewChat,
    super.key,
  });

  final List<ChatThreadSummary> threads;
  final String? activeThreadId;
  final ValueChanged<String> onThreadSelect;
  final ValueChanged<String> onRenameThread;
  final ValueChanged<String> onDeleteThread;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AiChatColors.inputSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AiChatColors.softShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Previous Chats',
                    style: AppTextStyles.title(context).copyWith(fontSize: 17),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  tooltip: 'New chat',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: threads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final thread = threads[index];
                final selected = thread.id == activeThreadId;
                final preview = (thread.lastMessagePreview ?? '').trim();
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onThreadSelect(thread.id),
                  child: Ink(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE8F2FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                thread.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bubbleAi(context).copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (preview.isNotEmpty)
                                Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.subtitle(context),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz_rounded),
                          onSelected: (value) {
                            if (value == 'rename') {
                              onRenameThread(thread.id);
                            }
                            if (value == 'delete') {
                              onDeleteThread(thread.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Rename chat'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete chat'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

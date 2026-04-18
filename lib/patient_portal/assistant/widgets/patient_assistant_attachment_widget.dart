part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class ChatAttachmentWidget extends StatelessWidget {
  const ChatAttachmentWidget({
    required this.attachment,
    required this.onTap,
    super.key,
  });

  final _ChatAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = attachment.isImage
        ? Icons.image_outlined
        : Icons.insert_drive_file_rounded;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.s10),
        padding: const EdgeInsets.all(AppSpacing.s10),
        decoration: BoxDecoration(
          color: AiChatColors.bubbleAiSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            if (attachment.isImage && attachment.url.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  attachment.url,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => _AttachmentIcon(icon: icon),
                ),
              )
            else
              _AttachmentIcon(icon: icon),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bubbleAi(
                      context,
                    ).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    attachment.sizeLabel,
                    style: AppTextStyles.subtitle(context),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  const _AttachmentIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AiChatColors.gradientStart),
    );
  }
}

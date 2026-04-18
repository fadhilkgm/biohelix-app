part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentDetailSheet extends StatefulWidget {
  const _DocumentDetailSheet({required this.document});

  final DocumentRecord document;

  @override
  State<_DocumentDetailSheet> createState() => _DocumentDetailSheetState();
}

class _DocumentDetailSheetState extends State<_DocumentDetailSheet> {
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.document.hasAnalysis) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final portal = context.read<PatientPortalProvider>();
        portal.loadDocumentConversation(widget.document.id).catchError((_) {});
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final theme = Theme.of(context);
        final analysis = portal.analysisFor(widget.document.id);
        final summary = analysis?.summary ?? widget.document.summary ?? '';
        final texts = analysis?.texts ?? const <String>[];
        final chat = portal.documentChatFor(widget.document.id);
        final canChat = widget.document.hasAnalysis || analysis != null;
        final isAnalyzing = portal.analyzingDocumentId == widget.document.id;
        final isLoadingChat = portal.isDocumentChatLoading(widget.document.id);
        final isSendingChat = portal.isSendingDocumentChat(widget.document.id);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.document.documentType.toUpperCase(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.document.date}${widget.document.time == null ? '' : ' • ${widget.document.time}'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(label: canChat ? 'Analyzed' : 'Processing'),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report summary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          summary.isEmpty
                              ? 'Run AI analysis to generate a patient-friendly explanation and open document-specific follow-up chat.'
                              : summary,
                        ),
                        const SizedBox(height: 16),
                        if (!canChat)
                          CustomButton(
                            onPressed: () async {
                              try {
                                await portal.analyzeDocument(
                                  widget.document.id,
                                );
                                if (!context.mounted) return;
                                await portal.loadDocumentConversation(
                                  widget.document.id,
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            },
                            text: 'Analyze report',
                            isLoading: isAnalyzing,
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (texts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Extracted clues',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...texts
                              .take(3)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    item,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask about this report',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canChat
                              ? 'Questions in this thread stay tied to this document only.'
                              : 'Document chat becomes available after analysis completes.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 260,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: !canChat
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      'Analyze this report to unlock AI follow-up questions about values, trends, and next steps.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                )
                              : isLoadingChat
                              ? const Center(child: CircularProgressIndicator())
                              : chat.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      'Ask something specific like “What abnormalities are mentioned?” or “What should I discuss with my doctor?”',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: chat.length,
                                  itemBuilder: (context, index) {
                                    final message = chat[index];
                                    final isUser = message.role == 'user';
                                    return Align(
                                      alignment: isUser
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        constraints: const BoxConstraints(
                                          maxWidth: 320,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isUser
                                              ? const Color(0xFF164E63)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Text(
                                          message.content,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: isUser
                                                    ? Colors.white
                                                    : null,
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                enabled: canChat && !isSendingChat,
                                minLines: 1,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Ask about this report',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: !canChat || isSendingChat
                                  ? null
                                  : () async {
                                      final text = _chatController.text.trim();
                                      _chatController.clear();
                                      await portal.sendDocumentChatMessage(
                                        documentId: widget.document.id,
                                        message: text,
                                      );
                                    },
                              icon: isSendingChat
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


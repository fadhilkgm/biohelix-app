import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class InAppDocumentViewer extends StatelessWidget {
  const InAppDocumentViewer({
    super.key,
    required this.title,
    required this.url,
    this.authToken,
  });

  final String title;
  final String url;
  final String? authToken;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required String url,
    String? authToken,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InAppDocumentViewer(title: title, url: url, authToken: authToken),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = Uri.parse(url);
    final headers = <String, String>{
      if ((authToken ?? '').isNotEmpty) 'Authorization': 'Bearer $authToken',
    };
    final isImage = _isImageDocument(title: title, uri: uri);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: isImage
          ? _NetworkImageDocument(url: url, headers: headers)
          : PdfViewer.uri(
              uri,
              headers: headers.isEmpty ? null : headers,
              params: PdfViewerParams(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                loadingBannerBuilder: (context, downloaded, total) => Center(
                  child: CircularProgressIndicator(
                    value: total != null && total > 0
                        ? downloaded / total
                        : null,
                  ),
                ),
                errorBannerBuilder: (context, error, stackTrace, documentRef) =>
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Could not display this report.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
    );
  }

  static bool _isImageDocument({required String title, required Uri uri}) {
    final candidate = '${title.toLowerCase()} ${uri.path.toLowerCase()}';
    return const ['.jpg', '.jpeg', '.png', '.webp'].any(candidate.contains);
  }
}

class _NetworkImageDocument extends StatelessWidget {
  const _NetworkImageDocument({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InteractiveViewer(
        minScale: 0.7,
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            headers: headers.isEmpty ? null : headers,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              final total = progress.expectedTotalBytes;
              return Center(
                child: CircularProgressIndicator(
                  value: total == null || total == 0
                      ? null
                      : progress.cumulativeBytesLoaded / total,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not display this image.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

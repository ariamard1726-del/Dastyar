part of 'chat_bubbles.dart';

class DraftDocumentCard extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<String> onCopySensitive;
  final void Function(String text, {String? subject}) onShare;

  const DraftDocumentCard({
    super.key,
    required this.message,
    required this.onCopySensitive,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'پیش‌نویس: ${message.docTitle}',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (!message.docReviewed) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message.docReviewNote.isEmpty
                        ? 'این قالب هنوز بازبینی نشده است.'
                        : message.docReviewNote,
                    style: TextStyle(color: cs.onErrorContainer, height: 1.6),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SelectableText(
                message.text,
                style: const TextStyle(fontSize: 16, height: 1.9),
              ),
              if (message.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  message.note,
                  style: TextStyle(color: cs.error, height: 1.6),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => onCopySensitive(message.text),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('کپی متن'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        onShare(message.text, subject: message.docTitle),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('اشتراک‌گذاری'),
                  ),
                ],
              ),
              if (message.laws.isNotEmpty || message.lawRefsTotal > 0) ...[
                const Divider(height: 28),
                Text('مواد قانونی مرتبط', style: tt.titleSmall),
                const SizedBox(height: 8),
                if (message.laws.isEmpty)
                  const Text('متن رسمی مواد مرتبط هنوز در برنامه نیست.'),
                for (final l in message.laws) ...[
                  Text(
                    '${l.source} — ${l.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // متن قانون تا وقتی با منبع رسمی تطبیق داده نشده، نباید
                  // ظاهر «سند تأییدشده» داشته باشد.
                  if (!l.verified)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: cs.error),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'متن این قانون هنوز با منبع رسمی تطبیق داده نشده است؛ '
                              'پیش از استناد، آن را با متن رسمی یا وکیل بسنجید.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.error,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (l.note.isNotEmpty) Text(l.note),
                  const SizedBox(height: 4),
                  SelectableText(
                    l.body,
                    style: const TextStyle(fontSize: 15, height: 1.8),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 10),
              Text(
                docDisclaimer,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صفحهٔ آغازین: فقط معرفی کوتاه برنامه. پیشنهادها هنگام نوشتن، بالای کادر
/// پیام و متناسب با موضوع نمایش داده می‌شوند.

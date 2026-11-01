import 'package:flutter/material.dart';

import '../chat_models.dart';
import '../feedback.dart';
import '../templates.dart';

class UserMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const UserMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'پیام شما',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF3A3A37) : const Color(0xFFEFEDE6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SelectableText(
            message.text,
            style: const TextStyle(fontSize: 16, height: 1.7),
          ),
        ),
      ),
    );
  }
}

class BotMessageView extends StatelessWidget {
  final ChatMessage message;
  final String question;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;

  const BotMessageView({
    super.key,
    required this.message,
    required this.question,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final canAct = !message.sensitive && message.text != '...';
    return Semantics(
      label: 'پاسخ دستیار',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: const TextStyle(fontSize: 16, height: 1.9),
            ),
            if (canAct)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'کپی',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => onCopy(message.text),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'اشتراک‌گذاری',
                    icon: const Icon(Icons.share_outlined, size: 18),
                    onPressed: () => onShare(message.text),
                  ),
                  FeedbackBar(question: question, answer: message.text),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

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

class ChatEmptyState extends StatelessWidget {
  final List<LegalTemplate> templates;
  final ValueChanged<String> onSelectTemplate;

  const ChatEmptyState({
    super.key,
    required this.templates,
    required this.onSelectTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance, size: 40, color: cs.primary),
            const SizedBox(height: 16),
            const Text(
              'سلام، چه کمکی از من برمی‌آید؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'بدون اینترنت کار می‌کنم. می‌توانید سؤال بپرسید، مشکل خود را شرح دهید، یا بنویسید «می‌خواهم دادخواست بنویسم».',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.7),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in templates)
                  ActionChip(
                    avatar: const Icon(Icons.description_outlined, size: 18),
                    label: Text(t.title),
                    onPressed: () => onSelectTemplate(t.title),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatChipsBar extends StatelessWidget {
  final bool busy;
  final List<ChatMessage> messages;
  final ValueChanged<String> onSelectChip;

  const ChatChipsBar({
    super.key,
    required this.busy,
    required this.messages,
    required this.onSelectChip,
  });

  @override
  Widget build(BuildContext context) {
    if (busy || messages.isEmpty) return const SizedBox.shrink();
    final last = messages.last;
    if (last.fromUser || last.chips.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in last.chips)
                ActionChip(label: Text(c), onPressed: () => onSelectChip(c)),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final bool isDrafting;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.busy,
    required this.isDrafting,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 6, 4),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF30302E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: isDrafting
                      ? 'پاسخ خود را بنویسید...'
                      : 'پیام خود را بنویسید...',
                ),
              ),
            ),
            if (busy)
              IconButton.filled(
                tooltip: 'توقف پاسخ',
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
              )
            else
              IconButton.filled(
                tooltip: 'ارسال پیام',
                onPressed: onSend,
                icon: const Icon(Icons.arrow_upward),
              ),
          ],
        ),
      ),
    );
  }
}

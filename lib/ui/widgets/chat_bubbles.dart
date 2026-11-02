import 'package:flutter/material.dart';

import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/domain/feedback.dart';

/// رنگ‌های مینیمال الهام‌گرفته از Claude: کرم گرم، حاشیهٔ نازک،
/// بدون سایه و بدون کادرهای پررنگ.
const Color _kUserLight = Color(0xFFF0EEE6);
const Color _kUserDark = Color(0xFF353532);
const Color _kInkLight = Color(0xFF2E2D2B);
const Color _kInkDark = Color(0xFFEDEBE4);

class UserMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const UserMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'پیام شما',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: dark ? _kUserDark : _kUserLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.55),
              width: 0.7,
            ),
          ),
          child: SelectableText(
            message.text,
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: dark ? _kInkDark : _kInkLight,
            ),
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
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'پاسخ دستیار',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // پاسخ دستیار مثل Claude: متن ساده و بدون حباب.
            SelectableText(
              message.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.85,
                color: dark ? _kInkDark : _kInkLight,
              ),
            ),
            if (message.conflictChains.isNotEmpty && message.text != '...') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant, width: 0.7),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ارتباط یا تعارض ثبت‌شدهٔ مواد:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    for (final chain in message.conflictChains)
                      Text(
                        '• ${chain.replaceAll('->', '←')}',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (canAct)
              IconTheme(
                data: IconThemeData(
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'کپی',
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => onCopy(message.text),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'اشتراک‌گذاری',
                      icon: const Icon(Icons.share_outlined, size: 16),
                      onPressed: () => onShare(message.text),
                    ),
                    FeedbackBar(question: question, answer: message.text),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 0.7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'پیش‌نویس: ${message.docTitle}',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (!message.docReviewed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
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
              style: const TextStyle(fontSize: 15, height: 1.8),
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
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('کپی متن'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      onShare(message.text, subject: message.docTitle),
                  icon: const Icon(Icons.share_outlined, size: 16),
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
                  style: const TextStyle(fontSize: 14, height: 1.8),
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
    );
  }
}

/// صفحهٔ آغازین: فقط یک خوش‌آمدگویی تمیز و فیلد تایپ (بدون منو،
/// بدون دکمه‌ها و بدون فهرست قالب‌ها).
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.balance,
              size: 30,
              color: cs.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 18),
            Text(
              'سلام، چه کمکی از من برمی‌آید؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: dark ? _kInkDark : _kInkLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'مشکل حقوقی‌ات را بنویس؛ پاسخ‌ها فقط از متن قوانین داخل برنامه استخراج می‌شوند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.8,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// نوار کوچک و افقیِ ChoiceChipها، دقیقاً بالای فیلد تایپ.
class ChatChipsBar extends StatelessWidget {
  final bool busy;
  final List<ChatSuggestion> suggestions;
  final ValueChanged<String> onSelectChip;

  const ChatChipsBar({
    super.key,
    required this.busy,
    required this.suggestions,
    required this.onSelectChip,
  });

  @override
  Widget build(BuildContext context) {
    if (busy || suggestions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 4),
        child: Row(
          children: [
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(
                    s.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: false,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) => onSelectChip(s.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final bool isDrafting;
  final bool isCounseling;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.busy,
    required this.isDrafting,
    this.isCounseling = false,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 3, 5, 3),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
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
                style: const TextStyle(fontSize: 15, height: 1.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  hintText: isDrafting
                      ? 'پاسخ فیلد پیش‌نویس را بنویسید...'
                      : (isCounseling
                          ? 'پاسخ خود را بنویسید یا از گزینه‌ها انتخاب کنید...'
                          : 'پرسش حقوقی‌ات را بنویسید...'),
                ),
              ),
            ),
            if (busy)
              IconButton.filled(
                tooltip: 'توقف پاسخ',
                iconSize: 19,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
              )
            else
              IconButton.filled(
                tooltip: 'ارسال پیام',
                iconSize: 19,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                onPressed: onSend,
                icon: const Icon(Icons.arrow_upward),
              ),
          ],
        ),
      ),
    );
  }
}

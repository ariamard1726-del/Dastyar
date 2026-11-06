import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/domain/feedback.dart';
import 'package:dastyar/domain/input_suggestions.dart';
import 'package:dastyar/domain/templates.dart';

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

class BotMessageView extends StatefulWidget {
  final ChatMessage message;
  final String question;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;

  /// در هر گام نمایش تدریجی صدا زده می‌شود (برای پایین‌بردن فهرست).
  final VoidCallback? onRevealTick;

  /// وقتی نمایش تدریجی تمام شد صدا زده می‌شود.
  final VoidCallback? onRevealed;

  const BotMessageView({
    super.key,
    required this.message,
    required this.question,
    required this.onCopy,
    required this.onShare,
    this.onRevealTick,
    this.onRevealed,
  });

  @override
  State<BotMessageView> createState() => _BotMessageViewState();
}

class _BotMessageViewState extends State<BotMessageView> {
  void _revealed() {
    if (mounted) setState(() {});
    widget.onRevealed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final onCopy = widget.onCopy;
    final onShare = widget.onShare;
    final question = widget.question;
    final done = message.revealed || MediaQuery.disableAnimationsOf(context);
    final canAct = !message.sensitive && message.text != '...' && done;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'پاسخ دستیار',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealText(
              message: message,
              style: const TextStyle(fontSize: 16, height: 1.9),
              onTick: widget.onRevealTick,
              onRevealed: _revealed,
            ),
            if (message.conflictChains.isNotEmpty &&
                message.text != '...' &&
                done) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ارتباط یا تعارض ثبت‌شدهٔ مواد:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    for (final chain in message.conflictChains)
                      Text(
                        '• ${chain.replaceAll('->', '←')}',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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

/// صفحهٔ آغازین: فقط معرفی کوتاه برنامه. پیشنهادها هنگام نوشتن، بالای کادر
/// پیام و متناسب با موضوع نمایش داده می‌شوند.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

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
              'وکیل و مشاور حقوقی آفلاین (بدون نیاز به اینترنت یا مدل هوش مصنوعی). مشکل خود را شرح دهید تا با پرسش‌وپاسخ منطقی بررسی کنیم و در صورت نیاز دادخواست، لایحه یا شکوائیه برایتان تنظیم کنم.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// ردیف پیشنهادها بالای کادر نوشتن (مثل چت‌بات‌های امروزی).
///
/// هنگام نوشتن، پیشنهادهای متناسب با موضوع متن ([InputSuggestions]) و در غیر
/// این صورت گزینه‌های آخرین پاسخ دستیار را نشان می‌دهد. تا وقتی پاسخ در حال
/// نوشته‌شدن است پنهان می‌ماند.
class SuggestionBar extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final bool isDrafting;
  final List<ChatMessage> messages;
  final List<LegalTemplate> templates;
  final ValueChanged<String> onSelect;

  const SuggestionBar({
    super.key,
    required this.controller,
    required this.busy,
    required this.isDrafting,
    required this.messages,
    required this.templates,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (busy) return const SizedBox.shrink();
        final items = <InputSuggestion>[];
        final typed = value.text.trim();
        if (typed.isNotEmpty && !isDrafting) {
          items.addAll(InputSuggestions.forTyping(typed, templates: templates));
        } else if (typed.isEmpty && messages.isNotEmpty) {
          final last = messages.last;
          final settled = last.revealed ||
              last.isDoc ||
              MediaQuery.disableAnimationsOf(context);
          if (!last.fromUser && settled) {
            items.addAll(
              last.chips.map((c) => InputSuggestion(c, SuggestionKind.question)),
            );
          }
        }
        if (items.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 48,
          child: SingleChildScrollView(
            key: const ValueKey('suggestion-bar'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  ActionChip(
                    avatar: switch (items[i].kind) {
                      SuggestionKind.template =>
                        const Icon(Icons.description_outlined, size: 18),
                      SuggestionKind.counsel =>
                        const Icon(Icons.forum_outlined, size: 18),
                      SuggestionKind.question => null,
                    },
                    label: Text(items[i].text),
                    onPressed: () => onSelect(items[i].text),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// متن پاسخ دستیار که مثل نوشتن یک انسان، تدریجی نمایش داده می‌شود.
///
/// از [AnimationController] (نه Timer) استفاده می‌کند تا در آزمون‌ها با
/// `pumpAndSettle` به پایان برسد. اگر متن در حین نمایش تغییر کند (جریان
/// پاسخ)، از بخش مشترک قبلی ادامه می‌دهد.
class RevealText extends StatefulWidget {
  final ChatMessage message;
  final TextStyle style;
  final VoidCallback? onTick;
  final VoidCallback? onRevealed;

  /// زمان نمایش هر نویسه.
  static const int msPerChar = 12;
  static const int minMs = 150;
  static const int maxMs = 1800;

  const RevealText({
    super.key,
    required this.message,
    required this.style,
    this.onTick,
    this.onRevealed,
  });

  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  int _from = 0;
  String _text = '';
  bool _animatedHere = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    _text = widget.message.text;
    if (!widget.message.revealed) _start(0);
  }

  @override
  void didUpdateWidget(covariant RevealText old) {
    super.didUpdateWidget(old);
    final next = widget.message.text;
    if (next == _text) return;
    final shown = _visible();
    _text = next;
    if (widget.message.revealed && !_animatedHere) return;
    widget.message.revealed = false;
    _start(_commonPrefix(shown, next));
  }

  int _commonPrefix(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }

  void _start(int from) {
    if (_text == '...') {
      _anim.stop();
      return;
    }
    _from = from.clamp(0, _text.length);
    final remaining = _text.length - _from;
    if (remaining <= 0) {
      _finish();
      return;
    }
    final ms = (remaining * RevealText.msPerChar)
        .clamp(RevealText.minMs, RevealText.maxMs);
    _animatedHere = true;
    _anim.duration = Duration(milliseconds: ms);
    _anim.forward(from: 0);
  }

  void _onTick() {
    // فقط در گام‌های انیمیشن (نه در میانهٔ ساخت ویجت) فهرست را جابه‌جا کن.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.transientCallbacks) {
      widget.onTick?.call();
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (widget.message.revealed) return;
    widget.message.revealed = true;
    // ممکن است در میانهٔ ساخت ویجت باشیم؛ به‌روزرسانی به فریم بعد می‌رود.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      widget.onRevealed?.call();
    });
  }

  String _visible() {
    if (widget.message.revealed || _text == '...') return _text;
    final n = _from + ((_text.length - _from) * _anim.value).round();
    return _text.substring(0, n.clamp(0, _text.length));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_text == '...') return const TypingDots();
    if (widget.message.revealed || MediaQuery.disableAnimationsOf(context)) {
      if (!widget.message.revealed) _finish();
      return SelectableText(_text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Text(_visible(), style: widget.style),
    );
  }
}

/// سه نقطهٔ «در حال نوشتن…».
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'در حال نوشتن پاسخ',
      child: SizedBox(
        height: 30,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    opacity: 0.3 +
                        0.7 *
                            (1 - (((_c.value * 3) - i).abs().clamp(0.0, 1.0))),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
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
                      ? 'پاسخ فیلد پیش‌نویس را بنویسید...'
                      : (isCounseling
                          ? 'پاسخ خود را بنویسید یا از گزینه‌ها انتخاب کنید...'
                          : 'مشکل حقوقی یا پرسش خود را بنویسید...'),
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

part of 'chat_bubbles.dart';

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
    // بازسازی محلی لازم است تا بخش «ارتباط یا تعارض» بعد از تمامشدن نگارش
    // ظاهر شود؛ والد نیازی به بازسازی کل صفحه ندارد.
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
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.balance, size: 14, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 6),
                Text(
                  'دستیار',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
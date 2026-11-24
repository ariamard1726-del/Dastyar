part of 'chat_bubbles.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDrafting;
  final VoidCallback onSend;

  /// کپی کل گفتگو؛ `null` یعنی هنوز پیامی نیست و دکمه غیرفعال است.
  final VoidCallback? onCopyAll;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isDrafting,
    required this.onSend,
    this.onCopyAll,
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
                      : 'مشکل حقوقی یا پرسش خود را بنویسید...',
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  tooltip: 'ارسال پیام',
                  onPressed: onSend,
                  icon: const Icon(Icons.arrow_upward),
                ),
                const SizedBox(height: 4),
                // کپی کل گفتگو: زیر دکمهٔ ارسال. تا وقتی پیامی نیست غیرفعال است.
                IconButton.filledTonal(
                  tooltip: 'کپی کل گفتگو',
                  onPressed: onCopyAll,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  iconSize: 18,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

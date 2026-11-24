part of 'chat_bubbles.dart';

class SuggestionBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDrafting;
  final List<ChatMessage> messages;
  final List<LegalTemplate> templates;
  final ValueChanged<String> onSelect;

  const SuggestionBar({
    super.key,
    required this.controller,
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

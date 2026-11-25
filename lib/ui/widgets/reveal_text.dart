part of 'chat_bubbles.dart';

/// پاسخ کامل را همان لحظه نشان میدهد.
///
/// نمایش نویسه/واژهبهواژه (با `AnimationController` و `setState` در هر گام)
/// حذف شد: روی پاسخهای بلند تا ۶ ثانیه، ۶۰ بار در ثانیه کل `SelectableText`
/// دوباره ساخته میشد و فهرست گفتگو را بهزحمت میانداخت. تنها حالت جدا مانده،
/// علامت «در حال نوشتن…» [`TypingDots`] برای پیامِ در انتظار (`...`) است که
/// پیش از آمدن پاسخ واقعی دیده میشود.
class RevealText extends StatefulWidget {
  final ChatMessage message;
  final TextStyle style;

  /// یکبار، پس از نامشخص شدن متنِ در انتظار (`...`) صدا زده میشود.
  final VoidCallback? onRevealed;

  const RevealText({
    super.key,
    required this.message,
    required this.style,
    this.onRevealed,
  });

  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText> {
  late String _text;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _text = widget.message.text;
    _settle();
  }

  @override
  void didUpdateWidget(covariant RevealText old) {
    super.didUpdateWidget(old);
    if (widget.message.text == _text) return;
    _text = widget.message.text;
    _settle();
  }

  /// پیامِ بازیافته از تاریخچه و پیامِ تمامشده نیازی به اعلام دوباره ندارند.
  void _settle() {
    if (_text == '...') return;
    widget.message.revealed = true;
    if (_announced) return;
    _announced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRevealed?.call();
    });
  }

  @override
  Widget build(BuildContext context) => _text == '...'
      ? const TypingDots()
      : SelectableText(_text, style: widget.style);
}

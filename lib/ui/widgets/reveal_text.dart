part of 'chat_bubbles.dart';

class RevealText extends StatefulWidget {
  final ChatMessage message;
  final TextStyle style;
  final VoidCallback? onTick;
  final VoidCallback? onRevealed;

  /// زمان نمایش هر نویسه: آهنگ نوشتنِ آرام و طبیعی، نه ظاهرشدنِ یک‌بارهٔ متن.
  static const int msPerChar = 18;
  static const int minMs = 250;

  /// پس از این تعداد نویسه، نگارش کمی تندتر می‌شود.
  static const int slowChars = 400;
  static const int msPerCharLong = 10;

  /// سقف زمان نگارشِ پاسخ‌های خیلی بلند (با یک لمس هم می‌شود ردش کرد).
  static const int maxMs = 24000;

  /// مکث کوتاهِ «در حال فکر کردن» پیش از شروع نگارش پاسخ‌های غیرکوتاه.
  static const int thinkMs = 500;

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

  /// آخرین متنی که واقعاً نمایش داده شده و آخرین حالت «در حال فکر کردن».
  ///
  /// بازسازی ویجت فقط وقتی رخ می‌دهد که یکی از این دو عوض شود. پیش‌تر
  /// `AnimatedBuilder` در هر فریم (۶۰ بار در ثانیه، تا ۲۴ ثانیه برای پاسخ
  /// بلند) یک `SelectableText` تازه می‌ساخت و متنِ در حال رشد را از نو
  /// می‌چید.
  String _shown = '';
  bool _thinkingShown = false;

  /// سهم مکثِ آغازین از کل زمان انیمیشن (۰ تا ۱).
  double _thinkShare = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    _text = widget.message.text;
    _shown = _text;
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
    _shown = _text.substring(0, _from);
    _thinkingShown = false;
    final remaining = _text.length - _from;
    if (remaining <= 0) {
      _finish();
      return;
    }
    // آغاز پاسخ آرام نوشته می‌شود و ادامهٔ پاسخ‌های بلند کمی روان‌تر، تا
    // هم حس نوشتن طبیعی بماند و هم کاربر برای متن بلند معطل نشود.
    final slow = remaining < RevealText.slowChars
        ? remaining
        : RevealText.slowChars;
    final ms = (slow * RevealText.msPerChar +
            (remaining - slow) * RevealText.msPerCharLong)
        .clamp(RevealText.minMs, RevealText.maxMs);
    final think = _from == 0 && remaining > 60 ? RevealText.thinkMs : 0;
    _thinkShare = think / (think + ms);
    _animatedHere = true;
    _anim.duration = Duration(milliseconds: think + ms);
    _anim.forward(from: 0);
    // حالت «در حال فکر کردن» از همان فریم اول درست نشان داده شود.
    _thinkingShown = _thinking;
  }

  /// با لمس متن، نگارش تدریجی رد می‌شود و کل پاسخ یک‌جا می‌آید.
  void _skip() {
    if (widget.message.revealed) return;
    _anim.stop();
    // اینجا در پاسخ به لمس هستیم (نه میانهٔ ساخت)، پس همین حالا بازسازی
    // می‌کنیم؛ با ایستادن انیمیشن دیگر فریمی در راه نیست که منتظرش بمانیم.
    widget.message.revealed = true;
    setState(() {});
    widget.onRevealed?.call();
  }

  bool get _thinking =>
      !widget.message.revealed && _thinkShare > 0 && _anim.value < _thinkShare;

  void _onTick() {
    // فقط در گام‌های انیمیشن (نه در میانهٔ ساخت ویجت) فهرست را جابه‌جا کن.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.transientCallbacks) {
      widget.onTick?.call();
    }
    if (!mounted || widget.message.revealed) return;
    final visible = _visible();
    final thinking = _thinking;
    if (visible == _shown && thinking == _thinkingShown) return;
    setState(() {
      _shown = visible;
      _thinkingShown = thinking;
    });
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
    final t = _thinkShare >= 1
        ? 1.0
        : ((_anim.value - _thinkShare) / (1 - _thinkShare)).clamp(0.0, 1.0);
    var n = (_from + ((_text.length - _from) * t).round())
        .clamp(0, _text.length);
    // واژه‌ها کامل ظاهر می‌شوند، نه حرف‌به‌حرف وسط یک کلمه.
    if (n < _text.length) {
      final space = _text.lastIndexOf(' ', n);
      final line = _text.lastIndexOf('\n', n);
      final edge = space > line ? space : line;
      if (edge > _from) n = edge;
    }
    return _text.substring(0, n);
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: _thinkingShown
          ? const TypingDots()
          // SelectableText تا در حین نمایش هم بشود متن را با نگه‌داشتن کپی کرد.
          : SelectableText('$_shown ●', style: widget.style),
    );
  }
}

/// سه نقطهٔ «در حال نوشتن…».

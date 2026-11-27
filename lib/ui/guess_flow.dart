import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:dastyar/ui/chat_models.dart';

/// نتیجهٔ یک نوبتِ خواندن پیام با مدل روی گوشی.
class GuessResult {
  const GuessResult({this.guess, this.shown = false, this.stale = false});

  final TopicGuess? guess;

  /// پیام کاربر همین حالا در گفتگو اضافه شده است (پیش از صبر برای مدل).
  final bool shown;

  /// در فاصلهٔ صبر، صفحه بسته شده یا گفتگوی دیگری باز شده است.
  final bool stale;
}

/// جریانِ حدسِ موضوع با مدل ([guesser]) — تنها وقتی که قاعده‌ها موضوع را نشناسند.
///
/// تا زمان آمدنِ حدس، پیام کاربر را بلافاصله نمایش می‌دهد، پرچم [thinking] را
/// روشن می‌کند، خطای مدل را به لیست مشکلات می‌سپارد و اگر در میانهٔ انتظار
/// گفتگوی تازه باز شد، نتیجهٔ کهنه را کنار می‌گذارد.
class GuessFlow {
  GuessFlow({
    required this.advocate,
    required this.guesser,
    required this.post,
    required this.changed,
    required this.scrollToEnd,
    required this.isAlive,
    required this.onProblem,
  });

  final Advocate advocate;
  final Future<TopicGuess?> Function(String text)? guesser;
  final void Function(ChatMessage) post;
  final void Function() changed;
  final void Function() scrollToEnd;
  final bool Function() isAlive;
  final void Function(String) onProblem;

  /// در حال خواندن پیام با مدل هستم (برای نشان‌دادن در صفحه).
  bool thinking = false;

  /// آخرین حدسِ مدل، برای صفحهٔ «درباره».
  TopicGuess? lastGuess;

  void reset() {
    thinking = false;
  }

  /// اگر قاعده‌ها هنوز موضوع را نشناخته و [guesser] حاضر باشد، جمله را
  /// می‌خواند؛ وگرنه بلافاصله بدون نمایش یا صبر برمی‌گردد.
  Future<GuessResult> read(
    String text, {
    required bool Function() isCurrent,
  }) async {
    final fn = guesser;
    if (fn == null || !advocate.wantsGuess(text)) {
      return const GuessResult();
    }
    // خواندن جمله با مدل روی گوشی کمی طول می‌کشد؛ پیام کاربر همان لحظه
    // نشان داده می‌شود و جواب بعد از آن می‌آید.
    post(ChatMessage(text, true));
    thinking = true;
    changed();
    scrollToEnd();
    TopicGuess? guess;
    try {
      guess = await fn(text);
    } catch (e) {
      onProblem('خواندن موضوع: $e');
      guess = null;
    }
    thinking = false;
    if (!isAlive()) return const GuessResult(shown: true, stale: true);
    if (!isCurrent()) {
      // در این فاصله گفتگو عوض شده است؛ این پیام دیگر جایی ندارد.
      changed();
      return const GuessResult(shown: true, stale: true);
    }
    lastGuess = guess ?? lastGuess;
    return GuessResult(guess: guess, shown: true);
  }
}

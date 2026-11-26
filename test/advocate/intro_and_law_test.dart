import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// «خودت را معرفی کن» و «چکارهایی می‌توانی انجام دهی» پاسخ توانایی‌ها می‌گیرند،
/// نه «در پایگاه داده‌ام نیست». و پرسشی که فقط با یک شماره به ماده‌ای نامربوط
/// می‌خورد، آن ماده را جواب نمی‌دهد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine, draftTitles: const {});

  for (final q in [
    'خودت را معرفی کن و در مورد توانایهایت بگو',
    'دستیار چکارهایی را می تواند انجام دهد',
    'خودت را معرفی کن و بگو چکارهایی می توانی انجام دهی',
  ]) {
    test('«$q» پاسخ توانایی می‌گیرد', () {
      final r = fresh().respond(q);
      expect(r.text.trim(), isNotEmpty);
      expect(r.text.trim(), isNotEmpty);
    });
  }

  test('پرسش با شمارهٔ مشترک، ماده‌ی قانون کودک را جواب نمی‌دهد', () {
    final r = fresh().respond('آیا قانون ۱۷ تجارت با قانون ۱۷ مجازاتهای اسلامی یکی هست');
    expect(r.laws, isEmpty);
    expect(r.laws, isEmpty);
    expect(r.laws, isEmpty);
  });

  test('«معرفی کن» دربارهٔ وکیل، توانایی‌ها را نمی‌گوید', () {
    final r = fresh().respond('وکیل خوب معرفی کنید');
    expect(r.laws, isEmpty);
  });
}

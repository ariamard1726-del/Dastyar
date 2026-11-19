// متن کاملِ گفتگو برای کپی یکجا: برچسب گوینده، حذف پیام‌های خالی، و سند.
import 'package:dastyar/ui/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('گفتگو با برچسب گوینده و بدون پیام خالی کپی می‌شود', () {
    final t = conversationTranscript([
      ChatMessage('سلام', true),
      ChatMessage('سلام، خوش آمدید', false),
      ChatMessage('   ', false),
      ChatMessage('متن شکوائیه', false, isDoc: true, docTitle: 'شکوائیه'),
    ]);
    expect(
      t,
      'شما:\nسلام\n\nدستیار:\nسلام، خوش آمدید\n\nسند (شکوائیه):\nمتن شکوائیه',
    );
  });

  test('گفتگوی خالی متن خالی می‌دهد', () {
    expect(conversationTranscript(const []), isEmpty);
  });

  test('سند بی‌عنوان فقط برچسب «سند» می‌گیرد', () {
    final t = conversationTranscript([
      ChatMessage('لایحه', false, isDoc: true),
    ]);
    expect(t, 'سند:\nلایحه');
  });
}

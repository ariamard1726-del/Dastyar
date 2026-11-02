import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/ui/widgets/chat_bubbles.dart';

void main() {
  group('مأموریت ۷: نوار ChoiceChip و صفحهٔ آغازین مینیمال', () {
    testWidgets('ChatChipsBar گزینه‌ها را کوچک و افقی اسکرول‌پذیر نشان می‌دهد',
        (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                children: [
                  ChatChipsBar(
                    busy: false,
                    suggestions: const [
                      ChatSuggestion('شکوائیه چک', 'شکوائیه چک برگشتی (شکایت کیفری)'),
                      ChatSuggestion('درخواست اجرائیه', 'درخواست صدور اجرائیه چک'),
                      ChatSuggestion('مشاوره', 'مشاورهٔ حقوقی گام‌به‌گام'),
                    ],
                    onSelectChip: picked.add,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(find.byType(ActionChip), findsNothing);
      final sv = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(sv.scrollDirection, Axis.horizontal);

      await tester.tap(find.text('درخواست اجرائیه'));
      await tester.pump();
      // مقدار فرستاده‌شده عنوان کامل قالب است، نه برچسب کوتاه.
      expect(picked, ['درخواست صدور اجرائیه چک']);
    });

    testWidgets('وقتی مشغول یا بدون گزینه است نوار پنهان می‌شود', (tester) async {
      for (final busy in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: ChatChipsBar(
                  busy: busy,
                  suggestions: const [],
                  onSelectChip: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(find.byType(ChoiceChip), findsNothing);
      }
    });

    testWidgets('ChatEmptyState فقط خوش‌آمدگویی دارد، بدون دکمه یا قالب',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ChatEmptyState()),
          ),
        ),
      );

      expect(find.text('سلام، چه کمکی از من برمی‌آید؟'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('شکوائیه'), findsNothing);
      expect(find.textContaining('لایحه'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/ui/widgets/chat_bubbles.dart';

void main() {
  group('حباب پیام دستیار: کادر ارتباط یا تعارض مواد', () {
    testWidgets('BotMessageView کادر ارتباط یا تعارض مواد را نمایش می‌دهد',
        (tester) async {
      final msg = ChatMessage(
        'متن آزمایشی ماده ۱۰۱',
        false,
        conflictChains: const ['۱۰۱ -> ۱۰۵ -> ۱۰۸ -> ۱۰۹'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BotMessageView(
                message: msg,
                question: 'ماده ۱۰۱ قانون مدنی',
                onCopy: (_) {},
                onShare: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ارتباط یا تعارض ثبت‌شدهٔ مواد:'), findsOneWidget);
      expect(find.textContaining('۱۰۱ ← ۱۰۵ ← ۱۰۸ ← ۱۰۹'), findsOneWidget);
    });
  });

  group('نمایش تدریجی پاسخ و ردیف پیشنهادها', () {
    Widget host(Widget child, {bool noAnim = false}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: noAnim),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: child),
            ),
          ),
        );

    testWidgets('پاسخ یکباره نمی‌آید و در پایان کامل و قابل انتخاب است',
        (tester) async {
      const full = 'این یک پاسخ نسبتاً بلند برای آزمودن نمایش تدریجی متن است.';
      final msg = ChatMessage(full, false);
      var done = 0;
      await tester.pumpWidget(host(BotMessageView(
        message: msg,
        question: 'پرسش',
        onCopy: (_) {},
        onShare: (_) {},
        onRevealed: () => done++,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(full), findsNothing);
      expect(msg.revealed, isFalse);
      await tester.pumpAndSettle();
      expect(msg.revealed, isTrue);
      expect(done, 1);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text(full), findsOneWidget);
    });

    testWidgets('پیام بازیابی‌شده از تاریخچه دوباره تایپ نمی‌شود',
        (tester) async {
      final msg = ChatMessage('متن قدیمی', false, revealed: true);
      await tester.pumpWidget(host(BotMessageView(
        message: msg,
        question: '',
        onCopy: (_) {},
        onShare: (_) {},
      )));
      expect(find.text('متن قدیمی'), findsOneWidget);
    });

    testWidgets('با خاموش بودن انیمیشن‌ها متن فوراً کامل نمایش داده می‌شود',
        (tester) async {
      final msg = ChatMessage('متن فوری', false);
      await tester.pumpWidget(host(
        BotMessageView(
          message: msg,
          question: '',
          onCopy: (_) {},
          onShare: (_) {},
        ),
        noAnim: true,
      ));
      expect(find.text('متن فوری'), findsOneWidget);
    });

    testWidgets('هنگام انتظار، نشانگر «در حال نوشتن» دیده می‌شود',
        (tester) async {
      final msg = ChatMessage('...', false);
      await tester.pumpWidget(host(BotMessageView(
        message: msg,
        question: '',
        onCopy: (_) {},
        onShare: (_) {},
      )));
      expect(find.byType(TypingDots), findsOneWidget);
      expect(find.text('...'), findsNothing);
    });

    testWidgets('صفحهٔ آغازین فقط معرفی دارد و دکمه ندارد', (tester) async {
      await tester.pumpWidget(host(const ChatEmptyState()));
      expect(find.text('سلام، چه کمکی از من برمی‌آید؟'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    testWidgets('ردیف پیشنهاد هنگام نوشتن متناسب با موضوع پر می‌شود',
        (tester) async {
      final ctrl = TextEditingController();
      String? picked;
      await tester.pumpWidget(host(SuggestionBar(
        controller: ctrl,
        busy: false,
        isDrafting: false,
        messages: const [],
        templates: const [],
        onSelect: (s) => picked = s,
      )));
      expect(find.byType(ActionChip), findsNothing);
      ctrl.text = 'مهریه';
      await tester.pump();
      expect(find.text('مهریه را چطور بگیرم؟'), findsOneWidget);
      await tester.tap(find.text('مهریه را چطور بگیرم؟'));
      expect(picked, 'مهریه را چطور بگیرم؟');
      ctrl.clear();
      await tester.pump();
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('گزینه‌های پاسخ فقط پس از پایان نوشتن پاسخ نمایش داده می‌شوند',
        (tester) async {
      final ctrl = TextEditingController();
      final bot = ChatMessage('پاسخ', false, chips: const ['گزینهٔ یک']);
      Widget bar() => host(SuggestionBar(
            controller: ctrl,
            busy: false,
            isDrafting: false,
            messages: [bot],
            templates: const [],
            onSelect: (_) {},
          ));
      await tester.pumpWidget(bar());
      expect(find.text('گزینهٔ یک'), findsNothing);
      bot.revealed = true;
      await tester.pumpWidget(bar());
      expect(find.text('گزینهٔ یک'), findsOneWidget);
    });
  });
}

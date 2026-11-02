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

      expect(find.text('ارتباط یا تعارض ثبت‌شدهٔ مواد:'), findsOneWidget);
      expect(find.textContaining('۱۰۱ ← ۱۰۵ ← ۱۰۸ ← ۱۰۹'), findsOneWidget);
    });
  });
}

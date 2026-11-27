// همهٔ آزمون‌ها پیش از اجرا راهنماهای آماده را نصب می‌کنند.
//
// داده از `legal_guides.dart` به `assets/brain/guides/legal_guides.json` رفت و
// حالا نصبِ صریح لازم دارد. اگر این کار را این‌جا نکنیم، هر آزمونی که به
// `LawyerVoice` یا انتخابِ راهنما وابسته است با فهرستِ خالی می‌سنجد و بی‌صدا
// چیزِ دیگری را تأیید می‌کند.
import 'dart:async';

import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/lawyer/legal_guides_loader.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadLegalGuides();
  if (!legalGuidesLoaded) {
    throw StateError('راهنماها در آزمون نصب نشدند');
  }
  await testMain();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// موقت: متنِ واقعیِ پاسخ برای سناریوی «لاکپشت بنفش دارم» را در پیامِ شکست
/// می‌آورد تا در آنوتیشن CI دیده شود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('debug unclear', () async {
    final engine = KnowledgeEngine();
    await engine.load();
    final a = Advocate(engine, draftTitles: const {});
    final r = a.respond('لاکپشت بنفش دارم');
    final shown = r.text.replaceAll('\n', ' ⏎ ');
    fail('REPLY>>> ${shown.length > 240 ? shown.substring(0, 240) : shown}');
  });
}

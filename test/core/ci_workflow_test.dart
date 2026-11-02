import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('مأموریت ۶: خطاهای CI بی‌صدا نمانند', () {
    test('jobِ commit-reports هیچ خطایی را پنهان نمی‌کند', () {
      final yml = File('.github/workflows/test.yml').readAsStringSync();
      final start = yml.indexOf('  commit-reports:');
      expect(start, greaterThanOrEqualTo(0),
          reason: 'jobِ commit-reports در workflow وجود ندارد');
      final section = yml.substring(start);

      expect(section.contains('|| true'), isFalse,
          reason: '|| true خطاها را بی‌صدا می‌کند');
      expect(section.contains('continue-on-error: true'), isFalse,
          reason: 'continue-on-error شکست step را پنهان می‌کند');
      expect(section.contains('2>/dev/null'), isFalse,
          reason: 'خطای git add نباید دور ریخته شود');
      expect(section.contains('set -euo pipefail'), isTrue);
      expect(section.contains('git pull --rebase\n'), isTrue);
      expect(section.contains('git push origin HEAD:'), isTrue);
    });

    test('jobِ test همچنان در صورت شکست هر مرحله قرمز می‌شود', () {
      final yml = File('.github/workflows/test.yml').readAsStringSync();
      expect(yml.contains('Fail if anything failed'), isTrue);
      expect(yml.contains('steps.ft.outcome == \'failure\''), isTrue);
      expect(yml.contains('steps.analyze.outcome == \'failure\''), isTrue);
      expect(yml.contains('steps.data.outcome == \'failure\''), isTrue);
    });
  });
}

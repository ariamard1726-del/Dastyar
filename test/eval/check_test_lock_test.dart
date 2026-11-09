import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  group('Check Test Lock', () {
    test('Manifest check passes when empty', () {
      ProcessResult result = Process.runSync(
        'dart',
        ['run', 'tool/eval/check_test_lock.dart'],
        workingDirectory: Platform.script.uri.toFilePath().split('/').sublist(0, -3).join('/'),
      );
      // Since eval/scenarios_test/ is empty, manifest will be TOTAL_SIZE:0
      // If manifest.sha256 doesn't exist, it fails. Let's create it first.
      File(Platform.script.uri.toFilePath().split('/').sublist(0, -3).join('/') + '/eval/test_manifest.sha256').writeAsStringSync('TOTAL_SIZE:0\n');
      ProcessResult result2 = Process.runSync(
        'dart',
        ['run', 'tool/eval/check_test_lock.dart'],
        workingDirectory: Platform.script.uri.toFilePath().split('/').sublist(0, -3).join('/'),
      );
      expect(result2.exitCode, equals(0));
    });
  });
}

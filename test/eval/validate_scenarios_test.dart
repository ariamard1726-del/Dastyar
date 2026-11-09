import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  group('Validate Scenarios', () {
    test('Validator runs and passes on seed files', () {
      ProcessResult result = Process.runSync(
        'dart',
        ['run', 'tool/eval/validate_scenarios.dart'],
        workingDirectory: Platform.script.uri.toFilePath().split('/').sublist(0, -3).join('/'), // /home/user/Dastyar
      );
      expect(result.exitCode, equals(0), 'Validator failed: ${result.stderr}');
      expect(result.stdout, contains('VALIDATION PASSED'));
    });
  });
}

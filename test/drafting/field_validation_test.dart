import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  group('اعتبارسنجی فیلدهای کد ملی و تلفن در جریان تهیهٔ متن', () {
    test('فیلدهای phone و national_id در DraftStep.answer اعتبارسنجی می‌شوند', () {
      final customTpl = LegalTemplate(
        id: 'verify_fields',
        title: 'آزمون اعتبارسنجی',
        description: '',
        version: 1,
        reviewed: true,
        reviewNote: '',
        tips: const [],
        keywords: const [],
        fields: [
          TemplateField(
            id: 'nid',
            label: 'کد ملی',
            type: 'national_id',
            required: true,
            hint: '',
            options: const [],
          ),
          TemplateField(
            id: 'tel',
            label: 'شماره همراه',
            type: 'phone',
            required: false,
            hint: '',
            options: const [],
          ),
        ],
        lawRefs: const [],
        body: 'کد ملی: {{nid}} - تلفن: {{tel}}',
      );

      final s = DraftSession(customTpl);
      final badNid = DraftStep.answer(s, '1111111111');
      expect(badNid.isDocument, isFalse);
      expect(s.index, 0);

      final okNid = DraftStep.answer(s, '0013542419');
      expect(okNid.isDocument, isFalse);
      expect(s.values['nid'], '۰۰۱۳۵۴۲۴۱۹');

      final badPhone = DraftStep.answer(s, 'abc123');
      expect(badPhone.isDocument, isFalse);

      final doc = DraftStep.answer(s, '+989123456789');
      expect(doc.isDocument, isTrue);
      expect(s.values['nid'], '۰۰۱۳۵۴۲۴۱۹');
      expect(s.values['tel'], '۰۹۱۲۳۴۵۶۷۸۹');
    });
  });
}

"""نگهبانی ساده تا باز کردن payload قدیمی دوباره از List<int>بهعنوان TypedData نکند.

`base64Decode` در Dart یک `List<int>` معمولی میدهد، ولی `Uint8List.sublistView`
فقط `TypedData` میپذیرد. این اشتباه در CI با خطای
`argument_type_not_assignable` تمام آزمونهای Dart را قرمز کرد.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'lib' / 'core' / 'privacy.dart').read_text(encoding='utf-8')


class PrivacyMigrationShapeTests(unittest.TestCase):
    def test_decoded_payload_is_converted_to_typed_data(self):
        start = SOURCE.index('static String? _openWithKey(')
        end = SOURCE.index('static Future<String?> _fallbackOpen(', start)
        body = SOURCE[start:end]
        self.assertIn('Uint8List.fromList(raw)', body)
        self.assertNotIn('Uint8List.sublistView(raw,', body)


if __name__ == '__main__':
    unittest.main()

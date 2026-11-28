"""نگهبان فاز ۸: مسیر غیرهمگام موتور، ماشین حالت ایمنی، نسخه‌بندی ذخیره‌ها و دامنهٔ بی‌فلاتر."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def _read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


class Phase8RuntimeAndLayersTests(unittest.TestCase):
    def test_guide_and_terms_use_async_worker_path(self):
        engine_src = _read('lib/core/engine.dart')
        worker_src = _read('lib/core/engine_worker.dart')
        guide_src = _read('lib/domain/advocate/guide_reply.dart')
        term_src = _read('lib/domain/advocate/term_reply.dart')
        flow_src = _read('lib/ui/reply_flow.dart')

        self.assertIn('prepareWith<', engine_src)
        self.assertIn("case 'fn':", worker_src)
        self.assertIn('this.prepared', guide_src)
        self.assertIn('prepared?.call(', guide_src)
        self.assertIn('this.preparedMatch', term_src)
        self.assertIn('preparedMatch?.call(', term_src)
        self.assertIn('wantsTermMatch(', flow_src)
        self.assertIn('prepareWith', flow_src)

    def test_safety_state_machine_tracks_severity_and_window(self):
        sections = _read('lib/domain/advocate/dialogue_sections.dart')
        safety = _read('lib/domain/advocate/safety_reply.dart')
        guard = _read('lib/domain/advocate/advocate_reply_guard.dart')

        self.assertIn('enum SafetySeverity', sections)
        self.assertIn('lastSafetyTurn', sections)
        self.assertIn('safetySeverity', sections)
        self.assertIn('SafetySeverity severityOf(', safety)
        self.assertIn('bool acknowledgesSafe(', safety)
        self.assertIn('acknowledgesSafe(', guard)

    def test_draft_and_feedback_payloads_have_schema_version(self):
        draft = _read('lib/domain/draft_models.dart')
        feedback = _read('lib/domain/feedback.dart')

        self.assertIn('static const int schemaVersion', draft)
        self.assertIn("'schemaVersion': schemaVersion", draft)
        self.assertIn('static const int schemaVersion', feedback)
        self.assertIn("'entries':", feedback)

    def test_domain_layer_has_zero_flutter_allowlist_exceptions(self):
        arch = _read('tests/python/test_architecture.py')
        self.assertIn('DOMAIN_FLUTTER_ALLOWLIST = set()', arch)
        self.assertFalse((ROOT / 'lib/domain/settings.dart').exists())
        self.assertTrue((ROOT / 'lib/ui/app_settings.dart').is_file())


if __name__ == '__main__':
    unittest.main()

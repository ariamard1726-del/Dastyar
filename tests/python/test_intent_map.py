"""نگهبان نگاشت IntentNet به موضوع‌های وکیل (هم‌راستا با test/advocate/intent_map_test.dart)."""
import json
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _net_topics():
    src = open(os.path.join(ROOT, 'lib/domain/advocate/advocate.dart'), encoding='utf-8').read()
    block = re.search(r'netTopics = \{(.*?)\};', src, re.S).group(1)
    return dict(re.findall(r"'([a-z_]+)':\s*'([a-z_]+)'", block))


def _topic_ids():
    ids = set()
    d = os.path.join(ROOT, 'lib/domain/advocate/topics')
    for name in os.listdir(d):
        if name.endswith('.dart'):
            text = open(os.path.join(d, name), encoding='utf-8').read()
            ids.update(re.findall(r"^\s{2}id: '([a-z_]+)'", text, re.M))
    return ids


class IntentMapTest(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(ROOT, 'assets/brain/intent_model.json'), encoding='utf-8') as f:
            self.labels = set(json.load(f)['labels'])
        self.mapping = _net_topics()

    def test_mapping_is_not_empty(self):
        self.assertGreaterEqual(len(self.mapping), 5)

    def test_every_target_is_a_real_topic(self):
        ids = _topic_ids()
        self.assertTrue(ids, 'هیچ شناسهٔ موضوعی پیدا نشد')
        for label, topic in self.mapping.items():
            self.assertIn(topic, ids, f'{label} -> {topic}')

    def test_every_source_is_a_real_label(self):
        for label in self.mapping:
            self.assertIn(label, self.labels)


if __name__ == '__main__':
    unittest.main()

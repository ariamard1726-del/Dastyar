import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/dialogue_state.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';
import 'package:dastyar/domain/advocate/reply_voice.dart';
import 'package:dastyar/domain/advocate/topic_flow.dart';

class _FakeTopicEngine extends KnowledgeEngine {
  _FakeTopicEngine(this._flows);

  final List<Map<String, dynamic>> _flows;

  @override
  List<Map<String, dynamic>> get topicFlows => _flows;
}

/// همتای tests/python/test_topic_flow.py: مسیر تصمیم چک در دارت باید با
/// پایتون یکسان باشد (همان نمونه‌ها، همان برگ‌ها).
void main() {
  final flow = jsonDecode(File('assets/brain/topics/cheque.json').readAsStringSync())
      as Map<String, dynamic>;

  test('همهٔ موضوعات: نمونه‌های توسعه همه درست‌اند', () {
    final index = jsonDecode(File('assets/brain/topics/index.json').readAsStringSync())
        as Map<String, dynamic>;
    for (final name in (index['topics'] as List).cast<String>()) {
      final topic = jsonDecode(File('assets/brain/topics/$name').readAsStringSync())
          as Map<String, dynamic>;
      final stem = name.replaceAll('.json', '');
      final gold = (jsonDecode(File('tests/topics/${stem}_gold.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      final bad = [
        for (final g in gold)
          if (TopicFlow.route(topic, g['q'] as String) != g['leaf']) '[$stem] ${g['q']}',
      ];
      expect(bad, isEmpty, reason: bad.join(' | '));
    }
  });

  test('تشخیص پیام دربارهٔ چک', () {
    expect(TopicFlow.mentionsCheque('چکم برگشت خورده'), isTrue);
    expect(TopicFlow.mentionsCheque('چک من'), isTrue);
    expect(TopicFlow.mentionsCheque('سلام'), isFalse);
    expect(TopicFlow.mentionsCheque('کفیل شدم'), isFalse);
  });

  test('پاسخ برگ دارنده شامل مادهٔ ۴ و ۱۱ و ۲۳ است', () {
    expect(TopicFlow.route(flow, 'چکم برگشت خورد'), 'returned_holder');
    final leaves = flow['leaves'] as Map<String, dynamic>;
    final refs = [for (final a in (leaves['returned_holder']['articles'] as List)) a['title']];
    expect(refs, containsAll(['ماده 4', 'ماده 11', 'ماده 23']));
  });

  test('دادهٔ ناقص یا بدشکل در جریان موضوعی بدون کرش به ask می‌رود', () {
    expect(TopicFlow.route(<String, dynamic>{}, 'چکم برگشت خورد'), 'ask');
    expect(
      TopicFlow.route(<String, dynamic>{
        'gate': <Object?>[123, null],
        'rules': <Object?>[
          'bad',
          <String, Object?>{'any': <Object?>['چک']},
          <String, Object?>{'any': <Object?>[42], 'leaf': 'x'},
          <String, Object?>{'all_groups': <Object?>['bad'], 'leaf': 'x'},
        ],
      }, 'چکم برگشت خورد'),
      'ask',
    );
  });

  test('مواد بدشکل در برگ موضوعی بدون کرش نادیده گرفته می‌شوند', () {
    final engine = _FakeTopicEngine(<Map<String, dynamic>>[
      <String, dynamic>{
        'live': true,
        'gate': <String>['چک'],
        'rules': <Map<String, dynamic>>[
          <String, dynamic>{
            'any': <String>['برگشت'],
            'leaf': 'leaf_a',
          },
        ],
        'leaves': <String, dynamic>{
          'leaf_a': <String, dynamic>{
            'title': 'عنوان',
            'text': 'متن',
            'articles': <Object?>[
              'bad',
              null,
              <String, Object?>{'law': 'none'},
            ],
          },
        },
        'disclaimer': '',
      },
    ]);
    final file = CaseFile();
    final dialog = DialogueState();
    final voice = ReplyVoice(
      engine: engine,
      file: file,
      unresolved: <String>[],
    );
    final termReply = TermReply(
      file: file,
      dialog: dialog,
      voice: voice,
      engine: engine,
      terms: LawTerms(engine),
    );
    final reply = termReply.topicFlow('چکم برگشت خورد', 'چکم برگشت خورد');
    if (reply == null) {
      fail('expected topicFlow reply');
    }
    expect(reply.source, AnswerSource.topicFlow);
    expect(reply.laws, isEmpty);
  });
}

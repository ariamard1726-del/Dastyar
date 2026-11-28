import 'dart:convert';

import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/all.dart';
import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTopicTexts();
    await loadRentTexts();
  });

  test('همهٔ ۲۴ موضوع چرخهٔ کامل toJson -> Topic.fromJson را بی‌اتلاف می‌گذرانند', () {
    expect(allTopics.length, 24);
    for (final original in allTopics) {
      final raw = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final rebuilt = Topic.fromJson(raw);
      expect(rebuilt.isDeclarative, isTrue, reason: original.id);
      expect(
        jsonEncode(rebuilt.toJson()),
        jsonEncode(raw),
        reason: '${original.id} بعد از Topic.fromJson تغییر کرد',
      );
    }
  });

  test('موضوع‌های بازسازی‌شده از JSON همان رفتار runtime را تولید می‌کنند', () {
    final sampleFacts = <String, CaseFile>{
      'cheque': CaseFile()
        ..facts['role'] = 'holder'
        ..facts['amount'] = '50000000'
        ..facts['cert'] = 'yes'
        ..facts['kind'] = 'day'
        ..facts['since'] = '10',
      'family': CaseFile()
        ..facts['role'] = 'wife'
        ..facts['violence'] = 'yes'
        ..facts['childAge'] = '4'
        ..facts['coins'] = '110',
      'labor': CaseFile()
        ..facts['event'] = 'fired'
        ..facts['fired'] = 'yes'
        ..facts['insured'] = 'no'
        ..facts['contract'] = 'yes'
        ..facts['months'] = '14'
        ..facts['salary'] = '20000000',
      'rent': CaseFile()
        ..facts['role'] = 'tenant'
        ..facts['matter'] = 'deposit'
        ..facts['ended'] = 'yes'
        ..facts['vacated'] = 'yes'
        ..facts['contract'] = 'no'
        ..facts['amount'] = '200000000',
    };

    for (final original in allTopics) {
      final raw = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final rebuilt = Topic.fromJson(raw);
      final cf = sampleFacts[original.id] ?? CaseFile();

      expect(rebuilt.opening(cf), original.opening(cf), reason: original.id);
      expect(rebuilt.follow.keys, original.follow.keys, reason: original.id);
      for (final k in original.follow.keys) {
        expect(rebuilt.follow[k]!(cf), original.follow[k]!(cf),
            reason: '${original.id}.follow[$k]');
      }
      if (original.recap != null) {
        expect(rebuilt.recap!(cf), original.recap!(cf), reason: original.id);
      }
      if (original.drafts != null) {
        expect(rebuilt.drafts!(cf), original.drafts!(cf), reason: original.id);
      }
      if (original.petition != null) {
        expect(rebuilt.petition!(cf)?.template, original.petition!(cf)?.template,
            reason: original.id);
        expect(rebuilt.petition!(cf)?.chip, original.petition!(cf)?.chip,
            reason: original.id);
      }
      if (original.brief != null) {
        expect(rebuilt.brief!(cf)?.template, original.brief!(cf)?.template,
            reason: original.id);
      }
      if (original.fill != null) {
        expect(rebuilt.fill!(cf, 'demand_money'),
            original.fill!(cf, 'demand_money'),
            reason: original.id);
      }
      if (original.askReply != null) {
        expect(rebuilt.askReply!(cf)?.text, original.askReply!(cf)?.text,
            reason: original.id);
        expect(rebuilt.askReply!(cf)?.chips, original.askReply!(cf)?.chips,
            reason: original.id);
      }
      for (var i = 0; i < original.slots.length; i++) {
        final os = original.slots[i];
        final rs = rebuilt.slots[i];
        expect(rs.first, os.first, reason: '${original.id}.${os.id}.first');
        expect(rs.sticky, os.sticky, reason: '${original.id}.${os.id}.sticky');
        expect(rs.yesValue, os.yesValue, reason: '${original.id}.${os.id}.yesValue');
        expect(rs.noValue, os.noValue, reason: '${original.id}.${os.id}.noValue');
        expect(rs.read(Sense.norm('بله')), os.read(Sense.norm('بله')),
            reason: '${original.id}.${os.id}.read');
        if (os.effect != null) {
          expect(rs.effect!(cf), os.effect!(cf),
              reason: '${original.id}.${os.id}.effect');
        }
      }
      for (var i = 0; i < original.issues.length; i++) {
        final oi = original.issues[i];
        final ri = rebuilt.issues[i];
        expect(ri.body(cf), oi.body(cf), reason: '${original.id}.${oi.id}');
        if (oi.rank != null) {
          expect(ri.rank!(cf), oi.rank!(cf), reason: '${original.id}.${oi.id}.rank');
        }
      }
    }
  });

  test('Topic.fromJson ورودی نامعتبر را با FormatException رد می‌کند', () {
    expect(
      () => Topic.fromJson(const {'id': 'x', 'title': 'x'}),
      throwsFormatException,
    );
    expect(
      () => factExprFromJson(const {'op': 'unknown_op'}),
      throwsFormatException,
    );
    expect(
      () => readRuleFromJson(const {'op': 'unknown_op'}),
      throwsFormatException,
    );
    expect(
      () => textExprFromJson(const {'op': 'unknown_op'}),
      throwsFormatException,
    );
  });
}

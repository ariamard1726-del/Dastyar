import 'package:dastyar/domain/advocate/case_model.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';

RecapItem recapItemFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'RecapItem');
  return RecapItem(
    when: m['when'] == null ? null : factExprFromJson(m['when']),
    text: textExprFromJson(m['text'], claims: claims),
  );
}

DraftRule draftRuleFromJson(Object? raw) {
  final m = dslAsMap(raw, 'DraftRule');
  if (m['cases'] is List) {
    return DraftRule.cases([
      for (final c in m['cases'] as List)
        () {
          final cm = dslAsMap(c, 'DraftCase');
          return DraftCase(factExprFromJson(cm['when']), dslStrList(cm['ids']));
        }(),
    ], elseIds: dslStrList(m['else']));
  }
  if (m['when'] != null) {
    return DraftRule.when(
      factExprFromJson(m['when']),
      thenIds: dslStrList(m['then']),
      elseIds: dslStrList(m['else']),
    );
  }
  return DraftRule.fixed(dslStrList(m['then']));
}

RankRule rankRuleFromJson(Object? raw) {
  final m = dslAsMap(raw, 'RankRule');
  final op = dslReqStr(m, 'op', 'RankRule');
  return switch (op) {
    'const' => RankConst((m['value'] as num).toInt()),
    'cases' => RankCases(
        [
          for (final c in dslAsList(m['cases'], 'RankCases'))
            () {
              final cm = dslAsMap(c, 'RankCase');
              return RankCase(
                factExprFromJson(cm['when']),
                (cm['value'] as num).toInt(),
              );
            }(),
        ],
        fallback: (m['fallback'] as num?)?.toInt() ?? 0,
      ),
    _ => throw FormatException('عملگر RankRule ناشناخته: $op'),
  };
}

FilingRule filingRuleFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'FilingRule');
  final op = dslReqStr(m, 'op', 'FilingRule');
  return switch (op) {
    'spec' => FilingSpec(
        dslReqStr(m, 'template', 'FilingSpec'),
        textExprFromJson(m['chip'], claims: claims),
        textExprFromJson(m['name'], claims: claims),
      ),
    'cases' => FilingCases(
        [
          for (final c in dslAsList(m['cases'], 'FilingCases'))
            () {
              final cm = dslAsMap(c, 'FilingCase');
              return FilingCase(
                factExprFromJson(cm['when']),
                cm['filing'] == null
                    ? null
                    : filingRuleFromJson(cm['filing'], claims: claims),
              );
            }(),
        ],
        fallback: m['fallback'] == null
            ? null
            : filingRuleFromJson(m['fallback'], claims: claims),
      ),
    _ => throw FormatException('عملگر FilingRule ناشناخته: $op'),
  };
}

PromptRule promptRuleFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'PromptRule');
  final op = dslReqStr(m, 'op', 'PromptRule');
  return switch (op) {
    'none' => const PromptNone(),
    'spec' => PromptSpec(
        textExprFromJson(m['text'], claims: claims),
        [
          for (final c in dslAsList(m['chips'], 'PromptSpec'))
            textExprFromJson(c, claims: claims),
        ],
      ),
    'cases' => PromptCases(
        [
          for (final c in dslAsList(m['cases'], 'PromptCases'))
            () {
              final cm = dslAsMap(c, 'PromptCase');
              return PromptCase(
                factExprFromJson(cm['when']),
                cm['prompt'] == null
                    ? null
                    : promptRuleFromJson(cm['prompt'], claims: claims),
              );
            }(),
        ],
        fallback: m['fallback'] == null
            ? null
            : promptRuleFromJson(m['fallback'], claims: claims),
      ),
    _ => throw FormatException('عملگر PromptRule ناشناخته: $op'),
  };
}

FillRule fillRuleFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'FillRule');
  return FillRule({
    for (final e in m.entries)
      e.key: [
        for (final a in dslAsList(e.value, 'FillAssignList'))
          () {
            final am = dslAsMap(a, 'FillAssign');
            return FillAssign(
              dslReqStr(am, 'field', 'FillAssign'),
              textExprFromJson(am['value'], claims: claims),
              when: am['when'] == null ? null : factExprFromJson(am['when']),
            );
          }(),
      ],
  });
}

Element elementFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'Element');
  return Element.dsl(
    dslReqStr(m, 'text', 'Element'),
    factExprFromJson(m['test']),
    ifNo: m['ifNo']?.toString() ?? '',
    needs: dslStrList(m['needs']),
    because: m['because'] == null
        ? null
        : textExprFromJson(m['because'], claims: claims),
  );
}

Claim claimFromJson(Object? raw) {
  final m = dslAsMap(raw, 'Claim');
  return Claim.dsl(
    goal: dslReqStr(m, 'goal', 'Claim'),
    label: m['label']?.toString() ?? '',
    cues: m['cues']?.toString() ?? '',
    uses: dslStrList(m['uses']),
    when: m['when'] == null ? null : factExprFromJson(m['when']),
    elements: [
      for (final e in dslAsList(m['elements'], 'Claim.elements'))
        elementFromJson(e),
    ],
    win: textExprFromJson(m['win']),
    counter: m['counter'] == null ? null : textExprFromJson(m['counter']),
  );
}

Slot slotFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'Slot');
  return Slot.dsl(
    id: dslReqStr(m, 'id', 'Slot'),
    ask: dslReqStr(m, 'ask', 'Slot'),
    why: m['why']?.toString() ?? '',
    read: readRuleFromJson(m['read']),
    readPending: m['readPending'] == null ? null : readRuleFromJson(m['readPending']),
    readSure: m['readSure'] == null ? null : readRuleFromJson(m['readSure']),
    options: dslStrList(m['options']),
    yesValue: m['yesValue']?.toString() ?? 'yes',
    noValue: m['noValue']?.toString() ?? 'no',
    effect: m['effect'] == null
        ? null
        : textExprFromJson(m['effect'], claims: claims),
    when: m['when'] == null ? null : factExprFromJson(m['when']),
    first: m['first'] == true,
    sticky: m['sticky'] == true,
    priority: dslStrList(m['priority']),
  );
}

Issue issueFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'Issue');
  return Issue.dsl(
    id: dslReqStr(m, 'id', 'Issue'),
    chip: dslReqStr(m, 'chip', 'Issue'),
    cues: dslReqStr(m, 'cues', 'Issue'),
    covers: dslStrList(m['covers']).toSet(),
    body: textExprFromJson(m['body'], claims: claims),
    when: m['when'] == null ? null : factExprFromJson(m['when']),
    rank: m['rank'] == null ? null : rankRuleFromJson(m['rank']),
  );
}

Topic topicFromJson(Map<String, dynamic> m) {
  final claims = <Claim>[
    if (m['claims'] is List)
      for (final c in m['claims'] as List) claimFromJson(c),
  ];
  final cuesMap = dslAsMap(m['cues'], 'Topic.cues');
  final followMap = dslAsMap(m['follow'], 'Topic.follow');
  return Topic.dsl(
    id: dslReqStr(m, 'id', 'Topic'),
    title: dslReqStr(m, 'title', 'Topic'),
    cues: {for (final e in cuesMap.entries) e.key: (e.value as num).toInt()},
    anti: m['anti']?.toString() ?? '',
    gate: m['gate'] == null ? null : gateRuleFromJson(m['gate']),
    slots: [
      for (final s in dslAsList(m['slots'], 'Topic.slots'))
        slotFromJson(s, claims: claims),
    ],
    issues: [
      for (final i in dslAsList(m['issues'], 'Topic.issues'))
        issueFromJson(i, claims: claims),
    ],
    opening: textExprFromJson(m['opening'], claims: claims),
    follow: {
      for (final e in followMap.entries)
        e.key: textExprFromJson(e.value, claims: claims),
    },
    drafts: m['drafts'] == null ? null : draftRuleFromJson(m['drafts']),
    claims: claims,
    recap: m['recap'] is List
        ? [for (final r in m['recap'] as List) recapItemFromJson(r, claims: claims)]
        : null,
    petition: m['petition'] == null
        ? null
        : filingRuleFromJson(m['petition'], claims: claims),
    brief: m['brief'] == null
        ? null
        : filingRuleFromJson(m['brief'], claims: claims),
    fill: m['fill'] == null ? null : fillRuleFromJson(m['fill'], claims: claims),
    askReply: m['askReply'] == null
        ? null
        : promptRuleFromJson(m['askReply'], claims: claims),
  );
}

import 'package:dastyar/domain/advocate/case_model.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';

Map<String, dynamic> dslAsMap(Object? raw, String ctx) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return {for (final e in raw.entries) e.key.toString(): e.value};
  }
  throw FormatException('ساختار Map نامعتبر در $ctx');
}

List<dynamic> dslAsList(Object? raw, String ctx) {
  if (raw is List) return raw;
  throw FormatException('ساختار List نامعتبر در $ctx');
}

String dslReqStr(Map<String, dynamic> m, String key, String ctx) {
  final v = m[key];
  if (v is String) return v;
  throw FormatException('فیلد متنی "$key" در $ctx پیدا نشد');
}

List<String> dslStrList(Object? raw) =>
    raw is List ? [for (final x in raw) x.toString()] : const [];

FactExpr factExprFromJson(Object? raw) {
  final m = dslAsMap(raw, 'FactExpr');
  final op = dslReqStr(m, 'op', 'FactExpr');
  return switch (op) {
    'const' => FactConst(m['value'] as bool?),
    'has' => FactHas(dslReqStr(m, 'key', 'FactHas')),
    'touched' => FactTouched(dslReqStr(m, 'key', 'FactTouched')),
    'covered' => FactCovered(dslReqStr(m, 'key', 'FactCovered')),
    'hasNum' => FactHasNum(dslReqStr(m, 'key', 'FactHasNum')),
    'yes' => FactYes(dslReqStr(m, 'key', 'FactYes')),
    'no' => FactNo(dslReqStr(m, 'key', 'FactNo')),
    'tri' => FactTri(dslReqStr(m, 'key', 'FactTri')),
    'eq' => FactEq(dslReqStr(m, 'key', 'FactEq'), dslReqStr(m, 'value', 'FactEq')),
    'in' => FactIn(dslReqStr(m, 'key', 'FactIn'), dslStrList(m['values'])),
    'numMin' => FactNumMin(
        dslReqStr(m, 'key', 'FactNumMin'),
        (m['min'] as num).toInt(),
        missingNull: m['missingNull'] != false,
      ),
    'numMax' => FactNumMax(
        dslReqStr(m, 'key', 'FactNumMax'),
        (m['max'] as num).toInt(),
        missingNull: m['missingNull'] != false,
      ),
    'not' => FactNot(factExprFromJson(m['inner'])),
    'all' => FactAll([for (final i in dslAsList(m['items'], 'FactAll')) factExprFromJson(i)]),
    'any' => FactAny([for (final i in dslAsList(m['items'], 'FactAny')) factExprFromJson(i)]),
    'triIf' => FactTriIf(
        factExprFromJson(m['cond']),
        m['then'] as bool?,
        m['else'] as bool?,
      ),
    'triWhen' => FactTriWhen(
        factExprFromJson(m['cond']),
        factExprFromJson(m['then']),
        m['else'] == null ? null : factExprFromJson(m['else']),
      ),
    'triCases' => FactTriCases(
        [
          for (final item in dslAsList(m['cases'], 'FactTriCases'))
            () {
              final cm = dslAsMap(item, 'FactCase');
              return FactCase(
                factExprFromJson(cm['when']),
                factExprFromJson(cm['then']),
              );
            }(),
        ],
        fallback: m['fallback'] == null ? null : factExprFromJson(m['fallback']),
      ),
    _ => throw FormatException('عملگر FactExpr ناشناخته: $op'),
  };
}

ReadRule readRuleFromJson(Object? raw) {
  final m = dslAsMap(raw, 'ReadRule');
  final op = dslReqStr(m, 'op', 'ReadRule');
  return switch (op) {
    'yn' => ReadYn(dslReqStr(m, 'yes', 'ReadYn'), dslReqStr(m, 'no', 'ReadYn')),
    'cases' => ReadCases([
        for (final item in dslAsList(m['cases'], 'ReadCases'))
          () {
            final cm = dslAsMap(item, 'ReadCase');
            return ReadCase(
              dslReqStr(cm, 'pattern', 'ReadCase'),
              dslReqStr(cm, 'value', 'ReadCase'),
              word: cm['word'] == true,
            );
          }(),
      ]),
    'amount' => ReadAmount(loose: m['loose'] == true),
    'numBefore' => ReadNumBefore(
        dslReqStr(m, 'unit', 'ReadNumBefore'),
        min: (m['min'] as num?)?.toInt(),
        max: (m['max'] as num?)?.toInt(),
        fallbackLoose: m['fallbackLoose'] == true,
      ),
    'months' => ReadMonths(min: (m['min'] as num?)?.toInt() ?? 1),
    'guard' => ReadGuard(
        dslReqStr(m, 'pattern', 'ReadGuard'),
        readRuleFromJson(m['inner']),
      ),
    'beforeMatch' => ReadBeforeMatch(
        dslReqStr(m, 'split', 'ReadBeforeMatch'),
        readRuleFromJson(m['inner']),
      ),
    'saysNoOrHas' => ReadSaysNoOrHas(
        dslReqStr(m, 'pattern', 'ReadSaysNoOrHas'),
        dslReqStr(m, 'value', 'ReadSaysNoOrHas'),
      ),
    'shortNonQuestion' => ReadShortNonQuestion(
        dslReqStr(m, 'value', 'ReadShortNonQuestion'),
        maxWords: (m['maxWords'] as num?)?.toInt() ?? 6,
      ),
    'seq' => ReadSeq([
        for (final s in dslAsList(m['steps'], 'ReadSeq')) readRuleFromJson(s),
      ]),
    _ => throw FormatException('عملگر ReadRule ناشناخته: $op'),
  };
}

GateRule gateRuleFromJson(Object? raw) {
  final m = dslAsMap(raw, 'GateRule');
  final op = dslReqStr(m, 'op', 'GateRule');
  return switch (op) {
    'readMatches' => GateReadMatches(readRuleFromJson(m['rule'])),
    'word' => GateWord(dslReqStr(m, 'pattern', 'GateWord')),
    'allHas' => GateAllHas(dslStrList(m['patterns'])),
    'any' => GateAny([
        for (final r in dslAsList(m['rules'], 'GateAny')) gateRuleFromJson(r),
      ]),
    _ => throw FormatException('عملگر GateRule ناشناخته: $op'),
  };
}

TextExpr textExprFromJson(Object? raw, {List<Claim> claims = const []}) {
  final m = dslAsMap(raw, 'TextExpr');
  final op = dslReqStr(m, 'op', 'TextExpr');
  return switch (op) {
    'topicText' => Tx(dslReqStr(m, 'key', 'Tx')),
    'rentText' => TxRent(dslReqStr(m, 'key', 'TxRent')),
    'raw' => TxRaw(dslReqStr(m, 'text', 'TxRaw')),
    'shared' => TxShared(SharedText.values.byName(dslReqStr(m, 'kind', 'TxShared'))),
    'forum' => TxForum(dslReqStr(m, 'factKey', 'TxForum')),
    'num' => TxNum(
        dslReqStr(m, 'factKey', 'TxNum'),
        fmt: NumFmt.values.byName(m['fmt']?.toString() ?? 'toman'),
        defaultZero: m['defaultZero'] == true,
      ),
    'numOffset' => TxNumOffset(
        dslReqStr(m, 'factKey', 'TxNumOffset'),
        (m['delta'] as num).toInt(),
        fmt: NumFmt.values.byName(m['fmt']?.toString() ?? 'fa'),
        defaultZero: m['defaultZero'] != false,
      ),
    'scaleMul' => TxScaleMul(
        dslReqStr(m, 'baseKey', 'TxScaleMul'),
        dslReqStr(m, 'scaleKey', 'TxScaleMul'),
        (m['factor'] as num).toDouble(),
        divisor: (m['divisor'] as num?)?.toInt() ?? 12,
        fmt: NumFmt.values.byName(m['fmt']?.toString() ?? 'toman'),
        divideFirst: m['divideFirst'] == true,
      ),
    'switch' => TxSwitch(
        dslReqStr(m, 'factKey', 'TxSwitch'),
        {
          for (final e in dslAsMap(m['cases'], 'TxSwitch').entries)
            e.key: textExprFromJson(e.value, claims: claims),
        },
        fallback: m['fallback'] == null
            ? null
            : textExprFromJson(m['fallback'], claims: claims),
      ),
    'cond' => TxCond(
        factExprFromJson(m['when']),
        textExprFromJson(m['then'], claims: claims),
        m['else'] == null ? null : textExprFromJson(m['else'], claims: claims),
      ),
    'concat' => TxConcat([
        for (final p in dslAsList(m['parts'], 'TxConcat'))
          textExprFromJson(p, claims: claims),
      ]),
    'join' => TxJoin(
        dslReqStr(m, 'separator', 'TxJoin'),
        [
          for (final p in dslAsList(m['parts'], 'TxJoin'))
            textExprFromJson(p, claims: claims),
        ],
      ),
    'listJoin' => TxListJoin(
        prefix: m['prefix'] == null
            ? null
            : textExprFromJson(m['prefix'], claims: claims),
        separator: textExprFromJson(m['separator'], claims: claims),
        suffix: m['suffix'] == null
            ? null
            : textExprFromJson(m['suffix'], claims: claims),
        items: [
          for (final i in dslAsList(m['items'], 'TxListJoin'))
            recapItemFromJson(i, claims: claims),
        ],
        empty: m['empty'] == null
            ? null
            : textExprFromJson(m['empty'], claims: claims),
      ),
    'cases' => TxCases(
        [
          for (final c in dslAsList(m['cases'], 'TxCases'))
            () {
              final cm = dslAsMap(c, 'TextCase');
              return TextCase(
                factExprFromJson(cm['when']),
                textExprFromJson(cm['then'], claims: claims),
              );
            }(),
        ],
        fallback: m['fallback'] == null
            ? null
            : textExprFromJson(m['fallback'], claims: claims),
      ),
    'assessDemands' => TxAssessDemands(
        claims: claims,
        replaceLabel: textExprFromJson(m['replaceLabel'], claims: claims),
        replacedText: textExprFromJson(m['replacedText'], claims: claims),
        extra: textExprFromJson(m['extra'], claims: claims),
        separator: textExprFromJson(m['separator'], claims: claims),
      ),
    _ => throw FormatException('عملگر TextExpr ناشناخته: $op'),
  };
}

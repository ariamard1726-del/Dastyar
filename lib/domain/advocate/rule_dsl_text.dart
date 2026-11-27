import 'package:dastyar/domain/advocate/case_state.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';
import 'package:dastyar/domain/advocate/topics/shared.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

enum SharedText { moneyCost, moneyTime, anyLawyer }

enum NumFmt { toman, fa, span }

String _formatNum(int v, NumFmt fmt) => switch (fmt) {
      NumFmt.toman => Sense.toman(v),
      NumFmt.fa => Sense.fa(v),
      NumFmt.span => Sense.span(v),
    };

/// عبارت‌های متنیِ قاعده‌مند (`opening`، `effect`، `body`، `win`، `counter`،
/// `because`، `follow`) و ساختار `Recap`/`Drafts`.
abstract class TextExpr {
  const TextExpr();
  String evalText(CaseFile f);
  Map<String, dynamic> toJson();
}

class Tx extends TextExpr {
  final String key;
  const Tx(this.key);

  @override
  String evalText(CaseFile f) => topicText(key);

  @override
  Map<String, dynamic> toJson() => {'op': 'topicText', 'key': key};
}

class TxRent extends TextExpr {
  final String key;
  const TxRent(this.key);

  @override
  String evalText(CaseFile f) => rentText(key);

  @override
  Map<String, dynamic> toJson() => {'op': 'rentText', 'key': key};
}

class TxRaw extends TextExpr {
  final String text;
  const TxRaw(this.text);

  @override
  String evalText(CaseFile f) => text;

  @override
  Map<String, dynamic> toJson() => {'op': 'raw', 'text': text};
}

class TxShared extends TextExpr {
  final SharedText kind;
  const TxShared(this.kind);

  @override
  String evalText(CaseFile f) => switch (kind) {
        SharedText.moneyCost => moneyCost,
        SharedText.moneyTime => moneyTime,
        SharedText.anyLawyer => anyLawyer,
      };

  @override
  Map<String, dynamic> toJson() => {'op': 'shared', 'kind': kind.name};
}

class TxForum extends TextExpr {
  final String factKey;
  const TxForum(this.factKey);

  @override
  String evalText(CaseFile f) => moneyForum(f.n(factKey));

  @override
  Map<String, dynamic> toJson() => {'op': 'forum', 'factKey': factKey};
}

class TxNum extends TextExpr {
  final String factKey;
  final NumFmt fmt;
  final bool defaultZero;
  const TxNum(this.factKey, {this.fmt = NumFmt.toman, this.defaultZero = false});

  @override
  String evalText(CaseFile f) {
    final v = f.n(factKey) ?? (defaultZero ? 0 : null);
    if (v == null) return '';
    return _formatNum(v, fmt);
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'num',
        'factKey': factKey,
        'fmt': fmt.name,
        if (defaultZero) 'defaultZero': true,
      };
}

class TxNumOffset extends TextExpr {
  final String factKey;
  final int delta;
  final NumFmt fmt;
  final bool defaultZero;
  const TxNumOffset(
    this.factKey,
    this.delta, {
    this.fmt = NumFmt.fa,
    this.defaultZero = true,
  });

  @override
  String evalText(CaseFile f) {
    final base = f.n(factKey) ?? (defaultZero ? 0 : null);
    if (base == null) return '';
    return _formatNum(base + delta, fmt);
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'numOffset',
        'factKey': factKey,
        'delta': delta,
        'fmt': fmt.name,
        if (!defaultZero) 'defaultZero': false,
      };
}

class TxScaleMul extends TextExpr {
  final String baseKey;
  final String scaleKey;
  final double factor;
  final int divisor;
  final NumFmt fmt;
  final bool divideFirst;
  const TxScaleMul(
    this.baseKey,
    this.scaleKey,
    this.factor, {
    this.divisor = 12,
    this.fmt = NumFmt.toman,
    this.divideFirst = false,
  });

  @override
  String evalText(CaseFile f) {
    final s = f.n(baseKey);
    final m = f.n(scaleKey);
    if (s == null || m == null) return '';
    final v = divideFirst
        ? (s * factor * (m / divisor)).round()
        : (s * factor * m / divisor).round();
    return _formatNum(v, fmt);
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'scaleMul',
        'baseKey': baseKey,
        'scaleKey': scaleKey,
        'factor': factor,
        'divisor': divisor,
        'fmt': fmt.name,
        if (divideFirst) 'divideFirst': true,
      };
}

class TxSwitch extends TextExpr {
  final String factKey;
  final Map<String, TextExpr> cases;
  final TextExpr? fallback;
  const TxSwitch(this.factKey, this.cases, {this.fallback});

  @override
  String evalText(CaseFile f) =>
      (cases[f.get(factKey)] ?? fallback)?.evalText(f) ?? '';

  @override
  Map<String, dynamic> toJson() => {
        'op': 'switch',
        'factKey': factKey,
        'cases': {for (final e in cases.entries) e.key: e.value.toJson()},
        if (fallback != null) 'fallback': fallback!.toJson(),
      };
}

class TxCond extends TextExpr {
  final FactExpr when;
  final TextExpr thenText;
  final TextExpr? elseText;
  const TxCond(this.when, this.thenText, [this.elseText]);

  @override
  String evalText(CaseFile f) =>
      when.evalCond(f) ? thenText.evalText(f) : (elseText?.evalText(f) ?? '');

  @override
  Map<String, dynamic> toJson() => {
        'op': 'cond',
        'when': when.toJson(),
        'then': thenText.toJson(),
        if (elseText != null) 'else': elseText!.toJson(),
      };
}

class TxConcat extends TextExpr {
  final List<TextExpr> parts;
  const TxConcat(this.parts);

  @override
  String evalText(CaseFile f) {
    final sb = StringBuffer();
    for (final p in parts) {
      sb.write(p.evalText(f));
    }
    return sb.toString();
  }

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'concat', 'parts': [for (final p in parts) p.toJson()]};
}

class TxJoin extends TextExpr {
  final String separator;
  final List<TextExpr> parts;
  const TxJoin(this.separator, this.parts);

  @override
  String evalText(CaseFile f) => [
        for (final p in parts)
          if (p.evalText(f).isNotEmpty) p.evalText(f),
      ].join(separator);

  @override
  Map<String, dynamic> toJson() => {
        'op': 'join',
        'separator': separator,
        'parts': [for (final p in parts) p.toJson()],
      };
}

class TxListJoin extends TextExpr {
  final TextExpr? prefix;
  final TextExpr separator;
  final TextExpr? suffix;
  final List<RecapItem> items;
  final TextExpr? empty;
  const TxListJoin({
    this.prefix,
    required this.separator,
    this.suffix,
    required this.items,
    this.empty,
  });

  @override
  String evalText(CaseFile f) {
    final out = <String>[];
    for (final item in items) {
      if (item.when != null && !item.when!.evalCond(f)) continue;
      final t = item.text.evalText(f);
      if (t.isNotEmpty) out.add(t);
    }
    if (out.isEmpty) return empty?.evalText(f) ?? '';
    return '${prefix?.evalText(f) ?? ''}${out.join(separator.evalText(f))}${suffix?.evalText(f) ?? ''}';
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'listJoin',
        if (prefix != null) 'prefix': prefix!.toJson(),
        'separator': separator.toJson(),
        if (suffix != null) 'suffix': suffix!.toJson(),
        'items': [for (final i in items) i.toJson()],
        if (empty != null) 'empty': empty!.toJson(),
      };
}

class RecapItem {
  final FactExpr? when;
  final TextExpr text;
  const RecapItem({required this.text, this.when});

  Map<String, dynamic> toJson() => {
        if (when != null) 'when': when!.toJson(),
        'text': text.toJson(),
      };
}

class RecapRule {
  final List<RecapItem> items;
  const RecapRule(this.items);

  List<String> evalRecap(CaseFile f) => [
        for (final i in items)
          if (i.when == null || i.when!.evalCond(f)) i.text.evalText(f),
      ];

  List<Map<String, dynamic>> toJson() => [for (final i in items) i.toJson()];
}

class DraftCase {
  final FactExpr when;
  final List<String> ids;
  const DraftCase(this.when, this.ids);

  Map<String, dynamic> toJson() => {'when': when.toJson(), 'ids': ids};
}

class DraftRule {
  final FactExpr? when;
  final List<String> thenIds;
  final List<String> elseIds;
  final List<DraftCase> cases;

  const DraftRule.fixed(this.thenIds)
      : when = null,
        elseIds = const [],
        cases = const [];
  const DraftRule.when(this.when,
      {required this.thenIds, this.elseIds = const []})
      : cases = const [];
  const DraftRule.cases(this.cases, {this.elseIds = const []})
      : when = null,
        thenIds = const [];

  List<String> evalDrafts(CaseFile f) {
    if (cases.isNotEmpty) {
      for (final c in cases) {
        if (c.when.evalCond(f)) return c.ids;
      }
      return elseIds;
    }
    return when == null || when!.evalCond(f) ? thenIds : elseIds;
  }

  Map<String, dynamic> toJson() => {
        if (cases.isNotEmpty) 'cases': [for (final c in cases) c.toJson()],
        if (when != null) 'when': when!.toJson(),
        if (thenIds.isNotEmpty) 'then': thenIds,
        if (elseIds.isNotEmpty) 'else': elseIds,
      };
}

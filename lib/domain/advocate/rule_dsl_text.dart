import 'package:dastyar/domain/advocate/case_state.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/shared.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

enum SharedText { moneyCost, moneyTime, anyLawyer }

enum NumFmt { toman, fa }

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
  const TxNum(this.factKey, {this.fmt = NumFmt.toman});

  @override
  String evalText(CaseFile f) {
    final v = f.n(factKey);
    if (v == null) return '';
    return fmt == NumFmt.toman ? Sense.toman(v) : Sense.fa(v);
  }

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'num', 'factKey': factKey, 'fmt': fmt.name};
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

class DraftRule {
  final FactExpr? when;
  final List<String> thenIds;
  final List<String> elseIds;
  const DraftRule.fixed(this.thenIds)
      : when = null,
        elseIds = const [];
  const DraftRule.when(this.when,
      {required this.thenIds, this.elseIds = const []});

  List<String> evalDrafts(CaseFile f) =>
      when == null || when!.evalCond(f) ? thenIds : elseIds;

  Map<String, dynamic> toJson() => {
        if (when != null) 'when': when!.toJson(),
        'then': thenIds,
        if (elseIds.isNotEmpty) 'else': elseIds,
      };
}

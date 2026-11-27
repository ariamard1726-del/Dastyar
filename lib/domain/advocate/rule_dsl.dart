import 'package:dastyar/domain/advocate/case_state.dart';

export 'package:dastyar/domain/advocate/rule_dsl_json.dart';
export 'package:dastyar/domain/advocate/rule_dsl_read.dart';
export 'package:dastyar/domain/advocate/rule_dsl_text.dart';

/// زبانِ داده‌ای شرط‌های موضوع (`FactExpr`): جایگزین قابل سریال‌سازی برای
/// کلوژرهای `when` و `Element.test`.
abstract class FactExpr {
  const FactExpr();
  bool? evalTri(CaseFile f);
  bool evalCond(CaseFile f) => evalTri(f) == true;
  Map<String, dynamic> toJson();
}

class FactConst extends FactExpr {
  final bool? value;
  const FactConst(this.value);
  @override
  bool? evalTri(CaseFile f) => value;
  @override
  Map<String, dynamic> toJson() => {'op': 'const', 'value': value};
}

class FactHas extends FactExpr {
  final String key;
  const FactHas(this.key);
  @override
  bool? evalTri(CaseFile f) => f.has(key);
  @override
  Map<String, dynamic> toJson() => {'op': 'has', 'key': key};
}

class FactHasNum extends FactExpr {
  final String key;
  const FactHasNum(this.key);
  @override
  bool? evalTri(CaseFile f) => f.n(key) != null;
  @override
  Map<String, dynamic> toJson() => {'op': 'hasNum', 'key': key};
}

class FactYes extends FactExpr {
  final String key;
  const FactYes(this.key);
  @override
  bool? evalTri(CaseFile f) => f.yes(key);
  @override
  Map<String, dynamic> toJson() => {'op': 'yes', 'key': key};
}

class FactNo extends FactExpr {
  final String key;
  const FactNo(this.key);
  @override
  bool? evalTri(CaseFile f) => f.no(key);
  @override
  Map<String, dynamic> toJson() => {'op': 'no', 'key': key};
}

class FactTri extends FactExpr {
  final String key;
  const FactTri(this.key);
  @override
  bool? evalTri(CaseFile f) => f.tri(key);
  @override
  Map<String, dynamic> toJson() => {'op': 'tri', 'key': key};
}

class FactEq extends FactExpr {
  final String key;
  final String value;
  const FactEq(this.key, this.value);
  @override
  bool? evalTri(CaseFile f) => f.eq(key, value);
  @override
  Map<String, dynamic> toJson() => {'op': 'eq', 'key': key, 'value': value};
}

class FactIn extends FactExpr {
  final String key;
  final List<String> values;
  const FactIn(this.key, this.values);
  @override
  bool? evalTri(CaseFile f) => f.isOne(key, values);
  @override
  Map<String, dynamic> toJson() => {'op': 'in', 'key': key, 'values': values};
}

class FactNumMin extends FactExpr {
  final String key;
  final int min;
  final bool missingNull;
  const FactNumMin(this.key, this.min, {this.missingNull = true});

  @override
  bool? evalTri(CaseFile f) {
    final v = f.n(key);
    if (v == null) return missingNull ? null : false;
    return v >= min;
  }

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'numMin', 'key': key, 'min': min, 'missingNull': missingNull};
}

class FactNot extends FactExpr {
  final FactExpr inner;
  const FactNot(this.inner);

  @override
  bool? evalTri(CaseFile f) {
    final v = inner.evalTri(f);
    return v == null ? null : !v;
  }

  @override
  bool evalCond(CaseFile f) => !inner.evalCond(f);

  @override
  Map<String, dynamic> toJson() => {'op': 'not', 'inner': inner.toJson()};
}

class FactAll extends FactExpr {
  final List<FactExpr> items;
  const FactAll(this.items);
  @override
  bool? evalTri(CaseFile f) => evalCond(f);

  @override
  bool evalCond(CaseFile f) {
    for (final item in items) {
      if (!item.evalCond(f)) return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'all', 'items': [for (final i in items) i.toJson()]};
}

class FactAny extends FactExpr {
  final List<FactExpr> items;
  const FactAny(this.items);
  @override
  bool? evalTri(CaseFile f) => evalCond(f);

  @override
  bool evalCond(CaseFile f) {
    for (final item in items) {
      if (item.evalCond(f)) return true;
    }
    return false;
  }

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'any', 'items': [for (final i in items) i.toJson()]};
}

class FactTriIf extends FactExpr {
  final FactExpr cond;
  final bool? thenValue;
  final bool? elseValue;
  const FactTriIf(this.cond, this.thenValue, [this.elseValue]);

  @override
  bool? evalTri(CaseFile f) => cond.evalCond(f) ? thenValue : elseValue;

  @override
  Map<String, dynamic> toJson() => {
        'op': 'triIf',
        'cond': cond.toJson(),
        'then': thenValue,
        'else': elseValue,
      };
}

class FactTriWhen extends FactExpr {
  final FactExpr cond;
  final FactExpr thenExpr;
  final FactExpr? elseExpr;
  const FactTriWhen(this.cond, this.thenExpr, [this.elseExpr]);

  @override
  bool? evalTri(CaseFile f) =>
      cond.evalCond(f) ? thenExpr.evalTri(f) : elseExpr?.evalTri(f);

  @override
  Map<String, dynamic> toJson() => {
        'op': 'triWhen',
        'cond': cond.toJson(),
        'then': thenExpr.toJson(),
        if (elseExpr != null) 'else': elseExpr!.toJson(),
      };
}

class FactCase {
  final FactExpr when;
  final FactExpr then;
  const FactCase(this.when, this.then);
  Map<String, dynamic> toJson() => {'when': when.toJson(), 'then': then.toJson()};
}

class FactTriCases extends FactExpr {
  final List<FactCase> cases;
  final FactExpr? fallback;
  const FactTriCases(this.cases, {this.fallback});

  @override
  bool? evalTri(CaseFile f) {
    for (final c in cases) {
      if (c.when.evalCond(f)) return c.then.evalTri(f);
    }
    return fallback?.evalTri(f);
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'triCases',
        'cases': [for (final c in cases) c.toJson()],
        if (fallback != null) 'fallback': fallback!.toJson(),
      };
}

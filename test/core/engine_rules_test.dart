import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine_rules.dart';

/// قاعده‌های موتور بازیابی باید از `dev/tools/contracts/engine_rules.json`
/// تولید شوند و بدون تکرارِ دستی در مصرف‌کننده‌های `lib/core/` بمانند.
void main() {
  final contract = jsonDecode(
    File('dev/tools/contracts/engine_rules.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('مقادیر EngineRules دقیقاً با قرارداد JSON برابر است', () {
    final bm = contract['bm25f'] as Map<String, dynamic>;
    expect(EngineRules.bm25K1, (bm['k1'] as num).toDouble());
    expect(EngineRules.bm25B, (bm['b'] as num).toDouble());
    expect(EngineRules.bm25WT, (bm['wTitle'] as num).toDouble());
    expect(EngineRules.bm25WB, (bm['wBody'] as num).toDouble());
    expect(EngineRules.bm25WC, (bm['wContext'] as num).toDouble());
    expect(EngineRules.obsoletePenalty, (bm['obsoletePenalty'] as num).toDouble());
    expect(EngineRules.explicitScore, (bm['explicitScore'] as num).toDouble());
    expect(EngineRules.prefixMinLen, bm['prefixMinLen']);
    expect(EngineRules.prefixWeight, (bm['prefixWeight'] as num).toDouble());
    expect(EngineRules.minHitScore, (bm['minScore'] as num).toDouble());
    expect(EngineRules.lowCover, (bm['lowCover'] as num).toDouble());
    expect(EngineRules.coverageMargin, (bm['coverageMargin'] as num).toDouble());
    expect(
      EngineRules.nearAlternativeFactor,
      (bm['nearAlternativeFactor'] as num).toDouble(),
    );
    expect(EngineRules.maxNearAlternatives, bm['maxNearAlternatives']);
    expect(EngineRules.altMinScoreRatio, (bm['altMinScoreRatio'] as num).toDouble());

    final aq = contract['articleQuery'] as Map<String, dynamic>;
    expect(EngineRules.articleQueryPattern, aq['pattern']);

    final ob = contract['obsolete'] as Map<String, dynamic>;
    expect(EngineRules.obsoleteMaxLen, ob['maxLen']);
    expect(EngineRules.obsoleteTrimPattern, ob['trimPattern']);
    expect(EngineRules.cleanBodyPattern, ob['cleanBodyPattern']);
    expect(EngineRules.obsoletePrefixes, (ob['prefixes'] as List).cast<String>());

    final df = contract['definitionPromotion'] as Map<String, dynamic>;
    expect(EngineRules.defQuestionPattern, df['questionPattern']);
    expect(EngineRules.defWords, (df['words'] as List).cast<String>().toSet());
    expect(
      EngineRules.defMetaPrefixes,
      (df['metaPrefixes'] as List).cast<String>().toSet(),
    );
    expect(EngineRules.defMarkPattern, df['markPattern']);
    expect(EngineRules.defStrongPattern, df['strongPattern']);
    expect(EngineRules.defTailWindow, df['tailWindow']);
    expect(EngineRules.defMaxPicked, df['maxPicked']);

    final lm = contract['lawMention'] as Map<String, dynamic>;
    expect(
      EngineRules.lawPrefixes,
      (lm['requiredPrefixes'] as List).cast<String>(),
    );
    expect(EngineRules.shortLawPrefix, lm['shortLawPrefix']);
    expect(EngineRules.shortLawMinLen, lm['shortLawMinLen']);

    final ud = contract['unloadedDomain'] as Map<String, dynamic>;
    expect(EngineRules.unloadedPenalTerms, (ud['penalTerms'] as List).cast<String>());
    expect(
      EngineRules.penalContextMarkers,
      (ud['penalContextMarkers'] as List).cast<String>(),
    );
    expect(
      EngineRules.loadedCriminalExceptions,
      (ud['loadedCriminalExceptions'] as List).cast<String>(),
    );
    expect(EngineRules.taxTriggers, (ud['taxTriggers'] as List).cast<String>());
    expect(
      EngineRules.socialSecurityTriggers,
      (ud['socialSecurityTriggers'] as List).cast<String>(),
    );
    final rawAnchors = (ud['anchorGroups'] as List).cast<List<dynamic>>();
    expect(EngineRules.anchorGroups.length, rawAnchors.length);
    for (var i = 0; i < rawAnchors.length; i++) {
      expect(EngineRules.anchorGroups[i].$1, rawAnchors[i][0]);
      expect(
        EngineRules.anchorGroups[i].$2,
        (rawAnchors[i][1] as List).cast<String>(),
      );
    }

    final cf = contract['conflicts'] as Map<String, dynamic>;
    expect(EngineRules.conflictsMaxDepth, cf['maxDepth']);
    expect(EngineRules.conflictsCycleSuffix, cf['cycleSuffix']);
  });

  test('مصرف‌کننده‌های core قواعد تکراری دستی ندارند', () {
    final ranker = File('lib/core/law_ranker.dart').readAsStringSync();
    expect(ranker.contains("RegExp(r'چیست|چیه"), isFalse);
    expect(ranker.contains('final double _k1 = 0.9;'), isFalse);

    final engine = File('lib/core/engine.dart').readAsStringSync();
    expect(engine.contains('_unloadedPenalTerms'), isFalse);
    expect(engine.contains('_anchorGroups'), isFalse);
  });
}

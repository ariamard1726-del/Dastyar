part of 'rent.dart';

// بحث‌های مشترکِ دو طرف: سرقفلی، فوتِ موجر، سند و…

final List<Issue> _rentIssuesBoth = [
  // ---- هر دو طرف
  Issue.dsl(
    id: 'goodwill',
    chip: rentText('issueGoodwillChip'),
    cues: _cGoodwill,
    body: _rentGoodwillBody,
    rank: const RankCases([RankCase(_shop, 4)], fallback: -1),
  ),
  Issue.dsl(
    id: 'death',
    chip: rentText('issueDeathChip'),
    cues: _cDeath,
    body: _rentDeathBody,
    rank: const RankConst(-1),
  ),
  Issue.dsl(
    id: 'sold',
    chip: rentText('issueSoldChip'),
    cues: _cSold,
    body: _rentSoldBody,
  ),
  Issue.dsl(
    id: 'usage',
    chip: rentText('issueUsageChip'),
    cues: _cUsage,
    body: _rentUsageBody,
    rank: const RankCases([
      RankCase(FactAll([_landlordSide, FactYes('ended')]), 3),
      RankCase(
        FactAll([FactNot(_landlordSide), FactYes('ended'), FactNo('vacated')]),
        2,
      ),
    ]),
  ),
  Issue.dsl(
    id: 'code',
    chip: rentText('issueCodeChip'),
    cues: _cCode,
    body: _rentCodeBody,
    rank: const RankCases([
      RankCase(FactAny([FactNo('witness'), FactNo('contract')]), 2),
    ]),
  ),
  Issue.dsl(
    id: 'penalty',
    chip: rentText('issuePenaltyChip'),
    cues: _cPenalty,
    body: _rentPenaltyBody,
    rank: const RankCases([
      RankCase(FactAll([_evicting, FactYes('ended')]), 2),
      RankCase(FactAll([_mDeposit, FactYes('vacated')]), 2),
    ]),
  ),
  Issue.dsl(
    id: 'noTerm',
    chip: rentText('issueNoTermChip'),
    cues: _cNoTerm,
    body: _rentNoTermBody,
    rank: const RankCases([RankCase(FactNo('contract'), 2)], fallback: -1),
  ),
];

part of 'rent.dart';

// بحث‌های مشترکِ دو طرف: سرقفلی، فوتِ موجر، سند و…

final List<Issue> _rentIssuesBoth = [
  // ---- هر دو طرف
  Issue(
    id: 'goodwill',
    chip: rentText('issueGoodwillChip'),
    cues: _cGoodwill,
    body: (f) => _rentGoodwillBody(),
    rank: (f) => _r(_shop(f), 4, -1),
  ),
  Issue(
    id: 'death',
    chip: rentText('issueDeathChip'),
    cues: _cDeath,
    body: _rentDeathBody,
    rank: (f) => -1,
  ),
  Issue(
    id: 'sold',
    chip: rentText('issueSoldChip'),
    cues: _cSold,
    body: _rentSoldBody,
  ),
  Issue(
    id: 'usage',
    chip: rentText('issueUsageChip'),
    cues: _cUsage,
    body: _rentUsageBody,
    rank: (f) => f.eq('role', 'landlord')
        ? _r(f.yes('ended'), 3)
        : _r(f.yes('ended') && f.no('vacated'), 2),
  ),
  Issue(
    id: 'code',
    chip: rentText('issueCodeChip'),
    cues: _cCode,
    body: (f) => _rentCodeBody(),
    rank: (f) => _r(f.no('witness') || f.no('contract'), 2),
  ),
  Issue(
    id: 'penalty',
    chip: rentText('issuePenaltyChip'),
    cues: _cPenalty,
    body: _rentPenaltyBody,
    rank: (f) => f.eq('role', 'landlord')
        ? _r(_evicting(f) && f.yes('ended'), 2)
        : _r(_matter(f, 'deposit') && f.yes('vacated'), 2),
  ),
  Issue(
    id: 'noTerm',
    chip: rentText('issueNoTermChip'),
    cues: _cNoTerm,
    body: _rentNoTermBody,
    rank: (f) => _r(f.no('contract'), 2, -1),
  ),
];

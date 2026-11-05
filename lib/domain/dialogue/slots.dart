/// Canonical slot keys shared by counseling, extraction, and planning.
///
/// These strings are persisted in counseling checkpoints. Keep their values
/// stable even if a Dart identifier is renamed; changing a value is a data
/// migration, not a cosmetic refactor.
class Slots {
  Slots._();

  static const String role = 'role';
  static const String nature = 'nature';
  static const String certTime = 'cert_time';
  static const String issue = 'issue';
  static const String proof = 'proof';
  static const String time = 'time';
  static const String expired = 'expired';
  static const String witnesses = 'witnesses';
  static const String subtopic = 'subtopic';
  static const String side = 'side';
  static const String detail = 'detail';
  static const String kind = 'kind';
  static const String evidence = 'evidence';
  static const String harmType = 'harm_type';
  static const String stage = 'stage';
  static const String deadline = 'deadline';
  static const String doc = 'doc';

  // Optional slots are extracted when present but are never required by the
  // planner before it can produce an answer.
  static const String amount = 'amount';
  static const String dueDate = 'due_date';
  static const String depositAmount = 'deposit_amount';

  // Synthetic planner action, not a persisted domain fact.
  static const String clarification = 'clarification';

  /// Required slot keys in planner priority order, keyed by legal domain.
  ///
  /// This is the single source of truth shared by [DomainSchema] and the
  /// counselor's legacy question adapter. Optional slots intentionally do not
  /// appear here.
  static const Map<String, List<String>> coreByDomain = <String, List<String>>{
    'cheque': <String>[role, nature, certTime],
    'labor': <String>[issue, proof, time],
    'lease': <String>[role, expired, witnesses],
    'family': <String>[subtopic, side, detail],
    'fraud_cyber': <String>[kind, evidence],
    'criminal_harm': <String>[harmType, proof],
    'litigation_defense': <String>[stage, deadline],
    'debt': <String>[role, doc],
  };

  static List<String> coreFor(String domainId) =>
      coreByDomain[domainId] ?? const <String>[];

  /// Every real slot key (excluding the synthetic clarification action).
  static const Set<String> all = <String>{
    role,
    nature,
    certTime,
    issue,
    proof,
    time,
    expired,
    witnesses,
    subtopic,
    side,
    detail,
    kind,
    evidence,
    harmType,
    stage,
    deadline,
    doc,
    amount,
    dueDate,
    depositAmount,
  };
}

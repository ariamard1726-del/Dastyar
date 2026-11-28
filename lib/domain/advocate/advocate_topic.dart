part of 'advocate.dart';

// تشخیص موضوع: کدام پرونده به حرف کاربر می‌خورد.

/// میان‌برِ داخلی: منطقش در `topic_score.dart` است تا بیرون از کلاس هم
/// آزمون‌شدنی باشد.
int _score(Topic t, String n) => TopicScore.of(t, n);

extension _TopicPicking on Advocate {
  double get _netMin => resolveNetMin(engine.pipeline);
  int get _topicOpenMin => resolveTopicOpenMin(engine.pipeline);
  int get _topicStrongMin => resolveTopicStrongMin(engine.pipeline);
  int get _topicDominantMin => resolveTopicDominantMin(engine.pipeline);

  // تشخیص موضوع در `TopicPicker` (topic_picker.dart) است؛ این‌ها پوستهٔ نازک‌اند.
  Topic? _current() => _picker.current();

  bool _answers(Topic t, String n) => _picker.answers(t, n);

  bool _guessable(String n) => _picker.guessable(n);

  AdvocateReply? _fromGuess(
          TopicGuess g, String raw, String n, Map<String, int> scores) =>
      _picker.fromGuess(g, raw, n, scores);

  Topic? _secondOpinion(String raw, String n) => _picker.secondOpinion(raw, n);

  Issue? _matchIssue(Topic t, String n) => _picker.matchIssue(t, n);

  LegalGuide? _matchGuide(String raw, String n) => _picker.matchGuide(raw, n);


}

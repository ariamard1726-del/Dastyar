import 'package:dastyar/core/persian_text.dart';

/// ضریب موضوعی قانون‌ها در رتبه‌بندی بازیابی (آینهٔ `law_factors` در
/// `tools/eval_py.py`؛ هر دو از `assets/brain/law_topics.json` می‌خوانند).
///
/// دو قاعده:
/// ۱. قانون‌های «تخصصی» (مثل مالیات‌های مستقیم یا تأمین اجتماعی) فقط وقتی
///    وزن کامل دارند که پرسش یکی از نشانه‌هایشان را داشته باشد؛ وگرنه امتیاز
///    موادشان در `specialistPenalty` ضرب می‌شود. این جلوی آمدن مادهٔ مالیاتی
///    برای پرسش «فسخ اجاره» را می‌گیرد.
/// ۲. اگر نشانهٔ یک موضوع (اجاره، کار، خانواده، چک، …) در پرسش باشد، امتیاز
///    قانون‌های همان موضوع در ضریبشان ضرب می‌شود.
///
/// تطبیق نشانه‌ها «آغاز واژه» است: نشانهٔ «اجاره» با «اجاره‌نامه» هم جور
/// می‌شود. نرمال‌سازی با `PersianText.phrase` است (ي/ك عربی، نیم‌فاصله و …).
class LawTopicPrior {
  final double specialistPenalty;
  final Map<String, List<String>> specialist;
  final List<LawTopic> topics;

  const LawTopicPrior({
    this.specialistPenalty = 1.0,
    this.specialist = const {},
    this.topics = const [],
  });

  static const LawTopicPrior empty = LawTopicPrior();

  bool get isEmpty => specialist.isEmpty && topics.isEmpty;

  factory LawTopicPrior.fromJson(Object? json) {
    if (json is! Map) return empty;
    final pen = json['specialistPenalty'];
    final spec = <String, List<String>>{};
    final rawSpec = json['specialist'];
    if (rawSpec is Map) {
      rawSpec.forEach((k, v) {
        if (k is String && v is List) {
          spec[k] = [
            for (final s in v)
              if (s is String && s.trim().isNotEmpty) PersianText.phrase(s),
          ];
        }
      });
    }
    final tops = <LawTopic>[];
    final rawTopics = json['topics'];
    if (rawTopics is List) {
      for (final t in rawTopics) {
        final topic = LawTopic.fromJson(t);
        if (topic != null) tops.add(topic);
      }
    }
    return LawTopicPrior(
      specialistPenalty: pen is num ? pen.toDouble() : 1.0,
      specialist: spec,
      topics: tops,
    );
  }

  static bool _hit(String paddedPhrase, List<String> signals) {
    for (final s in signals) {
      if (s.isNotEmpty && paddedPhrase.contains(' $s')) return true;
    }
    return false;
  }

  /// ضریب هر قانون برای این پرسش؛ قانونی که در نقشه نیست ضریب ۱ دارد.
  Map<String, double> factors(String question) {
    if (isEmpty) return const {};
    final n = ' ${PersianText.phrase(question)} ';
    final out = <String, double>{};
    specialist.forEach((law, signals) {
      if (!_hit(n, signals)) out[law] = specialistPenalty;
    });
    for (final t in topics) {
      if (!_hit(n, t.signals)) continue;
      t.laws.forEach((law, w) => out[law] = (out[law] ?? 1.0) * w);
    }
    return out;
  }
}

class LawTopic {
  final String id;
  final List<String> signals;
  final Map<String, double> laws;

  const LawTopic(this.id, this.signals, this.laws);

  static LawTopic? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final sig = json['signals'];
    final laws = json['laws'];
    if (sig is! List || laws is! Map) return null;
    final w = <String, double>{};
    laws.forEach((k, v) {
      if (k is String && v is num) w[k] = v.toDouble();
    });
    return LawTopic(
      id is String ? id : '',
      [
        for (final s in sig)
          if (s is String && s.trim().isNotEmpty) PersianText.phrase(s),
      ],
      w,
    );
  }
}

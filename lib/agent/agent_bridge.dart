import 'package:dastyar/agent/agent.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/templates.dart';

/// ابزارهایی که ایجنت می‌تواند صدا بزند؛ همه روی موتور آفلاین خود اپ کار می‌کنند.
class AgentBridge {
  static List<AgentTool> tools({
    required Assistant assistant,
    required List<LegalTemplate> templates,
  }) {
    return [
      AgentTool(
        'search_laws',
        'جستجو در متن رسمی قوانین موجود در اپ. args: {"query":"عبارت جستجو"}',
        (args) async {
          final q = (args['query'] ?? '').toString().trim();
          if (q.isEmpty) return 'عبارت جستجو خالی است.';
          var last = '';
          await for (final t in assistant.askWithAlternatives(q)) {
            last = t.text;
          }
          return last.trim().isEmpty ? 'نتیجه‌ای پیدا نشد.' : last;
        },
      ),
      AgentTool(
        'list_templates',
        'فهرست قالب‌های سند حقوقی (شکوائیه، دادخواست و...) که اپ می‌تواند بنویسد. args: {}',
        (args) async =>
            templates.map((t) => '${t.id}: ${t.title}').join('\n'),
      ),
    ];
  }
}

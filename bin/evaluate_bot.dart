// ابزار ارزیابی سرتاسری دستیار حقوقی (Phase 6).
//
// اجرا:
// flutter test bin/evaluate_bot.dart
// EVAL_ARGS="--verbose --json out/eval.json" flutter test bin/evaluate_bot.dart
// EVAL_STRICT=1 EVAL_ARGS="--strict" flutter test bin/evaluate_bot.dart
//
// چرا «flutter test»؟ موتور دانش، قوانین را از asset bundle می‌خواند
// (rootBundle) و اجرای آن به binding فلاتر نیاز دارد. این فایل یک ابزار
// توسعه است، نه بخشی از اپ، بنابراین استفاده از flutter_test در آن مجاز
// و کم‌هزینه است. اگر پروژه روزی assetها را از فایل‌سیستم هم بخواند، همین
// main بدون تغییر در dart run هم کار می‌کند. 

// ignore_for_file: avoid_print 

import 'dart:convert';
import 'dart:io'; 

import 'package:flutter_test/flutter_test.dart'
show TestWidgetsFlutterBinding, expect, isNot, test; 

import 'package:dastyar/core/debug_logger.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/evaluation/evaluation_dataset.dart';
import 'package:dastyar/domain/evaluation/evaluation_harness.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/templates.dart'; 

const String _usage = '''
ارزیابی دستیار حقوقی — Phase 6 

flutter test bin/evaluate_bot.dart
EVAL_ARGS="[گزینه‌ها]" flutter test bin/evaluate_bot.dart 

(آرگومان‌های خط فرمان به main نمی‌رسند؛ از EVAL_ARGS استفاده کنید.) 

گزینه‌ها:
--dataset <path> مسیر فایل سناریوها (پیش‌فرض: brain/eval/evaluation_dataset.json)
--limit <n> فقط n سناریوی نخست
--json <path> نوشتن گزارش کامل (JSON) در این مسیر
--traces <path> نوشتن ردِ دیباگِ نوبت‌ها در این مسیر (JSON)
--trace نمایش ردِ مرحله‌به‌مرحلهٔ هر نوبت در کنسول
--verbose نمایش جزئیات سناریوهای ناموفق
--strict خروج با کد ۱ اگر آستانه‌ها برآورده نشوند
--min-intent <x> آستانهٔ دقت نیت (پیش‌فرض 0.90)
--min-route <x> آستانهٔ دقت مسیر (پیش‌فرض 0.90)
--min-articles <x> آستانهٔ یادآوری مواد (پیش‌فرض 0.80)
--min-citation <x> آستانهٔ دقت استناد (پیش‌فرض 0.80)
--min-honesty <x> آستانهٔ صداقت (پیش‌فرض 1.00)
-h, --help همین راهنما
'''; 

class _Options {
String datasetPath = EvaluationDataset.defaultPath;
String? jsonPath;
String? tracesPath;
int? limit;
bool verbose = false;
bool trace = false;
bool strict = false;
bool help = false;
double minIntent = 0.90;
double minRoute = 0.90;
double minArticles = 0.80;
double minCitation = 0.80;
double minHonesty = 1.00; 

static _Options parse(List<String> args) {
final o = _Options();
String? valueOf(int i, String flag) {
if (i + 1 >= args.length) {
throw FormatException('مقدار $flag داده نشده است');
}
return args[i + 1];
} 

for (var i = 0; i < args.length; i++) {
final a = args[i];
if (a == '--dataset') {
o.datasetPath = valueOf(i, a)!;
i++;
} else if (a == '--json') {
o.jsonPath = valueOf(i, a);
i++;
} else if (a == '--traces') {
o.tracesPath = valueOf(i, a);
i++;
} else if (a == '--limit') {
o.limit = int.tryParse(valueOf(i, a)!);
i++;
} else if (a == '--min-intent') {
o.minIntent = double.tryParse(valueOf(i, a)!) ?? o.minIntent;
i++;
} else if (a == '--min-route') {
o.minRoute = double.tryParse(valueOf(i, a)!) ?? o.minRoute;
i++;
} else if (a == '--min-articles') {
o.minArticles = double.tryParse(valueOf(i, a)!) ?? o.minArticles;
i++;
} else if (a == '--min-citation') {
o.minCitation = double.tryParse(valueOf(i, a)!) ?? o.minCitation;
i++;
} else if (a == '--min-honesty') {
o.minHonesty = double.tryParse(valueOf(i, a)!) ?? o.minHonesty;
i++;
} else if (a == '--verbose') {
o.verbose = true;
} else if (a == '--trace') {
o.trace = true;
} else if (a == '--strict') {
o.strict = true;
} else if (a == '-h' || a == '--help') {
o.help = true;
} else if (a.startsWith('-')) {
throw FormatException('گزینهٔ ناشناخته: $a');
}
}
return o;
}
} 

List<LegalTemplate> _loadTemplates() {
final dir = Directory('assets/templates');
if (!dir.existsSync()) return const <LegalTemplate>[];
final out = <LegalTemplate>[];
for (final f in dir.listSync()) {
if (f is! File || !f.path.endsWith('.json')) continue;
try {
final json = jsonDecode(f.readAsStringSync());
if (json is Map<String, dynamic>) {
out.add(LegalTemplate.fromJson(json));
}
} catch (_) {
// قالب خراب نباید ارزیابی را متوقف کند.
}
}
out.sort((a, b) => a.id.compareTo(b.id));
return out;
} 

IntentNet? _loadIntentNet() {
try {
final file = File('assets/brain/intent_model.json');
if (!file.existsSync()) return null;
final json = jsonDecode(file.readAsStringSync());
if (json is! Map<String, dynamic>) return null;
return IntentNet.fromJson(json);
} catch (_) {
return null;
}
} 

/// اجرای ارزیابی و برگرداندن کدِ خروج.
Future<int> evaluateMain(List<String> args) async {
final _Options options;
try {
options = _Options.parse(args);
} on FormatException catch (e) {
stderr.writeln('خطا در گزینه‌ها: ${e.message}');
stderr.writeln(_usage);
return 2;
}
if (options.help) {
stdout.writeln(_usage);
return 0;
} 

// asset bundle بدون binding در دسترس نیست.
TestWidgetsFlutterBinding.ensureInitialized(); 

final file = File(options.datasetPath);
if (!file.existsSync()) {
stderr.writeln('دیتاست پیدا نشد: ${options.datasetPath}'); return 2; } final EvaluationDataset dataset; try { dataset = EvaluationDataset.fromJsonString(file.readAsStringSync()); } on FormatException catch (e) { stderr.writeln('دیتاست نامعتبر است: ${e.message}');
return 2;
} 

final engine = KnowledgeEngine();
await engine.load();
final knownLaws = engine.catalog.map((l) => l.id).toSet();
final problems = dataset.validate(knownLawIds: knownLaws);
if (problems.isNotEmpty) {
stderr.writeln('ایرادهای دیتاست:');
for (final p in problems) {
stderr.writeln(' • $p');
}
return 2;
} 

final net = _loadIntentNet();
final templates = _loadTemplates();
final logger = DebugLogger(
enabled: options.trace || options.tracesPath != null,
sinks: options.trace
? <DebugSink>[ConsoleDebugSink(verbose: options.verbose)]
: const <DebugSink>[],
); 

stdout.writeln('دیتاست: ${dataset.length} سناریو) — مدل نیت: ${net == null ? 'غیرفعال' : 'فعال'}');

final harness = EvaluationHarness(
engine,
net: net,
templates: templates,
logger: logger,
);
final report = harness.run(dataset, limit: options.limit); 

stdout.writeln(report.toText(verbose: options.verbose)); 

final jsonPath = options.jsonPath;
if (jsonPath != null) {
final out = File(jsonPath);
out.parent.createSync(recursive: true);
out.writeAsStringSync(
const JsonEncoder.withIndent(' ').convert(report.toJson()),
);
stdout.writeln('گزارش JSON: $jsonPath');
} 

final tracesPath = options.tracesPath;
if (tracesPath != null) {
final out = File(tracesPath);
out.parent.createSync(recursive: true);
out.writeAsStringSync(logger.exportJson());
stdout.writeln('ردِ دیباگ: $tracesPath');
} 

final ok = report.meets(
minIntent: options.minIntent,
minRoute: options.minRoute,
minArticles: options.minArticles,
minCitations: options.minCitation,
minHonesty: options.minHonesty,
);
if (!options.strict) return 0;
if (!ok) {
stderr.writeln(
'آستانه‌ها برآورده نشد: intent>=${options.minIntent} ' 'route>=${options.minRoute} articles>=${options.minArticles} ' 'citation>=${options.minCitation} honesty>=${options.minHonesty}',
);
return 1;
}
return 0;
} 

/// خواندن گزینه‌ها از متغیر محیطی، برای وقتی که فایل زیر flutter test
/// اجرا می‌شود و آرگومان‌های خط فرمان به main نمی‌رسند:
///
/// EVAL_ARGS="--verbose --json out/eval.json" flutter test bin/evaluate_bot.dart
List<String> _argsFromEnvironment() {
final raw = Platform.environment['EVAL_ARGS'];
if (raw == null || raw.trim().isEmpty) return const <String>[];
return raw.trim().split(RegExp(r'\s+'));
} 

Future<void> main() async {
// زیر flutter test آرگومان‌های خط فرمان به main نمی‌رسند؛ گزینه‌ها از
// EVAL_ARGS خوانده می‌شوند (نگاه کنید به _argsFromEnvironment).
final effective = _argsFromEnvironment();

if (Platform.environment['FLUTTER_TEST'] == 'true') {
// زیر flutter test باید یک test ثبت شود، وگرنه رانر «No tests ran» می‌دهد.
// کد ۲ یعنی گزینه/دیتاست نامعتبر؛ بقیهٔ کدها گزارشِ کیفیت‌اند، نه خطای ابزار.
final strictGate = Platform.environment['EVAL_STRICT'] == '1';
test('ارزیابی سرتاسری دستیار حقوقی', () async {
final code = await evaluateMain(effective);
expect(code, strictGate ? 0 : isNot(2));
});
return;
} 

exitCode = await evaluateMain(effective);
}


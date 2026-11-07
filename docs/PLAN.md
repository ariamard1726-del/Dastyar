# PLAN.md — برنامهٔ فازبندی‌شدهٔ P1 تا P5

- تاریخ: 2026-11-07 (۱۴۰۵/۰۸/۱۶)
- مبنا: یافته‌های فاز ۰ در `docs/AGENT_LOG.md` (کامیت پایه `98749d5`)
- وضعیت: پیش‌نویس، در انتظار تأیید مالک. هیچ کدی در این فاز تغییر نکرده است.

## اصلاح فرض‌ها (premise corrections)

1. premise correction: در کد نوعی به نام `RetrievalResult` وجود ندارد؛ خروجی‌های فعلی بازیابی `EngineReply` (`lib/core/models.dart:46`) و `EvidenceSet` (`lib/domain/dialogue/evidence.dart:82`) هستند. «RetrievalResult موجود» در این برنامه یعنی همین دو نوع، بدون تغییر.
2. premise correction: پرچم بازتولید parity در `tools/parity.py:15,118` برابر `--write` است، نه `--regen`. دستور درست: `python tools/parity.py --write`.
3. premise correction: `lib/domain/lawyer/legal_guides.dart` دارای 34 راهنماست (فاز ۰، B1). پس از ۳ درخت نمونهٔ P3a، باقی‌مانده **31** درخت است، نه 32.
4. premise correction: قاعدهٔ «حذف ماژول در همان فازی که جایگزینش را می‌آورد ممنوع است» با متن اولیهٔ P3b («حذف») و P4 («ادغام موتورها» و «ادغام PersianNormalizer») تعارض دارد. راه‌حل این برنامه: هر حذف به **فاز بعد از معرفی جایگزین** منتقل می‌شود (جدول «زمان‌بندی حذف‌ها» در پایین). ترتیب فازها تغییر نکرده است.

## تقسیم داده‌های ارزیابی (dev / test)

برای جلوگیری از تنظیم روی test، این تقسیم از P1 ثابت می‌شود (owner-overridable):

| نقش | فایل‌ها | دلیل |
|---|---|---|
| dev (مجاز برای تنظیم/کالیبراسیون) | `brain/eval/eval.txt`، `eval_extra.txt`، `eval_all_laws.txt`، `eval_everyday_laws.txt`، و فایل‌های تازهٔ `none_dev.txt` و `multiturn_dev.json` | هیچ‌کدام برچسب «تنظیم نشود» ندارند |
| test (فقط گزارش، هرگز برای انتخاب آستانه) | `eval_blind.txt`، `eval_v2.txt`، `eval_v3.txt`، `eval_v4.txt`، `gold500.txt`، `eval_none.txt`، و `multiturn_test.json` | سرخط هرکدام صریحاً می‌گوید «روی آن تنظیم نشود» |

گزینهٔ ردشده: استفاده از `eval_none.txt` برای کالیبراسیون؛ ردشده چون الان گیت CI است و تنظیم روی آن یعنی تنظیم روی test.

## نقشهٔ وابستگی‌ها

```
P1 ──► P4
P1 ──► P2 (اختیاری؛ P2 به P1 نیاز سخت ندارد)
P3a ──► P3b
P2, P3a, P3b ─╳─► P4   (P4 به آن‌ها نیاز ندارد)
P1..P4 ──► P5           (P5 عمداً آخر است تا مرز انتشار تمیز باشد)
```

- P1 نوع `Answer` را مصرف نمی‌کند؛ دروازهٔ ارتباط (relevance gate) فقط `EngineReply` و `EvidenceSet` موجود را بدون تغییر می‌خواند.
- P2 به schemaهای P3a نیازی ندارد.
- P3b بدون schema و چک CI از P3a شروع نمی‌شود.
- P4 به `DialogueFrame` از P1 نیاز دارد، اما به P2 و P3 نه. اگر P2/P3 ادغام نشده باشند، مرحلهٔ پاسخ در `TurnPipeline` همان `EngineReply` فعلی را برمی‌گرداند و مرحلهٔ راهنما همان `legal_guides.dart` را صدا می‌زند؛ پس P4 مستقل کار می‌کند.
- P5 از نظر فنی می‌تواند موازی P3/P4 اجرا شود، اما برای مرز انتشار تمیز، آخر قرار گرفته است.

---

## P1 — DialogueFrame + relevance gate + multi-turn eval set

**هدف:** هر نوبت پیش از چسبیدن به موضوع قبلی، با یک دروازهٔ قطعی و قابل‌ردیابی سنجیده شود تا پرسش مستقل هرگز با پروندهٔ قبلی ادغام نشود.

**فایل‌های ایجادشده**
- `lib/domain/dialogue/dialogue_frame.dart` — نوع immutable با فیلدهای `frameId`، `topicId`، `lawId`، `lastArticle`، `facts`، `pendingQuestion`، `openedAtTurn`، `lastTouchedTurn`؛ منبع یکتای «موضوع فعال».
- `lib/domain/dialogue/relevance_gate.dart` — تابع خالص `RelevanceDecision decide(String raw, DialogueFrame? frame, EngineReply rawReply, EvidenceSet rawEvidence)` با خروجی `{attach, independent, ambiguous}` و دلیل متنی برای ردیابی. قواعد: (۱) اگر پرسش خام به‌تنهایی `hasSufficientSupport` دارد و قانون top-1 با `frame.lawId` فرق دارد ⇒ independent؛ (۲) اگر `LawyerVoice.matchGuide` راهنمای دیگری از خانوادهٔ دیگر می‌دهد ⇒ independent؛ (۳) فقط وقتی attach که پرسش خام شواهد کافی ندارد و نشانگر ارجاع (ضمیر/بیضی) دارد؛ (۴) بقیه ⇒ ambiguous ⇒ پرسش روشن‌کننده، نه ادغام.
- `brain/eval/multiturn_dev.json` — حدود 40 گفتگوی چندنوبتی با انتظار `attach|independent|ambiguous` برای هر نوبت.
- `brain/eval/multiturn_test.json` — حدود 40 گفتگوی جدا؛ پیش از هر تنظیمی منجمد و هش SHA-256 آن در `AGENT_LOG.md` ثبت می‌شود.
- `bin/eval_multiturn.dart` — ارزیاب CLI که گفتگوها را از مسیر واقعی `ChatController.submit` اجرا می‌کند (برخلاف `evaluation_harness.dart:106-155` که `LegalCounselor` را مستقیم می‌زند).
- `brain/eval/none_dev.txt` — پرسش‌های بی‌پاسخ برای dev (پیش‌نویس از عامل، بازبینی و تأیید توسط مالک؛ متن قانون نیست).

**فایل‌های تغییرکرده**
- `lib/ui/chat_controller.dart` — در `submit` (`:250-298`) پیش از `_handleCaseReasoning` (`:286`) و `_handleGuideFollowUp` (`:290`) دروازه صدا زده می‌شود؛ در حالت `independent`، `_lastGuide`، `_facts`، `_pendingNeeds` و حافظهٔ موضوع پاک و فریم تازه باز می‌شود. وضعیت قدیمی همچنان نگه داشته می‌شود ولی از فریم همگام می‌شود (هیچ ماژولی حذف نمی‌شود).
- `lib/domain/dialogue/conversation_memory.dart` — `resolveFollowUp` (`:84-102`) فقط وقتی بازنویسی می‌کند که دروازه `attach` داده باشد.
- `docs/AGENT_LOG.md` — ثبت هش `multiturn_test.json`.

**فایل‌های حذف‌شده:** هیچ.

**تست‌های جدید**
- `test/domain/dialogue/dialogue_frame_test.dart` — immutability؛ `copyWith` فقط فیلد هدف را تغییر می‌دهد؛ سریال‌سازی رفت‌وبرگشت برابر است.
- `test/domain/dialogue/relevance_gate_test.dart` — برای هر قاعدهٔ ۱ تا ۴ دست‌کم یک مورد مثبت و یک منفی؛ پرسشی با قانون top-1 متفاوت و شواهد کافی هرگز `attach` نمی‌گیرد؛ خروجی برای ورودی یکسان قطعی است.
- `test/ui/derailment_regression_test.dart` — گفتگوهای واقعی: راهنمای چک ← «برای مهریه کجا شکایت کنم» به راهنمای چک نمی‌چسبد؛ راهنمای اجاره ← «بله» بعد از پرسش ما همچنان attach است؛ پرسش مستقل پس از راهنما پاسخ پروندهٔ قبلی را تکرار نمی‌کند.
- `test/eval/multiturn_eval_test.dart` — `multiturn_dev.json` را اجرا و آستانهٔ حداقلی را چک می‌کند؛ `multiturn_test.json` فقط گزارش می‌شود (بدون assert روی عدد)، و هشش با مقدار ثبت‌شده برابر است.

**اثر بر CI**
- باید دوباره اجرا شوند: `flutter analyze --fatal-warnings`، `flutter test` (تعداد تست از 529 بیشتر می‌شود)، `python tools/check.py all`.
- ممکن است تغییر کند: هیچ‌کدام از گیت‌های پایتون (موتور بازیابی دست نمی‌خورد؛ parity بدون تغییر).
- گیت جدید: `dart run bin/eval_multiturn.dart --check --set brain/eval/multiturn_dev.json` در `.github/workflows/test.yml`.

**ریسک‌ها و کاهش‌ها**
- ریسک: دروازه پیگیری‌های واقعی را «independent» بداند و گفتگو بریده شود. کاهش: حالت `ambiguous` به‌جای حدس، پرسش روشن‌کننده می‌دهد؛ معیار «پیگیری درست attach شد» در dev سنجیده می‌شود.
- ریسک: دو منبع وضعیت (فریم و فیلدهای قدیمی) از هم جدا شوند. کاهش: فیلدهای قدیمی فقط از فریم نوشته شوند؛ تست همگامی در `derailment_regression_test.dart`.
- ریسک: سناریوهای چندنوبتی با پیش‌نویس عامل سوگیری داشته باشند. کاهش: مالک نمونه‌ای را بازبینی و تأیید می‌کند؛ test پیش از هر تنظیم منجمد می‌شود.

**بازگشت (rollback):** `git revert` کامیت ادغام P1. چون هیچ ماژولی حذف نشده و موتور تغییر نکرده، revert کامل و بی‌اثر جانبی است.

**تغییر قابل‌مشاهده در اپ:** وقتی کاربر بعد از گفتگو دربارهٔ یک موضوع (مثلاً چک برگشتی) سؤال کاملاً تازه‌ای می‌پرسد (مثلاً دربارهٔ مهریه)، دستیار دیگر جواب را به پروندهٔ قبلی گره نمی‌زند و دربارهٔ موضوع تازه پاسخ می‌دهد. اگر معلوم نباشد کاربر ادامهٔ همان موضوع را می‌پرسد یا موضوع جدید، دستیار کوتاه می‌پرسد «منظورتان ادامهٔ همان ماجراست یا موضوع تازه؟». پاسخ‌های کوتاهی مثل «بله» یا «نه» بعد از پرسش دستیار مثل قبل کار می‌کنند.

**شرایط ورود:** فاز ۰ در `AGENT_LOG.md` ثبت شده؛ این PLAN.md تأیید مالک را گرفته؛ تقسیم dev/test بالا تأیید شده.

**شرایط خروج:** همهٔ تست‌های جدید سبز با دستور و خروجی ثبت‌شده؛ همهٔ گیت‌های C9 سبز (یا UNVERIFIED با دستور)؛ هش `multiturn_test.json` پیش از هر تنظیم در لاگ ثبت شده؛ گزارش `eval_multiturn` روی dev و test با n در لاگ آمده؛ هیچ ماژولی حذف نشده.

---

## P2 — Answer sealed type + single retrieval call + two-stage retrieval + generic-article penalty + calibrated thresholds

**هدف:** هر نوبت دقیقاً یک فراخوانی بازیابی داشته باشد، نتیجه‌اش یک نوع بسته و صریح (`Answer`) باشد، و رد/پل با آستانه‌هایی که روی dev کالیبره شده‌اند تصمیم بگیرد.

**فایل‌های ایجادشده**
- `lib/domain/answer.dart` — `sealed class Answer` با زیرنوع‌های `Grounded(hits, evidence)`، `Bridge(hits, reason)`، `NotFound(reason)`، `Refused(reason)`؛ جایگزین تشخیص رشته‌ای «پیدا نشد».
- `tools/calibrate.py` — آستانه‌ها را فقط از فایل‌های dev (`eval.txt`، `eval_extra.txt`، `eval_all_laws.txt`، `eval_everyday_laws.txt`، `none_dev.txt`) محاسبه می‌کند و از خواندن فایل‌های test امتناع می‌کند (assert روی نام فایل).
- `assets/brain/calibration.json` — خروجی ایستا: `refuseBelow`، `bridgeBelow`، n هر مجموعه، تاریخ و هش ورودی‌ها.
- `brain/reports/calibration.txt` — گزارش منحنی دقت/پوشش روی dev.

**فایل‌های تغییرکرده**
- `lib/domain/search/retrieval_pipeline.dart` — ثابت‌های `:34,37` از `calibration.json` خوانده می‌شوند؛ متد تازهٔ `Answer retrieveAnswer(...)`.
- `lib/core/engine.dart` — بازیابی دومرحله‌ای (مرحلهٔ ۱: انتخاب قانون/فصل؛ مرحلهٔ ۲: رتبه‌بندی ماده درون آن) و جریمهٔ ماده‌های عمومی (مثل `constitution اصل 50` که در `near_miss.txt:17,25,27` بی‌ربط برنده شده) با فهرست صریح و قابل‌ردیابی.
- `tools/eval_py.py` — آینهٔ پایتونِ همان دومرحله‌ای و جریمه (برابری C8).
- `lib/domain/assistant.dart` — از `Answer` استفاده می‌کند و `engine.query` را دوباره صدا نمی‌زند.
- `lib/ui/chat_controller.dart` — حذف فراخوانی دوم `engine.query` (`:1292`) و مقایسهٔ رشته‌ای (`:1297-1298`)؛ استفاده از `Answer`.
- `lib/domain/legal_counselor.dart` — جایگزینی تشخیص زیررشته‌ای «پیدا نکردم» (`:1236`) با `Answer`.
- `lib/domain/lawyer/lawyer_voice.dart` — امضای `frameEngineAnswer` (`:908`) به‌جای `notFoundRaw` نوع `Answer` می‌گیرد.
- `brain/parity_expected.json` — **توسط عامل ساخته نمی‌شود.** مالک پس از ادغام هر دو سمت اجرا می‌کند: `python tools/parity.py --write`. ادغام تا آن زمان مسدود است.
- `tools/check.py` — بخش تازهٔ `calibration` (تازگی `calibration.json` نسبت به هش فایل‌های dev).

**فایل‌های حذف‌شده:** هیچ (تشخیص رشته‌ای فقط از مسیر فراخوانی خارج می‌شود؛ کلید `not_found` در `assets/replies.json` باقی می‌ماند چون متن نمایشی است).

**تست‌های جدید**
- `test/domain/answer_test.dart` — هر زیرنوع از ورودی متناظر ساخته می‌شود؛ `switch` جامع بدون `default` کامپایل می‌شود.
- `test/domain/search/single_retrieval_test.dart` — با یک `KnowledgeEngine` شمارنده، هر نوبت `_ask` دقیقاً یک بار بازیابی صدا می‌زند.
- `test/engine/generic_penalty_test.dart` — سه پرسش `near_miss.txt:17,25,27` دیگر `constitution اصل 50` را top-1 نمی‌گیرند؛ پرسش مستقیم «اصل ۵۰ قانون اساسی» همچنان همان را برمی‌گرداند.
- `test/engine/two_stage_test.dart` — برای پرسش با نام صریح قانون، مرحلهٔ ۱ همان قانون را انتخاب می‌کند؛ رتبه‌بندی قطعی است.
- `test/domain/search/calibration_load_test.dart` — آستانه‌ها از asset خوانده می‌شوند و با `calibration.json` برابرند.
- `tools/test_calibrate.py` — `calibrate.py` با ورودی فایل test خطا می‌دهد.

**اثر بر CI**
- باید دوباره اجرا شوند: همهٔ گیت‌های C9.
- ممکن است تغییر کنند: `eval_py.py --check` (اعداد r@1 تغییر می‌کنند؛ آستانه‌های `tools/eval_py.py:449-454` پایین آورده نمی‌شوند)، `eval_none.py --check`، `parity` (نیاز به `--write` توسط مالک)، `near_miss.txt` (بازتولید خودکار در CI).
- گیت جدید: `python tools/check.py calibration`.

**ریسک‌ها و کاهش‌ها**
- ریسک: دومرحله‌ای، recall ماده‌های بین‌قانونی را کم کند. کاهش: اگر مرحلهٔ ۱ مطمئن نباشد، به رتبه‌بندی تک‌مرحله‌ای فعلی برمی‌گردد؛ گزارش قبل/بعد روی dev و test.
- ریسک: جریمهٔ عمومی پاسخ درست را از بین ببرد. کاهش: جریمه فقط برای ماده‌هایی است که در near_miss بی‌ربط برنده شده‌اند و ارجاع مستقیم را دور می‌زند؛ تست مثبت برای ارجاع مستقیم.
- ریسک: کالیبراسیون روی n کوچک ناپایدار باشد. کاهش: گزارش بازهٔ اطمینان در `calibration.txt`؛ در صورت تردید، آستانهٔ محافظه‌کارانه‌تر (C5).
- ریسک: ادغام قبل از parity. کاهش: ادغام تا اجرای `python tools/parity.py --write` توسط مالک مسدود است.

**بازگشت:** `git revert` کامیت ادغام P2 و سپس اجرای `python tools/parity.py --write` توسط مالک روی کد بازگشته. `calibration.json` با revert حذف و ثابت‌های قدیمی برمی‌گردند.

**تغییر قابل‌مشاهده در اپ:** برای پرسش‌های عمومی و مبهم، دستیار دیگر یک ماده‌ی بی‌ربط (مثل اصل ۵۰ قانون اساسی) را به‌عنوان جواب نمی‌آورد. در موارد مرزی، بیشتر صادقانه می‌گوید «در منابعم پاسخ مطمئنی نیست» یا ماده‌ی نزدیک را با برچسب «شاید این مرتبط باشد» نشان می‌دهد. پاسخ‌ها کمی سریع‌تر می‌آیند چون هر پرسش یک بار جست‌وجو می‌شود.

**شرایط ورود:** P0 ثبت شده؛ `brain/eval/none_dev.txt` توسط مالک تأیید شده (از P1، یا در صورت اجرای P2 پیش از P1، در شروع P2)؛ تقسیم dev/test منجمد است.

**شرایط خروج:** همهٔ گیت‌های C9 سبز؛ `calibration.json` فقط از dev ساخته شده (ثابت‌شده با `tools/test_calibrate.py`)؛ مالک `python tools/parity.py --write` را اجرا و نتیجه را کامیت کرده؛ گزارش قبل/بعد روی همهٔ مجموعه‌ها با n در لاگ.

---

## P3a — Schema for issues/deadlines/templates + deadlines.json + CI verify-deadlines + 3 representative issue trees

**هدف:** مهلت‌ها و درخت‌های موضوعی از داده‌ای بیرون بیایند که هر عدد و مدتش با نقل‌قول دقیق از متن رسمی ماده در CI راستی‌آزمایی می‌شود.

**فایل‌های ایجادشده**
- `assets/schema/issue.schema.json` — ساختار درخت موضوع: `id`، `family`، `triggers`، `excludes`، `nodes[]` (`question`، `slot`، `next`)، `refs[]`، `deadlineIds[]`، `templateIds[]`.
- `assets/schema/deadline.schema.json` — `id`، `lawId`، `article`، `quote` (برش دقیق از متن ماده)، `value`، `unit`، `appliesTo`.
- `assets/schema/template.schema.json` — ساختار فعلی قالب‌ها به‌اضافهٔ `reviewed`، `reviewedBy`، `reviewedAt`.
- `assets/deadlines.json` — فقط مهلت‌های سه درخت نمونه؛ هر ورودی `quote` دارد.
- `assets/issues/cheque_bounced.json`، `assets/issues/labor_dismissal.json`، `assets/issues/eviction.json` — سه درخت نمونه (شناسه‌ها هنگام اجرا با `legal_guides.dart` تطبیق داده می‌شوند؛ اگر نام راهنمای موجود فرق داشت، همان نام موجود حفظ می‌شود).
- `lib/domain/issues/issue_repository.dart` — بارگذار و اعتبارسنج سمت دارت.
- `tools/verify_deadlines.py` — برای هر ورودی `deadlines.json`: `quote` باید عیناً (پس از نرمال‌سازی `PersianText`/`brain/common.py`) در متن ماده موجود باشد و `value/unit` در `quote` آمده باشد.

**فایل‌های تغییرکرده**
- `tools/check.py` — بخش‌های تازهٔ `schema` و `deadlines` در `COMMANDS` (`:456-462`).
- `lib/domain/lawyer/lawyer_voice.dart` — برای سه موضوع نمونه، متن مهلت از `deadlines.json` با نقل‌قول ماده ساخته می‌شود؛ بقیه دست‌نخورده.
- `lib/domain/lawyer/legal_guides.dart` — سه راهنمای نمونه رشته‌های مدت سخت‌کد را با `deadlineIds` عوض می‌کنند (راهنماها حذف نمی‌شوند).
- `pubspec.yaml` — افزودن `assets/issues/`، `assets/schema/`، `assets/deadlines.json`.
- `test/domain/lawyer_voice_test.dart` — تست `:127` که «بیست روز» را سخت‌کد چک می‌کند، به چک برابری با `deadlines.json` تبدیل می‌شود.

**فایل‌های حذف‌شده:** هیچ.

**تست‌های جدید**
- `test/domain/issues/issue_schema_test.dart` — هر فایل `assets/issues/*.json` با schema معتبر است؛ هر `ref` با `findArticle` پیدا می‌شود؛ هر `deadlineId` در `deadlines.json` هست.
- `test/domain/issues/deadline_grounding_test.dart` — سمت دارتِ همان قاعدهٔ `verify_deadlines.py` (برابری C8).
- `test/domain/issues/sample_trees_test.dart` — برای هر درخت نمونه، یک گفتگوی سه‌نوبتی از ریشه به برگ می‌رسد و متن نهایی شامل `quote` ماده است.
- `tools/test_verify_deadlines.py` — یک `quote` جعلی شکست می‌خورد؛ یک `value` ناهمخوان با `quote` شکست می‌خورد.

**اثر بر CI**
- باید دوباره اجرا شوند: همهٔ گیت‌های C9.
- ممکن است تغییر کنند: `check.py all` (دو بخش تازه)؛ `flutter test` (تست‌های جدید). موتور بازیابی و parity تغییر نمی‌کنند.
- گیت جدید: `python tools/check.py deadlines` و `python tools/check.py schema`.

**ریسک‌ها و کاهش‌ها**
- ریسک: مهلتی که الان در راهنما هست در متن ماده‌ی واردشده پیدا نشود. کاهش: عامل متن را «درست» نمی‌کند؛ آن مهلت در گزارش با برچسب «مبنا در متن پیدا نشد» به مالک داده می‌شود و تا تأیید از پاسخ حذف می‌شود (C4، C5).
- ریسک: schema بیش از حد سخت باشد و مهاجرت P3b را کند کند. کاهش: سه نمونه عمداً از سه خانوادهٔ متفاوت (چک، کار، اجاره) انتخاب شده‌اند تا schema پیش از P3b آزموده شود.

**بازگشت:** `git revert` کامیت ادغام P3a؛ سه راهنمای نمونه به رشته‌های قبلی برمی‌گردند. هیچ دادهٔ قانونی تغییر نکرده است.

**تغییر قابل‌مشاهده در اپ:** در سه موضوع چک برگشتی، اخراج از کار و تخلیه، وقتی دستیار مهلتی را می‌گوید (مثلاً «ظرف چند روز»)، کنارش جمله‌ی دقیق ماده‌ی قانونی که آن مهلت را تعیین می‌کند هم نشان داده می‌شود. اگر مهلتی در متن رسمی پیدا نشود، دستیار آن را نمی‌گوید. بقیه‌ی موضوع‌ها هیچ تغییری ندارند.

**شرایط ورود:** P0 ثبت شده؛ مالک سه موضوع نمونه را تأیید کرده؛ P1 و P2 لازم نیستند.

**شرایط خروج:** `python tools/check.py deadlines` و `schema` سبز؛ همهٔ گیت‌های C9 سبز؛ فهرست مهلت‌های «مبنا پیدا نشد» (اگر باشد) در لاگ برای مالک ثبت شده؛ هیچ ماژولی حذف نشده.

---

## P3b — Migrate the remaining 31 issue trees + remove CaseReasoner outcome prediction

**هدف:** همهٔ 31 راهنمای باقی‌مانده به درخت داده‌محور و مهلت‌های نقل‌قول‌شده منتقل شوند و برآورد نتیجهٔ پرونده («شانس») از برنامه حذف شود.

**فایل‌های ایجادشده**
- `assets/issues/<guide_id>.json` — 31 فایل، یکی برای هر راهنمای باقی‌مانده در `legal_guides.dart` (شناسه‌ها عیناً از `id:`های فعلی).
- ورودی‌های تازه در `assets/deadlines.json` (همان فایل P3a؛ بزرگ‌تر می‌شود).
- `brain/reports/deadlines_unverified.txt` — فهرست مهلت‌هایی که مبنایشان در متن پیدا نشد، برای تصمیم مالک.

**فایل‌های تغییرکرده**
- `lib/domain/lawyer/case_reasoner.dart` — `FollowUpKind.chance` (`:22,251-252`) دیگر به `chance()` (`:546-643`) نمی‌رود؛ به پاسخ ثابت «پیش‌بینی نتیجه ممکن نیست» + فهرست مدارک لازم (`evidenceNeeded`) هدایت می‌شود. بدنهٔ `chance()` حذف می‌شود (جایگزینی ندارد؛ حذف ویژگی است، نه ماژول).
- `lib/domain/lawyer/lawyer_voice.dart` — همهٔ موضوع‌ها از `IssueRepository` خوانده می‌شوند؛ `legal_guides.dart` فقط به‌عنوان مسیر پشتیبان در صورت نبود فایل issue.
- `lib/domain/lawyer/legal_guides.dart` — رشته‌های مدت سخت‌کد باقی‌مانده با `deadlineIds` عوض می‌شوند؛ خود فایل **حذف نمی‌شود** (حذف در P4).
- `test/domain/case_reasoner_test.dart` — تست‌های `chance` به انتظار پاسخ ثابت تغییر می‌کنند.

**فایل‌های حذف‌شده:** هیچ فایلی. (تابع `CaseReasoner.chance` حذف می‌شود.)

**تست‌های جدید**
- `test/domain/issues/all_trees_test.dart` — 34 فایل issue وجود دارد؛ هرکدام با schema معتبر است؛ هر `id` یک‌بار؛ مجموعهٔ شناسه‌ها با `legal_guides.dart` برابر است.
- `test/domain/lawyer/no_outcome_prediction_test.dart` — برای همهٔ عبارت‌های `FollowUpKind.chance` در `case_reasoner.dart:252`، خروجی شامل «نقاط قوت شما»، «ارزیابی اولیه»، «درصد» یا «٪» نیست و شامل پیام «پیش‌بینی نتیجه ممکن نیست» است.
- `test/domain/issues/guide_parity_test.dart` — برای همهٔ پرسش‌های رایج `test/domain/lawyer_voice_test.dart:60-72`، راهنمای انتخاب‌شده از مسیر issue همان راهنمای قبلی است.

**اثر بر CI**
- باید دوباره اجرا شوند: همهٔ گیت‌های C9 و `check.py deadlines`/`schema`.
- ممکن است تغییر کنند: `flutter test` (تست‌های `chance` بازنویسی می‌شوند). موتور و parity تغییر نمی‌کنند.

**ریسک‌ها و کاهش‌ها**
- ریسک: مهاجرت 31 درخت خطای انسانی وارد کند. کاهش: `guide_parity_test.dart` رفتار مسیریابی را قفل می‌کند؛ مهاجرت در کامیت‌های کوچک به‌ازای هر خانواده.
- ریسک: کاربر حذف «شانس» را بی‌فایدگی بداند. کاهش: جایگزین آن فهرست مدارک و گام بعدی است، نه سکوت؛ این تصمیم ناشی از C5 و فهرست شکست‌های فاز است.
- ریسک: بخشی از مهلت‌ها مبنای متنی نداشته باشد. کاهش: آن‌ها از پاسخ حذف و در `deadlines_unverified.txt` برای مالک فهرست می‌شوند.

**بازگشت:** `git revert` کامیت‌های P3b (به‌ترتیب معکوس هر خانواده). چون `legal_guides.dart` باقی مانده، revert جزئی به‌ازای هر خانواده هم ممکن است.

**تغییر قابل‌مشاهده در اپ:** وقتی کاربر می‌پرسد «شانس دارم؟» یا «برنده می‌شوم؟»، دستیار دیگر نقاط قوت و ضعف و «ارزیابی اولیه» نمی‌دهد. صادقانه می‌گوید نتیجه‌ی پرونده قابل پیش‌بینی نیست و به‌جایش می‌گوید چه مدارکی مهم است و قدم بعدی چیست. در همه‌ی موضوع‌ها، هر مهلتی که دستیار می‌گوید با جمله‌ی دقیق ماده‌ی قانونی همراه است.

**شرایط ورود:** P3a ادغام شده و `python tools/check.py deadlines` و `schema` در CI سبزند.

**شرایط خروج:** 34 فایل issue معتبر؛ `no_outcome_prediction_test.dart` سبز؛ همهٔ گیت‌های C9 سبز؛ `deadlines_unverified.txt` به مالک تحویل شده.

---

## P4 — TurnPipeline refactor + engine merge + layering test + PersianNormalizer merge into PersianText with parity regen

**هدف:** هر نوبت از یک خط لولهٔ مرحله‌ای و قابل‌ردیابی بگذرد که وضعیت را فقط در `DialogueFrame` نگه می‌دارد، و لایه‌ها و نرمال‌سازی فارسی یکتا شوند.

**فایل‌های ایجادشده**
- `lib/domain/turn/turn_pipeline.dart` — مراحل مرتب و صریح: `normalize → gate (P1) → intent signals → retrieve → compose → guard`. هر مرحله یک `StageResult` با دلیل برای `DebugLogger` برمی‌گرداند. اگر P2 ادغام نشده باشد، مرحلهٔ retrieve همان `EngineReply` را برمی‌گرداند؛ اگر P3 ادغام نشده باشد، مرحلهٔ compose همان `legal_guides.dart` را صدا می‌زند.
- `lib/domain/turn/turn_stage.dart` — رابط مرحله و `StageResult`.
- `test/architecture/layering_test.dart` — قاعدهٔ لایه‌ها را با خواندن importها اجرا می‌کند.

**فایل‌های تغییرکرده**
- `lib/ui/chat_controller.dart` — زنجیرهٔ ۱۶ شرط `submit` (`:260-294`) به یک فراخوانی `TurnPipeline.run` تبدیل می‌شود؛ هندلرها به‌عنوان مرحله‌های pipeline نگه داشته می‌شوند، با همان ترتیب فعلی.
- `lib/core/engine.dart` — import `domain/dialogue/evidence.dart` (`:14`) حذف و `EvidenceSet`/`Evidence` به `lib/core/evidence.dart` منتقل می‌شوند.
- `lib/core/evidence.dart` (ایجاد) و `lib/domain/dialogue/evidence.dart` — یک re-export موقت برای جلوگیری از شکستن importها (حذف در P5).
- `lib/core/persian_text.dart` — افزودن `normalizeForMatching` و `tokens` و منطق `_suffixes`/`_verbPrefix` از `PersianNormalizer` (`lib/core/utils/persian_normalizer.dart:51,77,88,91,99`).
- `lib/core/utils/persian_normalizer.dart` — به یک shim منسوخ (`@Deprecated`) تبدیل می‌شود که به `PersianText` ارجاع می‌دهد (حذف در P5، طبق قاعدهٔ «حذف بعد از جایگزین»).
- `lib/core/router.dart`، `lib/domain/search/retrieval_pipeline.dart`، `lib/domain/dialogue/conversation_memory.dart`، `lib/domain/dialogue/response_composer.dart` — مهاجرت از `PersianNormalizer` به `PersianText`.
- `brain/common.py` و `tools/eval_py.py` — آینهٔ پایتونِ همان تغییرات نرمال‌سازی.
- `brain/parity_expected.json` — **توسط عامل ساخته نمی‌شود.** مالک اجرا می‌کند: `python tools/parity.py --write`. ادغام تا آن زمان مسدود است.
- `lib/domain/dialogue/conversation_memory.dart` — `DialogueStateManager` و `SlotValue` تکراری (`:120,151`) حذف می‌شوند؛ جایگزین (`DialogueFrame`) در P1 معرفی شده است.
- `lib/domain/lawyer/legal_guides.dart` — داده‌های راهنما حذف می‌شوند **فقط اگر P3b ادغام شده باشد** (جایگزین در P3a/P3b معرفی شده)؛ در غیر این صورت دست‌نخورده می‌ماند.
- `README.md` (`:9`) و `docs/ARCHITECTURE.md` — اصلاح ادعای «لایهٔ یکتای متن فارسی» و توصیف pipeline.

**فایل‌های حذف‌شده**
- بخش `DialogueStateManager` و `SlotValue` تکراری در `conversation_memory.dart` (جایگزین از P1).
- شرطی: داده‌های `legal_guides.dart` اگر P3b ادغام شده باشد.
- `LegalCounselor` و `PersianNormalizer` در P4 حذف **نمی‌شوند**؛ چون جایگزین‌هایشان (`TurnPipeline` و توابع تازهٔ `PersianText`) در همین فاز معرفی می‌شوند. حذفشان در P5.

**تست‌های جدید**
- `test/architecture/layering_test.dart` — هیچ فایلی در `lib/core/` از `package:dastyar/domain/` یا `package:dastyar/ui/` import نمی‌کند؛ هیچ فایلی در `lib/domain/` از `package:dastyar/ui/` import نمی‌کند.
- `test/domain/turn/turn_pipeline_test.dart` — ترتیب مراحل ثابت است؛ هر نوبت دقیقاً یک `StageResult` پایانی دارد؛ ردیابی هر مرحله در `DebugLogger` ثبت می‌شود.
- `test/domain/turn/pipeline_equivalence_test.dart` — برای همهٔ گفتگوهای `test/audit/conversations*.txt` و `multiturn_dev.json`، خروجی pipeline با خروجی پیش از refactor برابر است (golden ضبط‌شده در شروع P4).
- `test/core/persian_text_merge_test.dart` — برای `test/domain/dialogue/golden_sentences.json`، خروجی توابع تازهٔ `PersianText` با `PersianNormalizer` قدیمی برابر است.

**اثر بر CI**
- باید دوباره اجرا شوند: همهٔ گیت‌های C9.
- ممکن است تغییر کنند: `parity` (بخش normalize/tokenize)؛ `eval_py.py --check` و `eval_none.py --check` (اگر نرمال‌سازی واقعاً رفتار را عوض کند).
- گیت جدید: `layering_test.dart` در `flutter test`.

**ریسک‌ها و کاهش‌ها**
- ریسک: refactor رفتار گفتگو را بی‌صدا تغییر دهد. کاهش: `pipeline_equivalence_test.dart` با golden ضبط‌شده پیش از هر تغییر.
- ریسک: ادغام نرمال‌سازها خروجی را عوض کند و parity بشکند. کاهش: ادغام تا اجرای `python tools/parity.py --write` توسط مالک مسدود است؛ `persian_text_merge_test.dart` تفاوت‌ها را پیش از ادغام نشان می‌دهد.
- ریسک: P4 پیش از P2/P3 اجرا شود. کاهش: مراحل pipeline برای هر دو حالت (با یا بدون `Answer` و issue) تست دارند.

**بازگشت:** `git revert` کامیت‌های P4 و سپس اجرای `python tools/parity.py --write` توسط مالک. چون `LegalCounselor` و `PersianNormalizer` هنوز حذف نشده‌اند، revert ایمن است.

**تغییر قابل‌مشاهده در اپ:** هیچ تغییر قابل‌مشاهده‌ای نیست. گفتگوها باید دقیقاً مثل قبل باشند؛ این فاز فقط ساختار داخلی را مرتب می‌کند و هر تفاوت دیده‌شده یک باگ است.

**شرایط ورود:** P1 ادغام شده (`DialogueFrame` و relevance gate موجودند)؛ golden معادل‌سازی پیش از هر تغییر ضبط شده است.

**شرایط خروج:** `layering_test.dart` و `pipeline_equivalence_test.dart` سبز؛ مالک `python tools/parity.py --write` را اجرا و کامیت کرده؛ همهٔ گیت‌های C9 سبز؛ هیچ import از core به domain باقی نمانده.

---

## P5 — Data integrity (_meta.json fields, gaps.json) + build flavors + ProGuard

**هدف:** فراداده و شکاف‌های قوانین صریح و قابل‌سنجش شوند و نسخهٔ آفلاین بدون مجوز INTERNET و بدون موتور llama ساخته شود.

**فایل‌های ایجادشده**
- `assets/laws/gaps.json` — برای هر شکاف گزارش‌شدهٔ `tools/doctor.py` (فاز ۰، D2): `lawId`، `article`، `status` با یکی از `repealed | absent_in_source | not_imported | unknown`. مقدار اولیه برای همه `unknown`؛ **فقط مالک** وضعیت را تعیین می‌کند.
- `android/app/src/offline/AndroidManifest.xml` — بدون INTERNET و بدون `overrideLibrary` برای llama.
- `android/app/src/llm/AndroidManifest.xml` — INTERNET و `overrideLibrary` فعلی (`main/AndroidManifest.xml:5-8`).
- `lib/core/llm_stub.dart` — پیاده‌سازی بی‌کار `LlmBackend` برای فلیور offline.
- `lib/main_offline.dart` و `lib/main_llm.dart` — نقطه‌های ورود دو فلیور؛ فقط `main_llm.dart` به `lib/core/llama_backend.dart` ارجاع می‌دهد.

**فایل‌های تغییرکرده**
- `android/app/build.gradle.kts` — `flavorDimensions` و `productFlavors { offline; llm }` (`:48-60`).
- `android/app/src/main/AndroidManifest.xml` — حذف INTERNET (`:5`) و `overrideLibrary` (`:8`) و انتقال به فلیور `llm`.
- `android/app/proguard-rules.pro` — قاعدهٔ keep برای `com.write4me.llama_flutter_android.**` فقط در فلیور llm (فایل `proguard-llm.pro`).
- `pubspec.yaml` — `llama_flutter_android` (`:17`) همچنان وابستگی است (Flutter فلیور-بر-وابستگی ندارد)، اما فقط از `main_llm.dart` import می‌شود و R8 در offline آن را حذف می‌کند. گزینهٔ ردشده: پکیج جداگانه؛ ردشده چون ساختار مخزن را بیش از حد تغییر می‌دهد (owner-overridable).
- `lib/main.dart` — منطق مشترک بدون import llama (`:11,115-120` به `main_llm.dart` منتقل می‌شود).
- `assets/laws/_meta.json` — افزودن فیلدهای `sourceUrl` و `retrievedBy` با مقدار خالی برای 17 قانون مشترک (فاز ۰، D1)؛ پرکردنشان کار مالک است؛ تاریخ‌ها به یک قالب رقمی یکسان می‌رسند.
- `tools/check.py` — بخش `meta` (`cmd_meta`) هم `gaps.json` را با خروجی `doctor.py` برابر می‌کند و هم فیلدهای تازه را چک می‌کند.
- `lib/ui/about_page.dart` — نمایش تعداد شکاف‌ها و وضعیتشان به‌ازای هر قانون.
- `.github/workflows/build.yml` (`:79`) — ساخت `flutter build apk --release --flavor offline -t lib/main_offline.dart` و جداگانه `--flavor llm -t lib/main_llm.dart`.
- حذف‌های معوق از P4: `lib/core/utils/persian_normalizer.dart`، re-export موقت در `lib/domain/dialogue/evidence.dart`، و `lib/domain/legal_counselor.dart` (اگر `pipeline_equivalence_test.dart` در P4 نشان دهد هیچ مرحله‌ای به آن وابسته نیست).

**فایل‌های حذف‌شده:** `lib/core/utils/persian_normalizer.dart`، `test/core/utils/persian_normalizer_test.dart` (پوشش آن پیش‌تر در `persian_text_merge_test.dart` منتقل شده)، و به‌شرط بالا `lib/domain/legal_counselor.dart`.

**تست‌های جدید**
- `test/data/gaps_test.dart` — هر شکاف `doctor.py` یک ورودی در `gaps.json` دارد و برعکس؛ هر `status` از مجموعهٔ مجاز است.
- `tools/test_manifest.py` — manifest ادغام‌شدهٔ فلیور offline (از `build/.../merged_manifests/offlineRelease`) هیچ `android.permission.INTERNET` ندارد.
- `test/app/offline_no_llama_test.dart` — گراف import از `lib/main_offline.dart` به `llama_backend.dart` نمی‌رسد.
- `test/data/meta_fields_test.dart` — هر قانون همهٔ فیلدهای لازم را دارد؛ قالب تاریخ یکسان است.

**اثر بر CI**
- باید دوباره اجرا شوند: همهٔ گیت‌های C9 به‌اضافهٔ ساخت هر دو فلیور.
- ممکن است تغییر کنند: `check.py meta`؛ `build.yml` دو APK تولید می‌کند.
- گیت جدید: `tools/test_manifest.py` بعد از ساخت offline.

**ریسک‌ها و کاهش‌ها**
- ریسک: کرش release به‌خاطر R8 (فاز ۰، E5 UNVERIFIED). کاهش: قاعدهٔ keep در llm؛ آزمون روی دستگاه واقعی توسط مالک پیش از انتشار؛ تا آن زمان UNVERIFIED.
- ریسک: کاربران فعلی که مدل نصب کرده‌اند با به‌روزرسانی offline مدلشان را از دست بدهند. کاهش: `applicationIdSuffix` جدا برای llm تا دو نسخه کنار هم نصب شوند؛ تصمیم نهایی با مالک.
- ریسک: عامل وضعیت شکاف‌ها را حدس بزند. کاهش: مقدار اولیه برای همه `unknown`؛ فقط مالک تغییرش می‌دهد.

**بازگشت:** `git revert` کامیت‌های P5. فلیورها حذف و manifest اصلی برمی‌گردد؛ `gaps.json` حذف می‌شود؛ متن قوانین در هیچ حالتی تغییر نکرده است.

**تغییر قابل‌مشاهده در اپ:** دو نسخه‌ی جدا از برنامه ساخته می‌شود. نسخه‌ی «آفلاین» اصلاً اجازه‌ی اینترنت نمی‌خواهد و گزینه‌ی دانلود مدل زبانی در آن نیست. نسخه‌ی «با مدل» مثل نسخه‌ی فعلی است. در صفحه‌ی «درباره»، برای هر قانون نشان داده می‌شود چند ماده در بانک برنامه نیست و دلیلش، اگر مالک مشخص کرده باشد، چیست.

**شرایط ورود:** P1 تا P4 ادغام شده‌اند (برای مرز انتشار تمیز)؛ مالک تصمیم `applicationId` را گرفته است.

**شرایط خروج:** هر دو فلیور در CI ساخته می‌شوند؛ `tools/test_manifest.py` روی offline سبز؛ همهٔ گیت‌های C9 سبز؛ آزمون release روی دستگاه یا انجام شده یا صریحاً UNVERIFIED ثبت شده.

---

## زمان‌بندی حذف‌ها (قاعدهٔ «حذف بعد از جایگزین»)

| مورد حذف | جایگزین معرفی‌شده در | حذف در |
|---|---|---|
| `DialogueStateManager` و `SlotValue` تکراری در `conversation_memory.dart` | P1 (`DialogueFrame`) | P4 |
| تشخیص رشته‌ای `notFoundRaw` (فقط مسیر فراخوانی) | P2 (`Answer`) | P2 (حذف کد فراخوانی، نه ماژول) |
| `CaseReasoner.chance` | — (حذف ویژگی، بدون جایگزین) | P3b |
| داده‌های `legal_guides.dart` | P3a/P3b (`assets/issues/`) | P4 (به‌شرط ادغام P3b) |
| `PersianNormalizer` | P4 (توابع تازهٔ `PersianText`) | P5 |
| `LegalCounselor` | P4 (`TurnPipeline`) | P5 (به‌شرط) |
| re-export `domain/dialogue/evidence.dart` | P4 (`core/evidence.dart`) | P5 |

## موارد قابل‌لغو توسط مالک (owner-overridable)

- تقسیم dev/test بالا.
- انتخاب سه درخت نمونهٔ P3a.
- نگه‌داشتن `llama_flutter_android` در `pubspec.yaml` به‌جای پکیج جدا (P5).
- انتقال حذف `LegalCounselor` به P5 به‌جای P4.

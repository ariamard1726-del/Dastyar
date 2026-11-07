# AGENT_LOG — دفترچهٔ فازهای عامل

این فایل حافظهٔ بین‌فازی است. هر فاز در انتهای فایل اضافه می‌شود (append-only).
ادعاهای UNVERIFIED تا وقتی فایل/دستور نام‌برده اجرا نشده، باز می‌مانند.

---

## Phase 0 — Audit (read-only)

- تاریخ: 2026-11-07 (۱۴۰۵/۰۸/۱۶)
- کامیت پایه: `98749d5` (main؛ تنها تفاوتش با `7ea7d43` فایل `reports/last_test.txt` است)
- شاخه: `audit/phase-0`

### خلاصهٔ یافته‌ها

اندازهٔ مخزن با فرض‌ها می‌خواند: `lib/` = 20,822 سطر، `test/` = 7,629، `bin/` = 273 (جمعاً 28,724)؛ 24 قانون؛ 5,688 ماده طبق `assets/laws/_meta.json`؛ 529 تست طبق `reports/last_test.txt:2` (آخرین اجرای CI روی `7ea7d43`). سه موتور گفتگو (LegalCounselor 1,942 + dialogue/ 3,878 + lawyer/ 4,103 = 9,923 سطر؛ با `chat_controller.dart` 1,521 سطر می‌شود 11,444) وضعیت موضوع، اسلات‌ها و «پرسش در انتظار» را هرکدام جداگانه نگه می‌دارند (۶ نگه‌دارندهٔ موضوع، ۴ مخزن فکت، ۴ نگه‌دارندهٔ پرسش معلق). `ChatController.submit` زنجیرهٔ مرتب if/return با ۱۶ نگهبان پیش از `_ask` است؛ `_handleSmallTalk` تنها فیلتر پیش از بازیابی نیست. آستانه‌های `refuseBelow=0.50` و `bridgeBelow=0.65` هیچ فایل کالیبراسیونی پشتشان نیست. تشخیص «پیدا نشد» رشته‌ای است (برابری دقیق در chat_controller و زیررشته در legal_counselor) و هر نوبتِ `_ask` دست‌کم دو بار `engine.query` اجرا می‌کند. ادعای «اصل ۵۰ قانون اساسی» تأیید شد (۳ پرسش بی‌ربط). مولد `/tmp/build_intent_data.py` در مخزن نیست و هیچ سنجش «کاربر واقعی» برای IntentNet وجود ندارد (فقط 0.9653 روی 144 نمونهٔ دست‌نویس). ارزیاب ۲۸ سناریویی مستقیم `LegalCounselor.stepTraced` را صدا می‌زند و مسیر واقعی `ChatController.submit` را نمی‌سنجد. ۱۷ قانون تاریخ `1405/08/10` و منبع «اختبار» مشترک دارند. ادعای «`amended` هرگز خوانده نمی‌شود» رد شد (فقط نمایش داده می‌شود). مهم‌ترین مورد برای C1/C6: `llama_flutter_android` وابستگی بی‌قیدوشرط در `pubspec.yaml:17` است، در `lib/main.dart:11,115-120` همیشه سیم‌کشی می‌شود، فلیور ساخت وجود ندارد، و مجوز INTERNET در manifest اصلی اعلام شده؛ وقتی مدل نصب باشد، `Assistant` پاسخ را با LLM تولید می‌کند. گارد استناد فقط شمارهٔ ماده را (بدون قانون) می‌سنجد و برای `cited.isEmpty` مقدار `true` برمی‌گرداند؛ اعداد، مبالغ و مهلت‌ها را نمی‌سنجد.

### جدول حکم‌ها

| ID | حکم | file:line | یادداشت |
|---|---|---|---|
| A1 | CONFIRMED | `lib/domain/legal_counselor.dart:89-95`، `lib/domain/dialogue/dialogue_state.dart:52-85`، `lib/domain/dialogue/conversation_memory.dart:12-17,151-181`، `lib/domain/lawyer/case_facts.dart:41-43`، `lib/ui/chat_controller.dart:49-103` | 9,923 سطر در سه موتور (با controller: 11,444). موضوع در 6 جا: `topicId`، `domain`، `lastTopicQuery/lastLawId`، `DialogueStateManager._intent`، `_lastGuide`، `_lastCounselTopic`. فکت در 4 جا: `CounselingSession.facts`، `DialogueState.slots`، `DialogueStateManager._slots`، `CaseFacts`. دو کلاس هم‌نام `SlotValue` (`slot.dart:18` و `conversation_memory.dart:120`). |
| A2 | CONFIRMED | `lib/ui/chat_controller.dart:250-298`؛ importها `:1-31` | بدنه 49 سطر؛ 26 دستور import؛ زنجیرهٔ مرتب ۱۶ نگهبان `if (...) return` در `:260-294` (به‌علاوهٔ اثر جانبی `_slots.extractAndUpdate` در `:264`) و سپس `_ask` در `:297`. |
| A3 | REFUTED (بخش اول) / CONFIRMED (بخش دوم) | `lib/ui/chat_controller.dart:277-297` | `_handleSmallTalk` (`:287`) نهمین نگهبان است؛ ۱۵ فیلتر دیگر هم پیش از `_ask` هستند و ۸ تا پیش از خودِ small talk اجرا می‌شوند (از جمله `_handleCaseReasoning` در `:286`). هر ورودی‌ای که همه را رد کند به `_ask` می‌رسد (`:296-297`). |
| A4 | CONFIRMED | `brain/reports/near_miss.txt:17,25,27` | «قیم می‌تونه ملک بچه رو بفروشه»، «چکم گم شده…جلوی پرداختش»، «قرارداد رو می‌شه یک‌طرفه به هم زد» → هر سه `constitution اصل 50`. |
| A5 | CONFIRMED | `lib/domain/search/retrieval_pipeline.dart:34,37`؛ مصرف `lib/ui/chat_controller.dart:1321-1322`؛ `coverage` در `lib/core/engine.dart:567` | ثابت‌های دستی؛ در `brain/`، `tools/`، `docs/` هیچ آرتیفکت کالیبراسیونی که 0.50/0.65 را بسازد پیدا نشد. |
| A6 | CONFIRMED | `lib/ui/chat_controller.dart:1297-1298`، `lib/domain/lawyer/lawyer_voice.dart:908,920`، `lib/domain/legal_counselor.dart:1236` | برابری دقیق رشته با `replies.get('not_found')`؛ در counselor زیررشتهٔ «پیدا نکردم/پیدا نشد». در `_ask`: query اول از `Assistant` → `retrieval_pipeline.dart:21`، query دوم `chat_controller.dart:1292` ⇒ حداقل ۲ بار در هر نوبت (به‌علاوهٔ `coverage` تا ۴ بار، `:1236`). |
| A7 | CONFIRMED (پیاده‌سازی) / UNVERIFIED (علت) | `lib/domain/dialogue/conversation_memory.dart:84-102`؛ `lib/ui/chat_controller.dart:283,286,290,305,372-416,419-440,931-954`؛ `_lastGuide` در `:74` | منطق: `words.length <= 5 && _ellipticalMarkers.any(n.contains)` → «… درباره $lastTopicQuery» (`:98-100`)؛ شمارش توکن پس از حذف ایست‌واژه (`persian_text.dart:92-99`)، تطبیق زیررشته. `_lastGuide` فقط در `:181` و `:330` پاک می‌شود. هر دو جهت (بازنویسی حافظه / هندلرهای راهنمای کهنه) UNVERIFIED؛ فایل تعیین‌کننده: `test/audit/conversations_followup.txt` با یک تست چندنوبتی روی `ChatController.submit`. |
| A8 | CONFIRMED | `assets/brain/intent_model.json:1` (metrics)، `brain/intent_data.txt:1`، `brain/train_intent.py:174,304` | `eval_accuracy 0.9653` روی `eval_samples 144` (`brain/eval/intent_eval.txt`، دست‌نویس). مولد `/tmp/build_intent_data.py` در مخزن نیست. هیچ ادعای دقت «کاربر واقعی» در مخزن پیدا نشد. |
| B1 | CONFIRMED | `lib/domain/lawyer/legal_guides.dart:85`؛ `test/domain/lawyer_voice_test.dart:40-47,127` | 34 راهنما؛ 26 رشتهٔ مدت (۴ مورد سنّ «۱۸ سال»، ۲۲ مهلت/مدت). تست فقط `findArticle(...) isNotNull` را می‌سنجد؛ `:127` خودِ «بیست روز» را تثبیت می‌کند، نه تطابقش با متن ماده. |
| B2 | CONFIRMED | `lib/domain/lawyer/case_reasoner.dart:251-252,546,620-621` | `FollowUpKind.chance` و `chance()` «ارزیابی اولیه» با نقاط قوت/ضعف می‌دهد؛ درصد عددی ندارد اما برآورد نتیجه است. |
| B3 | CONFIRMED | `lib/domain/dialogue/domain_slot_schemas.dart`، `lib/domain/legal_counselor.dart:257`، `lib/domain/dialogue/slot_extractor.dart:13`، `lib/domain/lawyer/case_facts.dart:17-43`، `lib/domain/lawyer/case_reasoner.dart:32`، `lib/domain/dialogue/conversation_memory.dart:155-159` | schemas: 20 اسلات؛ counselor: 17 (همه زیرمجموعهٔ schemas از طریق `Slots`)؛ SlotExtractor همان 20؛ CaseFacts: 7 لیست + 19 پرچم؛ CaseReasoner کلیدهای `amount/duration/evidence` + 6 پرچم؛ DialogueStateManager: `amount/proof/date/incidentType/incomeStatus`. هم‌نام بین موتورهای مستقل: 3 (`amount`، `proof`، `evidence`)؛ سه استخراج‌گر مبلغ جدا. |
| C1 | CONFIRMED | `brain/reports/near_miss.txt:2-8`، `brain/reports/ngram.txt:5-25`، `brain/eval/gold500.txt:1` | near_miss TOTAL n=178: exact@1 0.60، law@1 0.88، near@5 0.88. ngram همهٔ مجموعه‌ها n=91 واژه‌ای: r@1 0.58. `gold500.txt` 201 سطر (200 ردیف)، نه 500، و در هیچ ابزار/تستی ارجاع ندارد. |
| C2 | CONFIRMED | `brain/embed_eval.py:19`؛ گزارش‌ها در `brain/reports/embed_*.txt` | در `lib/` و `pubspec.yaml` هیچ ارجاعی به e5/MiniLM/onnx/tflite نیست. |
| C3 | CONFIRMED (با قید) | `brain/eval/evaluation_dataset.json:4`؛ `lib/domain/evaluation/evaluation_harness.dart:106-119,142-155` | 28 سناریو، 8 تا با 2 follow-up. هارنس `LegalCounselor.stepTraced` را می‌زند، نه `ChatController.submit`. `test/audit/conversation_audit_test.dart:63` چندنوبتی است ولی فقط «بی‌پاسخ نماندن» را می‌سنجد. |
| D1 | CONFIRMED | `assets/laws/_meta.json:61-189` | 17 قانون: constitution، family_protection، civil_liability، child_protection، marriage، consumer_protection، penal، penal_taazirat، fraud_intensify، cybercrime، civil_procedure، civil_execution، dispute_councils، criminal_procedure، registration، direct_taxes، social_security. `civil` هم «اختبار» است ولی تاریخ دیگر. |
| D2 | CONFIRMED (شکاف‌ها) / REFUTED («amended خوانده نمی‌شود») | `tools/doctor.py` (خروجی)؛ `lib/ui/about_page.dart:121`، `lib/ui/chat_controller.dart:532-536` | direct_taxes: 19-20، 150-154؛ registration: 96-98، 147-148؛ social_security: 98-100؛ penal: 69، 72؛ civil_procedure: 411-412. برچسب‌زنی شکاف‌ها کار فاز ۰ نیست. `amended` فقط نمایش داده می‌شود و در استدلال اثری ندارد. |
| D3 | CONFIRMED | `assets/templates/*.json:6` | reviewed=true: defense_brief، formal_notice. reviewed=false: cheque_complaint، cheque_execution، complaint، demand_money، insolvency، legal_aid. |
| E1 | CONFIRMED | `lib/core/engine.dart:14` | `import 'package:dastyar/domain/dialogue/evidence.dart';` — وابستگی core → domain. |
| E2 | CONFIRMED | `README.md:9` | README «لایهٔ یکتای متن فارسی» را به `persian_text.dart` نسبت می‌دهد؛ اما 27 فایل `lib/` از PersianText و 4 فایل (router، retrieval_pipeline، conversation_memory، response_composer) از PersianNormalizer استفاده می‌کنند. |
| E3 | CONFIRMED | `lib/core/engine.dart:73,80,83` (مصرف `:962-963,987`) | 24 کامنت «Phase N» در 13 فایل `lib/`. |
| E4 | CONFIRMED | `android/app/src/main/AndroidManifest.xml:5`؛ `android/app/build.gradle.kts:48-60` | INTERNET در manifest اصلی؛ هیچ `productFlavors` وجود ندارد. |
| E5 | CONFIRMED (پیکربندی) / UNVERIFIED (کرش) | `android/app/build.gradle.kts:50-51`؛ `android/app/proguard-rules.pro:1-9` | `isMinifyEnabled = true`؛ هیچ قاعدهٔ keep برای `com.write4me.llama_flutter_android` نیست. کرش تا ساخت و اجرای `flutter build apk --release` روی دستگاه UNVERIFIED. |
| E6 | CONFIRMED | `lib/domain/guard/citation_guard.dart:45-50,52-59,68-103` | `if (cited.isEmpty) return true;` (`:47`). فقط شمارهٔ ماده (بدون قانون) در برابر عنوان/متن کانتکست، و نام رسمی قانون. اعداد، مبالغ، مهلت‌ها را نمی‌سنجد. |

### فایل‌ها

- ایجادشده: `docs/AGENT_LOG.md`
- تغییرکرده: هیچ
- حذف‌شده: هیچ

### تست‌های اضافه‌شده

هیچ (فاز فقط‌خواندنی).

### وضعیت CI

- فاز فقط‌خواندنی؛ هیچ کدی تغییر نکرد.
- اجراشده در sandbox (کامیت `98749d5`، پس از اجرا `git status` تمیز بود):
  - `python3 tools/check.py all` → exit 0، «همهٔ بررسی‌ها سالم است»، parity: «استاندارد طلایی تازه است (text=20 conflicts=4 rank=30)». GREEN
  - `python3 tools/doctor.py` → exit 0، «قانون‌های بررسی‌شده: 24 | خطا: 0 | هشدار: 0». GREEN
  - `python3 tools/eval_py.py --check` → exit 0 (eval r@1 0.93، extra 0.80، blind 0.58، all_laws 0.90، everyday law@1 0.95). GREEN
  - `python3 tools/eval_none.py --check` → exit 0، n=28، 27 رد درست، 1 پاسخ غلط با اطمینان («شرایط پناهندگی در کشورهای اروپایی» → قانون کار مادهٔ 122). GREEN
- UNVERIFIED (Flutter در sandbox نصب نیست): `flutter analyze --fatal-warnings` و `flutter test`. آخرین گزارش CI در `reports/last_test.txt` می‌گوید 529 تست روی `7ea7d43` قبول شده و analyze بدون خطاست.

### پرسش‌های باز برای مالک

1. C1/C6: `llama_flutter_android` و مجوز INTERNET همین الان در ساخت اصلی هستند. فاز بعد فلیور `offline` (بدون INTERNET و بدون llama) بسازد و فعلی را به فلیور `llm` منتقل کند؟
2. `brain/eval/gold500.txt` فقط 200 ردیف دارد و جایی مصرف نمی‌شود؛ این «مجموعهٔ تست» دست‌نخوردنی است؟
3. ارزیاب ۲۸ سناریویی مسیر `ChatController.submit` را نمی‌سنجد؛ ارزیاب چندنوبتی جدید روی controller ساخته شود؟
4. 17 قانون با تاریخ و منبع یکسان: منبع رسمی هرکدام را خودتان تأیید/بازوارد می‌کنید؟

### وضعیت پایان فاز ۰

- فاز ۰ تمام‌شده اعلام شد (2026-11-07). به دستور مالک، PR #38 فعلاً ادغام نمی‌شود.

---

## Phase 1 — Phased plan (plan-only)

- تاریخ: 2026-11-07 (۱۴۰۵/۰۸/۱۶)
- شاخه: `audit/phase-0` (همان PR #38، ادغام‌نشده)
- برنامه: [docs/PLAN.md](PLAN.md) — شش فاز P1، P2، P3a، P3b، P4، P5؛ هرکدام با هدف، فایل‌ها، تست‌ها، اثر CI، ریسک، بازگشت، تغییر قابل‌مشاهده، شرایط ورود و خروج.

### اصلاح فرض‌ها

- نوع `RetrievalResult` وجود ندارد؛ دروازهٔ P1 روی `EngineReply` (`lib/core/models.dart:46`) و `EvidenceSet` (`lib/domain/dialogue/evidence.dart:82`) کار می‌کند.
- پرچم parity در `tools/parity.py:118` برابر `--write` است؛ دستور درست: `python tools/parity.py --write`.
- پس از ۳ درخت P3a، 31 درخت باقی می‌ماند (34 راهنما)، نه 32.
- حذف `LegalCounselor` و `PersianNormalizer` از P4 به P5 منتقل شد تا حذف در همان فاز معرفی جایگزین انجام نشود.

### فایل‌ها

- ایجادشده: `docs/PLAN.md`
- تغییرکرده: `docs/AGENT_LOG.md` (افزودن)
- حذف‌شده: هیچ

### تست‌های اضافه‌شده

هیچ (فاز فقط برنامه).

### وضعیت CI

- not run (plan-only phase). هیچ کدی تغییر نکرد.

### پرسش‌های باز برای مالک

1. تأیید کل PLAN.md (شرط خروج فاز ۱).
2. تأیید تقسیم dev/test در PLAN.md.
3. تأیید سه درخت نمونهٔ P3a (چک برگشتی، اخراج از کار، تخلیه).

# نقشهٔ راه بازسازی (وضعیت)

برنامهٔ پنج‌مرحله‌ای رفع نقاط ضعف بازبینی. روش کار «درخت‌پیچ» است: هر گام
خودش کامل، آزمون‌دار و برگشت‌پذیر است؛ هیچ بازنویسی یک‌جا انجام نمی‌شود.

وضعیت: ✅ انجام‌شده · 🟡 **بدهی موقت** (نگهبان دارد، ولی رفع نشده) · ⏳ نیمه‌کاره · ⬜ انجام‌نشده

## مرحلهٔ ۰ — بندآوردن خون‌ریزی

| کار | وضعیت | یادداشت |
|---|---|---|
| مجوز پروژه | ✅ | `LICENSE` (MIT) + بندهای شخص ثالث (Noql، متن قوانین) |
| شفاف‌بودن متن تأییدنشده | ✅ | از پیش در `KnowledgeEngine.format` و صفحهٔ «درباره» بود؛ حالا در README هم هست |
| ارجاع‌های شکسته، خطا شوند | ✅ | `dev/tools/data_refs.py` + `check.py refs` (۱۹۷ ارجاع) |
| ساختار دادهٔ موضوع، نگهبان پیدا کند | ✅ | `dev/tools/topic_schema.py` + اسکیما + `check.py topics` |
| دادهٔ مرده آشکار شود | ✅ | `live:false` در بستهٔ برنامه خطاست؛ دو مسیر غیرفعال به `lab/topics/` رفتند (از APK بیرون) |
| ترتیب خط لوله، تک‌منبع شود | ✅ | `assets/pipeline.json` + `pipeline_check.py` + آزمون Dart |
| ساخت release فقط با کلید امضا | ✅ (از پیش) | `build.gradle.kts` بدون `ALLOW_DEBUG_SIGNING` می‌شکند |

## مرحلهٔ ۱ — دانش به‌جای کد

| کار | وضعیت | یادداشت |
|---|---|---|
| اسکیمای مسیر موضوعی | ✅ | `dev/tools/schemas/topic_flow.schema.json` |
| پروندهٔ گفتگو قابل‌سریال‌شدن | ✅ | `CaseFile.toJson/fromJson` + آزمون |
| ذخیره و بازیابی پرونده در تاریخچه | ✅ | `caseJson` داخل محمولهٔ رمزنگاریشدهٔ هر گفتگو (`_format = 4`) + `Advocate.restoreCase(json, dialogue: …)`؛ آزمون با `HistoryStore` تازه (راهاندازی مجدد)؛ قالب قدیمی با بازپخش پیام باز میشود |
| انتقال `rent.dart` (۲٬۶۷۶ خط) به JSON | 🟡 | ۴۲ متنِ `rent_bodies*`، ۸۷ متنِ ادعا، ۳۲ برچسبِ سند و ۱۹ متنِ طرحِ دعوا به چهار جدولِ `rent_texts.json` رفتند و هشِ نویسهبهنویسه قفل است؛ رشتههای محلیِ داخلِ توابع و بقیهٔ موضوعها هنوز Dartمحوراند |
| حذف `live:false` از APK | ✅ | `rent.json`/`labor_wages.json` در `lab/topics/`؛ آزمون‌هایشان همچنان اجرا می‌شوند |
| جایگزینی closureها (`Reader/Body/Tri`) با شناسهٔ قاعده | ⬜ | پیش‌نیاز سریال‌شدن کامل `Topic` |

## مرحلهٔ ۲ — یک داور، نه زنجیرهٔ ۷۵۰ خطی

| کار | وضعیت | یادداشت |
|---|---|---|
| نوع `AnswerCandidate {source, confidence, why}` | ✅ | `answer_candidate.dart` هر کاندید را نامدار میکند و `AnswerDecision` نام، منبع، دلیل و پاسخِ برنده را نگه میدارد؛ `Advocate.lastDecision` برای بازرسی. ترتیب و رفتار عوض نشد؛ `test/advocate/answer_candidate_test.dart` و `tests/python/test_reply_pipeline_candidate_contract.py` نگهباناند |
| جدول خط لوله از JSON به‌جای `if`های زنجیره‌ای | ⏳ | ترتیب و آستانه‌ها داده‌ای شد؛ اجرا هنوز `_reply` است |
| تصمیم دربارهٔ `IntentNet` و `Noql` | ✅ | مقایسهٔ چهار مجموعهٔ نگهداشته (`reports/intent_holdout.md`) نتیجهٔ یکسانی با و بدون IntentNet داد (۵/۱۱، ۶/۹، ۵/۹، ۴/۸). اپ فقط Noql را بار میکند؛IntentNet و مدلش فقط برای سنجش قابلتکرار نگه داشته شدهاند (`tests/python/test_classifier_choice.py`) |
| `NoqlEncoder` دستنویس — **دارایی اصلی، حفظشده** | ✅ | مدل ۱۲٫۳ MB در `assets/brain/noql.bin` عمداً در APK میماند: تنها مسیر حدس موضوع است (در Isolate، بارگذاری تنبلی، ۱۲s تایمـاوت) و دقتش در `reports/noql_finetune.md` ثبت شده است. چهار فایل `assets/brain/noql*` توسط `check.py noql` و `tests/python/test_noql_assets_guard.py` نگهبانی میشوند. بهینهسازی حافظهٔ `embed` فعلاً انجام نمیشود (ریاضیات حساس، ۳۴۶ms در پسزمینه قابلقبول است) |

## مرحلهٔ ۳ — ذخیره‌سازی، رمزنگاری، رشتهٔ رابط کاربری

| کار | وضعیت | یادداشت |
|---|---|---|
| SQLite + SQLCipher به‌جای SharedPreferences | ⬜ | کوئری، ایندکس و مهاجرت واقعی |
| رمزنگاری دست‌نویس حذف شود | ✅ | SHA-256/HMAC از `package:crypto`؛ بردارهای RFC در آزمون |
| کلید فقط در Keystore (بدون fallback) | ✅ | اندروید از Keystore استفاده میکند؛ مسیر جایگزین کلید را فقط در حافظهٔ همان اجرا نگه میدارد، آن را در SharedPreferences نمینویسد، کلید قدیمی را پاک میکند و دادهٔ اجرای قبل را fail-closed رد میکند (`test/core/privacy_test.dart`) |
| خطای ذخیرهٔ تنظیمات دیده شود | ✅ | `AppSettings.lastError` + بنر صفحهٔ تنظیمات؛ `setSecureScreen` bool برمی‌گرداند و `applySecureScreenAtStartup` تیک دروغین هنگام شروع را خاموش می‌کند |
| `engine.query` و `LawTerms` بیرون از رشتهٔ UI | 🟡 | `engine.query` در isolate دائمی (`core/engine_worker.dart`) اجرا میشود و API همگام قدیمی دستنخورده مانده؛ `LawTerms.match` هنوز PaLM از پیش ساخته را همگام میخواند (`domain/advocate/term_reply.dart`) |
| ارزانکردن نمایش تدریجی متن | ✅ | حذف کامل نگارش تدریجی؛ پاسخ یکجا نمایش داده میشود (`reveal_text.dart`) |
| حذف کامل انیمیشن نویسهبهنویسه | ✅ | انیمیشن و `onRevealTick` حذف شدند؛ تنها نشانگر «در حال نوشتن…» پیش از آمدن پاسخ مانده (`tests/python/test_ui_budget.py`) |
| نگه‌داشتن دکمه‌های پیشنهادی در تاریخچه | ✅ | `StoredMsg.chips`؛ گفتگوی بازیابی‌شده دیگر بی‌دکمه نیست |
| قفل‌کردن تقویم شمسی با الگوریتم مرجع | ✅ | `test/core/jalali_reference_test.dart` (۱۳۰۰–۱۵۰۰) |
| حذف حدس «تومان → میلیون» در `Sense.amount` | ⬜ | تغییر عدد به‌معنای تغییر حکم است |

## مرحلهٔ ۴ — آزمون، CI، بهداشت مخزن

| کار | وضعیت | یادداشت |
|---|---|---|
| آزمون ساختاری بهجای `contains` | ✅ | ابزار `test/support/reply_shape.dart` و میدان `ask` در `AdvocateReply`؛ نگهبان صفرتحمل `tests/python/test_structure_tests.py` هم شکل مثبت و هم منفی `contains` را قرمز میکند |
| تبدیل assertion های متنی به ساختاری | ✅ | ۱۱۹ حالت اصلی بهعلاوهٔ ۵۱ شکل منفی و سه مورد `.text.contains` به صفر رسیدند؛ هر تبدیل کامیت جداگانه دارد |
| دروازهٔ پوشش کد | ✅ | `flutter test --coverage` + `dev/tools/coverage_gate.py --min 40` در CI (`tests/python/test_coverage_gate.py`) |
| جداکردن `dev/brain/` و `dev/tools/` پژوهشی | ✅ | مرز اپ/ابزار در `docs/REPO_LAYOUT.md` و نگهبان بستهبندی (`tests/python/test_repo_hygiene.py`) قفل شد؛ پوشهها خارج از `pubspec` و APKاند |
| توقف کامیت خودکار گزارش‌ها | ✅ (از پیش) | `commit-reports` فقط روی موفقیت |
| حذف کامنت/کد مرده | ✅ | ۲۶ عکس توسعهٔ یتیم `tests/topics`، دو ابزار دستی بیارجاع و دو گزارش قدیمی حذف شد؛ همهٔ ۱۵۵ فایل `lib/` از `main.dart` قابل دسترساند. نگهبان: `tests/python/test_repo_hygiene.py`؛ فهرست کامل: `docs/DEAD_CODE.md` |
| ایست‌واژه‌ها و آستانهٔ تطبیق واژه‌ها یک منبع داشته باشند | ✅ | `dev/tools/contracts/law_terms.json` مرجع است؛ `dev/tools/gen_law_terms.py --write` دو فایل تولیدشده می‌سازد و `check.py lawterms` کهنه‌بودنشان را خطا می‌دهد — `tests/python/test_law_terms_parity.py` |
| ایست‌واژه‌های گفتاری در پاسخ نیایند | ✅ | ۵۵ واژهٔ روزمره (توانم، اگر، کاری…) به هر دو فهرست |
| پرسشِ بی‌جواب سه بار تکرار نشود | ✅ | سقفِ دو بار در `_out`؛ بار سوم جملهٔ صریح («از آن می‌گذرم») — `test/advocate/meta_and_tone_test.dart` |
| واژهٔ موضوع، بی‌ماجرا، حکم نگیرد | ✅ | `Topic.gate` + `fightGate` در `topics/fight.dart`: بی‌آدم/نقش/آسیب، پرسش به‌جای ماده — `test/advocate/meta_and_tone_test.dart` |
| لحنِ دلداریِ دروغ و وعدهٔ بی‌مدرک در راهنماها | ✅ | «خوشبختانه»، «موقعیت شما معمولاً قوی است»، «تخلیه سریع است» از `lib/domain/lawyer/legal_guides.dart` رفتند؛ نگهبان: `tests/python/test_tone_guard.py` |
| جدولِ بدهی‌های موقت داده باشد، نه متن | ✅ | `dev/tools/contracts/duplicated_logic.json` + `check.py debt`: هر جفت، نمونهٔ مشترک، خواندنش از هر دو زبان، و بودنش در همین سند — `tests/python/test_debt_check.py` |
| `Advocate` گاد-آبجکت نباشد | ✅ | وضعیتِ «روی میز» در `dialogue_state.dart` (۲۵ فیلد)، ساختِ پاسخ در `reply_voice.dart`، ۱۲ مسیرِ نام‌دار در `reply_routes.dart` (`_reply` ۵۶۰ → ۳۳۴ خط)، فیلدهای حالتیِ `Advocate` ۴۶ → ۱۲. تشخیص موضوع (`TopicScore`) و پرسش بعدی (`CasePlan`) از کلاس بیرون آمدند و `test/advocate/isolation_test.dart` بدونِ ساختنِ `Advocate` می‌سنجدشان. ترفندِ `file.turns--` رفت. `chat_controller.dart` ۵۳۰ → ۳۱۲ خط با `draft_flow.dart`. `rent.dart` ۲٬۶۷۹ خط → شش تکه؛ `labor.dart` و `family.dart` هم به چهار تکه با آزمونِ پیش از شکستن. سه همکارِ تازه: `CaseArgument` (استدلال)، `ChipPlan` (دکمه‌ها؛ `advocate_chips.dart` ۱۶۰ → ۲۳ خط)، `MetaReply` (پاسخ‌های «دربارهٔ برنامه»)؛ خلاصهٔ پرونده تابعِ `recapOf` شد. متدهای باقی‌مانده روی بخش‌های `Advocate` از ۱۹۰ به ۵۷ رسید (`LawAnswer`، `TalkReply`، `TalkRoute`، `TopicPicker`، `CaseFlow`، `ReplyRoutes`، `GuideReply`، `TermReply` هم جدا شدند) — ترتیبِ پاسخ‌ها حالا فهرستِ نام‌دار است (`AnswerCandidate`/`AnswerArbiter`)، ولی نیمهٔ دومِ `_reply` هنوز محاسبه و تصمیم را در هم می‌بافد و ادعا نمی‌کنیم تمام شده. موتور: `law_mention.dart`. نگهبان عددی: `tests/python/test_advocate_shape.py` |
| موتورِ قوانین هم شکسته شود | ✅ | `engine.dart` ۱٬۱۷۸ → **۶۳۸** خط: `LawIndex` (ایندکس + خواندنِ متن)، `LawRanker` (BM25F)، `LawText` (نوشتنِ متن)، `LawMention`، `ArticleQuery`. هر چهار با آزمونِ بی‌نیاز از دارایی‌ها (`test/core/law_*_test.dart`). در موتور چیزی جز بارگذاری و تصمیمِ پاسخ نماند |
| رفتارهای `Advocate` هم همکار داشته باشند | 🟡 نیمه | جدا شده‌اند: `DialogueState` (حالت)، `ReplyVoice` (ساختِ پاسخ)، `_Routes` (مسیرها)، `CaseArgument` (استدلال: پرونده + صدا + خلاصه + برعکس‌شدن‌ها). هنوز ~۱۹۰ متد در ۸ فایلِ `part` روی خودِ `Advocate` است؛ قدمِ بعد: `CaseFlow` (روندِ پرونده) و `CaseTalk` (گفت‌وگوی انسانی) با همان الگو |
| گفتگوهای گزارش‌شده خودکار آزمون شوند | ✅ | `test/audit/conversations_reported.txt` در فهرست ورودیِ `conversation_audit_test.dart` |

## بدهی‌های موقتِ ثبت‌شده

این‌ها **رفع نشده‌اند**؛ فقط نگهبان گرفته‌اند تا سکوت نکنند. اگر روزی یکی از
این‌ها عوض شود و آزمونش قرمز نشود، یعنی نگهبان هم از کار افتاده.

جدولِ زیر داده هم شده است: `dev/tools/contracts/duplicated_logic.json` +
`python3 dev/tools/check.py debt` بررسی می‌کند هر جفت هنوز همان مجموعهٔ نمونه را
از **هر دو زبان** می‌خواند و هنوز در همین بخشِ ROADMAP هست. حذف یک ردیف از
اینجا بی‌آن‌که جفتش از قرارداد برود، CI را قرمز می‌کند؛ و برعکس.

| بدهی | دو/چند پیاده‌سازی | نگهبان | رفع واقعی |
|---|---|---|---|
| الگوریتمِ تطبیق واژه‌ها | `lib/domain/advocate/law_terms.dart` ↔ `dev/tools/law_terms.py` | فهرست و آستانه‌ها یک‌جا شد (`check.py lawterms`)، ولی کدِ تطبیق دو جاست: `tests/law_terms/cases.json` روی هر دو اجرا می‌شود | ارزیابی روی خروجی خودِ اپ، یا حذف آینهٔ پایتون |
| یکدست‌سازی متن (الگوریتم) | `lib/core/persian_text.dart` + `lib/core/text_norm_rules.dart` ↔ `dev/brain/common.py` | قاعده‌ها یک‌جا شد (`check.py textnorm`)؛ کدِ اجراکننده دو جاست: `tests/text_norm_golden.json` و `tests/text_norm_norm_cases.json` | ارزیابی روی خروجی خودِ اپ |
| موتور بازیابی | `lib/core/engine.dart` ↔ `dev/tools/eval_py.py` | `dev/tools/check.py parity` + `test/core/parity_test.dart` | ارزیابی روی خروجی خودِ اپ (بدون بازنویسی پایتون) |
| مسیر موضوعی | `lib/domain/advocate/topic_flow.dart` ↔ `dev/tools/topic_flow.py` | `tests/python/test_topic_flow.py` (۴۶ نمونه) | همان موتور Dart از میز فرمان اجرا شود |
| دادهٔ مشتق (`laws_catalog.json`، `data_info.json`) | `assets/laws/_meta.json` → `dev/tools/sync_meta.py` | `dev/tools/check.py meta` (تازگی) | تولید در زمان ساخت، نه فایل کامیت‌شده |

### پرداخت‌شده: ایست‌واژه‌های تطبیق واژه‌ها

پیش‌تر فهرست ۱۵۳ ایست‌واژه و آستانه‌ها (کمینهٔ طول، df، پوشش، idf) دو بار
دستی نوشته شده بود: `lib/domain/advocate/law_terms.dart` و `dev/tools/law_terms.py`.
آزمون آینه فقط جلوی جداافتادنشان را می‌گرفت؛ خودِ دوتا‌بودن بدهی بود.

- **یک مرجع:** `dev/tools/contracts/law_terms.json` (ایست‌واژه‌ها، نگاشت `افحش→فاحش`،
  آستانه‌ها، نام منبع عمومیِ پاسخ).
- **تولید:** `python3 dev/tools/gen_law_terms.py --write` دو فایل می‌سازد
  (`lib/domain/advocate/law_terms_rules.dart`، `dev/brain/law_terms_rules.py`)؛
  `python3 dev/tools/check.py lawterms` کهنه‌بودنشان را خطا می‌دهد و `check.py all`
  هم آن را با خود دارد.
- **دو پیاده‌سازی منطق می‌مانند** (موتور دارت و آینهٔ پایتون) ولی هیچ فهرست یا
  عددی دیگر دستی نوشته نمی‌شود؛ آزمون `test_no_second_hand_written_list` جلوی
  برگشتنِ فهرست دستی را می‌گیرد.

### پرداخت‌شده: قاعده‌های متن

نرمال‌سازی از این فهرست بیرون رفت. پیش‌تر همان قاعده در پنج جا نوشته شده بود
(`persian_text.dart`، `text_sense.dart`، `dev/brain/common.py`، `dev/tools/topic_flow.py`،
`dev/tools/law_terms.py`). حالا:

- **یک مرجع:** `dev/tools/contracts/text_norm.json` — نگاشت نویسه، ارقام، اعراب،
  نویسه‌های فاصله‌ای، نشانه‌ها، قاعدهٔ نقطه، چسباندن «می/نمی» و بازنویسی‌های
  محاوره.
- **تولید:** `python3 dev/tools/gen_text_norm.py --write` دو فایل می‌سازد
  (`lib/core/text_norm_rules.dart`، `dev/brain/text_norm_rules.py`)؛
  `python3 dev/tools/check.py textnorm` کهنه‌بودنشان را خطا می‌دهد.
- **یک پیاده‌سازی در پایتون:** `common.normalize` / `common.norm` /
  `common.spaced(s, variant)`؛ `topic_flow` و `law_terms` فقط صدایش می‌زنند.
- **قفل رفتاری:** `tests/text_norm_golden.json` (خروجی پیش از تغییر) و
  `tests/text_norm_norm_cases.json`؛ سنجیده در
  `tests/python/test_text_norm_parity.py` و `test/core/text_norm_rules_test.dart`.

**آن‌چه باقی است (🟡):** خودِ *منطق* یکسان‌سازی دو بار نوشته شده — یک بار در
دارت (`Sense.norm`) و یک بار در پایتون (`common.norm`). این تقلیدِ بین‌زبانی
با تولید کد رفع نمی‌شود؛ نگهبانش همان دو فایلِ نمونهٔ بالاست و رفعِ کاملش
یعنی یکی از دو زبان از معادله بیرون برود (مثلاً ارزیابی روی خروجی خودِ اپ).

**هشدار:** بدهی بدون نگهبان، همان «خطای بی‌صدا»یی است که در بازبینی اول آمده
بود. قاعده: تا وقتی یک پیاده‌سازی دوگانه رفع نشده، باید دست‌کم یک آزمون مشترک
داشته باشد؛ اگر نگهبانی در جدول «ندارد» است، بدهی هنوز باز است.

## فاز ۱ — استحکام قرارداد پاسخ و مرز بستهبندی (انجامشد)

پس از فاز ۰، چهار کارِ مشخص با آزمونِ جداگانه و کامیتِ جداگانه انجام شد.
هر کدام یک نگهبانِ پایدار دارند تا برگشتِ بدهی را قرمز کند:

| کار | وضعیت | آزمون / نگهبان |
|---|---|---|
| تبدیلِ تمام assert های متنی `contains` به خواندن فیلدهای ساختاری | ✅ | `tests/python/test_structure_tests.py` (صفر تحمل) |
| جابهجایی فیزیکی `brain/` و `tools/` به `dev/` | ✅ | `tests/python/test_repo_hygiene.py` |
| بستهبندی نشدن ابزارها در APK | ✅ | `tests/python/test_apk_bundle_exclusion.py` + `check.py bundle` |
| مهاجرت امن کلید قدیمی SharedPreferences | ✅ | `test/core/privacy_migration_test.dart` |

**معیار پذیرش:** ۱۱۹ assert متنی (شامل ۵۱ شکل منفی و دو مورد `.text.contains`) به صفر رسید؛
نگهبان هم شکل مثبت و هم منفی را میگیرد. ابزارها فیزیکاً از ریشهٔ اپ بیروناند و
`check.py bundle` ۲۱ دارایی `assets/` را تأیید میکند. مهاجرت سه سناریو دارد:
دوباره مهروموم با Keystore، حذف fail-closed وقتی Keystore نیست، کلید خراب بدون کرش.
گزارش عددی: `reports/phase1_metrics.md`.

**باقیماندهٔ فاز ۱ از نقشهٔ اصلی (`docs/PHASES.md`)** نیازمند تأیید صریح مالک
برای جابهجایی متن قانون به داده است و بدون آن دست نخورده میماند؛ جابهجایی
بدون توافق متن حقوقی از حیطهٔ این فاز خارج است.

## قاعدهٔ کار در ادامه

1. هر گام: ابزار بررسی + آزمون + یک خط در همین جدول.
2. هیچ گام بدون `python -m unittest discover -s tests/python` و
   `python dev/tools/check.py all` سبز بسته نمی‌شود.
3. تغییر Dart بدون `flutter analyze`/`flutter test` در CI پذیرفته نمی‌شود؛
   در محیط ابری که Dart SDK ندارد، تغییر Dart فقط افزایشی و آزمون‌دار است.

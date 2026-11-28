# دستیار — دستیار حقوقی فارسی، آفلاین و قطعی

**دستیار** یک اپلیکیشن اندرویدی (Flutter/Dart) کاملاً آفلاین و متن‌باز با پروانهٔ MIT است که برای راهنمایی عمومی در مسائل حقوقی رایج (اجاره و ودیعه، چک، خانواده، کار، طلب و بدهی، کیفری، ثبتی و …) طراحی شده است. این برنامه **هیچ مدل زبانیِ مولدی (LLM) ندارد**، مجوز اینترنت نمی‌خواهد و هیچ پاسخی را به‌صورت زاینده تولید نمی‌کند؛ تمام پاسخ‌ها از **قاعده‌های صریح (`RuleDSL`)**، **راهنماهای ساختاری** و **متن قوانین بسته‌بندی‌شده درون اپ** ساخته می‌شوند. تنها مدل یادگیرندهٔ برنامه، یک رمزگذار برداری سبک (`Noql`) است که فقط زمانی که قاعده‌ها موضوع پیام را نشناسند، دسته‌بندی موضوعی را به‌عنوان «پیشنهاد» می‌سنجد و از کاربر تأیید می‌گیرد.

> **وضعیت انتشار: مسدود است.** تا این لحظه **۰/۲۴** قانون بسته‌بندی‌شده با منبع رسمی تطبیق داده شده‌اند (`verified`: صفر) و تنها **۲/۹** قالب سند بازبینی انسانی شده‌اند. دروازهٔ `python3 dev/tools/check.py trust` در گردش‌کار انتشار (`build.yml`) اجرا می‌شود و امروز عمداً قرمز است. پیش از تطبیق رسمی متون، این مخزن صرفاً نمونهٔ مهندسیِ قابل بررسی است و جایگزین وکیل یا مشاورهٔ حقوقی نیست.

---

## ۱. شاخص‌های واقعی مخزن (تاییدشده در CI و ابزارهای محلی)

| سنجه | مقدار واقعی | منبع سنجش |
|---|---|---|
| کد برنامه (`lib/`) | **۱۷۰** فایل Dart (مجموع **۲۵٬۰۳۰** خط؛ بزرگ‌ترین فایل `advocate.dart` ۴۰۷ خط و هیچ فایلی بالای سقف ۴۲۰ خط نیست) | `dev/tools/library.py` و `tests/python/test_file_sizes.py` |
| آزمون‌های Flutter/Dart | **۷۲۵** آزمون سبز (`۱۰۸` فایل آزمون؛ شامل ۳۸۷ آزمون وکیل و خط پایهٔ ۷۰۱ آزمون پس از تفکیک کنترلر) و پوشش کد **۹۱٫۷٪** (`8049/8782` خط) | `reports/last_test.txt` و `reports/coverage.txt` |
| سناریوهای گفتگوی انتها‌به‌انتها | **۱۳۰ از ۱۳۰** و **۱۷ از ۱۷** سناریوی موفق، تحلیل ایستا با **۰ هشدار/خطا** | گردش‌کار `.github/workflows/test.yml` |
| آزمون‌های نگهبان و قرارداد (Python) | **۳۶۶ از ۳۶۶** آزمون سبز در `۵۹` فایل با `-W error::ResourceWarning` بدون هیچ نشت فایل | `tests/python/` و `check.py all` |
| دانش قوانین و نثر داده‌ای | **۲۴** قانون (`۵٬۷۲۴` بخش، `۹٬۲۱۴` واژه)، **۲۴** موضوع، **۳۴** راهنما، **۱۲۰** پرسش‌وپاسخ اجاره، **۹** قالب سند، **۲٬۱۰۴** کلید نثر ثابت در JSON (`۶۶` فایل تحت قفل هش SHA-256) | `assets/brain/text_manifest.json` و `reports/startup.txt` |
| عملکرد استارت و حافظه (CI) | بارگذاری سرد **۹۴۴ ms** (`assets: ۵۷ ms`، `index: ۸۸۶ ms`)، آماده شدن Isolate موتور **۸۹۹ ms**، نخستین پرسش **۵۴ ms**، حجم کل دارایی‌ها **۱۶٫۸۸ MB** (`۱۲٫۷۲ MB` بارگذاری تنبل Noql)، حافظهٔ آزمون **۲۵۲٫۸ MB** | `reports/startup.txt` و `dev/tools/startup_gate.py` |

---

## ۲. برنامه چگونه کار می‌کند؟ (جریان گام‌به‌گام اجرا و پاسخ‌گویی)

### الف) راه‌اندازی امن و بوت برنامه (`lib/main.dart`)
1. در شروع اجرا، `AppSettings.load()` تنظیمات ذخیره‌شده (مقیاس قلم، تم، وضعیت رضایت و محافظت صفحه) را بارگذاری می‌کند و `applySecureScreenAtStartup()` با کانال بومی Android بررسی می‌کند که آیا `FLAG_SECURE` واقعاً فعال شده است یا نه (اگر گوشی اعمال نکند، تیک به‌دروغ روشن نمی‌ماند).
2. اگر کاربر هنوز رضایت بار نخست را نداده باشد، صفحهٔ `PrivacyNoticePage` نمایش داده می‌شود تا کاربر آگاهانه ذخیرهٔ تاریخچه را بپذیرد یا حالت «فقط همین اجرا» را برگزیند.
3. در `Loader._init()`:
   - ابتدا `PrivacyService.beginSession()` کانال بومی `com.ariabod.dastyar/privacy` (`probe` در `MainActivity.kt`) را می‌آزماید. اگر Keystore سخت‌افزاری قابل استفاده نباشد، پرچم `persistenceAllowed = false` می‌شود تا نوشتن تاریخچه، پیش‌نویس و بازخورد به‌صورت **fail-closed** متوقف شود و داده‌ای با کلید موقت غیرقابل‌بازیابی نوشته نشود.
   - `PrivacyMigration.run()` داده‌های نسخهٔ پیشین (`encf1:` با کلید قدیمی) را یک‌بار با Keystore دوباره مهروموم یا در صورت نبود Keystore/خرابی پاک می‌کند و `PrivacyService.discardLegacyKey()` کلید قدیمی را از دیسک حذف می‌کند.
   - به‌طور هم‌زمان، `KnowledgeEngine.load(startWorker: true)` (با `cache: false` برای جلوگیری از کش دوگانهٔ رشته‌های خام در `rootBundle` و راه‌اندازی Isolate دائمی `EngineWorker`)، راهنماهای آماده (`loadLegalGuides`)، سه دارایی نثر وکیل (`loadRentTexts`، `loadTopicTexts`، `loadAdvocateTexts`)، قالب‌های سند (`TemplateRepository.load`)، تاریخچه (`HistoryStore.load`)، پیش‌نویس نیمه‌کاره (`DraftCheckpointStore.load`) و پاک‌سازی بقایای قدیمی (`LegacyCleanup.run`) اجرا می‌شوند.
   - مدل برداری ۱۲٫۷ مگابایتی `Noql` (`ReaderService`) در شروع برنامه بار نمی‌شود و به‌صورت تنبل تا نخستین پیامی که قاعده‌ها موضوعش را نشناسند به تاخیر می‌افتد.

### ب) مسیر پردازش یک پیام کاربر (`ChatPage` → `ChatController` → جریان‌های سه‌گانه)
کنترلر `ChatController` (`lib/ui/chat_controller.dart`) تنها یک سیم‌کشی نازک میان سه همکار مستقل است:
1. **`DraftFlow` (`lib/ui/draft_flow.dart`):** اگر کاربری در حال پرکردن فرم یک سند باشد یا پیام درخواست نوشتن سند بدهد (با تشخیص `DraftIntent` یا پذیرش پیشنهاد «تنظیم دادخواست/لایحه»)، پیام به `DraftStep.answer` می‌رود، فیلدها یکی‌یکی اعتبارسنجی (عدد، کد ملی، تلفن، گزینه، متن) و با داده‌های پروندهٔ وکیل (`Advocate.fillFor`) تکمیل می‌شوند و در پایان `TemplateRenderer` سند نهایی را می‌سازد. در صورت فعال‌بودن گزینه، پیش‌نویس ناتمام در `DraftCheckpointStore` رمزنگاری و ذخیره می‌شود.
2. **`GuessFlow` (`lib/ui/guess_flow.dart`):** اگر هیچ پرونده‌ای باز نباشد و `Advocate.wantsGuess(raw)` تایید کند پیام حداقل ۳ واژه دارد و هیچ موضوعی در آن به آستانهٔ بازشدن نرسیده است، کنترلر به صورت ناهمگام از `ReaderService` (مدل `Noql` در Isolate) حدس موضوع را می‌گیرد (`TopicGuess` با آستانه‌های `open ≥ 0.143`، `margin ≥ 0.04`، `ask ≥ 0.087`).
3. **`ReplyFlow` (`lib/ui/reply_flow.dart`):** صف ترتیبی پیام‌ها و شمارندهٔ نسل گفتگو (`_generation`) را نگه می‌دارد تا پیام در صف، پس از زدن «گفتگوی جدید» به گفتگوی تازه نچسبد. سپس پرس‌وجوی موتور (`prepareQuery`)، پرس‌وجوی راهنمای باز (`guideReply`) و تطبیق واژه‌ها (`matchTermsInWorker`) را هم‌زمان در Isolate دائمی `EngineWorker` پیش‌ساخته و به `Advocate.respond` می‌فرستد.

### پ) مغز تصمیم‌گیری وکیل (`lib/domain/advocate/`)
هر پاسخ وکیل از مسیر `_guardedReply` (`ReplyLoopGuard` با سقف بازگشت `maxReplyDepth = 1` و ثبت یک‌بارهٔ `file.turns`) وارد `_reply` می‌شود. ترتیب اولویت پاسخ‌ها در `assets/pipeline.json` و جدول `advocate_data.dart` با آستانه‌های `netMin = 0.6`، `topicOpenMin = 3`، `topicStrongMin = 5` و `topicDominantMin = 5` قفل شده و داور `AnswerArbiter` از میان **۲۰ کاندید نام‌دار** اولین برنده را برمی‌گرداند:
1. **ایمنی (`SafetyReply`):** خشونت خانگی، تهدید، خودآسیبی و خطر فوری پیش از هر تحلیل حقوقی بررسی می‌شوند، وضعیت شدت (`SafetySeverity`: `none` / `elevated` / `critical`) و پنجرهٔ نوبتی را نگه می‌دارد و شمارهٔ اورژانس (۱۱۰، ۱۱۵، ۱۲۳) می‌دهد.
2. **حفاظت و هدایت گفتگو (`ReplyRoutes` / `TalkRoute` / `MetaReply`):** خروج از بحث، اصلاح برداشت قبلی وکیل («منظورم … نبود»)، لغو درخواست سند، ارجاع صریح به شمارهٔ ماده، پرسش دربارهٔ موضوع هم‌جوار (`also`)، مهلت اعتراض، احوال‌پرسی، ابراز ناامیدی/سوگ، خلاصهٔ پرونده و راهنمای «این برنامه چیست».
3. **پروندهٔ قاعده‌محور ۲۴ موضوع (`RuleDSL` + `CaseFlow` + `Reasoner`):**
   - هر ۲۴ موضوع (`topics/*.dart`) بدون کلوژر بی‌نام و با گره‌های سریال‌پذیر `RuleDSL` (`FactExpr`، `TextExpr`، `ReadRule`، `GateRule`، `RankRule`، `FilingRule`، `PromptRule`، `FillRule`) تعریف شده‌اند و با `Topic.toJson()` به JSON تبدیل می‌شوند.
   - پس از استخراج واقعیت‌ها از متن محاوره‌ای (`Sense.norm`، مبلغ، مدت، بله/نه، واژه‌های حقوقی)، `CaseFacts.absorb` پرونده (`CaseFile`) را به‌روزرسانی می‌کند، `Reasoner` تک‌تک ادعاها (`Claim`) و ارکانشان (`Element`) را سه‌ارزشی (`✓`، `✗`، `؟`) می‌سنجد و `CasePlan` هوشمندترین پرسش بعدی (`Slot`) را انتخاب می‌کند.
4. **لایه‌های تکمیلی و آخرین راه (`TermReply`، `GuideReply`، `LawAnswer`):**
   - `LawTerms`: تطبیق دقیق واژه‌های پرسش با متن قوانین (با حذف ایست‌واژه‌ها و رتبه‌بندی بر پایهٔ قرارداد `law_terms.json`).
   - `Glossary` و `LegalGuides`: واژه‌نامهٔ اصطلاحات و ۳۴ راهنمای ساختاری آماده.
   - `TopicFlow`: درخت تصمیم JSON برای مسیرهای `live` (مانند `assets/brain/topics/cheque.json`).
   - `TopicPicker` (`Noql`) و نظر دوم `IntentNet` (شبکهٔ سبک n-gram با اطمینان `>= 0.6`).
   - `QaBank` (۱۲۰ پرسش‌وپاسخ اجاره) و در نهایت رتبه‌بندی قطعی `BM25F` در `KnowledgeEngine` (`LawRanker` + `LawMention` + `LawTopicPrior` + `ConflictsService`).

### ت) حریم خصوصی و ذخیره‌سازی محلی (`MainActivity.kt` + `PrivacyService` + `HistoryStore`)
- `AndroidManifest.xml` هیچ `uses-permission` (از جمله اینترنت) ندارد و `allowBackup="false"` است.
- در اندروید، کلید سخت‌افزاری `AES-256-GCM` داخل `AndroidKeyStore` (`dastyar_local_store_v1`) قرار دارد. هر گفتگو در `HistoryStore` کلید رمزشدهٔ مستقل (`history_v1:m:<id>`) با قالب `v: 4` دارد که علاوه‌بر پیام‌ها، `caseJson` (`CaseFile`) و `dialogueJson` (`DialogueState`) را ذخیره می‌کند تا دکمه‌ها و وضعیت پرسش‌های نیمه‌کاره پس از بستن برنامه عیناً بازگردد.
- در سکوهای فاقد کانال بومی، `PrivacyService` در حالت پیش‌فرضِ برنامه پس از `beginSession()` ذخیرهٔ دیسک را خاموش (`fail-closed`) نگه می‌دارد و در تست‌های واحد از رمزنگاری احرازهویت‌شدهٔ HMAC-SHA256 + CTR با کلید صرفاً در حافظه استفاده می‌کند. کلیپ‌بورد اسناد نیز با پرچم `EXTRA_IS_SENSITIVE` اندروید ۱۳+ کپی می‌شود.

---

## ۳. نقشهٔ کامل پوشه‌ها و فایل‌های پروژه

| مسیر | نقش و فایل‌های اصلی |
|---|---|
| `lib/main.dart` | نقطهٔ ورود اپ، بارگذاری پروانهٔ Noql، تنظیم تم/فونت، صفحهٔ رضایت اولیه و راه‌اندازی هم‌زمان در `Loader` |
| `lib/core/` | هستهٔ بدون وابستگی به لایهٔ دامنه: `engine.dart`، `engine_load.dart`، `engine_query.dart`، `engine_worker.dart` (Isolate دائمی)، `engine_rules.dart` (تولیدشده)، `law_index.dart`، `law_ranker.dart` (BM25F)، `law_mention.dart`، `law_text.dart`، `article_query.dart`، `law_topic_prior.dart`، `conflicts_service.dart`، `persian_text.dart` + `text_norm_rules.dart` (تولیدشده)، `qa_bank.dart`، `replies.dart`، `router.dart`، `jalali.dart`، `models.dart`، `privacy.dart`، `privacy_migration.dart`، `history.dart` + `history_models.dart` + `history_store.dart`، `legacy_cleanup.dart` |
| `lib/domain/` | منطق حقوقی و مدل‌های خالص (کاملاً بدون `package:flutter`): `templates.dart`، `drafting.dart` و ۵ فایل `draft_{models,words,intent,step,laws}.dart`، `feedback.dart`، `intent_net.dart`، `input_suggestions.dart`، `settings_state.dart` |
| `lib/domain/advocate/` | هماهنگ‌کننده و همکاران وکیل: `advocate.dart`، `advocate_{data,model,constants,text,texts_loader,reply,reply_guard,reply_case,talk,topic,case,chips,argue,meta,leave}.dart`، `answer_candidate.dart`، `case_{file,state,model,flow,facts,answer,text,plan,recap}.dart`، `dialogue_{state,sections}.dart`، `rule_dsl*.dart` (۵ فایل)، `reasoner.dart`، `reply_{routes,voice}.dart`، `safety_reply.dart`، `talk_{reply,route}.dart`، `term_reply.dart`، `guide_reply.dart`، `law_{answer,terms,terms_rules}.dart`، `topic_{flow,picker,read,score}.dart`، `chip_{plan,texts}.dart`، `glossary.dart`، `phrases.dart`، `text_sense.dart`، `understanding.dart` |
| `lib/domain/advocate/topics/` | ثبت موضوع‌ها (`all.dart`)، قواعد مشترک (`shared.dart`)، بارگذارها (`rent_texts_loader.dart`، `topic_texts_loader.dart`) و ۲۴ موضوع حقوقی (`accused`، `admin`، `cheque`، `child`، `company`، `consumer`، `cyber`، `debt`، `enforce`، `family*` (۵ فایل)، `fight`، `foreign_contract`، `guarantee`، `inherit`، `injury`، `labor*` (۵ فایل)، `marriage`، `minor_sale`، `neighbor`، `partner`، `property`، `rent*` (۱۴ فایل)، `sale`، `theft`) |
| `lib/domain/lawyer/` | `legal_guides.dart`، `legal_guides_loader.dart` و لحن راهنماها در `lawyer_voice.dart` |
| `lib/domain/understanding/` | موتور برداری Dart خالص `Noql`: `noql_tokenizer.dart`، `noql_encoder.dart` (int8)، `topic_reader.dart`، `reader_service.dart` (Isolate با تایم‌اوت ۱۲ ثانیه) و `topic_guess.dart` |
| `lib/ui/` | رابط کاربری و کنترلر: `chat_controller.dart`، `draft_flow.dart`، `guess_flow.dart`، `reply_flow.dart`، `app_settings.dart`، `chat_models.dart`، `chat_page.dart`، `history_page.dart`، `settings_page.dart`، `about_page.dart`، `privacy_notice_page.dart`، `app_drawer.dart` و ۱۰ ویجت در `lib/ui/widgets/` |
| `android/` | تنظیمات Gradle (اجبار کلید امضای انتشار مگر با `ALLOW_DEBUG_SIGNING`)، مانیفست صفر-مجوز و `MainActivity.kt` (Keystore AES-GCM، `probe`، `FLAG_SECURE`، کلیپ‌بورد حساس و پاک‌سازی مدل قدیمی) |
| `assets/` | ۲۴ متن قانون + `_meta.json` (`assets/laws/`)، `pipeline.json`، `relationships.json`، `synonyms.txt`، `replies.json`، `laws_catalog.json`، `data_info.json`، ۹ قالب سند (`assets/templates/`)، `qa/lease_qa.json` و دارایی‌های `assets/brain/` (`noql*`، `intent_model.json`، `law_topics.json`، `legal_terms.json`، `guides/legal_guides.json`، `topic_texts.json`، `advocate_texts.json`، `text_manifest.json` و `topics/{index,cheque,rent_texts}.json`) |
| `dev/tools/` و `dev/brain/` | ابزارهای بیرون از APK: `check.py` (دروازهٔ کامل)، `library.py`، `lines.py`، `lawtext.py`، `doctor.py`، `pipeline_check.py`، `topic_schema.py`، `data_refs.py`، `text_manifest.py`، `feedback_eval.py` (تبدیل خروجی بازخورد به `eval`)، `law_diff.py`، `law_registry.py`، `sync_meta.py`، `parity.py`، `debt_check.py`، `coverage_gate.py`، `startup_gate.py`، `ci_{annotate,summary}.py`، `eval_{py,none}.py`، مولدهای `gen_{text_norm,law_terms,engine_rules,priority}.py`، قراردادهای `dev/tools/contracts/*.json`، اسکیماها و `dev/brain/` (آینهٔ پایتون `common.py`/`engine.py`، آموزش `train_intent.py`، `noql/` و بنچمارک‌ها) |
| `tests/` و `test/` | ۱۰۸ فایل آزمون Flutter/Dart در `test/` (واحد، ویجت، سناریوها، قراردادها و ممیزی گفتگو) + ۵۹ فایل نگهبان و قرارداد Python در `tests/python/` + ورودی‌های آزمون در `tests/{topics,law_terms,text_norm_*}` |
| `eval/`، `lab/`، `reports/` | مجموعه‌های ارزیابی آفلاین در `eval/`، مسیرهای آزمایشی بیرون از APK در `lab/topics/` و گزارش‌های خودکار CI و ممیزی در `reports/` |
| `docs/` و `.github/workflows/` | مستندات معماری و قرارداد (`ARCHITECTURE.md`، `CONTRACTS.md`، `PHASES.md`، `ROADMAP.md`، `PRIORITY.md`، `CODE_REVIEW.md`، `GOD_OBJECTS.md`، `LAW_SOURCES.md`، `DEAD_CODE.md`، `REPO_LAYOUT.md`) و گردش‌کارهای CI (`test.yml`، `lawyer-lab.yml`، `intent-eval.yml`، `alt-bench.yml`، `build.yml` و …) |

---

## ۴. گزارش کامل تمام مراحل و فازهای انجام‌شده روی این شاخه

روش بازسازی در تمام مراحل به‌صورت افزایشی و آزمون‌محور («اول نگهبان عددی، بعد تغییر کد با حفظ رفتار بیرونی») انجام شد:

| مرحله / فاز | مشکل و بدهی پیشین | کارهای انجام‌شده و فایل‌های تغییریافته | نگهبان و نتیجهٔ تاییدشده |
|---|---|---|---|
| **سخت‌سازی P0** | نبود probe برای Keystore، ازدست‌رفتن وضعیت گفتگو در تاریخچه، تکرار پیام ایمنی، نداشتن `toJson` پرونده و نبود دروازهٔ محتوایی | `MainActivity.kt` (`probe`)، `PrivacyService.beginSession` و ذخیرهٔ fail-closed؛ قالب `v: 4` تاریخچه (`dialogueJson`)؛ `CaseFile.toJson/fromJson`؛ مهاجرت امن کلید قدیمی (`privacy_migration.dart`)؛ `check.py trust` در `build.yml` | `privacy_fail_closed_test.dart`، `privacy_migration_test.dart`، `case_persistence_test.dart`، `dialogue_state_test.dart` و `test_trust_gate.py` |
| **فاز ۰** | نگهبان‌های پایتون فایل‌محور بودند و با تقسیم هر فایل `part` می‌شکستند | ایجاد `dev/tools/library.py` (`DartLibrary`) و `lines.py` به‌عنوان مرجع یکتای خواندن `lib/` و شمارش خط؛ اتصال ۸ نگهبان به آن | `test_guards_use_library.py` و `test_library_tool.py` |
| **فاز ۱ و ۱ب** | ۲٬۱۰۰+ رشتهٔ نثر ثابت فارسی در فایل‌های Dart پراکنده بود؛ ۱۱۹ آزمون به `contains` متنی وابسته بود؛ ابزارهای پایتون در ریشهٔ مخزن بودند | انتقال کامل نثر آزاد کل لایهٔ وکیل به `assets/brain/topics/rent_texts.json` (۵۲۵ کلید)، `assets/brain/topic_texts.json` (۱٬۱۰۶ کلید در ۲۴ بخش) و `assets/brain/advocate_texts.json` (۴۷۳ کلید در ۱۸ بخش) با بارگذارهای صریح و هش `text_manifest.json`؛ تبدیل همهٔ آزمون‌های متنی به ساختاری؛ انتقال ابزارها به `dev/` و بررسی `pubspec`/APK | `test_{rent,topic,advocate}_text_equivalence.py`، `test_structure_tests.py` (صفر `contains` متنی)، `test_repo_hygiene.py`، `test_apk_bundle_exclusion.py` (`check.py bundle` روی ۲۱ دارایی) |
| **فاز ۲** | اولویت ۲۰ کاندید پاسخ در زنجیرهٔ کد ضمنی بود و تداخل جفت‌ها آزمون نداشت | تعریف قرارداد `dev/tools/contracts/priority.json` و مولد `dev/tools/gen_priority.py` برای کل **۱۹۰ جفت** ممکن ($\binom{20}{2}$: ۱۱۳ هم‌پوشان با فراخوانی واقعی و ۷۷ جداگانه با اثبات ساختاری) | `docs/PRIORITY.md`، `test/advocate/priority_matrix_test.dart` و `test_priority_matrix.py` |
| **فاز ۳** | فراخوانی بازگشتی وکیل به خودش با ترفند `file.turns--` کنترل می‌شد | اعمال `ReplyLoopGuard` (`Advocate.maxReplyDepth = 1` و اجبار `again: true`)؛ قفل افزایش یک‌واحدی `file.turns` در هر نوبت؛ افزودن ایندکس صریح قواعد در `docs/ARCHITECTURE.md` | `test_reply_recursion_contract.py` و `test/advocate/reply_recursion_test.dart` |
| **فاز ۴** | `chat_controller.dart` بیش از ۳۰۰ خط با سه مسئولیت و امکان ناهماهنگی فایل‌های داده بود | تفکیک `chat_controller.dart` به `DraftFlow`، `GuessFlow` و `ReplyFlow` (ثبت خط پایهٔ **۷۰۱** آزمون Dart و ۳۳۱ پایتون)؛ تجمیع دادهٔ ارزیابی در `eval/` و گزارش‌ها در `reports/`؛ قفل تکرارناپذیری داده با SHA-256 | `test_chat_controller_shape.py` و `test/app/chat_flows_test.dart` |
| **فاز ۵** | نبود سنجش خط پایهٔ استارت، مصرف کش مضاعف رشته‌های خام در `rootBundle` و ابهام دربارهٔ تنبل‌سازی قوانین | افزودن `cache: false` و آزادسازی فوری داده‌های میانی در `engine_load.dart`؛ ثبت `StartupMetrics`؛ حفظ بارگذاری یک‌جای ۲۴ قانون (تنها ۳٫۱۱ MB) و تنبل‌سازی `noql` (۱۲٫۷۲ MB)؛ ایجاد دروازهٔ CI در `startup_gate.py` و ثبت در `reports/startup.txt` | `test/engine/load_budget_test.dart` و `test_startup_budget.py` |
| **فاز ۶** | بررسی مدل‌های جایگزین برای کاهش حجم `۱۲٫۷۲ MB` مدل `noql` | اجرای بنچمارک مدل‌های آزاد فارسی و ثبت نتیجه در `reports/alt_bench.md`؛ **توقف تغییر مدل به دستور صریح کاربر** تا مدل `noql` قابل فاین‌تون و دست‌نخورده بماند | `test_noql_assets_guard.py` و `check.py noql` |
| **فاز ۷** | تکرار منطق پارس لاگ CI، جدول ارقام فارسی، `AI_MARKERS`، خوانش `_meta.json` و `open()`های بی‌بست در ابزارهای پایتون | یکپارچه‌سازی `ci_annotate.py` و `ci_summary.py`؛ متمرکزسازی `lawtext.py` برای ۸ ابزار اصلی و `dev/tools/synonyms/`؛ بستن تمام فایل‌ها تا صفر `ResourceWarning` | `test_dev_tools_hygiene.py` و `test_ci_annotate.py` |
| **فاز ۸** | اجرای همگام `GuideReply`/`LawTerms` روی رشتهٔ UI، نبود ماشین حالت ایمنی، نبود `schemaVersion` در پیش‌نویس/بازخورد و وابستگی `lib/domain/` به فلاتر | اجرای ناهمگام در `EngineWorker` (`prepareWith`/`matchTermsInWorker`) در `ReplyFlow`؛ تعریف `SafetySeverity` و گذار «الان امن است» در `SafetyState`/`SafetyReply`؛ افزودن `schemaVersion = 1` در `DraftSession`/`FeedbackStore`؛ انتقال `AppSettings` به `lib/ui/app_settings.dart` و صفرشدن `DOMAIN_FLUTTER_ALLOWLIST` | `test_phase8_runtime_and_layers.py`، `worker_test.dart`، `safety_reply_test.dart` و `draft_checkpoint_test.dart` |
| **فاز ۹** | وجود کلوژرهای بی‌نام (`Reader`/`Body`/`Cond`/`Tri`) در ۲۰ موضوع ساده/میانی | پیاده‌سازی موتور سریال‌پذیر `RuleDSL` (`rule_dsl.dart`، `rule_dsl_text.dart`، `rule_dsl_read.dart`، `rule_dsl_json.dart`) و سازنده‌های `.dsl` در `case_model.dart`؛ مهاجرت کامل ۲۰ موضوع تک‌فایلی | `test_phase9_rule_dsl.py` و `test/advocate/rule_dsl_test.dart` |
| **فاز ۱۰** | کلوژرهای مرکب در ۴ موضوع بزرگ (`cheque`، `family`، `labor`، `rent`) مانع سریال‌سازی کامل موضوع‌ها بودند | توسعهٔ `rule_dsl_topic.dart` (`RankRule`، `FilingRule`، `PromptRule`، `FillRule`، `TxAssessDemands`، `TxRent`) و مهاجرت کامل ۴ موضوع بزرگ با **صفر کلوژر و صفر `=>` در کل ۲۴ موضوع** | `test_phase10_rule_dsl.py` و `test/advocate/phase10_rule_dsl_test.dart` |
| **فاز ۱۱** | هم‌پوشانی و تکرار ضرایب موتور، الگوهای ماده و جدول‌های نرمال‌سازی بین دارت و پایتون | تکمیل قراردادهای `text_norm.json` و `law_terms.json` و ایجاد قرارداد `engine_rules.json` با مولد `gen_engine_rules.py` → تولید `lib/core/engine_rules.dart` و `dev/brain/engine_rules.py` و اتصال تمام مصرف‌کنندگان دو زبان | `test_engine_rules_parity.py`، `test/core/engine_rules_test.dart`، `check.py enginerules` |
| **فاز ۱۲** | عددهای جادویی آستانه‌های موضوع (`3`/`5`)، ریسک cast ناایمن در `TopicFlow.route`، چند `open()` بی‌بست در `dev/brain/` و ردیف‌های کهنه در `ROADMAP.md` | تعریف `topicOpenMin`/`topicStrongMin`/`topicDominantMin` در `advocate_data.dart` متصل به `assets/pipeline.json` و `DartLibrary` در `pipeline_check.py`؛ جایگزینی `.cast`/`as String` در `topic_flow.dart` و `topic_flow.py` با بازگشت امن به `'ask'`؛ بستن فایل‌ها در `dev/brain/{common,alt_bench,embed_eval}.py`؛ به‌روزرسانی `ROADMAP.md`، `CONTRACTS.md` و `ARCHITECTURE.md` | `pipeline_contract_test.dart`، `test_pipeline_check.py`، `topic_flow_test.dart`، `test_topic_flow.py` و `test_dev_tools_hygiene.py` |
| **فاز ۱۳** | نادیده‌گرفته‌شدن `bool` ناموفق در `SharedPreferences` و خروجی تهی در `PrivacyService.seal`؛ کرش احتمالی روی `t` خراب بازخورد، فیلد بدشکل قالب یا `articles` غیرِ`Map` در `TermReply`؛ رقابت پوش در `commit-reports`ِ CI | بررسی بازگشت `bool` در `AppSettings` و `HistoryStore` و ثبت خطا در `lastError`؛ ثبت `_markFallback(null)` در `PrivacyService.seal`؛ پارس نوع‌امن در `FeedbackEntry.fromJson`، `TemplateField`/`LegalTemplate.fromJson` (`FormatException`) و `TermReply._topicLeaf`؛ افزودن حلقهٔ بازآزمایی `pull --rebase` به `.github/workflows/test.yml` | `settings_failure_test.dart`، `privacy_test.dart`، `feedback_test.dart`، `test/drafting/logic_test.dart`، `topic_flow_test.dart` و `test_startup_budget.py` |
| **فاز ۱۴** | خطاهای خاموش در `FeedbackStore`، `DraftCheckpointStore` و بخش‌هایی از UI (`FeedbackBar`، `SettingsPage`، `HistoryPage`، `ReplyFlow`)؛ ۱۲ هشدار واژهٔ دروازهٔ عام در `lab/topics/` (`check.py topics`)؛ نداشتن ابزار مصرف/پالایش بازخوردهای صادرشده (`F13`) | افزودن `lastError` و `Future<bool> clear()` به `FeedbackStore` و `DraftCheckpointStore`؛ بازگرداندن رأی و نمایش خطا در `FeedbackBar`، کارت خطای تاریخچه و بررسی خطای پاک‌سازی در `SettingsPage`، `SnackBar` خطای حذف در `HistoryPage` و ثبت `history.lastError` در `ReplyFlow`؛ حذف ۱۲ واژهٔ عام دروازه از `lab/topics/{labor_wages,rent}.json`؛ ساخت `dev/tools/feedback_eval.py` متصل به `lawtext.py` برای راستی‌آزمایی و افزودن بازخوردها به `eval/` | `feedback_test.dart`، `draft_checkpoint_test.dart`، `settings_failure_test.dart`، `topic_flow.py --check` (`۴۶/۴۶`)، `check.py topics` (بدون هشدار) و `test_feedback_eval.py` |

---

## ۵. ضعف‌های فعلی برنامه (تحلیل صادقانه)

1. **محتوای حقوقی تأییدنشده (مهم‌ترین ریسک محصولی):** هیچ‌کدام از ۲۴ قانون با منبع رسمی تطبیق داده نشده‌اند (`۰/۲۴ verified`)، `doctor.py` هنوز ۱۲۷ مادهٔ جاافتاده را به‌عنوان `info` گزارش می‌کند و ۷ قالب از ۹ قالب سند «پیشنویس» بدون بازبینی انسانی‌اند.
2. **افت دقت بازیابی روی پرسش‌های مبهم یا خارج از واژگان دقیق (`eval_blind` و `LawTerms`):**
   - روی جمله‌های ندیده و محاوره‌ای (`eval/eval_blind.txt`) امتیاز فعلی `recall@1 = 0.58` و `MRR = 0.714` است (در مقایسه با `0.93` روی `eval.txt`).
   - در گزارش ممیزی `reports/term_audit.md` از ۱۴ پرسش سخت، ۸ مورد درست و **۶ مورد باز** مانده است؛ از جمله تطبیق غلط جمله‌های غیرحقوقی (`نزدیک‌ترین ستاره به زمین` یا `بهترین نرم‌افزار ویرایش عکس`) با مواد قانون، و نپذیرفتن پرسش‌های کوتاه حقوقی مانند «قولنامه عادی»، «خیانت در امانت» و «بیع شرط رهن». همچنین در `eval_none.txt` از ۲۸ پرسش نامرتبط، ۱ مورد با اطمینان پاسخ غلط گرفته است.
3. **محدودیت‌های مدل برداری `Noql` و نفی:** مدل `Noql` روی `eval/understanding_probe.tsv` هنوز در جملهٔ «ماشینم را فروخته ام ولی خریدار پولش را کامل نداده» خطای `opened-WRONG` (`consumer` به‌جای `debt|property`) دارد، جمله‌های منفی و مثبت هم‌ریشه را نزدیک هم می‌بیند (شباهت کسینوسی `۰٫۸۷` تا `۰٫۹۳` در `reports/alt_bench.md`) و آستانه‌های آن (`۰٫۱۴۳` / `۰٫۰۴`) روی ۲۵۰ نمونه تنظیم شده‌اند.
4. **بدهی دوپیاده‌سازی پایتون ↔ دارت:** با وجود یک‌منبع‌شدن داده‌ها و ضرایب (`text_norm.json`، `law_terms.json`، `engine_rules.json`، `pipeline.json`)، خودِ **الگوریتم** در ۴ جفت (`duplicated_logic.json`: نرمال‌سازی، BM25F، تطبیق واژه و `TopicFlow`) همچنان هم در Dart و هم در Python پیاده شده است و مشتق‌های `_meta.json` (`laws_catalog.json`، `data_info.json`) به‌صورت دستی با `sync_meta.py` همگام می‌شوند.
5. **محدودیت ذخیره‌سازی بر پایهٔ `SharedPreferences` و نبود پایگاه‌دادهٔ ساختاریافته:** کل تاریخچه، پیش‌نویس و بازخورد در کلید-مقدارهای رمزنگاری‌شدهٔ `SharedPreferences` می‌نشینند، نه SQLite/SQLCipher؛ با افزایش حجم گفتگوها جست‌وجو فقط در حافظه انجام می‌شود و قابلیت مهاجرت ساختاریافتهٔ جداول وجود ندارد.
6. **فرض «تومان → میلیون تومان» در `Sense.amount`:** در `lib/domain/advocate/text_sense.dart` اعداد ۱ تا ۳ رقمیِ همراه با «تومان» (مثل «۵۰ تومان») به‌طور خودکار به ۵۰ میلیون تومان تبدیل می‌شوند. در گفتگوی محاوره‌ایِ اجاره این حدس کمک می‌کند، اما برای مبالغ واقعیِ خُرد (هزینهٔ دادرسی یا خسارت جزئی) خطر محاسبهٔ نادرست یک‌میلیون‌برابری دارد.
7. **جمع‌آوری دستی برچسب بازخورد پیش از `feedback_eval.py`:** اکنون ابزار `dev/tools/feedback_eval.py` خروجی صادرشدهٔ `FeedbackStore.exportText` را پالایش، با `_meta.json` و متن واقعی مواد راستی‌آزمایی و پس از حذف تکراری‌ها به `eval/` اضافه می‌کند؛ با این حال، واردکردن قانون و مادهٔ درستِ هر بازخورد منفی (`؟ | ؟`) همچنان نیازمند برچسب‌گذاری انسانی است و حلقهٔ خودکار رگرسیون درون گوشی اجرا نمی‌شود.
8. **عدم هم‌خوانی نسخهٔ SDK اعلامی با `pubspec.lock` و اجرای ناکامل ارزیابی در سندباکس:** `pubspec.yaml` حداقل SDK را `>=3.0.0` می‌نویسد در حالی که `pubspec.lock` به `Dart >=3.13.0` / `Flutter >=3.44.0` وابسته است (و در محیط ابری نویسنده ابزارهای `flutter` و `dart` نصب نبودند؛ از این‌رو صحت کدهای Dart از مسیر CI و گزارش‌های رسمی آن تایید شده است).
9. **داوری ۲۴ موضوع همچنان کد-پایه در `_reply`:** ترتیب کاندیدها از `pipeline.json` قفل شده، اما ارزیابی نهایی مسیرها و پیش‌شرط‌های ۲۴ موضوع هنوز در `advocate_reply*.dart` به‌شکل کد دستوری اجرا می‌شوند و موتور مستقلی برای اجرای مستقیم `Topic.toJson()` وجود ندارد.

---

## ۶. پیشنهادات اولویت‌دار برای ارتقای بعدی

1. **تطبیق و ممیزی حقوقی محتوای قوانین و قالب‌ها (اولویت ۱ — شرط انتشار):** تکمیل فیلدهای `status: verified`، `source` و `url` در `assets/laws/_meta.json` با استناد به روزنامهٔ رسمی/سامانهٔ قوانین، بررسی ۱۲۷ مادهٔ جاافتاده (به‌ویژه در `commerce` و `penal_taazirat`) و بازبینی ۷ قالب باقی‌مانده تا سبزشدن `check.py trust`.
2. **بهبود دقت `LawTerms` و `BM25F` برای ۶ مورد باز `term_audit.md` و `eval_blind` (اولویت ۲):** افزودن بررسی هم‌معنایی/حوزهٔ حقوقی پیش از پذیرش `LawTerms` تا جمله‌های نامرتبطِ دارای یک واژهٔ مشترک عمومی (مانند «زمین» یا «عکس») پذیرفته نشوند، گسترش `assets/synonyms.txt` برای عبارات محاوره‌ای/حقوقی («قولنامه عادی»، «خیانت در امانت»، «بیع شرط») و افزودن نمونه‌های کور تازه از بازخوردها.
3. **حذف بدهی دوپیاده‌سازی پایتون ↔ دارت (اولویت ۳):** افزودن یک runner سبک CLI در Dart برای اجرای مستقیم `KnowledgeEngine` و `Sense` روی فایل‌های `eval/*.txt` و `tests/*.json` در CI؛ با این کار منطق آینه‌ای در `dev/brain/{common,engine}.py` و `dev/tools/{eval_py,law_terms,topic_flow}.py` قابل حذف خواهد بود.
4. **ارتقای لایهٔ ذخیره به SQLite + SQLCipher (اولویت ۴):** جایگزینی `SharedPreferences` برای تاریخچهٔ گفتگوها، بازخورد و پرونده‌ها با پایگاه‌دادهٔ رمزنگاری‌شدهٔ SQLCipher جهت پشتیبانی از جست‌وجوی سریع بدون بارگذاری کل پیام‌ها در RAM و مهاجرت نسخه‌دار جداول.
5. **تایید تعاملی مبالغ در `Sense.amount` (اولویت ۵):** به‌جای ضرب قطعی اعداد کوچک در ۱٬۰۰۰٬۰۰۰، وقتی واحد «میلیون/هزار» صریح ذکر نشده (`!Sense.amountIsExplicit`)، وکیل می‌تواند با دکمه‌های پیشنهادی بین مبلغ خُرد و میلیون تومان تایید بگیرد تا هم مکالمهٔ طبیعی حفظ شود و هم خطای عددی رخ ندهد.
6. **اجرای موتور موضوع از روی JSON تولیدشدهٔ `RuleDSL` (اولویت ۶):** اکنون که هر ۲۴ موضوع دارای `Topic.toJson()` کامل هستند، می‌توان بارگذار موضوع از JSON ساخت تا به‌روزرسانی قواعد و متون موضوع‌ها بدون کامپایل مجدد کد Dart ممکن شود.
7. **هم‌راستاسازی `pubspec.yaml` و ارزیابی دوره‌ای خروجی `feedback_eval.py`:** به‌روزرسانی محدودهٔ SDK در `pubspec.yaml` مطابق نسخهٔ CI (`Flutter 3.47.6` / `Dart >=3.13.0`) و تبدیل دوره‌ای بازخوردهای برچسب‌خوردهٔ کاربران با `dev/tools/feedback_eval.py` به مجموعهٔ آزمون کور برای جلوگیری از بازگشت خطاها.

---

## ۷. اجرای محلی آزمون‌ها و دروازه‌ها

```sh
flutter pub get
flutter analyze --fatal-warnings
flutter test
python3 -W error::ResourceWarning -m unittest discover -s tests/python -q
python3 dev/tools/check.py all
python3 dev/tools/doctor.py
python3 dev/tools/eval_py.py --check
python3 dev/tools/eval_none.py --check
python3 dev/tools/check.py trust   # تا پیش از تایید رسمی قوانین و قالب‌ها عمداً با کد ۱ خارج می‌شود
```

**شرط صداقت محیط اجرا:** در محیط ابریِ توسعه، فقط `python3` موجود بود و ابزارهای `flutter` و `dart` محلاً نصب نبودند؛ اما تمام تغییرات Dart و سناریوها در گردش‌کارهای واقعی GitHub Actions (`Test`، `Lawyer Lab` و `Intent scenarios`؛ گزارش‌ها در `reports/last_test.txt`، `reports/coverage.txt`، `reports/startup.txt` و `reports/lab/`) اجرا و با **۷۲۵ آزمون Dart سبز**، پوشش **۹۱٫۷٪**، خط پایهٔ استارت **۹۴۴ ms** و **۰ خطای تحلیل‌گر** تایید شده‌اند. برای جزئیات عمیق‌تر ببینید: `docs/ARCHITECTURE.md`، `docs/CONTRACTS.md`، `docs/PHASES.md`، `docs/ROADMAP.md` و `docs/CODE_REVIEW.md`.

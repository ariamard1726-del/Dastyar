# معماری دستیار

یک صفحه نقشهٔ معماری: لایه‌ها، جریان یک پیام، منابع یکتای داده و دروازه‌های CI.

برنامه کاملاً آفلاین است: مدل زبانیِ مولد (LLM) ندارد، مجوز اینترنت نمی‌خواهد و هیچ جمله‌ای را ماشین «تولید» نمی‌کند. همهٔ پاسخ‌ها از قاعده‌های صریح و متن قوانینِ داخل برنامه ساخته می‌شوند. تنها مدلِ آموخته، یک مدل برداری کوچک (Noql) است که فقط موضوع پیام را حدس می‌زند؛ بخش «خوانندهٔ موضوع» را ببینید.

## لایه‌های `lib/`

وابستگی فقط رو به پایین است (core ← domain ← ui ← main): هیچ فایلی در `core/` چیزی از `domain/` یا `ui/` وارد نمی‌کند و هیچ فایلی در `domain/` چیزی از `ui/`. نمودارهای معماری در `docs/diagrams/` نگهداری می‌شوند (`docs/diagrams/layers.mmd` و `docs/diagrams/message_flow.mmd`).

| لایه | نقش | فایل‌ها |
|---|---|---|
| `lib/core/` | زیرساخت و بازیابی BM25F، بدون شناخت از قابلیت‌های وکیل | `persian_text` + `text_norm_rules` (لایهٔ یکتای متن فارسی)، `asset_loader` (`AssetTextLoader`) + `engine` + `engine_rules` + `models` + `law_topic_prior` (نمایهٔ BM25F و بازیابی ماده)، `router` (`QueryRouter` برای نیت‌های ثابت موتور)، `conflicts_service`، `replies`، `privacy`، `local_store` (`KeyValueStore`، `SharedPrefsKeyValueStore`، `MemoryKeyValueStore`) + `storage_migration` (`StorageMigration`)، `history`، `legacy_cleanup` |
| `lib/domain/` | قابلیت‌های حقوقی و مدل‌های آفلاین (کاملاً مستقل از فلاتر و `SharedPreferences`) | `advocate/` (وکیل)، `drafting` + `templates` (تنظیم سند)، `understanding/` (خوانندهٔ موضوع با مدل برداری Noql)، `intent_net` (طبقه‌بند نیت)، `input_suggestions`، `lawyer/` (راهنماها)، `feedback` (ذخیره روی `KeyValueStore` و صدور رمزنگاری‌شده، با `schemaVersion = 1`)، `settings_state` (مدل خالص تنظیمات بدون وابستگی فلاتر) |
| `lib/ui/` | نمایش و وضعیت گفتگو | `chat_page`، `chat_controller` (سیم‌کشی)، `app_settings` (`AppSettings` متصل به فلاتر)، `draft_flow`، `guess_flow`، `reply_flow`، `chat_models`، صفحه‌های تنظیمات/تاریخچه/درباره، `widgets/chat_bubbles`، `widgets/feedback_bar` |

## جریان یک پیام (تنها یک مسیر)

`ChatPage` → `ChatController.submit`:

1. اگر سندی در حال تنظیم است، پیام پاسخِ فیلد جاری است → `Drafting.answer`.
2. اگر پیام درخواست نوشتن سند است (دکمهٔ «تنظیم دادخواست …» یا «تنظیم لایحه …» همان پرونده، عنوان دقیق یک قالب، پاسخ به «کدام متن؟»، یا «برام بنویسش») → `Drafting.start`. برای «برام بنویسش» قالبی انتخاب می‌شود که به پروندهٔ جاری می‌خورد (`Advocate.draftIds`).
3. در غیر این صورت → `Advocate.respond`. اگر `Advocate.wantsGuess` بگوید قاعده‌ها موضوع این پیام را نشناخته‌اند (پرونده‌ای باز نیست، پیام دست‌کم سه واژه دارد)، کنترلر اول حدسِ خوانندهٔ موضوع را می‌گیرد و همراه پیام به وکیل می‌دهد.

کنترلر هیچ منطق حقوقی ندارد؛ فقط این‌ها را به هم وصل و تاریخچه را ذخیره می‌کند. پیام‌ها به ترتیب رسیدن پردازش می‌شوند، حتی اگر یکی منتظر مدل باشد.

## وکیل (`lib/domain/advocate/`)

- `text_sense.dart` (`Sense`): فهم متن محاوره‌ای با الگوهای منظم؛ مبلغ، مدت، بله/نه.
- `case_file.dart` (`CaseFile`، `Topic`، `Slot`، `Issue`، `Claim`، `Filing`): دروازهٔ پرونده — `CaseFile` در `case_state.dart` (وضعیت + JSON) و مدل‌های زبانِ موضوع در `case_model.dart`؛ این فایل فقط دو `export` است تا چهل مسیرِ `import` دست‌نخورده بماند.
- `topics/`: هر موضوع یک فایل به نام خودش (`rent`، `cheque`، `debt`، `labor`، `family`، `accused`، `partner`، `neighbor`، `admin`، `consumer`، `cyber`، `inherit`، `child`، `enforce`، `property`، `company`، `guarantee`، `marriage`، `injury`، و همچنین `fight`، `foreign_contract`، `minor_sale`، `sale`، `theft`). هر فایل همه‌چیزِ منطقی همان موضوع را دارد: الگوهای خواندن، قیدها، ادعاها و خودِ `Topic`؛ نثر ثابت فارسی در تمام ۲۴ موضوع و `topics/shared.dart` به JSON رفته است (`rent_texts_loader.dart` روی `assets/brain/topics/rent_texts.json` با ۵۲۵ کلید و `topic_texts_loader.dart` روی `assets/brain/topic_texts.json` با ۱٬۱۰۶ کلید در ۲۴ بخش؛ سر جمع ۱٬۶۳۱ کلید). `topics/shared.dart` تکه‌های مشترک (مرجع صالح، هزینه، زمان) و قرارداد نگارش را دارد و `topics/all.dart` تنها جایی است که موضوع‌ها ثبت می‌شوند (`allTopics`). افزودن موضوع تازه یعنی یک فایل تازه و یک خط در `all.dart`.
- `reasoner.dart` (`Reasoner`): استدلال روی واقعیت‌ها، بدون هیچ متنی. سه کار می‌کند: (۱) از میان `Claim`های موضوع، آن‌هایی را که با واقعیت‌های فعلی مطرح‌اند جدا می‌کند (یک ماجرا می‌تواند چند ادعا داشته باشد)؛ (۲) هر ادعا را شرط‌به‌شرط می‌سنجد و می‌گوید محکم است، هنوز باز است، یا گیر دارد؛ (۳) پرسش بعدی را آن پرسشی می‌گیرد که شرطِ نامعلومِ مهم‌ترین ادعای زنده را روشن می‌کند (`Element.needs`). موضوع‌های «کار»، «اجاره»، «چک»، «طلب» و «خانواده» شرط‌هایشان را به پرسش‌ها گره زده‌اند؛ در بقیهٔ موضوع‌ها ترتیب پرسش‌ها همان ترتیب نوشته‌شده است. روی همین سنجش، `advocate.dart` چهار رفتار دارد: جوابِ «می‌توانم…؟» حکمِ همان خواسته است (`Claim.cues`)؛ اگر حرف تازه نتیجه را عوض کند یا خواستهٔ تازه‌ای پیش بکشد همان‌جا گفته می‌شود؛ اگر کاربر حرف قبلی‌اش را برعکس کند، وکیل می‌گوید برداشتش را عوض کرده؛ و وقتی پرسش‌ها از یک خواسته به خواستهٔ دیگر می‌رود، اعلام می‌شود (`test/advocate/reasoner_test.dart`).
- `glossary.dart`، `phrases.dart`: واژه‌نامه و جمله‌های ثابت.
- `topics/rent.dart`: موضوع «اجاره و ودیعه»، مفصل‌ترین موضوع (الگوها، پرسش‌ها، بحث‌ها، ادعاها و سندها). هر الگو سه لایه دارد: زبان کوچه («بلندم کنه»)، زبان رسمی («تخلیه نمی‌نماید») و اصطلاح حقوقی («اجور معوقه»، «عین مستأجره»). محور پرونده برای مستأجر `matter` (ودیعه، افزایش اجاره، بیرون‌کردن، دستور تخلیه، تعمیر، زودتر رفتن) و برای موجر `aim` (تخلیه، اجارهٔ عقب‌افتاده، خسارت، تخلف از قرارداد) است. ترتیب `issues` مهم است: موتور نخستین بحثی را می‌گیرد که الگویش به پیام بخورد؛ پس بحث‌های مشخص پیش از بحث‌های کلی آمده‌اند (`test/advocate/rent_test.dart`).
- `advocate.dart` (`Advocate`): هماهنگ‌کننده. خودش فقط موتور، پرونده (`CaseFile`)، حالتِ روی میز (`DialogueState`) و صدا (`ReplyVoice`) را می‌شناسد و ترتیبِ مسیرها را می‌چیند؛ هر کدام از این‌ها صاحب جدا دارد:
  - `dialogue_state.dart` (`DialogueState`): «چه چیزی روی میز است» — پرسشی که پرسیده‌ام و دکمه‌هایش، پیشنهادِ معلق، موضوعِ منتظرِ تأیید، موضوعِ دومی که در همان پیام آمده (`also`)، راهنمای باز، حرف‌های شنیده‌شده و وضعیتِ ایمنی. پیش‌تر این ۲۵ فیلد روی `Advocate` بود (گاد-آبجکت)؛ سپس خودِ `DialogueState` گاد-آبجکت شد. اکنون نمایانهای نازک روی پنج تکهٔ `dialogue_sections.dart` است (`QuestionState`، `ChoiceState`، `GuideState`، `SafetyState`، `UnclearState`) و همان تکهها قابل ذخیرهاند (`toJson` / `applyJson`) تا وضعیت واقعی گفتگو در قالب ۴ تاریخچه برگردد.
  - `reply_voice.dart` (`ReplyVoice`): ساختِ پاسخ از متنِ آماده — برگرداندن ارجاع به نام ماده، کوتاه‌کردن، سقفِ تکرارِ پرسشِ بی‌جواب، چیدن دکمه‌ها. استنادهای آخر و متنِ آخرین پاسخ هم این‌جا می‌مانند.
  - روندِ پرونده چهار بخش است و همه `part`ِ `advocate.dart`: `case_flow.dart` (کلاس و ابزارها)، `case_facts.dart` (نوشتنِ `file.facts`)، `case_answer.dart` (تصمیمِ نوبت)، `case_text.dart` (جمله‌سازی). سه بخشِ دوم با `extension` روی `CaseFlow` نوشته شده‌اند تا سطحِ عمومی و دسترسی به وضعیت عوض نشود.
  - `advocate_reply.dart` (`extension _ReplyPipeline on Advocate`): ده تصمیمِ پاسخ؛ هم‌کتابخانه با `Advocate`، پس متدها خصوصی می‌مانند و API عوض نمی‌شود. سیم‌کشی و API عمومی در `advocate.dart` می‌مانند.
  - `safety_reply.dart` (`class SafetyReply`): پاسخِ خشونت/تهدید/اورژانس، پیش از هر پاسخِ دیگر؛ تنها قاعده‌ای که «حقوقی» نیست.
  - `topic_read.dart` (`class TopicRead`): نتیجهٔ خواندنِ موضوع از پیام (بهترین موضوع، امتیازش، امتیازِ همه) — یک مقدار، بی‌رفتار؛ تصمیم‌ها بیرونِ آن گرفته می‌شوند.
  - `answer_candidate.dart` (`class AnswerCandidate` / `class AnswerArbiter` / `class ReplyLoopGuard`): ترتیبِ پاسخ‌ها به‌جای زنجیرهٔ `if`، فهرستی از کاندیدهای نام‌دار است؛ داور اولین پاسخ‌دهنده را برمی‌گرداند و ترتیب = اولویت (بدونِ وزن‌دهی). نگهبان بازگشت (`ReplyLoopGuard` با `Advocate.maxReplyDepth = 1`) هم همین‌جاست تا حلقهٔ `routes → _reply → routes` یا شمارش دوبارهٔ `file.turns` با `StateError` متوقف شود.
  - `term_reply.dart` (`class TermReply`): پاسخ‌های واژه‌محور — تطبیقِ واژه‌ها با متنِ مواد (`lawTerms`) و مسیرهای تصمیم موضوعی (`topicFlow`).
  - `guide_reply.dart` (`class GuideReply`): راهنمای آماده، واژه‌نامه و آخرین راه (بانک پرسش‌وپاسخ + متن قوانین). `closeCase` را تابع می‌گیرد تا با `CaseFlow` گرهِ ساختِ دوسویه نخورد.
  - `reply_routes.dart` (`class ReplyRoutes`): سیزده مسیرِ یک‌نوبتیِ پاسخ؛ هر کدام `AdvocateReply?` برمی‌گرداند (`null` = این پیام مالِ من نیست). `ReplyRoutes` همکارهایش را در سازنده می‌گیرد (پرونده، گفتگو، صدا، `CaseFlow`، `TopicPicker`، `TalkReply`، `TalkRoute`، یک تابعِ بازگشت به `_reply`) و `_reply` فقط ترتیب را می‌چیند.
  بقیهٔ کار وکیل در بخش‌های همین کتابخانه است (`part`؛ هر بخش یک `extension` خصوصی روی `Advocate` به‌علاوهٔ تابع‌ها و ثابت‌های خودش):
  - `advocate_topic.dart`: تشخیص موضوع (امتیاز نشانه‌ها، حدس خوانندهٔ موضوع، نظر دوم طبقه‌بند).
  - `case_flow.dart` (`class CaseFlow`): روندِ پرونده — بازکردن، خواندنِ واقعیت‌ها (`absorb`)، پرسشِ بعدی (`nextAsk`)، واکنش، جمع‌بندی و پیشنهادِ قالب. هر چه از بیرون می‌خواهد در سازنده صریح است: پرونده، گفتگو، صدا، استدلال (`CaseArgument`)، تشخیصِ بحث (`TopicPicker`)، گفت‌وگوی انسانی (`TalkReply`)، بانک قوانین (`LawAnswer`)، دکمه‌ها (`ChipPlan`)، سندها، عنوانِ قالب‌ها، واژه‌نامه و راهنما. `advocate_case.dart` حالا فقط ۲۲ خط پوسته است.
  - `advocate_argue.dart`: استدلال — `class CaseArgument` (نه متدهای `Advocate`): پرونده و صدا را می‌گیرد و ارکان ✓ / ✗ / ؟ و نتیجه و اعلامِ تغییرِ نتیجه را می‌سازد.
  - `chip_plan.dart` (`ChipPlan`): دکمه‌های پیشنهادی — موضوع، پرونده و وضعیتِ روی میز را می‌گیرد و فهرستِ دکمه‌ها را برمی‌گرداند؛ `advocate_chips.dart` حالا فقط سه متدِ نازکِ `Advocate` است که به همین کلاس وامی‌گذارند.
  - `advocate_meta.dart` (`class MetaReply`): پاسخ‌های «دربارهٔ خودِ برنامه» و «ماجرای حقوقی نیست» — چهار متدِ `Advocate` شدند چهار متدِ این کلاس؛ `current` و `anyTopicCue` را از بیرون می‌گیرد و `hasCase` را از پرونده و حالتِ روی میزِ خودش می‌سازد.
  - `law_answer.dart` (`class LawAnswer`): پاسخ از بانک پرسش‌وپاسخ و از متن قوانین. موتور، صدا و شناساییِ طرفِ گفتگو را می‌گیرد؛ وقتی جوابی ندارد `null` می‌دهد و تصمیمِ بعدی («نمی‌فهمم»، موضوعِ درِ دروازه، پرسشِ کنجکاو) کارِ وکیل می‌ماند.
  - `talk_route.dart` (`class TalkRoute`): مسیرِ گفت‌وگویی که به پرونده مربوط نیست — سلام، تشکر، توهینِ کوتاه، سوگ، خلاصه‌خواستن، دستهٔ مشکل و «خارج شدم و برگشتم». `_meta` (۲۲۹ خط) و سه متدِ همراه‌ش از `Advocate` رفتند.
  - `talk_reply.dart` (`class TalkReply`): گفت‌وگوی انسانی — خلاصه، احوال‌پرسی، سوگ و «منظورتان چیست؟». `_summary`/`_social`/`_hopeless`/`_curious`/`_unclearReply` و دو یارِ آن‌ها از `Advocate` رفتند.
  - `topic_picker.dart` (`class TopicPicker`): تشخیص موضوع و بحث — «این پیام جوابِ همان پرسشِ باز است؟»، حدسِ موضوع از طبقه‌بند، و تطبیقِ بحث/راهنما. برای بازکردنِ پرونده یک تابع از بیرون می‌گیرد.
  - `case_recap.dart` (`recapOf`): خلاصهٔ پرونده از روی موضوع و پرونده، بی‌نیاز از وکیل؛ همان چیزی که به `CaseArgument` هم داده می‌شود.
  - `advocate_talk.dart`: گفت‌وگوی انسانی (احوال‌پرسی، خلاصه، حرف مبهم).
  - `advocate_text.dart`: جمله‌بندی و بریدنِ متن برای پاسخ.
  - `advocate_reply.dart` (۱۷۳ خط): **فقط ترتیب** — بیست `AnswerCandidate` که داور اولین پاسخ‌دهنده را برمی‌گرداند؛ ترتیب = اولویت. `advocate_reply_guard.dart` (۲۰۵): نگهبان‌های پیش از ترتیب (`_guardedReply` برای قفل بازگشت، `_leaveReply`، `_filingReply`، `_objectionDeadline`، `_safetyReply`، `_readTopics`، `_correctionReply`). `advocate_reply_case.dart` (۱۸۴): دو شاخهٔ «پرونده باز است / باز نیست» و پرسشِ تغییرِ موضوع (`_noCaseReply`، `_inCaseReply`، `_askSwitch`). ترتیبِ بیست کاندید با `tests/python/test_reply_pipeline_shape.py` قفل است. آستانه‌های موضوع (`topicOpenMin = 3`، `topicStrongMin = 5`، `topicDominantMin = 5`) در `advocate_data.dart` تعریف شده‌اند تا همهٔ اجزای وکیل همان آستانه‌های `assets/pipeline.json` را بخوانند و `TopicFlow.route` (`topic_flow.dart`) در برابر ورودی‌های ناقص بدون کرش به `'ask'` برگردد.
  - `case_file.dart` (۹ خط): فقط `export` — دروازه. `CaseFile` (وضعیت + `toJson`/`fromJson` + `schemaVersion`) در `case_state.dart` (۱۳۶) است و مدل‌های زبانِ موضوع (`Element`، `Claim`، `Slot`، `Issue`، `Filing`، `Prompt`، `Topic` + سازنده‌های `.dsl` و `Topic.fromJson`) در `case_model.dart` (۲۷۳). لایهٔ `RuleDSL` (`rule_dsl.dart` ۲۶۳ خط، `rule_dsl_text.dart` ۳۵۱ خط، `rule_dsl_read.dart` ۲۳۴ خط، `rule_dsl_topic.dart` ۲۸۴ خط، `rule_dsl_json.dart` ۱۳۷ خط، `rule_dsl_from_json.dart` ۲۱۴ خط، `rule_dsl_topic_from_json.dart` ۲۳۲ خط) امکان تعریف هر ۲۴ موضوع را با `.dsl(...)` بدون کلوژر بی‌نام و با چرخهٔ کامل `toJson()`/`Topic.fromJson()` فراهم می‌کند. API عمومیِ `Advocate` عمداً روی خودِ کلاس می‌ماند، نه `extension` (عضوِ `extension` از راهِ نوع دیده نمی‌شود؛ `tests/python/test_advocate_shape.py::test_public_api_stays_on_the_class`).
- `topic_score.dart` (`TopicScore`) و `case_plan.dart` (`CasePlan`): «این پیام کدام موضوع است؟» و «حالا چه بپرسم؟» — دو تابعِ خالص، بی‌نیاز از `Advocate` و بی‌نیاز از بانک قوانین؛ `test/advocate/isolation_test.dart` مستقیم صدایشان می‌زند.
- `topics/rent.dart` فقط سرِ کتابخانه است (`۲۶` خط، فقط `part`ها)؛ خودِ موضوع در **۱۳** تکه: `rent_patterns.dart` (۳۳۴، الگوهای واژگانی — `const String`)، `rent_reads.dart` (۱۸۰، خواندنِ نقش/موضوع/هدف/بله‌و‌نه)، `rent_bodies.dart` (۱۷۳، متنِ پاسخِ مستأجر و مشترک)، `rent_bodies_landlord.dart` (۱۳۸، متنِ پاسخِ موجر)، `rent_slots.dart` (۲۷۱، واقعیت‌هایی که پرسیده یا خوانده می‌شوند)، `rent_effects.dart` (۷۲، اثرِ حقوقیِ هر واقعیت)، `rent_issues.dart` (۷۷، سرِ فهرست و `rentTopic`) + `rent_issue_both.dart` (۶۶) + `rent_issue_tenant.dart` (۲۵۹) + `rent_issue_landlord.dart` (۲۰۸) که با `[...Both, ...Tenant, ...Landlord]` به همان ترتیبِ پیشین می‌پیوندند (ترتیب = اولویتِ نمایش)، `rent_claims.dart` (۳۳۱، ادعاها)، `rent_plan.dart` (۲۵۷، طرح دعوا/مدرک/مهلت)، `rent_fill.dart` (۲۶۱، متنِ فیلدهای دادخواست). متنِ حقوقی کلمه‌به‌کلمه جابه‌جا شد؛ مقایسهٔ خط‌به‌خط پیش و پس: صفر خطِ گم‌شده (`docs/GOD_OBJECTS.md`). تمام متنهای ثابت اجاره — ۴۲ رشتهٔ پایه، ۸۷ ادعا، ۳۲ برچسبِ سند، ۳۶ طرحِ دعوا، ۵۱ پارهٔ پاسخ (`rent_bodies*`)، ۵۱ متنِ آزادِ فیلدهای سند (`rent_fill`)، ۲۸ پرسشِ دکمه‌دار (`_rentAskReply`)، ۳۳ اثرِ حقوقی (`rent_effects` + `rent_slots`)، ۵۸ متنِ پرسش/توضیح/گزینه (`rent_slots`)، ۵۷ برچسب و عنوان/آغاز (`rent_issue_*` + `rent_issues`) و ۵۰ متنِ پایان طرح و خلاصهٔ پرونده (`rent_plan` / `rentRecap`) — اکنون در یازده جدولِ `texts`، `claims`، `filings`، `plans`، `bodies`، `fills`، `prompts`، `effects`، `slots`، `issues` و `recaps`ِ `assets/brain/topics/rent_texts.json`اند (جمعاً ۵۲۵ کلید) و `rentText(id)` (`rent_texts_loader.dart`) آنها را میخواند؛ قوانین `RuleDSL`، Regexها و ۱۵ گزینهٔ قالبمحور `rent_fill` در Dart ماندهاند. هشِ نویسهبهنویسه در `tests/python/test_rent_text_equivalence.py` قفل است.
- موضوع‌های «کار» و «خانواده» هم به همین قرارداد شکسته شده‌اند: `labor_patterns/claims/bodies/issues` (`۱۱۲`+`۱۵۶`+`۱۱۲`+`۲۹۷`، سرِ کتابخانه `labor.dart` ۱۲ خط) و `family_patterns/claims/bodies/issues` (`۷۲`+`۳۴`+`۱۰۰`+`۲۴۰`، سرِ کتابخانه `family.dart` ۱۲ خط)؛ همراه با `topics/shared.dart` و هر ۲۱ موضوع غیرِاجارهٔ دیگر (`accused` تا `theft`)، تمام ۱٬۱۰۶ متن ثابت آنها اکنون در `assets/brain/topic_texts.json` (۲۴ بخش) نگهداری و با `topicText(section, key)` (`topic_texts_loader.dart`) خوانده می‌شوند و برابریشان با `tests/python/test_topic_text_equivalence.py` قفل است. نثر ثابتِ ۲۱ فایلِ غیرموضوعی در `lib/domain/advocate/*.dart` نیز (واژه‌نامه، عبارت‌های چرخشی، ایمنی، راهنما، گفت‌وگو و استدلال — ۴۷۰ کلید در ۱۸ بخش) در `assets/brain/advocate_texts.json` نگهداری و از طریق `advocateText` / `advocateFormat` / `advocateTextSeq` (`advocate_texts_loader.dart`) خوانده می‌شود و با `tests/python/test_advocate_text_equivalence.py` قفل است. آزمون‌های `test/advocate/labor_test.dart` و `family_test.dart` پیش از شکستن نوشته شدند تا رفتار قفل باشد.

سه امکان که فعلاً فقط موضوع اجاره از آن‌ها استفاده می‌کند ولی در `case_model.dart` (مدل‌های زبانِ موضوع) برای همهٔ موضوع‌هاست:

- `Slot.sticky` و `Slot.priority`: واقعیتِ محوری (دعوا سرِ چیست) با اشارهٔ گذرا به بحثی دیگر عوض نمی‌شود؛ آن بحث جواب می‌گیرد ولی پرونده همان می‌ماند. فقط جوابِ همان پرسش، اصلاح صریح کاربر («منظورم … بود») یا رسیدن به مقدار مهم‌تر (`priority`) آن را تغییر می‌دهد (`absorb` در `case_facts.dart`).
- `Issue.rank`: هر بحث می‌گوید با واقعیت‌های همین پرونده چقدر «پرسشِ بعدیِ طبیعی» است؛ رتبهٔ منفی یعنی به‌عنوان دکمه پیشنهاد نشود (ولی اگر کاربر بپرسد جواب می‌گیرد).
- `Topic.petition`، `Topic.brief` و `Topic.fill`: دادخواست و لایحه‌ای که به همین وضعیت می‌خورد (`Filing`: قالب، متن دکمه، نام سند) و متن پیشنهادی برای فیلدهای آن قالب از روی واقعیت‌های پرونده.

موتورِ قوانین (`lib/core/engine.dart`) حالا فقط بارگذاری و پاسخ‌سازیِ کلان است و چهار همکار و یک مرجعِ قاعده (`engine_rules.dart`) دارد:

- `law_index.dart` (`LawIndex`): بخش‌ها، نمایهٔ واژه‌ها، فهرستِ وارونه و ایندکسِ مواد؛ خواندنِ متنِ قانون هم این‌جاست (`parseInto`، `build`) — `test/core/law_index_test.dart` بدونِ دارایی‌ها.
- `law_ranker.dart` (`LawRanker`): BM25F، گسترشِ پیشوند، پوشش و جلو‌آوردنِ مادهٔ تعریف‌کننده؛ ورودی‌هایش تزریق می‌شوند (ایندکس، شناساییِ نامِ قانون، ضریبِ موضوعی، مترادف‌ها) — `test/core/law_ranker_test.dart`.
- `law_mention.dart` (`LawMention`): کدام قانون در این جمله نام برده شده — `test/core/law_mention_test.dart`.
- `law_text.dart` (`LawText`): نوشتنِ متنِ ماده، فهرستِ قوانین و جملهٔ «پیدا نکردم» — `test/core/law_text_test.dart`.
- `article_query.dart` (`ArticleQuery`): الگوی «ماده ۱۲» و نامِ استانداردِ آن؛ مشترکِ موتور و رتبه‌بندی.
- `engine_rules.dart` (`EngineRules`): ثوابت، آستانه‌ها و الگوهای تولیدشده از `dev/tools/contracts/engine_rules.json` (مشترک با `dev/brain/engine_rules.py`).

چینش دکمه‌های پیشنهادی (`_suggest` در `advocate_chips.dart` و `_finish` در `advocate_case.dart`): وقتی وکیل پرسشی با گزینه پرسیده، اول گزینه‌های جواب می‌آید و بعد «تنظیم دادخواست …» و «تنظیم لایحه …». در بقیهٔ حالت‌ها چینش ثابت است: (۱) نزدیک‌ترین پرسش به همین گفتگو (از روی `rank` و حرف‌های خودِ کاربر)، (۲) دادخواست، (۳) لایحه، و بعد بقیهٔ پرسش‌ها. موضوعی که `petition` و `brief` ندارد مثل قبل رفتار می‌کند (عنوان یک قالب در انتهای پیشنهادها).

قاعده‌های بازشدن و عوض‌شدن پرونده:

- بدون پرونده، موضوعی باز می‌شود که جمع وزن نشانه‌هایش در پیام دست‌کم ۳ باشد.
- وسط پرونده، یک نشانهٔ تنها باعث پرش به موضوع دیگر نمی‌شود؛ وکیل می‌پرسد که آیا ماجرای جداگانه‌ای است.
- **ایمنی پیش از موضوع:** بررسی خشونت/اورژانس (`_safety`) پیش از سنجش موضوع و مستقل از امتیازش اجرا می‌شود؛ در هر پرونده یک بار. اگر همان پیام موضوع روشنی هم داشته باشد، پرونده بی‌صدا باز می‌شود تا گفتگو گم نشود؛ وگرنه متن پیام برای نوبت بعد نگه داشته می‌شود (`_safetyCarry`).

**مسیر پاسخ (`AnswerSource`):** هر `AdvocateReply` برچسب دارد که از کدام مسیر دانش آمده — `safety`، `topic`، `lawTerms`، `glossary`، `guide`، `topicFlow`، `guess`، `intentNet`، `qaBank`، `engine`. ترتیب قراردادی در `assets/pipeline.json` ثبت شده و `Advocate.pipelineOrder` باید عیناً همان باشد (`dev/tools/pipeline_check.py` این را می‌سنجد)؛ `test/advocate/answer_source_test.dart` این قرارداد را می‌سنجد. برچسب فقط برای شفافیت و آزمون است و هیچ فراخوانی مدل تازه‌ای اضافه نمی‌کند.

### خوانندهٔ موضوع (`lib/domain/understanding/` + `assets/brain/noql*`)

مدل برداری فارسی `shekar-ai/Noql` (ALBERT، ۱۲٫۷ میلیون پارامتر) دست‌نخورده، به‌علاوهٔ یک سرِ طبقه‌بندِ کوچک (رگرسیون لجستیک روی بردار ۷۶۸تایی، ۱۹ دسته، آموخته از `eval/topic_examples.tsv`). همه‌چیز Dart خالص است و کتابخانهٔ بومی ندارد:

- `noql_tokenizer.dart`: توکن‌ساز Unigram مدل؛ `noql_encoder.dart`: گذر رو به جلو با وزن‌های int8 (`assets/brain/noql.bin`، حدود ۱۲ مگابایت)؛ `topic_reader.dart`: بردار → دسته و اطمینان؛ `reader_service.dart`: اجرای همین‌ها در Isolate جدا تا صفحه قفل نشود.
- فایل‌های `assets/brain/noql*` و مرجع تست (`test/understanding/noql_ref.json`) را `dev/brain/noql/export.py` می‌سازد (گردش‌کار «Noql export»). همان‌جا هستهٔ مرجع پایتون (`dev/brain/noql/core.py`، همان الگوریتمِ کد Dart) با کتابخانه‌های اصلی مدل مقایسه می‌شود؛ گزارش در `reports/noql_export.md`. `test/understanding/noql_test.dart` نگهبانِ برابری Dart با آن مرجع است.
- آستانه‌ها (`open`، `margin`، `ask` در `noql_head.json`) فقط از اعتبارسنجی روی خودِ نمونه‌ها انتخاب می‌شوند، نه از جمله‌های محک.

وکیل با حدس سه کار می‌کند (`_fromGuess` در `advocate_topic.dart`): حدسِ مطمئن پروندهٔ موضوعِ هم‌معنا را باز می‌کند، در جواب می‌گوید «برداشتم این است که…» و دکمهٔ «موضوعم این نیست» می‌گذارد؛ حدسِ نامطمئن به پرسش «ماجرای شما به کدام نزدیک‌تر است؟» با دو گزینه می‌رسد؛ حدسِ ضعیف یا دسته‌ای که پرونده ندارد (`crime`، `general`، `chat`، `other`) نادیده گرفته می‌شود. نگاشت دسته‌ها به موضوع‌ها در `Advocate.guessTopics` است. مدل هیچ واقعیتی نمی‌خواند (نفی را نمی‌فهمد) و هیچ متنی نمی‌نویسد. نتیجهٔ قاعده‌ها به‌تنهایی و قاعده‌ها + مدل روی `eval/understanding_probe.tsv` در هر اجرای تست در `reports/understanding.txt` نوشته می‌شود.

محدودیت: هنگام بازکردن یک گفتگوی ذخیره‌شده (`Advocate.replay`) حدس‌ها دوباره محاسبه نمی‌شوند؛ پرونده‌ای که با حدس باز شده بود ممکن است بازسازی نشود.

### طبقه‌بند نیت (`intent_net.dart` + `assets/brain/intent_model.json`)

یک شبکهٔ کوچک (n-gram هش‌شده + یک لایهٔ پنهان) در یک فایل JSON سبک؛ مدل زبانی نیست و متنی نمی‌نویسد. فقط وقتی به‌کار می‌آید که خوانندهٔ موضوع حدسی نداده باشد (مثلاً مدل بار نشده). نقش آن «نظر دوم» است: فقط وقتی که هیچ پرونده‌ای باز نیست، قاعده‌ها موضوع را نشناخته‌اند، پیام دست‌کم سه واژه دارد و ارجاع مستقیم به ماده نیست. اگر طبقه‌بند با اطمینان ≥ ۰٫۶ یکی از برچسب‌های `cheque`، `debt`، `family`، `labor`، `lease` را بدهد، پروندهٔ همان موضوع باز می‌شود. متن پاسخ همچنان از قاعده‌های وکیل است. بدون این فایل هم وکیل کامل کار می‌کند (`test/advocate/intent_hint_test.dart`).

## موتورِ دانش

سه بخش، هر کدام یک مسئولیت: `engine.dart` (وضعیت و API عمومی: فهرستِ قوانین، ایندکس، پاسخ‌های ثابت)، `engine_load.dart` (تنها جایی که دارایی خوانده می‌شود؛ `load` و بارگذارهای کمکی)، `engine_query.dart` (یافتنِ ماده، رتبه‌بندی، پیشنهادها). دو بخشِ دوم `part`ِ همان کتابخانه‌اند و با `extension` روی `KnowledgeEngine` نوشته شده‌اند، تا سطحِ عمومی و اعضای خصوصی دست‌نخورده بمانند. لایهٔ `core` به `domain` وابسته نمی‌شود و آزمونِ `test_engine_shape.py` همین را نگه می‌دارد.

## تنظیم سند

پنج بخش، هر کدام یک مسئولیت: `draft_models.dart` (نشست و پاسخ‌ها)، `draft_words.dart` (واژه‌های بله/خیر و یکسان‌سازیِ متن)، `draft_intent.dart` (کدام قالب به حرفِ کاربر می‌خورد)، `draft_step.dart` (پرسشِ فیلدها و متنِ نهایی)، `draft_laws.dart` (موادِ ارجاع‌شده). `drafting.dart` فقط `export` می‌کند تا وارداتِ موجود نشکند؛ کلاسی به نامِ `Drafting` وجود ندارد.

قالب‌ها در `assets/templates`؛ فیلدها یکی‌یکی پرسیده و اعتبارسنجی می‌شوند. مبلغی که کاربر در گفتگو گفته (به تومان، در پروندهٔ وکیل) برای فیلد مبلغ به ریال پیشنهاد می‌شود. اگر موضوع برای قالب متن پیشنهادی داشته باشد (`Advocate.fillFor`)، کنترلر آن را کنار پرسشِ فیلد می‌گذارد (`ChatController._withCaseHelp`): در فیلد گزینه‌ای، گزینهٔ متناسب جلو می‌آید؛ در فیلد عددی دکمهٔ عدد اضافه می‌شود؛ و در فیلد متنی، متن پیشنهادی زیر پرسش نوشته می‌شود و با دکمهٔ «همین متن پیشنهادی» پذیرفته می‌شود. کاربر همیشه می‌تواند متن خودش را بنویسد. پیش‌نویس ناتمام، در صورت روشن‌بودنِ گزینه‌اش، رمزنگاری‌شده نگه داشته می‌شود. پیام‌های تنظیم سند در تاریخچه ذخیره نمی‌شوند.

## حریم خصوصی

- مانیفست اصلی هیچ مجوزی ندارد (اینترنت هم نه).
- تاریخچه و پیش‌نویس با `PrivacyService` (Android Keystore، AES-256-GCM) رمز می‌شوند و از طریق واسط انتزاعی `KeyValueStore` (`lib/core/local_store.dart`) و مسیر مهاجرت یک‌بارهٔ `StorageMigration.migrateOneShot` (`lib/core/storage_migration.dart`) بدون وابستگی مستقیمِ `lib/domain/` و `HistoryStore` به `SharedPreferences` مدیریت می‌شوند.
- **تاریخچهٔ افزایشی:** هر گفتگو کلید رمزشدهٔ خودش را دارد (`history_v1:m:<id>`) و کلید `history_v1` فقط سرصفحه‌ها را نگه می‌دارد. با هر پیام فقط همان گفتگو نوشته می‌شود؛ نوشتن‌ها در یک صف سریالی (`_writer`) اجرا می‌شوند تا نسخهٔ قدیمی روی تازه ننشیند. خطای یک رکورد بقیهٔ تاریخچه را از بین نمی‌برد و در `HistoryStore.lastError` ثبت می‌شود. قالب ۴ (`v: 4`) علاوه بر پرونده، وضعیت «روی میز» (`dialogueJson`) را هم در همان محمولهٔ رمزنگاری‌شده می‌نویسد تا دکمه‌ها و پرسش‌های نیمه‌کاره پس از بازگشایی همان معنا را داشته باشند. قالب تک‌کلیدی نسخهٔ قبل خودکار و رمزشده مهاجرت می‌کند.
- `LegacyCleanup` در اولین اجرا فایل مدل زبانی و تنظیمات به‌جامانده از نسخه‌های قدیمی را پاک می‌کند.

## منابع یکتای داده

| داده | منبع یکتا | مصرف‌کننده‌ها |
|---|---|---|
| متادیتای قوانین | `assets/laws/_meta.json` | `laws_catalog.json` و `data_info.json` با `dev/tools/sync_meta.py --write` مشتق می‌شوند؛ `dev/tools/check.py meta` تازگی را می‌سنجد |
| روابط/تضاد مواد | `assets/relationships.json` | دارت: `core/conflicts_service.dart`؛ پایتون: `dev/brain/engine.py` |
| طبقه‌بند نیت | `assets/brain/intent_model.json` | دارت: `domain/intent_net.dart`؛ آینهٔ پایتون: `dev/tools/check.py intent`؛ آموزش: `dev/brain/train_intent.py` |
| پاسخ‌های ثابت | `assets/replies.json` | `core/replies.dart` (فقط ۸ کلید فعال موتور بازیابی) |
| مجموعههای ارزیابی | `eval/*.txt` و `eval/*.tsv` | ورودیهای سنجش در یک پوشه؛ خروجیها در `reports/` |
| ترتیب مسیرهای پاسخ و آستانه‌ها | `assets/pipeline.json` | دارت: `Advocate.pipelineOrder` و ثوابت `netMin`/`topicOpenMin`/`topicStrongMin`/`topicDominantMin` در `advocate_data.dart`؛ نگهبان: `dev/tools/pipeline_check.py` (با `DartLibrary`) و `python dev/tools/check.py pipeline`؛ آزمون: `test/advocate/pipeline_contract_test.dart` |
| ساختار مسیر موضوعی | `dev/tools/schemas/topic_flow.schema.json` | نگهبان: `dev/tools/topic_schema.py` (`check.py topics`) |
| ارجاع‌های قانونیِ داده | متن قوانین + `_meta.json` | نگهبان: `dev/tools/data_refs.py` (`check.py refs`) برای `articles`، `lawRefs` و `refs` |

## وضعیت بازیابی مواد (BM25F در برابر مدل تعبیه‌ای)

جست‌وجوی مواد در زمان اجرا (`lib/core/engine.dart`) صرفاً واژه‌ای و قطعی است: **BM25F** همراه با `assets/synonyms.txt`، `assets/brain/law_topics.json` (`LawTopicPrior`) و `assets/relationships.json` (`ConflictsService`). فایل‌های آزمایشی تعبیهٔ مواد (`emb_q8.bin`، `art_vecs.bin`، `art_ids.json`) فقط خروجی اسکریپت آفلاین `dev/brain/train_brain.py` در پوشهٔ `brain_out/` (نادیده‌گرفته‌شده در `.gitignore`) هستند؛ در `pubspec.yaml` معرفی نشده‌اند، وارد APK نمی‌شوند و هیچ کدی در `lib/` آن‌ها را نمی‌خواند.

## برابری پایتون ↔ دارت

آینهٔ پایتون (`dev/tools/eval_py.py`، `dev/tools/eval_none.py`، `dev/brain/common.py`، `dev/brain/engine.py`) برای ارزیابی سریع آفلاینِ موتور بازیابی است و باید هم‌رفتار دارت بماند: قواعد و آستانه‌های هر دو زبان از سه قرارداد واحد (`text_norm.json`، `law_terms.json` و `engine_rules.json`) تولید و با `check.py textnorm` / `lawterms` / `enginerules` بررسی می‌شوند؛ خروجی یکپارچه نیز با `dev/tools/parity.py --write` در `dev/brain/parity_expected.json` ثبت می‌شود، `dev/tools/check.py parity` تازگی آن را می‌سنجد و `test/core/parity_test.dart` همان ورودی‌ها را به دارت می‌دهد. تغییر یکی بدون دیگری ⇒ CI قرمز.

## هزینهٔ استارت‌آپ

خوانندهٔ موضوع (مدل ۱۲ مگابایتی Noql) حتی در پسزمینه هم زود بار نمیشود: نخستین پیامی که قاعدهها نتوانستند موضوعش را بفهمند، بارگذاریاش آغاز میشود. تا آماده نشده، وکیل فقط با قاعدهها کار میکند و وزنها پس از انتقال به isolate از کش `rootBundle` پاک میشوند. زمان آمادهشدن و زمان آخرین خواندن روی همان دستگاه در صفحهٔ «اطلاعات و وضعیت دادهها» دیده میشود.

متن ۲۴ فایل قانون (`3.11 MB` از کل `16.88 MB` دارایی) یک بار در `KnowledgeEngine.load()` بدون کش‌کردنِ رشته‌های خام در `rootBundle` (`cache: false`) خوانده می‌شود (`74 ms` روی CI) و ساخت نمایه در isolate جدا (`EngineWorker` / `LawIndex.buildAsync`، جمعاً `1,467 ms` بارگذاری سرد و `1,443 ms` با worker) اجرا می‌شود تا UI مسدود نشود؛ چون `BM25F` در نوبت اول به `IDF` سراسری هر ۲۴ قانون نیاز دارد، این بخش آگاهانه یک‌جا بارگذاری می‌شود (تنها بخش سنگین `12.72 MB` یعنی Noql به‌صورت تنبل بار می‌شود). `StartupMetrics` سنجه‌های بارگذاری را نگه می‌دارد، `test/engine/load_budget_test.dart` گزارش `reports/startup.txt` را می‌نویسد، `dev/tools/startup_gate.py` در CI از پس‌رفت زمانی جلوگیری می‌کند و `test/engine/turn_budget_test.dart` سقف هزینهٔ هر نوبت را نگه می‌دارد.

## دروازه‌های CI (`.github/workflows/test.yml`)

- داده: `dev/tools/check.py all` (corpus، assets، meta، intent، parity) + `doctor.py` + `eval_py.py --check` + `eval_none.py --check`
- تحلیل: `flutter analyze --fatal-warnings`
- تست و خط پایه: `flutter test --coverage` + `coverage_gate.py` + `startup_gate.py reports/startup.txt`؛ گزارش در `reports/last_test.txt` و `reports/startup.txt`
- `lawyer-lab.yml`: رونوشت گفتگوهای `test/lab/probe.txt` با همان کنترلر برنامه در `reports/lab/transcripts.txt`

قرارداد کامل داده/کد و این‌که هر کدام با چه ابزاری سنجیده می‌شوند: `docs/CONTRACTS.md`. وضعیت مراحل بازسازی: `docs/ROADMAP.md`.

`build.yml` (دستی) همان زنجیره را پیش از ساخت APK اجرا می‌کند (`dev/tools/build.sh` صرفاً اسکریپت کمکی ترموکس برای آغاز `build.yml` و دریافت APK است).

## نقاط ضعف شناخته‌شده و نقشهٔ بازآرایی مرحله‌ای

1. **توسعهٔ دستی حوزه‌های حقوقی:** هر موضوع تازه در `lib/domain/advocate/topics/` نیازمند نوشتن دستی الگوها، پرسش‌ها و ادعاها، ثبت در `topics/all.dart`، افزودن قالب در `assets/templates/` و نمونه در `eval/` است.
2. **محدودیت و هزینهٔ Noql:** Noql نفی را تشخیص نمی‌دهد (شباهت کسینوسی ۰٫۸۷ تا ۰٫۹۳ در `reports/embed_bench.md`) و اجرای Dart خالص آن حدود ۴۰۰ میلی‌ثانیه روی CPU است؛ به همین دلیل فقط نقش «حدس موضوع پس از ناکامی قاعده‌ها» دارد. طبق محک `reports/alt_bench.md`، جایگزین‌های چندزبانه مانند `intfloat/multilingual-e5-small` (۱۱۷٫۷M پارامتر، دقت ۸۳/۱۰۱) هم سنگین‌تر و هم ضعیف‌تر از Noql (۱۲٫۷M پارامتر، دقت ۹۰/۱۰۱) بوده‌اند؛ بررسی جایگزین‌های ایستا و سبک‌تر (مانند Model2Vec فارسی) برای آینده باز است.
3. **بدهی‌های ساختاریِ قابل اصلاحِ مرحله‌ای (هر مرحله در یک کامیت جدا همراه با `flutter analyze` و `flutter test`):**
   - ✅ یکپارچهای پوشههای دوقلوی سنجش انجام شد (`eval/` و `reports/`)؛ مرز اپ و ابزار آفلاین در `docs/REPO_LAYOUT.md` قفل شده است.
   - تفکیک منطقی لایهٔ `retrieval/` از `lib/core/` و لایهٔ `ml/` از `lib/domain/` به‌عنوان دو لایهٔ هم‌ترازِ بالای `core/` (بدون وابستگی `retrieval → ml` و با حفظ اصل «اول قاعده، بعد مدل» در `Advocate`).
   - ✅ جداسازی وابستگی `ChangeNotifier`/`ThemeMode` از لایهٔ دامنه انجام شد (فاز ۸): `lib/domain/settings.dart` حذف شد و `AppSettings` به `lib/ui/app_settings.dart` رفت تا `lib/domain/` کاملاً مستقل از فلاتر بماند (`settings_state.dart`).
   - سامان‌دهی `assets/brain/` به تفکیک مدل (`models/`) و داده (`data/`؛ از جمله انتقال `law_topics.json` به بخش داده).
   - قرارداد نگهداری نمودارها: همهٔ فایل‌های نمودار (`.mmd`، `.png`) فقط در `docs/diagrams/`.

## بانک پرسش‌وپاسخ اجاره (`lib/core/qa_bank.dart` + `assets/qa/lease_qa.json`)

- **محتوا:** ۱۲۰ پرسش‌وپاسخ در نُه دستهٔ قرارداد، ودیعه، اجاره‌بها، تعمیرات، خسارت، حریم، تخلیه، سرقفلی و اجرت‌المثل. هر پاسخ دست‌کم به یک ماده از متن واقعی `قانون روابط موجر و مستأجر` یا `قانون مدنی` (فصل «در اجاره»، مواد ۴۶۶ تا ۵۰۴) استناد دارد.
- **جایگاه در جریان پیام:** فقط در `LawAnswer.lookup` (در `_reply`) و پیش از جست‌وجوی BM25F، و فقط وقتی قواعد موضوعی وکیل (از جمله `topics/rent.dart`) پاسخی نداده‌اند. بنابراین پرسش‌هایی که قواعد اجاره‌ای آن‌ها را می‌فهمند همان مسیر قبلی را طی می‌کنند.
- **تطبیق:** توکن‌سازی `PersianText.tokenize`؛ حداقل ۲ واژهٔ مشترک و نسبت ≥ ۰٫۶ از واژه‌های پرسش بانک. یک واژهٔ کلیدی تنها (مثل «ودیعه») تطبیق نمی‌گیرد.
- **استناد نمایشی:** `QaBank.citeLabel` شماره و عنوان قانون را به فارسی می‌نویسد، مثلاً «ماده ۴ قانون روابط موجر و مستأجر».
- **صحت:** `tests/python/test_lease_qa.py` (در CI با `unittest discover` اجرا می‌شود) تأیید می‌کند که:
  - شناسه‌ها و پرسش‌ها یکتا هستند؛ هر پرسش به «؟» ختم می‌شود؛
  - هر استناد به شماره‌ای اشاره دارد که واقعاً در فایل متن قانون وجود دارد؛
  - هر «ماده …»ی که داخل پاسخ آمده در فهرست استنادهای همان پرسش است؛
  - پاسخ‌ها عبارت «مجاز است … قفل/وسایل را بیرون» (تخلیهٔ خودسرانه) ندارند.
  
  این آزمون هنگام نوشتن همین بانک یک ناهماهنگی واقعی (ماده ۴۹۴ نام برده‌شده ولی استناد نشده) را گرفت و اصلاح شد.
- **محدودیت:** پاسخ‌ها اطلاع‌رسانی عمومی‌اند و جای مشاورهٔ وکیل را نمی‌گیرند؛ سقف افزایش سالانهٔ اجاره (اگر در مقررات سال جاری ابلاغ شده باشد) در متن این مخزن نیست و پاسخ‌ها به بررسی آن ارجاع می‌دهند.

## ایندکس صریح قواعد («کدام قاعده کدام‌جاست»)

مرجعِ سریع برای پیداکردنِ محلِ دقیقِ هر قاعده در کد؛ هر فایلِ نام‌برده زیرِ `lib/` است و قراردادِ ساختاریِ متناظرش در `tests/python/` و `test/` قفل شده است.

### ۱. خطِ تولید پاسخ، اولویت، بازگشت و شمارندهٔ نوبت

| دستهٔ قاعده | مسئولیت دقیق | فایلِ صاحبِ قاعده |
|---|---|---|
| گرهِ مرکزی و سقف بازگشت | `respond`، `reset`/`replay`/`restoreCase`، `Advocate.maxReplyDepth = 1`، `lastReplyDepth`، `lastReplyEntries` | `advocate.dart` و `answer_candidate.dart` (`ReplyLoopGuard`) |
| قفلِ ورود به `_reply` | تنها صدا زنندهٔ `_reply`: اجبار `again: true` در بازگشت و جلوگیری از `turns` تکراری (`_guardedReply`) | `advocate_reply_guard.dart` |
| ترتیبِ ۲۰ کاندید پاسخ و نوبت | فهرستِ رتبه‌بندی‌نشدهٔ ۲۰ `AnswerCandidate` + افزایش تک‌واحدی `if (!again) file.turns++` | `advocate_reply.dart` (ماتریس: `docs/PRIORITY.md`) |
| داوری و متادیتای کاندید | انتخاب اولین پاسخ‌دهنده بدون وزن‌دهی (`AnswerCandidate`, `AnswerDecision`, `AnswerArbiter`) | `answer_candidate.dart` |
| نگهبان‌های پیش از پرونده | انصراف، دکمهٔ سند، مهلتِ اعتراض بی‌پرونده، ایمنی، خواندن موضوع، اصلاح کاربر | `advocate_reply_guard.dart` |
| دو شاخهٔ پرونده | «پرونده باز نیست» (بازکردن، پیام کوتاه، واژگان، حدس، راهنما) در برابر «پرونده باز است» (تعویض موضوع/ادامه) | `advocate_reply_case.dart` |
| ۱۳ مسیر یک‌نوبتیِ پاسخ | `newCase`، `noOption`، `pending`، `fight`، `choice`، `wrongGuess`، `more`، `offer` (با `again: true`)، `bareAck`، `side`، `repeat`، `fixedRule`، `deadline` | `reply_routes.dart` |
| دکمهٔ همیشگی خروج | افزودنِ دکمهٔ «انصراف» به انتهای هر پاسخ (`_withLeave`) | `advocate_leave.dart` |
| قرارداد و جدول‌های ترتیب | `AnswerSource`، `AdvocateReply`، `pipelineOrder` (هماهنگ با `assets/pipeline.json`)، `netMin`، `netTopics`، `guessTopics` | `advocate_model.dart` و `advocate_data.dart` |

### ۲. فهم محاوره، ایمنی، واژگان، زمان و گفت‌وگو

| دستهٔ قاعده | مسئولیت دقیق | فایلِ صاحبِ قاعده |
|---|---|---|
| نرمال‌سازی متن و توکن | یکسان‌سازی حروف/اعراب، حذف نیم‌فاصله و توکن‌سازی (`text_norm.json`) | `persian_text.dart` و `text_norm_rules.dart` |
| فهم محاوره (`Sense`) | خواندن مبلغ، مدت، بله/خیر/نمی‌دانم، شمار واژه، پرسشِ پیگیری (`chance`/`argue`/`next`) | `text_sense.dart` |
| ایمنی فوری | تشخیص خطر/خشونت/اورژانس پیش از همهٔ موضوع‌ها (`SafetyReply`) | `safety_reply.dart` |
| تطبیق واژه با مواد و جریان‌ها | کلیدواژه‌های حقوقی (`law_terms.json`) و گره‌های `assets/brain/topics/*.json` | `law_terms.dart`، `law_terms_rules.dart`، `topic_flow.dart`، `term_reply.dart` |
| تاریخ و مهلت جلالی | تبدیل تاریخ و محاسبهٔ مهلت‌های اعتراض/تجدیدنظر | `jalali.dart` |
| واژه‌نامه و نثر ثابت وکیل | توضیح اصطلاح‌ها (`Glossary`)، جمله‌های چرخشی (`Say`)، بارگذار `advocate_texts.json` | `glossary.dart`، `phrases.dart`، `advocate_text.dart`، `advocate_texts_loader.dart` |
| گفت‌وگوی غیرحقوقی و نامفهوم | دربارهٔ برنامه، سلام، تشکر، توهین کوتاه، سوگ، خلاصه، دسته‌های شروع و ابهام | `advocate_meta.dart`، `talk_route.dart`، `talk_reply.dart`، `advocate_talk.dart` |
| صدا و چیدمان دکمه‌ها | جایگزینی ارجاع ماده، برش متن با بودجه، سقف تکرار پرسش و ترتیب دکمه‌ها | `reply_voice.dart`، `chip_plan.dart`، `chip_texts.dart`، `advocate_chips.dart` |

### ۳. تشخیص موضوع، وضعیت پرونده و استدلال حقوقی

| دستهٔ قاعده | مسئولیت دقیق | فایلِ صاحبِ قاعده |
|---|---|---|
| امتیازدهی و انتخاب موضوع | امتیاز نشانه‌های موضوع (`TopicScore`)، خواندن موضوع (`TopicRead`)، تطبیق بحث و نظر دوم | `topic_score.dart`، `topic_read.dart`، `topic_picker.dart`، `advocate_topic.dart` |
| حدسِ مدل‌ها | تبدیل خروجی Noql (`TopicGuess`) و طبقه‌بند سبک نیت (`IntentNet`) | `understanding.dart`، `intent_net.dart` |
| مدل پرونده و وضعیت روی میز | ساختار پرونده (`CaseFile`) و قالب ۴ تاریخچه، مدل موضوع (`Topic`/`Slot`/`Issue`/`Claim`) و پنج تکهٔ گفتگو | `case_file.dart`، `case_state.dart`، `case_model.dart`، `dialogue_state.dart`، `dialogue_sections.dart` |
| استدلال و پرسش بعدی | ارزیابی ارکان ادعاها (`Reasoner`)، حکم و تغییر نتیجه (`CaseArgument`) و انتخاب پرسشِ بعدی (`CasePlan`) | `reasoner.dart`، `advocate_argue.dart`، `case_plan.dart` |
| چرخهٔ پرونده | بازکردن، جذب واقعیت‌ها (`absorb`)، اثر حقوقی، واکنش نوبت و خلاصهٔ پرونده (`recapOf`) | `case_flow.dart`، `case_facts.dart`، `case_answer.dart`، `case_text.dart`، `case_recap.dart`، `advocate_case.dart` |

### ۴. بازیابی قوانین، راهنماها و تنظیم سند

| دستهٔ قاعده | مسئولیت دقیق | فایلِ صاحبِ قاعده |
|---|---|---|
| موتور BM25F و نمایه | بارگذاری و پارس مواد، شاخص واژه‌ها، رتبه‌بندی BM25F، نام قانون، الگوی «ماده N» و قواعد بازیابی | `engine.dart`، `engine_load.dart`، `engine_query.dart`، `engine_rules.dart`، `law_index.dart`، `law_ranker.dart`، `law_mention.dart`، `law_text.dart`، `article_query.dart` |
| ضریب موضوعی، تعارض و QA | وزن موضوعی مواد، زنجیرهٔ تعارض/رابطه مواد، ۱۲۰ پرسش‌وپاسخ اجاره و نیت ثابت موتور | `law_topic_prior.dart`، `conflicts_service.dart`، `qa_bank.dart`، `router.dart` |
| راهنماهای آماده و پاسخ از بانک | ۳۰+ راهنمای ساختاریافته (`legal_guides.json`) و بازگشت به بانک پرسش‌وپاسخ/قانون | `legal_guides.dart`، `guide_reply.dart`، `law_answer.dart` |
| تنظیم پیش‌نویس سند و کنترلر گفتگو | تشخیص درخواست سند، گام‌بندی فیلدها، ارجاع مواد و سیم‌کشی جریان‌های گفتگو | `drafting.dart`، `draft_intent.dart`، `draft_step.dart`، `draft_words.dart`، `draft_laws.dart`، `draft_models.dart`، `templates.dart`، `draft_flow.dart`، `guess_flow.dart`، `reply_flow.dart`، `chat_controller.dart` |

### ۵. قواعد ۲۴ موضوع حقوقی (`lib/domain/advocate/topics/`)

- **ثبت و مشترکات:** ترتیب ارزیابی ۲۴ موضوع در `all.dart` (`allTopics`)؛ تکه‌های مشترک مرجع/هزینه/زمان در `shared.dart`؛ بارگذاری متن موضوع‌ها از `assets/brain/topic_texts.json` در `topic_texts_loader.dart`.
- **اجاره و ودیعه (۱۳ بخش):** `rent.dart` (سر کتابخانه)، `rent_patterns.dart`، `rent_reads.dart`، `rent_slots.dart`، `rent_effects.dart`، `rent_issues.dart`، `rent_issue_both.dart`، `rent_issue_tenant.dart`، `rent_issue_landlord.dart`، `rent_claims.dart`، `rent_plan.dart`، `rent_bodies.dart`، `rent_bodies_landlord.dart`، `rent_fill.dart` و بارگذار `rent_texts_loader.dart`.
- **کار و خانواده (هر کدام ۴ بخش):** `labor.dart` (`labor_patterns.dart`، `labor_claims.dart`، `labor_bodies.dart`، `labor_issues.dart`) و `family.dart` (`family_patterns.dart`، `family_claims.dart`، `family_bodies.dart`، `family_issues.dart`).
- **۲۱ موضوع تک‌فایلی:** `accused.dart` (متهم)، `admin.dart` (دیوان عدالت و اداری)، `cheque.dart` (چک)، `child.dart` (حضانت و فرزند)، `company.dart` (شرکت تجاری)، `consumer.dart` (حمایت از مصرف‌کننده)، `cyber.dart` (جرایم رایانه‌ای)، `debt.dart` (طلب و دین)، `enforce.dart` (اجرای احکام)، `fight.dart` (نزاع و دروازهٔ `fightGate`)، `foreign_contract.dart` (قرارداد با طرف خارجی)، `guarantee.dart` (ضمانت)، `inherit.dart` (ارث و وصیت)، `injury.dart` (دیه و تصادف)، `marriage.dart` (نکاح و شروط)، `minor_sale.dart` (معاملهٔ صغیر)، `neighbor.dart` (همسایگی و آپارتمان)، `partner.dart` (شراکت)، `property.dart` (املاک و ثبت)، `sale.dart` (بیع و قرارداد)، `theft.dart` (سرقت و خیانت در امانت).

## بازبینی معماری (ممیزی این نسخه)

**آنچه سالم است**
- وابستگی‌ها یک‌طرفه‌اند: `core` هیچ وارداتی از `domain` یا `ui` ندارد؛ `domain` هیچ وارداتی از `ui` ندارد. این قاعده‌ها اکنون در `tests/python/test_architecture.py` قفل شده‌اند.
- `Advocate` همچنان قاعددهمحور است: قواعد → حدس Noql → بانک پرسشوجواب → BM25F. مسیر «نظر دوم IntentNet» فقط در ابزار سنجش آفلاین است و اپ مدل دوم را بار نمیکند (نتیجهٔ سنجش در `reports/intent_holdout.md`).
- `replies.json` و `Replies.defaults` یک‌به‌یک‌اند و کلیدهای مرده ندارند (آزمون Python و Dart).

**بدهی‌های باقی‌مانده**
1. ✅ `lib/domain/settings.dart` حذف شد (فاز ۸)؛ `AppSettings` به `lib/ui/app_settings.dart` منتقل شد و `DOMAIN_FLUTTER_ALLOWLIST = set()` صفر است.
2. `lib/core/` برای بارگذاری پیش‌فرض در `engine_load.dart` هنوز fallback `rootBundle` دارد تا آزمون‌های قدیمی بی‌آرگومان حفظ شوند، اما `KnowledgeEngine({AssetTextLoader? assetLoader})` (`lib/core/asset_loader.dart`) تزریق خالص Dart را پذیرفته، `lib/main.dart` آن را از UI تزریق می‌کند و `test/core/engine_pure_dart_test.dart` بدون `rootBundle` کل ۲۴ قانون را بارگذاری می‌کند (`test_phase19_decoupling.py`). همچنین `HistoryStore`، `FeedbackStore` و `DraftCheckpointStore` از `SharedPreferences` مستقیم جدا و به `KeyValueStore` (`lib/core/local_store.dart`) متصل شدند.
3. کد مرده: حذف شد (`HybridIntentRouter`، `persian_normalizer`، `lawFactors`، `mentionedLaws`). گزارش در `docs/DEAD_CODE.md`.
4. ✅ `eval/` و `reports/` دوقلو نبودند؛ ادغام شدند (`docs/REPO_LAYOUT.md`).
5. ✅ `chat_controller.dart` (۱۳۰، زیر سقف ۱۵۰ خط) اکنون فقط سیم‌کشیِ بین سه همکارِ مستقل است: `draft_flow.dart` (۲۹۷، فرم و پیش‌نویس سند)، `guess_flow.dart` (۸۵، حدسِ موضوع با مدل) و `reply_flow.dart` (۲۷۶، صفِ نوبت، پیش‌ساخت worker برای `query` و `LawTerms` و ذخیره/بازیابی نشست)؛ نگهبان فاز ۴ (`tests/python/test_chat_controller_shape.py`) اندازه، تفکیک و نبود نسخهٔ تکراری فایل‌های داده‌ای را قفل می‌کند.
6. بزرگ‌ترین فایل‌های امروز: `advocate.dart` ۴۰۷ خط (سیم‌کشی + API عمومی + پنج `static`؛ بردنِ API به `extension` آزموده و برگشت خورد، `docs/GOD_OBJECTS.md`) و `advocate/reply_routes.dart` ۴۰۶ خط، `advocate/advocate_argue.dart` ۳۷۵ خط، `advocate/talk_route.dart` ۳۶۰ خط، `advocate/rule_dsl_text.dart` ۳۵۱ خط و `core/history_store.dart` ۳۵۰ خط (`topics/rent_claims.dart` پس از مهاجرت به DSL به ۳۳۱ خط کاهش یافت). `lawyer/legal_guides.dart` ۱۰۲ و `advocate_case.dart` ۲۲ خط‌اند؛ عددهای قبلی (۱۳۹۶ و ۶۳۷) مربوط به پیش از بازآرایی بود.

**آزمون‌ها**
- Python (بدون Flutter SDK): **۳۳۶** آزمون (`python3 -m unittest discover -s tests/python`): داده، معماری، شکلِ فایل‌ها و کنترلر گفتگو، معادل‌بودن متن (`۵۲۵` کلید اجاره + `۱٬۱۰۶` کلید سایر موضوع‌ها + `۴۷۰` کلید عمومی وکیل)، قرارداد اولویت (`۱۹۰` جفت)، قفلِ بازگشت و شمارشِ نوبت، نبودِ تکرار داده‌ها، دروازهٔ استارت/حافظه، عددهای مستندات و لینک‌های همین سند.
- Dart: **۷۰۱** آزمون (`flutter test --coverage`: ۶۹۵ آزمون پیشین + ۶ آزمونِ تازهٔ `test/app/chat_flows_test.dart` با پوشش خطی **۸۴٫۵٪** / `8,661/10,250` خط) و `flutter analyze --fatal-warnings` بدونِ ایراد (`No issues found!`) به‌علاوهٔ ۱۳۰/۱۳۰ و ۱۷/۱۷ سناریوی گفتگو در CI؛ گزارشِ آخرین اجرا در `reports/last_test.txt` و خط پایهٔ استارت در `reports/startup.txt`.

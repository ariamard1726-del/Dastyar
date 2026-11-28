# نقشهٔ فازبندی: ضعف‌ها به قدرت

این سند نقطهٔ مقابلِ `docs/GOD_OBJECTS.md` است. آن‌جا نوشته شده **چه چیزی شکسته
شد**؛ این‌جا نوشته شده **چه چیزی مانده، با چه ترتیبی، و با چه معیارِ پذیرش**.
قاعده‌ای که هر فاز رعایت می‌کند همان قاعدهٔ کلِ PR است:

1. **اول نگهبانِ عددی، بعد دست‌زدن.** هر فاز با آزمونی شروع می‌شود که پیش از
   تغییر قرمز است، به دلیلِ درست.
2. **رفتار عوض نمی‌شود.** ۱۳۰ سناریوی گفتگو و ۷۰۱ آزمونِ دارت، قراردادِ
   بیرونی‌اند؛ هر فاز باید همان‌ها را سبز نگه دارد.
3. **هر فاز یک کامیت (یا چند کامیتِ پشتِ‌سرهم) با عدد و بدونِ «بعداً»‌ست.**
4. **بدهی فقط کوچک می‌شود.** فهرستِ استثناها در آزمون نوشته می‌شود و نگهبان
   دارد که بزرگ نشود.

## جدولِ فازها

| فاز | ضعفِ امروز | قدرتِ هدف | معیارِ پذیرش | وضعیت |
|---|---|---|---|---|
| ۰ | نگهبان‌ها فایل‌محور بودند؛ با هر تقسیمِ درست، یک نگهبان می‌شکست | یک ابزارِ مشترک برای خواندنِ کتابخانه (`dev/tools/library.py`) | صفر نگهبانی که خودش `lib/` را `open` کند؛ صفر نگهبانی که `part` را دستی بشمارد | **انجام شد** |
| ۱ | متنِ حقوقی داخلِ Dart؛ دو مکانیزمِ تعریفِ موضوع (۲۴ موضوع دست‌نویس، ۱ موضوع داده‌ای) | متن در داده، منطق در کد؛ هشِ متن تا هر تغییرِ متن دیده شود | ۱۳۰/۱۳۰ سناریو بی‌تغییر؛ زمانِ بارگذاری بدتر نشود؛ هر فایلِ متن‌دار هش داشته باشد | **جزئی انجام شد؛ باقی‌مانده با برچسب بدهی** |
| ۲ | اولویتِ ۲۰ کاندید ضمنی است (ترتیب + `null`) | جدولِ تصمیمِ صریح و آزمونِ جفت‌به‌جفت | هر جفتی که هر دو می‌توانند جواب بدهند، برندهٔ اعلام‌شده دارد | **انجام شد** |
| ۳ | `Advocate` گرهِ مرکزی با حلقهٔ `routes → reply → routes` | ایندکسِ صریحِ قواعد + آزمونِ «یک نوبت، یک افزایش» | `respond` بازگشتی بیش از سقف نزند؛ `turns` در هر پیام دقیقاً یکی بزرگ شود | **انجام شد** |
| ۴ | کنترلرِ ۳۱۲خطی با سه مسئولیت | یک منبع ارزیابی؛ کنترلر لاغر | `chat_controller` زیر ۱۵۰ خط با رفتار یکسان | **انجام شد** |
| ۵ | ۲۴ فایلِ قانون و ۱۷ مگابایت دارایی در استارت خوانده و ایندکس می‌شود | سنجشِ خطِ پایه + تصمیمِ آگاهانه دربارهٔ تنبل‌سازی | زمانِ استارت در CI ثبت و از خطِ پایه بدتر نشود | **انجام شد** |
| ۶ | کاهش حجم مدل/داده (Noql؛ حدود ۱۲٫۷ مگابایت) | بررسی و تصمیم معماری دربارهٔ اندازهٔ بسته و مدل | توافق بر سر جایگزین یا فشرده‌سازی بدون افت دقت | **متوقف/کنارگذاشته‌شده به دستور کاربر** (مدل فاین‌تون در `noql` دست‌نخورده می‌ماند) |
| ۷ | تکرار پارس لاگ CI، جدول ارقام، `AI_MARKERS`، خواندن `_meta.json` و `open()`های بی‌بست در `dev/tools/` | یکپارچه‌سازی در `lawtext.py` و `ci_annotate.py` با ۰ `ResourceWarning` | اشتراک پارس در گزارشگرهای CI، متمرکزشدن ابزارها روی `lawtext.py`، ۰ فایل باز رهاشده و به‌روزرسانی مستندات | **انجام شد** |
| ۸ | فراخوانی همگام در `GuideReply`/`LawTerms`، نبود ماشین شدت/پنجره در ایمنی، نبود `schemaVersion` در `DraftSession`/`FeedbackStore` و استثنای فلاتر در `lib/domain/settings.dart` | اجرای ناهمگام در `EngineWorker` (`prepareWith`/`matchTermsInWorker`)، ماشین حالت ایمنی (`SafetySeverity` و پنجره)، `schemaVersion = 1` با مهاجرت مقاوم و دامنهٔ صفر-فلاتر | صفر `DOMAIN_FLUTTER_ALLOWLIST`، عبور ایمنی از `SafetySeverity` و «الان امن است»، نسخه‌بندی ذخیره‌ها و حفظ ۱۳۰/۱۳۰ و ۷۰۱+ آزمون سبز | **انجام شد** |
| ۹ | وجود کلوژرهای بی‌نام (`Reader`/`Body`/`Cond`/`Tri`) در ۲۰ موضوع ساده/میانی | موتور `RuleDSL` (`rule_dsl.dart` / `rule_dsl_text.dart` / `rule_dsl_read.dart` / `rule_dsl_json.dart`) و سازنده‌های `.dsl(...)` در `case_model.dart` | مهاجرت ۲۰ موضوعِ غیرچندفایلی به `Topic.dsl`/`Slot.dsl`/`Issue.dsl`/`Claim.dsl`/`Element.dsl` با ۰ کلوژر، سریال‌پذیری JSON، حفظ ۱۳۰/۱۳۰ و ۷۰۱+ آزمون سبز | **انجام شد** |
| ۱۰ | کلوژرهای مرکب در ۴ موضوع بزرگ (`cheque`، `family`، `labor`، `rent`) | مهاجرت کامل ۴ موضوع بزرگ (`rule_dsl_topic.dart` + سازنده‌های `.dsl`) و سریال‌پذیرشدن `Topic.toJson()` روی هر ۲۴ موضوع | حذف کلوژرهای بی‌نام و توابع کمکی از کل ۲۴ موضوع با نگهبان `test_phase10_rule_dsl.py` و آزمون‌های `test/advocate/phase10_rule_dsl_test.dart` | **انجام شد** |
| ۱۱ | همگام‌سازی جفت‌های منطق موازی پایتون/دارت (`duplicated_logic.json`) | تکمیل قراردادهای `text_norm.json` و `law_terms.json` و افزودن قرارداد `engine_rules.json` با تولید خودکار دوطرفه | عبور تمام جفت‌های برابری، آزمون‌های دوطرفه (`engine_rules`/`text_norm`/`law_terms`) و تازگی کامل مستندات معماری | **انجام شد** |
| ۱۲ | آستانه‌های جادویی خط لوله (`topicOpen`/`topicStrong`/`topicDominant`)، شکنندگی `TopicFlow.route` روی دادهٔ ناقص، `open(` بی‌بست در `dev/brain/` و جدول‌های قدیمی `ROADMAP` | اتصال مستقیم آستانه‌های `assets/pipeline.json`، استفاده از `DartLibrary` در `pipeline_check.py`، ایمن‌سازی `TopicFlow.route` و هم‌تراز پایتونی، بستن فایل‌ها در `dev/brain/` و هم‌راستاسازی اسناد | قفل تمام ۴ آستانهٔ `pipeline.json`، بازگشت امن به `'ask'` در ورودی ناقص، ۰ `ResourceWarning` در `common.iter_law_files()`/تست‌ها و تازگی `ROADMAP`/`PHASES`/`CONTRACTS` | **انجام شد** |
| ۱۳ | شکست خاموش `setBool`/`setString` و `seal` تهی، حساسیت `FeedbackEntry`/`LegalTemplate`/`TermReply._topicLeaf` به دادهٔ بدشکل و رقابت پوش هم‌زمان در `commit-reports` | ثبت خطای `SharedPreferences`/`seal` در `lastError`/`fallbackUsed`، پارس ایمن نوعی در `FeedbackEntry`/`LegalTemplate`/`TermReply._topicLeaf` و بازآزمایی `pull --rebase` در `test.yml` | شکست ذخیره‌سازی بی‌صدا رد نشود، ورود دادهٔ بدشکل کل بازخورد/قالب/موضوع را نشکند و `commit-reports` با `Lawyer Lab` تداخل پوش نداشته باشد | **انجام شد** |
| ۱۴ | خطاهای خاموش در `FeedbackStore`، `DraftCheckpointStore` و UI (`FeedbackBar`، `SettingsPage`، `HistoryPage`، `ReplyFlow`)، ۱۲ هشدار واژهٔ دروازهٔ عام در `lab/topics/` و نبود ابزار مصرف بازخوردها | افزودن `lastError` و `Future<bool> clear()`، نمایش خطا در UI و بازگرداندن رأی، حذف ۱۲ واژهٔ عام دروازه از `lab/topics/` و ساخت `dev/tools/feedback_eval.py` | عبور `topic_flow.py --check` (`۴۶/۴۶`)، صفر هشدار در `check.py topics` و پاس شدن `feedback_test`/`draft_checkpoint_test`/`settings_failure_test`/`test_feedback_eval` | **انجام شد** |
| ۱۵ | ۱۴ برچسب گزینه‌ای فارسی داخل `rent_fill.dart`، فرض خودکار «تومان → میلیون تومان» بدون دکمهٔ اصلاح، و ناهم‌ترازی SDK در `pubspec.yaml` | انتقال گزینه‌های `rent_fill.dart` به بخش `"fillOptions"` در `rent_texts.json` (`۵۳۹` کلید)، افزودن دکمه و مسیر اصلاح مبلغ خُرد (`ChipTexts.plainTomanChip`/`wantsPlainToman`/`flips`) و هماهنگی `sdk: '>=3.13.0 <4.0.0'` در `pubspec.yaml` | صفر متن فارسی باقی‌مانده در `rent_fill.dart`، به‌روزرسانی `text_manifest.json`، و عبور `amount_clarification_test.dart` و `rent_texts_test.dart` | **انجام شد** |
| ۱۶ | ۶ شاخهٔ پایانی `_reply` خارج از `AnswerArbiter`، نبود خواندن زندهٔ `assets/pipeline.json` در موتور و نبود `Topic.fromJson` برای اجرای مستقیم مدل JSON | یکپارچه‌سازی هر ۲۶ کاندیدِ `_reply` در `AnswerArbiter` با ماتریس ۳۲۵ جفتی (`priority.json`/`PRIORITY.md`)، بارگذاری زندهٔ `PipelineConfig` از `assets/pipeline.json` در `KnowledgeEngine.load()` و پیاده‌سازی کامل `Topic.fromJson` | عبور `priority_matrix_test.dart` (`۳۲۵` جفت)، `pipeline_contract_test.dart`، چرخهٔ رفت‌وبرگشت ۲۴ موضوع در `rule_dsl_from_json_test.dart` و `test_phase16_arbiter_and_from_json.py` | **انجام شد** |

## فاز ۰ — ابزارِ مشترکِ خواندن (انجام شد)

**ضعف:** نگهبان‌ها هر کدام `_read` و `_class_body` و شمارشِ آکولادِ خودشان را
داشتند. دو بار در همین بازآرایی، نگهبانی که فقط یک فایل را می‌شناخت با یک
تقسیمِ **درست** قرمز شد و مجبور شدم **نگهبان** را عوض کنم، نه کد را.

**قدرت:** `dev/tools/library.py` تنها جایی است که `lib/` خوانده می‌شود:
`DartLibrary` سر و همهٔ `part`ها را یک متن می‌بیند، بدنهٔ کلاس را جدا می‌کند،
`extension`ها را با نامِ نوع پیدا می‌کند و می‌گوید هر نام کجا **تعریف** شده
(نه کجا صدا زده شده). `dev/tools/lines.py` هم تنها تعریفِ «شمارِ خط» است.

**نگهبانِ این فاز:** `tests/python/test_guards_use_library.py` — سه ادعا:
هیچ نگهبانی `open()` روی `lib/` نمی‌زند؛ هر نگهبانی که `part` می‌شمارد از
`library` می‌خواند؛ و `_class_body`/`_extensions_on_*` فقط وام‌می‌گیرند.
خودِ ابزار هم آزمون دارد: `tests/python/test_library_tool.py`.

**نتیجهٔ عددی:** هشت نگهبان به ابزارِ مشترک منتقل شدند، سه تعریفِ دستی از
«شمارِ خط» حذف شد، و ۲۳۲ آزمونِ پایتون سبز است.

## فاز ۱ — متن به داده، با هش (کارِ مشترک با اعتبارسنجیِ حقوقی)

این فاز عمداً **اول** آمده، چون متنِ قانون در حال اعتبارسنجی از منبعِ معتبر
است و نسخهٔ تأییدشده به همین شاخه می‌آید. اگر متن داخلِ کد بماند، ورودِ نسخهٔ
تأییدشده یعنی **پچِ دارت**؛ اگر در داده باشد، یعنی **جای‌گزینیِ مقدار** و
یک گزارشِ تفاضل.

### قدمِ انجام‌شده: خواندنِ یکتا و هشِ متن (بی‌آنکه یک جمله عوض شود)

پیش از هر جابه‌جاییِ متن، باید مطمئن شویم می‌توانیم **ببینیم** متن عوض شده یا
نه. سه ابزار آمد و هیچ‌کدام یک نویسهٔ متن را عوض نکرد:

* `dev/tools/lawtext.py` — همان کاری که `dev/tools/library.py` برای کد Dart کرد، برای
  متنِ قانون: تنها جایی که می‌داند خطِ `#` نامِ منبع است، خطِ `##` سرِ فصل، و
  `ماده 12` / `ماده 12 مکرر` / `اصل 9` / `ماده واحده` سرِ یک بلوک. `doctor.py`
  تعریفِ دستیِ خودش را داد به همین ماژول و `law_diff.py` هم از همین می‌خواند.
* `dev/tools/text_manifest.py` — برای هر فایلِ متن‌دار (۲۴ متنِ قانون،
  `_meta.json`، راهنماها، بانک پرسش‌وپاسخ، `replies.json` و هشت فایلِ Dart که
  متنِ پاسخ در آن‌هاست) یک `sha256` و شمارِ خط در
  `assets/brain/text_manifest.json` می‌نویسد. `check.py all` حالا بخشِ `text`
  را هم اجرا می‌کند: تغییرِ متن بدون به‌روزکردنِ هش = پوش نکن.
* `dev/tools/law_diff.py` — تفاضلِ **ماده‌به‌ماده**، نه فایل‌به‌فایل: با
  `--ref <مرجعِ گیت>` می‌گوید کدام ماده‌ها اضافه/حذف/عوض شده‌اند و با
  `--counts` شمارِ موادِ هر قانون را با `_meta.json` می‌سنجد.

**یافتهٔ صادقانه:** نخستین نسخهٔ تحلیلگر، «مادهٔ مکرر» را دور می‌ریخت و
«اصولِ قانون اساسی» را اصلاً ماده نمی‌شناخت: قانون مدنی ۱۳۳۶ ماده داشت و او
۱۳۳۲ می‌شمرد، قانون اساسی ۱۷۷ اصل داشت و او صفر. یعنی تفاضلِ آینده می‌توانست
۲۲ مادهٔ مکرر و ۱۷۷ اصل را **بی‌صدا** از دست بدهد. با خوانندهٔ مشترک، هر ۲۴
قانون حالا **دقیقاً** با `_meta.json` می‌خواند (۵٬۶۹۰ بلوک) و `--counts` سبز
است. با `--dir ../new-text` هم می‌توان دو درخت را مقایسه کرد، پیش از آنکه
چیزی جای‌گزین شود. آزمون‌ها: `tests/python/test_text_manifest.py` (۱۰ آزمون،
شاملِ «یک نویسهٔ عوض‌شده هم گرفته می‌شود»، «مادهٔ مکرر کلیدِ جدا دارد» و
«تفاضلِ دو درخت») و دو ادعای تازه در
`test_guards_use_library.py` (هیچ ابزاری الگوی ماده را دوباره نسازد).
قرمز و سبزِ ابزار با عوض‌کردنِ یک واژه در متنِ قانون کار و بازگردانیِ آن
آزموده شد.

### قدمِ تازه: متنِ ثابتِ اجاره به دارایی (انجام شد)

- ۴۲ رشتهٔ بلندِ `const String` در `rent_bodies.dart` و
  `rent_bodies_landlord.dart` به جدولِ `texts` در
  `assets/brain/topics/rent_texts.json` رفتند. در Dart فقط پوستهٔ
  `String _id() => rentText('id')` ماند و منطق، شرطها و جملهسازیِ وابسته
  به پرونده عمداً همانجا ماندند.
- گامِ بعدی همان قرارداد را به ۸۷ رشتهٔ ادعاهای `rent_claims.dart` تعمیم
  داد: جدولِ `claims` در همان دارایی، با هش و شمارشِ جداگانه. ترتیبِ
  `Claim`ها، `when`ها، `needs`ها و توابعِ filing نویسهبهنویسه هماناند؛
  فقط بدنهٔ رشتهها با `rentText('claim…')` جایگزین شد.
- سپس ۳۲ برچسبِ ۱۸ مورد `Filing` (`chip` و `name`) به جدولِ `filings`
  رفتند. شناسهٔ قالب (`demand_money` و …) در Dart مانده و تصمیمگیر است؛
  متنِ دکمه و نامِ سند از دارایی میآیند. `const Filing` به `Filing` تبدیل
  شد چون مقدارِ آن در زمانِ کامپایل معلوم نیست؛ فیلدها و ترتیبِ
  ۱۸ مورد دقیقاً هماناند.
- گامِ چهارم: ۱۳ متنِ بلندِ `_rentPlan` (طرحِ دعوا، مدرک و مهلت) به جدولِ
  `plans` رفت. چهار جاییکه متن با `moneyForum(sum)` یا `_rentPeace()`
  تمام میشد، درونیابی در Dart ماند و با `+` به متنِ دارایی چسبید؛
  متنِ ثابت و ترتیبِ ۱۳ شاخه نویسهبهنویسه هماناند.
- سپس ۵۱ پارهٔ متنِ تمامی ۱۵ تابعِ پاسخِ `rent_bodies.dart` و
  `rent_bodies_landlord.dart` (در دو گام: ابتدا ۱۲ پارهٔ `_rentRaiseBody`،
  `_rentDamageBody` و `_rentOrderBody` با هشِ `99831c24…ce3a4`، و سپس
  ۳۹ پارهٔ دوازده تابعِ باقیمانده شاملِ `_rentUnpaidBody`،
  `_rentNoMoneyBody`، `_rentPenaltyBody` و نُه تابعِ سمتِ موجر) به جدولِ
  `bodies` رفتند. متغیرهای محلی و شرطهای پرونده در Dart ماندند و
  چسباندنِ پارهها با `+` همان جملهٔ نهایی پیشین را میسازد.
- سپس ۶ متنِ `_rentDeadline` و سه شاخهٔ `_rentRefuse` (بهجز شاخهای که
  درونیابیِ `_rentPeace()` در میانه دارد) به همان جدولِ `plans` اضافه
  شدند؛ سپس ۱۰ متنِ `_rentChance` و متنِ سربرگِ ارزیابی (`planLead`) هم
  آمدند (جمعاً ۳۰ متن). `lead` از `const` به خواندن از دارایی تبدیل شد
  و عبارتِ `lead + rentText(id)` همان جملهٔ پیشین را میسازد. شاخهٔ
  درونیابیشدهٔ `_rentRefuse` هم به دو پارهٔ دارایی تبدیل شد و فقط عبارت
  `_rentPeace()` در میانشان در Dart ماند (جمعاً ۳۶ متن).
- بارگذاری صریح است (`loadRentTexts` در `main` و `test/flutter_test_config.dart`)؛
  نبودِ متن یا نسخهٔ ناشناخته خطا میدهد، نه جایگزینِ بیصدا.
- **آزمونِ معادلبودن:** `tests/python/test_rent_text_equivalence.py` هشِ
  رشتهها را **پیش از جابهجایی** از کد اصلی گرفته و با محتوای JSON میسنجد.
  یک نویسه تغییر یا برگشتِ متن به دارت، قرمز میشود. هش فوراً قبل/بعد:
  `60f7d07b…f2e` (۴۲ رشته، ۲۰٬۷۲۷ نویسه). هشِ ادعاها پیش/پس:
  `abd7d7a1…6041` (۸۷ رشته، ۷٬۰۶۲ نویسه). هشِ برچسبهای سند:
  `706c5bee…325db` (۳۲ رشته، ۸۵۰ نویسه). هشِ طرحهای دعوا:
  `c9f084ec…18214` (۳۶ رشته، ۱۲٬۱۲۲ نویسه). - گامِ پایانی روی `rent_fill.dart`: ۵۱ متنِ آزادِ فیلدهای سند
  (`basis_detail`، `ground_detail`، `subject`، `merits_defense`،
  `statement_body` و اقلامِ مدرک/پیوست) به جدولِ ششم `fills` رفتند؛
  مقدارِ فیلدهای گزینهایِ قالبها (`choice`) عمداً در Dart ماندند و
  نگهبان برابر بودنشان با `assets/templates/*.json` را میسنجد.
- **آزمونِ معادلبودن** ادامه: هشِ پارههای متن:
  `ab62ffd0…8b0ba` (۵۱ پاره، ۱۰٬۸۷۵ نویسه؛ پیشتر ۱۲ پاره با `99831c24…ce3a4`).
- گام بعدی روی `_rentAskReply` (`rent_bodies.dart`) و اثرهای حقوقی
  (`rent_effects.dart` + بندهای `effect:` در `rent_slots.dart`): ۲۸
  متنِ پرسش/گزینهٔ دکمه‌دار به جدول `prompts` و ۳۳ متنِ اثر به جدول
  `effects` رفتند؛ از این پس در `rent_bodies.dart`،
  `rent_bodies_landlord.dart` و `rent_effects.dart` صفر متنِ فارسی در کد
  مانده است.
- گام پایانیِ متنِ آزادِ اجاره روی `rent_slots.dart`، `rent_issue_*.dart`،
  `rent_issues.dart` و باقیماندهٔ `rent_plan.dart`: ۵۸ متنِ `ask`/`why`/`options`
  به جدول `slots`، ۵۷ برچسب/عنوان/آغاز (`chip`/`title`/`opening`) به جدول
  `issues` و ۵۰ متنِ پایانی `_rentChance`/`_rentWhere`/`rentRecap` به جدول
  `recaps` رفتند؛ اکنون در `rent_plan.dart` و `rent_issue_{both,tenant,landlord}.dart`
  هم صفر متنِ فارسی در کد باقی مانده و در `rent_slots.dart` و `rent_issues.dart`
  فقط الگوهای Regex (`readPending`/`cues`/`anti`) مانده‌اند.
- **آزمونِ معادلبودن** ادامه: هشِ پارههای متن:
  `ab62ffd0…8b0ba` (۵۱ پاره، ۱۰٬۸۷۵ نویسه؛ پیشتر ۱۲ پاره با `99831c24…ce3a4`).
  هشِ فیلدهای سند: `8d141bd9…1fe9` (۵۱ رشته، ۴٬۵۰۰ نویسه).
  هشِ پرسشهای دکمه‌دار: `d57126f6…760` (۲۸ رشته، ۶۶۱ نویسه).
  هشِ اثرهای حقوقی: `a92491ef…4a13` (۳۳ رشته، ۵٬۳۲۹ نویسه).
  هشِ پرسشهای پرونده: `e2dcd97d…7d6e` (۵۸ رشته).
  هشِ بحثها و عنوان: `5607256e…7981` (۵۷ رشته).
  هشِ پایان طرح و خلاصه: `ca6a9478…ae3a` (۵۰ رشته).
  بارگذار هر یازده جدول (۵۲۵ کلید) را نصب میکند و نبودِ هرکدام خطای صریح است.
### قدمِ تازه: متنِ ثابتِ هر ۲۴ موضوع و بخش مشترک به دارایی (انجام شد)

- **اجاره (`rent_texts.json`):** یازده جدول (`texts`، `claims`، `filings`،
  `plans`، `bodies`، `fills`، `prompts`، `effects`، `slots`، `issues`،
  `recaps` — جمعاً **۵۲۵ کلید** و ۶۷٬۹۷۱ نویسه)؛ منطق، closureها، Regexها و
  ۱۵ گزینهٔ قالبی در `rent_fill.dart` در Dart مانده‌اند. هش پیش و پس در
  `tests/python/test_rent_text_equivalence.py` قفل است.
- **سایر موضوع‌ها و بخش مشترک (`assets/brain/topic_texts.json`):** در دو
  موجِ پیاپی (`cba260b` و `da62cd9`)، تمام نثرِ آزادِ `shared.dart`،
  `labor_*`، `family_*` (موج الف: ۲۹۰ کلید) و هر ۲۱ موضوع غیرِاجارهٔ دیگر
  (`accused` تا `theft`؛ موج ب: ۸۱۶ کلید) در ۲۴ بخش (**۱٬۱۰۶ کلید** و
  ۱۲۱٬۷۰۵ نویسه؛ سر جمعِ ۲۴ موضوع و `shared`: **۱٬۶۳۱ کلید**) به JSON
  منتقل شدند و با `loadTopicTexts()` و `topicText(section, key)` خوانده
  می‌شوند (`topic_texts_loader.dart`).
- **متن‌های عمومی وکیل (`assets/brain/advocate_texts.json`):** در موج ج، تمام
  نثرِ ثابتِ ۲۱ فایل غیرموضوعیِ `lib/domain/advocate/*.dart` (`glossary.dart`،
  `phrases.dart`، `understanding.dart`، `reply_voice.dart`،
  `advocate_constants.dart`، `safety_reply.dart`، `advocate_meta.dart`،
  `talk_route.dart`، `talk_reply.dart`، `advocate_talk.dart`،
  `topic_picker.dart`، `reply_routes.dart`، `case_text.dart`،
  `advocate_argue.dart`، `law_answer.dart`، `term_reply.dart`،
  `guide_reply.dart`، `case_answer.dart`، `advocate_reply*.dart`) در ۱۸ بخش
  (**۴۷۰ کلید** و ۲۹٬۴۰۷ نویسه؛ سر جمعِ کل نثر وکیل در سه دارایی: **۲٬۱۰۱ کلید**)
  به JSON منتقل شد و از راه `loadAdvocateTexts()` و `advocateText` /
  `advocateFormat` / `advocateTextSeq` خوانده می‌شود (`advocate_texts_loader.dart`).
- `test_topic_text_equivalence.py` و `test_advocate_text_equivalence.py` مصرف
  ۱۰۰٪ کلیدها، نبود نثر آزاد در هر ۲۴ موضوع، `shared.dart` و ۲۱ فایل عمومی
  وکیل، برابری هش و شمار رشته‌ها با متنِ پیش از جابه‌جایی، تطابق جای‌نگهدارهای
  `advocateFormat` و اعتبار تمام استنادهای `[[کلید:شماره]]` درون JSONها را
  می‌سنجند؛ `text_manifest.json` هم اکنون ۶۶ فایل متن‌دار را قفل می‌کند.
- **تصمیمِ مرز دارایی:** `assets/brain/topics/` فقط شامل `index.json`،
  `cheque.json` و `rent_texts.json` می‌ماند؛ `topic_texts.json` و
  `advocate_texts.json` در `assets/brain/` قرار دارند تا قراردادِ موضوع‌های
  تصویب‌شده برهم نخورد.

**باقی‌ماندهٔ فاز ۱ (ثبت‌شده، پوشانده‌نشده):**

1. ۱۵ مقدار گزینه‌ایِ متصل به قالبها در `rent_fill.dart`، برچسب‌های ساختاری و
   الگوهای Regex/شرطهای پرونده و closureهای تصمیم در Dartاند؛ بخشِ **نثرِ ثابتِ
   آزادِ کل لایهٔ وکیل** (۲۴ موضوع، `shared.dart` و ۲۱ فایل عمومی) در
   `rent_texts.json` (۵۲۵ کلید)، `topic_texts.json` (۱٬۱۰۶ کلید) و
   `advocate_texts.json` (۴۷۰ کلید؛ سر جمع ۲٬۱۰۱ کلید) کامل شده است.
2. تأیید رسمیِ ۰/۲۴ متنِ قانون هنوز انجام نشده و این بدهی با برچسب باقی
   می‌ماند، نه اینکه «همهٔ متنها تأیید شده‌اند» ادعا شود.

**معیارِ پذیرش:** ۱۳۰/۱۳۰ سناریو بی‌تغییر؛ `flutter test` بی‌تغییر؛ زمانِ
`KnowledgeEngine.load()` بدتر نشود (سنجشِ CI موجود در `test/engine/load_budget_test.dart`)؛
`check.py text` سبز بماند و هیچ فایلِ متن‌داری بی‌هش نباشد.

**قراردادِ ورودِ نسخهٔ تأییدشدهٔ قانون:**

```
1. دارایی‌ها جای‌گزین می‌شوند (assets/laws/…)
2. python3 dev/tools/sync_meta.py --write      # _meta.json و فهرست‌ها
3. python3 dev/tools/check.py all              # ارجاع‌ها، هش، برابری
4. python3 -m unittest discover -s tests/python
5. python3 dev/tools/text_manifest.py --write    # اعلامِ آگاهانهٔ تغییرِ متن
6. python3 dev/tools/law_diff.py --ref HEAD --report   # ماده‌های عوض‌شده، نه فایل
7. flutter test + ۱۳۰ سناریو + APK (اندازه و اجرا)
```

هیچ‌کدام از این گام‌ها «بازنویسی» نیست؛ تا گامِ ۵ کسی نباید متن را دست‌کاری
کند، و گام ۵ و ۶ فقط **اجازهٔ** ادامه می‌دهند: اگر تفاضلی هست که کسی نخوانده،
`--report` با کدِ ۱ برمی‌گردد.

### مرحلهٔ ۱ب: استحکام قرارداد پاسخ (پس از موفقیت فاز ۰)

ضعف: ۱۱۹ آزمون رفتار وکیل را با جملهٔ دقیق پیام گره زدهبودند؛ اصلاحِ یک جمله،
دهها آزمون را میشکست. ابزارهای پایتون در ریشهٔ اپ قرار داشتند و مرز بستهبندی
APK فقط به امیدِ `pubspec.yaml` بود. کلید نسخهٔ قدیمی در SharedPreferences
میماند و مسیر امنی برای ارتقا نداشت.

قدرت: پاسخ حالا فیلد ساختاری `ask` دارد و آزمونها `source`، `chips`، `laws`،
`ask` و وضعیت پرونده را میخوانند. ابزارها در `dev/`اند، `check.py bundle` مرز
بستهبندی را میسنجد و لایهٔ مهاجرت کلید قدیمی را یکبار خوانده، دوباره مهروموم
یا fail-closed حذف میکند.

نگهبانها: `tests/python/test_structure_tests.py` (صفر تحمل، شکل مثبت و منفی)،
`tests/python/test_repo_hygiene.py`، `tests/python/test_apk_bundle_exclusion.py`
و `test/core/privacy_migration_test.dart`.

نتیجهٔ عددی: صفر assert متنی، ۲۱ دارایی بستهبندیشده بدون مسیر ابزاری،
سه سناریوی مهاجرت، ۲۶۱ آزمون پایتون سبز. جزئیات: `reports/phase1_metrics.md`.
 کار باقیماندهٔ فاز ۱ (انتقال متن قانون به داده) منوط به تأیید صریح مالک است
و در این مرحله عمداً انجام نشد.

## فاز ۲ — اولویتِ صریح، به‌جای ترتیبِ ضمنی (انجام شد)

۲۰ کاندید در `advocate_reply.dart` (شانزده کاندید در `hitDecision`، یک کاندید در
`dueDecision` و سه کاندید در `tailDecision`) که داور اولین پاسخ‌دهنده را
برمی‌گرداند. ترتیب پیش‌تر فقط با یک فهرستِ نام‌ها قفل بود و رفتارهای مرکب
(ایمنی × انصراف × تغییرِ موضوع × سند) محصولِ ضمنیِ همین ترتیب بودند.

**کار انجام‌شده:** قراردادِ `dev/tools/contracts/priority.json` + مولدِ
`dev/tools/gen_priority.py` که جدولِ کامل `docs/PRIORITY.md` و آزمونِ ساختاریِ
`test/advocate/priority_matrix_test.dart` را می‌سازد و در `check.py priority`
و `tests/python/test_priority_matrix.py` می‌سنجد. کلِ **۱۹۰ جفتِ ممکن**
($\binom{20}{2}$) تعریف شده‌اند: **۱۱۳ جفتِ هم‌پوشان** با فراخوانی‌های واقعی
`Advocate.respond` (۱۷ حالت گفت‌وگوی واقعی + بررسی پایهٔ بازنده و ترکیب
برنده با `lastDecision?.candidate.name`) و **۷۷ جفتِ جداگانه** با اثبات کد و
قفل ساختاری.

**معیار:** تعدادِ جفت‌های اعلام‌شده = ۱۹۰/۱۹۰؛ هیچ جفتِ «اتفاقی» نمانده است.

## فاز ۳ — گرهِ مرکزی و بازگشت (انجام شد)

**کار:** اعمالِ `ReplyLoopGuard` روی ورود به `_reply` (`Advocate.maxReplyDepth = 1`، اجبار `again: true` برای فراخوانی بازگشتی از `ReplyRoutes`، ثبتِ `lastReplyDepth` و `lastReplyEntries`، قفلِ تنها صدا زنندهٔ `_reply` در `_guardedReply`) و افزودنِ ایندکس صریح «کدام قاعده کدام‌جاست» در `docs/ARCHITECTURE.md`.

**نگهبان‌ها:** `tests/python/test_reply_recursion_contract.py` (قفل ساختاری نگهبان بازگشت، نبودِ فراخوانی مستقیم `_reply`، قفل تغییرِ `file.turns` و وجود ایندکس در معماری) و `test/advocate/reply_recursion_test.dart` (شکستِ `StateError` هنگامِ حلقهٔ `routes → reply → routes` یا عمق > ۱ یا `again: false`، و قفلِ افزایشِ دقیقاً یک‌واحدیِ `file.turns` در هر نوبت و روی مسیرِ بازگشتیِ `offer`).

**معیار:** سقفِ بازگشت در کد اعمال شود و آزمونش قرمز شود اگر کسی حلقه بسازد.

**نتیجه:** ۳۲۷/۳۲۷ آزمون پایتون (`unittest`) و `check.py all` سبز، ۶۹۵/۶۹۵ آزمون Dart (از جمله ۵ آزمون جدید `reply_recursion_test.dart` و ۳۷۷ آزمون وکیل)، `flutter analyze --fatal-warnings` بدون ایراد و ۱۳۰/۱۳۰ + ۱۷/۱۷ سناریو در CI (`0555e11`).

## فاز ۴ — یک منبع برای هر داده (انجام شد)

**کار (انجام شد):** ادغامِ ورودی‌ها در `eval/` و خروجی‌ها در `reports/`؛ تفکیکِ `chat_controller.dart` (`۱۳۰` خط، زیر سقف ۱۵۰) به سه همکار مستقل (`DraftFlow` در `draft_flow.dart`، `GuessFlow` در `guess_flow.dart`، و `ReplyFlow` در `reply_flow.dart`) با حفظ دقیقِ رفتار و API عمومی.

**نگهبان‌ها:** `tests/python/test_chat_controller_shape.py` (سقف `< ۱۵۰` خط برای `chat_controller.dart`، قفلِ تفکیک سه جریان و نبود نسخهٔ تکراری هم‌نام یا هم‌محتوای فایل‌های داده‌ای در `assets/`، `eval/`، `tests/` و `dev/` با SHA-256) و `test/app/chat_flows_test.dart` (آزمون واحد جریان‌های جداشده کنار آزمون‌های کنترلر و ماندگاری).

**معیار:** `chat_controller` زیرِ ۱۵۰ خط؛ هیچ فایلِ داده‌ای دو نسخه نداشته باشد (نگهبان: مسیرِ تکراری و محتوای تکراری ممنوع).

**نتیجه:** ۳۳۱/۳۳۱ آزمون پایتون (`unittest`) و `check.py all` سبز، ۷۰۱/۷۰۱ آزمون Dart (۶۹۵ آزمون پیشین + ۶ آزمون تازهٔ `chat_flows_test.dart`؛ ۳۷۷ آزمون وکیل)، `flutter analyze --fatal-warnings` بدون ایراد (`No issues found!`) و ۱۳۰/۱۳۰ + ۱۷/۱۷ سناریو در CI (`5325b89`).

## فاز ۵ — استارت و حافظه (انجام شد)

**کار و تصمیم معماری:**
- **تفکیک دارایی ۱۷٫۵ مگابایتی:** حدود **۱۲٫۹ مگابایت** (`assets/brain/noql*`) از پیش در `ReaderService.start()` به‌صورت تنبل و فقط هنگام نیاز بارگذاری می‌شود؛ کل ۲۴ فایلِ متن قانون فقط **۳٫۲ مگابایت**‌اند. چون رتبه‌بندی `BM25F` در همان پیام نخست به `IDF` سراسری، میانگین طول کل مواد و ارجاعات متقابلِ هر ۲۴ قانون نیاز دارد و باید هم‌رفتار آینهٔ پایتون (`dev/brain/engine.py`) بماند، تنبل‌سازیِ تک‌تک قوانین کنار گذاشته شد تا توازن رتبه و پاسخ‌دهی نوبت اول نشکند.
- **بهینه‌سازی حافظهٔ بارگذاری (`lib/core/engine_load.dart`):** همهٔ ۱۲ فراخوانی `rootBundle.loadString(..., cache: false)` بدون نگه‌داشتن نسخهٔ تکراری در کش `rootBundle` خوانده می‌شوند، دادهٔ انتقال به isolate فقط وقتی `startWorker: true` است ساخته می‌شود و `_repliesRaw` / `_lawTopicsRaw` بلافاصله پس از راه‌اندازی نمایه آزاد می‌شوند.
- **ثبت خط پایه و دروازهٔ CI:** `StartupMetrics` در `models.dart` و `engine.dart` زمان مراحل (`assetsMillis`, `indexMillis`, `totalMillis`) و ابعاد نمایه را ثبت می‌کند؛ `test/engine/load_budget_test.dart` خروجی را در `reports/startup.txt` می‌نویسد و `.github/workflows/test.yml` با `dev/tools/startup_gate.py` آن را در CI می‌سنجد و ثبت می‌کند.

**نگهبان:** `tests/python/test_startup_budget.py` و `dev/tools/startup_gate.py`.

**معیار:** عددِ ثبت‌شده در `reports/startup.txt` و جلوگیری از پس‌رفت زمانی در CI.

**نتیجه (اندازه‌گیری CI روی `6c05c96` / ثبت نهایی روی `f98bb5d`):**
- `reports/startup.txt`: بارگذاری سرد `1,140 ms` (`assets 63 ms` + `index 1,077 ms`)، با `EngineWorker`: `1,082 ms`، نخستین پرسش `50 ms`؛ ۲۴ قانون (`5,724` بخش، `9,214` واژه، `3.11 MB`)، Noql تنبل `12.72 MB` از کل `16.88 MB` دارایی، و حافظهٔ تست `253.8 MB` (شاهد عددی برای رد تنبل‌سازی تک‌تک قوانین: کل خواندن ۲۴ فایل فقط `63 ms` است).
- پوشش کد (`reports/coverage.txt`): `84.5%` (`8,661/10,250` خط)، `701/701` آزمون Dart، `336/336` آزمون پایتون، `No issues found! (10.9s)` و ۱۳۰/۱۳۰ + ۱۷/۱۷ سناریو سبز.

## فاز ۶ — حجم مدل و داده‌های Noql (موکول به مرحلهٔ آخر)

این فاز بنا به تصمیم مخزن پس از بررسی مستقل اجرا می‌شود و فعلاً تغییری در وزن‌ها یا واژگان `assets/brain/noql*` داده نشده است (`lazy_noql_mb=12.72`، حفاظت‌شده با `check.py noql`).

## فاز ۷ — یکپارچه‌سازی و زدودن تکرار در ابزارهای توسعه (انجام شد)

**ضعف:** با رشد `dev/tools/`، دو گزارش‌گر CI (`ci_annotate.py` و `ci_summary.py`) منطقِ پارسِ بلوک‌های `[E]`/`❌` و برش مسیر را جداگانه پیاده کرده بودند؛ هشت ابزار دیگر (`check.py`، `doctor.py`، `data_refs.py`، `check_refs.py`، `sync_meta.py`، `convert.py`، `law_registry.py`، `law_diff.py`) و سه اسکریپت `dev/tools/synonyms/*.py` نیز جدول‌های تبدیل ارقام (`FA_DIGITS`/`to_fa`)، نشانه‌های `AI_MARKERS` و خواندن `_meta.json` را کپی می‌کردند؛ و چندین فراخوانی `open(...)` بدون `with` در ابزارها و آزمون‌های پایتون `ResourceWarning` تولید می‌کردند.

**کار انجام‌شده:**
- **گزارش‌گرهای CI:** `dev/tools/ci_annotate.py` اکنون منبع مشترک `STATUS_RE`، `cut`، `blocks` و `cross_blocks` است و `dev/tools/ci_summary.py` به‌جای کپیِ حلقهٔ پارس از آن می‌خواند (`summarize` هم به‌صورت تابع قابل‌آزمون درآمد).
- **تک‌منبع‌سازی در `dev/tools/lawtext.py`:** افزودن `AI_MARKERS`، `FA_DIGITS`/`TO_FA`، `digits`، `to_fa`، `load_meta` و `law_files` و اتصال `check.py`، `doctor.py`، `sync_meta.py`، `data_refs.py`، `check_refs.py`، `convert.py`، `law_diff.py`، `law_registry.py` و اسکریپت‌های `dev/tools/synonyms/{coverage_report,distinct_words,validate_synonyms}.py` به آن بدون شکستن APIهای عمومی و ابزارهای پژوهشیِ متصل به CI (`dev/brain/`).
- **بهداشت بستن فایل‌ها (`ResourceWarning = 0`):** تبدیل تمام `open(...)`های بدون `with` در `dev/tools/{check,doctor,import_law,term_audit,topic_flow}.py`، `dev/tools/synonyms/*.py` و `tests/python/{test_pipeline_check,test_term_audit,test_topic_flow,test_topic_schema}.py`.

**نگهبان:** `tests/python/test_dev_tools_hygiene.py` (۵ آزمون: اشتراک پارس در گزارش‌گرهای CI، تک‌منبع‌بودن `lawtext.py`، بهداشت `dev/tools/synonyms/`، اجرای کل مجموعهٔ آزمون پایتون با `-W error::ResourceWarning` بدون هیچ هشدار نشتِ فایل، و هم‌خوانی `README.md` با وضعیت فازهای تکمیل‌شده) + آزمون جدید `test_ci_summary_formats_failures_and_compile_errors` در `test_ci_annotate.py`.

**نتیجه:** ۳۴۲/۳۴۲ آزمون پایتون (`unittest`) و `check.py all` سبز با `0` هشدار `ResourceWarning`، و هم‌راستایی کامل `README.md` و `docs/PHASES.md`.

## فاز ۸ — مسیر غیرهمگام موتور، ماشین حالت ایمنی، نسخه‌بندی ذخیره‌ها و دامنهٔ بی‌فلاتر (انجام شد)

**ضعف:**
1. `GuideReply.follow` (`guide_reply.dart`) و `TermReply.lawTerms` (`term_reply.dart` → `LawTerms.match`) هنوز در زمان تعامل کاربر به‌صورت همگام روی رشتهٔ UI اجرا می‌شدند، در حالی که `EngineWorker` تنها برای `LawAnswer` استفاده می‌شد.
2. `SafetyState` تنها `safetyShown`/`safetyCarry`/`lastSafetyText` داشت و شدت خطر (`elevated`/`critical`)، پنجرهٔ نوبتی (`lastSafetyTurn`) و گذارِ خروج به «الان امن است/هستم» (`acknowledgedSafe`) مدل‌سازی نشده بودند.
3. `DraftSession` و `FeedbackStore` نسخهٔ صریح (`schemaVersion`) و ردّ ایمنِ نسخهٔ آینده نداشتند.
4. `lib/domain/settings.dart` آخرین عضو `DOMAIN_FLUTTER_ALLOWLIST` بود که `package:flutter/material.dart` را وارد لایهٔ دامنه می‌کرد.

**کار انجام‌شده:**
- **گسترش `EngineWorker` برای اجراهای غیرهمگام دامنه بدون شکستن مرز لایه:** افزودن RPC عمومی `run<A, R>` / `KnowledgeEngine.prepareWith<A, R>` به `engine_worker.dart` و `engine.dart` (بدون وابستگی `core` به `domain`)، پیش‌ساخت هم‌زمان `guideReply` و `matchTermsInWorker` در `ReplyFlow._process`، و پشتیبانی `prepared` / `preparedMatch` در `GuideReply` و `TermReply` (با حفظ مسیر همگام به‌عنوان پشتیبان در آزمون‌ها و خطای isolate).
- **ماشین حالت ایمنی:** افزودن `enum SafetySeverity { none, elevated, critical }`، `lastSafetyTurn` و `acknowledgedSafe` در `SafetyState` (همراه با سریال‌پذیری کامل در `DialogueState.toJson/applyJson`)، `severityOf()` و `acknowledgesSafe()` در `SafetyReply` و گذارِ تشدید و بازگشتِ امن در `_safetyReply`.
- **نسخه‌بندی ذخیره‌ها:** افزودن `schemaVersion = 1` به `DraftSession` و `FeedbackStore` با پشتیبانی از مهاجرت دادهٔ قدیمی و ردّ ایمنِ نسخهٔ آینده.
- **دامنهٔ صفر-فلاتر:** انتقال `AppSettings` به `lib/ui/app_settings.dart`، حذف `lib/domain/settings.dart`، به‌روزرسانی واردات در UI و آزمون‌ها، و تهی‌کردن `DOMAIN_FLUTTER_ALLOWLIST = set()` در `tests/python/test_architecture.py`.

**نگهبان:** `tests/python/test_phase8_runtime_and_layers.py` و آزمون‌های واحد دارت در `test/engine/worker_test.dart`، `test/domain/safety_reply_test.dart`، `test/advocate/safety_test.dart`، `test/app/draft_checkpoint_test.dart` و `test/core/privacy_test.dart`.

## فازهای ۹ تا ۱۰ (انجام شد) و گام نهایی (۱۱)

- **فاز ۹ (`RuleDSL` + مهاجرت ۲۰ موضوع ساده/میانی؛ انجام شد):** معرفی موتور سبک `FactExpr`/`TextExpr`/`ReadRule`/`GateRule` قابل سریال‌پذیری در `rule_dsl*.dart` و `case_model.dart` (همراه با حفظ `const String` برای regexها و بدون افت عملکرد) و مهاجرت کامل ۲۰ موضوع تک‌فایلی به `Topic.dsl`.
- **فاز ۱۰ (مهاجرت ۴ موضوع بزرگ `cheque`، `family`، `labor`، `rent`؛ انجام شد):** افزودن `rule_dsl_topic.dart` (`RankRule`، `FilingRule`، `PromptRule`، `FillRule`، `TxCases`، `TxAssessDemands`) و عملگرهای پیشرفته (`FactTouched`، `FactCovered`، `FactNumMax`، `ReadGuard`، `ReadBeforeMatch`، `ReadMonths`، `TxRent`، `TxNumOffset`، `TxScaleMul`، `TxListJoin`) به `RuleDSL`، مهاجرت کامل هر چهار موضوع بزرگ (`cheque.dart`، پنج فایل `family*`، پنج فایل `labor*` و هر ۱۴ فایل `rent*`) با صفر کلوژر و صفر `=>` در کل ۲۴ موضوع، و قفل‌کردن هم‌ارزی رفتاری و `Topic.toJson()` با `test_phase10_rule_dsl.py` و `test/advocate/phase10_rule_dsl_test.dart`.
- **فاز ۱۱ — همگام‌سازی قراردادهای منطق موازی پایتون/دارت (انجام شد):**
  - **تکمیل `text_norm.json` (`gen_text_norm.py` / `check.py textnorm`):** افزودن بخش `tokenize` (`nonWord`، `stemMinStem`، `suffixes`، `suffixesIndex`، `stop`) و نگاشت‌های `spaced` (`tools` و `terms`)؛ یکپارچه‌سازی `PersianText.spacedWith` برای `TopicFlow.spaced` و `LawTerms.spaced` و اتصال `eval_py.py`، `check.py` و `train_intent.py` به همان خروجی تولیدشده.
  - **تکمیل `law_terms.json` (`gen_law_terms.py` / `check.py lawterms`):** افزودن بخش `ranking` و اتصال کامل `law_terms.dart` و `dev/tools/law_terms.py` به ثوابت قرارداد و `GENERAL_SOURCE` بدون هاردکد `'دانش عمومی'`.
  - **ایجاد `engine_rules.json` (`gen_engine_rules.py` / `check.py enginerules`):** تولید `lib/core/engine_rules.dart` و `dev/brain/engine_rules.py` برای الگوی ماده/اصل، ضرایب و آستانه‌های `BM25F`، تشخیص منسوخ‌بودن، ارتقای مواد تعریفی، نام قانون، پایش حوزه‌های خارج از پوشش و عمق زنجیرهٔ تضادها، و اتصال `article_query`، `law_index`، `law_mention`، `law_ranker`، `conflicts_service`، `engine`، `engine_query`، `eval_py.py`، `eval_none.py`، `dev/brain/common.py` و `dev/brain/engine.py` با نگهبان‌های `test_engine_rules_parity.py` و `test/core/engine_rules_test.dart`.
- **فاز ۱۲ — تکمیل قرارداد خط لوله، تاب‌آوری `TopicFlow`، بهداشت `dev/brain/` و هم‌راستاسازی اسناد (انجام شد):**
  - **قرارداد کامل `assets/pipeline.json` و `pipeline_check.py`:** تعریف `topicOpenMin` (`3`)، `topicStrongMin` (`5`) و `topicDominantMin` (`5`) در `lib/domain/advocate/advocate_data.dart` و جایگزینی تمام مقادیر تکراری `3`/`5` در `advocate.dart`، `advocate_reply*.dart`، `topic_read.dart` و `talk_reply.dart`؛ مهاجرت `dev/tools/pipeline_check.py` به `DartLibrary` مشترک از `dev/tools/library.py` و راستی‌آزمایی هر ۴ آستانهٔ JSON در `check.py pipeline` و `test/advocate/pipeline_contract_test.dart`.
  - **تاب‌آوری `TopicFlow.route`:** حذف `.cast<...>()` و `as String` شکننده در `lib/domain/advocate/topic_flow.dart` و هم‌ترازسازی `dev/tools/topic_flow.py` تا ورودی بدشکل یا `{}` بدون خطا به `'ask'` برگردد (`test/advocate/topic_flow_test.dart` و `tests/python/test_topic_flow.py`).
  - **بهداشت بستن فایل در `dev/brain/`:** افزودن `with open(...)` در `dev/brain/common.py` (`iter_law_files`)، `dev/brain/alt_bench.py` و `dev/brain/embed_eval.py` (بدون دست‌کاری در `dev/brain/noql/*`) با نگهبان `-W error::ResourceWarning` در `tests/python/test_dev_tools_hygiene.py`.
  - **به‌روزرسانی `docs/ROADMAP.md` و `docs/CONTRACTS.md`:** بستن وضعیت‌های تاریخی منسوخ مراحل ۱ تا ۴ در `ROADMAP.md` (`RuleDSL`، اجرای ناهمگام `LawTerms.match`، همکاران `Advocate`) مطابق وضع واقعی کد.
- **فاز ۱۳ — بستن شکست‌های خاموش ذخیره‌سازی، پارس ایمن و پایداری گزارش‌دهی CI (انجام شد):**
  - **جلوگیری از شکست خاموش ذخیره و رمزنگاری:** بررسی خروجی `bool` در `AppSettings` (`_save`، `acceptConsent`، `setSecureScreen`) و `HistoryStore` (`_writeSession`، `_writeIndex`) برای ثبت صریح در `lastError`، و فراخوانی `_markFallback(null)` در `PrivacyService.seal` هنگام خروجی تهی/`null` از کانال بومی.
  - **پارس نوع‌امن داده‌ها:** ایمن‌سازی `FeedbackEntry.fromJson` در برابر timestamp نامعتبر، جایگزینی `.cast<Map>()` با بررسی ایمن در `TermReply._topicLeaf`، و اعتبارسنجی صریح `TemplateField.fromJson` / `LegalTemplate.fromJson` با `FormatException` (`test/app/{settings_failure_test,feedback_test}.dart`، `test/core/privacy_test.dart`، `test/drafting/logic_test.dart` و `test/advocate/topic_flow_test.dart`).
  - **پایداری `commit-reports` در `.github/workflows/test.yml`:** افزودن حلقهٔ بازآزمایی `git -c rebase.autoStash=true pull --rebase` پیش از `git push` (هم‌تراز با `lawyer-lab.yml`) با حفظ شکست صریح در صورت عدم موفقیت نهایی (`tests/python/test_startup_budget.py`).
- **فاز ۱۴ — شفافیت خطاهای لایهٔ ذخیره در UI، پاک‌سازی دروازه‌های عام موضوعی و چرخهٔ پالایش بازخورد (انجام شد):**
  - **نمایش خطاهای بازخورد، پیش‌نویس و تاریخچه:** افزودن `lastError` و `Future<bool> clear()` به `FeedbackStore` (`feedback.dart`) و `DraftCheckpointStore` (`draft_models.dart`)، بازگرداندن `_vote` و نمایش خطای ذخیره/پاک‌سازی در `FeedbackBar` (`feedback_bar.dart`)، ثبت `history.lastError` در `ReplyFlow` (`reply_flow.dart`)، کارت قابل‌بستنِ خطای تاریخچه و بررسی خطای پاک‌سازی در `SettingsPage` (`settings_page.dart`) و `SnackBar` خطای حذف در `HistoryPage` (`history_page.dart`) همراه با آزمون‌های `test/app/{feedback,draft_checkpoint,settings_failure}_test.dart`.
  - **حذف ۱۲ واژهٔ دروازهٔ عام هشداردهنده (`check.py topics`):** حذف `طلب`/`پول`/`پایان` از `lab/topics/labor_wages.json` و `آپارتمان`/`صاحب`/`مغازه`/`خانه`/`مالک`/`خونه`/`قرارداد`/`ساکن`/`واحد` از `lab/topics/rent.json` با حفظ قبولی کامل `46/46` در `topic_flow.py --check`.
  - **ابزار پالایش بازخورد به `eval` (`F13`):** ساخت `dev/tools/feedback_eval.py` (متصل به `lawtext.py` برای راستی‌آزمایی شناسه‌های قانون و عنوان مواد با `_meta.json` و پرهیز از تکرار پرسش‌های موجود در `eval/*.txt`) و آزمون‌های `tests/python/test_feedback_eval.py`.
- **فاز ۱۵ — انتقال گزینه‌های `rent_fill.dart` به JSON، اصلاح تعامل مبلغ خُرد و هم‌راستاسازی SDK (انجام شد):**
  - **خروج ۱۴ برچسب گزینه‌ای باقی‌ماندهٔ `rent_fill.dart` به `rent_texts.json`:** افزودن بخش دوازدهم `"fillOptions"` (`۱۴` کلید، مجموع `۵۳۹` کلید) همراه با بارگذاری در `rent_texts_loader.dart`، به‌روزرسانی `test_rent_text_equivalence.py` و `rent_texts_test.dart` و بازتولید `text_manifest.json` (`۶۶` فایل).
  - **امکان اصلاح مبلغ خُرد/میلیونی (`Sense.wantsPlainToman`):** افزودن `ChipTexts.plainTomanChip` (`۵۷` خط)، `Sense.amountIsExplicit`/`Sense.wantsPlainToman`، اصلاح مستقیم `amount`/`salary` با `flips` و جلوگیری از تداخل «نیست» با پرسش معلق بله/نه در `case_facts.dart` + دکمهٔ راهنمای مبلغ خُرد در `CaseAnswer.finish` بدون افزودن فیلد به `DialogueState` و آزمون در `test/advocate/amount_clarification_test.dart`.
  - **هماهنگ‌سازی `pubspec.yaml`:** تنظیم `sdk: '>=3.13.0 <4.0.0'` متناظر با `pubspec.lock`.
- **فاز ۱۶ — یکپارچه‌سازی کامل `AnswerArbiter`، اتصال زندهٔ `pipeline.json` و `Topic.fromJson` (انجام شد):**
  - **انتقال ۶ شاخهٔ پایانی به `AnswerArbiter`:** واردکردن `_meta` (`پاسخِ کلیِ مقدم`) و ۵ شاخهٔ پایانی (`واژهٔ قانون و پیوند`، `هشدارِ قهر`، `گفتگو با برنامه`، `اصلاحِ موضوع` و `پرونده یا پاسخِ کلی`) به فهرست ۲۶ کاندید در `advocate_reply.dart`؛ به‌روزرسانی `priority.json` (`۳۲۵` جفت = `۲۲۹` هم‌پوشان + `۹۶` جداگانه) و بازتولید `docs/PRIORITY.md` و `test/advocate/priority_matrix_test.dart`.
  - **بارگذاری زندهٔ `assets/pipeline.json`:** افزودن `PipelineConfig` در `lib/core/models.dart`، `_loadPipeline()` در `engine_load.dart` و رزولورهای `advocate_data.dart` با پوشش آزمون در `pipeline_contract_test.dart`.
  - **پیاده‌سازی کامل `Topic.fromJson`:** افزودن `rule_dsl_from_json.dart`، `rule_dsl_topic_from_json.dart`، کامل‌کردن فیلدهای `SlotRuleJson.toJson` (`why`، `first`، `yesValue`، `noValue`) و سازندهٔ `Topic.fromJson` با آزمون رفت‌وبرگشت همهٔ ۲۴ موضوع در `test/advocate/rule_dsl_from_json_test.dart` و `tests/python/test_phase16_arbiter_and_from_json.py`.
- **فاز ۱۷ — اجراگر مستقیم Dart در CI، یکتاسازی کمکی‌های پایتون و اتصال خودکار `sync_meta.py` (انجام شد):**
  - افزودن `EngineReply.answered` به `lib/core/models.dart` و اصلاح کنترل کفِ پوشش مادهٔ برگزیده (`chosenCov`) در `lib/core/engine_query.dart` تا پرسش‌های نامرتبط با `topCov < 0.40` به‌غلط با امتیاز `hits[1..3]` پاسخ نگیرند.
  - ایجاد `test/core/dart_eval_suite_test.dart` (اجرای مستقیم `PersianText`/`Sense`، `KnowledgeEngine` روی کل `eval/*.txt` و `eval_none.txt`، `LawTerms` روی `cases.json`/`audit.json` و `TopicFlow` روی `tests/topics/*.json` و نگارش `reports/dart_eval.txt`) به همراه `dev/tools/dart_eval.py` و `tests/python/test_dart_eval_tool.py` و ثبت آن در `.github/workflows/test.yml`.
  - انتقال `collapse`، `phrase`، `tok`، `is_obsolete` و `iter_law_files(preserve_order=True)` به `dev/brain/common.py` بدون تکرار در `dev/tools/eval_py.py`، و افزودن `--check` به `dev/tools/sync_meta.py` با آزمون `tests/python/test_sync_meta.py` و اتصال به `.github/workflows/{test,build}.yml`.
- **فاز ۱۸ — بهبود دقت `LawTerms` و `BM25F`، بستن ۶ مورد باز `audit.json` و تولید `eval_feedback.txt` (انجام شد):**
  - یکدست‌کردن شرط `rareMissing.isEmpty && unknown.isEmpty` روی کل شاخه‌های پذیرش در `law_terms.dart` و `dev/tools/law_terms.py` (رد خودکار پرسش‌های غیرحقوقی و کاهش پذیرفته‌های کاذب در سناریوهای Dart از ۱۱ به ۳ مورد دقیق) و افزودن «خیانت در امانت» (`penal_taazirat` ماده ۶۷۴)، «قولنامه عادی» (`civil` ماده ۱۲۹۱) و «بیع شرط رهن» (`registration` ماده ۳۴) به `assets/brain/legal_terms.json` همراه با هم‌ترازسازی `audit.json` (`۱۴/۱۴`، ۰ باز)، `cases.json` (`۳۸/۳۸`)، `reports/term_audit.md` و `dev/brain/parity_expected.json`.
  - افزودن هم‌معناهای عمومی محاوره‌ای→قانونی به `assets/synonyms.txt` (`eval_blind`: `0.58 → 0.68` recall@1 و `0.84 → 0.97` recall@5؛ `eval_extra`: `0.77 → 0.83`؛ `eval_everyday_laws`: `0.93 → 0.95`)، افزودن پایش `اروپا`/`اروپایی` به `engine_rules.json` (`eval_none`: `۲۸/۲۸` رد درست، ۰٪ خطا) و تولید `eval/eval_feedback.txt` (`۱۸` نمونه) با `dev/tools/feedback_eval.py`.

## وضعیتِ P0های بازبینیِ انتشار (شاخهٔ جاری)

جدول بالا نقشهٔ قدیمیِ بدهی هاست؛ فهرست وضعیتِ زیر مربوط به بازبینیِ
آخرین شاخه است و با معیارِ «یا رفع شود، یا صریحاً غیرقابلاستناد برچسب بخورد»
جلوگیری میکند که P0ها بیصدا بمانند.

| P0 | وضعیتِ امروز | نگهبان / برچسب |
|---|---|---|
| متن قانون تأییدنشده | **ایمنشده، رفعنشده.** ۰/۲۴ قانون `verified`؛ ۱۲۷ مادهٔ جاافتاده فقط `info` | `check.py trust` در release CI قرمز؛ `AboutPage` و README صریحاً میگویند متنها غیررسمیاند |
| قالبهای بازبینینشده | **ایمنشده، رفعنشده.** ۲/۹ بازبینیشده | همان دروازه؛ بقیه «پیشنویس» برچسب خوردهاند |
|Keystore و `encf1:` | **رفعشده.** probe قبل از نوشتن؛ fail-closed؛ رکورد ناخوانا با اطلاع پاک میشود | `MainActivity.probe`، `PrivacyService.beginSession`، `test/core/privacy_fail_closed_test.dart` |
| بازیابیِ وضعیتِ گفتگو | **رفعشده (قالب ۴).** `dialogueJson` همراه پرونده ذخیره و بازیابی میشود | `test/advocate/dialogue_state_test.dart`، `test/app/case_persistence_test.dart` |
| ایمنی | **تا حدی رفعشده.** خودآسیبی پاسخ فوری میگیرد؛ خشونت تازه در همان پرونده دوباره هشدار میگیرد | `test/advocate/safety_test.dart`؛ فقدان ماشینِ شدت/زمان در README ثبت شده است |
| رضایت و پاکسازی | **رفعشده.** onboarding، قفلtoggleها هنگام نبود Keystore، صف سریالی `clear()` و بازنشانی گفتگوی باز | `lib/ui/privacy_notice_page.dart`، `tests/python/test_trust_gate.py` |
| گاد-آبجکت `DialogueState` | **رفعشده.** facade روی پنج تکه، با JSON قابل ذخیره | `tests/python/test_no_god_objects.py` (سقف ۱۲ فیلد حالتی) |

**حکم انتشار:** تا زمانی که دروازهٔ `trust` سبز نشود یا متنها رسماً برچسب
«غیرقابلاستناد» نگیرند، ساخت release مسدود است. سبز بودن `check.py all` به
معنای قابلانتشار بودن محتوای حقوقی نیست.

**سابقهٔ صداقت:** نخستین اجرای CI روی کامیت `9a02d9a` خطاهای واقعی Dart را
نشان داد (constructor پیشفرضِ `DialogueState` و پنج تکهاش، عبارتِ
`byId?[id]` در شرطِ سهتایی، `dialogueJson` خواندهشده از پرونده، و خطاهای
آزمون). تمام آنها اصلاح شدند و در کامیت `dfb8875`، `flutter analyze` بدون
ایراد و `flutter test` با ۵۶۳ آزمون و ۱۳۰ سناریو سبز شد. ادعای «سبز بودن»
فقط از همان اجرای CI است، نه از محیط محلی که Dart نداشت.

## چه چیزی عمداً در این نقشه نیست

- **شکستنِ `reply_routes` و `talk_route`**: مجموعه‌های منسجم‌اند؛ خط جابه‌جا
  می‌شود و مالکیتِ تازه‌ای ساخته نمی‌شود.
- **بردنِ API عمومی به `extension`**: آزموده شد و شکست (موج ۲۶)؛ حالا نگهبان
  دارد.
- **جایگزینی کلوژرهای موضوع‌ها با شناسهٔ قاعده/DSL سبک (فازهای ۹ و ۱۰):** در نسخهٔ فعلی، تبدیل کلوژرها بدون تبدیل `const String` به `RegExp` زمانِ اجرا انجام می‌شود تا شرطِ «بدون ضربه به عملکرد» حفظ شود.
- **رهاشدن فاز ۶ (`assets/brain/noql*`):** به دستور صریح کاربر به‌دلیل آموزش‌پذیربودن و فاین‌تون‌بودن مدل `noql` کنار گذاشته شد.

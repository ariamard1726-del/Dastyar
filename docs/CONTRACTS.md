# قراردادهای داده و کد

این سند فهرست «قرارداد»هایی است که داده و کد باید با هم رعایت کنند. هر
قرارداد یک ابزار بررسی و دست‌کم یک آزمون دارد؛ اگر کد و داده از هم جدا
بیفتند، CI قرمز می‌شود، نه اینکه کاربر جواب ناقص ببیند.

| قرارداد | منبع حقیقت | بررسی | آزمون |
|---|---|---|---|
| ترتیب مسیرهای پاسخ و آستانه‌ها | `assets/pipeline.json` | `python dev/tools/check.py pipeline` | `tests/python/test_pipeline_check.py`، `test/advocate/pipeline_contract_test.dart` |
| ساختار مسیرهای موضوعی | `dev/tools/schemas/topic_flow.schema.json` | `python dev/tools/check.py topics` | `tests/python/test_topic_schema.py` |
| رسیدن هر ارجاع قانونی به متن واقعی | `assets/laws/_meta.json` + متن قوانین | `python dev/tools/check.py refs` | `tests/python/test_data_refs.py` |
| سریال‌شدن پروندهٔ گفتگو | `CaseFile.toJson/fromJson` + `CaseFile.schemaVersion` | — | `test/advocate/case_file_json_test.dart` |
| ماندن پرونده در تاریخچه پس از راهاندازی مجدد | محمولهٔ رمزنگاریشدهٔ `history_v1:m:<id>` (`v: 4`) | `HistoryStore._readSession` | `test/app/case_persistence_test.dart` (با `HistoryStore` تازه؛ قالب ۴ وضعیت گفتگو را هم بازمیگرداند) |
| صدق تیک «محافظت از صفحه» | نتیجهٔ کانال بومی `setSecureScreen` | `AppSettings.applySecureScreenAtStartup` | `test/app/settings_failure_test.dart` |
| ارجاع‌های `[[کلید:شماره]]` در دانش وکیل | متن قوانین | `python dev/tools/check_refs.py` + `test_law_citations_inside_*` | `test/advocate/advocate_test.dart` (روی `.dart`، `rent_texts.json`، `topic_texts.json` و `advocate_texts.json`) + `tests/python/test_topic_text_equivalence.py` + `tests/python/test_advocate_text_equivalence.py` |
| متنِ ثابت موضوع‌های غیرِاجاره و بخش مشترک | `assets/brain/topic_texts.json` + `topic_texts_loader.dart` | `python dev/tools/check.py text` | `tests/python/test_topic_text_equivalence.py`، `test/domain/topic_texts_test.dart` |
| متنِ ثابت عمومیِ وکیل (گفت‌وگو و استدلال) | `assets/brain/advocate_texts.json` + `advocate_texts_loader.dart` | `python dev/tools/check.py text` | `tests/python/test_advocate_text_equivalence.py`، `test/domain/advocate_texts_test.dart` |
| شناسنامهٔ قوانین | `assets/laws/_meta.json` | `python dev/tools/check.py meta` | `tests/python/` |
| قاعده‌های متن | `dev/tools/contracts/text_norm.json` | `python3 dev/tools/gen_text_norm.py --check` (در `check.py textnorm`) | `lib/core/text_norm_rules.dart` و `dev/brain/text_norm_rules.py` (تولیدشده، دستی ویرایش نکنید) |
| خروجی لایهٔ متن | `tests/text_norm_golden.json` (پیش از یکسان‌سازی) + `tests/text_norm_norm_cases.json` | `tests/python/test_text_norm_parity.py` | `test/core/text_norm_rules_test.dart` |
| جدولِ بدهی‌های موقت (دو پیاده‌سازی) | `dev/tools/contracts/duplicated_logic.json` | `python3 dev/tools/debt_check.py --check` (در `check.py debt`) | `tests/python/test_debt_check.py` |
| ایست‌واژه‌ها و آستانهٔ تطبیق واژه‌ها | `dev/tools/contracts/law_terms.json` | `python3 dev/tools/gen_law_terms.py --check` (در `check.py lawterms`) | `lib/domain/advocate/law_terms_rules.dart` و `dev/brain/law_terms_rules.py` (تولیدشده، دستی ویرایش نکنید) + `tests/python/test_law_terms_parity.py` |

> دو پیاده‌سازیِ جدا (دارت و پایتون) **بدهی** است، نه راه‌حل؛ آزمون آینه فقط
> از جداافتادن‌شان جلوگیری می‌کند. ایست‌واژه‌ها و آستانه‌ها از این قاعده بیرون
> رفتند (بالا)؛ منطقِ پردازش هنوز دو جاست. فهرست کامل بدهی‌های موقت و نگهبان‌هایشان
> در `docs/ROADMAP.md` بخش «بدهی‌های موقتِ ثبت‌شده» است.

## ۱. خط لولهٔ پاسخ (`assets/pipeline.json`)

ترتیب مسیرهای دانش و آستانهٔ پذیرش طبقه‌بند (`netMin`) در JSON نوشته شده و
کد Dart باید عیناً همان باشد. دلیل: ترتیب مسیرها رفتار است؛ اگر جایی در کد
عوض شود و اینجا نه، هیچ آزمونی نمی‌فهمید.

```
python dev/tools/check.py pipeline
```

`dev/tools/pipeline_check.py` فهرست `Advocate.pipelineOrder` و مقدار
`Advocate.netMin` را از `lib/domain/advocate/advocate.dart` می‌خواند و با JSON
می‌سنجد. افزودن مسیر تازه: اول JSON، بعد enum و ترتیب در Dart.

## ۲. ساختار مسیر موضوعی (`dev/tools/schemas/topic_flow.schema.json`)

دو پوشه داریم: `assets/brain/topics/` (در APK بستهبندی میشود) و `lab/topics/`
(در دست ساخت، در `pubspec.yaml` نیست؛ فقط ساختارش سنجیده میشود و آزمونهای
نمونهاش اجرا میشوند). درون پوشهٔ بستهبندیشده دو قراردادِ جدا داریم:

- **مسیر تصمیم** (`index.json` + فایلهای فهرستشده مانند `cheque.json`): `live`
  الزامی و `live:false` **خطا**. هر فایل باید کلیدهای
  `live/gate/topic/law/disclaimer/clarify/rules/leaves` را داشته باشد، هر قاعده
  به برگی موجود اشاره کند، هر برگ `title` و `text` داشته باشد و ارجاعهای
  `articles` از شکل «ماده/اصل N» باشند.
- **متن ثابت اجاره** (`assets/brain/topics/rent_texts.json`): یازده جدولِ `texts`،
  `claims`، `filings`، `plans`، `bodies`، `fills`، `prompts`، `effects`،
  `slots`، `issues` و `recaps` (جمعاً ۵۲۵ کلید؛ `id → text`) که تصمیم‌گیر
  نیستند و در `index.json` فهرست نمی‌شوند. شناسهٔ قالبِ سند (`template`) و
  ۱۵ گزینهٔ قالبیِ `rent_fill.dart` جزءِ تصمیم‌اند و در Dart می‌مانند.
  درونیابیِ وابسته به پرونده (مثلِ `moneyForum(sum)`) هم در Dart می‌ماند و
  با `+` به متنِ دارایی چسبیده می‌شود.
  هشِ نویسهبه‌نویسهٔ هر جدول و شمارِ رشته‌هایش در
  `tests/python/test_rent_text_equivalence.py` قفل است؛ بارگذاری صریح است
  (`loadRentTexts`) و نصبِ ناقص خطا می‌دهد.
- **متن ثابت بقیهٔ موضوع‌ها و بخش مشترک** (`assets/brain/topic_texts.json`،
  در `assets/brain/` و بیرون از `assets/brain/topics/` تا مرز موضوع‌های
  JSON دست‌نخورده بماند): ۲۴ بخش (`shared`، `labor`، `family` و ۲۱ موضوعِ
  غیرِاجاره — جمعاً ۱٬۱۰۶ کلید) که از راه `topicText(section, key)` و
  `loadTopicTexts` خوانده می‌شوند. مصرف ۱۰۰٪ کلیدها، نبودِ نثرِ آزادِ
  باقی‌مانده در فایل‌های `topics/*.dart`، اعتبار استنادهای `[[کلید:شماره]]`
  و برابری متن‌ها با پیش از انتقال در
  `tests/python/test_topic_text_equivalence.py` و `test/domain/topic_texts_test.dart`
  قفل است.

نگهبان، هر فایلِ اضافه در `assets/brain/topics/` را قرمز میکند تا حالتِ
میانهٔ «دادهٔ بلااستفاده» دوباره شکل نگیرد.

هشدارها (نه خطا) این‌ها را نشان می‌دهند:

- واژهٔ دروازهٔ عام («خانه»، «پول»، «قرارداد»، …) که هر پیامی را به این مسیر می‌کشد؛
- موضوع `live:false` که در APK می‌ماند ولی در گفتگو جواب نمی‌دهد؛
- برگی که هیچ قاعده‌ای به آن نمی‌رسد (دادهٔ مرده).

```
python dev/tools/check.py topics
```

## ۳. یکپارچگی ارجاع‌های داده (`dev/tools/data_refs.py`)

هر ارجاع قانونی در داده باید به ماده‌ای برسد که واقعاً در متن قانون هست:

- `assets/brain/topics/*.json` → `leaves[*].articles`
- `assets/templates/*.json` → `lawRefs[*]`
- `assets/qa/*.json` → `refs` («شناسه‌قانون:ماده N»)

اگر ارجاعی بشکند، `KnowledgeEngine.chunkOf` نال می‌دهد و کاربر پاسخی
می‌بیند که هیچ ماده‌ای پشتش نیست. این ابزار همان سکوت را به خطا تبدیل می‌کند
و ارقام فارسی/عربی را هم می‌شناسد.

```
python dev/tools/check.py refs
```

## ۴. پروندهٔ گفتگو (`CaseFile`)

`CaseFile` سه‌حالته‌ها («بله»، «نه»، «نمی‌دانم»)، شمار پرسش‌ها و بخش‌های
توضیح‌داده‌شده را نگه می‌دارد. با `toJson()`/`fromJson()` می‌شود پرونده را
بدون پخش دوبارهٔ پیام‌ها ذخیره کرد.

- `CaseFile.schemaVersion` نسخهٔ قالب است؛ تغییر ساختار = افزایش نسخه و
  نوشتن مهاجرت در `fromJson`.
- ورودی نامعتبر یا نسخهٔ ناشناخته پروندهٔ خالی می‌دهد (نه استثنا): گفتگو با
  پروندهٔ تازه ادامه می‌یابد.

آزمون: `test/advocate/case_file_json_test.dart`.

## ۵. ایست‌واژه‌ها و آستانهٔ تطبیق واژه‌ها (`dev/tools/contracts/law_terms.json`)

پرسش کوتاهِ کاربر با متن مواد سنجیده می‌شود و پیش از سنجش، واژه‌های گفتاری
(«بود»، «خیلی»، «میشه»…) از پرسش در می‌آیند؛ وگرنه هر پرسشی با هر ماده‌ای
«پوشش» پیدا می‌کند. این فهرست و آستانه‌ها (کمینهٔ طول واژه، شمار نامزدهای
برتر، پوشش لازم، dfِ «نادر»، بیشترین فاصلهٔ عبارت، کمینهٔ idfِ عبارت) پیش‌تر
دستی در دو جا نوشته شده بود.

- **یک مرجع:** `dev/tools/contracts/law_terms.json`.
- **تولید:** `python3 dev/tools/gen_law_terms.py --write` →
  `lib/domain/advocate/law_terms_rules.dart` و `dev/brain/law_terms_rules.py`.
- **بررسی:** `python3 dev/tools/check.py lawterms` (و در `check.py all`) کهنه‌بودن را
  خطا می‌دهد. افزودن واژهٔ تازه: اول JSON، بعد `--write`؛ ویرایش فایل‌های
  تولیدشده در بازبینی رد می‌شود.
- **منطق هنوز دو جاست** (موتور دارت و آینهٔ پایتون). این بدهی در `docs/ROADMAP.md`
  مانده؛ چیزی که یک‌جا شد، خودِ داده (فهرست و آستانه‌ها) است، نه الگوریتم.

آزمون: `tests/python/test_law_terms_parity.py` (تازگیِ تولید، یکی‌بودن فهرست،
یکی‌بودن آستانه‌ها و نگاشت `افحش→فاحش`)، و `dev/tools/law_terms.py --check` روی
۳۵ نمونهٔ `tests/law_terms/cases.json`.

## ۶. جدولِ بدهی‌های موقت (`dev/tools/contracts/duplicated_logic.json`)

هر جا یک چیز در دو زبان پیاده شده است، در این فایل یک ردیف دارد: فایلِ دارت،
فایلِ پایتون، مجموعهٔ نمونهٔ مشترک، توضیح و «رفع واقعی». `check.py debt` سه
چیز را می‌سنجد:

1. هر مسیرِ نوشته‌شده وجود دارد؛
2. هر مجموعهٔ نمونه از هر دو زبان خوانده می‌شود (نامش در کدِ هر دو طرف هست)
   — اگر یک طرف دست بکشد، دوئیت به یک پیاده‌سازیِ بی‌نگهبان تبدیل می‌شود؛
3. جفت هنوز در `docs/ROADMAP.md` بخش «بدهی‌های موقتِ ثبت‌شده» ذکر شده است.

پس دو کار با هم انجام می‌شود: رفع واقعی (یکی از دو طرف حذف/تولید شود) و حذف
ردیف از هر دو جا در یک جا. جفتِ تازه = ردیفِ تازه این‌جا، نه فقط یک خط در سند.

آزمون: `tests/python/test_debt_check.py`.

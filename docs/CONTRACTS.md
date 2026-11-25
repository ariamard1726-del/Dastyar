# قراردادهای داده و کد

این سند فهرست «قرارداد»هایی است که داده و کد باید با هم رعایت کنند. هر
قرارداد یک ابزار بررسی و دست‌کم یک آزمون دارد؛ اگر کد و داده از هم جدا
بیفتند، CI قرمز می‌شود، نه اینکه کاربر جواب ناقص ببیند.

| قرارداد | منبع حقیقت | بررسی | آزمون |
|---|---|---|---|
| ترتیب مسیرهای پاسخ و آستانه‌ها | `assets/pipeline.json` | `python tools/check.py pipeline` | `tests/python/test_pipeline_check.py`، `test/advocate/pipeline_contract_test.dart` |
| ساختار مسیرهای موضوعی | `tools/schemas/topic_flow.schema.json` | `python tools/check.py topics` | `tests/python/test_topic_schema.py` |
| رسیدن هر ارجاع قانونی به متن واقعی | `assets/laws/_meta.json` + متن قوانین | `python tools/check.py refs` | `tests/python/test_data_refs.py` |
| سریال‌شدن پروندهٔ گفتگو | `CaseFile.toJson/fromJson` + `CaseFile.schemaVersion` | — | `test/advocate/case_file_json_test.dart` |
| ماندن پرونده در تاریخچه پس از راهاندازی مجدد | محمولهٔ رمزنگاریشدهٔ `history_v1:m:<id>` (`v: 3`) | `HistoryStore._readSession` | `test/app/case_persistence_test.dart` (با `HistoryStore` تازه) |
| صدق تیک «محافظت از صفحه» | نتیجهٔ کانال بومی `setSecureScreen` | `AppSettings.applySecureScreenAtStartup` | `test/app/settings_failure_test.dart` |
| ارجاع‌های `[[کلید:شماره]]` در کد Dart | متن قوانین | `python tools/check_refs.py` | `tests/python/` (آزمون‌های شناسنامه) |
| شناسنامهٔ قوانین | `assets/laws/_meta.json` | `python tools/check.py meta` | `tests/python/` |
| قاعده‌های متن | `tools/contracts/text_norm.json` | `python3 tools/gen_text_norm.py --check` (در `check.py textnorm`) | `lib/core/text_norm_rules.dart` و `brain/text_norm_rules.py` (تولیدشده، دستی ویرایش نکنید) |
| خروجی لایهٔ متن | `tests/text_norm_golden.json` (پیش از یکسان‌سازی) + `tests/text_norm_norm_cases.json` | `tests/python/test_text_norm_parity.py` | `test/core/text_norm_rules_test.dart` |
| جدولِ بدهی‌های موقت (دو پیاده‌سازی) | `tools/contracts/duplicated_logic.json` | `python3 tools/debt_check.py --check` (در `check.py debt`) | `tests/python/test_debt_check.py` |
| ایست‌واژه‌ها و آستانهٔ تطبیق واژه‌ها | `tools/contracts/law_terms.json` | `python3 tools/gen_law_terms.py --check` (در `check.py lawterms`) | `lib/domain/advocate/law_terms_rules.dart` و `brain/law_terms_rules.py` (تولیدشده، دستی ویرایش نکنید) + `tests/python/test_law_terms_parity.py` |

> دو پیاده‌سازیِ جدا (دارت و پایتون) **بدهی** است، نه راه‌حل؛ آزمون آینه فقط
> از جداافتادن‌شان جلوگیری می‌کند. ایست‌واژه‌ها و آستانه‌ها از این قاعده بیرون
> رفتند (بالا)؛ منطقِ پردازش هنوز دو جاست. فهرست کامل بدهی‌های موقت و نگهبان‌هایشان
> در `docs/ROADMAP.md` بخش «بدهی‌های موقتِ ثبت‌شده» است.

## ۱. خط لولهٔ پاسخ (`assets/pipeline.json`)

ترتیب مسیرهای دانش و آستانهٔ پذیرش طبقه‌بند (`netMin`) در JSON نوشته شده و
کد Dart باید عیناً همان باشد. دلیل: ترتیب مسیرها رفتار است؛ اگر جایی در کد
عوض شود و اینجا نه، هیچ آزمونی نمی‌فهمید.

```
python tools/check.py pipeline
```

`tools/pipeline_check.py` فهرست `Advocate.pipelineOrder` و مقدار
`Advocate.netMin` را از `lib/domain/advocate/advocate.dart` می‌خواند و با JSON
می‌سنجد. افزودن مسیر تازه: اول JSON، بعد enum و ترتیب در Dart.

## ۲. ساختار مسیر موضوعی (`tools/schemas/topic_flow.schema.json`)

دو پوشه داریم: `assets/brain/topics/` (در APK بسته‌بندی می‌شود؛ `live` الزامی و
`live:false` **خطا**) و `lab/topics/` (در دست ساخت، در `pubspec.yaml` نیست؛ فقط
ساختارش سنجیده می‌شود و آزمون‌های نمونه‌اش اجرا می‌شوند).

هر `assets/brain/topics/*.json` باید کلیدهای `live/gate/topic/law/disclaimer/
clarify/rules/leaves` را داشته باشد، هر قاعده به برگی موجود اشاره کند، هر برگ
`title` و `text` داشته باشد و ارجاع‌های `articles` از شکل «ماده/اصل N» باشند.

هشدارها (نه خطا) این‌ها را نشان می‌دهند:

- واژهٔ دروازهٔ عام («خانه»، «پول»، «قرارداد»، …) که هر پیامی را به این مسیر می‌کشد؛
- موضوع `live:false` که در APK می‌ماند ولی در گفتگو جواب نمی‌دهد؛
- برگی که هیچ قاعده‌ای به آن نمی‌رسد (دادهٔ مرده).

```
python tools/check.py topics
```

## ۳. یکپارچگی ارجاع‌های داده (`tools/data_refs.py`)

هر ارجاع قانونی در داده باید به ماده‌ای برسد که واقعاً در متن قانون هست:

- `assets/brain/topics/*.json` → `leaves[*].articles`
- `assets/templates/*.json` → `lawRefs[*]`
- `assets/qa/*.json` → `refs` («شناسه‌قانون:ماده N»)

اگر ارجاعی بشکند، `KnowledgeEngine.chunkOf` نال می‌دهد و کاربر پاسخی
می‌بیند که هیچ ماده‌ای پشتش نیست. این ابزار همان سکوت را به خطا تبدیل می‌کند
و ارقام فارسی/عربی را هم می‌شناسد.

```
python tools/check.py refs
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

## ۵. ایست‌واژه‌ها و آستانهٔ تطبیق واژه‌ها (`tools/contracts/law_terms.json`)

پرسش کوتاهِ کاربر با متن مواد سنجیده می‌شود و پیش از سنجش، واژه‌های گفتاری
(«بود»، «خیلی»، «میشه»…) از پرسش در می‌آیند؛ وگرنه هر پرسشی با هر ماده‌ای
«پوشش» پیدا می‌کند. این فهرست و آستانه‌ها (کمینهٔ طول واژه، شمار نامزدهای
برتر، پوشش لازم، dfِ «نادر»، بیشترین فاصلهٔ عبارت، کمینهٔ idfِ عبارت) پیش‌تر
دستی در دو جا نوشته شده بود.

- **یک مرجع:** `tools/contracts/law_terms.json`.
- **تولید:** `python3 tools/gen_law_terms.py --write` →
  `lib/domain/advocate/law_terms_rules.dart` و `brain/law_terms_rules.py`.
- **بررسی:** `python3 tools/check.py lawterms` (و در `check.py all`) کهنه‌بودن را
  خطا می‌دهد. افزودن واژهٔ تازه: اول JSON، بعد `--write`؛ ویرایش فایل‌های
  تولیدشده در بازبینی رد می‌شود.
- **منطق هنوز دو جاست** (موتور دارت و آینهٔ پایتون). این بدهی در `docs/ROADMAP.md`
  مانده؛ چیزی که یک‌جا شد، خودِ داده (فهرست و آستانه‌ها) است، نه الگوریتم.

آزمون: `tests/python/test_law_terms_parity.py` (تازگیِ تولید، یکی‌بودن فهرست،
یکی‌بودن آستانه‌ها و نگاشت `افحش→فاحش`)، و `tools/law_terms.py --check` روی
۳۵ نمونهٔ `tests/law_terms/cases.json`.

## ۶. جدولِ بدهی‌های موقت (`tools/contracts/duplicated_logic.json`)

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

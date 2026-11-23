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
| ارجاع‌های `[[کلید:شماره]]` در کد Dart | متن قوانین | `python tools/check_refs.py` | `tests/python/` (آزمون‌های شناسنامه) |
| شناسنامهٔ قوانین | `assets/laws/_meta.json` | `python tools/check.py meta` | `tests/python/` |

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

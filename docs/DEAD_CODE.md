# گزارش کد و فایل‌های مرده

این سند فهرست کدها و فایل‌هایی است که در ممیزی بی‌مصرف تشخیص داده شده‌اند.
**هیچ‌کدام هنوز حذف نشده‌اند.** حذف هر مورد فقط با تأیید صریح صاحب پروژه انجام می‌شود.

روش بررسی:
- **Dart (سطح نماد):** برای هر کلاس/تابع، جست‌وجوی ارجاع در کل `lib/` و `test/`. نمادی که فقط در تعریف خودش دیده شود مرده است.
- **Dart (سطح فایل):** گراف واردات از `lib/main.dart` (شامل `part`). همهٔ فایل‌های `lib/` از `main.dart` قابل دسترس‌اند، پس مرده‌ها در سطح نماد هستند.
- **غیر-Dart:** جست‌وجوی نام فایل در کل مخزن (به‌جز `.git`). ارجاع پویا (مثلاً پوشهٔ `assets/templates/` که به‌صورت فهرست خوانده می‌شود، یا فایل‌های اندروید که Gradle می‌خواند) مرده حساب نشده است.

## ۱. کد Dart بی‌مصرف

| مورد | محل | شواهد | پیشنهاد |
|---|---|---|---|
| `lawFactors(String)` | `lib/core/engine.dart` (حدود خط ۱۸۱) | فقط تعریف؛ توضیح «برای آزمون و عیب‌یابی» دارد ولی هیچ آزمونی آن را صدا نمی‌زند | حذف |
| `mentionedLaws(String)` | `lib/core/engine.dart` (حدود خط ۴۷۲) | فقط یک پوشش عمومی روی `_mentionedLaws` است؛ هیچ‌جا صدا زده نمی‌شود | حذف (خود `_mentionedLaws` بماند) |
| `HybridIntentRouter` و کلاس‌های کمکی آن (`HybridRouterConfig`، `KeywordScores`، `RoutingDecision`، `RoutingSource`، `WeightedKeyword`، `StrictPhrase`، `_PreparedKeyword`، `_PreparedStrict`) | `lib/core/router.dart` (خطوط ۵۲ تا ۵۶۷) | در اجرای برنامه صدا زده نمی‌شود؛ فقط `test/core/hybrid_router_test.dart` (۱۸ آزمون) از آن استفاده می‌کند | حذف همراه با آزمونش؛ فقط `QueryRouter` (خطوط ۱ تا ۵۰) که در `engine.dart` استفاده می‌شود باقی بماند |
| `lib/core/persian_normalizer.dart` (۱۴۸ خط) و `test/core/persian_normalizer_test.dart` (۵۸ خط) | — | تنها مصرف‌کنندهٔ آن `HybridIntentRouter` است؛ پس با حذف مورد بالا، این فایل هم مرده می‌شود | حذف همراه با مورد بالا |

**اثر کلی حذف بسته‌ای (بندهای بالا):** حدود ۶۶۵ خط کد (۵۱۷ خط از `router.dart` که `QueryRouter` را نگه می‌دارد + ۱۴۸ خط `persian_normalizer.dart`) و ۱۸۷ خط آزمون (`hybrid_router_test` با ۱۸ آزمون + `persian_normalizer_test`). این حذف رفتار اپ را تغییر نمی‌دهد، ولی `flutter test` باید بعداً اجرا شود تا چیزی وابسته نشده باشد.

## ۲. ابزار و اسکریپت‌های پایتون و فایل‌های بی‌ارجاع

| فایل | وضعیت | توضیح |
|---|---|---|
| `tools/make_icon.py` | یک‌بار مصرف | تولید آیکون با Pillow؛ آیکون تولیدشده در پروژه است و اسکریپت دیگر لازم نیست |
| `tools/laws_status.py` | احتمالاً منسوخ | گزارش وضعیت قوانین؛ `tools/law_registry.py status` همین کار را انجام می‌دهد |
| `tools/ci_status.py` | بی‌ارجاع | کمک CLI برای وضعیت CI؛ در گردش‌کارها یا مستندات صدا زده نمی‌شود |
| `tools/dupes.py` | بی‌ارجاع | یافتن قانون/ماده تکراری؛ پوشش آن توسط `check.py corpus` و `law_registry` ممکن است |
| `tools/set_meta.py` | دستی | فقط خودش در توضیحش ارجاع دارد؛ ابزار ویرایش دستی `_meta.json` — اگر نگه داشته شود، در README ذکر شود |
| `brain/ngram_eval.py` | آزمایش انجام‌شده | خروجی‌اش `brain/reports/ngram.txt` موجود است؛ آزمایش بسته شده و کد آن بی‌ارجاع است (بایگانی پیشنهاد می‌شود) |
| `brain/eval/gold500.txt` (۲۱ کیلوبایت) | داده بی‌ارجاع | هیچ اسکریپت یا گردش‌کاری آن را نمی‌خواند |
| `eval/dialogues.txt` | داده بی‌ارجاع | هیچ آزمونی آن را نمی‌خواند؛ `test/audit/conversations.txt` کار مشابه را می‌کند |
| `tools/synonyms/new_rows.txt` | پیش‌نویس | ردیف‌های جدید مترادف که هنوز در `assets/synonyms.txt` ادغام نشده‌اند؛ پس از ادغام یا رد، حذف شود |
| `docs/review_guide.md` | سند بی‌ارجاع | راهنمای کارشناس حقوقی برای بازبینی قالب‌ها؛ از README یا مستندات دیگر لینک نشده است |
| `brain/reports/embed_intfloat_multilingual-e5-small.txt`، `brain/reports/embed_sentence-transformers_paraphrase-multilingual-MiniLM-L12-v2.txt` | خروجی خام | خلاصهٔ مقایسه در `brain/reports/embed_bench.md` و `alt_bench.md` آمده؛ این دو خروجی خام تکراری‌اند و می‌توانند بایگانی شوند |

## ۳. ساختار تکراری (نه مرده، ولی باید یکی شود)

- `eval/` و `brain/eval/`؛ `reports/` و `brain/reports/`: هر دو در گردش‌کارهای CI و آزمون‌های Dart ارجاع دارند. ادغام نیاز به به‌روزرسانی هم‌زمان ۱۰+ گردش‌کار، ۸ آزمون Dart و ۱۲ اسکریپت پایتون دارد و باید در کامیت جدا با `flutter test` انجام شود.

## ۴. موارد که عمداً مرده حساب نشده‌اند

- `assets/templates/*.json`: با فهرست پوشه خوانده می‌شوند؛ ارجاع نامی ندارند.
- `android/**`: توسط Gradle و Flutter مصرف می‌شوند.
- `raw/*.txt`: متن خام منابع قانونی؛ `docs/LAW_SOURCES.md` و `docs/review_guide.md` به آن‌ها ارجاع می‌دهند. این‌ها منبع نسخهٔ بسته‌بندی‌شده نیستند، ولی برای ممیزی دستی لازم‌اند.
- `test/lab/probe.txt`، `reports/lab/`، `brain/eval/debug_queries.txt`: ورودی گردش‌کارهای آزمایشگاه و آزمون رتبه‌بندی.

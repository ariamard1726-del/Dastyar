# گزارش کد و فایل‌های مرده

این سند ثبت ممیزی و حذف فایل‌های بی‌مصرف است. حذف‌ها با تأیید صاحب پروژه انجام شده‌اند؛ هر فایل حذف‌شده از تاریخچهٔ گیت قابل بازیابی است (کامیت قبل از حذف: `f0fc737`).

روش بررسی:
- **Dart (سطح نماد):** جست‌وجوی ارجاع هر کلاس/تابع در کل `lib/` و `test/`. نمادی که فقط در تعریف خودش دیده شود مرده است.
- **Dart (سطح فایل):** گراف واردات از `lib/main.dart` (شامل `part`).
- **غیر-Dart:** جست‌وجوی نام فایل در کل مخزن. ارجاع پویا (فهرست پوشهٔ قالب‌ها، فایل‌های اندروید) مرده حساب نشده است.

## ۰. خارج‌شده از بستهٔ برنامه (همین شاخه)

| مورد | چرا | کجا رفت |
|---|---|---|
| `assets/brain/topics/rent.json`، `assets/brain/topics/labor_wages.json` | `live:false` بودند: در APK بسته‌بندی و در حافظه parse می‌شدند ولی هرگز در گفتگو جواب نمی‌دادند (دروازه‌هایشان هم عام بود: «خانه»، «پول»، «قرارداد»). | `lab/topics/`؛ در `pubspec.yaml` نیستند و نمونه‌های آزمونشان (`tests/topics/*_gold.json`) همچنان اجرا می‌شوند. `assets/brain/topics/index.json` حالا فقط موضوع‌های `live` را فهرست می‌کند و `live:false` در بستهٔ برنامه **خطا** است (`dev/tools/topic_schema.py`). |

## ۱. حذف‌شده

### کد Dart
| مورد | شواهد |
|---|---|
| `HybridIntentRouter` و کلاس‌های کمکی‌اش (`HybridRouterConfig`، `KeywordScores`، `RoutingDecision`، `RoutingSource`، `WeightedKeyword`، `StrictPhrase`، `_PreparedKeyword`، `_PreparedStrict`) در `lib/core/router.dart` | در اجرای برنامه صدا زده نمی‌شد؛ فقط آزمونش استفاده می‌کرد. `QueryRouter` (تنها بخش مصرف‌شده) نگه داشته شد. |
| `test/core/hybrid_router_test.dart` (۱۸ آزمون) | آزمون کد حذف‌شده |
| `lib/core/persian_normalizer.dart` و `test/core/persian_normalizer_test.dart` | تنها مصرف‌کنندهٔ آن `HybridIntentRouter` بود |
| `lawFactors(String)` در `lib/core/engine.dart` | هیچ‌جا صدا زده نمی‌شد. نسخهٔ پایتونی آن در `dev/tools/eval_py.py` (`law_factors`) فعال است و نگه داشته شد. |
| `mentionedLaws(String)` در `lib/core/engine.dart` | پوشش عمومی بی‌مصرف روی `_mentionedLaws` |

### فایل‌های پایتون و داده
| فایل | دلیل |
|---|---|
| `dev/tools/make_icon.py` | تولید آیکون یک‌بار مصرف؛ آیکون در پروژه موجود است |
| `dev/tools/laws_status.py` | منسوخ؛ `dev/tools/law_registry.py status` همین کار را می‌کند |
| `dev/tools/ci_status.py` | بی‌ارجاع |
| `dev/tools/dupes.py` | بی‌ارجاع |
| `dev/brain/ngram_eval.py` | آزمایش تمام‌شده؛ گزارشش هم در پاکسازی سوم حذف شد (شاهد بدون مدل در `reports/alt_bench.md` باقی است). |
| `eval/gold500.txt` | داده بی‌ارجاع؛ هیچ اسکریپت یا گردش‌کاری آن را نمی‌خواند |
| `eval/dialogues.txt` | داده بی‌ارجاع؛ `test/audit/conversations.txt` کار مشابه را می‌کند |
| `reports/embed_intfloat_multilingual-e5-small.txt`، `reports/embed_sentence-transformers_paraphrase-multilingual-MiniLM-L12-v2.txt` | خروجی خام تکراری؛ نتیجه در `embed_bench.md` و `alt_bench.md` آمده |

**اثر:** حدود ۶۶۵ خط کد Dart و ۱۸۷ خط آزمون Dart حذف شد. رفتار اپ تغییر نکرده است، چون هیچ مسیر زنده‌ای به این کدها وصل نبود.

## ۲. نگه‌داشته‌شده (عمداً)

| مورد | دلیل نگه‌داشتن |
|---|---|
| `dev/tools/synonyms/new_rows.txt` | پیش‌نویس مترادف‌های جدید که هنوز در `assets/synonyms.txt` ادغام نشده؛ حذفش داده را از بین می‌برد. |
| `docs/review_guide.md` | راهنمای کارشناس حقوقی برای بازبینی قالب‌ها؛ سند انسانی است، نه کد مرده. |

## ۳. ساختار تکراری (هنوز یکی نشده)

- ✅ دوقلوی `eval/` و `reports/` حذف شد؛ ورودیها در `eval/` و خروجیها در `reports/`اند (`tests/python/test_repo_hygiene.py`).

## ۴. موارد که مرده حساب نشده‌اند
- `assets/templates/*.json`: با فهرست پوشه خوانده می‌شوند.
- `android/**`: توسط Gradle و Flutter مصرف می‌شوند.
- `raw/*.txt`: متن خام منابع قانونی؛ `docs/LAW_SOURCES.md` به آن‌ها ارجاع می‌دهد.
- `test/lab/probe.txt`، `reports/lab/`، `eval/debug_queries.txt`: ورودی گردش‌کارهای آزمایشگاه و آزمون رتبه‌بندی.

## ۵. ممیزی دوم (نوامبر ۲۰۲۶)

روش: گراف واردات از `lib/main.dart` (همهٔ فایل‌های `lib/` از آن قابل دسترس‌اند، پس فایل مرده‌ای نمانده)، شمارش ارجاع هر نماد سطح بالا در `lib/`، `test/` و `tool/`، و جست‌وجوی نام هر فایل غیر-Dart در کل مخزن.

### حذف‌شده
| مورد | شواهد |
|---|---|
| `ConflictsService.loadData()` و کش `_cache` در `lib/core/conflicts_service.dart` | موتور `relationships.json` را خودش می‌خواند و به سرویس می‌دهد؛ این متد هیچ‌جا صدا زده نمی‌شد. |
| `ReplyBank.setOverrides(Map<String,String>)` در `lib/core/replies.dart` | پوشانندهٔ «سازگاری با فراخوان‌های قدیمی»؛ فراخوانی نداشت. `setOverridesRaw` در موتور استفاده می‌شود. |
| `PersianText.stemIndex` و `PersianText.stemQuery` در `lib/core/persian_text.dart` | پوشانندهٔ عمومی؛ فقط نسخهٔ خصوصی `_stemIndex` و `_stem` داخل همان فایل استفاده می‌شوند. |
| `IntentNet.groupScore` در `lib/domain/intent_net.dart` | هیچ‌جا صدا زده نمی‌شد. |

### نگه‌داشته‌شده (عمداً)
| مورد | دلیل |
|---|---|
| `tests/python/test_intent_map.py`، `tests/python/test_law_registry.py` | `python -m unittest discover -s tests/python` در گردش‌کار `gemini-agent` همهٔ `test_*.py` را اجرا می‌کند؛ بی‌ارجاع نامی، ولی زنده‌اند. |
| `raw/*.txt` | همان دلیل بخش ۴. |

### نکتهٔ معماری (تغییر داده نشد)
- لایه‌بندی درست است: `core/` و `domain/` هیچ‌جا `ui/` یا `core/` را از `domain/` وارد نمی‌کنند؛ `ui/` فقط به `core/` و `domain/` وابسته است.
- `lib/domain/settings.dart` `material.dart` را وارد می‌کند (برای مدل تنظیمات). اگر لازم شد، می‌شود مدل را از Flutter جدا کرد.

## ۶. پاکسازی سوم (همین شاخه، نوامبر ۲۰۲۶)

روش: گراف واردات `lib/` از `lib/main.dart` (همهٔ ۱۵۵ فایل قابل دسترساند)، شمارش ارجاع نام فایل در کل مخزن، و خواندن کدهایی که نمونهها را با الگو میخوانند.

### حذفشده
| مورد | شواهد |
|---|---|
| ۲۶ عکسِ توسعهٔ `tests/topics/*` (`*_dev5..7`، `*_fresh*`، `*_test5..7`، `cheque_heldout2..6`، `rent_heldout.json`، `labor_wages_heldout.json`، `misfiled_*`) | تنها چهار نمونه توسط کد خوانده میشوند: `cheque_gold.json` و `cheque_heldout.json` (`test_topic_flow.py`) و `rent_gold.json` / `labor_wages_gold.json` (`topic_flow.py --check`). بقیه در هیچ اسکریپت، آزمون یا گردشکاری نام برده نمیشوند. |
| `dev/tools/holdout_intent.py` و `reports/intent_holdout_netcompare.txt` | ابزار دستی و نتیجهاش؛ فقط در همین سند نام میآمدند. `reports/intent_holdout.md` زنده است و توسط `tests/python/test_classifier_choice.py` خوانده میشود. |
| `dev/tools/set_meta.py` | ابزار دستی یکبارمصرف؛ بعد از جابجایی `_meta.json`ها به داراییهای تولیدشده هیچ فراخوانی نداشت. |
| `reports/ngram.txt` | خروجی آزمایش تمامشده؛ جای آن در `reports/alt_bench.md` (ردیف شاهد بدون مدل) است. |

### نگه داشتهشده (عمداً)
- `tests/topics/{cheque_gold,cheque_heldout,rent_gold,labor_wages_gold}.json` — توسط آزمونها خوانده میشوند.
- `lab/topics/*.json` — اگرچه در APK نیستند، `topic_flow.py --check` نمونههایشان را اجرا میکند.
- `dev/tools/synonyms/new_rows.txt` — پیشنویس ادغامنشده، داده است نه کد مرده.
- `raw/*.txt` و `eval/*` — منابع قانونی و ورودیهای سنجش.

نگهبان: `tests/python/test_repo_hygiene.py` هم گراف واردات و هم فهرست حذفها را قفل میکند.

# دستیار

دستیار حقوقی آفلاین فارسی برای اندروید (Flutter). پاسخ‌ها از متن قوانینِ داخل برنامه بازیابی می‌شوند، با ذکر منبع و ماده. اگر ماده‌ای پیدا نشود، به‌جای حدس‌زدن همین را می‌گوید. قالب‌های پیش‌نویس (مثل شکوائیهٔ چک) فقط پیش‌نویس‌اند و هنوز بازبینی حقوقی نشده‌اند. برنامه وکیل نیست.

## ساختار

لایه‌بندی `lib/` (وابستگی فقط رو به پایین؛ جزئیات در `docs/ARCHITECTURE.md`):

- `lib/core/`: زیرساخت بدون وابستگی به قابلیت‌ها — `persian_text.dart` (لایهٔ یکتای متن فارسی: نرمال‌سازی، ارقام، برش ایمن یونیکد، اعتبارسنجی کد ملی/تلفن، ایست‌واژه و ریشه‌یابی)، `engine.dart` و `models.dart` (بارگذاری موازی قوانین در Isolate، نمایهٔ معکوس BM25F، بازیابی تک‌مرحله‌ای)، `router.dart` (نیت‌های ثابت پرسش)، `conflicts_service.dart` (زنجیرهٔ تعارض مواد)، `replies.dart` (پاسخ‌های ثابت)، `llm.dart` (بک‌اندهای مدل زبانی محلی: `OnDeviceChannelLlm`، `LocalLoopbackLlm` محدود به `127.0.0.1`، `AdaptiveLlm`)، `privacy.dart` (رمزنگاری محلی با Android Keystore، `AES-256-GCM`، کلیپ‌بورد حساس و `FLAG_SECURE`)، `history.dart` و `config.dart`
- `lib/domain/`: قابلیت‌های حقوقی — `assistant.dart` و `prompt_builder.dart` (هماهنگ‌کنندهٔ پاسخ و نگهبان استناد مواد/قوانین)، `legal_counselor.dart` (مشاورهٔ گام‌به‌گام با شبکهٔ نیت و RAG)، `intent_net.dart` (شبکهٔ عصبی نیت، آینهٔ پایتون آن در `tools/check.py intent`)، `drafting.dart` و `templates.dart` (پیش‌نویس مرحله‌به‌مرحلهٔ اسناد با ذخیرهٔ موقت رمزنگاری‌شده)، `feedback.dart`، `settings.dart`
- `lib/ui/`: رابط کاربری — `chat_page.dart`، `chat_controller.dart` و `chat_models.dart` (کنترلر مستقل وضعیت گفتگو، پیشنهاد قالب، استریم و لغو ایمن)، صفحه‌های تنظیمات/تاریخچه/درباره و `widgets/chat_bubbles.dart`
- `assets/laws`: متن قوانین با `_meta.json` (منبع یکتای متادیتا؛ `laws_catalog.json` و `data_info.json` با `tools/sync_meta.py` از آن مشتق می‌شوند). `assets/templates`: قالب‌ها. `assets/synonyms.txt`، `relationships.json` (منبع یکتای روابط مواد)، `replies.json`
- `test`: در شش شاخهٔ `core/`، `domain/`، `engine/`، `drafting/`، `counselor/` و `app/` (نام‌گذاری رفتاری، شامل تست برابری پایتون↔دارت در `test/core/parity_test.dart`)
- `tools`: ابزارهای پایتون برای اعتبارسنجی یکپارچه (`check.py` با زیردستورهای corpus/assets/meta/intent/parity)، همگام‌سازی متادیتا (`sync_meta.py`)، سلامت‌سنجی (`doctor.py`)، ارزیابی آفلاین (`eval_py.py`) و امضای نسخهٔ انتشار (`setup_release_signing.py`)
- `brain`: آزمایش‌های آفلاین (embedding و مدل کوچک) به‌همراه مجموعه‌های ارزیابی (`brain/eval/`) و استاندارد طلایی برابری پایتون↔دارت (`parity_expected.json`). اپ فقط `assets/brain/intent_model.json` را می‌خواند.

## ساخت و آزمایش

پایتون فقط در زمان ساخت و آزمایش استفاده می‌شود، نه در اجرای اپ.

    python tools/go.py "پیام"     # commit، push، انتظار برای تست، چاپ گزارش کوتاه
    python tools/go.py report     # دوباره چاپ گزارش آخر
    bash tools/build.sh           # ساخت APK امضاشده و دانلود (نیاز به gh)
    python tools/check.py all     # اعتبارسنجی یکپارچهٔ داده/دارایی/متادیتا/مدل نیت/برابری
    python tools/doctor.py        # سلامت‌سنجی و تشخیص وضعیت محیط و گزارش تست

Workflowها در `.github/workflows`:

- `build.yml`: ساخت APK (دستی). با کلید اصلی امضا می‌شود و کلید فقط در Secrets نگهداری می‌شود.
- `test.yml`: بررسی داده‌ها، `flutter analyze` و `flutter test` روی هر push
- `embed.yml` و `train.yml`: آزمایش‌های دستی آفلاین

## قواعد

- متن قوانین فقط از منبع رسمی (سامانهٔ قوانین و مقررات جمهوری اسلامی ایران) کپی شود و منبع و تاریخ ثبت شود.
- تستی که داده را ندارد باید قرمز شود، نه بی‌صدا رد شود.
- فایل کلید (jks) هرگز در گیت نباشد و یک نسخهٔ پشتیبان بیرون از GitHub نگه داشته شود.
- جواب غلط با ظاهر موثق بدتر از «پیدا نشد» است.

## درخواست کمک

    هدف: (یک جمله)
    اتفاق: (خطای دقیق)
    خروجی: python tools/doctor.py ...

# دستیار

دستیار حقوقی آفلاین فارسی برای اندروید (Flutter). پاسخ‌ها از متن قوانینِ داخل برنامه بازیابی می‌شوند، با ذکر منبع و ماده. اگر ماده‌ای پیدا نشود، به‌جای حدس‌زدن همین را می‌گوید. قالب‌های پیش‌نویس (مثل شکوائیهٔ چک) فقط پیش‌نویس‌اند و هنوز بازبینی حقوقی نشده‌اند. برنامه وکیل نیست.

## ساختار

- `lib/main.dart`، `chat_page.dart`، `widgets/chat_bubbles.dart` و صفحه‌های جانبی: رابط کاربری
- `lib/chat_controller.dart`، `chat_models.dart`: کنترلر مستقل وضعیت گفتگو، پیشنهاد قالب، استریم و لغو ایمن پاسخ
- `lib/assistant.dart`، `prompt_builder.dart`، `llm.dart`: هماهنگ‌کنندهٔ پاسخ، نگهبان استناد مواد/قوانین و بک‌اندهای مدل زبانی محلی (`OnDeviceChannelLlm`، `LocalLoopbackLlm` محدود به `127.0.0.1` و `AdaptiveLlm`)
- `lib/router.dart`: تشخیص نیت پرسش (معرفی توانایی‌ها و پیش‌بینی نتیجهٔ دادگاه)
- `lib/engine.dart`، `models.dart`، `services/conflicts_service.dart`: بارگذاری موازی قوانین، نمایهٔ معکوس BM25F، نگهبان حوزه‌های خارج از پوشش، تشخیص زنجیرهٔ تعارض/ارتباط مواد و بازیابی تک‌مرحله‌ای
- `lib/persian_text.dart`، `core/text_utils.dart`: لایهٔ متن فارسی (نرمال‌سازی، تبدیل ارقام، برش ایمن یونیکد، اعتبارسنجی کد ملی و شماره تلفن ایران، ایست‌واژه و ریشه‌یابی)
- `lib/privacy.dart`: رمزنگاری محلی داده‌ها با Android Keystore (`AES-256-GCM`)، کلیپ‌بورد حساس و `FLAG_SECURE`
- `lib/drafting.dart`، `templates.dart`: پیش‌نویس مرحله‌به‌مرحلهٔ اسناد حقوقی با امکان ذخیرهٔ موقت رمزنگاری‌شدهٔ پیش‌نویس ناتمام (`DraftCheckpointStore`)
- `assets/laws`: متن قوانین (در ساختار پوشه‌ای دسته‌بندی‌شده به همراه `_meta.json`). `assets/templates`: قالب‌ها. `assets/synonyms.txt`، `relationships.json`، `replies.json`
- `test`: تست‌های واحد، ویجت و ارزیابی کیفیت بازیابی
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

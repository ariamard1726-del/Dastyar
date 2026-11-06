معماری دستیار

یک صفحه نقشهٔ معماری: لایه‌ها، جریان پرسش، منابع یکتای داده، دروازه‌های CI و تصمیم‌های کلیدی. اپ ۱۰۰٪ آفلاین است؛ هیچ LLM بیرونی یا API شبکه‌ای در مسیر پاسخ وجود ندارد.

لایه‌های lib/

وابستگی فقط رو به پایین است (core ← domain ← ui ← main). هیچ import بالارونده‌ای مجاز نیست.

لایهنقشفایل‌هاlib/core/زیرساخت بدون شناخت از قابلیت‌هاpersian_text (لایهٔ یکتای متن فارسی)، engine + models (نمایهٔ BM25F و بازیابی)، router (نیت‌های ثابت)، conflicts_service، replies، llm (بک‌اندهای محلی)، privacy، debug_logger (ردِ مرحله‌به‌مرحلهٔ نوبت)، history، configlib/domain/قابلیت‌های حقوقیassistant + prompt_builder (تولید و راستی‌آزمایی استناد)، legal_counselor (مشاورهٔ گام‌به‌گام)، intent_net (شبکهٔ نیت)، drafting + templates (پیش‌نویس اسناد)، evaluation/ (دیتاست طلایی + هارنس + گزارش)، feedback، settingslib/ui/نمایش و وضعیت گفتگوchat_page، chat_controller، chat_models، صفحه‌های تنظیمات/تاریخچه/درباره، widgets/chat_bubbles

مسئولیت‌های هم‌پوشان قدیمی روشن شد: router فقط نیت‌های ثابتِ سطح موتور (معرفی توانایی‌ها، پیش‌بینی حکم) را تشخیص می‌دهد؛ intent_net + legal_counselor مسیریابی گفتگوی مشاوره (شروع/ادامه/لغو/RAG) را بر عهده دارند؛ assistant لایهٔ تولید پاسخ (موتور یا مدل محلی) به‌همراه نگهبان استناد است و chat_controller فقط وضعیت رابط کاربری را مدیریت می‌کند.

جریان یک پرسش

کاربر → ChatPage → ChatController.submit → LegalCounselor.step (اگر گفتگوی مشاوره فعال/در جریان باشد: لغو → نیت NN → RAG → intake → اسلات‌ها) → Assistant.askWithAlternatives → KnowledgeEngine.query (نیت ثابت: QueryRouter — توانایی‌ها/پیش‌بینی نتیجه) → rank (BM25F + نمایهٔ معکوس + تعریف/مترادف/مکرر) → EngineReply = پاسخ + جایگزین‌ها + زنجیرهٔ تعارض (ConflictsService) → PromptBuilder + LlmBackend (پیش‌فرض NoLlm → پاسخ موتور) → راستی‌آزمایی: citedArticles + نام قانون + وجود ماده در متن بازیابی‌شده → Drafting (اگر کاربر پیش‌نویس خواست: قالب → فیلدها → اعتبارسنجی → سند) → HistoryStore / FeedbackStore (رمزنگاری‌شده، از طریق PrivacyService) 

منابع یکتای داده

دادهمنبع یکتامشتق‌ها / مصرف‌کننده‌هامتادیتای قوانینassets/laws/_meta.jsonlaws_catalog.json (عنوان‌ها) و data_info.json (lawsUpdated) با tools/sync_meta.py --write مشتق می‌شوند؛ tools/check.py meta تازگی مشتق‌ها را در CI می‌سنجدروابط/تضاد موادassets/relationships.jsonدارت: core/conflicts_service.dart؛ پایتون: brain/engine.py (کپی محلی حذف شد)مدل نیتassets/brain/intent_model.jsonدارت: domain/intent_net.dart؛ آینهٔ پایتون: tools/check.py intentپاسخ‌های ثابتassets/replies.jsoncore/replies.dartمجموعه‌های ارزیابیbrain/eval/*.txtهمهٔ ابزارهای ارزیابی و تست‌ها از همین شاخه می‌خوانند

برابری پایتون ↔ دارت (دو موتور موازی)

آینهٔ پایتون (tools/eval_py.py، brain/common.py، brain/engine.py) برای ارزیابی سریع آفلاین است و باید دقیقاً هم‌رفتار موتور دارت بماند. مکانیزم تضمین، دو طرفه است:

tools/parity.py --write خروجی سمت پایتون (لایهٔ متن، زنجیرهٔ تضادها، top-3 رتبه‌بندی برای brain/eval/eval.txt) را در brain/parity_expected.json ثبت می‌کند.tools/check.py parity (دروازهٔ داده در CI) تازگی آن فایل را نسبت به پایتونِ روز می‌سنجد.test/core/parity_test.dart همان ورودی‌ها را به دارت می‌دهد و خروجی دقیقاً یکسان می‌خواهد.

نتیجه: تغییر یکی از دو موتور بدون دیگری ⇒ CI قرمز. اگر تغییر پایتون عمدی است، ابتدا سمت دارت هم‌تراز شود، سپس parity.py --write و پوش.

هزینهٔ استارت‌آپ (تصمیم آگاهانه)

متن قوانین .txt است و یک بار در KnowledgeEngine.load() پارس می‌شود؛ ساخت نمایه (توکن‌سازی، جدول‌های TF، وارونه) کامل در Isolate جدا اجرا می‌شود (Isolate.run) تا UI هرگز مسدود نشود. ایندکس از پیش ساختهٔ داخل assets عمداً اضافه نشده است: هزینهٔ غالبِ بارگذاری، ساخت جدول‌های فرکانس واژه از متن است نه پارس ساختاری؛ هر ایندکس asset یا متن را دوباره حمل می‌کند (~۳٫۵ مگابایت اضافه در APK بدون صرفهٔ محسوس) یا باید جدول‌های TF را سریال کند (چند برابر بدتر). به‌جای آن، test/engine/load_budget_test.dart سقف زمانی و حداقل تعداد بخش‌ها را در CI نگهبانی می‌کند تا رشد داده یا رگرسیون الگوریتمی بی‌صدا نماند. اگر روزی لازم شد، مسیر درست «بارگذاری تنبل به‌تفکیک حوزه» است، نه ایندکس سنگین در assets.

دروازه‌های CI (.github/workflows/test.yml)

داده: tools/check.py all (corpus، assets، meta+تازگی مشتق‌ها، intent، parity) + doctor.py + eval_py.py --check + eval_none.py --checkتحلیل: flutter analyze --fatal-warningsتست: flutter test (شاخه‌های test/core|engine|drafting|counselor|app)؛ گزارش در reports/last_test.txt ثبت می‌شودگزارش near-miss: test/engine/near_miss_test.dart → brain/reports/near_miss.txt

build.yml قبل از ساخت APK همان زنجیرهٔ داده را اجرا می‌کند و امضای انتشار با tools/setup_release_signing.py از Secrets پیکربندی می‌شود.


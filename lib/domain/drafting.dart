// پیش‌نویس‌ها: یک سرِ کتابخانه، پنج صاحب.
//
// تا وقتی همه در یک فایلِ ۶۵۸ خطی بودند، عوض کردنِ یک جمله در پرسشِ فیلد، کلِ
// تشخیصِ قالب و اعتبارسنجیِ عدد را در همان صفحه می‌آورد. حالا:
//
//  • `draft_models.dart` — داده: نشست، پاسخ، متنِ قانون، نتیجهٔ تشخیص.
//  • `draft_words.dart`  — واژه‌های آماده و یکسان‌سازیِ متن.
//  • `draft_intent.dart` — کدام قالب به حرفِ کاربر می‌خورد.
//  • `draft_step.dart`   — پرسشِ فیلدها و ساختنِ متن.
//  • `draft_laws.dart`   — موادِ قانونیِ ارجاع‌شده.
//
// این فایل فقط `export` می‌کند تا هجده فایلی که امروز `drafting.dart` را وارد
// می‌کنند بی‌تغییر بمانند؛ خودِ نام‌فضایِ `Drafting` حذف شده است.

export 'draft_models.dart';
export 'draft_words.dart';
export 'draft_intent.dart';
export 'draft_step.dart';
export 'draft_laws.dart';

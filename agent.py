import os
import re
import subprocess
from google import genai

# ۱. تنظیمات اولیه
api_key = os.environ.get("GEMINI_API_KEY")
comment_body = os.environ.get("COMMENT_BODY", "")
client = genai.Client(api_key=api_key)

# اگر کامنت کلمه "همه" یا "کل" یا "all" داشت، کل پروژه بررسی شود
# در غیر این صورت، فقط فایل مشخص شده را بررسی می‌کند (مثل قبل)
check_all = any(word in comment_body.lower() for word in ["همه", "کل", "all", "project"])

if check_all:
    print("🔍 درخواست بررسی کل پروژه دریافت شد. در حال اجرای Flutter Analyze...")
    # اجرای ابزار تحلیل فلاتر برای پیدا کردن خطاها
    result = subprocess.run(["flutter", "analyze"], capture_output=True, text=True)
    analyze_output = result.stdout + result.stderr
    
    if not analyze_output.strip() or "No issues found!" in analyze_output:
        print("✅ هیچ خطایی در پروژه پیدا نشد!")
        exit(0)

    # استخراج نام فایل‌هایی که خطا دارند
    # خروجی فلاتر معمولاً به شکل "error • message • lib/main.dart:10:5 • error_code" است
    error_files = set(re.findall(r'([\w\-\./]+\.dart):\d+:\d+', analyze_output))
    
    print(f"🚨 خطا در {len(error_files)} فایل پیدا شد: {error_files}")

    for file in error_files:
        if os.path.exists(file):
            with open(file, 'r', encoding='utf-8') as f:
                code = f.read()
            
            prompt = f"""تو یک متخصص فلاتر (Flutter) هستی.
من یک فایل از پروژه را به همراه خطاهای آن برایت می‌فرستم.
خطاهای گزارش شده توسط فلاتر:
{analyze_output}

کد فایل {file}:
```dart
{code}
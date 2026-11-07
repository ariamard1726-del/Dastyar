import os
import re
import subprocess
import time
from google import genai

# ۱. تنظیمات اولیه
api_key = os.environ.get("GEMINI_API_KEY")
comment_body = os.environ.get("COMMENT_BODY", "")
client = genai.Client(api_key=api_key)

def ask_gemini(prompt_text):
    """تابع کمکی برای ارتباط با جمنای با قابلیت تلاش مجدد"""
    models_to_try = ['gemini-3.1-flash-lite', 'gemini-3.5-flash-lite']
    for model_name in models_to_try:
        for attempt in range(3):
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt_text,
                )
                # پاک کردن بلاک مارک‌داون در صورت وجود
                text = response.text
                if text.startswith("```"): text = "\n".join(text.split("\n")[1:])
                if text.endswith("```"): text = "\n".join(text.split("\n")[:-1])
                return text.strip()
            except Exception as e:
                print(f"خطا در مدل {model_name} (تلاش {attempt+1}): {e}")
                if "503" in str(e) or "UNAVAILABLE" in str(e):
                    time.sleep(5)
                else:
                    break 
    return None

# بررسی اینکه آیا کاربر درخواست بررسی کل پروژه را داده است یا خیر
check_all = any(word in comment_body.lower() for word in ["همه", "کل", "all", "project"])

if check_all:
    print("🔍 درخواست بررسی کل پروژه دریافت شد. در حال اجرای Flutter Analyze...")
    result = subprocess.run(["flutter", "analyze"], capture_output=True, text=True)
    analyze_output = result.stdout + result.stderr

    if not analyze_output.strip() or "No issues found!" in analyze_output:
        print("✅ هیچ خطایی در پروژه پیدا نشد!")
        exit(0)

    # استخراج نام فایل‌هایی که خطا دارند
    error_files = set(re.findall(r'([\w\-\./]+\.dart):\d+:\d+', analyze_output))
    print(f"🚨 خطا در {len(error_files)} فایل پیدا شد.")

    for file in error_files:
        if os.path.exists(file):
            with open(file, 'r', encoding='utf-8') as f:
                code = f.read()

            prompt = f"""تو یک متخصص فلاتر (Flutter) هستی.
خطاهای گزارش شده توسط فلاتر:
{analyze_output}

کد فایل {file}:
```dart
{code}
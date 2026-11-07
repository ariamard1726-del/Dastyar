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

            # حذف علامت‌های بک‌تیک برای جلوگیری از تداخل
            prompt = f"""تو یک متخصص فلاتر (Flutter) هستی.
خطاهای گزارش شده توسط فلاتر:
{analyze_output}

کد فایل {file}:
{code}

لطفا این فایل را اصلاح کن تا خطاها برطرف شوند. 
بسیار مهم: فقط و فقط کد نهایی را برگردان. هیچ توضیح اضافه‌ای ننویس و کد را داخل بلاک مارک‌داون قرار نده.
"""
            new_code = ask_gemini(prompt)
            if new_code:
                with open(file, 'w', encoding='utf-8') as f:
                    f.write(new_code)
                print(f"✅ فایل {file} اصلاح شد.")

else:
    # حالت اصلاح تک‌فایل
    file_match = re.search(r'([\w\-\./]+\.(?:dart|py|js|txt|md|yaml))', comment_body)
    if not file_match:
        print("خطا: نام فایلی برای اصلاح مشخص نشده است. (مثلا: fix pubspec.yaml)")
        exit(0)
    
    target_file = file_match.group(1)
    if not os.path.exists(target_file):
        print(f"خطا: فایل {target_file} در پروژه پیدا نشد.")
        exit(0)

    with open(target_file, 'r', encoding='utf-8') as f:
        original_code = f.read()

    print(f"فایل {target_file} خوانده شد. در حال ارسال به جمنای...")
    prompt = f"""تو یک برنامه‌نویس ارشد هستی. کد فعلی فایل {target_file}:
{original_code}

درخواست کاربر: {comment_body}

لطفا کد را اصلاح کن. بسیار مهم: فقط و فقط کد نهایی را برگردان. هیچ توضیح اضافه‌ای ننویس و کد را داخل بلاک مارک‌داون قرار نده.
"""
    new_code = ask_gemini(prompt)
    if new_code:
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(new_code)
        print(f"✅ فایل {target_file} با موفقیت اصلاح شد.")
    else:
        print("متاسفانه جمنای پاسخی برنگرداند.")
        exit(1)
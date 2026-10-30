import os
import json

PROJECT_NAME = "Dastyar"

def setup_project():
    base_dir = os.path.expanduser(f"~/{PROJECT_NAME}")
    os.makedirs(base_dir, exist_ok=True)
    os.chdir(base_dir)

    files_to_check = {
        "relationships.json": {
            "articles": {
                "101": {"title": "ماده ۱۰۱", "conflicts_with": ["105"]},
                "105": {"title": "ماده ۱۰۵", "conflicts_with": ["108"]}
            }
        },
        "reasoner.py": "# کد منطق برنامه Dastyar را اینجا کپی کنید\n"
    }

    print(f"🔍 در حال بررسی سلامت پروژه {PROJECT_NAME}...")

    for filename, default_content in files_to_check.items():
        if not os.path.exists(filename):
            print(f"⚠️ فایل {filename} یافت نشد. در حال ساخت...")
            try:
                with open(filename, 'w', encoding='utf-8') as f:
                    if filename.endswith('.json'):
                        json.dump(default_content, f, indent=4, ensure_ascii=False)
                    else:
                        f.write(default_content)
                print(f"✅ فایل {filename} با موفقیت ساخته شد.")
            except Exception as e:
                print(f"❌ خطا در ساخت {filename}: {e}")
        else:
            print(f"✅ فایل {filename} موجود است.")

    print(f"\n📁 مسیر پروژه: {base_dir}")
    print("پایان بررسی. پروژه آماده اجراست.")

if __name__ == "__main__":
    setup_project()

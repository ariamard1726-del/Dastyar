import json
import os

def check_project():
    print("🔍 در حال بررسی سلامت پروژه...")
    
    files_needed = ['relationships.json', 'reasoner.py', 'relations.py']
    all_ok = True

    # ۱. بررسی وجود فایل‌ها
    for filename in files_needed:
        if not os.path.exists(filename):
            print(f"❌ خطا: فایل '{filename}' پیدا نشد.")
            all_ok = False
        else:
            print(f"✅ فایل '{filename}' موجود است.")

    # ۲. بررسی صحت فرمت JSON در relationships.json
    if os.path.exists('relationships.json'):
        try:
            with open('relationships.json', 'r', encoding='utf-8') as f:
                json.load(f)
            print("✅ فایل 'relationships.json' معتبر است.")
        except json.JSONDecodeError as e:
            print(f"❌ خطا: فایل 'relationships.json' دارای فرمت JSON اشتباه است.")
            print(f"   جزئیات خطا: {e}")
            all_ok = False

    if all_ok:
        print("\n🎉 همه چیز مرتب است! پروژه آماده اجراست.")
    else:
        print("\n⚠️ پروژه دارای مشکلاتی است. لطفاً موارد بالا را برطرف کنید.")

if __name__ == "__main__":
    check_project()


import json, os, re, glob

def check_meta():
    print("🔍 1. بررسی مسیرهای _meta.json...")
    try:
        with open('assets/laws/_meta.json', 'r', encoding='utf-8') as f:
            meta = json.load(f)
        for key, data in meta.items():
            path = data.get('path')
            if not path:
                print(f"  ❌ {key}: فیلد path ندارد.")
                continue
            full_path = os.path.join('assets/laws', path)
            if not os.path.exists(full_path):
                print(f"  ❌ {key}: فایل در مسیر {full_path} پیدا نشد!")
            else:
                print(f"  ✅ {key}: مسیر درست است.")
    except Exception as e:
        print(f"  ❌ خطا در خواندن _meta.json: {e}")

def check_engine():
    print("\n🔍 2. بررسی کد engine.dart...")
    try:
        with open('lib/engine.dart', 'r', encoding='utf-8') as f:
            code = f.read()
        if 'relPath' in code and 'meta.entries.where' in code:
            print("  ✅ کد جدید (relPath) در engine.dart وجود دارد.")
        else:
            print("  ❌ کد جدید در engine.dart اعمال نشده است!")
    except Exception as e:
        print(f"  ❌ خطا در خواندن engine.dart: {e}")

def check_pubspec():
    print("\n🔍 3. بررسی pubspec.yaml...")
    try:
        with open('pubspec.yaml', 'r', encoding='utf-8') as f:
            content = f.read()
        if '- assets/laws/' in content:
            print("  ✅ مسیر assets/laws/ ثبت شده است.")
        else:
            print("  ❌ مسیر assets/laws/ در pubspec.yaml وجود ندارد!")
    except Exception as e:
        print(f"  ❌ خطا در خواندن pubspec.yaml: {e}")

def check_workflows():
    print("\n🔍 4. بررسی تنظیمات GitHub Actions...")
    workflows = glob.glob('.github/workflows/*.yml') + glob.glob('.github/workflows/*.yaml')
    if not workflows:
        print("  ⚠️ هیچ فایل ورک‌فلویی پیدا نشد.")
        return
    for wf in workflows:
        print(f"  📄 فایل: {wf}")
        with open(wf, 'r', encoding='utf-8') as f:
            content = f.read()
        if 'flutter test' in content: print("     - دستور flutter test دارد.")
        if 'flutter build' in content: print("     - دستور flutter build دارد.")
        if 'flutter clean' in content:
            print("     - دستور flutter clean دارد (عالی).")
        else:
            print("     ⚠️ دستور flutter clean ندارد! (احتمال خطای کش)")

if __name__ == "__main__":
    print("🚀 شروع بررسی خطاها...\n")
    check_meta()
    check_engine()
    check_pubspec()
    check_workflows()
    print("\n✅ بررسی به پایان رسید.")

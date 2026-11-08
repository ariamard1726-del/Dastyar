import os import re import subprocess import time from pathlib import Path

from google import genai

============================== تنظیمات ============================== 

API_KEY = os.environ.get("GEMINI_API_KEY") COMMENT_BODY = os.environ.get("COMMENT_BODY", "").strip()

حداکثر تعداد مراحل برای جلوگیری از حلقه بی‌نهایت 

MAX_AGENT_STEPS = 5

MODELS_TO_TRY = [ "gemini-3.1-flash-lite", "gemini-3.5-flash-lite", ]

============================== ابزارهای سیستم ============================== 

def run_command(command, timeout=300): """اجرای یک دستور و برگرداندن کد خروج و خروجی کامل.""" try: result = subprocess.run( command, capture_output=True, text=True, timeout=timeout, ) return result.returncode, result.stdout + result.stderr

except subprocess.TimeoutExpired: return 1, f"زمان اجرای دستور تمام شد: {' '.join(command)}" except Exception as error: return 1, str(error) 

def run_flutter_analyze(): """اجرای Flutter Analyze.""" print("\n🔍 در حال اجرای flutter analyze...")

return_code, output = run_command( ["flutter", "analyze"], timeout=300, ) if return_code == 0 or "No issues found!" in output: return True, output return False, output ============================== ارتباط با Gemini ============================== 

def get_gemini_client(): """ساخت Gemini Client.""" if not API_KEY: raise RuntimeError( "متغیر محیطی GEMINI_API_KEY تنظیم نشده است." )

return genai.Client(api_key=API_KEY) 

def ask_gemini(prompt_text): """ارسال درخواست به Gemini با تلاش مجدد."""

client = get_gemini_client() for model_name in MODELS_TO_TRY: for attempt in range(3): try: print( f"🤖 استفاده از مدل: {model_name} " f"(تلاش {attempt + 1}/3)" ) response = client.models.generate_content( model=model_name, contents=prompt_text, ) text = (response.text or "").strip() # حذف احتمالی Markdown code fence if text.startswith("```"): lines = text.splitlines() # حذف خط اول ``` یا ```language lines = lines[1:] # حذف ``` انتهایی if lines and lines[-1].strip() == "```": lines = lines[:-1] text = "\n".join(lines).strip() if text: print(f"✅ پاسخ موفق از مدل: {model_name}") return text except Exception as error: print( f"⚠️ خطا در مدل {model_name} " f"(تلاش {attempt + 1}/3): {error}" ) error_text = str(error).upper() temporary_error = any( value in error_text for value in ( "503", "UNAVAILABLE", "RATE_LIMIT", "429", ) ) if temporary_error: time.sleep(5 * (attempt + 1)) else: break return None ============================== اصلاح فایل ============================== 

def fix_file(file_path, errors, user_request=""): """ارسال یک فایل به Gemini و اعمال اصلاح پیشنهادی."""

path = Path(file_path) if not path.exists() or not path.is_file(): print(f"❌ فایل پیدا نشد: {file_path}") return False try: original_code = path.read_text(encoding="utf-8") except Exception as error: print(f"❌ خطا در خواندن {file_path}: {error}") return False print(f"\n🛠️ در حال بررسی فایل: {file_path}") prompt = f""" 

تو یک مهندس ارشد Flutter و متخصص رفع خطا هستی.

وظیفه تو فقط اصلاح فایل زیر است.

نام فایل: {file_path}

خطاهای گزارش‌شده از flutter analyze: {errors}

درخواست کاربر: {user_request}

کد فعلی فایل: --- شروع کد --- {original_code} --- پایان کد ---

قوانین بسیار مهم:

فقط همین فایل را اصلاح کن.

تغییرات غیرضروری انجام نده.

ساختار پروژه را تغییر نده.

فقط کد کامل و نهایی همین فایل را برگردان.

هیچ توضیحی ننویس.

از Markdown و ``` استفاده نکن. """

new_code = ask_gemini(prompt)

if not new_code: print(f"❌ Gemini پاسخی برای {file_path} نداد.") return False

جلوگیری از نوشتن پاسخ‌های بسیار کوتاه 

if len(new_code) < 10: print( "⚠️ پاسخ Gemini مشکوک است و در فایل نوشته نشد." ) return False

ایجاد نسخه پشتیبان محلی 

backup_path = Path(f"{file_path}.agent_backup")

try: backup_path.write_text( original_code, encoding="utf-8", )

path.write_text( new_code, encoding="utf-8", ) print(f"✅ تغییر در فایل اعمال شد: {file_path}") return True 

except Exception as error: print(f"❌ خطا در نوشتن فایل: {error}")

# تلاش برای بازگردانی فایل اصلی try: path.write_text( original_code, encoding="utf-8", ) except Exception: pass return False ============================== ایجنت خودمختار ============================== 

def extract_error_files(analyze_output): """استخراج نام فایل‌های Dart از خروجی flutter analyze."""

patterns = [ r"([\w./-]+\.dart):\d+:\d+", r"([\w./-]+\.dart)\s+\d+:\d+", ] files = [] for pattern in patterns: files.extend( re.findall( pattern, analyze_output, ) ) # حذف تکراری‌ها با حفظ ترتیب return list(dict.fromkeys(files)) 

def autonomous_agent(user_goal): """ چرخه ایجنت: Analyze -> پیدا کردن فایل خطادار -> اصلاح -> Analyze مجدد """

print("\n🤖 حالت ایجنت خودمختار فعال شد.") print( f"🎯 هدف: {user_goal or 'رفع خطاهای پروژه'}" ) for step in range(1, MAX_AGENT_STEPS + 1): print("\n" + "=" * 50) print( f"🤖 مرحله خودمختار " f"{step}/{MAX_AGENT_STEPS}" ) print("=" * 50) success, analyze_output = run_flutter_analyze() if success: print("\n🎉 بررسی پروژه با موفقیت انجام شد.") print( "✅ هیچ خطایی در Flutter Analyze باقی نمانده است." ) return True error_files = extract_error_files(analyze_output) if not error_files: print( "⚠️ فایل مشخصی از خروجی Analyze استخراج نشد." ) print(analyze_output[-3000:]) return False print( f"🚨 تعداد فایل‌های دارای خطا: " f"{len(error_files)}" ) # در هر مرحله فقط اولین فایل اصلاح می‌شود، # سپس Analyze دوباره اجرا خواهد شد. target_file = error_files[0] print( f"🎯 انتخاب فایل برای اصلاح: {target_file}" ) fixed = fix_file( target_file, analyze_output, user_goal, ) if not fixed: print("⚠️ اصلاح فایل ناموفق بود.") return False # جلوگیری از ارسال درخواست‌های بسیار سریع time.sleep(2) print( f"\n⚠️ ایجنت پس از " f"{MAX_AGENT_STEPS} مرحله متوقف شد." ) print( "تغییرات ایجادشده را با دستور زیر بررسی کنید:" ) print("git diff") return False ============================== حالت اصلاح تک‌فایل ============================== 

def single_file_mode(comment_body): """اصلاح یک فایل که نام آن در درخواست کاربر آمده است."""

file_match = re.search( r"([\w./-]+\.(?:dart|py|js|ts|txt|md|yaml|yml))", comment_body, re.IGNORECASE, ) if not file_match: print( "❌ نام فایل مشخص نشده است.\n" "مثال: fix lib/main.dart" ) return False target_file = file_match.group(1) return fix_file( target_file, "", comment_body, ) ============================== نقطه شروع برنامه ============================== 

if name == "main": print("🚀 GEMINI AUTONOMOUS AGENT STARTED")

if COMMENT_BODY: print(f"📝 COMMENT_BODY: {COMMENT_BODY}") else: print("📝 COMMENT_BODY خالی است.") autonomous_keywords = [ "agent", "autonomous", "خودمختار", "بررسی همه", "بررسی کل", "fix all", "analyze project", "اصلاح", ] is_autonomous = any( keyword.lower() in COMMENT_BODY.lower() for keyword in autonomous_keywords ) print(f"🤖 Autonomous mode: {is_autonomous}") if is_autonomous: success = autonomous_agent(COMMENT_BODY) else: success = single_file_mode(COMMENT_BODY) raise SystemExit(0 if success else 1) 
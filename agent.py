import os import re import subprocess import time from pathlib import Path from google import genai

============================== تنظیمات ============================== 

API_KEY = os.environ.get("GEMINI_API_KEY") COMMENT_BODY = os.environ.get("COMMENT_BODY", "").strip()

حداکثر تعداد تلاش Agent برای جلوگیری از حلقه بی‌نهایت 

MAX_AGENT_STEPS = 5

MODELS_TO_TRY = [ "gemini-3.1-flash-lite", "gemini-3.5-flash-lite", ]

if not API_KEY: raise RuntimeError("متغیر محیطی GEMINI_API_KEY تنظیم نشده است.")

client = genai.Client(api_key=API_KEY)

============================== ابزارهای سیستم ============================== 

def run_command(command): """اجرای یک دستور و برگرداندن خروجی کامل""" try: result = subprocess.run( command, capture_output=True, text=True, timeout=120 ) return result.returncode, result.stdout + result.stderr except Exception as e: return 1, str(e)

def run_flutter_analyze(): """اجرای Flutter Analyze""" print("\n🔍 در حال اجرای flutter analyze...")

returncode, output = run_command(["flutter", "analyze"]) if "No issues found!" in output: return True, output return False, output 

def get_git_status(): """بررسی تغییرات Git""" _, output = run_command(["git", "status", "--short"]) return output.strip()

============================== ارتباط با Gemini ============================== 

def ask_gemini(prompt_text): """ارسال درخواست به Gemini با تلاش مجدد"""

for model_name in MODELS_TO_TRY: for attempt in range(3): try: print( f"🤖 استفاده از مدل: {model_name} " f"(تلاش {attempt + 1})" ) response = client.models.generate_content( model=model_name, contents=prompt_text, ) text = response.text or "" # حذف Markdown code fence text = text.strip() if text.startswith("```"): lines = text.splitlines() lines = lines[1:] if lines and lines[-1].strip() == "```": lines = lines[:-1] text = "\n".join(lines) if text.strip(): print(f"✅ پاسخ موفق از مدل: {model_name}") return text.strip() except Exception as e: print( f"⚠️ خطا در {model_name} " f"(تلاش {attempt + 1}): {e}" ) error_text = str(e).upper() if ( "503" in error_text or "UNAVAILABLE" in error_text or "RATE_LIMIT" in error_text or "429" in error_text ): time.sleep(5 * (attempt + 1)) else: break return None ============================== اصلاح فایل ============================== 

def extract_code_response(response): """پاک‌سازی ساده پاسخ مدل""" if not response: return None

return response.strip() 

def fix_file(file_path, errors, user_request=""): """ارسال یک فایل به Gemini و اعمال اصلاح"""

path = Path(file_path) if not path.exists() or not path.is_file(): print(f"❌ فایل پیدا نشد: {file_path}") return False try: original_code = path.read_text(encoding="utf-8") except Exception as e: print(f"❌ خطا در خواندن {file_path}: {e}") return False print(f"\n🛠️ در حال بررسی فایل: {file_path}") prompt = f""" 

تو یک مهندس ارشد Flutter و متخصص رفع خطا هستی.

وظیفه تو فقط اصلاح فایل زیر است:

نام فایل: {file_path}

خطاهای مربوط به پروژه: {errors}

درخواست کاربر: {user_request}

کد فعلی فایل: --- شروع کد --- {original_code} --- پایان کد ---

قوانین بسیار مهم:

فقط همین فایل را اصلاح کن.

تغییرات غیرضروری انجام نده.

ساختار پروژه را تغییر نده.

فقط کد نهایی کامل فایل را برگردان.

هیچ توضیحی ننویس.

از Markdown و ``` استفاده نکن. """

response = ask_gemini(prompt) new_code = extract_code_response(response)

if not new_code: print(f"❌ Gemini پاسخی برای {file_path} نداد.") return False

جلوگیری از نوشتن پاسخ‌های بسیار کوتاه و مشکوک 

if len(new_code) < 10: print("⚠️ پاسخ Gemini مشکوک است و نوشته نشد.") return False

Backup موقت 

backup_path = Path(f"{file_path}.agent_backup")

try: backup_path.write_text(original_code, encoding="utf-8") path.write_text(new_code, encoding="utf-8")

print(f"✅ تغییر در فایل اعمال شد: {file_path}") return True 

except Exception as e: print(f"❌ خطا در نوشتن فایل: {e}")

# تلاش برای بازگردانی فایل try: path.write_text(original_code, encoding="utf-8") except Exception: pass return False ============================== Agent خودمختار ============================== 

def autonomous_agent(user_goal): """ ایجنت خودمختار: Analyze -> انتخاب فایل‌های دارای خطا -> اصلاح -> Analyze مجدد """

print("\n🤖 حالت ایجنت خودمختار فعال شد.") print(f"🎯 هدف: {user_goal or 'رفع خطاهای پروژه'}") initial_git_status = get_git_status() for step in range(1, MAX_AGENT_STEPS + 1): print("\n" + "=" * 50) print(f"🤖 مرحله خودمختار {step}/{MAX_AGENT_STEPS}") print("=" * 50) success, analyze_output = run_flutter_analyze() if success: print("\n🎉 ایجنت با موفقیت پروژه را بررسی کرد.") print("✅ هیچ خطایی در Flutter Analyze باقی نمانده است.") return True # استخراج فایل‌های Dart دارای خطا error_files = list( dict.fromkeys( re.findall( r"([\w\-.\/]+\.dart):\d+:\d+", analyze_output ) ) ) if not error_files: print("⚠️ فایل مشخصی از خروجی Analyze استخراج نشد.") print(analyze_output[-3000:]) return False print( f"🚨 تعداد فایل‌های دارای خطا: {len(error_files)}" ) # در هر مرحله فقط اولین فایل را اصلاح می‌کنیم # سپس دوباره Analyze اجرا می‌شود. target_file = error_files[0] print(f"🎯 انتخاب فایل برای اصلاح: {target_file}") fixed = fix_file( target_file, analyze_output, user_goal ) if not fixed: print("⚠️ اصلاح فایل ناموفق بود.") return False # کمی مکث برای جلوگیری از درخواست‌های سریع API time.sleep(2) print( f"\n⚠️ Agent پس از {MAX_AGENT_STEPS} مرحله متوقف شد." ) print("تغییرات ایجاد شده را با Git بررسی کنید:") print("git diff") return False ============================== اجرای حالت تک‌فایل ============================== 

def single_file_mode(comment_body):

file_match = re.search( r"([\w\-.\/]+\.(?:dart|py|js|txt|md|yaml|yml))", comment_body, re.IGNORECASE ) if not file_match: print( "❌ نام فایل مشخص نشده است.\n" "مثال: fix lib/main.dart" ) return False target_file = file_match.group(1) return fix_file( target_file, "", comment_body ) ============================== نقطه شروع ============================== 

if name == "main":

autonomous_keywords = [ "agent", "autonomous", "خودمختار", "بررسی همه", "بررسی کل", "fix all", "analyze project", ] is_autonomous = any( keyword.lower() in COMMENT_BODY.lower() for keyword in autonomous_keywords ) if is_autonomous: autonomous_agent(COMMENT_BODY) else: single_file_mode(COMMENT_BODY) 
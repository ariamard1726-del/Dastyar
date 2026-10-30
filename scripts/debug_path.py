import os

# مسیر فایل فعلی
current_dir = os.path.dirname(os.path.abspath(__file__))
data_path = os.path.join(current_dir, 'data', 'relationships.json')

print(f"مسیر فعلی فایل: {current_dir}")
print(f"مسیر مورد انتظار برای فایل: {data_path}")
print(f"آیا فایل وجود دارد؟ {os.path.exists(data_path)}")


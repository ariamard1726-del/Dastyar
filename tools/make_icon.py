import os

from PIL import Image, ImageDraw

S = 512
img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle((0, 0, S - 1, S - 1), radius=110, fill=(201, 100, 66, 255))
w = (255, 255, 255, 255)

d.ellipse((236, 96, 276, 136), fill=w)
d.rectangle((246, 130, 266, 400), fill=w)
d.rounded_rectangle((170, 392, 342, 420), radius=10, fill=w)
d.rounded_rectangle((110, 140, 402, 160), radius=10, fill=w)
for cx in (130, 382):
    d.line((cx, 150, cx - 45, 290), fill=w, width=8)
    d.line((cx, 150, cx + 45, 290), fill=w, width=8)
    d.pieslice((cx - 60, 230, cx + 60, 350), 0, 180, fill=w)

sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
res = os.path.join('android', 'app', 'src', 'main', 'res')
for name, px in sizes.items():
    folder = os.path.join(res, 'mipmap-' + name)
    os.makedirs(folder, exist_ok=True)
    img.resize((px, px), Image.LANCZOS).save(os.path.join(folder, 'ic_launcher.png'))

# آیکن تطبیقی پیش‌فرض (اگر باشد) را حذف می‌کنیم تا همین آیکن استفاده شود
for root, _dirs, files in os.walk(res):
    if os.path.basename(root).startswith('mipmap-anydpi'):
        for f in files:
            if f.startswith('ic_launcher') and f.endswith('.xml'):
                os.remove(os.path.join(root, f))

print('icon ok')

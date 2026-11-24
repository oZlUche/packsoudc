from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

p = Path(__file__).resolve().parent.parent
im = Image.new("RGB", (1200, 830), "#f4eddc")
d = ImageDraw.Draw(im)


def font(n):
    return ImageFont.truetype("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", n, index=2)


def txt(x, y, s, n=16):
    d.text((x, y), s, font=font(n), fill="#3f372b")


txt(26, 14, "边境集市    /    场地与镜头", 29)
txt(25, 65, "平面图   ·   北 ↑", 19)


def pt(x, y):
    return 310 + x * 15, 170 - y * 6.9


def zone(x, y, w, h, col):
    a, b = pt(x - w / 2, y + h / 2)
    c, e = pt(x + w / 2, y - h / 2)
    d.rectangle((a, b, c, e), fill=col)


d.polygon(
    [pt(-1, -22), pt(2.525, 8), pt(2.525, 17), pt(5.875, 17), pt(5.875, 8), pt(2.4, -22)],
    fill="#e2bf86",
)
for x, w in [(-8, 20.4), (13.2, 13.6)]:
    zone(x, 11, w, 0.8, "#806448")
for x in [-2.05, 10.38]:
    zone(x, 11, 2.3, 2.5, "#915e42")
for x, y in [(-10, 0), (-8, 5), (11, 2), (-4.1, 3), (7.55, 6.9)]:
    zone(x, y, 3.5, 2.5, "#999675")
for x in [-6, 7]:
    zone(x, -7, 2.8, 2, "#ae7049")
for x in [-18, 18]:
    d.line([pt(0, -22), pt(x, 11)], fill="#79949c", width=2)
txt(310, 320, "机位  (0, −22, 4.2 m)", 15)
txt(39, 353, "门净宽 4.40 m　·　路宽 3.35 m　·　道路与门洞共享中心线", 16)
source = Image.open(p / "01-original.jpg")
source.thumbnail((555, 312))
im.paste(source, (620, 71))
txt(620, 389, "原始画幅与构图锚点", 17)
for offset, title, arr in [
    (0, "正视占位 · 朝北", [(-10, 3, 2), (-8, 3, 2), (-2.05, 2, 6), (10.38, 2, 6), (11, 3, 2)]),
    (595, "侧视占位 · 朝西", [(-7, 3, 1.5), (0, 3, 2.4), (5, 3, 2.3), (8, 2.4, 2.2), (11, 2.5, 6)]),
]:
    x0 = 286 + offset
    y0 = 697
    txt(offset + 27, 480, title, 20)
    d.line((offset + 35, y0, offset + 558, y0), fill="#896f4c", width=2)
    for x, w, h in arr:
        xx = x0 + x * 18
        ww = w * 16
        yy = y0 - h * 23
        d.rectangle((xx - ww / 2, yy, xx + ww / 2, y0 - 1), outline="#77674f", width=2)
        d.line(
            [(xx - ww / 2 - 3, yy), (xx, yy - 12), (xx + ww / 2 + 3, yy)], fill="#8e5642", width=2
        )
txt(28, 759, "几何尺寸以场地假设为准；成品镜头保持独立，视线略俯，向右偏转。", 18)
im.save(p / "01-plan.jpg", quality=94)

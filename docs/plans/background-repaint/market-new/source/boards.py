"""Render the market study boards from completed Blender outputs."""

import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent.parent
PAPER = "#f4eddc"
INK = "#37392e"
MUTED = "#686858"
RULE = "#c3b99f"
ACCENT = "#9a4936"
FONT_DIR = Path("/usr/share/fonts/opentype/noto")


def font(size, bold=False):
    weight = "Bold" if bold else "Regular"
    return ImageFont.truetype(str(FONT_DIR / f"NotoSansCJK-{weight}.ttc"), size, index=2)


def title(canvas, title_text):
    draw = ImageDraw.Draw(canvas)
    draw.text((42, 18), title_text, font=font(41, True), fill=INK)
    draw.text(
        (canvas.width - 42, 40), "边境集市  /  场景绘制", font=font(23), fill=MUTED, anchor="ra"
    )
    draw.line((42, 90, canvas.width - 42, 90), fill=RULE, width=2)


def panel(canvas, rect, path, label, note=""):
    x, y, w, h = rect
    d = ImageDraw.Draw(canvas)
    d.rectangle((x, y, x + 5, y + 34), fill=ACCENT)
    d.text((x + 20, y - 6), label, font=font(28, True), fill=INK)
    if note:
        d.text((x + w, y + 3), note, font=font(19), fill=MUTED, anchor="ra")
    y += 49
    with Image.open(path) as src:
        im = ImageOps.contain(src.convert("RGB"), (w, h), Image.Resampling.LANCZOS)
    d.rectangle((x, y, x + w - 1, y + h - 1), fill="#e3ddca")
    canvas.paste(im, (x + (w - im.width) // 2, y + (h - im.height) // 2))


def structure(root):
    b = root / "build"
    with Image.open(b / "03-camera.png") as src:
        camera = src.convert("RGB")
    # A compact key in the upper-left preserves the full camera frame.
    scale = camera.width / 1920
    overlay = Image.new("RGBA", camera.size)
    d = ImageDraw.Draw(overlay)
    xy = lambda x: round(x * scale)
    xy0 = xy(29)
    label = "日光从左上前方斜射"
    typeface = font(max(12, xy(24)), True)
    bbox = d.textbbox((0, 0), label, font=typeface, anchor="lt")
    boxw = bbox[2] + xy(92)
    d.rounded_rectangle((xy0, xy0, xy0 + boxw, xy0 + xy(54)), radius=xy(3), fill=(37, 43, 41, 208))
    d.line(
        [(xy(48), xy(44)), (xy(68), xy(64)), (xy(59), xy(63))], fill="#efc975", width=max(2, xy(3))
    )
    d.line([(xy(68), xy(64)), (xy(67), xy(55))], fill="#efc975", width=max(2, xy(3)))
    d.text((xy(83), xy0 + xy(14)), label, font=typeface, fill="white", anchor="lt")
    camera.paste(overlay, mask=overlay.getchannel("A"))
    camera.save(root / "03-structure.png")
    board = Image.new("RGB", (2200, 1470), PAPER)
    title(board, "三视图与成品镜头")
    panels = [
        ("view-top.png", "俯视", "场地布局"),
        ("03-camera.png", "独立透视镜头", "构图与遮挡"),
        ("view-front.png", "正视", "高度与跨度"),
        ("view-side.png", "侧视", "前后间距"),
    ]
    for i, (filename, label, note) in enumerate(panels):
        panel(
            board, (42 + 1075 * (i % 2), 122 + 660 * (i // 2), 1040, 588), b / filename, label, note
        )
    board.save(root / "views.jpg", quality=93, subsampling=0)


def values(root):
    with Image.open(root / "build/05-light.png") as src:
        src.convert("RGB").convert("L").save(root / "05-values.png")


def gallery(root):
    stage_list = [
        ("01-original.jpg", "原画参照"),
        ("01-plan.jpg", "01  场地设计"),
        ("03-structure.png", "03  结构与镜头"),
        ("05-values.png", "05  黑白明度"),
        ("06-*.png", "06  固有色"),
        ("07-*.png", "07  材质"),
        ("08-*.png", "08  细节"),
        ("09-*.png", "09  最终画面"),
    ]
    board = Image.new("RGB", (2200, 2770), PAPER)
    title(board, "边境集市绘制过程")
    for i, (pattern, label) in enumerate(stage_list):
        files = sorted(root.glob(pattern))
        if len(files) != 1:
            raise ValueError(f"Expected exactly one matching {pattern!r} in {root}, got {files}")
        panel(board, (42 + 1075 * (i % 2), 122 + 660 * (i // 2), 1040, 588), files[0], label)
    board.save(root / "stages.jpg", quality=93, subsampling=0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("action", choices=("3", "5", "gallery"))
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    {"3": structure, "5": values, "gallery": gallery}[args.action](args.root)

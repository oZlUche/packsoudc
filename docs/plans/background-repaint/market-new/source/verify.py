from pathlib import Path
import os, sys, io
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from zipfile import ZipFile
from xml.etree import ElementTree as ET

d = Path(__file__).resolve().parent.parent


def report(n, box):
    with ZipFile(d / (n + ".ora")) as z:
        xml = ET.fromstring(z.read("stack.xml"))
        layers = list(xml.find("stack"))
        layer = lambda el: Image.open(io.BytesIO(z.read(el.attrib["src"]))).convert("RGBA")
        fg = [np.array(layer(el).crop(box))[:, :, 3].max() for el in layers[:-1]]
        land = layer(layers[-1])
        full = Image.open(d / (n + ".png")).convert("RGBA")
        same = np.array_equal(np.array(land.crop(box)), np.array(full.crop(box)))
        return fg, same, land, full


def project(p):
    cam = np.array([0, -22, 4.2])
    f = np.array((0.7, 34, -1.95))
    f = f / np.linalg.norm(f)
    r = np.cross(f, [0, 0, 1])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    v = np.array(p) - cam
    return np.array((960, 540)) + 1920 * 28.25 / 36 * np.array((v @ r, -v @ u)) / (v @ f)


ctr = tuple(project((4.2, 11, 1.45)).astype(int))
box = (ctr[0] - 12, ctr[1] - 12, ctr[0] + 12, ctr[1] + 12)
for n in ["06-color", "07-material", "08-details", "09-final"]:
    fg, same, land, full = report(n, box)
    print(n, box, fg, same)
    assert not any(fg) and same
a, b = [
    np.asarray(Image.open(d / (f + ".png")).convert("RGB"), dtype=float) / 255
    for f in ["08-details", "09-final"]
]
for rgb in [a, b]:
    y = rgb @ np.array([0.2126, 0.7152, 0.0722])
    print(
        "mean, P90-P10, red-blue",
        y.mean(),
        np.percentile(y, 90) - np.percentile(y, 10),
        (rgb[:, :, 0] - rgb[:, :, 2]).mean(),
    )
# Full plate vs isolated land plus a close crop of the aperture.
font = ImageFont.truetype("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", 19, index=2)
out = Image.new("RGB", (1200, 405), "#ede4d1")
draw = ImageDraw.Draw(out)
for i, (im, label) in enumerate([(land, "仅开启连续远景与道路层"), (full, "开启全部图层")]):
    draw.text((i * 600 + 14, 10), label, font=font, fill="#352b22")
    patch = im.crop((790, 310, 1420, 688)).convert("RGB")
    out.paste(patch.resize((600, 360)), (i * 600, 45))
out.save(d / "gate-check.jpg", quality=94)

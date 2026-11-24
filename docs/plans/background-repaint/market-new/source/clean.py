"""Suppress Monte Carlo speckle with an edge-preserving filter on solid pixels."""

from pathlib import Path
import sys
from PIL import Image, ImageFilter
import numpy as np
from scipy.ndimage import minimum_filter

for arg in sys.argv[1:]:
    p = Path(arg)
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im)
    alpha = a[:, :, 3]
    crop = im.getbbox()
    if not crop:
        continue
    tile = im.crop(crop)
    raw = np.asarray(tile.convert("RGB"), dtype="float32")
    med = np.asarray(tile.convert("RGB").filter(ImageFilter.MedianFilter(3)), dtype="float32")
    guide = med.mean(axis=2)
    avg = np.zeros_like(raw)
    wtotal = np.zeros_like(guide)
    pad = np.pad(med, ((3, 3), (3, 3), (0, 0)), mode="edge")
    h, w = guide.shape
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            v = pad[3 + dy : 3 + dy + h, 3 + dx : 3 + dx + w]
            delta = v.mean(axis=2) - guide
            weight = np.exp(-(delta**2) / (2 * 12**2) - (dx * dx + dy * dy) / 8)
            avg += v * weight[:, :, None]
            wtotal += weight
    avg /= wtotal[:, :, None]
    solid = minimum_filter(np.asarray(tile)[:, :, 3], size=3) == 255
    out = np.where(solid[:, :, None], 0.13 * raw + 0.87 * avg, raw)
    clean = Image.fromarray(np.uint8(np.clip(out, 0, 255)))
    clean.putalpha(tile.getchannel("A"))
    im.paste(clean, crop[:2])
    im.save(p)

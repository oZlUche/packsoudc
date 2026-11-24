"""Apply the smithy final grade to an exported RGB or RGBA stage (Pillow, NumPy)."""

import argparse

import numpy as np
from PIL import Image


def grade(image):
    rgba = np.array(image.convert("RGBA"))
    rgb = rgba[:, :, :3] / 255.0
    luma = rgb @ [0.2126, 0.7152, 0.0722]
    value = np.interp(
        luma,
        [0, 0.10, 0.23, 0.40, 0.55, 0.72, 0.86, 1],
        [0.007, 0.047, 0.124, 0.267, 0.455, 0.683, 0.855, 0.992],
    )
    # Taper the warm shift at both ends to retain deep shadows and the flame core.
    warmth = np.clip(luma / 0.22, 0, 1) * np.clip((1 - luma) / 0.15, 0, 1)
    color = value[..., None] + (rgb - luma[..., None]) * 1.04
    color += warmth[..., None] * [0.037, 0.002, -0.040]
    rgba[:, :, :3] = np.rint(np.clip(color, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(rgba).convert("RGBA" if "A" in image.getbands() else "RGB")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input")
    parser.add_argument("output")
    args = parser.parse_args()
    with Image.open(args.input) as image:
        grade(image).save(args.output)

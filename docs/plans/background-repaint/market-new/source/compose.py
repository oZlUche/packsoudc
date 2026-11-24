"""Assemble a market painting and verify its editable OpenRaster stack.

Run with ordinary Python and Pillow, e.g. python source/compose.py 6.
"""

import argparse
import io
from pathlib import Path
import tempfile
from xml.etree import ElementTree as ET
from zipfile import ZipFile, ZIP_STORED

from PIL import Image, ImageChops, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
STAGES = {6: "06-color", 7: "07-material", 8: "08-details", 9: "09-final"}
LAYERS = (
    ("land", "Sky, hills and road"),
    ("gate", "Stockade and gate"),
    ("tents", "Tents and traders"),
    ("cargo", "Cart and goods"),
)
SKY = (146, 194, 221, 255)


def grade(image):
    # Shared affine channel curves preserve coverage at antialiased edges.
    tables = [
        [max(0, min(255, round((v - 128) * 1.065 + 128 + shift))) for v in range(256)]
        for shift in (-2, -6, -12)
    ]
    channels = [channel.point(table) for channel, table in zip(image.split(), tables)]
    result = ImageEnhance.Color(Image.merge("RGB", channels)).enhance(1.24)
    result.putalpha(image.getchannel("A"))
    return result


def png_bytes(image):
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


def write_ora(path, layers, merged):
    w, h = merged.size
    doc = ET.Element("image", {"version": "0.0.3", "w": str(w), "h": str(h), "name": path.stem})
    stack = ET.SubElement(doc, "stack")
    with ZipFile(path, "w", compression=ZIP_STORED) as archive:
        archive.writestr("mimetype", "image/openraster")
        # OpenRaster lists the uppermost layer first.
        for key, name, layer in reversed(layers):
            src = f"data/{key}.png"
            ET.SubElement(
                stack,
                "layer",
                {
                    "src": src,
                    "name": name,
                    "x": "0",
                    "y": "0",
                    "opacity": "1.0",
                    "visibility": "visible",
                    "composite-op": "svg:src-over",
                },
            )
            archive.writestr(src, png_bytes(layer))
        archive.writestr("stack.xml", ET.tostring(doc, encoding="utf-8", xml_declaration=True))
        archive.writestr("mergedimage.png", png_bytes(merged))
        thumb = merged.copy()
        thumb.thumbnail((256, 256), Image.Resampling.LANCZOS)
        archive.writestr("Thumbnails/thumbnail.png", png_bytes(thumb))


def verify(png, ora):
    with Image.open(png) as image:
        expected = image.convert("RGBA")
    with ZipFile(ora) as archive:
        stack = ET.fromstring(archive.read("stack.xml")).find("stack")
        if [el.attrib["src"] for el in stack] != [f"data/{k}.png" for k, _ in reversed(LAYERS)]:
            raise ValueError(f"Unexpected layer order in {ora}")
        rebuilt = Image.new("RGBA", expected.size)
        for el in reversed(list(stack)):
            with Image.open(io.BytesIO(archive.read(el.attrib["src"]))) as layer:
                rebuilt = Image.alpha_composite(rebuilt, layer.convert("RGBA"))
        embedded = Image.open(io.BytesIO(archive.read("mergedimage.png"))).convert("RGBA")
        for name, candidate in (("stack", rebuilt), ("merged preview", embedded)):
            if expected.size != candidate.size or any(
                channel.getbbox() for channel in ImageChops.difference(expected, candidate).split()
            ):
                raise ValueError(f"{name} differs from {png}")


def compose(stage, root=ROOT):
    source_stage = min(stage, 8)
    layers = []
    for key, name in LAYERS:
        path = root / "build" / f"{source_stage}-{key}.png"
        with Image.open(path) as image:
            layer = image.convert("RGBA")
        if key == "land":
            layer = Image.alpha_composite(Image.new("RGBA", layer.size, SKY), layer)
        elif layer.size != layers[0][2].size:
            raise ValueError(f"Unexpected layer dimensions for {path}")
        layers.append((key, name, grade(layer) if stage == 9 else layer))

    merged = layers[0][2].copy()
    for _, _, layer in layers[1:]:
        merged = Image.alpha_composite(merged, layer)
    name = STAGES[stage]
    with tempfile.TemporaryDirectory(dir=root) as staging:
        png = Path(staging) / f"{name}.png"
        ora = png.with_suffix(".ora")
        merged.save(png)
        write_ora(ora, layers, merged)
        verify(png, ora)
        png.replace(root / png.name)
        ora.replace(root / ora.name)
    print(f"{name}: {merged.width} x {merged.height}, four layers, pixel match")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", type=int, choices=STAGES)
    compose(parser.parse_args().stage)

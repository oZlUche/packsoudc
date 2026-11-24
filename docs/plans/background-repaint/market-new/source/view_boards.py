"""Build stage-specific orthographic and camera comparison sheets."""

import argparse
from pathlib import Path
from PIL import Image
from boards import PAPER, panel, title

ROOT = Path(__file__).resolve().parent.parent
STAGES = {
    5: ("05-values.png", "黑白明度"),
    6: ("06-color.png", "固有色"),
    7: ("07-material.png", "材质"),
    8: ("08-details.png", "细节"),
    9: ("09-final.png", "最终调色"),
}


def board(root, stage):
    geometry = min(stage, 8)
    filename, label = STAGES[stage]
    build = root / "build"
    canvas = Image.new("RGB", (2200, 1470), PAPER)
    title(canvas, f"{stage:02d}  {label} · 三视图与成品镜头")
    panels = [
        (build / f"{geometry:02d}-ortho-top.png", "俯视", "北向上"),
        (root / filename, "成品镜头", label),
        (build / f"{geometry:02d}-ortho-front.png", "正视", "从南向北"),
        (build / f"{geometry:02d}-ortho-side.png", "右侧视", "从东向西"),
    ]
    if stage == 9:
        panels[0] = (panels[0][0], "俯视", "沿用第 08 阶段几何 · 北向上")
    for i, (path, name, note) in enumerate(panels):
        panel(canvas, (42 + 1075 * (i % 2), 122 + 660 * (i // 2), 1040, 588), path, name, note)
    dest = root / "views"
    dest.mkdir(exist_ok=True)
    canvas.save(dest / f"{stage:02d}.jpg", quality=92, subsampling=0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("stages", nargs="*", type=int)
    args = parser.parse_args()
    for stage in args.stages or STAGES:
        board(args.root, stage)

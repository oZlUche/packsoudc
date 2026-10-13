#!/usr/bin/env bash
# 168：按 assets/fonts/charset.txt 把四个原始字体裁成子集，写进 assets/fonts/。
# 用法：tools/subset_fonts.sh [原始字体目录]（默认 /mnt/project-files/art/fonts/chosen）
# 要 fonttools：python3 -m pip install fonttools（一次）。先跑 python3 tools/font_charset.py 更新字集。
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:-/mnt/project-files/art/fonts/chosen}"
OUT=assets/fonts
CHARSET="$OUT/charset.txt"
for pair in \
	"LXGWWenKai-Regular.ttf:wenkai_regular.ttf" \
	"LXGWWenKai-Medium.ttf:wenkai_medium.ttf" \
	"ZhuqueFangsong-Regular.ttf:zhuque_fangsong.ttf" \
	"MaShanZheng-Regular.ttf:mashanzheng.ttf"; do
	src="$SRC/${pair%%:*}"
	dst="$OUT/${pair##*:}"
	pyftsubset "$src" --text-file="$CHARSET" --layout-features='*' --name-IDs='*' --output-file="$dst"
	printf '%s → %s（%s 字节）\n' "$src" "$dst" "$(wc -c < "$dst")"
done
# 霞鹜文楷的授权（OFL）保留了字体名「霞鹜 / 霞鶩 / 落霞孤鹜 / 落霞孤鶩 / LXGW」：裁过的子集是修改版，游戏里带着不算网页字体，
# 不能再叫这些名字 —— 把名字表里的字体名改成「PackSDC Kai」，版权与授权那几条（0、13、14）原样留着
python3 - "$OUT/wenkai_regular.ttf" "$OUT/wenkai_medium.ttf" <<'PY'
import sys
from fontTools.ttLib import TTFont
RESERVED = ("霞鹜", "霞鶩", "落霞孤鹜", "落霞孤鶩", "LXGW")
KEEP = (0, 13, 14)
for path in sys.argv[1:]:
    style = "Medium" if "medium" in path else "Regular"
    names = {1: "PackSDC Kai" + (" Medium" if style == "Medium" else ""), 2: "Regular", 3: "PackSDC Kai " + style,
        4: "PackSDC Kai " + style, 6: "PackSDCKai-" + style, 16: "PackSDC Kai", 17: style}
    font = TTFont(path)
    table = font["name"]
    for rec in list(table.names):
        if rec.nameID in KEEP:
            continue
        if rec.nameID in names:
            rec.string = names[rec.nameID]
        elif any(r in rec.toUnicode() for r in RESERVED):
            table.names.remove(rec)
    if "CFF " in font:
        font["CFF "].cff.fontNames = [names[6]]
    font.save(path)
    print("%s：字体名改成 %s" % (path, names[4]))
PY

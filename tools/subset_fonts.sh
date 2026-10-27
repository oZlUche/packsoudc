#!/usr/bin/env bash
# 168：按 assets/fonts/charset.txt 把四个原始字体裁成子集，写进 assets/fonts/。
# 2026-10-27 作者定稿：正文思源宋体 Medium / Black（方案 B2，之前是 Regular / Bold），大标题寒蝉锦书宋 Heavy（方案 A，替换马善政）。
# 用法：tools/subset_fonts.sh [原始字体目录]（默认 /mnt/project-files/art/fonts/chosen）
# 要 fonttools：python3 -m pip install fonttools（一次）。先跑 python3 tools/font_charset.py 更新字集。
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:-/mnt/project-files/art/fonts/chosen}"
OUT=assets/fonts
CHARSET="$OUT/charset.txt"
for pair in \
	"NotoSerifCJKsc-Medium.otf:serif_regular.otf" \
	"NotoSerifCJKsc-Black.otf:serif_bold.otf" \
	"ZhuqueFangsong-Regular.ttf:zhuque_fangsong.ttf" \
	"ChillJinshuSongHeavy.otf:display_heavy.otf"; do
	src="$SRC/${pair%%:*}"
	dst="$OUT/${pair##*:}"
	pyftsubset "$src" --text-file="$CHARSET" --layout-features='*' --name-IDs='*' --output-file="$dst"
	printf '%s → %s（%s 字节）\n' "$src" "$dst" "$(wc -c < "$dst")"
done
# 思源宋体（Noto Serif CJK SC）、朱雀仿宋没有保留字体名，子集照原名。
# 寒蝉锦书宋的授权（OFL）保留了字体名「Jinshu」（锦书）和 Adobe 的「Source」（思源）：裁过的子集是修改版，不能再叫这些名字 ——
# 名字表里的字体名改成「PackSDC Display」，含保留名的别的条目删掉，版权与授权那几条（0、13、14）原样留着（168 当年霞鹜文楷改 PackSDC Kai 同理）
python3 - "$OUT/display_heavy.otf" <<'PY'
import sys
from fontTools.ttLib import TTFont
RESERVED = ("Jinshu", "锦书", "錦書", "Source", "思源")
KEEP = (0, 13, 14)
names = {1: "PackSDC Display Heavy", 2: "Regular", 3: "PackSDC Display Heavy", 4: "PackSDC Display Heavy",
    6: "PackSDCDisplay-Heavy", 16: "PackSDC Display", 17: "Heavy"}
for path in sys.argv[1:]:
    font = TTFont(path)
    table = font["name"]
    for rec in list(table.names):
        if rec.nameID in KEEP:
            continue
        if rec.nameID in names:
            rec.string = names[rec.nameID]
        elif any(r in rec.toUnicode() for r in RESERVED):
            table.names.remove(rec)
    for nid in (3, 6):     # 只有部分平台写了的条目补齐，免得哪一条还留着原名
        if table.getName(nid, 3, 1, 0x409) is None:
            table.setName(names[nid], nid, 3, 1, 0x409)
    if "CFF " in font:
        font["CFF "].cff.fontNames = [names[6]]
        top = font["CFF "].cff.topDictIndex[0]
        for key in ("FullName", "FamilyName"):
            if hasattr(top, key):
                setattr(top, key, names[4] if key == "FullName" else names[16])
    font.save(path)
    print("%s：字体名改成 %s" % (path, names[4]))
PY
# 224：账单数字 Cinzel Bold（罗马碑刻体，OFL）—— 不按字集裁，只留数字、I V X 和 + − - % / · — × 空格（225：包架角标「×n」）（汉字不走它，缺的走思源宋体 Bold）
pyftsubset "$SRC/Cinzel-Bold.ttf" --text="0123456789IVX+−-%/·—× " --layout-features='*' --name-IDs='*' --output-file="$OUT/cinzel_bold.ttf"
printf '%s → %s（%s 字节）\n' "$SRC/Cinzel-Bold.ttf" "$OUT/cinzel_bold.ttf" "$(wc -c < "$OUT/cinzel_bold.ttf")"

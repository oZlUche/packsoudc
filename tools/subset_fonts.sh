#!/usr/bin/env bash
# 168：按 assets/fonts/charset.txt 把四个原始字体裁成子集（170 定稿起正文是思源宋体 Regular / Bold，不再是霞鹜文楷），写进 assets/fonts/。
# 用法：tools/subset_fonts.sh [原始字体目录]（默认 /mnt/project-files/art/fonts/chosen）
# 要 fonttools：python3 -m pip install fonttools（一次）。先跑 python3 tools/font_charset.py 更新字集。
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:-/mnt/project-files/art/fonts/chosen}"
OUT=assets/fonts
CHARSET="$OUT/charset.txt"
for pair in \
	"NotoSerifCJKsc-Regular.otf:serif_regular.otf" \
	"NotoSerifCJKsc-Bold.otf:serif_bold.otf" \
	"ZhuqueFangsong-Regular.ttf:zhuque_fangsong.ttf" \
	"MaShanZheng-Regular.ttf:mashanzheng.ttf"; do
	src="$SRC/${pair%%:*}"
	dst="$OUT/${pair##*:}"
	pyftsubset "$src" --text-file="$CHARSET" --layout-features='*' --name-IDs='*' --output-file="$dst"
	printf '%s → %s（%s 字节）\n' "$src" "$dst" "$(wc -c < "$dst")"
done
# 思源宋体（Noto Serif CJK SC）、朱雀仿宋、马善政都没有保留字体名，子集照原名（168 时霞鹜文楷要改名 PackSDC Kai，170 换掉文楷后这一步删了）
# 224：账单数字 Cinzel Bold（罗马碑刻体，OFL）—— 不按字集裁，只留数字、I V X 和 + − - % / · — × 空格（225：包架角标「×n」）（汉字不走它，缺的走思源宋体 Bold）
pyftsubset "$SRC/Cinzel-Bold.ttf" --text="0123456789IVX+−-%/·—× " --layout-features='*' --name-IDs='*' --output-file="$OUT/cinzel_bold.ttf"
printf '%s → %s（%s 字节）\n' "$SRC/Cinzel-Bold.ttf" "$OUT/cinzel_bold.ttf" "$(wc -c < "$OUT/cinzel_bold.ttf")"

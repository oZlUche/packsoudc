#!/usr/bin/env python3
"""168：裁字用的字集 —— 扫文案里出现的所有非 ASCII 字，并上一组固定字集，写成 assets/fonts/charset.txt（一行一个字，按码位排序）。

扫的范围和覆盖测试（tests/ui/test_fonts_168.gd、tools/check_content.gd）是同一张表：
data 下的 json / tres / txt（帮助页也在 data 里）、ui 与 core 与 tools 下的 gd / tscn。
文案新增了字 → 重跑本脚本，再跑 tools/subset_fonts.sh，提交子集与 charset.txt。
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts", "charset.txt")
# (目录, 后缀)：和 FontCoverage.SCAN 一致；不收的字（BOM、换行类）和 FontCoverage.SKIP 一致
SCAN = [
    ("data", (".json", ".tres", ".txt")),
    ("ui", (".gd", ".tscn")),
    ("core", (".gd",)),
    ("tools", (".gd", ".tscn")),
]
SKIP = {0xFEFF, 0x2028, 0x2029}
FIXED = (
    "".join(chr(c) for c in range(0x20, 0x7F))     # ASCII
    + "".join(chr(c) for c in range(0x3000, 0x3040))     # CJK 标点
    + "".join(chr(c) for c in range(0xFF01, 0xFF5F))     # 全角符号
    + "〇一二三四五六七八九十百千万"
    + "".join(chr(c) for c in range(0x2160, 0x216C))     # 罗马数字 Ⅰ–Ⅻ
    + "♥◆★▶⏸⏭‖×▸·—…“”‘’±−→←↑↓"
)


def scan() -> set:
    chars = set()
    for d, exts in SCAN:
        base = os.path.join(ROOT, d)
        for dirpath, _, files in os.walk(base):
            for f in files:
                if not f.endswith(exts):
                    continue
                with open(os.path.join(dirpath, f), encoding="utf-8", errors="ignore") as fh:
                    for ch in fh.read():
                        if ord(ch) > 0x7F and ord(ch) not in SKIP:
                            chars.add(ch)
    return chars


def main() -> int:
    chars = scan() | set(FIXED)
    chars.discard("\n")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        for ch in sorted(chars):
            fh.write(ch + "\n")
    print("%s：%d 个字" % (os.path.relpath(OUT, ROOT), len(chars)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

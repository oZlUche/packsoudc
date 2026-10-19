#!/usr/bin/env bash
# 201：把美术导出的道具图拷进 assets/items/，重写 manifest.json，再导入一次生成 .import。
# 源目录里是 <id>.png（60 px / 格）和 @2x/<id>.png（160 px / 格），画布 = 形状 rot 0 的包围盒，格外透明。
# 只把两套都有的 id 写进清单；缺一套的列出来不收。尺寸、格外透明、旋转对位由 tests/content/test_item_art_201.gd 守着。
# 208：<id>@<变体>.png（晶石 c2/c1/c0、生长 s1/s2）是实例变体图，进清单的 "variants"；同样两套都有才收，本图没收的变体也不收。
#
#   bash tools/sync_item_art.sh /mnt/project-files/art/items/drafts1/out
set -u
SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "用法：bash tools/sync_item_art.sh <美术导出目录（含 *.png 与 @2x/）>" >&2
  exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="$ROOT/assets/items"
mkdir -p "$DST/@2x"
cp "$SRC"/*.png "$DST"/
if [ -d "$SRC/@2x" ]; then
  cp "$SRC"/@2x/*.png "$DST"/@2x/
fi
# 205：信仰印记（marks/<faith>.png 24 px 与 marks/@2x/ 64 px）一并拷，不进清单
if [ -d "$SRC/marks" ]; then
  mkdir -p "$DST/marks/@2x"
  cp "$SRC"/marks/*.png "$DST"/marks/
  [ -d "$SRC/marks/@2x" ] && cp "$SRC"/marks/@2x/*.png "$DST"/marks/@2x/
  echo "印记：$(ls "$DST"/marks/*.png | wc -l) 枚 → assets/items/marks/"
fi

ids=()
vfiles=()
missing=()
for f in "$DST"/*.png; do
  id="$(basename "$f" .png)"
  if [ ! -f "$DST/@2x/$id.png" ]; then
    missing+=("$id")
  elif [[ "$id" == *@* ]]; then
    vfiles+=("$id")
  else
    ids+=("$id")
  fi
done
for f in "$DST"/@2x/*.png; do
  id="$(basename "$f" .png)"
  [ -f "$DST/$id.png" ] || missing+=("@2x/$id")
done
# 变体：本图得在清单里
variants=()
for v in "${vfiles[@]}"; do
  base="${v%%@*}"
  if printf '%s\n' "${ids[@]}" | grep -qx "$base"; then
    variants+=("$v")
  else
    missing+=("$v（没有本图 $base）")
  fi
done

{
  printf '{\n  "cell": 60,\n  "items": [\n'
  n=${#ids[@]}
  i=0
  for id in $(printf '%s\n' "${ids[@]}" | LC_ALL=C sort); do
    i=$((i + 1))
    if [ "$i" -lt "$n" ]; then printf '    "%s",\n' "$id"; else printf '    "%s"\n' "$id"; fi
  done
  printf '  ],\n  "variants": {'
  sep=""
  for base in $(printf '%s\n' "${variants[@]}" | sed 's/@.*//' | LC_ALL=C sort -u); do
    printf '%s\n    "%s": [' "$sep" "$base"
    vsep=""
    for v in $(printf '%s\n' "${variants[@]}" | grep "^$base@" | sed 's/^[^@]*@//' | LC_ALL=C sort); do
      printf '%s"%s"' "$vsep" "$v"
      vsep=", "
    done
    printf ']'
    sep=","
  done
  [ -n "$sep" ] && printf '\n  '
  printf '}\n}\n'
} > "$DST/manifest.json"
echo "清单：${#ids[@]} 件、${#variants[@]} 张变体 → assets/items/manifest.json"
if [ ${#missing[@]} -gt 0 ]; then
  echo "✗ 只有一套、没收进清单：${missing[*]}"
fi

if [ -z "${GODOT:-}" ]; then
  for candidate in godot godot4 Godot; do
    if command -v "$candidate" >/dev/null 2>&1; then
      GODOT="$(command -v "$candidate")"
      break
    fi
  done
fi
GODOT="${GODOT:-/e/Godot/Godot_v4.7.1-stable_win64_console.exe}"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
echo "已导入（.import 和别的美术一样提交）"

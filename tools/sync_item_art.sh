#!/usr/bin/env bash
# 201：把美术导出的道具图拷进 assets/items/，重写 manifest.json，再导入一次生成 .import。
# 源目录里是 <id>.png（60 px / 格）和 @2x/<id>.png（160 px / 格），画布 = 形状 rot 0 的包围盒，格外透明。
# 只把两套都有的 id 写进清单；缺一套的列出来不收。尺寸、格外透明、旋转对位由 tests/content/test_item_art_201.gd 守着。
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

ids=()
missing=()
for f in "$DST"/*.png; do
  id="$(basename "$f" .png)"
  if [ -f "$DST/@2x/$id.png" ]; then
    ids+=("$id")
  else
    missing+=("$id")
  fi
done
for f in "$DST"/@2x/*.png; do
  id="$(basename "$f" .png)"
  [ -f "$DST/$id.png" ] || missing+=("@2x/$id")
done

{
  printf '{\n  "cell": 60,\n  "items": [\n'
  n=${#ids[@]}
  i=0
  for id in $(printf '%s\n' "${ids[@]}" | LC_ALL=C sort); do
    i=$((i + 1))
    if [ "$i" -lt "$n" ]; then printf '    "%s",\n' "$id"; else printf '    "%s"\n' "$id"; fi
  done
  printf '  ]\n}\n'
} > "$DST/manifest.json"
echo "清单：${#ids[@]} 件 → assets/items/manifest.json"
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

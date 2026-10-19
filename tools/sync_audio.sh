#!/usr/bin/env bash
# 204：把美术交来的音效拷进 assets/audio/sfx/，CREDITS.md 并进 assets/audio/CREDITS.md，再导入一次生成 .import。
# 不生成清单：cue 表 data/authoring/audio/cues.json 是手写的（文件名对得上就行；不在表里的文件不会播）。
# 文件在不在、是不是 .ogg 由 tests/ui/test_audio_204.gd / test_audio_206.gd 守着。
# 206：目录下有 ogg/（每个 cue 几版 <cue>_v1.ogg …）时给 --variant v1，把那一版拷成 sfx/<cue>.ogg；
# 定稿（final/，已是最终名）照旧整体拷，同名覆盖。
#
#   bash tools/sync_audio.sh /mnt/project-files/art/audio/ui
#   bash tools/sync_audio.sh /mnt/project-files/art/audio/sfx2 --variant v1
#   bash tools/sync_audio.sh /mnt/project-files/art/audio/sfx2/final
set -u
SRC="${1:-}"
VARIANT=""
if [ "${2:-}" = "--variant" ]; then
  VARIANT="${3:-}"
fi
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "用法：bash tools/sync_audio.sh <美术目录（含 *.ogg，可带 CREDITS.md）> [--variant v1]" >&2
  exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="$ROOT/assets/audio"
mkdir -p "$DST/sfx"
n=0
if [ -n "$VARIANT" ] && [ -d "$SRC/ogg" ]; then
  for f in "$SRC"/ogg/*_"$VARIANT".ogg; do
    [ -f "$f" ] || continue
    name="$(basename "$f" "_$VARIANT.ogg")"
    cp "$f" "$DST/sfx/$name.ogg"
    n=$((n + 1))
  done
else
  for f in "$SRC"/*.ogg; do
    [ -f "$f" ] || continue
    cp "$f" "$DST/sfx/"
    n=$((n + 1))
  done
fi
echo "音效：$n 个 → assets/audio/sfx/"
CRED="$SRC/CREDITS.md"
[ -f "$CRED" ] || CRED="$(dirname "$SRC")/CREDITS.md"
if [ -f "$CRED" ]; then
  head_line="$(head -n 1 "$CRED")"
  if [ ! -f "$DST/CREDITS.md" ]; then
    cp "$CRED" "$DST/CREDITS.md"
  elif ! grep -qxF "$head_line" "$DST/CREDITS.md"; then
    { printf '\n'; cat "$CRED"; } >> "$DST/CREDITS.md"     # 新的一批另起一节，已有的不重复并
  fi
  echo "来源：assets/audio/CREDITS.md"
else
  echo "✗ 没有 CREDITS.md：每个文件的来源、作者、许可要记下来"
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
echo "已导入（.import 和别的素材一样提交）"

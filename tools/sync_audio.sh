#!/usr/bin/env bash
# 204：把美术交来的音效拷进 assets/audio/sfx/，CREDITS.md 拷到 assets/audio/，再导入一次生成 .import。
# 不生成清单：cue 表 data/authoring/audio/cues.json 是手写的（文件名对得上就行；不在表里的文件不会播）。
# 文件在不在、是不是 .ogg 由 tests/ui/test_audio_204.gd 守着。
#
#   bash tools/sync_audio.sh /mnt/project-files/art/audio/ui
set -u
SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "用法：bash tools/sync_audio.sh <美术目录（含 *.ogg，可带 CREDITS.md）>" >&2
  exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="$ROOT/assets/audio"
mkdir -p "$DST/sfx"
n=0
for f in "$SRC"/*.ogg; do
  [ -f "$f" ] || continue
  cp "$f" "$DST/sfx/"
  n=$((n + 1))
done
echo "音效：$n 个 → assets/audio/sfx/"
if [ -f "$SRC/CREDITS.md" ]; then
  cp "$SRC/CREDITS.md" "$DST/CREDITS.md"
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

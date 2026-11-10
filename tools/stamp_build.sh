#!/usr/bin/env bash
# 平衡检测方案（2026-11-10）§4.1：把构建标识写进 build_id.txt（BuildInfo.id 先读它）。打包或开发启动前跑一次。
#
#   bash tools/stamp_build.sh        # 写 build_id.txt，并打印
#
# 格式：git:<提交号前 12 位>，工作区有改动时再接 +dirty:<改动摘要前 8 位>（git diff HEAD 的 sha256，含未跟踪文件名）。
# build_id.txt 不进仓库（.gitignore）
set -eu
cd "$(dirname "$0")/.."
sha="$(git rev-parse HEAD | cut -c1-12)"
id="git:$sha"
if [ -n "$(git status --porcelain)" ]; then
  sum="$( { git diff HEAD; git ls-files --others --exclude-standard; } | sha256sum | cut -c1-8)"
  id="$id+dirty:$sum"
fi
printf '%s\n' "$id" > build_id.txt
echo "$id"

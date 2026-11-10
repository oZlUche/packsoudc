# 找 Godot：给 tools/*.sh 用 `.` 引进来的，不单独跑。
# GODOT 没设就先在 PATH 里找（Linux / CI / 容器），都找不到才用作者机器上的 Windows 路径
if [ -z "${GODOT:-}" ]; then
  for candidate in godot godot4 Godot; do
    if command -v "$candidate" >/dev/null 2>&1; then
      GODOT="$(command -v "$candidate")"
      break
    fi
  done
fi
GODOT="${GODOT:-/e/Godot/Godot_v4.7.1-stable_win64_console.exe}"

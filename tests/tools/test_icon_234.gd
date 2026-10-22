## 234（作者 2026-10-22 09:31 选「缝格背包」）：游戏图标 —— 项目图标是 assets/icon/icon.png（256），
## Windows 原生图标与导出用 assets/icon/icon.ico（多档，至少有 16 与 256）；不截图
extends RefCounted

const PNG := "res://assets/icon/icon.png"
const ICO := "res://assets/icon/icon.ico"


## .ico 目录里的各档边长（宽字节 0 = 256）
static func ico_sizes(path: String) -> Array[int]:
	var out: Array[int] = []
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 6 or bytes.decode_u16(2) != 1:
		return out
	var count := bytes.decode_u16(4)
	for i in count:
		var at := 6 + i * 16
		if at + 16 > bytes.size():
			break
		var w := bytes[at]
		out.append(256 if w == 0 else w)
	out.sort()
	return out


static func run(t: TestCase) -> void:
	t.begin("234 · 游戏图标：icon.png 与 icon.ico 在、项目设置指着它们、.ico 有 16 和 256 两档")
	t.check(FileAccess.file_exists(PNG), "icon.png 在")
	t.check(FileAccess.file_exists(ICO), "icon.ico 在")
	t.eq(ProjectSettings.get_setting("application/config/icon"), PNG, "项目图标")
	t.eq(ProjectSettings.get_setting("application/config/windows_native_icon"), ICO, "Windows 原生图标")
	var sizes := ico_sizes(ProjectSettings.globalize_path(ICO))
	t.check(sizes.has(16) and sizes.has(256), ".ico 有 16 和 256（%s）" % [sizes])
	var img := Image.load_from_file(ProjectSettings.globalize_path(PNG))
	t.check(img != null and img.get_width() == 256 and img.get_height() == 256, "icon.png 是 256 × 256")

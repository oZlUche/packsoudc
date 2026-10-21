## 事件配图的装载（063 / 064）。事件屏与事件编辑器的预览共用这一份。
##
## 编辑器导入的图片直接复制到 `res://assets/events/`，Godot 编辑器还没扫过（`.import` 没生成）时
## `load()` 拿不到；跑测试、跑无头截图也一样。所以先问 ResourceLoader，拿不到再按原始文件读 ——
## 作者导完图立刻能在预览里看见，不必先切回 Godot 让它扫一遍。
class_name EventImage
extends RefCounted

## 认得的图片后缀（小写、不带点）
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]


static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		var res := load(path)
		if res is Texture2D:
			return res
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	var img := Image.load_from_file(absolute)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


static func is_image_file(path: String) -> bool:
	return EXTENSIONS.has(path.get_extension().to_lower())


## 配图那一块（事件屏的左栏、编辑器的预览）：有图就铺满、按比例裁；没有图就一块深底色，居中写两行占位字（标题、提示）。
## [param size] 是最小尺寸；[param broken_hint] 是路径有、图却读不到时的提示（空 = 写出路径）；[param sep] 是两行占位字的间距
## [param light]（232 书页）：没图时不画深底黑块，画一块淡墨框、墨色字
static func area(path: String, title: String, size: Vector2, big_size: int = 22, small_size: int = 12,
		broken_hint: String = "", sep: int = 6, light: bool = false) -> Control:
	var area := Control.new()
	area.clip_contents = true
	area.custom_minimum_size = size
	var loaded := load_texture(path)
	if loaded != null:
		var tex := TextureRect.new()
		tex.texture = loaded
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		area.add_child(tex)
		return area
	var bg := ColorRect.new()
	bg.color = Color(UiTheme.INK_DEFAULT, 0.08) if light else Color("0d0f12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(center)
	var col := UiTheme.vbox(sep)
	center.add_child(col)
	if title != "":     # 226 批二：游戏里的事件屏不写占位标题（传空），编辑器预览照写
		var big := UiTheme.make_label(title, big_size, Color(UiTheme.INK_DEFAULT, 0.55) if light else UiPalette.DIM.darkened(0.35))
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(big)
	# 2026-10-17：路径坏了的提示只在开发版露出
	var missing := "" if path == "" else (broken_hint if broken_hint != "" else ("（图像占位：%s）" % path if GameSettings.dev_build() else ""))
	if missing != "":
		var hint := UiTheme.make_label(missing, small_size, UiPalette.DIM.darkened(0.45))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(hint)
	return area

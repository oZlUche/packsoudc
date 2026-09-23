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

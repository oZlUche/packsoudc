## 地图底图（作者定：每章一张手绘地图当底，风格各不同）：`assets/maps/<id>.png` + 同名 `.json`（`tone` 深 / 浅、`display_name`）。
##
## 章节写 [member ChapterDef.map_skin]（默认遗迹，和宝箱皮肤同一套章节主题）；地图屏把它铺满（cover，裁边不拉伸）画在路网底下，
## 中间那一大块椭圆是美术留给路网的淡底。字色跟 `tone` 走：浅纸上的字换字色模板的浅版（[method UiPalette.for_tone]，169）。没这张图 = 照旧石板 / 纯色底
class_name MapSkin
extends RefCounted

const DEFAULT := &"ruins"
## 底图目录（测试指到别处）
static var root := "res://assets/maps/"


static func texture(id: StringName) -> Texture2D:
	if String(id) == "":
		return null
	var path := root + String(id) + ".png"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	return EventImage.load_texture(path)


## 180 §4：这张底图的装饰层（石头、水、树木……）`<id>_deco.png` —— 透明底、和底图同尺寸、同一种铺法，叠在底图上、圈下面。
## 美术还没交 = null（入局转场照常，只是没有浮现装饰那一段）
static func deco(id: StringName) -> Texture2D:
	if String(id) == "":
		return null
	return texture(StringName(String(id) + "_deco"))


static func meta(id: StringName) -> Dictionary:
	var path := root + String(id) + ".json"
	if String(id) == "" or not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## 这张底是深是浅（json 没写按深 —— 原来的字色就是按深底配的）
static func tone(id: StringName) -> StringName:
	return UiTheme.TONE_LIGHT if String(meta(id).get("tone", "")) == "light" else UiTheme.TONE_DARK


## 铺满（cover）：图里取哪一块画到 [param area]（等比放大到盖满，多出来的两边裁掉、居中）
static func cover_region(tex_size: Vector2, area: Vector2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or area.x <= 0.0 or area.y <= 0.0:
		return Rect2(Vector2.ZERO, tex_size)
	var scale := maxf(area.x / tex_size.x, area.y / tex_size.y)
	var src := area / scale
	return Rect2((tex_size - src) * 0.5, src)

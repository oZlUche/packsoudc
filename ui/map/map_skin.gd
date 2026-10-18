## 地图底图（作者定：每章一张手绘地图当底，风格各不同）：`assets/maps/<id>.png` + 同名 `.json`（`tone` 深 / 浅、`display_name`）。
##
## 章节写 [member ChapterDef.map_skin]（默认遗迹，和宝箱皮肤同一套章节主题）。中间那一大块椭圆是美术留给路网的淡底（json 的 `safe_area`）。
## 192（作者 2026-10-18「实施」191 甲）：底图钉在画布上 —— 进图按 `safe_area` 把底图对准路网画布（[method paper_rect]），之后和路、点一起缩放平移。字色跟 `tone` 走：浅纸上的字换字色模板的浅版（[method UiPalette.for_tone]，169）。没这张图 = 照旧石板 / 纯色底
class_name MapSkin
extends RefCounted

const DEFAULT := &"ruins"
## 192：json 没写 `safe_area` 数字时的默认（占整张的比例）
const SAFE_DEFAULT := Rect2(0.1, 0.14, 0.8, 0.72)
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


## 192：底图的逻辑尺寸（json 的 `size`；没写按贴图尺寸）。贴图换成两倍图时几何不变，画的时候整张贴进目标矩形
static func logical_size(id: StringName) -> Vector2:
	var sz = meta(id).get("size", null)
	if sz is Array and (sz as Array).size() == 2 and float(sz[0]) > 0.0 and float(sz[1]) > 0.0:
		return Vector2(float(sz[0]), float(sz[1]))
	var tex := texture(id)
	return tex.get_size() if tex != null else Vector2.ZERO


## 192：美术留给路网的那块（淡色椭圆的外接矩形，图像素，按 [method logical_size]）：json `safe_area` 写四个数 `[x, y, w, h]`；
## 没写数字（还是一句话、或缺）= 默认中间 80% × 72%（gen.py 的椭圆）
static func safe_rect(id: StringName) -> Rect2:
	var a = meta(id).get("safe_area", null)
	if a is Array and (a as Array).size() == 4 and float(a[2]) > 0.0 and float(a[3]) > 0.0:
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	var sz := logical_size(id)
	return Rect2(sz.x * SAFE_DEFAULT.position.x, sz.y * SAFE_DEFAULT.position.y, sz.x * SAFE_DEFAULT.size.x, sz.y * SAFE_DEFAULT.size.y)


## 192：底图在画布坐标里占的矩形 —— 把 [method safe_rect] 等比放大到盖住 [param canvas]、两者中心对齐。没有底图 = 空矩形
static func paper_rect(id: StringName, canvas: Rect2) -> Rect2:
	var safe := safe_rect(id)
	var sz := logical_size(id)
	if texture(id) == null or safe.size.x <= 0.0 or safe.size.y <= 0.0 or not canvas.has_area():
		return Rect2()
	var s := maxf(canvas.size.x / safe.size.x, canvas.size.y / safe.size.y)
	return Rect2(canvas.get_center() - safe.get_center() * s, sz * s)


## 铺满（cover）：图里取哪一块画到 [param area]（等比放大到盖满，多出来的两边裁掉、居中）
static func cover_region(tex_size: Vector2, area: Vector2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or area.x <= 0.0 or area.y <= 0.0:
		return Rect2(Vector2.ZERO, tex_size)
	var scale := maxf(area.x / tex_size.x, area.y / tex_size.y)
	var src := area / scale
	return Rect2((tex_size - src) * 0.5, src)

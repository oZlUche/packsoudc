## 180：开局第三页中栏的地图预览 —— 选中一张图，纸上从中心化开一片（墨化边，`ink_reveal.gdshader`），
## 片里是这张图的底图（按整个窗口铺满裁边，和局内 [MapView] 同一种铺法，入局时纸不跳）与虚线圈。
## 圈数 = 这一档规模**真生成出来**的环数（第三页按种子生成一次交给它），圈距 = 化开半径 ÷ 环数；
## 半径按规模（[constant RADIUS_BY_SCALE]）：小型一团、圈少而疏，大型几乎铺满、圈多而密。
## 没有底图的章：只画圈。不进核心层，只是画面
class_name MapPreview
extends Control

const SHADER := preload("res://ui/map/ink_reveal.gdshader")
## 化开半径：× 自己较短边的一半
const RADIUS_BY_SCALE := {&"small": 0.55, &"medium": 0.75, &"large": 0.95}
const RADIUS_DEFAULT := 0.75
## 第一次化开、换图时先收再长
const GROW_SEC := 0.6
const SHRINK_SEC := 0.25
const REGROW_SEC := 0.5
const SHRINK_TO := 0.3
## 墨边模糊多宽（像素）
const SOFTNESS := 24.0
## 虚线圈：一段多长、隔多长；线宽小型粗、大型细
const DASH := 10.0
const DASH_GAP := 8.0
const RING_WIDTH_MAX := 3.0
const RING_WIDTH_MIN := 1.0

## 现在铺的底图（[MapSkin] 的 id）与环数
var skin: StringName = &""
var levels: int = 0
## 目标半径与现在的半径（都是 × 较短边一半）
var target_frac: float = 0.0
var radius_frac: float = 0.0:
	set(v):
		radius_frac = v
		_sync_material()
		queue_redraw()

static var _noise: NoiseTexture2D = null
var _skin_tex: Texture2D = null
var _tween: Tween = null
## 180 定稿：虚线圈的样子（美术 `setup/rings.json` 给小型 / 大型两套，中型取中间）：{width, dash, gap, color}；没给 = 空，按常量画
var _ring_style: Dictionary = {}
## 规模在两套之间的位置（小 0、中 0.5、大 1）
const RING_STYLE_T := {&"small": 0.0, &"medium": 0.5, &"large": 1.0}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"softness", SOFTNESS)
	m.set_shader_parameter(&"noise", noise_texture())
	material = m
	resized.connect(_sync_material)


## 墨边的噪声（引擎现生成，不要美术图）
static func noise_texture() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.noise = n
	return _noise


## 换一张图：[param skin_id] 底图、[param ring_levels] 环数、[param scale_id] 规模（定半径）。
## 第一次从零化开；已经化开着就先收一点再长到新的。[param animate] 假 = 一步到位（测试、转场关着）
func show_map(skin_id: StringName, ring_levels: int, scale_id: StringName, animate: bool = true) -> void:
	var was_open := radius_frac > 0.0
	skin = skin_id
	_skin_tex = MapSkin.texture(skin_id)
	levels = maxi(0, ring_levels)
	target_frac = float(RADIUS_BY_SCALE.get(scale_id, RADIUS_DEFAULT))
	_ring_style = ring_style(scale_id)
	if _tween != null:
		_tween.kill()
		_tween = null
	if not animate or not is_inside_tree():
		radius_frac = target_frac
		return
	_tween = create_tween()
	if was_open:
		_tween.tween_property(self, ^"radius_frac", radius_frac * SHRINK_TO, SHRINK_SEC).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(self, ^"radius_frac", target_frac, REGROW_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_tween.tween_property(self, ^"radius_frac", target_frac, GROW_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## 收起（没有可选的图）
func clear() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	skin = &""
	_skin_tex = null
	levels = 0
	target_frac = 0.0
	radius_frac = 0.0


## 动画直接到头
func finish() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	radius_frac = target_frac


## 圆心（本地像素）
func center() -> Vector2:
	return size * 0.5


## 半个较短边（像素）：半径的单位
func half_extent() -> float:
	return minf(size.x, size.y) * 0.5


## 化开到头时的半径与圈距（像素；入局转场从这里接）
func target_radius() -> float:
	return target_frac * half_extent()


func ring_gap() -> float:
	return target_radius() / float(levels) if levels > 0 else 0.0


## 线宽：有美术参数按规模取，没有就环越多越细
func ring_width() -> float:
	if not _ring_style.is_empty():
		return float(_ring_style["width"])
	return clampf(RING_WIDTH_MAX - 0.2 * float(maxi(0, levels - 3)), RING_WIDTH_MIN, RING_WIDTH_MAX)


## 一档规模的虚线样子（小型、大型照 json，中型两套各取一半）；没有 json 空字典
static func ring_style(scale_id: StringName) -> Dictionary:
	var meta := UiTheme.art_meta(UiTheme.ART_RINGS)
	if not meta.has("small") or not meta.has("large"):
		return {}
	var a: Dictionary = meta["small"]
	var b: Dictionary = meta["large"]
	var k := float(RING_STYLE_T.get(scale_id, 0.5))
	var ca := Color(String(a.get("color", "#3a2c1e")), float(a.get("alpha", 0.8)))
	var cb := Color(String(b.get("color", "#3a2c1e")), float(b.get("alpha", 0.8)))
	return {
		"width": lerpf(float(a.get("width", RING_WIDTH_MAX)), float(b.get("width", RING_WIDTH_MIN)), k),
		"dash": lerpf(float(a.get("dash", DASH)), float(b.get("dash", DASH)), k),
		"gap": lerpf(float(a.get("gap", DASH_GAP)), float(b.get("gap", DASH_GAP)), k),
		"color": ca.lerp(cb, k),
	}


func _sync_material() -> void:
	var m := material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter(&"center", center())
	m.set_shader_parameter(&"radius", radius_frac * half_extent())


func _draw() -> void:
	if radius_frac <= 0.0:
		return
	if _skin_tex != null:
		# 按整个窗口铺（和局内地图同一种铺法），本地坐标里窗口左上是 -global_position
		var vp := get_viewport_rect().size
		var area := Rect2(-get_global_rect().position, vp)
		draw_texture_rect_region(_skin_tex, area, MapSkin.cover_region(_skin_tex.get_size(), vp))
	var gap := ring_gap()
	if gap <= 0.0:
		return
	var ink: Color = _ring_style.get("color", Color(UiTheme.INK, 0.75))
	var width := ring_width()
	for lv in range(1, levels + 1):
		_dashed_circle(center(), gap * float(lv), ink, width)


func _dashed_circle(at: Vector2, r: float, color: Color, width: float) -> void:
	var on := float(_ring_style.get("dash", DASH))
	var step := (on + float(_ring_style.get("gap", DASH_GAP))) / r
	var dash := on / r
	var a := 0.0
	while a < TAU:
		draw_arc(at, r, a, minf(a + dash, TAU), 4, color, width, true)
		a += step

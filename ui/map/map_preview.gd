## 180：开局第三页中栏的地图预览 —— 选中一张图，纸上从中心化开一片（墨化边，`ink_reveal.gdshader`），
## 片里是这张图的底图（按整个窗口铺满裁边，和局内 [MapView] 同一种铺法，入局时纸不跳）与虚线圈。
## 圈数 = 这一档规模**真生成出来**的环数（第三页按种子生成一次交给它），圈距 = 化开半径 ÷ 环数；
## 半径按规模（[constant RADIUS_BY_SCALE]）：小型一团、圈少而疏，大型几乎铺满、圈多而密。
## 没有底图的章：只画圈。不进核心层，只是画面
## 182（作者 2026-10-17 15:26）：纸上还画这张图的几个入口（出生点）的印记，别的节点一概不画（入局转场里一环环长出来）。
## 点印记 / 点空白发信号（选不选、开不开提示窗是开局屏的事）；挑中的入口以它为偏移中心微放大（底图、圈、印记一起动，墨化的那片不动）
class_name MapPreview
extends Control

## 点了一个入口 / 点了预览上的空白
signal entry_pressed(id: int)
signal blank_pressed

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
		_redraw_marks()

static var _noise: NoiseTexture2D = null
var _skin_tex: Texture2D = null
var _tween: Tween = null
## 180 定稿：虚线圈的样子（美术 `setup/rings.json` 给小型 / 大型两套，中型取中间）：{width, dash, gap, color}；没给 = 空，按常量画
var _ring_style: Dictionary = {}
## 规模在两套之间的位置（小 0、中 0.5、大 1）
const RING_STYLE_T := {&"small": 0.0, &"medium": 0.5, &"large": 1.0}
## 182：入口印记屏幕上多大（不随圈距缩放，大图上也看得清）、点中的判定多放宽几像素
const MARK_SIZE := 40.0
const MARK_SLOP := 6.0
## 182：挑中一个入口时微放大多少倍、视中心往它挪几成、走多久
const ZOOM_IN := 1.35
const ZOOM_SHIFT := 0.4
const ZOOM_SEC := 0.25
## 印记的底色、选中那一圈（红）
const MARK_PAPER := Color("efe6cf")

## 182：入口 —— {id, rel（离圆心几个环距的向量，和尺寸无关）, route（路线下标）}
var entries: Array[Dictionary] = []
## 挑中的、鼠标底下的入口（-1 = 没有）
var selected: int = -1:
	set(v):
		selected = v
		_redraw_marks()
var hovered: int = -1
## 微放大：倍数与视中心离圆心的偏移（本地像素）；不放大 = 1 与 0
var view_zoom: float = 1.0:
	set(v):
		view_zoom = v
		queue_redraw()
		_redraw_marks()
var view_shift: Vector2 = Vector2.ZERO:
	set(v):
		view_shift = v
		queue_redraw()
		_redraw_marks()
## 现在放大在哪个入口上（-1 = 没放大）
var zoomed_on: int = -1
var _view_tween: Tween = null
## 印记画在这一层（不挂墨化着色器：最外环正好在墨边上，挂了会被墨边糊掉一半）
var _marks: Control = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"softness", SOFTNESS)
	m.set_shader_parameter(&"noise", noise_texture())
	material = m
	resized.connect(_sync_material)
	_marks = Control.new()
	_marks.name = "EntryMarks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


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
	zoom_reset(false)
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
	set_entries(null)


## 动画直接到头（化开与微放大）
func finish() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	radius_frac = target_frac
	if _view_tween != null:
		_view_tween.kill()
		_view_tween = null
		_apply_view_target()


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


#region 182：入口印记与微放大
## 换上这张图的入口（[param graph] 的 `entry_ids`，位置按同心环布局真算）；null / 不是同心环的图 = 不画入口。选择、放大一并清掉
func set_entries(graph: MapGraph) -> void:
	entries.clear()
	selected = -1
	hovered = -1
	zoom_reset(false)
	var lay := MapLayout.for_graph(graph) if graph != null else null
	if lay is RingLayoutBase:
		var ring := lay as RingLayoutBase
		var canvas := Rect2(Vector2.ZERO, ring.canvas_size(graph))
		var pos := ring.positions(graph, canvas)
		for i in graph.entry_ids.size():
			var id := graph.entry_ids[i]
			if not pos.has(id):
				continue
			var route := -1
			for r in graph.routes.size():
				if int(graph.routes[r].get("entry_id", -1)) == id:
					route = r
			entries.append({"id": id, "rel": ((pos[id] as Vector2) - canvas.get_center()) / RingLayoutBase.RING_STEP, "route": route})
	_redraw_marks()


func entry_ids() -> Array[int]:
	var out: Array[int] = []
	for e in entries:
		out.append(int(e["id"]))
	return out


## 入口在预览上的位置（本地像素，没放大时）；不是入口返回圆心
func entry_base(id: int) -> Vector2:
	for e in entries:
		if int(e["id"]) == id:
			return center() + (e["rel"] as Vector2) * ring_gap()
	return center()


## 本地点（没放大时的位置）→ 现在屏上画在哪（套上微放大）
func to_view(p: Vector2) -> Vector2:
	return center() + (p - center() - view_shift) * view_zoom


## 入口现在画在哪（本地像素）
func entry_point(id: int) -> Vector2:
	return to_view(entry_base(id))


## 屏上本地点 [param at] 点中了哪个入口（-1 = 没有；印记还没化开出来时一律没有）
func entry_at(at: Vector2) -> int:
	if marks_alpha() <= 0.0:
		return -1
	var best := -1
	var best_d := MARK_SIZE * 0.5 + MARK_SLOP
	for e in entries:
		if mark_alpha(int(e["id"])) < 0.5:
			continue     # 放大后挪出墨化那片的入口看不见，也点不着
		var d := at.distance_to(entry_point(int(e["id"])))
		if d <= best_d:
			best = int(e["id"])
			best_d = d
	return best


## 印记的透明度：纸化开到八成以后才浮出来
func marks_alpha() -> float:
	if target_frac <= 0.0:
		return 0.0
	return clampf((radius_frac / target_frac - 0.8) / 0.2, 0.0, 1.0)


## 一个入口印记的透明度：再乘上「在不在墨化那片里」—— 微放大后被推出那片的入口淡掉（纸上那片以外没有图）
func mark_alpha(id: int) -> float:
	var edge := radius_frac * half_extent()     # 最外一圈就在这里：没放大时入口正好压在上面
	var d := entry_point(id).distance_to(center())
	return marks_alpha() * (1.0 - smoothstep(edge + 4.0, edge + 16.0, d))


## 以入口 [param id] 及周围为偏移中心微放大（视中心往它挪 [constant ZOOM_SHIFT]、放大到 [constant ZOOM_IN]）；已经放大在它上面就不动
func zoom_to(id: int, animate: bool = true) -> void:
	if zoomed_on == id:
		return
	zoomed_on = id
	_tween_view(animate)


## 回到不放大
func zoom_reset(animate: bool = true) -> void:
	zoomed_on = -1
	_tween_view(animate)


func _view_target() -> Array:
	if zoomed_on < 0:
		return [1.0, Vector2.ZERO]
	return [ZOOM_IN, (entry_base(zoomed_on) - center()) * ZOOM_SHIFT]


func _apply_view_target() -> void:
	var to := _view_target()
	view_zoom = to[0]
	view_shift = to[1]


func _tween_view(animate: bool) -> void:
	if _view_tween != null:
		_view_tween.kill()
		_view_tween = null
	if not animate or not is_inside_tree():
		_apply_view_target()
		return
	var to := _view_target()
	_view_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_view_tween.tween_property(self, ^"view_zoom", to[0], ZOOM_SEC)
	_view_tween.tween_property(self, ^"view_shift", to[1], ZOOM_SEC)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := entry_at((event as InputEventMouseMotion).position)
		if h != hovered:
			hovered = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
			_redraw_marks()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit := entry_at(mb.position)
			if hit >= 0:
				entry_pressed.emit(hit)
			else:
				blank_pressed.emit()
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hovered >= 0:
		hovered = -1
		_redraw_marks()


func _redraw_marks() -> void:
	if _marks != null:
		_marks.queue_redraw()


## 印记：有美术图（小旗 `setup/spawn_flag_normal` / `_hover` / `_sel`，选中的红圈画在图里）就贴图；没有是一枚纸底墨圈、中间「生」的图标，选中外面加一圈红
func _draw_marks() -> void:
	if marks_alpha() <= 0.0 or entries.is_empty():
		return
	for e in entries:
		var id := int(e["id"])
		var p := entry_point(id)
		var a := mark_alpha(id)
		if a <= 0.0:
			continue
		var state := "_sel" if id == selected else ("_hover" if id == hovered else "_normal")
		var tex := UiTheme.art_cached(UiTheme.ART_SPAWN_MARK + state)
		if tex != null:
			var half := Vector2(MARK_SIZE, MARK_SIZE) * 0.5
			_marks.draw_texture_rect(tex, Rect2(p - half, half * 2.0), false, Color(1, 1, 1, a))
			continue
		var r := MARK_SIZE * 0.5 - 2.0
		var ink := Color(UiTheme.INK, a)
		_marks.draw_circle(p, r, Color(MARK_PAPER, 0.92 * a))
		_marks.draw_arc(p, r, 0.0, TAU, 48, ink, 3.0 if id == hovered else 2.0, true)
		var icon := MapNodeStyle.icon(&"spawn")
		if icon != null:
			var s := r * 1.1
			_marks.draw_texture_rect(icon, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, ink)
		else:
			var font := get_theme_default_font()
			var fs := int(r)
			var glyph := String(MapNodeStyle.of(&"spawn").get("glyph", "生"))
			var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_marks.draw_string(font, p + Vector2(-w * 0.5, fs * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		if id == selected:
			_marks.draw_arc(p, r + 5.0, 0.0, TAU, 48, Color(UiTheme.PARCHMENT_RED, a), 3.0, true)
#endregion


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
		# 192：和局内同一张纸、同一大小（纸按画布摆，画布按入局转场的 zoom0 缩到这一页）
		# 182：微放大时底图一起放大（直接算放大后的矩形，不用 draw_set_transform：墨化着色器读的是没变换的顶点）
		var shown := paper_on_screen()
		if shown.has_area():
			draw_texture_rect(_skin_tex, shown, false)
		else:
			# 还没有圈距：按整个窗口铺，本地坐标里窗口左上是 -global_position
			var vp := get_viewport_rect().size
			var area := Rect2(-get_global_rect().position, vp)
			draw_texture_rect_region(_skin_tex, Rect2(to_view(area.position), area.size * view_zoom), MapSkin.cover_region(_skin_tex.get_size(), vp))
	var gap := ring_gap()
	if gap <= 0.0:
		return
	var ink: Color = _ring_style.get("color", Color(UiTheme.INK, 0.75))
	var width := ring_width()
	var at := to_view(center())
	for lv in range(1, levels + 1):
		_dashed_circle(at, gap * float(lv) * view_zoom, ink, width)


## 192：纸在这一页上的矩形（本地像素，含 182 的微放大）。和局内 [MapView] 在入局 zoom0 = 圈距 / RING_STEP 时一样大、一样摆；
## 没底图或还没有圈距是空矩形
func paper_on_screen() -> Rect2:
	var gap := ring_gap()
	if _skin_tex == null or gap <= 0.0:
		return Rect2()
	var canvas := Rect2(Vector2.ZERO, Vector2.ONE * RingLayoutBase.canvas_side(levels))
	var paper := MapSkin.paper_rect(skin, canvas)
	if not paper.has_area():
		return Rect2()
	var zoom_p := gap / RingLayoutBase.RING_STEP
	return Rect2(to_view(center() + (paper.position - canvas.get_center()) * zoom_p), paper.size * zoom_p * view_zoom)


func _dashed_circle(at: Vector2, r: float, color: Color, width: float) -> void:
	var on := float(_ring_style.get("dash", DASH))
	var step := (on + float(_ring_style.get("gap", DASH_GAP))) / r
	var dash := on / r
	var a := 0.0
	while a < TAU:
		draw_arc(at, r, a, minf(a + dash, TAU), 4, color, width, true)
		a += step

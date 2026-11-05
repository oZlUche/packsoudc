## 281 寂灭的路（三）：结算屏第二页，带回来的寂灭上放一次黑洞（作者选美术设计的 B「劈开」，界面动画 11-05 落地）：
## 黑洞带着旋臂张开、波纹往外荡 → 寂灭从洞里升起 → 洞面裂出光纹 → 沿一道锯齿缝从中劈开、左右两半退散、缝里透出红光 → 露出棋盘上的寂灭，自己摘掉。
## 全程 2 s。照美术设计的样张（art/items/w279/gen10_jimie_fx.py）在 320 见方的坐标里画，按寂灭的长边缩放。
## 演着的时候棋盘上那件先不画（[member InventoryView.veiled]），由这里画（升起时裁在洞里）；演完交回去。关了动效就不放
class_name JimieBlackHole
extends Control

const SEC := 2.0
## 样张的坐标：画布 320 见方、洞心 (160, 160)、洞最大半径 70、法杖长 240
const REF := 320.0
const REF_STAFF := 240.0
const C := Vector2(160, 160)
const RMAX := 70.0
## 各段（全程 0 → 1）：张开到 0.3；升起 0.3–0.6（从下面 230 处）；裂纹 0.6–0.7；劈开 0.7–1
const GROW_END := 0.3
const RISE_FROM := 230.0
const CRACK_AT := 0.6
const TEAR_AT := 0.7
## 劈开：两半各退多远、转几度
const TEAR_DX := 110.0
const TEAR_DY := 10.0
const TEAR_DEG := 14.0

const CORE := Color("08060c")
const INK := Color("1d1520")
const RED := Color("d0302a")
const RED_L := Color("f58a7a")
const CRACK_CORE := Color("ffd2c8")
const ARM := Color("6e4e9e")
const ARM_HI := Color("f0b070")
const RIPPLE := Color("c8b4f0")
const HAZE := Color("6a3a9a")
const STAFF_GLOW := Color("b07ad8")
## 裂纹：一条主缝 + 四条岔
const CRACKS := [
	[Vector2(160, 92), Vector2(150, 120), Vector2(166, 146), Vector2(152, 176), Vector2(168, 204), Vector2(160, 228)],
	[Vector2(150, 120), Vector2(124, 112)],
	[Vector2(166, 146), Vector2(196, 136)],
	[Vector2(152, 176), Vector2(122, 190)],
	[Vector2(168, 204), Vector2(198, 214)],
]
## 劈开的锯齿缝（洞里那几个折点；两头接在洞的上下沿）
const ZIG := [Vector2(152, 104), Vector2(168, 132), Vector2(150, 160), Vector2(170, 188), Vector2(152, 216)]

## 演到哪儿了：0 → 1
var t: float = 0.0:
	set(v):
		t = v
		_refresh()
var _view: InventoryView = null
var _uid := -1
var _k := 1.0
var _mask: Control = null     # 升起时裁法杖用的圆
var _staff: Control = null
var _over: Control = null     # 裂纹压在法杖上


## 盖在 [param view] 里 uid 那件道具上（找不到就不放）。返回放了的那个
static func cover(view: InventoryView, uid: int) -> JimieBlackHole:
	if view == null:
		return null
	var rect := view.item_rect(uid)
	if rect.size == Vector2.ZERO:
		return null
	var hole := JimieBlackHole.new()
	hole._view = view
	hole._uid = uid
	hole._k = maxf(rect.size.x, rect.size.y) / REF_STAFF
	var side := REF * hole._k
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.size = Vector2(side, side)
	# 游戏测试 11-05：寂灭贴着棋盘边时洞被面板裁掉一半 —— 挂到这一屏上（不在会裁的面板里），按棋盘的屏幕位置摆
	_host(view).add_child(hole)
	hole._place()
	view.veiled[uid] = true
	view.queue_redraw()
	hole.play()
	return hole


## 挂在哪：棋盘所在的那一屏（找不到就挂棋盘自己）
static func _host(view: InventoryView) -> Control:
	var n: Node = view
	while n != null:
		if n is GameScreen:
			return n
		n = n.get_parent()
	return view


## 罩在那件上：洞心 = 那件的中心（换算到挂的地方）。每步都摆一次，排版晚到也跟得上
func _place() -> void:
	var host := get_parent() as CanvasItem
	if host == null or _view == null or not is_instance_valid(_view):
		return
	var rect := _view.item_rect(_uid)
	if rect.size == Vector2.ZERO:
		return
	var at := host.get_global_transform().affine_inverse() * _view.get_global_transform() * rect.get_center()
	position = at - size * 0.5


func _init() -> void:
	_mask = _layer(self)
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_mask.draw.connect(_draw_mask)
	_staff = _layer(_mask)
	_staff.draw.connect(_draw_staff)
	_over = _layer(self)
	_over.draw.connect(_draw_cracks)


func _layer(parent: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	return c


func play() -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "t", 1.0, SEC)
	tw.finished.connect(_finish)
	return tw


## 演完：棋盘上那件交回去画，自己摘掉
func _finish() -> void:
	_unveil()
	queue_free()


func _exit_tree() -> void:
	_unveil()


func _unveil() -> void:
	if _view != null and is_instance_valid(_view) and _view.veiled.erase(_uid):
		_view.queue_redraw()


func _refresh() -> void:
	_place()
	# 劈开后法杖整根露在外面，不再裁
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED if t >= TEAR_AT else CanvasItem.CLIP_CHILDREN_ONLY
	queue_redraw()
	_mask.queue_redraw()
	_staff.queue_redraw()
	_over.queue_redraw()


#region 各段的进度（测试看）
static func _cl(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func grow() -> float:
	return _ease(_cl(t / GROW_END))


func rise() -> float:
	return _ease(_cl((t - GROW_END) / (CRACK_AT - GROW_END)))


func crack() -> float:
	return _cl((t - CRACK_AT) / (TEAR_AT - CRACK_AT))


func tear() -> float:
	return _ease(_cl((t - TEAR_AT) / (1.0 - TEAR_AT)))


func radius() -> float:
	return RMAX * maxf(grow(), 0.02)
#endregion


func _base() -> Transform2D:
	return Transform2D(0.0, Vector2(_k, _k), 0.0, Vector2.ZERO)


func _draw() -> void:
	draw_set_transform_matrix(_base())
	var r := radius()
	var tp := tear()
	var fade := 1.0 - tp
	_haze(C, r * 2.4, HAZE, 0.4 * fade)
	for k in 3:     # 波纹
		var p := fmod(t * 2.2 + k / 3.0, 1.0)
		var a := 0.55 * (1.0 - p) * fade * grow()
		if a > 0.01:
			draw_arc(C, r * (1.25 + 1.5 * p), 0.0, TAU, 64, Color(RIPPLE, a), 2.2 * (1.0 - p) + 0.4, true)
	_arms(r, deg_to_rad(t * 520.0), fade)
	if tp <= 0.0:
		_disk(r, 1.0, 0.0, TAU)
		return
	# 劈开：缝里一道红光，两半沿锯齿缝左右退散
	for i in 3:
		var w := 60.0 * tp + 12.0 + i * 10.0
		draw_rect(Rect2(C.x - w * 0.5, 60.0 - i * 6.0, w, 200.0 + i * 12.0), Color(RED, 0.7 * fade / (i + 1.5)), true)
	var half_a := 1.0 - tp * 0.95
	for side in 2:
		var dir := -1.0 if side == 0 else 1.0
		var move := Transform2D(deg_to_rad(TEAR_DEG * tp * dir), C + Vector2(TEAR_DX * tp * dir, -TEAR_DY * tp * dir)) * Transform2D(0.0, -C)
		draw_set_transform_matrix(_base() * move)
		draw_colored_polygon(_half(r, side), Color(CORE, half_a))
		var from := PI * 0.5 if side == 0 else -PI * 0.5
		_disk(r, fade * half_a, from, from + PI, false)
	draw_set_transform_matrix(_base())
	_haze_ellipse(Vector2(160, 130), Vector2(48, 110), STAFF_GLOW, 0.45 * (1.0 - tp))     # 演完光也收尽，交回棋盘时不跳


## 洞：红圈（外一圈虚光）+ 黑心。[param from] → [param to] 只画这一段弧（劈开的半边）
func _disk(r: float, ring_a: float, from: float, to: float, core := true) -> void:
	draw_arc(C, r * 1.12, from, to, 64, Color(RED, 0.3 * ring_a), r * 0.26, true)
	draw_arc(C, r * 1.1, from, to, 64, Color(RED, ring_a), r * 0.1, true)
	if core:
		draw_circle(C, r, CORE)
		draw_arc(C, r, 0.0, TAU, 64, INK, 2.4, true)


## 劈开的半边（0 左 1 右）：洞沿那一半弧 + 锯齿缝
func _half(r: float, side: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a0 := -PI * 0.5 if side == 0 else PI * 0.5
	for i in 33:     # 从顶（左半）/ 底（右半）沿洞沿绕半圈
		var a := a0 - PI * i / 32.0
		pts.append(C + Vector2(cos(a), sin(a)) * r)
	var zig: Array = ZIG.duplicate()
	if side == 0:
		zig.reverse()     # 左半绕到底，沿缝自下而上回去；右半绕到顶，自上而下
	for p in zig:
		pts.append(p)
	return pts


## 三条旋臂：墨底 + 紫身 + 一线金
func _arms(r: float, rot: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	for k in 3:
		var pts := PackedVector2Array()
		for j in 18:
			var a := deg_to_rad(k * 120.0 + j * 13.0) + rot
			pts.append(C + Vector2(cos(a), sin(a)) * r * (2.3 - j * 0.07))
		draw_polyline(pts, Color(INK, 0.9 * alpha), r * 0.2, true)
		draw_polyline(pts, Color(ARM, alpha), r * 0.13, true)
		draw_polyline(pts, Color(ARM_HI, 0.9 * alpha), r * 0.045, true)


## 一团淡光：一圈圈叠（不用模糊）
func _haze(at: Vector2, r: float, color: Color, alpha: float) -> void:
	if alpha <= 0.01:
		return
	for i in 6:
		draw_circle(at, r * (1.0 - i * 0.15), Color(color, alpha / 6.0))


func _haze_ellipse(at: Vector2, radii: Vector2, color: Color, alpha: float) -> void:
	if alpha <= 0.01:
		return
	draw_set_transform_matrix(_base() * Transform2D(0.0, radii / radii.x, 0.0, at))
	_haze(Vector2.ZERO, radii.x, color, alpha)
	draw_set_transform_matrix(_base())


func _draw_mask() -> void:
	if t >= TEAR_AT:
		return     # 不裁了：圆自己别露出来
	_mask.draw_set_transform_matrix(_base())
	_mask.draw_circle(C, radius(), Color.WHITE)


## 法杖：升起时从洞下面往上冒（裁在洞里），劈开后整根立着
func _draw_staff() -> void:
	if t < GROW_END or _view == null or not is_instance_valid(_view):
		return
	var inst: ItemInstance = _view.inventory.get_item(_uid) if _view.inventory != null else null
	if inst == null:
		return
	var dy := 0.0 if t >= TEAR_AT else (1.0 - rise()) * RISE_FROM * _k
	# 棋盘坐标 → 本控件坐标（洞不挂在棋盘里），再往下错开 dy
	var base := Transform2D(0.0, Vector2(0, dy)) * _staff.get_global_transform().affine_inverse() * _view.get_global_transform()
	var anchor := _view.cell_origin_px(inst.origin)
	var tint := ItemPainter.runs_tint(inst)
	_staff.draw_set_transform_matrix(base)
	if not ItemPainter.draw_art(_staff, inst.def, inst.rotation, anchor, _view.cell_px, tint, base, ItemPainter.variant_of(inst)):
		ItemPainter.draw_item(_staff, inst.cells(), anchor, _view.cell_px, ItemPainter.body_color(inst.def, inst.rarity()), ItemPainter.rarity_color(inst.def, inst.rarity()))


## 裂纹：红光一道道爬满洞面（按总长显出）
func _draw_cracks() -> void:
	var c := crack()
	if c <= 0.0 or t >= TEAR_AT:
		return
	_over.draw_set_transform_matrix(_base())
	var total := 0.0
	for line in CRACKS:
		for i in range(1, line.size()):
			total += (line[i] as Vector2).distance_to(line[i - 1])
	var left := total * c
	for line in CRACKS:
		for i in range(1, line.size()):
			if left <= 0.0:
				return
			var a: Vector2 = line[i - 1]
			var b: Vector2 = line[i]
			var seg := a.distance_to(b)
			var e := a.lerp(b, minf(1.0, left / seg))
			left -= seg
			_over.draw_line(a, e, Color(RED_L, 0.25 * c), 10.0, true)
			_over.draw_line(a, e, Color(RED_L, 0.6 * c), 5.0, true)
			_over.draw_line(a, e, CRACK_CORE, 1.6, true)

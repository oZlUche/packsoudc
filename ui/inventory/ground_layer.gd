## 地上（128，作者定）：不画地上框 —— 格子外的整块屏幕就是「地上」，拖出背包放哪就在哪。
##
## 画的是一个 [ItemStash]：每件按它的形状画在自己的落点上（[member ItemStash.spots]，归一化坐标，乘回本控件尺寸），
## 和棋盘同一套画法、同一个格子尺寸，所以「放下去是什么样就是什么样」。允许重叠，后放的在上；没有框、没有标题、没有滚动条。
## 落点**只是样子**：不占格、不碰撞、不参与任何规则（3.4）。
##
## 两种用法：
## [codeblock]
## fills_screen = true   导演持有的那一层（一个节点一层）：铺满视口，盖在所有屏上面；只有道具本身接鼠标，
##                       拖拽层把它当「棋盘外」—— 放手在哪就落在哪（[method DragLayer.drop_at]）
## fills_screen = false  一块普通的落点区域（开局屏、沙盒）：拖进这块就落在放手点
## [endcodeblock]
##
## 各屏向它登记自己占住的面板（[method reserve]）：地上的东西被面板盖住就往最近的空处推开；面板关了，落在它上沿的那几件再往下掉（162 补充二）。
##
## 134：**落地动画**（只是样子）。这一层记着上一次见过的 uid，多出来的就是刚落地的 —— 谁放的都一样（拖拽、顶出、战利品放不下……）。
## 162 补充二（作者定）：**竖直往下掉** —— 起点看 [member ItemStash.landing_from]（手动拖出 = 松手时残影的位置，自动掉 = 源格），
## 落到起点正下方第一个支撑（登记面板的上沿或屏幕底）上，按重力加速（沉的不封顶、飘的到末速度、左右小摆），途中绕重心转到重心最低的朝向，
## 触地弹一下；面板关了，托在它上面的再掉一次。没写起点的从落点上方竖直落下；就地（true）只缩放 + 弹。换一片地、读档、回到存过东西的点不播。
## 半空中的照样接鼠标（按此刻画在哪）
class_name GroundLayer
extends ContainerView

## 自动推开时离面板留的空（像素）
const PUSH_GAP := 6.0
## 134：落地动画 —— 没起点时从多高落下、一串落下时每件错开、最多错开几件、起始透明度
const LAND_DROP := 60.0
const LAND_STAGGER := 0.04
const LAND_STAGGER_MAX := 10
const LAND_ALPHA := 0.6
## 162 补充二：重力 —— g = LAND_G × 屏高 / 秒²（各分辨率一个节奏）；密度（162 补充一，每格几重）到 LAND_SINK_DENSITY 算「沉」
const LAND_G := 2.0
const LAND_SINK_DENSITY := 2.0
## 「飘」：末速度封顶（屏高 / 秒，包更慢）、触地弹 6 像素、起手放大 1.15、途中左右摆（包摆得更大）
const LAND_VMAX := 0.5
const LAND_VMAX_BAG := 0.35
const LAND_BOUNCE := 6.0
const LAND_SCALE := 1.15
const LAND_SWAY := 3.0
const LAND_SWAY_BAG := 5.0
## 「沉」：不封顶，触地弹 = 触地速度 × LAND_IMPACT_K（夹在 2 ～ 6 像素）、一下即止；起手只放大 1.05、不摆；就地放下弹 3
const LAND_IMPACT_K := 0.004
const LAND_IMPACT_MIN := 2.0
const LAND_IMPACT_MAX := 6.0
const LAND_BOUNCE_SINK := 3.0
const LAND_SCALE_SINK := 1.05
## 触地后弹一下多久；起点已经贴着地（就地放下、放手点就在地上）时缩放 / 翻转用多久
const LAND_BOUNCE_SEC := 0.18
const LAND_PLACE_SEC := 0.2
const COLOR_HIGHLIGHT := Color(0.42, 0.86, 0.52)

## 导演持有的那一层（没有 = null：测试、沙盒）。各屏开拖拽时拿它登记
static var _current: GroundLayer = null

@export var label_font: Font

var stash: ItemStash:
	set = set_stash
## 见类注释
var fills_screen: bool = false
## 085：亮一圈的（uid → true）：拖着的那件能和它合成。拖拽层设
var highlights: Dictionary = {}
## 登记占着地方的面板
var _reserved: Array[Control] = []
var tip: HoverTip = null
## 接着这层地的拖拽层（后接的在上）。好几块面板同时开着时（地图上的背包浮窗 + 叠层），只有最上面那块接地上的抓取 / 双击
var _drags: Array[DragLayer] = []
## 134：上一次见过的 uid（uid → true）—— 多出来的就是刚落地的
var _known: Dictionary = {}
## 134：正在落的（uid → 一段下落：已播秒数 `t`（负 = 还在排队）、重心起止、翻转、触地时刻……见 [method _begin_fall]）
var _landing: Dictionary = {}
## 162 补充二：落在哪块面板的上沿上（uid → 面板）；面板关了这几件再掉一次
var _support: Dictionary = {}
var _scan_queued: bool = false


static func current() -> GroundLayer:
	return _current if _current != null and is_instance_valid(_current) else null


## 导演设 / 撤
static func set_current(layer: GroundLayer) -> void:
	_current = layer


func attach(drag: DragLayer) -> void:
	_drags.erase(drag)
	_drags.append(drag)


func detach(drag: DragLayer) -> void:
	_drags.erase(drag)


## 现在接地上抓取的那个拖拽层（没人接 = null：谁都能抓，测试里就是这样）
func top_drag() -> DragLayer:
	for i in range(_drags.size() - 1, -1, -1):
		if is_instance_valid(_drags[i]) and not _drags[i].is_queued_for_deletion() and _drags[i].is_inside_tree() and DragLayer.is_live(_drags[i]):
			return _drags[i]
	return null


func _init() -> void:
	auto_tooltip = false     # 自己带一个悬浮窗（画在地上的东西上面）
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	super._ready()
	tip = HoverTip.new()
	add_child(tip)
	tip.watch(self)
	resized.connect(_on_resized)
	_on_resized()


func set_stash(s: ItemStash) -> void:
	if stash == s:
		return
	if stash != null and stash.changed.is_connected(_on_stash_changed):
		stash.changed.disconnect(_on_stash_changed)
	stash = s
	# 134：换一片地 = 基线，不播
	_landing.clear()
	_known = _uids()
	if stash != null:
		stash.landing_from.clear()
		stash.changed.connect(_on_stash_changed)
		_sync_norms()
	set_process(false)
	queue_redraw()


func container() -> ItemContainer:
	return stash


func _on_stash_changed() -> void:
	queue_redraw()
	# 晚一拍再比对：放手 / 顶出的调用方在 insert 之后才写起点
	if not _scan_queued:
		_scan_queued = true
		_scan.call_deferred()


#region 落地动画（134）
func _uids() -> Dictionary:
	var out := {}
	if stash != null:
		for inst in stash.items():
			out[(inst as ItemInstance).uid] = true
	return out


## 和上一次见过的比：多出来的各给一段落地动画（按插入顺序错开），不在了的停掉。
## 162 补充二：给了起点像素的（放手点、源格）落到起点**正下方**的地上（[method spot_below]），朝向转到重心最低的那个 —— 核心层给的落点被这里改掉
func _scan() -> void:
	_scan_queued = false
	if not is_instance_valid(self) or stash == null:
		return
	var now := _uids()
	for uid in _landing.keys():
		if not now.has(uid):
			_landing.erase(uid)
	for uid in _support.keys():
		if not now.has(uid):
			_support.erase(uid)
	var k := 0
	for inst in stash.items():
		var uid := (inst as ItemInstance).uid
		if _known.has(uid):
			continue
		var from: Variant = stash.landing_from.get(uid, null)
		stash.landing_from.erase(uid)
		if from is bool and not from:
			continue     # 本来就在（读档、回到存过东西的点）
		var stagger := -LAND_STAGGER * mini(k, LAND_STAGGER_MAX)
		if from is Vector2:
			_begin_fall(inst, (from as Vector2) - global_position, stagger)
		else:
			# 就地落下（拖拽放手、单击一下又放回）画在落点上，照样接鼠标：否则单击后紧跟的那一下双击落空；
			# 没给起点的（核心层自己找的空处）从落点上方竖直落下
			var target := item_rect(uid).position
			var start := target if from is bool else target - Vector2(0.0, LAND_DROP)
			_landing[uid] = _fall(inst, start, inst.rotation, target, inst.rotation, stagger, from is bool)
		k += 1
	_known = now
	set_process(not _landing.is_empty())
	queue_redraw()


## 一件从 [param from_local]（本控件内像素，现在朝向的包围盒左上角）往下掉：算地、算落稳朝向，改落点与朝向（核心层的状态立刻是终态），记一段动画
func _begin_fall(inst: ItemInstance, from_local: Vector2, stagger: float) -> void:
	if inst.def == null or inst.def.shape == null:
		return
	var rot_from := inst.rotation
	var rot_to := inst.def.shape.rest_rotation(rot_from)
	var land := spot_below(from_local, inst, rot_from, rot_to)
	inst.rotation = rot_to
	var target: Vector2 = land["pos"]
	if land["panel"] != null:
		_support[inst.uid] = land["panel"]
	else:
		_support.erase(inst.uid)
	_landing[inst.uid] = _fall(inst, from_local, rot_from, target, rot_to, stagger, false)
	stash.set_spot(inst.uid, to_spot(target))


## 162 补充二：起点 [param from_local]（朝向 [param rot_from] 的包围盒左上角）正下方的落点：重心 x 不变（夹在屏内），
## 落到这一列往下第一个支撑（[method floor_under]）上。返回 {pos: 落稳后（朝向 [param rot_to]）包围盒左上角, panel: 托着它的面板或 null}
func spot_below(from_local: Vector2, inst: ItemInstance, rot_from: int, rot_to: int) -> Dictionary:
	var span_to := span_px(inst, rot_to)
	var com_x := from_local.x + inst.def.shape.center_of_mass(rot_from).x * InventoryView.CELL
	var x := clampf(com_x - inst.def.shape.center_of_mass(rot_to).x * InventoryView.CELL, 0.0, maxf(0.0, size.x - span_to.x))
	var bottom := from_local.y + span_px(inst, rot_from).y
	var under := floor_under(x, x + span_to.x, bottom)
	return {"pos": Vector2(x, maxf(0.0, float(under["y"]) - span_to.y)), "panel": under["panel"]}


## 162 补充二：横向 [param x0]～[param x1] 这一条、从 [param from_y] 往下第一个支撑：登记面板的上沿（{y, panel}），没有就是屏幕底（panel = null）
func floor_under(x0: float, x1: float, from_y: float) -> Dictionary:
	var best := size.y * (1.0 - ItemStash.SPOT_MARGIN)
	var by: Control = null
	for panel in _reserved:
		if not is_instance_valid(panel) or not panel.is_inside_tree() or not panel.is_visible_in_tree():
			continue
		var g := panel.get_global_rect()
		var r := Rect2(g.position - global_position, g.size)
		if r.size.x <= 0.0 or r.size.y <= 0.0 or r.position.x >= x1 or r.end.x <= x0:
			continue
		if r.position.y >= from_y - 0.5 and r.position.y < best:
			best = r.position.y
			by = panel
	return {"y": best, "panel": by}


## 一段下落：重心从起点到终点，竖直按重力（沉的不封顶、飘的到末速度封顶），横向线性（只有夹边时才有），翻转 / 缩放 / 透明跟落了几成走；触地后弹一下
func _fall(inst: ItemInstance, from_local: Vector2, rot_from: int, to_local: Vector2, rot_to: int, stagger: float, in_place: bool) -> Dictionary:
	var prof := land_profile(inst.def)
	var shape := inst.def.shape
	var com_from := shape.center_of_mass(rot_from) * InventoryView.CELL
	var com_to := shape.center_of_mass(rot_to) * InventoryView.CELL
	var p0 := from_local + com_from
	var p1 := to_local + com_to
	var drop := p1.y - p0.y
	var h := _screen_h()
	var g := LAND_G * h
	var vmax := float(prof["vmax"]) * h if prof["vmax"] != INF else INF
	var t_hit := LAND_PLACE_SEC
	var v_hit := 0.0
	var falls := drop >= 1.0 and not in_place
	if falls:
		var d_cap := vmax * vmax / (2.0 * g) if vmax != INF else INF
		if drop <= d_cap:
			t_hit = sqrt(2.0 * drop / g)
			v_hit = g * t_hit
		else:
			t_hit = vmax / g + (drop - d_cap) / vmax
			v_hit = vmax
	var amp := float(prof["bounce"])
	if falls and bool(prof["sink"]):
		amp = clampf(v_hit * LAND_IMPACT_K, LAND_IMPACT_MIN, LAND_IMPACT_MAX)
	var steps := posmod(rot_to - rot_from, 4)
	var turn: float = [0.0, PI * 0.5, PI, -PI * 0.5][steps]     # 走最短的一边（顺时针为正）
	return {"t": stagger, "p0": p0, "p1": p1, "falls": falls, "g": g, "vmax": vmax, "t_hit": t_hit, "v_hit": v_hit,
		"sec": t_hit + LAND_BOUNCE_SEC, "amp": amp, "rot_from": rot_from, "turn": turn, "com_from": com_from,
		"in_place": in_place, "profile": prof}


## 屏高（重力按它）：在树里按视口，不在（测试）按自己
func _screen_h() -> float:
	if is_inside_tree():
		return maxf(1.0, get_viewport_rect().size.y)
	return maxf(1.0, size.y)


## 这一段落了几成（0 ～ 1）：真落的按重力算出的竖直位移，就地 / 贴地的按时间
static func _fall_progress(a: Dictionary, t: float) -> float:
	if t >= float(a["t_hit"]):
		return 1.0
	if not bool(a["falls"]):
		return clampf(t / float(a["t_hit"]), 0.0, 1.0)
	var g := float(a["g"])
	var vmax := float(a["vmax"])
	var t_cap := vmax / g if vmax != INF else INF
	var fallen := 0.5 * g * t * t if t <= t_cap else vmax * vmax / (2.0 * g) + vmax * (t - t_cap)
	var drop := (a["p1"] as Vector2).y - (a["p0"] as Vector2).y
	return clampf(fallen / drop, 0.0, 1.0)


## 此刻往下落的速度（像素 / 秒；测试看重力与末速度）
func landing_speed(uid: int) -> float:
	if not _landing.has(uid):
		return 0.0
	var a: Dictionary = _landing[uid]
	var t := float(a["t"])
	if t < 0.0 or not bool(a["falls"]) or t >= float(a["t_hit"]):
		return 0.0
	return minf(float(a["g"]) * t, float(a["vmax"]))


## 面板关了：托在它上沿的那几件从现在的位置再掉一次（只往下，不往回挪）
func _drop_supported(panel: Control) -> void:
	if stash == null:
		return
	for uid in _support.keys():
		if _support[uid] != panel:
			continue
		_support.erase(uid)
		var inst := stash.get_item(uid)
		if inst == null:
			continue
		_landing.erase(uid)
		_begin_fall(inst, item_rect(uid).position, 0.0)
	set_process(not _landing.is_empty())
	queue_redraw()


## 托着这件的面板（测试看；没有 null）
func support_of(uid: int) -> Control:
	return _support.get(uid, null)


func _process(delta: float) -> void:
	advance_landing(delta)


## 162 补充一 / 二：一件怎么落 —— {sink: 沉还是飘, vmax: 末速度（屏高 / 秒，沉 = INF）, bounce: 就地 / 飘的弹几像素, sway: 摆幅, scale: 起手放大}
static func land_profile(def: ItemDef) -> Dictionary:
	var cells := def.cell_count() if def != null else 0
	var density := float(ItemWeight.of(def)) / cells if cells > 0 else 0.0
	if density >= LAND_SINK_DENSITY:
		return {"sink": true, "vmax": INF, "bounce": LAND_BOUNCE_SINK, "sway": 0.0, "scale": LAND_SCALE_SINK}
	var bag := def != null and def.is_bag
	return {"sink": false, "vmax": LAND_VMAX_BAG if bag else LAND_VMAX, "bounce": LAND_BOUNCE, "sway": LAND_SWAY_BAG if bag else LAND_SWAY, "scale": LAND_SCALE}


## 推进落地动画 [param delta] 秒（测试直接调）
func advance_landing(delta: float) -> void:
	if _landing.is_empty():
		set_process(false)
		return
	for uid in _landing.keys():
		var a: Dictionary = _landing[uid]
		a["t"] = float(a["t"]) + delta
		if float(a["t"]) >= float(a["sec"]):
			_landing.erase(uid)
	if _landing.is_empty():
		set_process(false)
	queue_redraw()


## 这件是不是正在落
func is_landing(uid: int) -> bool:
	return _landing.has(uid)


## 这一段从出队到落稳一共多久（触地 + 弹一下；不在落 = 0）
func landing_sec(uid: int) -> float:
	return float(_landing[uid]["sec"]) if _landing.has(uid) else 0.0


## 正在落的（测试看）
func landing_uids() -> Array:
	return _landing.keys()


## 一件此刻画成什么样：{"pos": 不转不缩时包围盒左上角（起手朝向 `rot`）, "pivot": 重心（转与缩放绕它）, "angle": 转了多少（弧度）,
## "rot": 画的是哪个朝向的格子, "scale", "alpha", "hidden": 还在排队}。没在落 = 落点、现在的朝向、1、1
func landing_pose(uid: int) -> Dictionary:
	var r := item_rect(uid)
	var inst := stash.get_item(uid) if stash != null else null
	var rot := inst.rotation if inst != null else 0
	if not _landing.has(uid):
		var com := inst.def.shape.center_of_mass(rot) * InventoryView.CELL if inst != null and inst.def != null and inst.def.shape != null else r.size * 0.5
		return {"pos": r.position, "pivot": r.position + com, "angle": 0.0, "rot": rot, "scale": 1.0, "alpha": 1.0, "hidden": false}
	var a: Dictionary = _landing[uid]
	var prof: Dictionary = a["profile"]
	var t := float(a["t"])
	var com_from: Vector2 = a["com_from"]
	var p0: Vector2 = a["p0"]
	if t < 0.0:
		return {"pos": p0 - com_from, "pivot": p0, "angle": 0.0, "rot": a["rot_from"], "scale": float(prof["scale"]), "alpha": 0.0, "hidden": true}
	var s := _fall_progress(a, t)
	var pivot := p0.lerp(a["p1"], s)
	if bool(a["falls"]):
		pivot.x += float(prof["sway"]) * sin(TAU * s)     # 飘的左右荡下来；沉的摆幅 0
	if t > float(a["t_hit"]):
		pivot.y -= float(a["amp"]) * sin(PI * clampf((t - float(a["t_hit"])) / LAND_BOUNCE_SEC, 0.0, 1.0))
	var angle := float(a["turn"]) * s * s     # 缓入：越落转得越快，触地正好转到位
	return {"pos": pivot - com_from, "pivot": pivot, "angle": angle, "rot": a["rot_from"], "scale": lerpf(float(prof["scale"]), 1.0, s), "alpha": lerpf(LAND_ALPHA, 1.0, s), "hidden": false}
#endregion


func _on_resized() -> void:
	_sync_norms()
	queue_redraw()


## 把一格的大小和面板占的地方换成归一化坐标告诉 stash（自动铺放用）
func _sync_norms() -> void:
	if stash == null or size.x <= 0.0 or size.y <= 0.0:
		return
	stash.cell_norm = Vector2(InventoryView.CELL / size.x, InventoryView.CELL / size.y)
	var norm: Array[Rect2] = []
	for r in reserved_rects():
		norm.append(Rect2(r.position / size, r.size / size))
	stash.avoid = norm


#region 坐标
## 本控件内像素 → 落点（归一化）
func to_spot(local_px: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(clampf(local_px.x / size.x, 0.0, 1.0), clampf(local_px.y / size.y, 0.0, 1.0))


## 一件道具的包围盒尺寸（像素）
static func span_px(inst: ItemInstance, rot: int) -> Vector2:
	var hi := Vector2i.ZERO
	if inst != null and inst.def != null:
		for c in inst.def.cells_rotated(rot):
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Vector2(hi + Vector2i.ONE) * InventoryView.CELL


## 一件画在哪（本控件内像素）：落点乘回尺寸，再整块夹进屏里 —— 换了窗口大小东西也还在屏内
func item_rect(uid: int) -> Rect2:
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null:
		return Rect2()
	return _fit(Rect2(stash.spot_of(uid) * size, span_px(inst, inst.rotation)))


func _fit(r: Rect2) -> Rect2:
	var p := Vector2(
		clampf(r.position.x, 0.0, maxf(0.0, size.x - r.size.x)),
		clampf(r.position.y, 0.0, maxf(0.0, size.y - r.size.y)))
	return Rect2(p, r.size)


## 鼠标下最上面那一件（后放的在上）；没有 -1。162：半空中的也接（按它此刻画在哪、多大），排队还没出现的不接
func uid_at_local(p: Vector2) -> int:
	if stash == null:
		return -1
	var list := stash.items()
	for i in range(list.size() - 1, -1, -1):
		var inst := list[i] as ItemInstance
		if _landing.has(inst.uid) and bool(landing_pose(inst.uid)["hidden"]):
			continue
		var cell := _cell_under(inst.uid, p)
		if inst.def.cells_rotated(inst.rotation).has(cell):
			return inst.uid
	return -1


## [param p] 落在这一件的哪一格（现在朝向的坐标；不夹边，包围盒外是越界的格）：正在落的按此刻的位置、缩放、转角（绕重心）反推，
## 再从画着的起手朝向换到现在的朝向
func _cell_under(uid: int, p: Vector2) -> Vector2i:
	var r := item_rect(uid)
	var q := p - r.position
	var drawn_rot := -1
	if _landing.has(uid):
		var pose := landing_pose(uid)
		var k := maxf(0.01, float(pose["scale"]))
		q = ((p - (pose["pivot"] as Vector2)) / k).rotated(-float(pose["angle"])) + ((pose["pivot"] as Vector2) - (pose["pos"] as Vector2))
		drawn_rot = int(pose["rot"])
	if q.x < 0.0 or q.y < 0.0:
		return Vector2i(-1, -1)
	var cell := Vector2i((q / InventoryView.CELL).floor())
	var inst := stash.get_item(uid)
	if drawn_rot >= 0 and inst != null and drawn_rot != inst.rotation:
		var shape := inst.def.shape
		if not shape.cells_rotated(drawn_rot).has(cell):
			return Vector2i(-1, -1)
		cell = shape.transform_point(shape.untransform_point(cell, drawn_rot), inst.rotation)
	return cell


## 抓在这一件的哪一格（拖拽层反推落点用）
func grab_cell_at(uid: int, local: Vector2) -> Vector2i:
	var r := item_rect(uid)
	if r.size == Vector2.ZERO:
		return Vector2i.ZERO
	var c := _cell_under(uid, local)
	var span := Vector2i(r.size / InventoryView.CELL)
	return Vector2i(clampi(c.x, 0, maxi(0, span.x - 1)), clampi(c.y, 0, maxi(0, span.y - 1)))


## 放手：残影左上角在 [param global_top_left]，这件（朝向 [param rot]）该落在哪（归一化）。
## 压在登记的面板上就往最近的空处推开（128 §2.4）
func spot_for_drop(global_top_left: Vector2, inst: ItemInstance, rot: int) -> Vector2:
	var r := _fit(Rect2(global_top_left - global_position, span_px(inst, rot)))
	return to_spot(push_out(r).position)


func _has_point(point: Vector2) -> bool:
	if not fills_screen:
		return Rect2(Vector2.ZERO, size).has_point(point)
	# 铺满屏的那一层只有道具本身接鼠标，空地上的点击穿下去给各屏
	return uid_at_local(point) >= 0
#endregion


#region 面板占地
## 登记一块占着地方的面板（各屏打开时）；它离开树就自动撤销
func reserve(panel: Control) -> void:
	if panel == null or _reserved.has(panel):
		return
	_reserved.append(panel)
	panel.resized.connect(_settle_deferred)
	panel.visibility_changed.connect(_settle_deferred)
	panel.tree_exited.connect(func(): unreserve(panel))
	_settle_deferred()


func unreserve(panel: Control) -> void:
	if not _reserved.has(panel):
		return
	_reserved.erase(panel)
	_drop_supported(panel)     # 162 补充二：托在它上沿的再掉一次
	if is_instance_valid(panel):
		if panel.resized.is_connected(_settle_deferred):
			panel.resized.disconnect(_settle_deferred)
		if panel.visibility_changed.is_connected(_settle_deferred):
			panel.visibility_changed.disconnect(_settle_deferred)
	_sync_norms()


## 现在占着地方的面板（本控件内像素）
func reserved_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for panel in _reserved:
		if is_instance_valid(panel) and panel.is_inside_tree() and panel.is_visible_in_tree():
			var r := panel.get_global_rect()
			if r.size.x > 0.0 and r.size.y > 0.0:
				out.append(Rect2(r.position - global_position, r.size))
	return out


## 一块压在面板上就推到最近的空处（上下左右各试一下，取挪得最少、不压别的面板、在屏内的）；推不开原样返回
func push_out(r: Rect2) -> Rect2:
	var blocks := reserved_rects()
	for _round in 4:
		var hit := Rect2()
		var found := false
		for b in blocks:
			if b.intersects(r):
				hit = b
				found = true
				break
		if not found:
			return r
		var tries: Array[Vector2] = [
			Vector2(hit.position.x - r.size.x - PUSH_GAP, r.position.y),
			Vector2(hit.end.x + PUSH_GAP, r.position.y),
			Vector2(r.position.x, hit.position.y - r.size.y - PUSH_GAP),
			Vector2(r.position.x, hit.end.y + PUSH_GAP),
		]
		var best := Rect2()
		var best_d := INF
		for p in tries:
			var cand := Rect2(p, r.size)
			if cand.position.x < 0.0 or cand.position.y < 0.0 or cand.end.x > size.x or cand.end.y > size.y:
				continue
			var clear := true
			for b in blocks:
				if b.intersects(cand):
					clear = false
					break
			var d := p.distance_to(r.position) + (0.0 if clear else 100000.0)
			if d < best_d:
				best_d = d
				best = cand
		if best_d == INF:
			return r
		r = best
	return r


func _settle_deferred() -> void:
	settle.call_deferred()


## 被面板盖住的东西推开（面板关了也不挪回）
func settle() -> void:
	if not is_instance_valid(self):
		return
	_sync_norms()
	if is_inside_tree() and not is_visible_in_tree():
		return     # 地藏着（战斗回放之类）时不挪
	if stash == null or size.x <= 0.0 or size.y <= 0.0:
		return
	for inst in stash.items():
		var r := item_rect((inst as ItemInstance).uid)
		var moved := push_out(r)
		if moved.position != r.position:
			stash.set_spot((inst as ItemInstance).uid, to_spot(moved.position))
#endregion


func _gui_input(event: InputEvent) -> void:
	if stash == null or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var uid := uid_at_local(mb.position)
	if uid < 0:
		return
	if mb.double_click:
		item_double_clicked.emit(self, uid)     # 084：双击 = 快速置入棋盘
	else:
		grab_requested.emit(self, uid, mb.position)
	if not stash.has_item(uid):
		_landing.erase(uid)     # 162：半空中被抓走 —— 动画停在这一刻，拖拽层接手
	accept_event()


func _draw() -> void:
	if stash == null:
		return
	var font := label_font if label_font != null else get_theme_default_font()
	for one in stash.items():
		var inst := one as ItemInstance
		if inst.def == null:
			continue
		var r := item_rect(inst.uid)
		var cells := inst.def.cells_rotated(inst.rotation)
		var edge := COLOR_HIGHLIGHT if highlights.has(inst.uid) else ItemPainter.rarity_color(inst.def)
		var body := ItemPainter.body_color(inst.def)
		var ink := ItemPainter.label_color(inst.def)
		var at := r.position
		var landing := _landing.has(inst.uid)
		if landing:
			# 134 / 162 补充二：正在落 —— 画起手朝向的格子，绕重心转、缩放，颜色乘透明度
			var pose := landing_pose(inst.uid)
			if bool(pose["hidden"]):
				continue
			var k := float(pose["scale"])
			var alpha := float(pose["alpha"])
			var pivot: Vector2 = pose["pivot"]
			draw_set_transform(pivot, float(pose["angle"]), Vector2(k, k))
			cells = inst.def.cells_rotated(int(pose["rot"]))
			at = (pose["pos"] as Vector2) - pivot
			body.a *= alpha
			edge.a *= alpha
			ink.a *= alpha
		ItemPainter.draw_item(self, cells, at, InventoryView.CELL, body, edge)
		ItemPainter.draw_label(self, cells, at, InventoryView.CELL, Names.of_item(inst), font, 13, ink)
		if landing:
			draw_set_transform(Vector2.ZERO)

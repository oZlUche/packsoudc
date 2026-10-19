## 地上（128，作者定）：不画地上框 —— 格子外的整块屏幕就是「地上」，拖出背包放哪就在哪。
##
## 画的是一个 [ItemStash]：每件按它的形状画在自己的落点上（[member ItemStash.spots]，归一化坐标，乘回本控件尺寸），
## 和棋盘同一套画法、同一个格子尺寸，所以「放下去是什么样就是什么样」。没有框、没有标题、没有滚动条。
## 落点**只是样子**：不占格、不参与任何规则（3.4）。
## 180 §2.2（作者定）：**不重叠，相遇弹开** —— 两件相交就按半弹性碰撞分开（物件之间 e = 0.5；墙、地面、面板吸收大部分弹力 e = 0.15），
## 很快贴住；分开后的终点写回落点。只在画面层（这一类）里解算，核心层照旧不碰撞。
## 198（作者 2026-10-19）：碰撞、找支撑、推开面板、落稳朝向都按**轮廓**（[ItemSilhouette]：有道具图按透明通道，没图按格子外形），
## 不按格子的包围盒 —— L / T 能互相嵌、斜着弹开、落在真实的底边上；矩形件和以前一样。落点仍是包围盒左上角
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
## 180 §2.2：碰撞 —— 恢复系数（物件之间 / 墙、地面、面板），撞墙的反弹速度封顶（× LAND_VMAX × 屏高），
## 每次反弹后速度再乘（物件之间 / 墙），两次反弹隔得比这短就贴住，速度低于这个（像素 / 秒）算静止
const BUMP_E := 0.5
const BUMP_E_WALL := 0.15
const BUMP_WALL_VCAP := 0.5
const BUMP_AFTER := 0.5
const BUMP_AFTER_WALL := 0.3
const BUMP_STICK_SEC := 0.05
const BUMP_REST := 20.0
## 每 1/60 秒速度乘的衰减；相交时以「重叠 ÷ BUMP_SEP_SEC」的相对速度分开（封顶 BUMP_SEP_VMAX），每小步再直接推开重叠的 BUMP_FIX 成
const BUMP_DAMP := 0.85
const BUMP_SEP_SEC := 0.1
const BUMP_SEP_VMAX := 900.0
const BUMP_FIX := 0.05
## 一小步多久、最多解算多久（到时还相交的退回 [method ItemStash.next_free_spot]）、重叠不到这么多像素不算
const BUMP_STEP := 1.0 / 120.0
const BUMP_MAX_SEC := 1.0
const BUMP_EPS := 0.5

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
## 作者 2026-10-17（碰撞有延迟、没弹性）：落在哪件东西的顶上（uid → 底下那件的 uid）；底下那件被拿走 / 又掉了，这几件跟着再掉
var _rest_on: Dictionary = {}
var _scan_queued: bool = false
## 180 §2.2：正在弹开的（uid → {pos: 包围盒左上角像素, vel, m: 质量, size, floor: 地面 y, last: 上次反弹时刻, skip: 起手就压着的面板}）；
## 空 = 都静着。解算中 [method item_rect] 按这里画，结束一次写回落点
var _bodies: Dictionary = {}
var _bump_t: float = 0.0
var _bump_acc: float = 0.0
## 挤满了放弃弹开时地上有哪些（uid → true）；还是这几件就不再弹
var _bump_hold: Dictionary = {}


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
	_bodies.clear()
	_known = _uids()
	if stash != null:
		stash.landing_from.clear()
		stash.changed.connect(_on_stash_changed)
		_sync_norms()
	set_process(false)
	wake_bumps()
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
	for uid in _rest_on.keys():
		if not now.has(uid):
			_rest_on.erase(uid)
	for uid in _known.keys():
		if not now.has(uid):
			_drop_resting_on(uid)     # 底下那件被拿走了
	for uid in _bodies.keys():
		if not now.has(uid):
			_bodies.erase(uid)
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
	wake_bumps()     # 180：读档 / 程序摆的有重叠也弹开
	_sync_process()
	queue_redraw()


## 一件从 [param from_local]（本控件内像素，现在朝向的包围盒左上角）往下掉：算地、算落稳朝向，改落点与朝向（核心层的状态立刻是终态），记一段动画
func _begin_fall(inst: ItemInstance, from_local: Vector2, stagger: float) -> void:
	if inst.def == null or inst.def.shape == null:
		return
	var rot_from := inst.rotation
	var rot_to := ItemSilhouette.rest_rotation(inst.def, rot_from)
	var land := spot_below(from_local, inst, rot_from, rot_to)
	inst.rotation = rot_to
	var target: Vector2 = land["pos"]
	if land["panel"] != null:
		_support[inst.uid] = land["panel"]
	else:
		_support.erase(inst.uid)
	if int(land.get("item", -1)) >= 0:
		_rest_on[inst.uid] = int(land["item"])
	else:
		_rest_on.erase(inst.uid)
	_landing[inst.uid] = _fall(inst, from_local, rot_from, target, rot_to, stagger, false)
	stash.set_spot(inst.uid, to_spot(target))
	_drop_resting_on(inst.uid)     # 托在它上面的跟着再掉


## 162 补充二：起点 [param from_local]（朝向 [param rot_from] 的包围盒左上角）正下方的落点：重心 x 不变（夹在屏内），
## 包围盒底边对齐起点的底边，再往下掉到第一个支撑（[method floor_under]）上。返回 {pos: 落稳后（朝向 [param rot_to]）包围盒左上角, panel: 托着它的面板或 null}
## 198：重心 = 轮廓的面积重心
func spot_below(from_local: Vector2, inst: ItemInstance, rot_from: int, rot_to: int) -> Dictionary:
	var span_to := span_px(inst, rot_to)
	var com_x := from_local.x + ItemSilhouette.centroid(inst.def, rot_from).x
	var x := clampf(com_x - ItemSilhouette.centroid(inst.def, rot_to).x, 0.0, maxf(0.0, size.x - span_to.x))
	var start := Vector2(x, from_local.y + span_px(inst, rot_from).y - span_to.y)
	var under := floor_under(ItemSilhouette.of(inst.def, rot_to)["parts"], start, inst.uid)
	return {"pos": Vector2(x, maxf(0.0, start.y + float(under["dy"]))), "panel": under["panel"], "item": under["item"]}


## 162 补充二：轮廓 [param parts]（包围盒左上角在 [param pos]）竖直往下第一个支撑：登记面板的上沿（{dy: 还能掉多远, panel}），没有就是屏幕底（panel = null）。
## 作者 2026-10-17：地上别的东西的顶也是支撑（{item: 它的 uid}，不然穿过去落到底、落稳了才被弹开 —— 看着既慢又软）；[param self_uid] 是正在掉的那件自己。
## 198：按轮廓竖直投射（[method ItemSilhouette.drop_gap]）—— 落在对方真实的上边上，L 的缺角里放得下就落进去；起手就压着的不算支撑
func floor_under(parts: Array, pos: Vector2, self_uid: int = -1) -> Dictionary:
	var box := ItemSilhouette.bounds_of(parts)
	box.position += pos
	var best := size.y * (1.0 - ItemStash.SPOT_MARGIN) - box.end.y
	var by: Control = null
	var on_item := -1
	if stash != null:
		for it in stash.items():
			var inst := it as ItemInstance
			if inst.uid == self_uid or inst.def == null:
				continue
			var r := item_rect(inst.uid)
			if r.size.x <= 0.0 or r.position.x >= box.end.x - BUMP_EPS or r.end.x <= box.position.x + BUMP_EPS:
				continue
			var gap := ItemSilhouette.drop_gap(parts, pos, _parts(inst), r.position, BUMP_EPS)
			if gap < best:
				best = gap
				on_item = inst.uid
	for panel in _reserved:
		if not is_instance_valid(panel) or not panel.is_inside_tree() or not panel.is_visible_in_tree():
			continue
		var g := panel.get_global_rect()
		var r := Rect2(g.position - global_position, g.size)
		if r.size.x <= 0.0 or r.size.y <= 0.0 or r.position.x >= box.end.x or r.end.x <= box.position.x:
			continue
		var gap := ItemSilhouette.drop_gap(parts, pos, [ItemSilhouette.rect_poly(r)], Vector2.ZERO)
		if gap < best:
			best = gap
			by = panel
			on_item = -1
	return {"dy": best, "panel": by, "item": on_item}


## 198：这件此刻朝向（或 [param rot]）的轮廓凸块
static func _parts(inst: ItemInstance, rot: int = -1) -> Array:
	if inst == null or inst.def == null:
		return []
	return ItemSilhouette.of(inst.def, inst.rotation if rot < 0 else rot)["parts"]


## 底下那件 [param uid] 没了 / 挪了：托在它顶上的从现在的位置再掉一次（再往上托着的跟着掉）
func _drop_resting_on(uid: int) -> void:
	if stash == null:
		return
	for top in _rest_on.keys():
		if int(_rest_on[top]) != uid:
			continue
		_rest_on.erase(top)
		var inst := stash.get_item(top)
		if inst == null:
			continue
		var at := item_rect(top).position
		_landing.erase(top)
		_bodies.erase(top)
		_begin_fall(inst, at, 0.0)


## 一段下落：重心从起点到终点，竖直按重力（沉的不封顶、飘的到末速度封顶），横向线性（只有夹边时才有），翻转 / 缩放 / 透明跟落了几成走；触地后弹一下
func _fall(inst: ItemInstance, from_local: Vector2, rot_from: int, to_local: Vector2, rot_to: int, stagger: float, in_place: bool) -> Dictionary:
	var prof := land_profile(inst.def)
	var com_from := ItemSilhouette.centroid(inst.def, rot_from)     # 198：转轴 = 轮廓重心
	var com_to := ItemSilhouette.centroid(inst.def, rot_to)
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
		_bodies.erase(uid)
		_begin_fall(inst, item_rect(uid).position, 0.0)
	_sync_process()
	queue_redraw()


## 托着这件的面板（测试看；没有 null）
func support_of(uid: int) -> Control:
	return _support.get(uid, null)


func _process(delta: float) -> void:
	advance_landing(delta)
	advance_bumps(delta)


func _sync_process() -> void:
	set_process(not _landing.is_empty() or not _bodies.is_empty())


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
		_sync_process()
		return
	var landed := false
	for uid in _landing.keys():
		var a: Dictionary = _landing[uid]
		a["t"] = float(a["t"]) + delta
		if float(a["t"]) >= float(a["sec"]):
			_landing.erase(uid)
			landed = true
	if landed:
		wake_bumps()     # 180：落稳了压着别人就弹开
	_sync_process()
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
		var com := ItemSilhouette.centroid(inst.def, rot) if inst != null and inst.def != null and inst.def.shape != null else r.size * 0.5
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
	if not _bodies.is_empty():
		_finish_bumps()     # 像素坐标跟着尺寸变了：先写回，再按新尺寸重新看
	wake_bumps()
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
	if _bodies.has(uid):
		return Rect2(_bodies[uid]["pos"], span_px(inst, inst.rotation))
	return _fit(Rect2(stash.spot_of(uid) * size, span_px(inst, inst.rotation)))


func _fit(r: Rect2) -> Rect2:
	var p := Vector2(
		clampf(r.position.x, 0.0, maxf(0.0, size.x - r.size.x)),
		clampf(r.position.y, 0.0, maxf(0.0, size.y - r.size.y)))
	return Rect2(p, r.size)


## 鼠标下最上面那一件（后放的在上）；没有 -1。162：半空中的也接（按它此刻画在哪、多大），排队还没出现的不接。
## 198：有道具图的（落稳的）按透明通道点，透明的角点不着；没图按格子
func uid_at_local(p: Vector2) -> int:
	if stash == null:
		return -1
	var list := stash.items()
	for i in range(list.size() - 1, -1, -1):
		var inst := list[i] as ItemInstance
		if _landing.has(inst.uid) and bool(landing_pose(inst.uid)["hidden"]):
			continue
		if not _landing.has(inst.uid) and inst.def != null and ItemSilhouette.of(inst.def, inst.rotation)["mask"] != null:
			if ItemSilhouette.hit(inst.def, inst.rotation, p - item_rect(inst.uid).position):
				return inst.uid
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
	return to_spot(push_out(r, _parts(inst, rot)).position)


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


## 一块压在面板上就推到最近的空处（上下左右各试一下，取挪得最少、不压别的面板、在屏内的）；推不开原样返回。
## 198：「压没压着」按轮廓 [param parts]（从包围盒左上角量；不给 = 整个包围盒）—— 只是缺角伸进面板不算压着
func push_out(r: Rect2, parts: Array = []) -> Rect2:
	var blocks := reserved_rects()
	if parts.is_empty():
		parts = [ItemSilhouette.rect_poly(Rect2(Vector2.ZERO, r.size))]
	for _round in 4:
		var hit := Rect2()
		var found := false
		for b in blocks:
			if _presses(parts, r.position, b):
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
				if _presses(parts, cand.position, b):
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


## 轮廓 [param parts]（摆在 [param pos]）压没压着面板 [param panel]
static func _presses(parts: Array, pos: Vector2, panel: Rect2) -> bool:
	return float(ItemSilhouette.separate(parts, pos, [ItemSilhouette.rect_poly(panel)], Vector2.ZERO)["depth"]) > 0.0


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
		var moved := push_out(r, _parts(inst))
		if moved.position != r.position:
			_bodies.erase((inst as ItemInstance).uid)
			stash.set_spot((inst as ItemInstance).uid, to_spot(moved.position))
	wake_bumps()
#endregion


#region 相遇弹开（180 §2.2）
## 地上（不在落的）两两相交的（uid 对；测试看「任何时候都不重叠」）。198：按轮廓，压进去超过 [constant BUMP_EPS] 才算
func overlapping_pairs() -> Array:
	var out: Array = []
	if stash == null:
		return out
	var at := {}
	var parts := {}
	for inst in stash.items():
		var it := inst as ItemInstance
		if not _landing.has(it.uid) and it.def != null:
			at[it.uid] = item_rect(it.uid).position
			parts[it.uid] = _parts(it)
	var keys := at.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var hit := ItemSilhouette.separate(parts[keys[i]], at[keys[i]], parts[keys[j]], at[keys[j]])
			if float(hit["depth"]) > BUMP_EPS:
				out.append([keys[i], keys[j]])
	return out


## 有相交的就开始弹开：地上不在落的每件都成一个物体（被撞到的邻居也会动）。地藏着、没尺寸时不动
func wake_bumps() -> void:
	if not _bodies.is_empty() or stash == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if is_inside_tree() and not is_visible_in_tree():
		return
	if not _bump_hold.is_empty() and _bump_hold == _uids():
		return
	if overlapping_pairs().is_empty():
		return
	var ground_y := size.y * (1.0 - ItemStash.SPOT_MARGIN)
	var walls := reserved_rects()
	for inst in stash.items():
		var it := inst as ItemInstance
		if _landing.has(it.uid) or it.def == null:
			continue
		var r := item_rect(it.uid)
		var parts := _parts(it)
		var box := ItemSilhouette.bounds_of(parts)
		var skip: Array[int] = []
		for i in walls.size():
			if _presses(parts, r.position, walls[i]):
				skip.append(i)     # 起手就压着的面板不当墙（那是 settle 的事），免得一推推出屏
		_bodies[it.uid] = {"pos": r.position, "vel": Vector2.ZERO, "m": maxf(0.5, float(ItemWeight.of(it.def))),
			"size": r.size, "parts": parts, "box": box, "floor": maxf(ground_y, r.position.y + box.end.y), "last": -INF, "skip": skip}
	_bump_t = 0.0
	_bump_acc = 0.0
	_sync_process()


## 是不是正在弹开
func is_bumping() -> bool:
	return not _bodies.is_empty()


## 推进弹开 [param delta] 秒（按 [constant BUMP_STEP] 小步走；测试直接调）
func advance_bumps(delta: float) -> void:
	if _bodies.is_empty():
		return
	for uid in _bodies.keys():
		if stash == null or not stash.has_item(uid) or _landing.has(uid):
			_bodies.erase(uid)     # 被抓走、又在落
	_bump_acc += delta
	while _bump_acc >= BUMP_STEP and not _bodies.is_empty():
		_bump_acc -= BUMP_STEP
		_bump_t += BUMP_STEP
		if _bump_step(BUMP_STEP) or _bump_t >= BUMP_MAX_SEC:
			_finish_bumps()
	_sync_process()
	queue_redraw()


## 一口气解算到底（测试、不在树里时）
func settle_bumps() -> void:
	while not _bodies.is_empty():
		advance_bumps(BUMP_STEP)


## 一小步：走、物件两两分开、撞墙。返回「都静了且不再相交」
func _bump_step(h: float) -> bool:
	var damp := pow(BUMP_DAMP, h * 60.0)
	for b in _bodies.values():
		b["pos"] = (b["pos"] as Vector2) + (b["vel"] as Vector2) * h
	var keys := _bodies.keys()
	var touching := false
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if _bump_pair(_bodies[keys[i]], _bodies[keys[j]], int(keys[i]) < int(keys[j])):
				touching = true
	var walls := reserved_rects()
	var cap := BUMP_WALL_VCAP * LAND_VMAX * _screen_h()
	var still := not touching
	for b in _bodies.values():
		_bump_walls(b, walls, cap)
		var v: Vector2 = (b["vel"] as Vector2) * damp
		if v.length() < BUMP_REST:
			v = Vector2.ZERO
		b["vel"] = v
		if v != Vector2.ZERO:
			still = false
	return still


## 一对：相交就沿分离轴分开（198：轮廓的 SAT 给的方向，任意角度；矩形件就是重叠较小的那条轴）——
## 迎面来的先按 e = 0.5 反弹（按质量反比分），再把分开的相对速度补到「重叠 ÷ BUMP_SEP_SEC」，外加直接推开一点。返回是否相交
func _bump_pair(a: Dictionary, b: Dictionary, a_first: bool) -> bool:
	var hit := ItemSilhouette.separate(a["parts"], a["pos"], b["parts"], b["pos"], 1.0 if a_first else -1.0)
	var depth := float(hit["depth"])
	if depth <= BUMP_EPS:
		return false
	var n: Vector2 = hit["n"]
	var ia := 1.0 / float(a["m"])
	var ib := 1.0 / float(b["m"])
	var va: Vector2 = a["vel"]
	var vb: Vector2 = b["vel"]
	var vn := (vb - va).dot(n)
	if vn < 0.0:
		var j := -(1.0 + BUMP_E) * vn / (ia + ib)
		va = (va - n * j * ia) * BUMP_AFTER
		vb = (vb + n * j * ib) * BUMP_AFTER
		if _bump_t - float(a["last"]) < BUMP_STICK_SEC:
			va = Vector2.ZERO
		if _bump_t - float(b["last"]) < BUMP_STICK_SEC:
			vb = Vector2.ZERO
		a["last"] = _bump_t
		b["last"] = _bump_t
		vn = (vb - va).dot(n)
	var want := minf(depth / BUMP_SEP_SEC, BUMP_SEP_VMAX)
	if vn < want:
		var k := (want - vn) / (ia + ib)
		va -= n * k * ia
		vb += n * k * ib
	a["vel"] = va
	b["vel"] = vb
	var fix := depth * BUMP_FIX / (ia + ib)
	a["pos"] = (a["pos"] as Vector2) - n * fix * ia
	b["pos"] = (b["pos"] as Vector2) + n * fix * ib
	return true


## 撞墙：屏边、地面、登记的面板都是推不动的，但吸收大部分弹力（e = 0.15，反弹速度封顶 [param cap]），撞完速度再乘 0.3；
## 两次撞墙隔得太近就贴住。198：屏边、地面碰的是轮廓最左 / 最右 / 最高 / 最低的顶点，面板按轮廓的 SAT
func _bump_walls(b: Dictionary, walls: Array[Rect2], cap: float) -> void:
	var pos: Vector2 = b["pos"]
	var box: Rect2 = b["box"]
	var v: Vector2 = b["vel"]
	var hit := false
	var lo := -box.position
	var hi := Vector2(maxf(lo.x, size.x - box.end.x), maxf(lo.y, float(b["floor"]) - box.end.y))
	for axis in 2:
		if pos[axis] < lo[axis]:
			pos[axis] = lo[axis]
			if v[axis] < 0.0:
				v[axis] = minf(-v[axis] * BUMP_E_WALL, cap)
				hit = true
		elif pos[axis] > hi[axis]:
			pos[axis] = hi[axis]
			if v[axis] > 0.0:
				v[axis] = -minf(v[axis] * BUMP_E_WALL, cap)
				hit = true
	var skip: Array[int] = b["skip"]
	for i in walls.size():
		if skip.has(i):
			continue
		var sep := ItemSilhouette.separate(b["parts"], pos, [ItemSilhouette.rect_poly(walls[i])], Vector2.ZERO)
		var depth := float(sep["depth"])
		if depth <= 0.0:
			continue
		var n: Vector2 = sep["n"]     # 指向面板：往 −n 推出来
		pos -= n * depth
		var vn := v.dot(n)
		if vn > 0.0:
			v = v - n * vn - n * minf(vn * BUMP_E_WALL, cap)
			hit = true
	if hit:
		v *= BUMP_AFTER_WALL
		if _bump_t - float(b["last"]) < BUMP_STICK_SEC:
			v = Vector2.ZERO
		b["last"] = _bump_t
	b["pos"] = pos
	b["vel"] = v


## 收尾：动过的写回落点；到时还相交的（地上挤满了）退回网格扫出来的空处
func _finish_bumps() -> void:
	var bodies := _bodies
	_bodies = {}
	if stash == null:
		return
	var moved: Array[int] = []
	for uid in bodies.keys():
		if stash.has_item(uid):
			var p := to_spot(bodies[uid]["pos"])
			if not stash.spot_of(uid).is_equal_approx(p):
				stash.set_spot(uid, p)
				moved.append(uid)
	for pair in overlapping_pairs():
		var inst := stash.get_item(pair[1])
		if inst != null:
			stash.set_spot(inst.uid, stash.next_free_spot(inst))
	# 地上真挤满了（扫也扫不出空处）：这一批不再反复弹，等地上的东西变了再说
	_bump_hold = _uids() if not overlapping_pairs().is_empty() else {}
	# 作者 2026-10-17：弹开后悬空的（被推离了托着它的那件）掉下去；托在挪走那件上的也掉
	moved.sort_custom(func(a: int, b: int) -> bool: return item_rect(a).end.y > item_rect(b).end.y)     # 低的先落，上面的落在它的新位置上
	for uid in moved:
		_refall_if_hanging(uid)
		_drop_resting_on(uid)


## 这件底下离支撑还有空（悬着）就从现在的位置掉下去
func _refall_if_hanging(uid: int) -> void:
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null or inst.def == null or inst.def.shape == null or _landing.has(uid):
		return
	var at := item_rect(uid).position
	var land := spot_below(at, inst, inst.rotation, ItemSilhouette.rest_rotation(inst.def, inst.rotation))
	if (land["pos"] as Vector2).y > at.y + 1.0:
		_rest_on.erase(uid)
		_begin_fall(inst, at, 0.0)
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
		var base := Transform2D.IDENTITY
		var tint := Color.WHITE
		var rot := inst.rotation
		if landing:
			# 134 / 162 补充二：正在落 —— 画起手朝向的格子，绕重心转、缩放，颜色乘透明度
			var pose := landing_pose(inst.uid)
			if bool(pose["hidden"]):
				continue
			var k := float(pose["scale"])
			var alpha := float(pose["alpha"])
			var pivot: Vector2 = pose["pivot"]
			draw_set_transform(pivot, float(pose["angle"]), Vector2(k, k))
			base = Transform2D(float(pose["angle"]), Vector2(k, k), 0.0, pivot)
			rot = int(pose["rot"])
			tint.a = alpha
			cells = inst.def.cells_rotated(rot)
			at = (pose["pos"] as Vector2) - pivot
			body.a *= alpha
			edge.a *= alpha
			ink.a *= alpha
		# 201：有图就画图、不写名字；base 是落地动画的变换（相乘，不覆盖）
		if not ItemPainter.draw_art(self, inst.def, rot, at, InventoryView.CELL, tint, base):
			ItemPainter.draw_item(self, cells, at, InventoryView.CELL, body, edge)
			ItemPainter.draw_label(self, cells, at, InventoryView.CELL, Names.of_item(inst), font, 13, ink)
		var sil := ItemSilhouette.of(inst.def, rot)
		if sil["mask"] != null:     # 198：有道具图的描边 / 高亮沿轮廓走（没图的格子已经沿外形描过了）
			for poly in (sil["outline"] as Array):
				var line := (poly as PackedVector2Array).duplicate()
				line.append(line[0])
				for k in line.size():
					line[k] += at
				draw_polyline(line, edge, 2.0)
		if landing:
			draw_set_transform(Vector2.ZERO)

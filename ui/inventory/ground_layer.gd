## 地上（128，作者定）：不画地上框 —— 格子外的整块屏幕就是「地上」，拖出背包放哪就在哪。
##
## 画的是一个 [ItemStash]：每件按它的形状画在自己的落点上（[member ItemStash.spots]，归一化坐标，乘回本控件尺寸），
## 和棋盘同一套画法、同一个格子尺寸，所以「放下去是什么样就是什么样」。没有框、没有标题、没有滚动条。
## 落点**只是样子**：不占格、不参与任何规则（3.4）。
## 180 §2.2（作者定）：**不重叠，相遇弹开** —— 两件相交就按半弹性碰撞分开（物件之间 e = 0.5；墙、地面、面板吸收大部分弹力 e = 0.15），
## 很快贴住；分开后的终点写回落点。只在画面层（这一类）里解算，核心层照旧不碰撞。
## 198（作者 2026-10-19）：碰撞、找支撑、推开面板、落稳朝向都按**轮廓**（[ItemSilhouette]：有道具图按透明通道，没图按格子外形），
## 不按格子的包围盒 —— L / T 能互相嵌、斜着弹开、落在真实的底边上；矩形件和以前一样。落点仍是包围盒左上角。
## 198 补充一（作者 2026-10-19 选「自由角度」）：地上的东西可以**斜着躺** —— 四向（[member ItemInstance.rotation]）之外每件多一个斜度
## （[method ItemStash.tilt_of]，绕轮廓重心转，(−45°, 45°]）；解算补上转动、重力、摩擦，落在堆上的会翻、会靠、会滑到停。捡起来斜度即丢
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
## 相交时以「重叠 ÷ BUMP_SEP_SEC」的速度挪开（只挪位置、不留速度，封顶 BUMP_SEP_VMAX），每小步再直接推开重叠的 BUMP_FIX 成
const BUMP_SEP_SEC := 0.1
const BUMP_SEP_VMAX := 900.0
const BUMP_FIX := 0.05
## 一小步多久、一件最多醒着解算多久（198 补充一：翻一下再滑停比弹开慢；到时这件冻住，§7.3）、一整轮最多多久（从最后一次有新落稳的 / 被叫醒的算起：
## 互相撞醒个没完时的兜底；到时都冻住，还相交的先就地推开 [constant BUMP_RELAX_MAX] 像素以内的，再不行退回 [method ItemStash.next_free_spot]）、重叠不到这么多像素不算
const BUMP_STEP := 1.0 / 120.0
const BUMP_MAX_SEC := 1.5
const BUMP_RUN_MAX_SEC := 6.0
const BUMP_EPS := 0.5
const BUMP_RELAX_MAX := 4.0
const BUMP_REFALL_MAX := 2
## 198 补充一：摩擦系数（物件之间 / 地面、面板、屏边），角速度低于这个（弧度 / 秒）算不转，静着（且有接触、没在被推开）连续这么久就睡着，
## 每小步冲量迭代几轮，压进去这么深以内不推（贴着的不抖），隔这么近（像素）就算接触，斜不到这么多（弧度，约 0.5°）收尾时摆正，
## 找支撑时离这么近（像素）算托着
const BUMP_MU := 0.6
const BUMP_MU_WALL := 0.8
const BUMP_W_REST := 0.2
const BUMP_SLEEP_SEC := 0.1
## 重心不在接触点区间上方的（斜卡在别的东西和墙之间之类）静这么久也睡（真在往下倒的这么久早就快起来了）
const BUMP_SLEEP_WEDGED_SEC := 0.5
## 角速度封顶（弧度 / 秒）
const BUMP_W_MAX := 12.0
const BUMP_ITERS := 8
const BUMP_SLOP := 0.25
const BUMP_TOUCH := 0.5
const BUMP_TILT_SNAP := 0.0087
## 摆正后往下贴回支撑最多挪多少像素（再远就当悬着，收尾时掉下去）
const BUMP_SNAP_SEAT := 4.0
const SUPPORT_TOUCH := 1.0
## 249：用手甩到地上 —— 拖拽层记松手前多久的鼠标（秒）、最多几个样本；乘过密度因子后快过 THROW_MIN（屏高 / 秒）才算甩（慢的照旧竖直掉），
## 封顶 THROW_VMAX；密度因子 = 1 / (1 + 密度 / THROW_DENSITY)。都是占位数，按手感调
const THROW_WINDOW_SEC := 0.09
const THROW_SAMPLES := 8
const THROW_MIN := 0.15
const THROW_VMAX := 1.6
const THROW_DENSITY := 2.0

## 249：甩出去的那件第一次撞上地面 / 墙 / 面板（过撞击线）—— 这一下响落地声
signal thrown_landed(uid: int)

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
## 作者 2026-10-17（碰撞有延迟、没弹性）：落在哪件东西的顶上（uid → 底下那件的 uid）；底下那件被拿走 / 又掉了，这几件跟着再掉
var _rest_on: Dictionary = {}
## 正在让托在它上面的再掉的（uid → true；防托着的关系绕成圈时来回掉）
var _dropping: Dictionary = {}
var _scan_queued: bool = false
## 180 §2.2：正在解算的（uid → 一个物体，见 [method _new_body]）；空 = 都静着。解算中 [method item_rect] / [method tilt_of] 按这里画，结束一次写回落点与斜度
var _bodies: Dictionary = {}
var _bump_t: float = 0.0
var _bump_start: float = 0.0
## 198 补充一：解算收尾时又落了几次（翻倒 / 悬着）—— 够 [constant BUMP_REFALL_MAX] 次的再落稳就不再按站不住解算（同一处落了翻、翻了落的兜底）
var _refalls: Dictionary = {}
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
	for uid in _rest_on.keys():
		if not now.has(uid):
			_rest_on.erase(uid)
	for uid in _refalls.keys():
		if not now.has(uid):
			_refalls.erase(uid)
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
		var vel: Vector2 = stash.landing_vel.get(uid, Vector2.ZERO)
		stash.landing_vel.erase(uid)
		if from is bool and not from:
			continue     # 本来就在（读档、回到存过东西的点）
		var stagger := -LAND_STAGGER * mini(k, LAND_STAGGER_MAX)
		if from is Vector2 and vel.length() >= THROW_MIN * _screen_h():
			_begin_throw(inst, (from as Vector2) - global_position, vel)     # 249：甩出去的，带着手上的速度飞
		elif from is Vector2:
			# 253：松手点压着面板时，放下那一刻推开过的落点（[method spot_for_drop]）—— 竖直掉的 x 用推开后的那个
			var at := (from as Vector2) - global_position
			at.x = push_out(_fit(Rect2(at, span_px(inst, inst.rotation))), _parts(inst)).position.x
			_begin_fall(inst, at, stagger)
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
## [param carry]：托在它上面的跟着再掉（198 补充一：解算收尾时不连带 —— 上面的各自看还悬不悬着，低的先落）
func _begin_fall(inst: ItemInstance, from_local: Vector2, stagger: float, carry: bool = true) -> void:
	if inst.def == null or inst.def.shape == null:
		return
	var rot_from := inst.rotation
	var tilt_from := stash.tilt_of(inst.uid)     # 198 补充一：从斜着的姿态起落，落完是四向之一
	var rot_to := ItemSilhouette.rest_rotation(inst.def, rot_from)
	var land := spot_below(from_local, inst, rot_from, rot_to)
	stash.set_tilt(inst.uid, 0.0)
	inst.rotation = rot_to
	var target: Vector2 = land["pos"]
	if int(land.get("item", -1)) >= 0:
		_rest_on[inst.uid] = int(land["item"])
	else:
		_rest_on.erase(inst.uid)
	_landing[inst.uid] = _fall(inst, from_local, rot_from, target, rot_to, stagger, false, tilt_from)
	stash.set_spot(inst.uid, to_spot(target))
	if carry:
		_drop_resting_on(inst.uid)     # 托在它上面的跟着再掉


## 249：手甩出去的一件 —— 不走竖直掉，起手就是醒着的刚体：从松手时残影的位置 [param from_local]、带着速度 [param vel]（全局像素 / 秒，
## 已乘密度因子，这里封顶 [constant THROW_VMAX] 屏高 / 秒）飞出去，不带角速度。重力、撞地 / 屏边 / 面板、砸醒别的、滑行翻倒都交给 198 的解算
func _begin_throw(inst: ItemInstance, from_local: Vector2, vel: Vector2) -> void:
	if inst.def == null or inst.def.shape == null:
		return
	stash.set_tilt(inst.uid, 0.0)
	stash.set_spot(inst.uid, to_spot(from_local))     # 落点由解算收尾时改成真正停下的地方
	_rest_on.erase(inst.uid)
	if _bodies.is_empty():
		_bump_t = 0.0
		_bump_acc = 0.0
	_bump_start = _bump_t
	var b := _new_body(inst, size.y * (1.0 - ItemStash.SPOT_MARGIN), true, from_local)
	b["vel"] = vel.limit_length(THROW_VMAX * _screen_h())
	b["thrown"] = true
	_bodies[inst.uid] = b


## 249：甩出去的速度乘多少 —— 越密越沉、手一样快也飞得近：1 / (1 + 密度 / [constant THROW_DENSITY])；密度 = 重 ÷ 格数（包重 0 → 1）
static func throw_factor(def: ItemDef) -> float:
	var cells := def.cell_count() if def != null else 0
	var density := float(ItemWeight.of(def)) / cells if cells > 0 else 0.0
	return 1.0 / (1.0 + density / THROW_DENSITY)


## 162 补充二：起点 [param from_local]（朝向 [param rot_from] 的包围盒左上角）正下方的落点：重心 x 不变（夹在屏内），
## 包围盒底边对齐起点的底边，再往下掉到第一个支撑（[method floor_under]）上。返回 {pos: 落稳后（朝向 [param rot_to]）包围盒左上角, item: 托着它的那件或 -1}
## 198：重心 = 轮廓的面积重心
func spot_below(from_local: Vector2, inst: ItemInstance, rot_from: int, rot_to: int) -> Dictionary:
	var span_to := span_px(inst, rot_to)
	var com_x := from_local.x + ItemSilhouette.centroid(inst.def, rot_from).x
	var x := clampf(com_x - ItemSilhouette.centroid(inst.def, rot_to).x, 0.0, maxf(0.0, size.x - span_to.x))
	var start := Vector2(x, from_local.y + span_px(inst, rot_from).y - span_to.y)
	var under := floor_under(ItemSilhouette.of(inst.def, rot_to)["parts"], start, inst.uid)
	return {"pos": Vector2(x, maxf(0.0, start.y + float(under["dy"]))), "item": under["item"]}


## 162 补充二：轮廓 [param parts]（包围盒左上角在 [param pos]）竖直往下第一个支撑（{dy: 还能掉多远}），没有就是屏幕底。
## 253（作者 2026-10-25「道具拿出棋盘外时有时候会吸附在背包界面的边缘，尤其是上缘」）：登记的面板不再是桌面 —— 东西竖直掉过窗面落到下面，落稳后压着面板的才推开（[method _push_off_panels]）。
## 作者 2026-10-17：地上别的东西的顶也是支撑（{item: 它的 uid}，不然穿过去落到底、落稳了才被弹开 —— 看着既慢又软）；[param self_uid] 是正在掉的那件自己。
## 198：按轮廓竖直投射（[method ItemSilhouette.drop_gap]）—— 落在对方真实的上边上，L 的缺角里放得下就落进去；起手就压着的不算支撑
func floor_under(parts: Array, pos: Vector2, self_uid: int = -1) -> Dictionary:
	var box := ItemSilhouette.bounds_of(parts)
	box.position += pos
	var best := size.y * (1.0 - ItemStash.SPOT_MARGIN) - box.end.y
	var on_item := -1
	if stash != null:
		for it in stash.items():
			var inst := it as ItemInstance
			if inst.uid == self_uid or inst.def == null:
				continue
			var r := item_bounds(inst.uid)
			if r.size.x <= 0.0 or r.position.x >= box.end.x - BUMP_EPS or r.end.x <= box.position.x + BUMP_EPS:
				continue
			var gap := ItemSilhouette.drop_gap(parts, pos, _parts_of(inst.uid), item_rect(inst.uid).position, BUMP_EPS)
			if gap < best:
				best = gap
				on_item = inst.uid
	return {"dy": best, "item": on_item}


## 198：这件此刻朝向（或 [param rot]）不斜时的轮廓凸块（斜着的用 [method _parts_of]）
static func _parts(inst: ItemInstance, rot: int = -1) -> Array:
	if inst == null or inst.def == null:
		return []
	return ItemSilhouette.of(inst.def, inst.rotation if rot < 0 else rot)["parts"]


## 底下那件 [param uid] 没了 / 挪了：托在它顶上的从现在的位置（斜着的从斜着的姿态）再掉一次（再往上托着的跟着掉）
func _drop_resting_on(uid: int) -> void:
	if stash == null or _dropping.has(uid):
		return
	_dropping[uid] = true     # 斜靠着的互相托着时不会来回掉个没完
	for top in _rest_on.keys():
		if int(_rest_on.get(top, -1)) != uid:
			continue     # 前面掉下去的连带着已经挪走了的也跳过
		_rest_on.erase(top)
		var inst := stash.get_item(top)
		if inst == null:
			continue
		var at := item_rect(top).position
		_landing.erase(top)
		_bodies.erase(top)
		_begin_fall(inst, at, 0.0)
	_dropping.erase(uid)


## 一段下落：重心从起点到终点，竖直按重力（沉的不封顶、飘的到末速度封顶），横向线性（只有夹边时才有），翻转 / 缩放 / 透明跟落了几成走；触地后弹一下。
## [param tilt_from]：起手斜着多少（198 补充一，再掉一次的斜着的件），途中转回四向
func _fall(inst: ItemInstance, from_local: Vector2, rot_from: int, to_local: Vector2, rot_to: int, stagger: float, in_place: bool, tilt_from: float = 0.0) -> Dictionary:
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
		"sec": t_hit + LAND_BOUNCE_SEC, "amp": amp, "rot_from": rot_from, "turn": turn, "tilt_from": tilt_from, "com_from": com_from,
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


## 206：这几件同时落稳响哪一声：有一件是沉的（[method land_profile] 的 `sink`）就是重的
func landing_cue(uids: Array) -> StringName:
	for uid in uids:
		var inst := stash.get_item(int(uid)) if stash != null else null
		if inst != null and bool(land_profile(inst.def)["sink"]):
			return &"bag.land.heavy"
	return &"bag.land.light"


## 推进落地动画 [param delta] 秒（测试直接调）
func advance_landing(delta: float) -> void:
	if _landing.is_empty():
		_sync_process()
		return
	var landed: Array = []
	for uid in _landing.keys():
		var a: Dictionary = _landing[uid]
		a["t"] = float(a["t"]) + delta
		if float(a["t"]) >= float(a["sec"]):
			_landing.erase(uid)
			landed.append(uid)
	if not landed.is_empty():
		AudioHub.play(landing_cue(landed))     # 206：一帧落稳几件只响一声，按最重的那件
		_push_off_panels(landed)     # 253：落稳时压着面板的往两边推开
		wake_bumps(landed)     # 180：落稳了压着别人就弹开；198 补充一：站不住的翻下去
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
## "rot": 画的是哪个朝向的格子, "scale", "alpha", "hidden": 还在排队}。没在落 = 落点、现在的朝向、斜度（198 补充一）、1、1
func landing_pose(uid: int) -> Dictionary:
	var r := item_rect(uid)
	var inst := stash.get_item(uid) if stash != null else null
	var rot := inst.rotation if inst != null else 0
	if not _landing.has(uid):
		var com := ItemSilhouette.centroid(inst.def, rot) if inst != null and inst.def != null and inst.def.shape != null else r.size * 0.5
		return {"pos": r.position, "pivot": r.position + com, "angle": tilt_of(uid), "rot": rot, "scale": 1.0, "alpha": 1.0, "hidden": false}
	var a: Dictionary = _landing[uid]
	var prof: Dictionary = a["profile"]
	var t := float(a["t"])
	var com_from: Vector2 = a["com_from"]
	var p0: Vector2 = a["p0"]
	var tilt0 := float(a.get("tilt_from", 0.0))
	if t < 0.0:
		return {"pos": p0 - com_from, "pivot": p0, "angle": tilt0, "rot": a["rot_from"], "scale": float(prof["scale"]), "alpha": 0.0, "hidden": true}
	var s := _fall_progress(a, t)
	var pivot := p0.lerp(a["p1"], s)
	if bool(a["falls"]):
		pivot.x += float(prof["sway"]) * sin(TAU * s)     # 飘的左右荡下来；沉的摆幅 0
	if t > float(a["t_hit"]):
		pivot.y -= float(a["amp"]) * sin(PI * clampf((t - float(a["t_hit"])) / LAND_BOUNCE_SEC, 0.0, 1.0))
	var angle := tilt0 + (float(a["turn"]) - tilt0) * s * s     # 缓入：越落转得越快，触地正好转到位
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


## 一件画在哪（本控件内像素）：落点乘回尺寸，再整块夹进屏里 —— 换了窗口大小东西也还在屏内。
## 198 补充一：给的是**不斜时**的包围盒（斜着的绕它的轮廓重心再转 [method tilt_of]）；斜着的落点记的是斜着的包围盒（[method _spot_off]），夹边也按它
func item_rect(uid: int) -> Rect2:
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null:
		return Rect2()
	var span := span_px(inst, inst.rotation)
	if _bodies.has(uid):
		return Rect2(_bodies[uid]["pos"], span)
	var tilt := stash.tilt_of(uid)
	if tilt == 0.0:
		# 夹边按轮廓：道具图四周透明的那一圈可以出屏（解算、落地都按轮廓贴地贴边，按包围盒夹会把它顶离地面）
		var sb: Rect2 = ItemSilhouette.of(inst.def, inst.rotation)["bounds"]
		return Rect2(_fit(Rect2(stash.spot_of(uid) * size + sb.position, sb.size)).position - sb.position, span)
	var off := _spot_off(inst, tilt)
	var box: Rect2 = _tilted(inst, tilt)["bounds"]
	return Rect2(_fit(Rect2(stash.spot_of(uid) * size, box.size)).position - off, span)


## 198 补充一：斜着的包围盒（本控件内像素）—— 屏边夹取、找支撑按它
func item_bounds(uid: int) -> Rect2:
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null or inst.def == null:
		return Rect2()
	var tilt := tilt_of(uid)
	if tilt == 0.0:
		return item_rect(uid)
	var box: Rect2 = _tilted(inst, tilt)["bounds"]
	return Rect2(item_rect(uid).position + box.position, box.size)


## 198 补充一：这件斜了多少（弧度，顺时针为正；解算中按此刻的）
func tilt_of(uid: int) -> float:
	if _bodies.has(uid):
		return float(_bodies[uid]["ang"])
	return stash.tilt_of(uid) if stash != null else 0.0


## 这件此刻的轮廓凸块（从不斜时包围盒左上角量；斜着的已转好）
func _parts_of(uid: int) -> Array:
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null or inst.def == null:
		return []
	return _tilted(inst, tilt_of(uid))["parts"]


static func _tilted(inst: ItemInstance, tilt: float) -> Dictionary:
	return ItemSilhouette.tilted(ItemSilhouette.of(inst.def, inst.rotation), tilt)


## 斜着的件落点记的是斜着的包围盒的左上角（屏边夹取时整块留在屏内、存档里也不会出界）：比不斜时的左上角挪了多少。不斜 = 0
static func _spot_off(inst: ItemInstance, tilt: float) -> Vector2:
	if tilt == 0.0:
		return Vector2.ZERO
	return (_tilted(inst, tilt)["bounds"] as Rect2).position - (ItemSilhouette.of(inst.def, inst.rotation)["bounds"] as Rect2).position


## 写回一件的落点（不斜时包围盒左上角在 [param pos]）与斜度
func _store(uid: int, pos: Vector2, tilt: float) -> void:
	var inst := stash.get_item(uid)
	if inst == null:
		return
	stash.set_tilt(uid, tilt)
	var spot := to_spot(pos + _spot_off(inst, tilt))
	if not stash.spot_of(uid).is_equal_approx(spot):
		stash.set_spot(uid, spot)


## 点 [param p] 反着转回这件不斜时的样子（绕轮廓重心转 −斜度）；不斜原样
func _untilt(uid: int, p: Vector2) -> Vector2:
	var tilt := tilt_of(uid)
	if tilt == 0.0:
		return p
	var inst := stash.get_item(uid)
	var pivot := item_rect(uid).position + ItemSilhouette.centroid(inst.def, inst.rotation)
	return pivot + (p - pivot).rotated(-tilt)


func _fit(r: Rect2) -> Rect2:
	var p := Vector2(
		clampf(r.position.x, 0.0, maxf(0.0, size.x - r.size.x)),
		clampf(r.position.y, 0.0, maxf(0.0, size.y - r.size.y)))
	return Rect2(p, r.size)


## 鼠标下最上面那一件（后放的在上）；没有 -1。162：半空中的也接（按它此刻画在哪、多大），排队还没出现的不接。
## 198：有道具图的（落稳的）按透明通道点，透明的角点不着；没图按格子。198 补充一：斜着的把点反着转回去再查
func uid_at_local(p: Vector2) -> int:
	if stash == null:
		return -1
	var list := stash.items()
	for i in range(list.size() - 1, -1, -1):
		var inst := list[i] as ItemInstance
		if _landing.has(inst.uid) and bool(landing_pose(inst.uid)["hidden"]):
			continue
		if not _landing.has(inst.uid) and inst.def != null and ItemSilhouette.of(inst.def, inst.rotation)["mask"] != null:
			if ItemSilhouette.hit(inst.def, inst.rotation, _untilt(inst.uid, p) - item_rect(inst.uid).position):
				return inst.uid
			continue
		var cell := _cell_under(inst.uid, p)
		if inst.def.cells_rotated(inst.rotation).has(cell):
			return inst.uid
	return -1


## [param p] 落在这一件的哪一格（现在朝向的坐标；不夹边，包围盒外是越界的格）：正在落的按此刻的位置、缩放、转角（绕重心）反推，
## 再从画着的起手朝向换到现在的朝向。斜着的先反着转回去
func _cell_under(uid: int, p: Vector2) -> Vector2i:
	var r := item_rect(uid)
	var q := _untilt(uid, p) - r.position
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
## 198：「压没压着」按轮廓 [param parts]（从包围盒左上角量；不给 = 整个包围盒）—— 只是缺角伸进面板不算压着。
## 253：[param sideways] = 只往左右推（落稳在地上 / 别的东西上的，往上推就悬空了）
func push_out(r: Rect2, parts: Array = [], sideways: bool = false) -> Rect2:
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
		]
		if not sideways:
			tries.append(Vector2(r.position.x, hit.position.y - r.size.y - PUSH_GAP))
			tries.append(Vector2(r.position.x, hit.end.y + PUSH_GAP))
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


## 253：落稳的这几件（[param uids]）压着面板就往左右推到最近的空处（面板不再是桌面 / 墙，只是「不压着」）；推完压着别的由 [method wake_bumps] 弹开
func _push_off_panels(uids: Array) -> void:
	if stash == null or reserved_rects().is_empty():
		return
	for uid in uids:
		if not stash.has_item(uid) or _landing.has(uid):
			continue
		var r := item_rect(uid)
		var moved := push_out(r, _parts_of(uid), true)
		if moved.position != r.position:
			_store(uid, moved.position, tilt_of(uid))


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
		var uid := (inst as ItemInstance).uid
		var r := item_rect(uid)
		var moved := push_out(r, _parts_of(uid))
		if moved.position != r.position:
			var tilt := tilt_of(uid)
			_bodies.erase(uid)
			_store(uid, moved.position, tilt)
	wake_bumps()
#endregion


#region 相遇弹开（180 §2.2）、翻、靠（198 补充一）
## 地上（不在落的）两两相交的（uid 对；测试看「任何时候都不重叠」）。198：按轮廓（斜着的按斜着的），压进去超过 [constant BUMP_EPS] 才算
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
			parts[it.uid] = _parts_of(it.uid)
	var keys := at.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var hit := ItemSilhouette.separate(parts[keys[i]], at[keys[i]], parts[keys[j]], at[keys[j]])
			if float(hit["depth"]) > BUMP_EPS:
				out.append([keys[i], keys[j]])
	return out


## 有相交的、或刚落稳却站不住的（[param landed] 里重心不在支撑上方的，198 补充一）就开始解算：地上不在落的每件都成一个物体，
## 相交的和站不住的醒着，其余睡着（被撞到再醒）。正在解算时新落稳的加进去。地藏着、没尺寸时不动
func wake_bumps(landed: Array = []) -> void:
	if stash == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if is_inside_tree() and not is_visible_in_tree():
		return
	var restless := {}
	if _bodies.is_empty() and not _bump_hold.is_empty() and _bump_hold == _uids():
		pass     # 挤满了放弃过：重叠不再弹，只看新落稳的
	else:
		for pair in overlapping_pairs():
			if _bodies.has(pair[0]) and _bodies.has(pair[1]):
				continue     # 正在解算的两件之间的事解算自己管（别把它们醒着的钟拨回去）
			restless[pair[0]] = true
			restless[pair[1]] = true
	for uid in landed:
		if stash.has_item(uid) and not _landing.has(uid) and int(_refalls.get(uid, 0)) < BUMP_REFALL_MAX and not is_stable(uid):
			restless[uid] = true
	if _bodies.is_empty():
		if restless.is_empty():
			return
		_bump_t = 0.0
		_bump_acc = 0.0
	if not restless.is_empty():
		_bump_start = _bump_t
	var ground_y := size.y * (1.0 - ItemStash.SPOT_MARGIN)
	for inst in stash.items():
		var it := inst as ItemInstance
		if _landing.has(it.uid) or it.def == null:
			continue
		if _bodies.has(it.uid):
			if restless.has(it.uid):
				_wake(_bodies[it.uid])
			continue
		_bodies[it.uid] = _new_body(it, ground_y, restless.has(it.uid))
	_sync_process()


## 一件成一个物体：{pos: 不斜时包围盒左上角, vel: 重心速度, ang: 斜度, w: 角速度, m: 质量, I: 转动惯量, com: 轮廓重心（从 pos 量）,
## sil: 这一向的轮廓, floor: 地面 y, last: 上次撞击时刻, rest: 静了多久, asleep}。253：面板不是墙，不用记起手压着哪块
## 249：[param at] 给了（不是 NaN）就从这个左上角起（甩出去的从松手点起，不从落点）
func _new_body(it: ItemInstance, ground_y: float, awake: bool, at: Vector2 = Vector2(NAN, NAN)) -> Dictionary:
	var r := item_rect(it.uid)
	if not is_nan(at.x):
		r.position = at
	var sil := ItemSilhouette.of(it.def, it.rotation)
	var ang := tilt_of(it.uid)
	var parts: Array = ItemSilhouette.tilted(sil, ang)["parts"]
	var box: Rect2 = sil["bounds"]
	var m := sqrt(maxf(0.5, float(ItemWeight.of(it.def))))     # 开方：重的仍挪得少，但轻重差几十倍时夹在中间的不会被挤炸
	var low := r.position.y + ItemSilhouette.bounds_of(parts).end.y
	return {"uid": it.uid, "pos": r.position, "vel": Vector2.ZERO, "ang": ang, "w": 0.0, "m": m, "I": m * (box.size.x * box.size.x + box.size.y * box.size.y) / 12.0,
		"com": sil["centroid"], "sil": sil, "floor": maxf(ground_y, low), "last": -INF, "rest": 0.0,
		"asleep": not awake, "vp": Vector2.ZERO, "age": 0.0, "topple": false, "settled": false, "more": false}


## [param fresh]：新的事（刚落稳、刚被摆过来）—— 醒着的钟从头算；被旁边的碰醒的接着算（一堆东西互相碰醒个没完时，每件醒着的总时长仍封顶）
static func _wake(b: Dictionary, fresh: bool = true) -> void:
	b["asleep"] = false
	b["rest"] = 0.0
	if fresh:
		b["age"] = 0.0
	b["topple"] = false
	b["settled"] = false


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
		if _bump_step(BUMP_STEP) or _bump_t - _bump_start >= BUMP_RUN_MAX_SEC:
			_finish_bumps()
	_sync_process()
	queue_redraw()


## 一口气解算到底（测试、不在树里时）
func settle_bumps() -> void:
	while not _bodies.is_empty():
		advance_bumps(BUMP_STEP)


## 一个物体此刻的凸块（本控件内像素，斜着的已转好）
static func _body_parts(b: Dictionary) -> Array:
	var out: Array = []
	var com: Vector2 = b["com"]
	for poly in (b["sil"]["parts"] as Array):
		out.append(ItemSilhouette.turn(poly, com, float(b["ang"]), b["pos"]))
	return out


## 一小步（198 补充一 §7.3）：重力 → 找接触（物件两两、屏边与地面、面板）→ 冲量迭代（法向带反弹、切向摩擦）→ 分开重叠（只挪位置）→
## 撞击后的衰减与贴住 → 直接推开一点重叠 → 走 → 夹回屏内、推出面板 → 静够了睡着。返回「都睡着了」
func _bump_step(h: float) -> bool:
	var g := LAND_G * _screen_h()
	var impact := maxf(BUMP_REST, 2.0 * g * h)     # 躺着时每步被重力压进去的速度不算撞
	var list: Array = _bodies.values()
	for b in list:
		if not bool(b["asleep"]):
			b["vel"] = (b["vel"] as Vector2) + Vector2(0.0, g * h)
		b["world"] = _body_parts(b)
		b["wb"] = ItemSilhouette.bounds_of(b["world"])
		b["pushed"] = false
		b["hit"] = 0
		b["hit_up"] = false     # 253：这一步撞上的有朝上的面（落在地 / 件 / 顶上）
		b["hit_side"] = false     # 253：这一步撞上屏边（竖直的墙）
		b["side_free"] = false     # 253：甩出去还没落过地的撞屏边 —— 不夹不衰减，只按 e_wall / μ
		b["touch"] = false     # 253：这一步有没有挨着任何东西（半空的不计醒着的时长、不睡）
		b["held"] = Vector2(INF, -INF)
		b["cx"] = (b["pos"] as Vector2).x + (b["com"] as Vector2).x
	var contacts: Array = []
	for i in list.size():
		for j in range(i + 1, list.size()):
			_pair_contacts(list[i], list[j], contacts, impact)
	for b in list:
		if not bool(b["asleep"]):
			_wall_contacts(b, contacts)
	for c in contacts:
		_prep(c, h, impact)
		_note_hold(c)
		c["a"]["touch"] = true
		if c["b"] != null:
			c["b"]["touch"] = true
	for _it in BUMP_ITERS:
		for c in contacts:
			_solve(c)
	for _it in BUMP_ITERS:
		for c in contacts:
			_solve_split(c)
	var cap := BUMP_WALL_VCAP * LAND_VMAX * _screen_h()
	for b in list:
		_after_impact(b, cap)
		if not bool(b.get("thrown", false)):
			b["vel"] = (b["vel"] as Vector2).limit_length(BUMP_SEP_VMAX)     # 夹在两件之间解不开时冲量会越攒越大：封顶（249：甩出去还没落地的不按它封）
		b["w"] = clampf(float(b["w"]), -BUMP_W_MAX, BUMP_W_MAX)
	for c in contacts:
		if c["b"] != null and float(c["depth"]) > BUMP_SLOP:
			_fix_pair(c)
	for b in list:
		if bool(b["asleep"]):
			continue
		b["pos"] = (b["pos"] as Vector2) + ((b["vel"] as Vector2) + (b["vp"] as Vector2)) * h
		b["ang"] = float(b["ang"]) + float(b["w"]) * h
		if absf(float(b["ang"])) < 0.00001:
			b["ang"] = 0.0     # 浮点误差攒出来的几乎为零的斜度不算斜
		b["vp"] = Vector2.ZERO
		_clamp_body(b)
	var all_asleep := true
	for b in list:
		if bool(b["asleep"]):
			continue
		var v: Vector2 = b["vel"]
		var held: Vector2 = b["held"]
		var propped := float(b["cx"]) >= held.x - 0.5 and float(b["cx"]) <= held.y + 0.5
		if not bool(b["touch"]) and not propped:
			b["rest"] = 0.0
			all_asleep = false
			continue     # 253：半空中（什么也没挨着）照落，不计醒着的时长、不睡 —— 不再冻在半空
		b["age"] = float(b["age"]) + h
		if float(b["age"]) >= BUMP_MAX_SEC - 0.000001 and not propped and not bool(b["more"]):
			b["more"] = true     # 到时还在倒（重心不在支撑上方）：再给一段，让它自己翻下去 —— 比收尾时再落一次自然
			b["age"] = 0.0
		if float(b["age"]) >= BUMP_MAX_SEC - 0.000001:
			b["asleep"] = true     # 醒着解算够久了：冻在这个姿态（还在倒的收尾时再落一次）
			b["topple"] = not propped
			b["vel"] = Vector2.ZERO
			b["w"] = 0.0
			continue
		if not bool(b["pushed"]) and v.length() < BUMP_REST and absf(float(b["w"])) < BUMP_W_REST:
			b["rest"] = float(b["rest"]) + h
			if float(b["rest"]) >= (BUMP_SLEEP_SEC if propped else BUMP_SLEEP_WEDGED_SEC) - 0.000001:
				b["asleep"] = true
				b["settled"] = true     # 自己静下来的：解算认定它被托着 / 卡着
				b["vel"] = Vector2.ZERO
				b["w"] = 0.0
				continue
		else:
			b["rest"] = 0.0
		all_asleep = false
	return all_asleep


## 一对物体的接触（至少一件醒着）。睡着的那件被撞得够狠（压进 1 像素以上、迎面速度过撞击线）或被正在动的碰到就醒；没醒就当推不动
func _pair_contacts(a: Dictionary, b: Dictionary, out: Array, impact: float) -> void:
	if bool(a["asleep"]) and bool(b["asleep"]):
		return
	if not (a["wb"] as Rect2).grow(BUMP_TOUCH).intersects(b["wb"]):
		return
	var wa: Array = a["world"]
	var wb: Array = b["world"]
	for i in wa.size():
		var ra := ItemSilhouette.bounds_of([wa[i]]).grow(BUMP_TOUCH)
		for j in wb.size():
			if not ra.intersects(ItemSilhouette.bounds_of([wb[j]])):
				continue
			var c := ItemSilhouette.contact(wa[i], wb[j], BUMP_TOUCH)
			if c.is_empty():
				continue
			c["a"] = a
			c["b"] = b
			c["mu"] = BUMP_MU
			c["e"] = BUMP_E
			if bool(a["asleep"]) or bool(b["asleep"]):
				var mover: Dictionary = a if bool(b["asleep"]) else b
				var sleeper: Dictionary = b if bool(b["asleep"]) else a
				var woken := float(c["depth"]) > 1.0 or float(mover["rest"]) <= 0.0 or -_rel_normal(c) > impact
				if woken and float(sleeper["age"]) < BUMP_MAX_SEC - 0.000001:
					_wake(sleeper, false)     # 醒着够久冻住了的不再被碰醒，当推不动
			if float(c["depth"]) > BUMP_EPS:
				a["pushed"] = true
				b["pushed"] = true
			out.append(c)


## 记下谁被这处接触撑着：不是从上面压下来的接触，接触点的横向区间（重心在区间上方才睡得着 —— 只有一个角着地、还在往下倒的不算静）
static func _note_hold(c: Dictionary) -> void:
	var n: Vector2 = c["n"]
	var sides := []
	if n.y > -0.3:
		sides.append(c["a"])
	if c["b"] != null and n.y < 0.3:
		sides.append(c["b"])
	for side in sides:
		var held: Vector2 = side["held"]
		for p in (c["points"] as PackedVector2Array):
			held = Vector2(minf(held.x, p.x), maxf(held.y, p.x))
		side["held"] = held


## 迎面速度（接触点上 b 相对 a 沿 n；负 = 靠近），取几个接触点里最快的
static func _rel_normal(c: Dictionary) -> float:
	var worst := INF
	for p in (c["points"] as PackedVector2Array):
		worst = minf(worst, _point_vel(c["b"], p).dot(c["n"]) - _point_vel(c["a"], p).dot(c["n"]))
	return worst


## 物体 [param b]（null = 墙）上点 [param p] 的速度
static func _point_vel(b: Variant, p: Vector2) -> Vector2:
	if b == null:
		return Vector2.ZERO
	var r := p - ((b["pos"] as Vector2) + (b["com"] as Vector2))
	var w := float(b["w"])
	return (b["vel"] as Vector2) + Vector2(-w * r.y, w * r.x)


## 屏边、地面（半平面：碰到的顶点）—— 推不动的。253：登记的面板不再是墙
func _wall_contacts(b: Dictionary, out: Array) -> void:
	var verts := PackedVector2Array()
	for poly in (b["world"] as Array):
		verts.append_array(poly)
	var planes := [[Vector2(0, 1), float(b["floor"])], [Vector2(-1, 0), 0.0], [Vector2(1, 0), size.x], [Vector2(0, -1), 0.0]]
	for k in planes.size():
		var c := _plane_contact(verts, planes[k][0], planes[k][1])
		if not c.is_empty():
			c["a"] = b
			c["b"] = null
			c["mu"] = BUMP_MU_WALL
			c["e"] = BUMP_E_WALL
			out.append(c)


## 一堆顶点碰半平面（[param n] 指向墙外，墙在 `p·n = limit`）：最深的那几个顶点沿墙的两头（1～2 个接触点）
static func _plane_contact(verts: PackedVector2Array, n: Vector2, limit: float) -> Dictionary:
	var deepest := -INF
	for v in verts:
		deepest = maxf(deepest, v.dot(n) - limit)
	if deepest <= -BUMP_TOUCH:
		return {}
	var tan := Vector2(-n.y, n.x)
	var lo := INF
	var hi := -INF
	var p_lo := Vector2.ZERO
	var p_hi := Vector2.ZERO
	for v in verts:
		if v.dot(n) - limit < deepest - ItemSilhouette.FEATURE_TOL:
			continue
		var t := v.dot(tan)
		if t < lo:
			lo = t
			p_lo = v
		if t > hi:
			hi = t
			p_hi = v
	var points := PackedVector2Array([p_lo])
	if hi - lo >= 1.0:
		points.append(p_hi)
	return {"n": n, "depth": deepest, "points": points}


## 解算前：每个接触点的力臂、有效质量；迎面快过撞击线的按恢复系数反弹（记一次撞击）
func _prep(c: Dictionary, h: float, impact: float) -> void:
	var a: Dictionary = c["a"]
	var b: Variant = c["b"]
	var n: Vector2 = c["n"]
	var t := Vector2(-n.y, n.x)
	var ima := _inv_m(a)
	var iia := _inv_i(a)
	var imb := _inv_m(b)
	var iib := _inv_i(b)
	var pts: Array = []
	var vn0 := _rel_normal(c)
	var target := 0.0
	if float(c["depth"]) < 0.0:
		target = float(c["depth"]) / h     # 还隔着一点：允许这一步正好靠上
	if -vn0 > impact:
		target = maxf(target, -float(c["e"]) * vn0)
		a["hit"] = int(a["hit"]) | (2 if b == null else 1)
		if n.y > 0.5:
			a["hit_up"] = true     # n 指向对方：对方在下面 = 落在它上面
		elif b == null and absf(n.y) < 0.5:
			a["hit_side"] = true
			a["side_free"] = bool(a.get("thrown", false))
		if b != null:
			b["hit"] = int(b["hit"]) | 1
			if n.y < -0.5:
				b["hit_up"] = true
		elif bool(a.get("thrown", false)):
			a["thrown"] = false     # 249：甩出去的第一次撞上地 / 墙 / 面板响一声落地，之后的小碰不响
			AudioHub.play(landing_cue([a["uid"]]))
			thrown_landed.emit(int(a["uid"]))
	for p in (c["points"] as PackedVector2Array):
		var ra := p - ((a["pos"] as Vector2) + (a["com"] as Vector2))
		var rb := p - ((b["pos"] as Vector2) + (b["com"] as Vector2)) if b != null else Vector2.ZERO
		var kn := ima + imb + iia * pow(ra.cross(n), 2) + iib * pow(rb.cross(n), 2)
		var kt := ima + imb + iia * pow(ra.cross(t), 2) + iib * pow(rb.cross(t), 2)
		pts.append({"p": p, "ra": ra, "rb": rb, "kn": kn, "kt": kt, "pn": 0.0, "pt": 0.0})
	c["pts"] = pts
	c["t"] = t
	c["target"] = target
	c["ims"] = [ima, iia, imb, iib]
	c["bias"] = minf(maxf(0.0, float(c["depth"]) - BUMP_SLOP) / BUMP_SEP_SEC, BUMP_SEP_VMAX)
	c["ps"] = 0.0


## 推不动的（墙、睡着的）逆质量 0
static func _inv_m(b: Variant) -> float:
	return 0.0 if b == null or bool(b["asleep"]) else 1.0 / float(b["m"])


static func _inv_i(b: Variant) -> float:
	return 0.0 if b == null or bool(b["asleep"]) else 1.0 / maxf(0.0001, float(b["I"]))


## 一轮冲量：法向（累计不为负；两个接触点的一起解，平底边压着平面时左右一样、不会凭空转起来），再每个点切向摩擦（累计封顶「摩擦系数 × 法向」）
static func _solve(c: Dictionary) -> void:
	var a: Dictionary = c["a"]
	var b: Variant = c["b"]
	var n: Vector2 = c["n"]
	var t: Vector2 = c["t"]
	var ims: Array = c["ims"]
	var pts: Array = c["pts"]
	if pts.size() != 2 or not _solve_pair(c):
		for q in pts:
			if float(q["kn"]) <= 0.0:
				continue
			var p: Vector2 = q["p"]
			var dv := _point_vel(b, p) - _point_vel(a, p)
			var d := (float(c["target"]) - dv.dot(n)) / float(q["kn"])
			var pn := maxf(float(q["pn"]) + d, 0.0)
			d = pn - float(q["pn"])
			q["pn"] = pn
			_push(a, b, q, n * d, ims)
	for q in pts:
		if float(q["kt"]) <= 0.0:
			continue
		var p: Vector2 = q["p"]
		var pn := float(q["pn"])
		var dv := _point_vel(b, p) - _point_vel(a, p)
		var cap := float(c["mu"]) * pn
		var dt := -dv.dot(t) / float(q["kt"])
		var pt := clampf(float(q["pt"]) + dt, -cap, cap)
		dt = pt - float(q["pt"])
		q["pt"] = pt
		_push(a, b, q, t * dt, ims)


## 两个接触点的法向冲量一起解（累计不为负的 2 × 2 线性互补，Box2D 的块解法）。两点太近（矩阵病态）返回 false，退回逐点解
static func _solve_pair(c: Dictionary) -> bool:
	var a: Dictionary = c["a"]
	var b: Variant = c["b"]
	var n: Vector2 = c["n"]
	var ims: Array = c["ims"]
	var q1: Dictionary = c["pts"][0]
	var q2: Dictionary = c["pts"][1]
	var ima := float(ims[0]) + float(ims[2])
	var k11 := float(q1["kn"])
	var k22 := float(q2["kn"])
	var k12 := ima + float(ims[1]) * (q1["ra"] as Vector2).cross(n) * (q2["ra"] as Vector2).cross(n) + float(ims[3]) * (q1["rb"] as Vector2).cross(n) * (q2["rb"] as Vector2).cross(n)
	var det := k11 * k22 - k12 * k12
	if k11 <= 0.0 or k22 <= 0.0 or k11 * k11 >= 1000.0 * det:
		return false
	var a1 := float(q1["pn"])
	var a2 := float(q2["pn"])
	var target := float(c["target"])
	var vn1 := (_point_vel(b, q1["p"]) - _point_vel(a, q1["p"])).dot(n) - target
	var vn2 := (_point_vel(b, q2["p"]) - _point_vel(a, q2["p"])).dot(n) - target
	var b1 := vn1 - (k11 * a1 + k12 * a2)
	var b2 := vn2 - (k12 * a1 + k22 * a2)
	var x1 := -(k22 * b1 - k12 * b2) / det
	var x2 := -(k11 * b2 - k12 * b1) / det
	if x1 < 0.0 or x2 < 0.0:
		x1 = -b1 / k11
		x2 = 0.0
		if x1 < 0.0 or k12 * x1 + b2 < 0.0:
			x1 = 0.0
			x2 = -b2 / k22
			if x2 < 0.0 or k12 * x2 + b1 < 0.0:
				x1 = 0.0
				x2 = 0.0
				if b1 < 0.0 or b2 < 0.0:
					return false
	_push(a, b, q1, n * (x1 - a1), ims)
	_push(a, b, q2, n * (x2 - a2), ims)
	q1["pn"] = x1
	q2["pn"] = x2
	return true


## 冲量 [param imp] 加在 b 上、反向加在 a 上（各按逆质量、逆转动惯量）
static func _push(a: Dictionary, b: Variant, q: Dictionary, imp: Vector2, ims: Array) -> void:
	a["vel"] = (a["vel"] as Vector2) - imp * float(ims[0])
	a["w"] = float(a["w"]) - float(ims[1]) * (q["ra"] as Vector2).cross(imp)
	if b != null:
		b["vel"] = (b["vel"] as Vector2) + imp * float(ims[2])
		b["w"] = float(b["w"]) + float(ims[3]) * (q["rb"] as Vector2).cross(imp)


## 分开重叠：只改「这一步的挪动」（vp），不留速度 —— 读档压在一起的推开就停，不会炸开。墙、地面、面板也一起解（推不动），
## 否则夹在墙和别的件之间的会被推进墙、再被夹回来，一直压着睡不着
static func _solve_split(c: Dictionary) -> void:
	var a: Dictionary = c["a"]
	var b: Variant = c["b"]
	var ims: Array = c["ims"]
	var k := float(ims[0]) + float(ims[2])
	if k <= 0.0:
		return
	var n: Vector2 = c["n"]
	var vb: Vector2 = b["vp"] if b != null else Vector2.ZERO
	var vn := (vb - (a["vp"] as Vector2)).dot(n)
	var ps := maxf(float(c["ps"]) + (float(c["bias"]) - vn) / k, 0.0)
	var d := ps - float(c["ps"])
	c["ps"] = ps
	a["vp"] = (a["vp"] as Vector2) - n * d * float(ims[0])
	if b != null:
		b["vp"] = (b["vp"] as Vector2) + n * d * float(ims[2])


## 撞过之后（180）：撞墙的弹回速度封顶、再乘 0.3，物件之间乘 0.5；两次撞击隔得太近就贴住。
## 253（作者 2026-10-25「道具拿出时有时候会卡住不动」）：甩出去还没落过地的撞屏边不夹不衰减（只按 e_wall / μ）；「隔得太近就贴住」不管只撞了屏边的那一下（侧着撞墙不归零；物件之间照旧，一堆挤着的才静得下来）
func _after_impact(b: Dictionary, cap: float) -> void:
	var hit := int(b["hit"])
	if hit == 0 or bool(b["asleep"]):
		return
	var v: Vector2 = b["vel"]
	var w := float(b["w"])
	var side_only := bool(b["side_free"]) and not bool(b["hit_up"])
	if hit & 2 and not side_only:
		for axis in 2:
			v[axis] = clampf(v[axis], -cap, cap)
		v *= BUMP_AFTER_WALL
		w *= BUMP_AFTER_WALL
	if hit & 1:
		v *= BUMP_AFTER
		w *= BUMP_AFTER
	var wall_side_only := bool(b["hit_side"]) and not bool(b["hit_up"]) and not (hit & 1)
	if not wall_side_only and _bump_t - float(b["last"]) < BUMP_STICK_SEC:
		v = Vector2.ZERO
		w = 0.0
	b["last"] = _bump_t
	b["vel"] = v
	b["w"] = w


## 走完夹回去：斜着的轮廓整块留在屏内、不低于地面（253：面板不推，落稳后再说）
func _clamp_body(b: Dictionary) -> void:
	var parts := _body_parts(b)
	var box := ItemSilhouette.bounds_of(parts)
	var shift := Vector2.ZERO
	if box.position.x < 0.0:
		shift.x = -box.position.x
	elif box.end.x > size.x:
		shift.x = maxf(size.x - box.end.x, -box.position.x)
	if box.end.y > float(b["floor"]):
		shift.y = float(b["floor"]) - box.end.y
	elif box.position.y < 0.0:
		shift.y = -box.position.y
	b["pos"] = (b["pos"] as Vector2) + shift


## 物件之间每小步再直接推开重叠的 [constant BUMP_FIX] 成（按逆质量分）
static func _fix_pair(c: Dictionary) -> void:
	var ims: Array = c["ims"]
	var k := float(ims[0]) + float(ims[2])
	if k <= 0.0:
		return
	var fix := (float(c["depth"]) - BUMP_SLOP) * BUMP_FIX / k
	var n: Vector2 = c["n"]
	c["a"]["pos"] = (c["a"]["pos"] as Vector2) - n * fix * float(ims[0])
	c["b"]["pos"] = (c["b"]["pos"] as Vector2) + n * fix * float(ims[2])


## 站得住吗（198 补充一）：重心在托着它的那些接触点（地面、面板、别的东西的顶）横向围成的区间上方。没有任何支撑 = 站不住
func is_stable(uid: int) -> bool:
	var sup := supports_of(uid)
	if not bool(sup["any"]):
		return false
	var inst := stash.get_item(uid)
	var com_x := item_rect(uid).position.x + ItemSilhouette.centroid(inst.def, inst.rotation).x
	var span: Vector2 = sup["span"]
	return com_x >= span.x - 0.5 and com_x <= span.y + 0.5


## 这件此刻被谁托着：{any, span: 托着它的接触点横向从 .x 到 .y, item: 托着它的那件的 uid（没有 -1）, floor: 着地}（253：面板不托东西）。
## 接触法线朝下（对方在它下面）的才算托着
func supports_of(uid: int) -> Dictionary:
	var out := {"any": false, "span": Vector2(INF, -INF), "item": -1, "floor": false}
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null or inst.def == null:
		return out
	var at := item_rect(uid).position
	var mine: Array = []
	for poly in _parts_of(uid):
		mine.append(ItemSilhouette.turn(poly, Vector2.ZERO, 0.0, at))
	var box := ItemSilhouette.bounds_of(mine)
	var span := Vector2(INF, -INF)
	var floor_y := maxf(size.y * (1.0 - ItemStash.SPOT_MARGIN), box.end.y)
	for poly in mine:
		for v in (poly as PackedVector2Array):
			if v.y >= floor_y - SUPPORT_TOUCH:
				span = Vector2(minf(span.x, v.x), maxf(span.y, v.x))
				out["floor"] = true
	for it in stash.items():
		var other := it as ItemInstance
		if other.uid == uid or other.def == null or _landing.has(other.uid):
			continue
		if not item_bounds(other.uid).grow(SUPPORT_TOUCH).intersects(box):
			continue
		var o_at := item_rect(other.uid).position
		for pb in _parts_of(other.uid):
			var hit := _support_span(mine, ItemSilhouette.turn(pb, Vector2.ZERO, 0.0, o_at))
			if hit.x <= hit.y:
				span = Vector2(minf(span.x, hit.x), maxf(span.y, hit.y))
				if int(out["item"]) < 0:
					out["item"] = other.uid
	out["span"] = span
	out["any"] = span.x <= span.y
	return out


## 凸块们 [param mine] 压在凸块 [param below] 上的接触点横向区间（没压着：x > y）
static func _support_span(mine: Array, below: PackedVector2Array) -> Vector2:
	var span := Vector2(INF, -INF)
	for pa in mine:
		var c := ItemSilhouette.contact(pa, below, SUPPORT_TOUCH)
		if c.is_empty() or (c["n"] as Vector2).y < 0.3:
			continue
		for p in (c["points"] as PackedVector2Array):
			span = Vector2(minf(span.x, p.x), maxf(span.y, p.x))
	return span


## 收尾：斜过 45° 的换成相邻的四向（画面一个像素不跳，§7.2）、几乎没斜的摆正，写回落点与斜度；到时还相交的（地上挤满了）退回网格扫出来的空处；
## 按最后的接触重算托着谁；悬着的（解算到时冻在半空、托着的被挪走）掉下去。
## 到时（这件醒着够 [constant BUMP_MAX_SEC]、或整轮到 [constant BUMP_RUN_MAX_SEC]）还在倒、重心不在支撑上方的（一个角着地正往下翻）不冻在半倒的样子：
## 从这个姿态再落一次（落地动画转回四向里最稳的那个）
func _finish_bumps() -> void:
	var bodies := _bodies
	_bodies = {}
	if stash == null:
		return
	var toppling := {}
	for uid in bodies.keys():
		var b: Dictionary = bodies[uid]
		var unpropped: bool = b.has("held") and (float(b["cx"]) < (b["held"] as Vector2).x - 0.5 or float(b["cx"]) > (b["held"] as Vector2).y + 0.5)
		if bool(b["topple"]) or (not bool(b["asleep"]) and unpropped):
			toppling[uid] = true
	for uid in bodies.keys():
		var inst := stash.get_item(uid)
		if inst == null:
			continue
		var pose := normalize_pose(inst.def, inst.rotation, bodies[uid]["pos"], float(bodies[uid]["ang"]))
		var pos: Vector2 = pose["pos"]
		var ang := float(pose["tilt"])
		inst.rotation = int(pose["rot"])
		if absf(ang) < BUMP_TILT_SNAP and ang != 0.0 and _snaps_clear(inst, pos):
			ang = 0.0
			var dy := float(floor_under(_parts(inst), pos, uid)["dy"])
			if dy > -1.5 and dy < BUMP_SNAP_SEAT:
				pos.y += dy     # 摆正后贴回支撑上（长条斜一点点，摆正时一头会抬起一两像素）
		_store(uid, pos, ang)
	_relax_overlaps(bodies)
	_push_off_panels(bodies.keys())     # 253：解算停下时压着面板的往左右推开（面板不是墙，解算里会穿过去）
	for pair in overlapping_pairs():
		var inst := stash.get_item(pair[1])
		if inst != null:
			stash.set_tilt(inst.uid, 0.0)
			stash.set_spot(inst.uid, _free_spot(inst))
	# 地上真挤满了（扫也扫不出空处）：这一批不再反复弹，等地上的东西变了再说
	_bump_hold = _uids() if not overlapping_pairs().is_empty() else {}
	var order: Array = bodies.keys().filter(func(uid: int) -> bool: return stash.has_item(uid))
	for uid in order:
		var sup := supports_of(uid)
		if int(sup["item"]) >= 0:
			_rest_on[uid] = int(sup["item"])
		else:
			_rest_on.erase(uid)
	# 作者 2026-10-17：悬着的掉下去 —— 低的先落，上面的落在它的新位置上
	order.sort_custom(func(a: int, b: int) -> bool: return item_bounds(a).end.y > item_bounds(b).end.y)
	for uid in order:
		if toppling.has(uid) and not _landing.has(uid):
			_rest_on.erase(uid)
			_begin_fall(stash.get_item(uid), item_rect(uid).position, 0.0, false)
		elif not bool(bodies[uid]["settled"]) or not _touches_any(uid):
			_refall_if_hanging(uid)     # 自己静下来、还挨着东西的（卡在两件之间、靠着侧面）不算悬着
		if _landing.has(uid):
			_refalls[uid] = int(_refalls.get(uid, 0)) + 1
		elif bool(bodies[uid]["settled"]):
			_refalls.erase(uid)


## 退回网格扫出来的空处（[method ItemStash.next_free_spot]）—— 斜着的那几件按斜着的包围盒让开（核心层只知道不斜的大小，253 种子 6：退回的那件压在斜着的件上）
func _free_spot(inst: ItemInstance) -> Vector2:
	var keep := stash.avoid.duplicate()
	for it in stash.items():
		var uid := (it as ItemInstance).uid
		if uid != inst.uid and tilt_of(uid) != 0.0:
			var r := item_bounds(uid)
			stash.avoid.append(Rect2(r.position / size, r.size / size))
	var spot := stash.next_free_spot(inst)
	stash.avoid = keep
	return spot


## 收尾时还压着一点的（到时冻在半路、静下来时还压进去零点几像素）：沿分开方向就地推开，轻的挪得多；往下推的那件不动、全给上面那件（不推进地里）。
## 只推 [constant BUMP_RELAX_MAX] 像素以内的，推几遍；压得更深的留给后面退回空处
func _relax_overlaps(bodies: Dictionary) -> void:
	for _pass in 8:
		var moved := false
		for pair in overlapping_pairs():
			var a: int = pair[0]
			var b: int = pair[1]
			var pa := item_rect(a).position
			var pb := item_rect(b).position
			var hit := ItemSilhouette.separate(_parts_of(a), pa, _parts_of(b), pb)
			var depth := float(hit["depth"])
			if depth > BUMP_RELAX_MAX:
				continue
			var n: Vector2 = hit["n"]
			var ma := float(bodies[a]["m"]) if bodies.has(a) else 1.0
			var mb := float(bodies[b]["m"]) if bodies.has(b) else 1.0
			var share_b := ma / (ma + mb)
			if n.y > 0.3:
				share_b = 0.0     # b 在下面：只抬 a
			elif n.y < -0.3:
				share_b = 1.0     # a 在下面：只抬 b
			var d := n * (depth + 0.1)
			_store(a, pa - d * (1.0 - share_b), tilt_of(a))
			_store(b, pb + d * share_b, tilt_of(b))
			moved = true
		if not moved:
			return


## 198 补充一 §7.2 归一化：斜过 45° 的换成相邻的四向 —— 朝向 [param rot]、不斜时包围盒左上角 [param pos]、斜 [param ang] 的这件，
## 返回画面上一模一样的 {rot, pos, tilt}，斜度落在 (−45°, 45°]（重心不动；201 的贴图与 cells_rotated 同一套顺时针变换，所以一个像素不跳）
static func normalize_pose(def: ItemDef, rot: int, pos: Vector2, ang: float) -> Dictionary:
	var k := 0
	while ang > PI * 0.25 + 0.000001:
		ang -= PI * 0.5
		k += 1
	while ang <= -PI * 0.25 - 0.000001:
		ang += PI * 0.5
		k -= 1
	if k == 0:
		return {"rot": rot, "pos": pos, "tilt": ang}
	var to := posmod(rot + k, 4)
	return {"rot": to, "pos": pos + ItemSilhouette.centroid(def, rot) - ItemSilhouette.centroid(def, to), "tilt": ang}


## 几乎没斜的摆正之后不压着别人才摆正
func _snaps_clear(inst: ItemInstance, pos: Vector2) -> bool:
	var parts := _parts(inst)
	for it in stash.items():
		var other := it as ItemInstance
		if other.uid == inst.uid or other.def == null or _landing.has(other.uid):
			continue
		if float(ItemSilhouette.separate(parts, pos, _parts_of(other.uid), item_rect(other.uid).position)["depth"]) > BUMP_EPS:
			return false
	return true


## 这件是不是挨着什么（别的道具、面板、地面、屏幕两边，差 [constant SUPPORT_TOUCH] 以内，哪个方向都算）
func _touches_any(uid: int) -> bool:
	var at := item_rect(uid).position
	var mine: Array = []
	for poly in _parts_of(uid):
		mine.append(ItemSilhouette.turn(poly, Vector2.ZERO, 0.0, at))
	var box := ItemSilhouette.bounds_of(mine)
	if box.end.y >= size.y * (1.0 - ItemStash.SPOT_MARGIN) - SUPPORT_TOUCH or box.position.x <= SUPPORT_TOUCH or box.end.x >= size.x - SUPPORT_TOUCH:
		return true
	var others: Array = []
	for it in stash.items():
		var other := it as ItemInstance
		if other.uid == uid or other.def == null or _landing.has(other.uid) or not item_bounds(other.uid).grow(SUPPORT_TOUCH).intersects(box):
			continue
		var o_at := item_rect(other.uid).position
		for pb in _parts_of(other.uid):
			others.append(ItemSilhouette.turn(pb, Vector2.ZERO, 0.0, o_at))
	for pa in mine:
		for pb in others:
			if not ItemSilhouette.contact(pa, pb, SUPPORT_TOUCH).is_empty():
				return true
	return false


## 这件底下离支撑还有空（悬着）就从现在的位置掉下去（斜着的按斜着的轮廓量）
func _refall_if_hanging(uid: int) -> void:
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null or inst.def == null or inst.def.shape == null or _landing.has(uid):
		return
	var at := item_rect(uid).position
	if float(floor_under(_parts_of(uid), at, uid)["dy"]) > 1.0:
		_rest_on.erase(uid)
		_begin_fall(inst, at, 0.0, false)
#endregion


func _gui_input(event: InputEvent) -> void:
	if stash == null or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or not mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	var uid := uid_at_local(mb.position)
	if uid < 0:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		item_context.emit(self, uid)     # 230：右键 = 钉住悬浮窗
		accept_event()
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
		var edge := COLOR_HIGHLIGHT if highlights.has(inst.uid) else ItemPainter.rarity_color(inst.def, inst.rarity())
		var body := ItemPainter.body_color(inst.def, inst.rarity())
		var ink := ItemPainter.label_color(inst.def, inst.rarity())
		var at := r.position
		var landing := _landing.has(inst.uid)
		var base := Transform2D.IDENTITY
		var tint := Color.WHITE
		var rot := inst.rotation
		var tilt := 0.0 if landing else tilt_of(inst.uid)
		if tilt != 0.0:
			# 198 补充一：斜着躺 —— 绕轮廓重心转
			var pivot := r.position + ItemSilhouette.centroid(inst.def, rot)
			draw_set_transform(pivot, tilt)
			base = Transform2D(tilt, pivot)
			at = r.position - pivot
		elif landing:
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
		if not ItemPainter.draw_art(self, inst.def, rot, at, InventoryView.CELL, tint, base, ItemPainter.variant_of(inst)):
			ItemPainter.draw_item(self, cells, at, InventoryView.CELL, body, edge)
			ItemPainter.draw_label(self, cells, at, InventoryView.CELL, Names.of_item(inst), font, 13, ink)
		ItemPainter.draw_lock(self, inst, rot, at, InventoryView.CELL, tint)     # 230
		var sil := ItemSilhouette.of(inst.def, rot)
		if sil["mask"] != null:     # 198：有道具图的描边 / 高亮沿轮廓走（没图的格子已经沿外形描过了）
			for poly in (sil["outline"] as Array):
				var line := (poly as PackedVector2Array).duplicate()
				line.append(line[0])
				for k in line.size():
					line[k] += at
				draw_polyline(line, edge, 2.0)
		if landing or tilt != 0.0:
			draw_set_transform(Vector2.ZERO)

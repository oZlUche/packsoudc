## 腰带（147，作者定）：随身消耗品槽 —— 一条 1 × N 的格子，默认 3 格，`RunContext.belt_slots_bonus` 往上加（科技 / 角色 / buff）。
## 只收【随身】（`belt`）道具；它们**不上棋盘**（不参战、不占背包），地上与仓库照旧什么都收。点一下就用（[member ItemDef.belt_use]）。
##
## 101 的插件模型：状态（容器）、存档、接线全在这里，[RunState] 不认识腰带。自己接一条 hook：`belt_use`（界面只认它）。
## 开局带进来的随身道具（作战棋盘不收，开局先落在地上）在装上时挪进腰带。取它用 [method of]
class_name BeltModule
extends RunModule

const ID := &"belt"
const CONTAINER_ID := 5

## 用掉了一件（定义 id）
signal used(def_id: StringName)

## 默认几格（内容里可改；`RunContext.belt_slots_bonus` 加在上面）
@export var slots: int = 3

var belt: GridInventory = null
var _run: RunState = null
var _saved: Dictionary = {}


## 这一局的腰带模块（没装返回 null）
static func of(run: RunState) -> BeltModule:
	return run.module(ID) as BeltModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "腰带：%d 格，放随身道具（烟雾弹、急救包……），点一下就用" % slot_count()


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if belt == null:
		var saved_grid: Variant = _saved.get("belt", null)
		if saved_grid is Dictionary:
			belt = GridInventory.from_dict(saved_grid as Dictionary, run.items)
			belt.id = CONTAINER_ID
		else:
			belt = GridInventory.new(Vector2i(slot_count(), 1), CONTAINER_ID, false)
			belt.only_tags = [ItemDef.BELT] as Array[StringName]
			_take_from_ground()
		belt.only_tags = [ItemDef.BELT] as Array[StringName]
	sync_slots()
	run.hooks.register(&"belt_use", use)


## 现在该有几格：默认 + 一局的规则加的
func slot_count() -> int:
	var bonus := _run.hooks.run_context().belt_slots_bonus if _run != null else 0
	return maxi(1, slots + bonus)


## 格数变了就跟上：变大扩列；变小只在空格上缩（东西不丢）
func sync_slots() -> void:
	if belt == null:
		return
	belt.resize_cols(slot_count())


## 能不能用这一件：空串 = 能，否则是原因（界面灰字）
func can_use(uid: int) -> String:
	var inst := belt.get_item(uid) if belt != null else null
	if inst == null or inst.def == null:
		return "腰带里没有这件"
	var how := inst.def.belt_use
	if how == null:
		return "这件不能直接用"
	if _run == null or _run.is_over():
		return "这一局结束了"
	var prebattle := _run.events != null and not _run.events.pending_battle.is_empty()
	if prebattle and not how.on_prebattle():
		return "开战前用不了"
	if not prebattle and not how.on_map():
		return "只能在开战前用"
	for e in how.effects:
		if e == null:
			continue
		var why := e.blocked_reason(_run)
		if why != "":
			return why
	return ""


## 用掉这一件：都能用才逐个生效，然后从腰带拿走。返回空串 = 用了，否则是原因
func use(uid: int) -> String:
	var why := can_use(uid)
	if why != "":
		return why
	var inst := belt.get_item(uid)
	var def := inst.def
	belt.remove(uid)
	for e in def.belt_use.effects:
		if e != null:
			e.apply(_run)
	used.emit(def.id)
	return ""


## 里面的件数
func item_count() -> int:
	return belt.item_count() if belt != null else 0


func to_dict() -> Dictionary:
	return {"belt": belt.to_dict() if belt != null else null}


func restore(d: Dictionary) -> void:
	_saved = d.duplicate(true)


## 开局：带进来的随身道具落在地上（棋盘不收）—— 挪进腰带，满了的留在地上
func _take_from_ground() -> void:
	if _run == null or _run.storage == null:
		return
	for inst in _run.storage.items():
		var it := inst as ItemInstance
		if it.def != null and it.def.is_belt():
			var taken := _run.storage.remove(it.uid)
			if taken != null and not belt.try_add(taken):
				_run.storage.admit(taken)

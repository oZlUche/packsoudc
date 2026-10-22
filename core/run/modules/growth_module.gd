## 207（作者定）：自然系的【生长】—— 作战棋盘上、整件在包里的会长的道具，**全局倒计时每走一步长一步**（[signal ActionClock.advanced]，
## 走路、原地耗时都算；战斗不算）。到阶扎根（[method GridInventory.is_locked]），再到阶连包扎根；加成由编译器按实例上的阶并进来。
## 休眠的（自然之神不是当前信仰）不长、不退，锁保留。
##
## 离开棋盘清零（[member GrowthProfile.reset_on_leave]）：记下每件在棋盘上时的置入序号（[member ItemInstance.placed_seq]），
## 离开了（到了别的容器）就清零；从别处回来的序号变了也清零 —— 拿在手上挪个位置序号不变，不算离开。
## 带回基地那一下由 [MetaState] 清（[method GrowthProfile.on_leave]）。
##
## 101 的插件模型：订 `travel.clock.advanced` 与 `board.changed`，计数记在实例上，自己只存「谁在棋盘上、序号多少」
class_name GrowthModule
extends RunModule

const ID := &"growth"

## 某件升了阶（以后的动画、音效挂这里）
signal grown(uid: int, stage: int)

## uid -> 在棋盘上时的置入序号（进存档：读档回来不把还在棋盘上的当成「刚放上来」）
var _seen: Dictionary = {}
## uid -> 实例（不进存档）：离开棋盘之后还找得到它、给它清零
var _insts: Dictionary = {}
var _clock: ActionClock = null


static func of(run: RunState) -> GrowthModule:
	return run.module(ID) as GrowthModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "生长：自然之神的种子在背包里随倒计时长大，长到一定阶段就扎根"


func to_dict() -> Dictionary:
	var out := {}
	for uid in _seen:
		out[str(uid)] = int(_seen[uid])
	return {"seen": out} if not out.is_empty() else {}


func restore(d: Dictionary) -> void:
	_seen.clear()
	var raw: Variant = d.get("seen", {})
	if raw is Dictionary:
		for k in raw:
			_seen[int(k)] = int(raw[k])


func install(run: RunState) -> void:
	if run == null or run.board == null:
		return
	_run = run
	run.board.growth_locks = true
	if not run.board.changed.is_connected(_sync):
		run.board.changed.connect(_sync)
	var clock := run.travel.clock if run.travel != null else null
	if clock != _clock:
		if _clock != null and _clock.advanced.is_connected(_on_advanced):
			_clock.advanced.disconnect(_on_advanced)
		_clock = clock
		if _clock != null:
			_clock.advanced.connect(_on_advanced)
	_sync()


## 棋盘上会长的、整件在包里的、不休眠的那些（uid 升序）
func growing() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if _run == null or _run.board == null:
		return out
	var dormant := FaithState.dormant_uids(_run.board)
	for raw in _run.board.items():
		var inst := raw as ItemInstance
		if inst == null or inst.def == null or inst.def.growth == null:
			continue
		if dormant.has(inst.uid) or _run.board.bag_of(inst.uid) == GridInventory.EMPTY_UID:
			continue
		out.append(inst)
	out.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return a.uid < b.uid)
	return out


func _on_advanced(_total: int, delta: int) -> void:
	_sync()
	var any := false
	for inst in growing():
		if GrowthProfile.grow(inst, delta, _run.run_seed):
			any = true
			grown.emit(inst.uid, GrowthProfile.stage_of(inst))
		elif inst.def.growth.stages.size() > GrowthProfile.stage_of(inst):
			any = true     # 计数变了：悬浮窗里的「再几步」跟着变
	if any:
		_run.board.changed.emit()     # 名字前缀、扎根、加成都变了：棋盘重画


## 对一遍「谁在棋盘上」：离开的清零、从别处回来的清零
func _sync() -> void:
	if _run == null or _run.board == null:
		return
	var board := _run.board
	for uid in _seen.keys():
		if board.has_item(uid):
			continue
		var gone: ItemInstance = _insts.get(uid, null)
		if gone != null and gone.container_id == 0:
			continue     # 拿在手上：还没离开
		if gone != null:
			GrowthProfile.on_leave(gone)
		_seen.erase(uid)
		_insts.erase(uid)
	for raw in board.items():
		var inst := raw as ItemInstance
		if inst == null or inst.def == null or inst.def.growth == null:
			continue
		if _seen.has(inst.uid) and int(_seen[inst.uid]) != inst.placed_seq:
			GrowthProfile.on_leave(inst)     # 从别处回来的（地上、保险箱……）
		_seen[inst.uid] = inst.placed_seq
		_insts[inst.uid] = inst

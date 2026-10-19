## 道具耐久（148，作者定）：每场战斗结束，这一场**真的供给了**的道具（站在法杖受益格上的魔晶石，[member CombatantSpec.fed_uids]）
## 剩余次数 −1，不低于 0；没点亮的不耗（没用就不坏）。归零 = 破碎：编译器不再让它供给、卖价打折（[WearProfile]）。
## 蛮神 3 级的秒杀不算打了一场，不扣。
## 208：归零且定义写了 [member WearProfile.broken_into] 的，就地换成那件（碎晶），装载格空出来；原点放不下（不会）进地上。
##
## 101 的插件模型：只订阅 [signal NodeEvents.battle_finished]，次数记在实例上（[member ItemInstance.state]），自己不存东西
class_name WearModule
extends RunModule

const ID := &"wear"

## 这一场用掉了几件的耐久：{uid: 剩几次}
signal worn(left: Dictionary)

var _run: RunState = null


static func of(run: RunState) -> WearModule:
	return run.module(ID) as WearModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "道具耐久：魔晶石每供给一场少一次，用完就碎了"


func install(run: RunState) -> void:
	if run == null or run.events == null:
		return
	_run = run
	if not run.events.battle_finished.is_connected(_on_battle_finished):
		run.events.battle_finished.connect(_on_battle_finished)


func _on_battle_finished(_node: MapNode, _result: BattleResult, _won: bool) -> void:
	var last: Dictionary = _run.events.last_battle
	if bool(last.get("smite", false)):
		return
	var spec := last.get("player", null) as CombatantSpec
	if spec == null or _run.board == null:
		return
	var left := {}
	for uid in spec.fed_uids:
		var inst := _run.board.get_item(uid)
		if inst == null or inst.def == null or inst.def.wear == null:
			continue
		var bag := ItemWeight.bag_def_of(inst, _run.board)
		if bag != null and bag.bag_wear_free:
			continue     # 209：符文囊里的晶石不耗耐久
		left[uid] = inst.spend_charge(1)
	if left.is_empty():
		return
	for uid in left:
		if int(left[uid]) == 0:
			shatter(_run.board, _run.board.get_item(uid), _run.items, _run.storage)
	_run.board.changed.emit()     # 名字前缀变了：棋盘重画
	worn.emit(left)


## 208：把破碎的 [param inst] 换成 [member WearProfile.broken_into]（占原点那一格、朝向 0）。原地换件不算「置入」：
## 不发 [signal GridInventory.placed]，信力不记、「最后置入」的先后照旧。原点放不下就进 [param ground]。
## 返回换上的实例；不该换（没碎、没写换成什么、找不到定义）返回 null、原件不动
static func shatter(board: GridInventory, inst: ItemInstance, items: ItemDatabase, ground: ItemStash = null) -> ItemInstance:
	if board == null or inst == null or inst.def == null or inst.def.wear == null or items == null:
		return null
	if not inst.is_broken() or inst.def.wear.broken_into == &"":
		return null
	var to := items.get_def(inst.def.wear.broken_into)
	if to == null:
		return null
	var at := inst.origin
	var seq := inst.placed_seq
	if board.remove(inst.uid) == null:
		return null
	var shard := ItemInstance.create(to, 0)
	shard.container_id = board.id
	shard.placed_seq = seq
	if board.place(shard, at, 0):
		return shard
	if ground != null and ground.insert(shard):
		return shard
	board.place(inst, at, inst.rotation)     # 哪都放不下：原件放回去，什么都不换
	return null

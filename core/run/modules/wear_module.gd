## 道具耐久（148，作者定）：每场战斗结束，这一场**真的供给了**的道具（站在法杖受益格上的魔晶石，[member CombatantSpec.fed_uids]）
## 剩余次数 −1，不低于 0；没点亮的不耗（没用就不坏）。归零 = 破碎：编译器不再让它供给、卖价打折（[WearProfile]）。
## 蛮神 3 级的秒杀不算打了一场，不扣。
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
		left[uid] = inst.spend_charge(1)
	if not left.is_empty():
		_run.board.changed.emit()     # 名字前缀变了：棋盘重画
		worn.emit(left)

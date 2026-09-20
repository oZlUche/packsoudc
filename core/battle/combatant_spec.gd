## 一个战斗单位的完整编译结果。[BattleSim] 只吃它，不碰背包。
class_name CombatantSpec
extends RefCounted

var max_hp: int = 0                  ## 定点

## 角色自带的基础属性（生命上限、耐力上限…），不属于任何道具。
## 为 null 时该单位没有任何自带属性 —— 手搓的测试假人就是这样。
var baseline: StatSet = null
## 按 source_uid 升序，顺序稳定
var items: Array[CompiledItem] = []

## 套装带来的规则。不属于任何物品，来源 uid 为 0，取属性时退回单位级。
var set_rules: Array[AbilityRule] = []

var _by_uid: Dictionary = {}


func add(item: CompiledItem) -> void:
	items.append(item)
	_by_uid[item.source_uid] = item


func stats_of(uid: int) -> StatSet:
	var it: CompiledItem = _by_uid.get(uid, null)
	return it.stats if it != null else null


func item_of(uid: int) -> CompiledItem:
	return _by_uid.get(uid, null)


## 有规则的物品
func active_items() -> Array[CompiledItem]:
	var out: Array[CompiledItem] = []
	for it in items:
		if it.is_active():
			out.append(it)
	return out


func max_hp_int() -> int:
	return StatMath.to_int(max_hp)


func rough_dps() -> float:
	var total := 0.0
	for it in items:
		total += it.estimated_dps()
	return total


func _to_string() -> String:
	return "CombatantSpec(HP=%d, %d 件物品 / %d 件主动, 约 %.1f DPS)" % [
		max_hp_int(), items.size(), active_items().size(), rough_dps()
	]

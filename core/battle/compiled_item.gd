## 一件物品的编译结果：结算后的属性快照 + 它的规则表。
##
## 原名 Ability。改名是因为它承载的已不止「一个能力」——
## 一件物品可以有多条规则（平时按冷却出手、受击时反击、开局加护盾）。
class_name CompiledItem
extends RefCounted

var source_uid: int = 0
var def_id: StringName = &""
## 结算后的属性快照。战斗中不再回头读背包。
var stats: StatSet = null
var rules: Array[AbilityRule] = []


func is_active() -> bool:
	return not rules.is_empty()


## 粗略 DPS，供玩家拖动物品时实时预估。
## 不考虑触发顺序、消耗与状态效果，只做手感参考。
func estimated_dps() -> float:
	var total := 0.0
	for rule in rules:
		var r := rule as AbilityRule
		if r.cadence == null:
			continue
		var hz := r.cadence.estimated_hz(stats)
		if hz <= 0.0:
			continue
		for effect in r.effects:
			total += hz * (effect as Effect).estimated_damage(stats)
	return total


func _to_string() -> String:
	return "CompiledItem(%s uid=%d %d 条规则 约 %.1f DPS)" % [
		def_id, source_uid, rules.size(), estimated_dps()
	]

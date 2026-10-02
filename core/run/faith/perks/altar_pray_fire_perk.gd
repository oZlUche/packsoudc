## 日神 2 级（093）：在神坛祈祷，获得局内永久的火焰伤害加成，非线性 —— 次数记进 AltarModule.rituals["pray_fire"]，火焰附魔（EnchantWeaponsPerk）按 pray_percent × n^curve 读
class_name AltarPrayFirePerk
extends FaithPerk

const KEY := "pray_fire"
@export var max_times: int = 0


func altar_label() -> String:
	return "祈祷（火焰伤害永久加成，越祈越多但越来越慢）"


func altar_available(run: RunState, _node: MapNode) -> String:
	var rituals := AltarModule.rituals_of(run)
	return "" if max_times <= 0 or int(rituals.get(KEY, 0)) < max_times else "祈祷已到上限"


func altar_apply(run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	var rituals := AltarModule.rituals_of(run)
	rituals[KEY] = int(rituals.get(KEY, 0)) + 1
	var altar := AltarModule.of(run)
	var ench := altar.perk(&"enchant_weapons") if altar != null else null
	var bonus: int = int(ench.call("fire_bonus", run)) if ench != null else 0
	return "向日神祈祷（第 %d 次）：火焰伤害加成现在 +%d%%" % [int(rituals[KEY]), bonus]


func _summary() -> String:
	return "神坛：祈祷换局内永久火焰伤害加成（非线性）"

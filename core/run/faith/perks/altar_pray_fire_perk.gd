## 日神 2 级（093）：在神坛祈祷，获得局内永久的火焰伤害加成，非线性 —— 次数记进 faith_rituals["pray_fire"]，火焰附魔（EnchantWeaponsPerk）按 pray_percent × n^curve 读
class_name AltarPrayFirePerk
extends FaithPerk

const KEY := "pray_fire"
@export var max_times: int = 0


func altar_label() -> String:
	return "祈祷（火焰伤害永久加成，越祈越多但越来越慢）"


func altar_available(run: RunState, _node: MapNode) -> String:
	return "" if max_times <= 0 or int(run.faith_rituals.get(KEY, 0)) < max_times else "祈祷已到上限"


func altar_apply(run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	run.faith_rituals[KEY] = int(run.faith_rituals.get(KEY, 0)) + 1
	var ench := run.faith_perk(&"enchant_weapons")
	var bonus: int = int(ench.call("fire_bonus", run)) if ench != null else 0
	return "向日神祈祷（第 %d 次）：火焰伤害加成现在 +%d%%" % [int(run.faith_rituals[KEY]), bonus]


func describe() -> String:
	return note if note != "" else "神坛：祈祷换局内永久火焰伤害加成（非线性）"

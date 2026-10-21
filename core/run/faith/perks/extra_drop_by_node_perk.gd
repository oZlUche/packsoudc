## 日神 4 级（093）：敌人必定掉落一个额外道具，稀有度按点的类型：普通 3 紫 / 精英 4 金 / BOSS 5 红
class_name ExtraDropByNodePerk
extends FaithPerk

@export var by_type: Dictionary = {"battle": 3, "elite": 4, "core": 5}


func modify_loot(ctx: LootContext, node_type: StringName) -> void:
	var key := String(node_type)
	if by_type.has(key):
		ctx.extra_drop_rarity = maxi(ctx.extra_drop_rarity, int(by_type[key]))


func _summary() -> String:
	return UiText.t("perk.extra_drop")

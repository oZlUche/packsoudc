## 提高某个稀有度的出现率。
class_name RarityBias
extends LootEffect

@export var rarity: int = 3
## 权重偏移，正数偏向该稀有度
@export var amount: int = 10

func modify(ctx: LootContext) -> void:
	ctx.add_rarity_bias(rarity, amount)

func describe() -> String:
	return UiText.t("loot.rarity_bias") % [rarity, amount]

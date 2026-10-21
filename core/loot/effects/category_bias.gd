## 提高某类道具的出现率。类别用标签表示，与物品的 tags 对应。
class_name CategoryBias
extends LootEffect

@export var tag: StringName = &"weapon"
@export var amount: int = 10

func modify(ctx: LootContext) -> void:
	ctx.add_category_bias(tag, amount)

func describe() -> String:
	return UiText.t("loot.category_bias") % [tag, amount]

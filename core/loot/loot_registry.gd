## 战利品那一层的构件注册表（101 第 5 刀，从 [EffectRegistry] 拆出来）：类型名 → 脚本路径。
##
## 战斗那一层的在 [EffectRegistry]，一局那一层的在 [RunRegistry]；三张合起来见 [ContentRegistries]（查表都走那边，这里只是常量）。
class_name LootRegistry
extends RefCounted

## 战利品作用域的效果。**不依赖扳机，激活即生效。**
const LOOT_EFFECTS := {
	&"extra_rolls": "res://core/loot/effects/extra_rolls.gd",
	&"rarity_bias": "res://core/loot/effects/rarity_bias.gd",
	&"category_bias": "res://core/loot/effects/category_bias.gd",
	&"drop_owned_chance": "res://core/loot/effects/drop_owned_chance.gd",
}


const TABLES := {
	&"loot_effect": LOOT_EFFECTS,
}

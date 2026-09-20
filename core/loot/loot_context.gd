## 战利品掉落计算的上下文。[LootEffect] 通过它施加影响。
##
## [b]掉落系统（M4）尚未实现[/b] —— 这里先把接口定下来，
## 好让套装与道具的战利品效果现在就能被写出来并测试。
## 真正的掉落表、权重表等 M4 时再接。
class_name LootContext
extends RefCounted

## 基础掉落次数
var rolls: int = 1

## 稀有度 → 权重偏移。正数偏向该稀有度。
var rarity_bias: Dictionary = {}

## 物品类别（标签）→ 权重偏移
var category_bias: Dictionary = {}

## 敌人掉落其自身携带道具的概率（定点，0..ONE）
var drop_owned_chance: int = 0


func add_rolls(n: int) -> void:
	rolls = maxi(0, rolls + n)


func add_rarity_bias(rarity: int, amount: int) -> void:
	rarity_bias[rarity] = int(rarity_bias.get(rarity, 0)) + amount


func add_category_bias(tag: StringName, amount: int) -> void:
	category_bias[tag] = int(category_bias.get(tag, 0)) + amount


func add_drop_owned_chance(amount: int) -> void:
	drop_owned_chance = clampi(drop_owned_chance + amount, 0, StatMath.ONE)


func snapshot() -> Dictionary:
	return {
		"rolls": rolls,
		"rarity_bias": rarity_bias.duplicate(),
		"category_bias": category_bias.duplicate(),
		"drop_owned_chance": drop_owned_chance,
	}

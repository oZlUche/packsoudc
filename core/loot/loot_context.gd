## 战利品掉落计算的上下文（架构文档 6.1）。[LootEffect] 通过它施加影响，[DropResolver] 读它掷骰。
##
## 四个来自道具 / 套装效果树的量（rolls、rarity_bias、category_bias、drop_owned_chance）是 M2 就定下的接口；
## M4-2 加了作者要的修正来源：难度、幸运值，以及局外 buff / 地图 buff 的接缝（[member sources]）。
## 各量在掉落里的用处见 [DropResolver] 的类注释。
class_name LootContext
extends RefCounted

## 珍宝尝试次数（基础 1）。「掉落次数 +1」的道具效果加在这里
var rolls: int = 1

## 稀有度 → 权重偏移。正数偏向该稀有度（珍宝抽稀有度时加到权重上）
var rarity_bias: Dictionary = {}

## 物品类别（标签）→ 权重偏移（珍宝在候选里抽哪件时加权）
var category_bias: Dictionary = {}

## 敌人掉落其自身携带道具的概率加成（定点，0..ONE）
var drop_owned_chance: int = 0

## 章节难度（正面加成，每级加 DropRule.difficulty_bonus）
var difficulty: int = 0

## 幸运值，可正可负（每点加 DropRule.luck_bonus）。谁提供幸运值是 run 层的事（角色、buff……）
var luck: int = 0

## 其他修正来源：局外 buff、地图 buff —— 都是 [DropBonusSource]，现在是占位实现
var sources: Array[DropBonusSource] = []


func add_rolls(n: int) -> void:
	rolls = maxi(0, rolls + n)


func add_rarity_bias(rarity: int, amount: int) -> void:
	rarity_bias[rarity] = int(rarity_bias.get(rarity, 0)) + amount


func add_category_bias(tag: StringName, amount: int) -> void:
	category_bias[tag] = int(category_bias.get(tag, 0)) + amount


func add_drop_owned_chance(amount: int) -> void:
	drop_owned_chance = clampi(drop_owned_chance + amount, 0, StatMath.ONE)


func add_source(source: DropBonusSource) -> void:
	if source != null:
		sources.append(source)


func snapshot() -> Dictionary:
	return {
		"rolls": rolls,
		"rarity_bias": rarity_bias.duplicate(),
		"category_bias": category_bias.duplicate(),
		"drop_owned_chance": drop_owned_chance,
		"difficulty": difficulty,
		"luck": luck,
		"sources": sources.size(),
	}

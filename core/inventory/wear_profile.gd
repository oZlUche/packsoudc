## 148：道具的**耐久**（次数制）—— 剩几次记在实例上（[member ItemInstance.state] 的 `charges`），名字前缀由它算。
##
## 一件道具一个定义：明亮 / 闪烁 / 黯淡 / 破碎不是四件道具，是同一件的四种状态（报告 148 设计点 1）。
## 什么时候扣由 [WearModule] 管（这一种是「每场战斗结束，点亮过的 −1」）。归零 = 破碎：不再供给（[member AdjacencyProfile.feed_mods]），卖价打折
class_name WearProfile
extends Resource

const CHARGES_KEY := "charges"

## 满的时候几次
@export var max_charges: int = 3
## 246：一档几次 —— 前缀下标 = (剩余 − 1) ÷ 这个数（一档一次时就是剩余 − 1）
@export var charge_band: int = 1
## 前缀，下标 = (剩余次数 − 1) ÷ [member charge_band]（剩 1 次用第一个）。比档数短时用最后一个
@export var prefixes: Array[String] = ["黯淡的", "闪烁的", "明亮的"]
## 别的语言的前缀：`{"en": ["Dim ", "Flickering ", "Bright "]}`（前缀直接拼在名字前，英文自己带空格）
@export var prefixes_by_lang: Dictionary = {}
@export var broken_prefix: String = "破碎的"
@export var broken_prefixes: Dictionary = {}
## 破碎的卖价是原价的几成
@export var broken_value_ratio: float = 0.25
## 208：归零就换成这件道具（碎晶 `crystal_shards`，占原点那一格）；空 = 破碎的原件留在格里
@export var broken_into: StringName = &""
## 246 补充二：破碎的原件留在格里时稀有度低几档（[method ItemInstance.rarity]：框色、卖价都按它）
@export var broken_rarity_drop: int = 0
## 246：按剩余次数换的变体图有几张（`@c0`～`@c<张数 − 1>`，c0 是碎的那张）—— 次数多于张数时折算（[method art_variant]）
@export var art_levels: int = 4


## 剩 [param charges] 次时的前缀（0 = 破碎）
func prefix_for(charges: int, lang: String = "") -> String:
	if charges <= 0:
		return Names.pick(broken_prefixes, broken_prefix, lang)
	var table: Array = prefixes
	var other: Variant = prefixes_by_lang.get(lang if lang != "" else UiText.lang, null)
	if other is Array and not (other as Array).is_empty():
		table = other
	if table.is_empty():
		return ""
	return String(table[clampi((charges - 1) / maxi(1, charge_band), 0, table.size() - 1)])


## 246：剩 [param charges] 次用第几张变体图 —— 满的不用（-1，画本图）；归零 = 0（碎的那张）；
## 其余把 1～满 − 1 均分到 1～[member art_levels] − 1 张上（满九次、四张：1～3 → c1，4～6 → c2，7～8 → c3）
func art_variant(charges: int) -> int:
	if charges >= max_charges:
		return -1
	if charges <= 0:
		return 0
	var steps := maxi(1, art_levels - 1)
	return clampi(ceili(float(charges) * steps / float(max_charges)), 1, steps)

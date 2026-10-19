## 148：道具的**耐久**（次数制）—— 剩几次记在实例上（[member ItemInstance.state] 的 `charges`），名字前缀由它算。
##
## 一件道具一个定义：明亮 / 闪烁 / 黯淡 / 破碎不是四件道具，是同一件的四种状态（报告 148 设计点 1）。
## 什么时候扣由 [WearModule] 管（这一种是「每场战斗结束，点亮过的 −1」）。归零 = 破碎：不再供给（[member AdjacencyProfile.feed_mods]），卖价打折
class_name WearProfile
extends Resource

const CHARGES_KEY := "charges"

## 满的时候几次
@export var max_charges: int = 3
## 前缀，下标 = 剩余次数 − 1（剩 1 次用第一个）。比满次数短时用最后一个
@export var prefixes: Array[String] = ["黯淡的", "闪烁的", "明亮的"]
## 别的语言的前缀：`{"en": ["Dim ", "Flickering ", "Bright "]}`（前缀直接拼在名字前，英文自己带空格）
@export var prefixes_by_lang: Dictionary = {}
@export var broken_prefix: String = "破碎的"
@export var broken_prefixes: Dictionary = {}
## 破碎的卖价是原价的几成
@export var broken_value_ratio: float = 0.25
## 208：归零就换成这件道具（碎晶 `crystal_shards`，占原点那一格）；空 = 破碎的原件留在格里
@export var broken_into: StringName = &""


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
	return String(table[clampi(charges - 1, 0, table.size() - 1)])

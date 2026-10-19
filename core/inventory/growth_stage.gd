## 207：生长的一阶（种子之后的茎叶、绽放……）。按序写在 [member GrowthProfile.stages] 里。
##
## [member mods] / [member rules] 是**到了这一阶的那一份**（不累加：表里写终值，作者改数一眼看全）。
## [member bonus_pool] 非空 = 到阶时按 `hash(局种子, uid, 阶)` 抽 [member bonus_count] 条，抽中的下标记在实例上（重开不变）
class_name GrowthStage
extends Resource

## 111：`@export_enum` 的可选值，导入器从这里读
const LOCK_NONE := "none"
const LOCK_ITEM := "item"
const LOCK_BAG := "bag"

## 悬浮窗里这一阶叫什么（「茎叶」）
@export var name: String = ""
## 别的语言：`{"en": "Sprout"}`
@export var names_by_lang: Dictionary = {}
## 名字前缀（「抽芽的」），直接拼在名字前（英文自己带空格）
@export var prefix: String = ""
@export var prefixes_by_lang: Dictionary = {}
## 从上一阶起再走几步全局倒计时才到这一阶（作者的 N、M），至少 1
@export_range(1, 999) var after: int = 4
## 到了这一阶锁什么：none 不锁 / item 这件拖不动、挪不走 / bag 这件和它所在的包都动不了（包里别的照旧能动）
@export_enum("none", "item", "bag") var lock: String = "item"
## 这一阶的属性修饰（终值）
@export var mods: Array[StatModifier] = []
## 这一阶的规则（终值；同信仰加成，不许有 costs）
@export var rules: Array[AbilityRule] = []
## 「有可能获得额外效果」：到阶时从这里抽
@export var bonus_pool: Array[GrowthBonus] = []
## 抽几条（不超过池子大小）
@export_range(0, 9) var bonus_count: int = 0


func name_in(lang: String = "") -> String:
	return Names.pick(names_by_lang, name, lang)


func prefix_in(lang: String = "") -> String:
	return Names.pick(prefixes_by_lang, prefix, lang)


func locks_item() -> bool:
	return lock == LOCK_ITEM or lock == LOCK_BAG


func locks_bag() -> bool:
	return lock == LOCK_BAG


## 这一阶本身的效果一句（属性修饰 + 规则）
func effect_text() -> String:
	return effect_text_of(mods, rules, "")


static func effect_text_of(p_mods: Array, p_rules: Array, note: String) -> String:
	var bits: Array[String] = []
	if not p_mods.is_empty():
		bits.append(Glossary.mods_text(p_mods))
	for r in p_rules:
		if r is AbilityRule:
			bits.append(Glossary.rule_text(r))
	if note != "":
		bits.append(TextTemplate.render(note, {}))
	return "；".join(bits) if not bits.is_empty() else "（无）"

## 角色自带的基础属性 —— 不属于任何道具的那一份。
##
## [b]占位，等角色系统。[/b] 现在全局只有一份默认值；将来不同角色会有不同的
## 初始生命上限、耐力上限与其他资源，届时由角色定义提供一份本资源即可，
## 编译器与战斗一行不改。
##
## 为什么不是一个 `base_hp: float` 参数：那样只表达得了生命。
## 玩家开局捡到一把枪却因为没有耐力而一发打不出，是个只有做成属性表才能修的坑 ——
## 资源种类本来就是可扩展的（配一个 max_xxx 就多一种），基线也必须同样可扩展。
class_name CombatantBaseline
extends Resource

## 属性键 → 数值（写浮点，编译期转定点）。键见 [BattleStats]。
@export var base_stats: Dictionary = {}

## run 级默认值。角色系统落地前，所有单位都用这一份。
## [b]数值是占位[/b]，等内容定稿。结构才是要紧的：多一种资源就多两行。
const DEFAULT_STATS := {
	"max_hp": 25.0,
	"max_stamina": 50.0,
	"regen_stamina": 4.0,
}


static func default_baseline() -> CombatantBaseline:
	var b := CombatantBaseline.new()
	b.base_stats = DEFAULT_STATS.duplicate()
	return b


## 只改生命上限的便捷构造，其余沿用默认。测试与调参用。
static func with_hp(hp: float) -> CombatantBaseline:
	var b := default_baseline()
	b.base_stats["max_hp"] = hp
	return b


## 写进一份 StatSet
func seed_stats(into: StatSet) -> void:
	for key in base_stats:
		into.set_base(StringName(key), StatMath.from_float(float(base_stats[key])))


func value_of(key: StringName, fallback: float = 0.0) -> float:
	return float(base_stats.get(String(key), fallback))

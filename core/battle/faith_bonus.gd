## 信仰道具在信力过了第 [member tier] 阶之后多出来的功能（作者定，报告 082）：属性修饰与规则，和道具本身的战斗定义同一套词汇。
## 写在道具上（[ItemDef.faith_bonuses]），[BattleCompiler.compile] 按传进来的「信仰 → 现在第几阶」决定并不并入。
class_name FaithBonus
extends Resource

## 生效方式（095，作者定）：tier = 过了第 tier 阶；active = 激活即生效；scaled = 按信力每 per_points 算一份（最多 max_stacks 份，0 = 不限）
@export var mode: String = "tier"
## 第几阶起生效（1 = 过了第一道阈值；mode = tier 用）
@export var tier: int = 1
@export var per_points: int = 50
@export var max_stacks: int = 0
## 施加给这件道具的属性修饰
@export var mods: Array[StatModifier] = []
## 多出来的规则
@export var rules: Array[AbilityRule] = []
## 给界面的补充一句，接在按字段拼的主句后面（104 第十节：不再和主句各写一遍数）；是 [TextTemplate] 模板，数写 `{per_points}` 这类字段名
@export var note: String = ""


## 现在给几份（0 = 不生效）：[param p_tier] 现在第几阶、[param points] 现在多少信力
func times_for(p_tier: int, points: int) -> int:
	match mode:
		"active":
			return 1
		"scaled":
			@warning_ignore("integer_division")
			var n := points / maxi(1, per_points)
			return mini(n, max_stacks) if max_stacks > 0 else n
		_:
			return 1 if p_tier >= tier else 0


## 生效条件的一句：「激活即」「Lv.2」「每 50 信力一份，最多 6 份」（104：阶统一写 Lv.n）
func gate_text() -> String:
	match mode:
		"active":
			return "激活即"
		"scaled":
			return "每 %d 信力一份%s" % [per_points, ("，最多 %d 份" % max_stacks) if max_stacks > 0 else ""]
		_:
			return "Lv.%d" % tier


## 给界面的一整句（104 第十节）：生效条件 + 属性修饰 + 规则 + 作者补充。道具浮窗、信仰浮窗都用它，数只来自字段
func describe() -> String:
	var bits: Array[String] = []
	if not mods.is_empty():
		bits.append(Glossary.mods_text(mods))
	for r in rules:
		if r is AbilityRule:
			bits.append(Glossary.rule_text(r))
	if note != "":
		bits.append(TextTemplate.render(note, TextParams.of(self)))
	return "%s：%s" % [gate_text(), "；".join(bits) if not bits.is_empty() else "（无）"]

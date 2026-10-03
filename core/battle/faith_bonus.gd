## 信仰道具在信力过了第 [member tier] 阶之后多出来的功能（作者定，报告 082）：属性修饰与规则，和道具本身的战斗定义同一套词汇。
## 写在道具上（[ItemDef.faith_bonuses]），[BattleCompiler.compile] 按传进来的「信仰 → 现在第几阶」决定并不并入。
class_name FaithBonus
extends Resource

## 111（作者定）：编辑器里哪个字段在什么方式下才显示 —— 按阶只有「第几阶」一个框，激活即没有框，按信力是「每多少信力一份」与叠层上限。
## 没列的字段永远显示；切走时隐藏的字段归默认值（[method ContentSchema.field_visible]）
const FIELD_WHEN := {
	"tier": {"mode": ["tier"]},
	"per_points": {"mode": ["scaled"]},
	"max_stacks": {"mode": ["scaled"]},
}

## 生效方式（095，作者定）：tier = 过了第 tier 阶；active = 激活即生效；scaled = 按信力每 per_points 算一份（最多 max_stacks 份，0 = 不限）。
## 111：`@export_enum` —— 编辑器里是下拉，JSON 里照旧是字符串
@export_enum("tier", "active", "scaled") var mode: String = "tier"
## 第几阶起生效（1 = 过了第一道阈值；mode = tier 用）。表单限 1～5，导入器再按这件道具所属信仰的阈值数拦一次
@export_range(1, 5) var tier: int = 1
## 每多少信力算一份（mode = scaled 用），正整数
@export_range(1, 100000) var per_points: int = 50
## 最多几份，0 = 不限（mode = scaled 用）
@export_range(0, 999) var max_stacks: int = 0
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

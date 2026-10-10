## 战斗基线加成：生命上限、耐力上限……（4.2 的属性键）。[RunState.effective_baseline] 把它盖到基线上。
## 149：[member mode] = MULT 时 [member amount] 是百分数（10 = +10%），乘角色面板；乘算相加后乘一次、再加加算（133）
class_name StatBonus
extends RunEffect

enum Mode { ADD, MULT }

@export var stat: StringName = &"max_hp"
@export var mode: Mode = Mode.ADD
## 加算 = 固定值；乘算 = 百分数
@export var amount: float = 0.0


func modify(ctx: RunContext) -> void:
	var into := ctx.stat_mult if mode == Mode.MULT else ctx.stat_bonus
	into[stat] = float(into.get(stat, 0.0)) + amount


func describe() -> String:
	var names := {"max_hp": "生命", "max_stamina": "耐力", "regen_stamina": "耐力回复"}
	var what: String = names.get(String(stat), String(stat))
	return "%s %+.0f%%" % [what, amount] if mode == Mode.MULT else "%s %+.0f" % [what, amount]

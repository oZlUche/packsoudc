## 战斗基线加成：生命上限、耐力上限……（4.2 的属性键）加多少（布鲁图斯的被动）。[RunState.compile_player] 把它盖到基线上
class_name StatBonus
extends RunEffect

@export var stat: StringName = &"max_hp"
@export var amount: float = 0.0


func modify(ctx: RunContext) -> void:
	ctx.stat_bonus[stat] = float(ctx.stat_bonus.get(stat, 0.0)) + amount


func describe() -> String:
	var names := {"max_hp": "生命", "max_stamina": "耐力", "regen_stamina": "耐力回复"}
	return "%s %+.0f" % [names.get(String(stat), String(stat)), amount]

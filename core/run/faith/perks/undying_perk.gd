## 蛮神 4 级（093）：战斗中生命归零后仍可坚持 [member seconds] 秒 —— 期间耐力无限、受到的伤害照记（喂信力）；到期血还是 0 才真倒下，被治回来就活着。
## 落在结算内核：CombatantRuntime.undying_sec（从 spec.flags 读）、mark_dead / settle_undying；一场只一次
class_name UndyingPerk
extends FaithPerk

@export var seconds: float = 10.0


func modify_spec(spec: CombatantSpec, _board: GridInventory, _run: RunState) -> void:
	spec.flags["undying_sec"] = maxf(float(spec.flags.get("undying_sec", 0.0)), seconds)


func _summary() -> String:
	return "生命归零后仍坚持 %.0f 秒：耐力无限、伤害照记；到期血还是 0 才倒下" % seconds


## 103：作用于角色本身 → 进 buff 栏
func battle_note(_run: RunState) -> String:
	return describe()

## 蛮神 4 级（093）：战斗中生命归零后仍可坚持 [member seconds] 秒 —— 期间耐力无限、受到的伤害照记（喂信力）；到期血还是 0 才真倒下，被治回来就活着。
## 落在结算内核：[member CompileInput.undying_sec] → [member CombatantSpec.undying_sec]（101 第 5 刀：带类型的字段，不再是 `flags` 里的字符串键）、
## [CombatantRuntime] 的 mark_dead / settle_undying；一场只一次
class_name UndyingPerk
extends FaithPerk

@export var seconds: float = 10.0


func compile_into(input: CompileInput, _board: GridInventory, _run: RunState) -> void:
	input.keep_undying(seconds)


func _summary() -> String:
	return "生命归零后仍坚持 %.0f 秒：耐力无限、伤害照记；到期血还是 0 才倒下" % seconds


## 103：作用于角色本身 → 进 buff 栏
func battle_note(_run: RunState) -> String:
	return describe()

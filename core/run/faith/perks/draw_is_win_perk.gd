## 自然 5 级（093）：平局也视为胜利（战斗单位上立旗，BattleSim 收尾时读）
class_name DrawIsWinPerk
extends FaithPerk


func modify_spec(spec: CombatantSpec, _board: GridInventory, _run: RunState) -> void:
	spec.flags["draw_is_win"] = true


func draw_is_win() -> bool:
	return true


func describe() -> String:
	return note if note != "" else "平局也算胜利"

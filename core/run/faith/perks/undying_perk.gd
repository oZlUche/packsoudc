## 蛮神 4 级（093；188 补充一作者改写）：战斗中首次生命归零后仍持续战斗 X 秒，X 随信力（[member base_sec] + （信力 / [member step] 取整） × [member per_sec]，
## 不超过 [member max_sec]；开战时的信力定一场）—— 期间耐力无限、受到的伤害照记（喂信力）；到期血还是 0 才真倒下，被治回来就活着。
## 落在结算内核：[member CompileInput.undying_sec] → [member CombatantSpec.undying_sec]、[CombatantRuntime] 的 mark_dead / settle_undying；一场只一次
class_name UndyingPerk
extends FaithPerk

@export var base_sec: float = 2.0
@export var step: int = 50
@export var per_sec: float = 1.0
@export var max_sec: float = 20.0


## 有 [param points] 信力时坚持几秒
func seconds_at(points: int) -> float:
	return FaithPerk.scaled(points, base_sec, step, per_sec, max_sec)


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	input.keep_undying(seconds_at(FaithPerk.points_now(run)))


func _summary() -> String:
	return summary_for(null, 0)


func summary_for(_def: FaithDef, points: int) -> String:
	return UiText.t("perk.undying") % TextTemplate.num(seconds_at(points))


## 103：作用于角色本身 → 进 buff 栏
func battle_note(run: RunState) -> String:
	return summary_for(null, FaithPerk.points_now(run))

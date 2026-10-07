## 后果：从猎手面前逃跑（071）。只立旗，[NodeEvents] 让猎手系统掷成功率；没逃掉接着打。
## 136：写了 [member skill]（「脱身」）= 用那个局内技能逃，必定逃掉、记一次技能的账
class_name HunterFlee
extends EventOutcome

@export var skill: StringName = &""


func apply(ctx: EventContext) -> void:
	ctx.hunter_flee = true
	ctx.flee_skill = skill


func describe() -> String:
	return "逃跑" if skill == &"" else "用「%s」逃跑（必定逃掉）" % skill

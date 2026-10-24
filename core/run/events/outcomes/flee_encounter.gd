## 后果（248）：被缠上了逃跑 —— 搜索遭遇、伏击。只立旗，[NodeEvents] 按节点规则的 `flee` 掷成功率（加 buff 的 flee_bonus）：
## 逃掉和「脱身」同一条路（点用过、没战利品，搜索会话按 slipped 收）；没逃掉扣体力、背虚弱，接着开打。猎手走自己的 [HunterFlee]
class_name FleeEncounter
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.flee_encounter = true


func describe() -> String:
	return "逃跑（掷成功率，失败扣体力、背虚弱后开打）"

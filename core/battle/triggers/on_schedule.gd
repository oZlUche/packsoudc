## 自发型：不等任何事件，由频率层排出下一次执行时刻。
##
## 取代了原来的 OnTick。**模拟里没有帧** —— 帧是渲染概念，
## 「每帧检查一下冷却好没好」是固定步长模拟才需要的东西。
## 事件驱动的模拟直接算出下一次出手的精确时刻，在时刻之间跳跃。
##
## 搭配 [CooldownCadence] 即为「每 N 秒出手一次」，且 N 可以是任意小数。
## 要「每 3 次才真打一发」，在 costs 里加一条 [ChargeCost] —— 那属于消耗层，
## 挡住时冷却照常推进，不会让调度器卡在同一时刻。
class_name OnSchedule
extends Trigger

## 自发型不订阅任何事件，它靠时间轮驱动
func subscribed_events() -> Array[StringName]:
	return [] as Array[StringName]


func matches(_ctx: RuleContext, _event: BattleEvent) -> bool:
	return false


## 供 [BattleSim] 识别：本规则要进时间轮
func is_self_driven() -> bool:
	return true


## 142：自发的不写「自发」，方括号里写频率（[method Glossary.rule_text] 拼「每 N 秒」）
func describe() -> String:
	return "自发"

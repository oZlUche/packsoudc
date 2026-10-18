## 后果：原地耗掉几个行动点（8-3）—— 扎营、等人、修东西。行动计数走、侵蚀照推进、站的这个点照结算，猎手也得一个回合
class_name PassTime
extends EventOutcome

@export var actions: int = 1


func apply(ctx: EventContext) -> void:
	ctx.wait_actions += maxi(0, actions)


func describe() -> String:
	return "%s −%d" % [Glossary.COUNTDOWN_WORD, maxi(0, actions)]

## 施加增益／减益。
##
## [b]会改变规则集[/b]（buff 可携带 rules），因此施加后必须重算事件掩码 ——
## 否则新规则订阅的事件可能尚未开启，那条规则会静默失效。
class_name ApplyStatus
extends Effect

enum Target { OPPONENT, SELF }

@export var target: Target = Target.OPPONENT
@export var buff: BuffDef
@export var stacks: int = 1


func apply(ctx: RuleContext) -> void:
	if buff == null:
		return
	var who := ctx.opponent() if target == Target.OPPONENT else ctx.owner
	var had := who.find_buff(buff.id) != null
	var added := who.apply_buff(buff, maxi(1, stacks))
	if added <= 0 and had:
		return

	ctx.battle.emit(BattleEvent.STATUS_STACKED, who.side, {
		"buff": String(buff.id), "delta": added, "stacks": who.stacks_of(buff.id),
	})
	# 新 buff 带来了新规则，订阅集变了，必须重算掩码
	if not had and not buff.rules.is_empty():
		ctx.battle.refresh_event_mask()
	for e in buff.on_apply:
		(e as Effect).apply(ctx)


func describe() -> String:
	return "施加 %s" % (buff.display_name if buff != null else "?")

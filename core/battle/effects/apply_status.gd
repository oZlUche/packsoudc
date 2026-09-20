## 施加增益／减益。
##
## [b]会改变规则集[/b]（buff 可携带 rules），索引重建由 [CombatantRuntime] 自动完成。
class_name ApplyStatus
extends CombatEffect

@export var target: Target = Target.OPPONENT
@export var buff: BuffDef
@export var stacks: int = 1
## 层数是否乘以来源 buff 的层数
@export var per_stack: bool = false


func apply(ctx: RuleContext) -> void:
	if buff == null:
		return
	var n := maxi(1, stacks) * (ctx.source_stacks() if per_stack else 1)
	for who in resolve_targets(ctx, target):
		var added := who.apply_buff(buff, n, ctx.battle.now)
		if added <= 0:
			continue
		ctx.battle.emit(BattleEvent.STATUS_STACKED, who.side, {
			"buff": String(buff.id), "delta": added, "stacks": who.stacks_of(buff.id),
		})
		for e in buff.on_apply:
			(e as CombatEffect).apply(ctx)


func describe() -> String:
	return "施加 %s" % (buff.display_name if buff != null else "?")

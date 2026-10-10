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
		give(ctx, who, buff, n)


## 给 [param who] 叠 [param n] 层 [param def]，返回实际加上的层数。加上了才发 status_stacked 与 130 的 status_applied
## （施加方 = 本规则的主人）、跑 on_apply；叠满了只刷新时长的那一下什么都不发。[ConvertStatus] 也走这里
static func give(ctx: RuleContext, who: CombatantRuntime, def: BuffDef, n: int) -> int:
	var added := who.apply_buff(def, n, ctx.battle.now)
	if added <= 0:
		return 0
	var stacks := who.stacks_of(def.id)
	ctx.battle.emit(BattleEvent.STATUS_STACKED, who.side, {
		"buff": String(def.id), "delta": added, "stacks": stacks,
	})
	ctx.battle.emit(BattleEvent.STATUS_APPLIED, who.side, {
		"buff": String(def.id), "delta": added, "stacks": stacks, "source_side": ctx.owner.side,
	})
	for e in def.on_apply:
		(e as CombatEffect).apply(ctx)
	return added


## 087（作者定）：只写名词，不写细节 —— 「血怒」的「伤害 +10%」、永续与层数上限都在词条的侧窗里（[Glossary.describe_buff]）
func describe() -> String:
	if buff == null:
		return "施加 ?"
	return "%s%s%s" % ["施加" if target != Target.SELF else "获得", Names.of(buff), ("×%d" % stacks) if stacks > 1 else ""]


## 151：估值 —— 层数 × 一层在那一边身上总共值多少（[method BuffDef.stack_value]，从那一边的角度）；
## 给对手的取反（对手身上的增益是我的损失、减益是我的收益）
func estimated_value(ctx: PowerContext) -> float:
	if buff == null:
		return NAN
	var n := stacks * (ctx.stacks_or_assumed() if per_stack else 1.0)
	var v := 0.0
	if target != Target.OPPONENT:
		v += n * buff.stack_value(ctx.for_carrier(true))
	if target != Target.SELF:
		v -= n * buff.stack_value(ctx.for_carrier(false))
	return v


## 151：不可叠层的 buff 还在身上时再上一次是白费：min(1, 1 ÷ (一秒几次 × 平均待多久))
func estimated_cap(ctx: PowerContext, rate: float) -> float:
	if buff == null or buff.is_stackable():
		return 1.0
	var stay := rate * ctx.weights.expected_duration(buff.duration_sec, buff.is_permanent())
	return minf(1.0, 1.0 / stay) if stay > 0.0 else 1.0

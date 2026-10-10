## 减少增益／减益的层数。
##
## 「净化」「驱散」「削减对手的蓄力」都用它。[member stacks] 为 0 表示**全部移除**。
## 132：[member all_debuffs] / [member all_buffs] 一次清光目标身上全部减益 / 增益（按 [member BuffDef.is_debuff] 分；系统 buff 不清），
## 填了就忽略 [member buff_id]
class_name RemoveStatus
extends CombatEffect

@export var target: Target = Target.SELF
@export var buff_id: StringName = &""
## 移除几层；0 = 全部
@export var stacks: int = 1
## 132：清光全部减益
@export var all_debuffs: bool = false
## 132：清光全部增益
@export var all_buffs: bool = false


func apply(ctx: RuleContext) -> void:
	if all_debuffs or all_buffs:
		for who in resolve_targets(ctx, target):
			var ids: Array[StringName] = []
			for b in who.buffs:
				var inst := b as BuffInstance
				if inst.def.system:
					continue     # 103：系统效果不可解除
				if (inst.def.is_debuff and all_debuffs) or (not inst.def.is_debuff and all_buffs):
					ids.append(inst.def.id)
			for id in ids:
				_remove(ctx, who, id, 0)
		return
	if buff_id == &"":
		return
	for who in resolve_targets(ctx, target):
		_remove(ctx, who, buff_id, stacks)


static func _remove(ctx: RuleContext, who: CombatantRuntime, id: StringName, n_stacks: int) -> void:
	var have := who.stacks_of(id)
	if have <= 0:
		return
	take(ctx, who, id, have if n_stacks <= 0 else mini(n_stacks, have), "removed")


## 从 [param who] 身上扣 [param n] 层 [param id]，返回实际扣掉的层数；扣掉了才发 status_unstacked（与 [method ApplyStatus.give] 对称）。
## [ConvertStatus] 与 [StatusStackCost] 也走这里。[param reason] 为空就不写这个键 —— 消耗那条原本就不带，回放载荷逐字节不变
static func take(ctx: RuleContext, who: CombatantRuntime, id: StringName, n: int, reason: String = "") -> int:
	var removed := who.remove_buff_stacks(id, n)
	if removed <= 0:
		return 0
	var payload := {"buff": String(id), "delta": -removed, "stacks": who.stacks_of(id)}
	if reason != "":
		payload["reason"] = reason
	ctx.battle.emit(BattleEvent.STATUS_UNSTACKED, who.side, payload)
	return removed


## 142：写目标与状态名（不写 id）：「清掉对手全部流血」「移除你 2 层中毒」「清除对手全部增益」
func describe() -> String:
	var who := {Target.OPPONENT: "对手", Target.SELF: "你", Target.BOTH: "双方"}[target] as String
	if all_debuffs or all_buffs:
		return "清除%s全部%s" % [who, "增益与减益" if all_debuffs and all_buffs else ("减益" if all_debuffs else "增益")]
	if stacks <= 0:
		return "清掉%s全部%s" % [who, Glossary.status_name(buff_id)]
	return "移除%s %d 层%s" % [who, stacks, Glossary.status_name(buff_id)]


## 151：估值 —— 拿掉那几层在那一边身上「还剩的价值」：从自己身上拿掉减益为正、拿掉增益为负；对手身上的反过来。
## 全部 = 估算上下文假定的层数；清光全部减益 / 增益按假定层数 × 查不到的 buff 每层值多少
func estimated_value(ctx: PowerContext) -> float:
	var n := float(stacks) if stacks > 0 else ctx.stacks_or_assumed()
	var v := 0.0
	for on_owner in [true, false]:
		if (on_owner and target == Target.OPPONENT) or (not on_owner and target == Target.SELF):
			continue
		var carrier := ctx.for_carrier(on_owner)
		var each := 0.0
		if all_debuffs or all_buffs:
			var unknown := ctx.weights.unknown_buff_value * ctx.weights.expected_duration(0.0, true)
			each = (-unknown if all_debuffs else 0.0) + (unknown if all_buffs else 0.0)
			n = ctx.stacks_or_assumed()
		else:
			var b := ctx.buff(buff_id)
			if b == null:
				return NAN
			each = b.stack_value(carrier)
		# each 是那几层对挂着它的那一边值多少：从自己身上拿掉 = 自己少了这些，从对手身上拿掉 = 对手少了这些
		v += -n * each if on_owner else n * each
	return v

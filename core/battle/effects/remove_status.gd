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
	var n := have if n_stacks <= 0 else mini(n_stacks, have)
	var removed := who.remove_buff_stacks(id, n)
	if removed > 0:
		ctx.battle.emit(BattleEvent.STATUS_UNSTACKED, who.side, {
			"buff": String(id), "delta": -removed,
			"stacks": who.stacks_of(id), "reason": "removed",
		})


func describe() -> String:
	if all_debuffs or all_buffs:
		return "清除全部%s" % ("增益与减益" if all_debuffs and all_buffs else ("减益" if all_debuffs else "增益"))
	return "移除 %s %s 层" % [buff_id, "全部" if stacks <= 0 else str(stacks)]

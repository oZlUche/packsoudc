## 175 补充五：道具的「造成伤害后施加」简写（[member ItemDef.applies]）的一项 —— `{"buff": "scorch", "stacks": 1}`。
##
## 【造成伤害】和【施加元素】是两件事（作者定），但多数时候结伴：火焰法杖一下既打火伤又叠一层灼伤。
## 简写让「结伴」仍是一行数据，编译时拼成一条普通规则，经 108 的附加入口挂上（来源 [constant ORIGIN]）：
## [codeblock]
## on_damage {direction: DEALT, own_only: true, landed_only: true} → apply_status OPPONENT buff × stacks
## [endcodeblock]
## 只在**这件道具造成伤害之后**施加，被取消的那一下不施加（[member DamageTrigger.landed_only]）。
## 要别的时机（出手就施加、受伤时、开战时）写普通规则，不用简写。[member stacks] 就是「一次叠多层」的口子
class_name ElementApply
extends Resource

## 编译挂上时记的来源（悬浮窗按它单写一行，不写「附加 ← …」）
const ORIGIN := &"applies"

## 施加哪个状态（通常是元素印：灼伤 / 寒冷 / 麻痹 / 中毒 / 流血）
@export var buff: BuffDef
## 一次叠几层
@export var stacks: int = 1


## 一件道具的简写拼成的那条规则（每项一个 [ApplyStatus]，同一个扳机）；没有可施加的返回 null
static func rule_of(list: Array) -> AbilityRule:
	var effects: Array[CombatEffect] = []
	for a in list:
		var ea := a as ElementApply
		if ea == null or ea.buff == null:
			continue
		var eff := ApplyStatus.new()
		eff.target = CombatEffect.Target.OPPONENT
		eff.buff = ea.buff
		eff.stacks = maxi(1, ea.stacks)
		effects.append(eff)
	if effects.is_empty():
		return null
	var trig := OnDamage.new()
	trig.direction = DamageTrigger.Direction.DEALT
	trig.own_only = true
	trig.landed_only = true
	var r := AbilityRule.new()
	r.trigger = trig
	r.cadence = Always.new()
	for e in effects:
		r.effects.append(e)
	return r

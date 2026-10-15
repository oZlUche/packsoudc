## 战斗那一层的构件注册表：类型名 → 脚本路径（架构文档第 10 节）。
##
## 内容管线的关键约束：**导入器不认识任何具体效果**，只按本表解析类型名。
## 新增一种时机／频率／消耗／效果 = 加一个脚本 + 在这里登记一行，
## 导入器、[BattleSim]、编辑器三方都不需要改。
##
## 101 第 5 刀：这里**只有战斗那一层** —— 战利品的在 [LootRegistry]，一局的（规则、模块、事件、信仰、猎手、侵蚀）
## 在 [RunRegistry]。拆开是为了依赖方向：战斗层不认识一局的构件。内容管线要三张合起来，见 [ContentRegistries]
class_name EffectRegistry
extends RefCounted

const TRIGGERS := {
	&"on_schedule": "res://core/battle/triggers/on_schedule.gd",
	&"on_battle_start": "res://core/battle/triggers/on_battle_start.gd",
	&"on_item_fired": "res://core/battle/triggers/on_item_fired.gd",
	# 状态条件型：条件在相关事件发生的那一刻求值
	&"on_stacks_at_least": "res://core/battle/triggers/on_stacks_at_least.gd",
	&"on_axis_at_least": "res://core/battle/triggers/on_axis_at_least.gd",
	&"on_resource_below": "res://core/battle/triggers/on_resource_below.gd",
	&"on_damage": "res://core/battle/triggers/on_damage.gd",
	&"on_before_damage": "res://core/battle/triggers/on_before_damage.gd",
	# 130：某状态被施加时（层数增加那一瞬）
	&"on_status_applied": "res://core/battle/triggers/on_status_applied.gd",
	# 132：某状态掉光时；加时开始时
	&"on_status_removed": "res://core/battle/triggers/on_status_removed.gd",
	&"on_overtime": "res://core/battle/triggers/on_overtime.gd",
}

const CADENCES := {
	&"always": "res://core/battle/cadences/always.gd",
	&"cooldown": "res://core/battle/cadences/cooldown_cadence.gd",
	# 175：法杖轮读（单次冷却 + 总冷却）
	&"cycle": "res://core/battle/cadences/cycle_cadence.gd",
}

## 消耗与条件同层：两者失败行为一致，都是跳过效果但不退还冷却。
## costs 本身就是列表且 AND 语义，因此不需要 AllOf 之类的组合子。
const COSTS := {
	&"resource": "res://core/battle/costs/resource_cost.gd",
	&"status_stack": "res://core/battle/costs/status_stack_cost.gd",
	&"charge": "res://core/battle/costs/charge_cost.gd",
	&"uses": "res://core/battle/costs/uses_cost.gd",
	&"chance": "res://core/battle/costs/chance_condition.gd",
	# 130：目标身上有这么多层才放行，不扣层
	&"status_condition": "res://core/battle/costs/status_condition.gd",
	# 132：资源 / 标准轴条件（不扣），扣自己的轴层数
	&"resource_condition": "res://core/battle/costs/resource_condition.gd",
	&"axis_condition": "res://core/battle/costs/axis_condition.gd",
	&"axis_cost": "res://core/battle/costs/axis_cost.gd",
}

## 战斗作用域的效果。依赖扳机。
const COMBAT_EFFECTS := {
	&"deal_damage": "res://core/battle/effects/deal_damage.gd",
	&"change_resource": "res://core/battle/effects/change_resource.gd",
	&"apply_status": "res://core/battle/effects/apply_status.gd",
	&"remove_status": "res://core/battle/effects/remove_status.gd",
	# 130：把目标身上一种状态的层数换成另一种
	&"convert_status": "res://core/battle/effects/convert_status.gd",
	# 标准轴（4.3，103）：单位级带符号层数
	&"shift_axis": "res://core/battle/effects/shift_axis.gd",
	# 只在受伤前阶段有效，见 DamageResolver
	&"modify_damage": "res://core/battle/effects/modify_damage.gd",
	&"low_hp_empower": "res://core/battle/effects/low_hp_empower.gd",
	&"fire_enchant": "res://core/battle/effects/fire_enchant.gd",
	&"reflect_damage": "res://core/battle/effects/reflect_damage.gd",
	# 132：只在受伤前阶段有效，把这一包换成另一种类型
	&"convert_damage_type": "res://core/battle/effects/convert_damage_type.gd",
	# 175：法杖按轮读取这一下的晶石，打出它的元素
	&"fire_loaded": "res://core/battle/effects/fire_loaded.gd",
	# 175 补充四：给目标身上的状态加保底层数（凝毒 / 冻疮）
	&"guard_status": "res://core/battle/effects/guard_status.gd",
}

const TABLES := {
	&"trigger": TRIGGERS,
	&"cadence": CADENCES,
	&"cost": COSTS,
	&"effect": COMBAT_EFFECTS,
}


static func instantiate(kind: StringName, type_name: StringName) -> Resource:
	return RegistryLookup.instantiate(TABLES, kind, type_name)


static func has_type(kind: StringName, type_name: StringName) -> bool:
	return RegistryLookup.has_type(TABLES, kind, type_name)


static func type_names(kind: StringName) -> Array:
	return RegistryLookup.type_names(TABLES, kind)

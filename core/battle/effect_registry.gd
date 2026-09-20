## 类型名 → 脚本路径（架构文档第 10 节）。
##
## 内容管线的关键约束：**导入器不认识任何具体效果**，只按本表解析类型名。
## 新增一种时机／频率／消耗／效果 = 加一个脚本 + 在这里登记一行，
## 导入器、[BattleSim]、编辑器三方都不需要改。
class_name EffectRegistry
extends RefCounted

const TRIGGERS := {
	&"on_schedule": "res://core/battle/triggers/on_schedule.gd",
	&"on_battle_start": "res://core/battle/triggers/on_battle_start.gd",
	&"on_item_fired": "res://core/battle/triggers/on_item_fired.gd",
	&"on_resource_changed": "res://core/battle/triggers/on_resource_changed.gd",
	# 状态条件型：条件在相关事件发生的那一刻求值
	&"on_stacks_at_least": "res://core/battle/triggers/on_stacks_at_least.gd",
	&"on_resource_below": "res://core/battle/triggers/on_resource_below.gd",
	&"on_damage": "res://core/battle/triggers/on_damage.gd",
	&"on_before_damage": "res://core/battle/triggers/on_before_damage.gd",
}

const CADENCES := {
	&"always": "res://core/battle/cadences/always.gd",
	&"cooldown": "res://core/battle/cadences/cooldown_cadence.gd",
}

## 消耗与条件同层：两者失败行为一致，都是跳过效果但不退还冷却。
## costs 本身就是列表且 AND 语义，因此不需要 AllOf 之类的组合子。
const COSTS := {
	&"resource": "res://core/battle/costs/resource_cost.gd",
	&"status_stack": "res://core/battle/costs/status_stack_cost.gd",
	&"charge": "res://core/battle/costs/charge_cost.gd",
	&"uses": "res://core/battle/costs/uses_cost.gd",
	&"chance": "res://core/battle/costs/chance_condition.gd",
}

## 战斗作用域的效果。依赖扳机。
const COMBAT_EFFECTS := {
	&"deal_damage": "res://core/battle/effects/deal_damage.gd",
	&"change_resource": "res://core/battle/effects/change_resource.gd",
	&"apply_status": "res://core/battle/effects/apply_status.gd",
	&"remove_status": "res://core/battle/effects/remove_status.gd",
	# 只在受伤前阶段有效，见 DamageResolver
	&"modify_damage": "res://core/battle/effects/modify_damage.gd",
	&"reflect_damage": "res://core/battle/effects/reflect_damage.gd",
}

## 战利品作用域的效果。**不依赖扳机，激活即生效。**
const LOOT_EFFECTS := {
	&"extra_rolls": "res://core/loot/effects/extra_rolls.gd",
	&"rarity_bias": "res://core/loot/effects/rarity_bias.gd",
	&"category_bias": "res://core/loot/effects/category_bias.gd",
	&"drop_owned_chance": "res://core/loot/effects/drop_owned_chance.gd",
}

## 地图作用域：占位，M3 再填
const MAP_EFFECTS := {}

const TABLES := {
	&"trigger": TRIGGERS,
	&"cadence": CADENCES,
	&"cost": COSTS,
	&"effect": COMBAT_EFFECTS,
	&"loot_effect": LOOT_EFFECTS,
	&"map_effect": MAP_EFFECTS,
}


## 按种类与类型名构造一个实例。未登记的类型名返回 null 并告警 ——
## 导入器据此拒绝生成资产，不产出半成品。
static func instantiate(kind: StringName, type_name: StringName) -> Resource:
	var table: Dictionary = TABLES.get(kind, {})
	var path: String = table.get(type_name, "")
	if path.is_empty():
		push_warning("EffectRegistry: 未登记的 %s 类型 '%s'" % [kind, type_name])
		return null
	var script: GDScript = load(path)
	if script == null:
		push_error("EffectRegistry: 脚本加载失败 %s" % path)
		return null
	return script.new()


static func has_type(kind: StringName, type_name: StringName) -> bool:
	return (TABLES.get(kind, {}) as Dictionary).has(type_name)


static func type_names(kind: StringName) -> Array:
	var k := (TABLES.get(kind, {}) as Dictionary).keys()
	k.sort()
	return k

## 类型名 → 脚本路径（架构文档第 9 节）。
##
## 内容管线的关键约束：**导入器不认识任何具体效果**，只按本表解析类型名。
## 新增一种时机／频率／消耗／效果 = 加一个脚本 + 在这里登记一行，
## 导入器、[BattleSim]、编辑器三方都不需要改。
class_name EffectRegistry
extends RefCounted

const TRIGGERS := {
	&"on_tick": "res://core/battle/triggers/on_tick.gd",
	&"on_battle_start": "res://core/battle/triggers/on_battle_start.gd",
	&"on_item_fired": "res://core/battle/triggers/on_item_fired.gd",
	&"on_resource_changed": "res://core/battle/triggers/on_resource_changed.gd",
}

const CADENCES := {
	&"always": "res://core/battle/cadences/always.gd",
	&"cooldown": "res://core/battle/cadences/cooldown_cadence.gd",
	&"every_nth": "res://core/battle/cadences/every_nth.gd",
	&"once_per_battle": "res://core/battle/cadences/once_per_battle.gd",
	&"chance": "res://core/battle/cadences/chance_cadence.gd",
	&"all_of": "res://core/battle/cadences/all_of.gd",
}

const COSTS := {
	&"resource": "res://core/battle/costs/resource_cost.gd",
	&"status_stack": "res://core/battle/costs/status_stack_cost.gd",
}

const EFFECTS := {
	&"deal_damage": "res://core/battle/effects/deal_damage.gd",
	&"restore_resource": "res://core/battle/effects/restore_resource.gd",
	&"apply_status": "res://core/battle/effects/apply_status.gd",
}

const TABLES := {
	&"trigger": TRIGGERS,
	&"cadence": CADENCES,
	&"cost": COSTS,
	&"effect": EFFECTS,
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

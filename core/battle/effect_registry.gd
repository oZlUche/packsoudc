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
	&"low_hp_empower": "res://core/battle/effects/low_hp_empower.gd",
	&"fire_enchant": "res://core/battle/effects/fire_enchant.gd",
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

## 一局的规则（059 的 buff 骨架）：体力上限、开局钱、多搜几次、商店价、幸运。**不依赖扳机，激活即生效。**
const RUN_EFFECTS := {
	&"vitality_max_bonus": "res://core/run/effects/vitality_max_bonus.gd",
	&"starting_funds_bonus": "res://core/run/effects/starting_funds_bonus.gd",
	&"extra_searches": "res://core/run/effects/extra_searches.gd",
	&"shop_price_mult": "res://core/run/effects/shop_price_mult.gd",
	&"luck_bonus": "res://core/run/effects/luck_bonus.gd",
	&"scout_range": "res://core/run/effects/scout_range.gd",
	&"stealth": "res://core/run/effects/stealth.gd",
	&"flee_bonus": "res://core/run/effects/flee_bonus.gd",
	&"free_losses": "res://core/run/effects/free_losses.gd",
	&"stat_bonus": "res://core/run/effects/stat_bonus.gd",
}

## 局内技能（082）：被动常驻 + 可选的主动一击
const RUN_SKILLS := {
	&"passive": "res://core/run/skills/passive_skill.gd",
	&"assault": "res://core/run/skills/assault_skill.gd",
	&"evade": "res://core/run/skills/evade_skill.gd",
}

## 信力（082）：信仰指定的行为
const FAITH_DEEDS := {
	&"place_item": "res://core/run/faith/deeds/place_item_deed.gd",
	&"battle": "res://core/run/faith/deeds/battle_deed.gd",
	&"travel": "res://core/run/faith/deeds/travel_deed.gd",
	&"earn_money": "res://core/run/faith/deeds/earn_money_deed.gd",
	&"spend_money": "res://core/run/faith/deeds/spend_money_deed.gd",
	&"explore": "res://core/run/faith/deeds/explore_deed.gd",
	&"event_choice": "res://core/run/faith/deeds/event_choice_deed.gd",
	# 093（作者表）：按量累计的行为
	&"damage": "res://core/run/faith/deeds/damage_deed.gd",
	&"vitality_lost": "res://core/run/faith/deeds/vitality_lost_deed.gd",
	&"item_cycle": "res://core/run/faith/deeds/item_cycle_deed.gd",
	&"heal": "res://core/run/faith/deeds/heal_deed.gd",
	&"item_triggered": "res://core/run/faith/deeds/item_triggered_deed.gd",
	&"enter_node": "res://core/run/faith/deeds/enter_node_deed.gd",
}

## 093：信仰级的效果（写在信仰上、按阶生效）
const FAITH_PERKS := {
	&"stat_mod": "res://core/run/faith/perks/stat_mod_perk.gd",
	&"low_hp_empower": "res://core/run/faith/perks/low_hp_empower_perk.gd",
	&"enchant_weapons": "res://core/run/faith/perks/enchant_weapons_perk.gd",
	&"food_shield": "res://core/run/faith/perks/food_shield_perk.gd",
	&"food_double": "res://core/run/faith/perks/food_double_perk.gd",
	&"altar_sacrifice_hp": "res://core/run/faith/perks/altar_sacrifice_hp_perk.gd",
	&"altar_pray_fire": "res://core/run/faith/perks/altar_pray_fire_perk.gd",
	&"altar_food_vitality": "res://core/run/faith/perks/altar_food_vitality_perk.gd",
	&"altar_train_board": "res://core/run/faith/perks/altar_train_board_perk.gd",
	&"altar_reshape_node": "res://core/run/faith/perks/altar_reshape_node_perk.gd",
	&"smite": "res://core/run/faith/perks/smite_perk.gd",
	&"extra_drop_by_node": "res://core/run/faith/perks/extra_drop_by_node_perk.gd",
	&"gift_on_enter": "res://core/run/faith/perks/gift_on_enter_perk.gd",
	&"draw_is_win": "res://core/run/faith/perks/draw_is_win_perk.gd",
	&"undying": "res://core/run/faith/perks/undying_perk.gd",
	&"altar_bless": "res://core/run/faith/perks/altar_bless_perk.gd",
}

## 事件层（063）：选项的条件（只读）与后果（做一件事或立一面旗）
const EVENT_CONDITIONS := {
	&"has_buff_tag": "res://core/run/events/conditions/has_buff_tag.gd",
	&"has_map_buff": "res://core/run/events/conditions/has_map_buff.gd",
	&"can_afford": "res://core/run/events/conditions/can_afford.gd",
	&"vitality_at_least": "res://core/run/events/conditions/vitality_at_least.gd",
	&"steps_within": "res://core/run/events/conditions/steps_within.gd",
	&"bracket_within": "res://core/run/events/conditions/bracket_within.gd",
	&"erosion_depth_within": "res://core/run/events/conditions/erosion_depth_within.gd",
	&"has_item": "res://core/run/events/conditions/has_item.gd",
	&"node_type_is": "res://core/run/events/conditions/node_type_is.gd",
	&"has_flag": "res://core/run/events/conditions/has_flag.gd",
	&"faith_active": "res://core/run/events/conditions/faith_active.gd",
}

const EVENT_OUTCOMES := {
	&"give_item": "res://core/run/events/outcomes/give_item.gd",
	&"give_random_item": "res://core/run/events/outcomes/give_random_item.gd",
	&"restore_vitality": "res://core/run/events/outcomes/restore_vitality.gd",
	&"spend_vitality": "res://core/run/events/outcomes/spend_vitality.gd",
	&"change_money": "res://core/run/events/outcomes/change_money.gd",
	&"grant_map_buff": "res://core/run/events/outcomes/grant_map_buff.gd",
	&"remove_map_buff": "res://core/run/events/outcomes/remove_map_buff.gd",
	&"start_battle": "res://core/run/events/outcomes/start_battle.gd",
	&"open_search": "res://core/run/events/outcomes/open_search.gd",
	&"open_shop": "res://core/run/events/outcomes/open_shop.gd",
	&"next_event": "res://core/run/events/outcomes/next_event.gd",
	&"say": "res://core/run/events/outcomes/say.gd",
	&"hunter_fight": "res://core/run/events/outcomes/hunter_fight.gd",
	&"hunter_flee": "res://core/run/events/outcomes/hunter_flee.gd",
	&"teleport": "res://core/run/events/outcomes/teleport.gd",
	&"change_node_type": "res://core/run/events/outcomes/change_node_type.gd",
	&"proceed": "res://core/run/events/outcomes/proceed.gd",
	&"extract": "res://core/run/events/outcomes/extract.gd",
	&"pass_time": "res://core/run/events/outcomes/pass_time.gd",
	&"lose_item": "res://core/run/events/outcomes/lose_item.gd",
	&"set_flag": "res://core/run/events/outcomes/set_flag.gd",
	&"open_altar": "res://core/run/events/outcomes/open_altar.gd",
	&"next_event_random": "res://core/run/events/outcomes/next_event_random.gd",
	&"bless_item": "res://core/run/events/outcomes/bless_item.gd",
}

## 一局的机制（069）：难度清单里开的那些
## 101 第 0 刀：一局的模块 —— 本体功能与难度机制同一张表（[RunModule]；[RunMechanic] 是它的子类）
const RUN_MODULES := {
	&"erosion": "res://core/run/mechanics/erosion_mechanic.gd",
	&"hunters": "res://core/run/mechanics/hunter_mechanic.gd",
	&"safe": "res://core/run/modules/safe_module.gd",
	&"node_storage": "res://core/run/modules/node_storage_module.gd",
	&"countdown": "res://core/run/modules/countdown_module.gd",
	&"crafting": "res://core/run/modules/crafting_module.gd",
	&"altar": "res://core/run/modules/altar_module.gd",
	&"buff": "res://core/run/modules/buff_module.gd",
}

## 猎手（069 / 071）：行动逻辑与战败后果
const HUNTER_BEHAVIORS := {
	&"approach": "res://core/run/hunters/behaviors/approach_behavior.gd",
	&"flee": "res://core/run/hunters/behaviors/flee_behavior.gd",
	&"wander": "res://core/run/hunters/behaviors/wander_behavior.gd",
	&"ambush": "res://core/run/hunters/behaviors/ambush_behavior.gd",
	&"patrol": "res://core/run/hunters/behaviors/patrol_behavior.gd",
}

const HUNTER_LOSSES := {
	&"spend_vitality": "res://core/run/hunters/losses/loss_spend_vitality.gd",
	&"nothing": "res://core/run/hunters/losses/loss_nothing.gd",
	&"kill": "res://core/run/hunters/losses/loss_kill.gd",
	&"vanish": "res://core/run/hunters/losses/loss_vanish.gd",
	&"retreat": "res://core/run/hunters/losses/loss_retreat.gd",
	&"expel_and_guard": "res://core/run/hunters/losses/loss_expel_and_guard.gd",
}

## 侵蚀（5.7 / 075）：被侵蚀的点结算时过门的效果
const EROSION_EFFECTS := {
	&"spend_vitality": "res://core/run/erosion/effects/erode_spend_vitality.gd",
	&"damage_item": "res://core/run/erosion/effects/erode_damage_item.gd",
	&"drain_money": "res://core/run/erosion/effects/erode_drain_money.gd",
}

const TABLES := {
	&"trigger": TRIGGERS,
	&"cadence": CADENCES,
	&"cost": COSTS,
	&"effect": COMBAT_EFFECTS,
	&"loot_effect": LOOT_EFFECTS,
	&"map_effect": MAP_EFFECTS,
	&"run_effect": RUN_EFFECTS,
	&"event_condition": EVENT_CONDITIONS,
	&"event_outcome": EVENT_OUTCOMES,
	&"run_module": RUN_MODULES,
	&"run_mechanic": RUN_MODULES,     # 101：旧键名的别名（DifficultyDef.mechanics 还叫机制）
	&"hunter_behavior": HUNTER_BEHAVIORS,
	&"hunter_loss": HUNTER_LOSSES,
	&"erosion_effect": EROSION_EFFECTS,
	&"run_skill": RUN_SKILLS,
	&"faith_deed": FAITH_DEEDS,
	&"faith_perk": FAITH_PERKS,
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

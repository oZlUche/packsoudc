## 编辑器里字段 / 类型 / 枚举值的**显示文字**（091，作者定：中文模式下界面写中文，字段名与变量名一律不改；每个属性有悬浮说明）。
##
## 三层，都只管「怎么显示」：
## 1. **标签** [method label]：字段名 → 短中文（`rarity` → 稀有度）。查 `类名.字段` 再查 `字段`，没有就原样显示字段名。英文模式直接显示字段名。
## 2. **说明** [method help]：从脚本源码里**读 `@export` 上面的 `##` 注释**（代码里本来就写着每个字段是什么），不另抄一份 —— 注释改了说明跟着改。
##    读不到源码（导出包剥了源码）就退回标签。结果按脚本缓存。
## 3. **类型 / 枚举 / 类名** [method type_label] / [method enum_label] / [method class_label]：注册表名（`say` → 说一句）、枚举值（`SELF` → 自己）、类名（`AbilityRule` → 规则）。
##
## [PropertyForm] 用它画每一行；别的编辑器要写字段名也走这里
class_name FieldText
extends RefCounted

## 字段名 → 中文。`类名.字段` 优先（同名字段在别的类里意思不同时用）
const LABELS := {
	"id": "id", "display_name": "名字", "display_names": "别的语言的名字", "description": "说明", "descriptions": "别的语言的说明",
	"title": "标题", "titles": "别的语言的标题", "text": "正文", "texts": "别的语言的正文", "label": "选项文字", "labels": "别的语言的选项文字",
	"image": "配图", "tags": "标签", "tag": "标签", "order": "先后", "hidden": "隐藏", "note": "备注", "tip": "弹词条", "internal": "内部标签",
	"amount": "数量", "value": "数值", "count": "件数", "percent": "百分比", "flat": "固定值", "mult": "倍率", "StatModifier.mode": "乘算 / 加算",
	"chance": "概率", "seconds": "秒", "steps": "步数", "min_steps": "最少步数", "max_steps": "最多步数", "min_value": "最少", "flag": "旗标",
	"absent": "反过来（要求没有）", "add": "累加", "clear": "拔掉", "target": "对象", "where": "在哪", "pick": "挑法", "item": "道具", "items": "道具",
	"include_bags": "包也算", "include_self": "含自己", "invert": "反转", "enabled": "启用", "absolute": "绝对值", "only_total": "只算总量",
	# 道具
	"shape": "形状", "rarity": "稀有度", "rarity_cap": "稀有度上限", "is_bag": "是包", "bag_accept_tags": "包只收的标签", "bag_mods": "包体加成",
	"set_id": "套装", "effects": "效果", "faith_bonuses": "信仰加成", "dormant_keeps_combat": "休眠仍保留战斗效果", "requires_unlock": "需要的解锁",
	"combat": "战斗", "adjacency": "邻接", "base_stats": "基础属性", "rules": "规则", "trigger": "触发", "cadence": "节奏", "costs": "消耗",
	"use_haste": "受急速影响", "cooldown": "冷却", "resource_key": "资源", "damage_type": "伤害类型", "damage_stat": "伤害用的属性", "amount_stat": "数量改从属性取（留空 = 用上面的数量）",
	"stat": "属性", "stat_scale": "属性系数", "direct_override": "直接伤害（−1 按来源定）", "shield_absorbable": "可被护盾吸收", "provokes": "招致反应", "on_self": "对自己", "same_side": "同一边",
	"buff": "增益", "buff_id": "增益 id", "stacks": "叠层", "stackable": "可叠层（不限层）", "max_shares": "最多几份（0 = 不限）", "per_stack": "按叠层", "duration_sec": "持续秒数",
	"by_self": "只认本方施加", "from": "转化前", "to": "转化成", "ratio": "换算比例", "keep_from": "保留原状态",     # 130
	"source_tags": "只听带这些标签的", "full": "回满", "crit_only": "只在暴击时", "receive_rules": "受益规则", "min_percent": "至少百分之", "max_percent": "至多百分之",
	"absolute_min": "至少点数", "absolute_max": "至多点数", "negate": "取反", "percent_of": "按生命比例", "percent_of_target": "比例按谁的生命",
	"per_target_stack": "乘目标身上的层数", "percent_of_damage": "按这一下伤害的百分比", "all_debuffs": "清光全部减益", "all_buffs": "清光全部增益",     # 132
	"is_debuff": "是减益", "refresh_on_restack": "再叠刷新时长", "on_apply": "施加时", "on_expire": "到期时", "mods": "属性加成", "consume": "消耗掉",
	"grant_cells": "增益格", "receive_cells": "受益格", "grant_mods": "给邻居的加成", "grant_rules": "给邻居挂的规则", "receive_mods": "邻居给的加成", "grant_filter": "只给", "receive_filter": "只收",
	"uses": "次数", "max_uses": "最多次数", "hp_fraction": "生命比例", "direction": "方向", "source": "来源", "weapon_tag": "武器标签", "min_amount": "最少量",
	"speed": "速度", "cells": "格", "pieces": "件", "tiers": "档位", "count_mode": "计数方式", "common_tags": "通用标签",
	# 事件
	"options": "选项", "requires": "条件", "outcomes": "后果", "hide_when_locked": "条件不满足时隐藏", "event": "事件", "node_type": "点的类型", "node_types": "点的类型",
	"min_bracket": "最低段位", "max_bracket": "最高段位", "min_depth": "最浅", "max_depth": "最深", "action_cost": "行动点", "actions": "行动点",
	# 章节 / 地图
	"map_source": "地图来源", "mode": "方式", "preset_path": "预设文件", "generator_id": "生成器", "generator_config": "生成参数",
	"enemy_pool": "敌人池", "difficulty": "难度", "drop_rule": "掉落规则", "carry_rule": "携带规则", "encumbrance_rules": "负重规则", "weight": "重量", "weight_capacity": "负重上限", "node_rules": "节点规则", "economy_rules": "经济规则",
	"step_limit": "全局倒计时（行动点）", "blessings": "赐福模板", "blessed_of": "从哪件派生", "per_points": "每多少信力一份",
	"name_prefix": "名字前缀", "name_prefix_en": "英文前缀", "add_tags": "多出的标签", "rarity_up": "稀有度加几", "value_mult": "价值倍率", "convert_chance": "包内转化概率", "convert_per_tier": "每级加的转化概率",
	"bless_chance": "赐福替代概率（没激活）", "bless_chance_active": "赐福替代概率（激活了）", "cost": "花费", "carry_budget": "带入预算（价值）", "carry_over_cost": "每超多少价值倒计时 −1", "event_groups": "成组限量的事件", "events": "事件与权重", "offerings": "献祭品", "perks": "信仰效果", "multiplier": "倍率", "cap": "每场上限",
	"count_dealt": "算造成的", "count_taken": "算受到的", "min_cells": "最少格子数", "exact_grade": "体积恰好", "per_cell": "乘格子数", "first_amount": "首次给", "again_amount": "再次给", "has_stat": "显式带有的属性", "rarity_pow": "按 2^稀有度给", "plus": "再加", "first_kind_only": "同种一局只算一次", "by_type": "按节点类型", "closing_extract": "过半关一个撤离点", "safes": "保险箱个数", "safe_size": "保险箱大小",
	"grants_unlock": "通关给的解锁", "hidden_by_unlock": "拿到此解锁后收起", "characters": "可选角色", "vitality_bonus": "额外体力", "starting_items": "开局道具",
	"starting_keepsakes": "开局特殊道具", "next_chapter": "下一章", "allow_carry_in": "允许从仓库带入", "auto_spawn": "直接站在出生点", "skip_setup": "不走开局屏",
	"intro_event": "开场事件", "node_tooltips": "节点浮窗", "tooltip_mode": "浮窗模板", "tooltip_texts": "浮窗文字", "rings": "环", "kind": "种类",
	"slots": "槽位数", "node_count": "点数", "quota": "配额", "type_weights": "类型权重", "ring_template": "环模板", "scales": "规模", "routes": "路线",
	"mix": "配比", "min_share": "最低占比", "risk_band": "风险区间", "reward_band": "回报区间", "ends_at": "终点类型", "spawns_zones": "岔出高危区", "type_risk": "类型风险", "type_reward": "类型回报",
	"mandatory_types": "必有的类型", "danger_risk_multiplier": "危险等级风险倍率", "danger_reward_multiplier": "危险等级回报倍率", "ev_tolerance": "期望容差",
	"coverage": "覆盖", "no_adjacent": "不许相邻", "zone_spec": "高危区", "zone_rules": "高危区规则", "entries": "出生点数", "zones": "高危区数", "zone_size": "高危区大小",
	"pivots": "枢纽数", "nodes_by_rings": "按环数的点数", "extract_gap": "撤离点间距", "extract_bands": "撤离点环带", "haven_at": "安全点位置", "placeholder": "占位",
	"width": "宽", "floors": "层数", "base_width": "底宽", "shrink_per_row": "每层收窄", "half_rows": "半边行数", "neck_rows": "颈部行数",
	# 规则表
	"random_weights": "随机点权重", "event_weights": "事件权重", "events_by_type": "各类点的事件表", "event_restore": "事件回体力", "event_item_rarity_cap": "事件道具稀有度上限",
	"loss_cost": "战败代价", "rest_restore": "休息回体力", "search": "搜索", "reveal_seconds": "揭示秒数", "items_per_search": "每次搜几件", "max_searches": "最多搜几次",
	"boss_extracts": "打完核心直接撤离", "boss_rarity": "核心保底稀有度", "base_chance": "基础概率", "treasure_chance": "珍宝概率", "min_drops": "至少掉几件",
	"bags_always_drop": "包必掉", "rarity_weights": "稀有度权重", "shop_slots": "商店栏位", "shop_sell_ratio": "出售折价", "shop_price_mult": "商店价格倍率",
	"shop_refresh_cost": "刷新价", "extract_fee": "撤离费", "starting_balance": "开局钱", "reward_base": "打赢基础进账", "warehouse_size": "仓库大小", "first_kit": "第一套",
	# 角色 / 敌人 / 猎手 / 信仰
	"board_size": "棋盘尺寸", "starting_bags": "初始包", "vitality_max": "体力上限", "carry_max_items": "最多带几件", "carry_rarity_cap": "带入稀有度上限", "skills": "技能",
	"bags": "包", "board": "棋盘", "signature": "招牌道具", "signature_by_strength": "按档位的招牌", "schools": "流派", "item_tags": "道具标签", "item_count": "道具件数",
	"strength": "档位", "strength_rule": "档位规则", "loadout": "装备", "behavior": "行动逻辑", "visibility": "可见性", "loss_options": "战败结果档", "loss_pick": "选档方式", "HunterLossOption.weight": "权重", "LossPickFixed.index": "第几档（从 0 数）", "loss_type": "战败类型",
	"god": "神", "camp": "阵营", "thresholds": "阈值", "deeds": "行为", "single_faith": "只认一位神", "grants": "给的解锁", "level": "档",
	"mechanics": "机制", "warn_lead_actions": "预警提前量", "first_at_action": "第一次在第几步", "interval_actions": "间隔步数",
	"from_depth": "从第几层起", "per_depth": "每层", "hunter_ids": "猎手", "bracket_steps": "段位表", "inputs": "输入", "output": "产物",
	"funds": "钱", "rows": "行数", "effect": "效果",     # 110：局外科技
}

## 注册表名 → 中文
const TYPE_LABELS := {
	"on_schedule": "按节奏出手（自发）", "on_battle_start": "开战时", "on_item_fired": "某件出手时",
	"on_stacks_at_least": "叠层达到时", "on_resource_below": "资源低于时", "on_damage": "受伤时", "on_before_damage": "受伤前",
	"on_status_applied": "某状态被施加时", "status_condition": "状态条件", "convert_status": "转化状态",     # 130
	"on_status_removed": "某状态掉光时", "on_overtime": "加时开始时", "resource_condition": "资源条件", "axis_condition": "标准轴条件", "axis_cost": "消耗轴层数",
	"convert_damage_type": "改伤害类型",     # 132
	"always": "每次都行", "cooldown": "冷却",
	"resource": "消耗资源", "status_stack": "消耗叠层", "charge": "充能", "uses": "限次", "chance": "概率",
	"deal_damage": "造成伤害", "change_resource": "改资源", "apply_status": "施加状态", "remove_status": "移除状态", "modify_damage": "改伤害", "reflect_damage": "反弹伤害",
	"extra_rolls": "额外掉落次数", "rarity_bias": "稀有度偏移", "category_bias": "类别偏移", "drop_owned_chance": "掉身上有的概率",
	"vitality_max_bonus": "体力上限加成", "starting_funds_bonus": "开局钱加成", "extra_searches": "额外搜索次数", "shop_price_mult": "商店价格倍率",
	"luck_bonus": "幸运加成", "scout_range": "侦察范围", "stealth": "潜行", "flee_bonus": "逃跑加成", "free_losses": "免扣体力次数", "stat_bonus": "属性加成", "carry_capacity_bonus": "负重上限加成",
	"passive": "被动", "assault": "突击", "evade": "躲避",
	# 136：角色的套装
	"slip": "脱身", "second_wind": "咬牙", "travel_discount": "熟门熟路（免费步）", "rest_bonus": "休息多回体力", "erosion_resist": "侵蚀少扣体力",
	"battle_reward_mult": "打赢的钱倍率", "every": "每几步", "factor": "倍数",
	"skill_ready": "技能能用", "skill": "技能",
	"place_item": "置入道具", "battle": "打仗", "travel": "走路", "earn_money": "进账", "spend_money": "花钱", "explore": "搜索", "event_choice": "事件里选特定选项",
	"has_buff_tag": "有带标记的增益", "has_map_buff": "有某地图增益", "can_afford": "钱够", "vitality_at_least": "体力至少", "steps_within": "步数在区间",
	"bracket_within": "段位在区间", "erosion_depth_within": "侵蚀深度在区间", "has_item": "身上有道具", "node_type_is": "点的类型是", "has_flag": "有局外旗标",
	"give_item": "给道具", "give_random_item": "给随机道具", "restore_vitality": "回体力", "spend_vitality": "扣体力", "change_money": "钱加减",
	"grant_map_buff": "给地图增益", "remove_map_buff": "去掉地图增益", "start_battle": "开战", "open_search": "开搜索", "open_shop": "开商店", "next_event": "接下一个事件",
	"say": "说一句", "hunter_fight": "迎战猎手", "hunter_flee": "逃离猎手", "teleport": "传送", "change_node_type": "改点的类型", "proceed": "照常发生", "extract": "撤离",
	"pass_time": "原地耗时", "lose_item": "失去道具", "set_flag": "立局外旗标",
	# 093 信仰流派
	"damage": "造成 / 受到伤害", "vitality_lost": "失去体力", "item_cycle": "道具成功循环", "heal": "战斗内回血", "item_triggered": "触发某类道具", "enter_node": "进入空白节点",
	"item_acquired": "获得道具", "distinct_items_fired": "不同名字的道具出手", "first_place": "每局首次置入一种道具",
	"faith_active": "激活了信仰", "rest_part_unused": "休息点这一份没用过", "open_altar": "打开神坛", "next_event_random": "随机接一个事件", "low_hp_empower": "低血增伤", "fire_enchant": "火焰附魔",
	"stat_mod": "属性修饰（信仰级）", "enchant_weapons": "武器火焰附魔", "food_shield": "按食物给护盾", "food_double": "食物效果翻倍",
	"altar_sacrifice_hp": "神坛：献祭生命上限", "altar_pray_fire": "神坛：祈祷火焰", "altar_food_vitality": "献祭食物回体力", "altar_train_board": "神坛：锻炼（棋盘 +1 行）",
	"altar_reshape_node": "神坛：改造此点", "smite": "秒杀（耗体力）", "extra_drop_by_node": "按点类型必掉额外一件", "gift_on_enter": "踩上点给对应道具", "overtime_regen": "加时阶段回春", "on_axis_at_least": "标准轴到 N 层时", "shift_axis": "改标准轴层数", "axis_boost": "开战带几层标准轴", "undying": "血归零后坚持几秒", "altar_bless": "神坛：祈求赐福", "bless_item": "赐福一件",
	"erosion": "侵蚀", "hunters": "猎手", "safe": "保险箱", "node_storage": "按点暂存", "countdown": "全局倒计时", "crafting": "合成", "altar": "神坛", "buff": "一局的 buff",     # 101：一局的模块（本体功能与难度机制同一张表）
	"approach": "逼近", "flee": "逃跑", "wander": "游荡", "ambush": "伏击", "patrol": "巡逻",
	"nothing": "没事", "kill": "击杀", "vanish": "消失", "retreat": "撤退", "expel_and_guard": "驱逐并守卫", "expel": "驱逐（退回上一步）", "random": "按权重随机", "fixed": "固定一档",
	"damage_item": "损坏道具", "drain_money": "掉钱",
	"warehouse_rows": "仓库加行",     # 110：局外科技的效果
	"tech_run_buff": "每级给一条局外 buff", "tech_safe_size": "保险箱扩格",     # 118
}

## 枚举值 → 中文
const ENUM_LABELS := {
	"SELF": "自己", "OPPONENT": "对手", "BOTH": "两边", "BOARD": "棋盘", "STORAGE": "地上", "RANDOM": "随机", "MOST_VALUABLE": "最值钱的",
	"LEAST_VALUABLE": "最不值钱的", "BY_ID": "指定 id", "NEAREST": "最近的", "FARTHEST": "最远的", "FIXED": "指定的", "HIDDEN": "隐藏", "VISIBLE": "可见",
	"NEAR": "靠近才可见", "ANY": "任意", "INCREASE": "增加", "DECREASE": "减少", "GODS": "诸神", "CHURCH": "新教", "META": "局外", "MAP": "地图",
	"PRESET": "预设", "UNVISITED": "没去过", "VISITED": "去过", "TOTAL": "总数", "DISTINCT": "不重复",
	"OWN": "自己的", "OTHER": "别人的", "ALLY": "同伴", "DEALT": "打出的", "TAKEN": "受到的", "BELOW": "降到以下", "ABOVE": "涨到以上",     # 132
	"ADD": "加算", "MULT": "乘算",     # 133
	"tier": "按阶", "active": "激活即", "scaled": "按信力",     # 111：信仰加成的生效方式（字符串枚举，值是小写原文）
}

## 类名 → 中文
const CLASS_LABELS := {
	"ItemDef": "道具", "BuffDef": "增益", "EventDef": "事件", "EventOption": "选项", "CombatProfile": "战斗", "AbilityRule": "规则", "AdjacencyProfile": "邻接",
	"StatModifier": "属性修饰", "ItemShape": "形状", "FaithBonus": "信仰加成", "RingSpec": "环", "RingMapConfig": "环形图参数", "MapSource": "地图来源",
	"ChapterDef": "章节", "CharacterDef": "角色", "EnemyDef": "敌人", "DifficultyDef": "难度", "HunterDef": "猎手", "HunterLossOption": "战败结果档", "FaithDef": "信仰", "RecipeDef": "配方",
	"AchievementDef": "成就", "TagDef": "标签", "DamageTypeDef": "伤害类型", "LoadoutDef": "开局装备", "NodeRules": "节点规则", "DropRule": "掉落规则", "EconomyRules": "经济规则", "MetaRules": "局外规则",
	"SearchRules": "搜索规则", "ItemSetDef": "套装", "SetTier": "套装档位", "RunBuffDef": "局外 / 地图增益", "EnemyPool": "敌人池", "StrengthRule": "档位规则",
	"TechDef": "局外科技", "TechTier": "科技一级", "TechEffect": "科技效果",
}

## 脚本路径 → {字段名 → 说明}；"" 键 = 类的说明
static var _doc_cache: Dictionary = {}


static func zh() -> bool:
	return UiText.lang == "zh"


## 字段的显示标签
static func label(owner: Object, key: String) -> String:
	if not zh():
		return key
	var cls := String(ContentSchema.class_name_of(owner)) if owner != null else ""
	if cls != "" and LABELS.has(cls + "." + key):
		return String(LABELS[cls + "." + key])
	return String(LABELS.get(key, key))


## 字段的说明：脚本里 `@export` 上面的 `##` 注释（含父类的）；读不到就退回标签
static func help(owner: Object, key: String) -> String:
	var doc := doc_of(owner, key)
	return doc if doc != "" else label(owner, key)


## 悬浮窗文字：标签（字段名）+ 说明
static func tip(owner: Object, key: String) -> String:
	var l := label(owner, key)
	var head := l if l == key else "%s（%s）" % [l, key]
	var doc := doc_of(owner, key)
	return head if doc == "" else head + "\n" + doc


## 注册表里的类型名怎么显示
static func type_label(name: StringName) -> String:
	if not zh():
		return String(name)
	return String(TYPE_LABELS.get(String(name), CLASS_LABELS.get(String(name), String(name))))


## 一个构件 / 定义的说明：类顶上的 `##` 注释
static func type_help(inst: Object) -> String:
	if inst == null:
		return ""
	var name := String(ContentSchema.registry_name_of(inst))
	var doc := doc_of(inst, "")
	var head := type_label(name)
	head = head if head == name else "%s（%s）" % [head, name]
	return head if doc == "" else head + "\n" + doc


static func enum_label(name: String) -> String:
	return String(ENUM_LABELS.get(name, name)) if zh() else name


static func class_label(cls: StringName) -> String:
	return String(CLASS_LABELS.get(String(cls), String(cls))) if zh() else String(cls)


#region 从源码读注释
## 这个对象的脚本（含父类）里，字段 [param key] 上面的 `##` 注释；[param key] 为空 = 类顶上的注释。读不到源码返回空串
static func doc_of(owner: Object, key: String) -> String:
	if owner == null:
		return ""
	var script := owner.get_script() as GDScript
	while script != null:
		var table := _docs(script)
		if table.has(key) and String(table[key]) != "":
			return String(table[key])
		if key == "":
			break
		script = script.get_base_script() as GDScript
	return ""


static func _docs(script: GDScript) -> Dictionary:
	var path := script.resource_path
	if path != "" and _doc_cache.has(path):
		return _doc_cache[path]
	var table := _parse(script.source_code)
	if path != "":
		_doc_cache[path] = table
	return table


## 解析一份源码：`@export… var name` 上面连续的 `##` 行（中间允许夹 `@export_group` 行）；文件头的 `##` 段是类的说明
static func _parse(source: String) -> Dictionary:
	var out := {}
	if source == "":
		return out
	var lines := source.split("\n")
	# 类的说明：开头连续的 ## 行（允许空的 ## 行），到第一行别的东西为止
	var head: Array[String] = []
	for line in lines:
		var s := line.strip_edges()
		if s.begins_with("##"):
			head.append(_clean(s))
		elif s == "" and head.is_empty():
			continue
		else:
			break
	out[""] = "\n".join(head).strip_edges()
	var export_re := RegEx.new()
	export_re.compile("^\\s*@export\\w*(\\([^)]*\\))?\\s+var\\s+(\\w+)")
	for i in lines.size():
		var m := export_re.search(lines[i])
		if m == null:
			continue
		var name := m.get_string(2)
		var doc: Array[String] = []
		var j := i - 1
		while j >= 0:
			var s := lines[j].strip_edges()
			if s.begins_with("##"):
				doc.push_front(_clean(s))
			elif s.begins_with("@export_group") or s.begins_with("@export_subgroup"):
				pass
			else:
				break
			j -= 1
		if not doc.is_empty():
			out[name] = "\n".join(doc).strip_edges()
	return out


## 去掉 `## ` 前缀与文档标记（[b]、[method x] 这类）
static func _clean(s: String) -> String:
	var t := s.trim_prefix("##").strip_edges()
	t = t.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "")
	var re := RegEx.new()
	re.compile("\\[(method|member|constant|signal|enum|param|code)\\s+([^\\]]+)\\]")
	t = re.sub(t, "$2", true)
	re.compile("\\[/?code\\]")
	t = re.sub(t, "", true)
	return t
#endregion

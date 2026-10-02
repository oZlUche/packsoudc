## 内容管线：JSON → 资源 → JSON（架构文档第 10 节）。
extends RefCounted

const CI := preload("res://core/authoring/content_importer.gd")


static func _ctx() -> ContentImporter.Context:
	return ContentImporter.Context.new()


static func _report() -> ImportReport:
	return ImportReport.new()


static func _import_item(data: Dictionary, ctx = null) -> Array:
	var c = ctx if ctx != null else _ctx()
	var r := _report()
	var def := ContentImporter.import_item(data, c, r)
	return [def, r]


static func run(t: TestCase) -> void:
	t.begin("内容管线 · 最小物品")

	var out := _import_item({"id": "rock", "display_name": "石头", "shape": ["1"]})
	var def: ItemDef = out[0]
	var report: ImportReport = out[1]

	t.check(report.ok(), "最小物品导入成功：" + report.to_text())
	t.eq(def.id, &"rock", "id")
	t.eq(def.display_name, "石头", "显示名")
	t.eq(def.shape.cell_count(), 1, "形状一格")

	# --- 形状两种写法等价 ---
	var multi: ItemDef = _import_item({"id": "l", "shape": ["11", "10"]})[0]
	var oneline: ItemDef = _import_item({"id": "l", "shape": "11\n10"})[0]
	t.eq(multi.shape.to_bits(), "11\n10", "字符串数组写法")
	t.eq(oneline.shape.to_bits(), "11\n10", "单行加换行写法等价")

	# --- 标签、包 ---
	var bag: ItemDef = _import_item({
		"id": "belt", "shape": ["1", "1", "1"], "is_bag": true,
		"tags": ["gear"], "bag_accept_tags": ["consumable"],
		"bag_mods": [{"stat": "haste", "mult_category": "HASTE", "mult_percent": 15}],
	})[0]
	t.check(bag.is_bag, "是包")
	t.eq(bag.tags, [&"gear"] as Array[StringName], "标签转成了 StringName")
	t.eq(bag.bag_mods.size(), 1, "包体效果")
	t.eq(bag.bag_mods[0].mult_category, StatMath.Buff.HASTE,
		"乘区可以写名字 —— 裸 int 属性靠 INT_ENUMS 登记")
	t.eq(bag.bag_mods[0].stat, &"haste", "属性键")


static func run_rules(t: TestCase) -> void:
	t.begin("内容管线 · 四层规则")

	var out := _import_item({
		"id": "rifle",
		"display_name": "步枪",
		"shape": ["1", "1", "1"],
		"rarity": 2,
		"tags": ["weapon"],
		"combat": {
			"base_stats": {"damage": 8.0},
			"rules": [{
				"trigger": {"type": "on_schedule"},
				"cadence": {"type": "cooldown", "seconds": 0.8},
				"costs": [{"type": "resource", "resource_key": "stamina", "amount": 5.0}],
				"effects": [{"type": "deal_damage", "damage_type": "fire"}],
			}],
		},
	})
	var def: ItemDef = out[0]
	var report: ImportReport = out[1]
	t.check(report.ok(), "导入成功：" + report.to_text())

	t.eq(def.combat.base_stats["damage"], 8.0, "基础属性")
	t.eq(def.combat.rules.size(), 1, "一条规则")
	var rule := def.combat.rules[0]
	t.check(rule.trigger is OnSchedule, "时机按 type 从注册表造出来")
	t.check(rule.cadence is CooldownCadence, "频率同理")
	t.eq((rule.cadence as CooldownCadence).seconds, 0.8, "频率的参数也填上了")
	t.eq(rule.costs.size(), 1, "一条消耗")
	t.eq((rule.costs[0] as ResourceCost).resource_key, &"stamina", "消耗的资源键")
	t.eq(rule.effects.size(), 1, "一个效果")
	t.eq((rule.effects[0] as DealDamage).damage_type, &"fire", "伤害类型")

	# --- 带类型的枚举可以写名字 ---
	var both: ItemDef = _import_item({
		"id": "nova", "shape": ["1"],
		"combat": {"rules": [{
			"trigger": {"type": "on_battle_start"},
			"cadence": {"type": "always"},
			"effects": [{"type": "deal_damage", "target": "BOTH", "amount": 10.0}],
		}]},
	})[0]
	t.eq((both.combat.rules[0].effects[0] as DealDamage).target, CombatEffect.Target.BOTH,
		"target 写成 BOTH，靠 Godot 自带的枚举提示解析")


static func run_cross_scope(t: TestCase) -> void:
	t.begin("内容管线 · 跨域效果与增益引用")

	# 道具自带的战利品效果：和战斗效果同一棵树，导入器不需要区别对待
	var charm: ItemDef = _import_item({
		"id": "charm", "shape": ["1"],
		"effects": [
			{"type": "extra_rolls", "rolls": 2},
			{"type": "drop_owned_chance", "percent": 25},
		],
	})[0]
	t.eq(charm.effects.size(), 2, "两条掉落效果")
	t.check(charm.effects[0] is ExtraRolls, "Effect 这一支要在三个作用域里都找一遍")
	t.eq((charm.effects[1] as DropOwnedChance).percent, 25, "参数")

	# --- 增益：先导入，再按 id 引用 ---
	var ctx := _ctx()
	var r := _report()
	ContentImporter.import_buff({
		"id": "burn", "display_name": "灼烧", "max_stacks": 10,     # 可叠层的永续，不填时长（085）
		"rules": [{
			"trigger": {"type": "on_schedule"},
			"cadence": {"type": "cooldown", "seconds": 1.0},
			"effects": [{
				"type": "deal_damage", "target": "SELF", "damage_type": "fire",
				"damage_stat": "", "amount": 2.0, "per_stack": true,
			}],
		}],
	}, ctx, r)
	t.check(r.ok(), "增益导入成功：" + r.to_text())
	t.check(ctx.buffs.has(&"burn"), "登记进上下文")

	var torch: ItemDef = _import_item({
		"id": "torch", "shape": ["1"],
		"combat": {"rules": [{
			"trigger": {"type": "on_schedule"},
			"cadence": {"type": "cooldown", "seconds": 2.0},
			"effects": [{"type": "apply_status", "buff": "burn", "stacks": 2}],
		}]},
	}, ctx)[0]
	var apply := torch.combat.rules[0].effects[0] as ApplyStatus
	t.eq(apply.buff.id, &"burn", "按 id 引用到了先前导入的增益")
	t.eq(apply.stacks, 2, "层数")

	# --- 也可以内联 ---
	var inline: ItemDef = _import_item({
		"id": "inline", "shape": ["1"],
		"combat": {"rules": [{
			"trigger": {"type": "on_battle_start"},
			"cadence": {"type": "always"},
			"effects": [{"type": "apply_status", "buff": {"id": "rush", "max_stacks": 1, "duration_sec": 3.0}}],
		}]},
	})[0]
	t.eq((inline.combat.rules[0].effects[0] as ApplyStatus).buff.id, &"rush",
		"只被一件道具用到的增益可以内联，不必单开文件")


static func run_buff_duration_rule(t: TestCase) -> void:
	t.begin("内容管线 · 作者定：可叠层的 buff 永续不许填时长（独立文件与道具内联都拦）；不可叠层的可以过期；BuffDef.is_permanent 按此判")
	var ctx := _ctx()
	var bad := _report()
	ContentImporter.import_buff({"id": "t_stack_timed", "display_name": "x", "max_stacks": 5, "duration_sec": 6.0}, ctx, bad)
	t.check(not bad.ok(), "可叠层 + 时长：拦下（%s）" % bad.to_text())
	var ok := _report()
	ContentImporter.import_buff({"id": "t_single_timed", "display_name": "x", "max_stacks": 1, "duration_sec": 6.0}, ctx, ok)
	t.check(ok.ok(), "不可叠层 + 时长：可以")
	var ok2 := _report()
	ContentImporter.import_buff({"id": "t_stack_forever", "display_name": "x", "max_stacks": 0}, ctx, ok2)
	t.check(ok2.ok(), "不限层、没时长：可以")
	var bad_item := _report()
	ContentImporter.import_item({"id": "t_vial", "shape": ["1"], "combat": {"rules": [{"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0},
		"effects": [{"type": "apply_status", "buff": {"id": "t_inline", "max_stacks": 3, "duration_sec": 2.0}}]}]}}, ctx, bad_item)
	t.check(not bad_item.ok(), "道具内联的可叠层 buff 填了时长：也拦")
	var stack := BuffDef.new()
	stack.max_stacks = 5
	stack.duration_sec = 6.0
	t.check(stack.is_stackable() and stack.is_permanent(), "可叠层的就算写了时长也永续")
	var single := BuffDef.new()
	single.max_stacks = 1
	single.duration_sec = 6.0
	t.check(not single.is_stackable() and not single.is_permanent() and single.duration_text().contains("6.0"), "不可叠层 + 时长：会过期")
	single.duration_sec = 0.0
	t.check(single.is_permanent() and single.duration_text() == "永续", "不可叠层没填时长：也永续")
	var inst := BuffInstance.create(stack, 1, 0)
	t.check(inst.is_permanent(), "实例按 is_permanent 判：可叠层的不设过期时刻")


static func run_weapon_stamina_rules(t: TestCase) -> void:
	t.begin("内容管线 · 103 作者定：武器必须造成伤害；只有武器消耗耐力；不限层 + 百分比的 buff 告警")
	var hit := {"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0}, "effects": [{"type": "deal_damage"}]}
	var hit_cost := hit.duplicate(true)
	hit_cost["costs"] = [{"type": "resource", "amount": 5.0}]
	var poison := {"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0},
		"effects": [{"type": "apply_status", "target": "ENEMY", "buff": {"id": "t_poison", "is_debuff": true}}]}

	var ok: ImportReport = _import_item({"id": "t_knife", "shape": ["1"], "tags": ["weapon"], "combat": {"rules": [hit_cost]}})[1]
	t.check(ok.ok(), "武器 + 伤害 + 耗耐力：可以（%s）" % ok.to_text())
	var free: ImportReport = _import_item({"id": "t_free", "shape": ["1"], "tags": ["weapon"], "combat": {"rules": [hit]}})[1]
	t.check(free.ok(), "武器不耗耐力也可以（不强制武器耗耐力）")
	var trap: ImportReport = _import_item({"id": "t_trap", "shape": ["1"], "combat": {"rules": [hit]}})[1]
	t.check(trap.ok(), "不带武器标签也可以造成伤害")

	var no_dmg: ImportReport = _import_item({"id": "t_stick", "shape": ["1"], "tags": ["weapon"]})[1]
	t.check(not no_dmg.ok() and no_dmg.to_text().contains("不造成伤害"), "武器没有任何伤害规则：拦下（%s）" % no_dmg.to_text())
	var only_poison: ImportReport = _import_item({"id": "t_vial", "shape": ["1"], "tags": ["weapon"], "combat": {"rules": [poison]}})[1]
	t.check(not only_poison.ok(), "武器只施毒不直接伤害：拦下（施毒不算造成伤害）")

	var tool_cost: ImportReport = _import_item({"id": "t_tool", "shape": ["1"], "tags": ["tool"], "combat": {"rules": [hit_cost]}})[1]
	t.check(not tool_cost.ok() and tool_cost.to_text().contains("耐力只归武器"), "非武器耗耐力：拦下（%s）" % tool_cost.to_text())
	var mana := hit.duplicate(true)
	mana["costs"] = [{"type": "resource", "resource_key": "mana", "amount": 5.0}]
	var drone: ImportReport = _import_item({"id": "t_drone", "shape": ["1"], "tags": ["tool"], "combat": {"rules": [mana]}})[1]
	t.check(drone.ok(), "非武器耗法力：可以")

	var warn := _report()
	ContentImporter.import_buff({"id": "t_rage", "mods": [{"stat": "armor", "mult_category": "EMPOWER", "mult_percent": 10}]}, _ctx(), warn)
	t.check(warn.ok() and warn.warnings.size() == 1, "不限层 + 百分比：告警不报错（%s）" % warn.to_text())
	var capped := _report()
	ContentImporter.import_buff({"id": "t_rage3", "max_stacks": 3, "mods": [{"stat": "armor", "mult_category": "EMPOWER", "mult_percent": 10}]}, _ctx(), capped)
	t.check(capped.ok() and capped.warnings.is_empty(), "填了层数上限：不告警")
	var flat := _report()
	ContentImporter.import_buff({"id": "t_tough", "mods": [{"stat": "max_hp", "flat": 5.0}]}, _ctx(), flat)
	t.check(flat.warnings.is_empty(), "不限层 + 固定值：不告警")

	# 现有全部道具都守规矩（撬棍加了武器标签之后）
	var bad: Array[String] = []
	for f in DirAccess.get_files_at("res://data/authoring/items"):
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/items/" + f))
		var r := _report()
		var def := ContentImporter.import_item(data, _ctx(), r)
		if def.tags.has(&"weapon") or not r.ok():
			for e in r.errors:
				bad.append("%s %s" % [f, e["message"]])
	t.check(bad.is_empty(), "data/authoring/items 全部满足武器 / 耐力规矩：%s" % ", ".join(bad))
	var crowbar = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/items/crowbar.json"))
	t.check((crowbar["tags"] as Array).has("weapon"), "撬棍带武器标签（作者定）")

	var desc := Glossary.describe_buff(ContentImporter.import_buff({"id": "t_brief", "max_stacks": 1, "duration_sec": 3.0}, _ctx(), _report()))
	t.check(desc.contains("[color=") and desc.contains("不可叠层") and desc.contains("持续 3.0 秒"), "词条：不可叠层与会过期用例外色标出（%s）" % desc)
	var desc2 := Glossary.describe_buff(ContentImporter.import_buff({"id": "t_stack"}, _ctx(), _report()))
	t.check(not desc2.contains("[color="), "默认（不限层、永续）不上色")


static func run_validation(t: TestCase) -> void:
	t.begin("内容管线 · 校验比引擎严格")

	# --- 打错字段名要报错，不能静默取默认值 ---
	var typo: ImportReport = _import_item({"id": "x", "shape": ["1"], "raritty": 3})[1]
	t.check(not typo.ok(), "拼错的字段名被拒")
	t.check(typo.errors[0]["message"].contains("未知字段"), "说清楚是未知字段")
	t.check(typo.errors[0]["message"].contains("rarity"), "并列出可用字段，方便改")

	# --- 认不得的 type 要列出可选项 ---
	var bad_type: ImportReport = _import_item({
		"id": "x", "shape": ["1"],
		"combat": {"rules": [{
			"trigger": {"type": "on_sneeze"}, "cadence": {"type": "always"},
			"effects": [{"type": "deal_damage"}],
		}]},
	})[1]
	t.check(not bad_type.ok(), "认不得的 type 被拒")
	t.check(bad_type.errors[0]["message"].contains("on_schedule"),
		"报错里列出了可用的 type")
	t.check(bad_type.errors[0]["path"].begins_with("combat.rules[0].trigger"),
		"路径定位到具体位置：" + bad_type.errors[0]["path"])

	# --- 缺 id、缺形状 ---
	t.check(not _import_item({"shape": ["1"]})[1].ok(), "缺 id 被拒")
	t.check(not _import_item({"id": "x"})[1].ok(), "缺形状被拒")
	t.check(not _import_item({"id": "x", "shape": ["000"]})[1].ok(), "全 0 的形状被拒")

	# --- 类型不对 ---
	var wrong: ImportReport = _import_item({"id": "x", "shape": ["1"], "rarity": "高"})[1]
	t.check(not wrong.ok(), "稀有度写成字符串被拒")

	# --- 抽象基类必须写 type ---
	var no_type: ImportReport = _import_item({
		"id": "x", "shape": ["1"],
		"combat": {"rules": [{"trigger": {}, "cadence": {"type": "always"}}]},
	})[1]
	t.check(not no_type.ok(), "时机没写 type 被拒")

	# --- 标记格压在自己身上：永远点不亮，但不是错误 ---
	var overlap := _import_item({
		"id": "plate", "shape": ["11"],
		"adjacency": {
			"grant_cells": [[0, 0], [2, 0]],
			"grant_mods": [{"stat": "armor", "flat": 1.0}],
		},
	})
	t.check((overlap[1] as ImportReport).ok(), "压在自己身上只是警告，不阻断")
	t.eq((overlap[1] as ImportReport).warnings.size(), 1, "只对压住的那一格报")
	t.check((overlap[1] as ImportReport).warnings[0]["message"].contains("(0, 0)"),
		"报出来是哪一格：" + (overlap[1] as ImportReport).warnings[0]["message"])

	# --- 警告不阻断 ---
	var warn_only := _import_item({
		"id": "x", "shape": ["1"], "bag_accept_tags": ["consumable"],
	})
	t.check((warn_only[1] as ImportReport).ok(), "只有警告时仍然产出资产")
	t.eq((warn_only[1] as ImportReport).warnings.size(), 1, "提醒了「不是包，准入标签不生效」")


static func run_round_trip(t: TestCase) -> void:
	t.begin("内容管线 · 往返一致")

	# 这一组是整条管线最要紧的测试：**导出再导入必须一致**。
	# 新增一种效果如果没走通用路径（比如在导入器里写了 if），往返立刻就崩。
	var source := {
		"id": "kitchen_sink",
		"display_name": "全家桶",
		"shape": ["110", "011"],
		"rarity": 3,
		"tags": ["weapon", "tool"],
		"set_id": "scavenger",
		"effects": [{"type": "rarity_bias", "rarity": 2, "amount": 15}],
		"combat": {
			"base_stats": {"damage": 12.0, "max_stamina": 30.0},
			"rules": [
				{
					"trigger": {"type": "on_schedule"},
					"cadence": {"type": "cooldown", "seconds": 1.5, "use_haste": false},
					"costs": [
						{"type": "resource", "resource_key": "stamina", "amount": 7.0},
						{"type": "chance", "percent": 80},
					],
					"effects": [
						{"type": "deal_damage", "damage_type": "poison", "per_stack": true},
						{"type": "change_resource", "resource_key": "hp", "amount": -3.0},
					],
				},
				{
					"trigger": {
						"type": "on_damage", "direction": "DEALT", "min_amount": 5.0,
					},
					"cadence": {"type": "always"},
					"effects": [{"type": "reflect_damage", "percent": 40}],
				},
			],
		},
		"adjacency": {
			"grant_cells": [[1, 0], [-1, 0]],
			"grant_filter": ["weapon"],
			"grant_mods": [{"stat": "damage", "mult_category": "SHARP", "mult_percent": 20}],
			"receive_cells": [[0, 1]],
			"receive_mods": [{"stat": "damage", "flat": 2.0}],
		},
	}

	var first := _import_item(source)
	var def: ItemDef = first[0]
	t.check((first[1] as ImportReport).ok(), "导入成功：" + (first[1] as ImportReport).to_text())

	var dumped := ContentExporter.export_item(def)
	var second := _import_item(dumped)
	var def2: ItemDef = second[0]
	t.check((second[1] as ImportReport).ok(),
		"导出的 JSON 能再导入：" + (second[1] as ImportReport).to_text())

	# 逐项比对
	t.eq(def2.id, def.id, "往返：id")
	t.eq(def2.rarity, def.rarity, "往返：稀有度")
	t.eq(def2.tags, def.tags, "往返：标签")
	t.eq(def2.set_id, def.set_id, "往返：套装归属")
	t.eq(def2.shape.to_bits(), def.shape.to_bits(), "往返：形状")
	t.eq(def2.effects.size(), 1, "往返：跨域效果")
	t.eq((def2.effects[0] as RarityBias).amount, 15, "往返：跨域效果的参数")

	t.eq(def2.combat.base_stats, def.combat.base_stats, "往返：基础属性")
	t.eq(def2.combat.rules.size(), 2, "往返：两条规则")

	var r0 := def2.combat.rules[0]
	t.eq((r0.cadence as CooldownCadence).seconds, 1.5, "往返：冷却秒数")
	t.eq((r0.cadence as CooldownCadence).use_haste, false, "往返：非默认的布尔值")
	t.eq(r0.costs.size(), 2, "往返：两条消耗")
	t.eq((r0.costs[1] as ChanceCondition).percent, 80, "往返：概率")
	t.eq((r0.effects[0] as DealDamage).damage_type, &"poison", "往返：伤害类型")
	t.eq((r0.effects[1] as ChangeResource).amount, -3.0, "往返：负数")

	var r1 := def2.combat.rules[1]
	t.eq((r1.trigger as OnDamage).direction, DamageTrigger.Direction.DEALT, "往返：枚举")
	t.eq((r1.effects[0] as ReflectDamage).percent, 40, "往返：反伤")

	t.eq(def2.adjacency.grant_cells, def.adjacency.grant_cells, "往返：增益格")
	t.eq(def2.adjacency.grant_filter, def.adjacency.grant_filter, "往返：过滤器")
	t.eq(def2.adjacency.grant_mods[0].mult_percent, 20, "往返：邻接加成")
	t.eq(def2.adjacency.receive_mods[0].flat, 2.0, "往返：固定加值")

	# 导出的 JSON 只写非默认值 —— 否则每个道具都拖着二十行 false
	t.check(not dumped.has("icon"), "没设过的字段不写进 JSON")
	t.check(not (dumped["combat"]["rules"][1]["effects"][0] as Dictionary).has("flat"),
		"子对象同样只写非默认值")

	# 再导出一次必须逐字节相同 —— 否则 git diff 会无限抖动
	t.eq(ContentExporter.to_json(ContentExporter.export_item(def2)),
		ContentExporter.to_json(dumped),
		"二次导出与一次导出逐字节相同，git diff 不会抖")


static func run_existing_assets(t: TestCase) -> void:
	t.begin("内容管线 · 现有资产能往返")

	# 拿 data/items 里真实的 .tres 过一遍：手写的测试数据总是碰巧合规，
	# 真资产才会暴露漏掉的字段。
	var db := ItemDatabase.new()
	if db.load_dir() == 0:
		t.check(false, "没有加载到任何物品定义")
		return

	var ctx := _ctx()
	var checked := 0
	var failed: Array[String] = []
	for id in db.all_ids():
		var def := db.get_def(id)
		if def == null:
			continue
		var dumped := ContentExporter.export_item(def)
		var report := _report()
		report.source = String(id)
		var back := ContentImporter.import_item(dumped, ctx, report)
		checked += 1
		if not report.ok():
			failed.append("%s: %s" % [id, report.to_text()])
			continue
		if back.shape == null or back.shape.to_bits() != def.shape.to_bits():
			failed.append("%s: 形状对不上" % id)
		if back.combat != null and def.combat != null:
			if back.combat.rules.size() != def.combat.rules.size():
				failed.append("%s: 规则条数对不上" % id)

	t.check(checked >= 15, "过了 %d 件真实资产" % checked)
	t.check(failed.is_empty(), "全部往返成功" if failed.is_empty() else "\n".join(failed))


static func run_assets_match_json(t: TestCase) -> void:
	t.begin("内容管线 · 仓库里的作者 JSON 与 .tres 一致（100 第 1 步；命令行是 tools/check_content.gd，同一段逻辑）")
	# 每一种都得有导出器与登记，否则新种类会悄悄躲过这道检查
	for kind in ContentPaths.ORDER:
		t.check(ContentCheck.KINDS.has(String(kind)), "%s 在 ContentCheck.KINDS 里" % kind)
	for kind in ContentCheck.KINDS:
		t.check(not ContentPaths.dirs_of(kind).is_empty(), "%s 有目录（KINDS 或 EDITOR_ONLY_KINDS）" % kind)
	var problems := ContentCheck.run_all()
	t.check(problems.is_empty(), "198 份内容对得上" if problems.is_empty() else "\n      ".join(problems))
	# 这道检查本身抓不抓得住：改一个值、少一份资产，都得报出来
	var items: Array[String] = ContentCheck.check_kind("items")
	t.check(items.is_empty(), "items 一致")
	t.check(not ContentCheck.check_kind("根本没有这一种").is_empty(), "不认识的种类会报出来")
	# 100（作者定）：buffs / sets 有目录、不进 KINDS，所以不走这道检查
	for kind in ["buffs", "sets"]:
		t.check(not ContentPaths.KINDS.has(kind), "%s 不在 KINDS 里" % kind)
		t.check(ContentPaths.authoring_file(kind, "x") != "" and ContentPaths.asset_file(kind, "x") != "",
			"%s 的路径照样算得出来（编辑器在用）" % kind)

## 101 第 5 刀：注册表拆成三张（战斗 / 战利品 / 一局），内容管线要的是合起来那一张
static func run_registries_split(t: TestCase) -> void:
	t.begin("注册表 · 拆成三张（101 第 5 刀）：各层只认自己的构件，内容管线按 ContentRegistries 查全部；种类名不许撞")
	t.eq(EffectRegistry.TABLES.keys(), [&"trigger", &"cadence", &"cost", &"effect"], "战斗那张只有战斗的四种")
	t.eq(LootRegistry.TABLES.keys(), [&"loot_effect"], "战利品那张只有掉落效果")
	for kind in [&"run_effect", &"run_module", &"run_mechanic", &"event_condition", &"event_outcome",
			&"run_skill", &"faith_deed", &"faith_perk", &"hunter_behavior", &"hunter_loss", &"erosion_effect", &"map_effect"]:
		t.check(RunRegistry.TABLES.has(kind), "一局那张有 %s" % kind)
		t.check(not EffectRegistry.TABLES.has(kind), "战斗那张没有 %s（它不认识一局的构件）" % kind)
	var all := ContentRegistries.tables()
	t.eq(all.size(), EffectRegistry.TABLES.size() + LootRegistry.TABLES.size() + RunRegistry.TABLES.size(),
		"合起来 = 三张之和（种类名没撞）")
	# 三张各自查自己的；合起来的三家都查得到
	t.check(EffectRegistry.has_type(&"trigger", &"on_battle_start") and not EffectRegistry.has_type(&"run_module", &"safe"),
		"战斗那张查得到扳机、查不到模块")
	t.check(RunRegistry.has_type(&"run_module", &"safe") and RunRegistry.has_type(&"faith_perk", &"undying"), "一局那张查得到模块与 perk")
	for pair in [[&"trigger", &"on_battle_start"], [&"loot_effect", &"extra_rolls"], [&"run_module", &"safe"], [&"faith_perk", &"undying"]]:
		t.check(ContentRegistries.has_type(pair[0] as StringName, pair[1] as StringName), "合起来查得到 %s/%s" % pair)
	t.not_null(ContentRegistries.instantiate(&"run_module", &"safe"), "合起来造得出一局的构件")
	t.not_null(ContentRegistries.instantiate(&"trigger", &"on_battle_start"), "合起来造得出战斗的构件")
	t.is_null(ContentRegistries.instantiate(&"run_module", &"no_such_module"), "没登记的造不出来（导入器据此拒绝生成资产）")
	# 校验表（ContentSchema）认得的每一种，合起来那张都得有
	for base in ContentSchema.ABSTRACT_ROOTS:
		for kind in ContentSchema.ABSTRACT_ROOTS[base]:
			t.check(all.has(kind), "校验表里的种类 %s（%s）在注册表里" % [kind, base])

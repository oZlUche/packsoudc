## 104（神明总表落地）：删战争之神、技巧 / 狩猎的四条新信力行为、获得的对账、信力节奏量尺、献祭的 has_stat 与新倍率、
## 暴击属性（默认 10% / 150%、只加算、掷骰与包旗、两条固定值轴、预估乘期望）、xlsx ⇄ JSON 对照、每位神一枚 1 格护符。
## 期望从数据推：行为构件说给几点就断言几点，倍率读信仰文件。
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _start(items: ItemDatabase) -> RunState:
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "chapter_01"))
	var chars := GameFlow.load_characters()
	for seed in range(1, 60):
		var s := RunState.start(chapter, seed, items, enemies, sets, [] as Array[StringName], {}, [] as Array[StringName], chars[0] if not chars.is_empty() else null)
		if s != null:
			s.faith_defs = FaithDef.load_all()
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func _gain(def: FaithDef, event: StringName, payload: Dictionary) -> int:
	var n := 0
	for d in def.deeds:
		n += maxi(0, (d as FaithDeed).gain(event, payload))
	return n


static func run_content(t: TestCase) -> void:
	t.begin("104 · 内容：战争之神删了；技巧 / 狩猎有 1 格护符（信物、暂无效果）；胫骨大棒没有 1 阶功能；leather 标签；每位诸神至少一枚 1 格护符")
	var defs := FaithDef.load_all()
	t.check(not defs.has(&"war"), "没有战争之神")
	t.eq(defs.size(), 7, "七份信仰（四位主神 + 技巧 + 狩猎 + 新教占位）")
	var db := _db()
	for fid in [&"skill", &"hunt"]:
		var charm := db.get_def(StringName("charm_%s" % fid))
		t.not_null(charm, "%s 的护符" % fid)
		if charm == null:
			continue
		t.check(charm.is_anchor() and FaithDef.id_of_tag(charm.faith_tag()) == fid, "%s 的护符是它的信物" % fid)
		t.eq(ItemVolume.cells_of(charm), 1, "1 格")
		t.check(charm.faith_bonuses.is_empty() and charm.combat == null, "暂无效果")
	t.check(db.get_def(&"tibia_violence").faith_bonuses.is_empty(), "胫骨大棒移除了 1 阶功能")
	t.check(db.get_def(&"tibia_violence").tags.has(&"faith:brute"), "但仍是蛮神的道具")
	t.check(db.get_def(&"leather_armor").tags.has(&"leather") and db.get_def(&"bag_leather").tags.has(&"leather"), "皮甲、皮革包带 leather")
	# 导入器守 1 格护符
	var ctx := ContentImporter.Context.new()
	for id in defs:
		ctx.register_faith(defs[id])
	for id in db.ids():
		ctx.register_item(db.get_def(id))
	var ok := ImportReport.new()
	ContentImporter.validate_faith_charms(ctx, ok)
	t.check(ok.ok(), "现有内容每位神都有 1 格护符：%s" % ok.to_text())
	ctx.items.erase(&"charm_skill")
	var bad := ImportReport.new()
	ContentImporter.validate_faith_charms(ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("技巧之神"), "拿掉技巧之神的护符就拦：%s" % bad.to_text().strip_edges().left(60))


static func run_deeds(t: TestCase) -> void:
	t.begin("104 · 四条新行为：获得金属道具按格 ×3、每种武器首次出手 +10 封顶 50、按节点类型给（输了也给）、每局首次置入一种战利品 2^稀有度 + 1")
	var defs := FaithDef.load_all()
	var skill: FaithDef = defs[&"skill"]
	var hunt: FaithDef = defs[&"hunt"]
	t.eq(_gain(skill, &"item_acquired", {"id": "x", "tags": ["metal", "weapon"], "cells": 4}), 12, "4 格金属 +12")
	t.eq(_gain(skill, &"item_acquired", {"id": "x", "tags": ["weapon"], "cells": 4}), 0, "不是金属不给")
	var two_same := {"fired_items": [{"id": "knife", "tags": ["weapon"], "count": 3}, {"id": "knife", "tags": ["weapon"], "count": 1},
		{"id": "shortsword", "tags": ["weapon"], "count": 2}, {"id": "salve", "tags": ["consumable"], "count": 5}]}
	t.eq(_gain(skill, &"battle", two_same), 20, "两把同名匕首 + 一把短剑出手 → +20（同名只算一次、不是武器不算）")
	var six := {"fired_items": []}
	for i in 6:
		(six["fired_items"] as Array).append({"id": "w%d" % i, "tags": ["weapon"], "count": 1})
	t.eq(_gain(skill, &"battle", six), 50, "六把不同的封顶 50")
	t.eq(_gain(hunt, &"battle", {"won": false, "node_type": "elite"}), 20, "进精英战 +20，输了也给")
	t.eq(_gain(hunt, &"battle", {"won": true, "node_type": "battle"}), 5, "普通 +5")
	t.eq(_gain(hunt, &"battle", {"won": true, "node_type": "core"}), 50, "BOSS +50")
	t.eq(_gain(hunt, &"battle", {"won": true, "node_type": "search"}), 0, "表里没有的类型不给")
	t.eq(_gain(hunt, &"place_item", {"tags": ["trophy"], "rarity": 3, "first_in_run": true}), 9, "首次置入稀有度 3 的战利品 +9")
	t.eq(_gain(hunt, &"place_item", {"tags": ["trophy"], "rarity": 3, "first_in_run": false}), 0, "再置入同种不给")
	t.eq(_gain(hunt, &"place_item", {"tags": ["weapon"], "rarity": 3, "first_in_run": true}), 0, "不是战利品不给")
	# 往返
	var text := ContentExporter.to_json(ContentExporter.export_faith(skill))
	var back := ContentImporter.import_faith(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_faith(back)), text, "技巧之神导出 → 导入 → 再导出逐字节相同")


static func run_acquired_wiring(t: TestCase) -> void:
	t.begin("104 · 接线：获得的对账只发一次、带进来的不算；置入的 first_in_run 按种类；战斗账带 node_type 与道具 id；信力记录与读档")
	var db := _db()
	var s := _start(db)
	if s == null:
		t.check(false, "开不了局")
		return
	var defs := FaithDef.load_all()
	t.eq(s.reconcile_owned(), 0, "开局带进来的都算对过账")
	var charm := ItemInstance.create(db.get_def(&"charm_skill"), 0)
	s.storage.admit(charm)
	t.check(s.equip(charm.uid), "放上技巧之神的护符")
	t.eq(s.active_faith_id(), &"skill", "激活技巧之神")
	var metal: ItemDef = null
	for id in db.ids():
		var d := db.get_def(id)
		if d.tags.has(&"metal") and not d.has_faith() and not d.is_blessed():
			metal = d
			break
	t.not_null(metal, "有一件金属道具")
	if metal == null:
		return
	var before := s.faith_power.points_of(&"skill")
	s.storage.admit(ItemInstance.create(metal, 0))
	t.eq(s.reconcile_owned(), 2, "护符和金属道具两件新对上")
	var want := 3 * ItemVolume.cells_of(metal) + _gain(defs[&"skill"], &"item_acquired", {"tags": ["treasure", "faith", "faith:skill", "faith_anchor"], "cells": 1})
	t.eq(s.faith_power.points_of(&"skill") - before, want, "%s（%d 格金属）+%d" % [metal.id, ItemVolume.cells_of(metal), 3 * ItemVolume.cells_of(metal)])
	var mid := s.faith_power.points_of(&"skill")
	t.eq(s.reconcile_owned(), 0, "再对一次：没有新的")
	t.eq(s.faith_power.points_of(&"skill"), mid, "同一件不再给")
	# 置入：first_in_run 按定义 id
	t.check(s.placed_ids.has("charm_skill"), "护符置入过，记下了种类")
	# 战斗账
	var r := BattleResult.new()
	var e := BattleEvent.new()
	e.name = BattleEvent.ITEM_FIRED
	e.side = 0
	e.payload = {"uid": charm.uid}
	r.log.append(e)
	var sum := RunState.battle_summary(r, false, s.board, &"elite")
	t.eq(String(sum.get("node_type", "")), "elite", "战斗账带 node_type")
	t.eq(String((sum["fired_items"] as Array)[0].get("id", "")), "charm_skill", "出手的道具带 id")
	# 记录与读档
	t.check(not s.faith_power.history.is_empty(), "信力有记录")
	var last: Dictionary = s.faith_power.history[-1]
	t.eq(String(last.get("faith", "")), "skill", "记录写了哪位神")
	t.eq(int(last.get("total", -1)), s.faith_power.points_of(&"skill"), "记录写了累计")
	var d := s.to_dict()
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(d)), s.chapter, db, s.enemies, s.sets)
	t.not_null(back, "读档")
	if back == null:
		return
	t.eq(back.faith_power.history.size(), s.faith_power.history.size(), "信力记录跟着存档")
	t.eq(back.owned_uids.size(), s.owned_uids.size(), "对过账的实例跟着存档")
	t.check(back.placed_ids.has("charm_skill") and back.acquired_ids.has(String(metal.id)), "种类账跟着存档")
	back.faith_defs = defs
	t.eq(back.reconcile_owned(), 0, "读档后不会把身上的东西再算一遍")
	# 老存档没有这笔账：读回来把身上的记成对过账，不补点
	var old := (JSON.parse_string(JSON.stringify(d)) as Dictionary)
	old.erase("owned_uids")
	var back_old := RunState.from_dict(old, s.chapter, db, s.enemies, s.sets)
	back_old.faith_defs = defs
	var p_old := back_old.faith_power.points_of(&"skill")
	t.eq(back_old.reconcile_owned(), 0, "老存档：身上的不算新获得")
	t.eq(back_old.faith_power.points_of(&"skill"), p_old, "老存档：不补点")


static func run_pace(t: TestCase) -> void:
	t.begin("104 · 信力节奏的量尺：每阶头一回是第几步、结算屏一行、CSV")
	var hist := [
		{"step": 2, "node_type": "battle", "faith": "sun", "event": "battle", "gained": 30, "total": 30, "tier": 0},
		{"step": 3, "node_type": "battle", "faith": "sun", "event": "battle", "gained": 25, "total": 55, "tier": 1},
		{"step": 9, "node_type": "elite", "faith": "sun", "event": "offering", "gained": 120, "total": 175, "tier": 2},
	]
	t.eq(FaithPower.tier_steps(hist, &"sun"), [3, 9] as Array[int], "第 3 步到 1 阶、第 9 步到 2 阶")
	var defs := FaithDef.load_all()
	var line := FaithPower.pace_line(hist, defs)
	t.check(line.contains("日神") and line.contains("第 3 步到 1 阶") and line.contains("第 9 步到 2 阶"), "结算屏一行：%s" % line)
	t.eq(FaithPower.pace_line([], defs), "", "没攒过信力不写")
	var csv := FaithPower.history_csv(hist)
	t.eq(csv.split("\n", false).size(), 4, "CSV 表头 + 三行")
	t.check(csv.begins_with("step,node_type,faith,event,gained,total,tier"), "CSV 表头")
	var r := RunResult.new()
	r.run_seed = 104
	r.faith_history = hist
	var path := r.export_faith_csv("user://")
	t.eq(path, "user://faith_history_104.csv", "写到 user://faith_history_<seed>.csv")
	t.eq(FileAccess.get_file_as_string(path), csv, "内容就是那份 CSV")
	DirAccess.remove_absolute(path)


static func run_offerings(t: TestCase) -> void:
	t.begin("104 · 献祭：倍率默认 1；has_stat 只认显式写了的属性；多条命中相加；技巧之神的暴击道具 ×8")
	t.eq(OfferingRule.new().multiplier, 1.0, "倍率默认 1")
	var defs := FaithDef.load_all()
	var skill: FaithDef = defs[&"skill"]
	var brute: FaithDef = defs[&"brute"]
	var crit_item := ItemDef.new()
	crit_item.id = &"probe_crit"
	crit_item.rarity = 2
	crit_item.combat = CombatProfile.new()
	crit_item.combat.base_stats = {"damage": 5.0, "crit_chance": 0.2}
	var plain := ItemDef.new()
	plain.id = &"probe_plain"
	plain.rarity = 2
	plain.combat = CombatProfile.new()
	plain.combat.base_stats = {"damage": 5.0}
	t.eq(skill.offering_value(crit_item), 4 * 8, "显式写了暴击率：2^2 × 8 = 32")
	t.eq(skill.offering_value(plain), 0, "默认 10% 不算「带有」")
	# 骨制武器献给蛮神 = 2^稀有度 × (5 + 2)
	var bone_weapon := ItemDef.new()
	bone_weapon.id = &"probe_bone"
	bone_weapon.rarity = 1
	bone_weapon.tags = [&"bone", &"weapon"] as Array[StringName]
	t.eq(brute.offering_value(bone_weapon), 2 * (5 + 2), "骨制武器献给蛮神：2^1 × (5 + 2) = 14")
	# has_stat 往返
	var data := {"id": "probe", "display_name": "试", "offerings": [{"has_stat": "crit_chance", "multiplier": 8.0}]}
	var def := ContentImporter.import_faith(data, ContentImporter.Context.new(), ImportReport.new())
	var text := ContentExporter.to_json(ContentExporter.export_faith(def))
	t.check(text.contains("\"has_stat\": \"crit_chance\""), "has_stat 导出")
	var back := ContentImporter.import_faith(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq((back.offerings[0] as OfferingRule).has_stat, &"crit_chance", "has_stat 导入回来")


static func _attacker(stats: Dictionary, from_stat: bool = true) -> CombatantSpec:
	var cd := CooldownCadence.new()
	cd.seconds = 1.0
	var hit := DealDamage.new()
	if not from_stat:
		hit.damage_stat = &""
		hit.amount = 2.0
	return H._spec(100.0, [H._compiled(1, "blade", stats, [H._rule(OnSchedule.new(), cd, [hit])])])


static func _first_damage(stats: Dictionary, from_stat: bool = true) -> BattleEvent:
	var ctx := H._battle(_attacker(stats, from_stat), H._spec(100.0, []))
	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()
	H._advance_to(ctx, 1.5)
	for ev in ctx.log:
		var e := ev as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1:
			return e
	return null


static func run_crit(t: TestCase) -> void:
	t.begin("104 · 暴击：默认 10% / 150%；0 永不、1 必中；暴击包 raw × 暴击伤害；固定值伤害不暴击；事件带 crit；轴加算；只收 flat；预估乘期望")
	t.eq(BattleStats.default_base(BattleStats.CRIT_CHANCE), StatMath.from_float(0.10), "暴击率默认 10%")
	t.eq(BattleStats.default_base(BattleStats.CRIT_DAMAGE), StatMath.from_float(1.5), "暴击伤害默认 150%")
	t.eq(BattleStats.default_base(BattleStats.HASTE), StatMath.ONE, "急速仍是 1.0")
	t.eq(StatSet.new().total_of(BattleStats.CRIT_CHANCE), StatMath.from_float(0.10), "没写的道具取到默认值")
	var never := _first_damage({"damage": 10.0, "crit_chance": 0.0})
	t.not_null(never, "打出了伤害")
	if never != null:
		t.check(not never.get_bool(&"crit") and never.get_int(&"raw") == StatMath.from_float(10.0), "暴击率 0：不暴击，raw 10")
	var always := _first_damage({"damage": 10.0, "crit_chance": 1.0})
	if always != null:
		t.check(always.get_bool(&"crit"), "暴击率 1：必暴击")
		t.eq(always.get_int(&"raw"), StatMath.from_float(15.0), "暴击包 raw × 1.5 = 15")
	var big := _first_damage({"damage": 10.0, "crit_chance": 1.0, "crit_damage": 2.25})
	if big != null:
		t.eq(big.get_int(&"raw"), StatMath.from_float(22.5), "暴击伤害 225%：raw 22.5")
	var fixed := _first_damage({"crit_chance": 1.0}, false)
	if fixed != null:
		t.check(not fixed.get_bool(&"crit") and fixed.get_int(&"raw") == StatMath.from_float(2.0), "固定值伤害（灼烧那种）不暴击")
	# 默认 10% 在 1000 次里落在 7%～13%
	var ctx := H._battle(_attacker({"damage": 10.0}), H._spec(100.0, []))
	var rc := RuleContext.create(ctx, ctx.sides[0], ctx.sides[0].rules[0])
	var hits := 0
	for i in 1000:
		if DealDamage.roll_crit(rc):
			hits += 1
	t.check(hits >= 70 and hits <= 130, "默认 10%%：1000 次暴击 %d 次（7%%～13%%）" % hits)
	# 同种子同结果
	var a := BattleSim.run(_attacker({"damage": 10.0, "crit_chance": 0.5}), H._spec(200.0, []), _rng(7), 20.0)
	var b := BattleSim.run(_attacker({"damage": 10.0, "crit_chance": 0.5}), H._spec(200.0, []), _rng(7), 20.0)
	var crits_a := 0
	var same := a.log.size() == b.log.size()
	for i in mini(a.log.size(), b.log.size()):
		var ea := a.log[i] as BattleEvent
		var eb := b.log[i] as BattleEvent
		if ea.name != eb.name or ea.payload != eb.payload:
			same = false
		if ea.name == BattleEvent.DAMAGE and ea.get_bool(&"crit"):
			crits_a += 1
	t.check(same, "同种子两次模拟逐事件相同")
	t.check(crits_a > 0, "50%% 暴击率打了一阵：暴击 %d 次" % crits_a)
	# 轴：锐目 +5 层 = +5%，加算到每件道具上
	ctx.sides[0].shift_axis(StatAxes.CRIT_CHANCE, 5)
	t.eq(ctx.sides[0].item_stat(1, BattleStats.CRIT_CHANCE), StatMath.from_float(0.15), "锐目 5 层：道具的暴击率 10% + 5% = 15%")
	ctx.sides[0].shift_axis(StatAxes.CRIT_DAMAGE, -2)
	t.eq(ctx.sides[0].item_stat(1, BattleStats.CRIT_DAMAGE), StatMath.from_float(1.4), "钝击 2 层：暴击伤害 150% − 10% = 140%")
	t.eq(StatAxes.name_of(StatAxes.CRIT_CHANCE, 1), "锐目", "正名")
	t.eq(StatAxes.name_of(StatAxes.CRIT_DAMAGE, -1), "钝击", "负名")
	t.check(StatAxes.describe(StatAxes.CRIT_CHANCE, 3).contains("±1%"), "说明按百分数写：%s" % StatAxes.describe(StatAxes.CRIT_CHANCE, 3))
	# 只收 flat
	var bad := ImportReport.new()
	ContentImporter.import_buff({"id": "b", "display_name": "b", "mods": [{"stat": "crit_chance", "mult_category": "EMPOWER", "mult_percent": 10}]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok() and bad.to_text().contains("crit_chance"), "暴击率写乘区：拦（%s）" % bad.to_text().strip_edges().left(50))
	var good := ImportReport.new()
	ContentImporter.import_buff({"id": "b", "display_name": "b", "mods": [{"stat": "crit_chance", "flat": 0.05}]}, ContentImporter.Context.new(), good)
	t.check(good.ok(), "暴击率写 flat：过")
	var m := StatModifier.new()
	m.stat = BattleStats.CRIT_CHANCE
	m.flat = 0.05
	t.eq(Glossary.mod_text(m), "暴击率 +5%", "按百分数写")
	# 预估乘期望
	var stats := StatSet.new()
	stats.set_base(BattleStats.DAMAGE, StatMath.from_float(10.0))
	t.check(absf(DealDamage.new().estimated_damage(stats) - 10.5) < 0.001, "预估：10 × 1.05 = 10.5")


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


static func run_gods_table(t: TestCase) -> void:
	t.begin("104 · 神明总表 ⇄ JSON：读得了 xlsx；表与七份信仰 JSON 一致；改表就对不上")
	var sheets := XlsxReader.read(GodsTable.PATH)
	t.check(sheets.has("神明总表") and sheets.has("信力行为") and sheets.has("献祭") and sheets.has("等级效果"), "四张机器读的表都在")
	var problems: Array[String] = []
	var table := GodsTable.fields(sheets, problems)
	t.check(problems.is_empty(), "表里没有看不懂的：%s" % "；".join(problems))
	t.eq(table.size(), 7, "七位神")
	t.eq((table.get("skill", {}) as Dictionary).get("thresholds", []), [25, 80], "技巧之神占位阈值 25 / 80")
	var check := GodsTable.check()
	t.check(check.is_empty(), "表与 JSON 一致：%s" % "；".join(check))
	# 改一处就红
	var sun_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file("faiths", "sun")))
	var f: Dictionary = (table["sun"] as Dictionary).duplicate(true)
	f["thresholds"] = [1, 2, 3, 4]
	var want := GodsTable.normalized(GodsTable.apply(sun_json, f))
	t.check(ContentCheck._diff_path(sun_json, want, "") != "", "表里阈值变了：和 JSON 对不上")
	# 条件解析
	var cond := GodsTable._condition("tags: gear / armor；min_cells: 9", "x", problems)
	t.eq(cond, {"tags": ["gear", "armor"], "min_cells": 9}, "条件「；」并列")

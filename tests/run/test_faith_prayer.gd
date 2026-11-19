## 信仰重构 B（交接方案 §3、§4）：信力（成长，阶只看它，不花）与祈愿（消费，有上限）分开；
## 打完一场有效战斗给祈愿、秒杀不给；献祭两样都进；花祈愿不降阶；存档往返；
## 派生赐福版在异神下只停神力层，基础层照常（编译、套装、画灰都按它）。
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _start(items: ItemDatabase) -> RunState:
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var chars := GameFlow.load_characters()
	for seed_ in range(1, 60):
		var s := RunState.start(chapter, seed_, items, enemies, sets, [] as Array[StringName], {}, [] as Array[StringName], chars[0] if not chars.is_empty() else null)
		if s != null:
			s.faith_defs = FaithDef.load_all()
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func _battle_node(run: RunState) -> MapNode:
	for id_ in run.map.node_ids():
		var n := run.map.get_node(id_)
		if n != null and n.type == &"battle":
			return n
	return run.current_node()


static func run_prayer_pool(t: TestCase) -> void:
	t.begin("信仰重构 B · 祈愿：上限、花不降阶、不够不扣、改信两边都留")
	var db := _db()
	var run := _start(db)
	if run == null:
		t.check(false, "开不了一局")
		return
	var fp := run.faith_power
	var cap := fp.prayer_cap(&"brute")
	t.eq(cap, FaithPower.PRAYER_CAP_DEFAULT, "没配上限：默认 %d" % FaithPower.PRAYER_CAP_DEFAULT)
	t.eq(fp.add_prayer(&"brute", cap + 30), cap, "加超了只进到上限")
	t.eq(fp.prayer_of(&"brute"), cap, "封顶")
	t.eq(fp.add_prayer(&"brute", 5), 0, "满了再加：0")
	fp.add_points(&"brute", 200)
	var tier := fp.tier_of(&"brute")
	t.check(fp.spend_prayer(&"brute", 60), "花 60 祈愿")
	t.eq(fp.prayer_of(&"brute"), cap - 60, "祈愿扣了")
	t.eq(fp.points_of(&"brute"), 200, "信力一点不扣")
	t.eq(fp.tier_of(&"brute"), tier, "阶不变")
	t.check(not fp.spend_prayer(&"brute", cap), "不够：false")
	t.eq(fp.prayer_of(&"brute"), cap - 60, "不够就一点不扣")
	t.check(not fp.spend_prayer(&"brute", 0) and not fp.spend_prayer(&"brute", -5), "0 和负数不算花")
	fp.add_prayer(&"sun", 12)
	t.eq([fp.prayer_of(&"brute"), fp.prayer_of(&"sun")], [cap - 60, 12], "各神各一份，不互相转")
	# 存档往返
	var d := fp.progress_to_dict()
	var back := FaithPower.new()
	back.setup(run)
	back.restore_progress(d)
	t.eq([back.points_of(&"brute"), back.prayer_of(&"brute"), back.prayer_of(&"sun")], [200, cap - 60, 12], "faith_progress 存读一致")
	back.restore_progress({"brute": {"devotion": -4, "prayer": "x"}, "sun": 7})
	t.eq([back.points_of(&"brute"), back.prayer_of(&"brute"), back.prayer_of(&"sun")], [0, 0, 0], "负数清成 0、坏类型跳过")


static func run_prayer_income(t: TestCase) -> void:
	t.begin("信仰重构 B · 祈愿从哪来：有效战斗 +8（记给开战时的信仰）、秒杀不给、不奉神不记；献祭进 min(2V, 余量)")
	var db := _db()
	var run := _start(db)
	if run == null:
		t.check(false, "开不了一局")
		return
	var fp := run.faith_power
	var node := _battle_node(run)
	run.events.last_battle = {"player": run.compile_player(), "node": node.id}
	run.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(fp.prayer_of(&"brute"), 0, "不奉神：打完不记祈愿")
	Support.activate(run, &"charm_brute")
	t.eq(run.active_faith_id(), &"brute", "奉蛮神")
	run.events.last_battle = {"player": run.compile_player(), "node": node.id}
	run.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(fp.prayer_of(&"brute"), FaithPower.PRAYER_PER_BATTLE, "打完一场 +%d 祈愿" % FaithPower.PRAYER_PER_BATTLE)
	run.events.last_battle = {"player": run.compile_player(), "node": node.id, "smite": true}
	run.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(fp.prayer_of(&"brute"), FaithPower.PRAYER_PER_BATTLE, "秒杀不算打了一场：不给祈愿")
	t.eq(run.faith_context().prayer, FaithPower.PRAYER_PER_BATTLE, "快照里有祈愿")
	var rows := fp.history.filter(func(r: Dictionary) -> bool: return r.has("prayer"))
	t.check(not rows.is_empty() and String(rows[-1]["event"]) == "battle", "祈愿进出记进节奏表（校准用）")
	# 献祭
	var altar := AltarModule.of(run)
	var sword := ItemInstance.create(db.get_def(&"shortsword"))
	var v := run.active_faith().offering_value(sword.def)
	t.check(v > 0, "蛮神收短剑（V = %d）" % v)
	var p0 := fp.prayer_of(&"brute")
	var dv0 := fp.points_of(&"brute")
	var out := altar.offer([sword])
	t.eq(int(out["points"]), v, "信力 +V")
	t.eq(fp.points_of(&"brute"), dv0 + v, "信力进账")
	t.eq(int(out["prayer"]), mini(2 * v, fp.prayer_cap(&"brute") - p0), "祈愿 +min(2V, 余量)")
	t.eq(fp.prayer_of(&"brute"), p0 + int(out["prayer"]), "祈愿进账")
	fp.add_prayer(&"brute", 999)
	var full := altar.offer([ItemInstance.create(db.get_def(&"shortsword"))])
	t.eq(int(full["prayer"]), 0, "祈愿满了：照实写 0（信力照进）")
	t.eq(int(full["points"]), v, "信力照进")


static func run_base_layer(t: TestCase) -> void:
	t.begin("信仰重构 B · 基础层与赐福层：派生赐福版在异神 / 不奉神下仍是原物品（属性照算、不压灰、不算整件休眠），只停信力加成")
	var db := _db()
	var sb := db.get_def(&"shortsword_brute")
	var base := db.get_def(&"shortsword")
	t.check(sb != null and base != null and sb.is_blessed(), "有蛮神赐福的短剑（派生版）")
	if sb == null or base == null:
		return
	t.check(FaithState.keeps_base_layer(sb), "派生赐福版有基础层")
	t.check(not FaithState.keeps_base_layer(db.get_def(&"charm_brute")), "信物没有可分离的基础层")
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	var sword := TestSupport.put(b, sb)
	var charm := TestSupport.put_apart(b, db.get_def(&"charm_sun"), [sword])
	t.check(sword != null and charm != null, "放上蛮神赐福短剑与日神护符")
	if sword == null or charm == null:
		return
	b.select_faith(&"faith:sun")
	t.check(FaithState.is_dormant(sb, FaithState.active_tag(b)), "日神下蛮神赐福那一层休眠")
	t.check(not FaithState.is_inert(sb, FaithState.active_tag(b)), "但不是整件休眠")
	t.check(not FaithState.dormant_uids(b).has(sword.uid), "不在整件休眠的名单里（不压灰、生长照走）")
	var tag := &"faith:brute"
	var base_dmg := float(base.combat.base_stats.get("damage", 0.0))
	var spec := BattleCompiler.compile_board(b, null, [] as Array[StatModifier], [] as Array[AbilityRule], {tag: 4}, {tag: 9999})
	var got := StatMath.to_float(spec.stats_of(sword.uid).total_of(BattleStats.DAMAGE))
	t.check(absf(got - base_dmg) < 0.01, "异神下按原件算：伤害 %.2f（原件 %.2f），信力加成一点不进" % [got, base_dmg])
	b.select_faith(&"")
	spec = BattleCompiler.compile_board(b, null, [] as Array[StatModifier], [] as Array[AbilityRule], {tag: 4}, {tag: 9999})
	got = StatMath.to_float(spec.stats_of(sword.uid).total_of(BattleStats.DAMAGE))
	t.check(absf(got - base_dmg) < 0.01, "不奉神：也按原件算（%.2f）" % got)
	t.check(FaithState.dormant_uids(b).has(charm.uid), "护符（手写信仰道具）照旧整件休眠")

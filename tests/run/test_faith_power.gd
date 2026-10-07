## 信力（作者定，报告 082）：激活了一个信仰之后，完成它指定的行为（置入值钱的道具 / 打仗 / 走路 / 进账 / 花钱 / 搜索 / 事件里选特定选项）攒点数；
## 过了几道阈值就是第几阶，信仰道具上按阶写的功能（faith_bonuses）由编译器并入。每个信仰一个池子、只有激活的收点；跟着存档走。
## 期望从数据推：行为构件说给几点就断言几点；阈值表推阶；道具上的加成推编译结果。
extends RefCounted

const SAVE := "user://test_faith_power_run.json"


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
	for seed in range(1, 60):
		var s := RunState.start(chapter, seed, items, enemies, sets, [] as Array[StringName], {}, [] as Array[StringName], chars[0] if not chars.is_empty() else null)
		if s != null:
			s.faith_defs = FaithDef.load_all()
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


## 一件某信仰的道具（有的话）
static func _item_of_faith(db: ItemDatabase, fid: StringName) -> ItemDef:
	for id in db.ids():
		var d := db.get_def(id)
		if d.is_anchor() and FaithDef.id_of_tag(d.faith_tag()) == fid:     # 095：只有信物能激活
			return d
	return null


static func _expected_gain(def: FaithDef, event: StringName, payload: Dictionary) -> int:
	var n := 0
	for d in def.deeds:
		n += maxi(0, (d as FaithDeed).gain(event, payload))
	return n


static func run_defs_and_tiers(t: TestCase) -> void:
	t.begin("信力 · 信仰文件里有阈值与行为；阶从阈值推；导入器拦错的阈值 / 行为 / 加成")
	var defs := FaithDef.load_all()
	for id in defs:
		var def := defs[id] as FaithDef
		t.check(not def.deeds.is_empty(), "%s 列了攒信力的行为：%s" % [id, def.deeds_summary()])
		for i in range(1, def.thresholds.size()):
			t.check(def.thresholds[i] >= def.thresholds[i - 1], "%s 的阈值非递减" % id)
		t.eq(def.tier_of(0), 0, "%s：0 点第 0 阶" % id)
		if not def.thresholds.is_empty():
			t.eq(def.tier_of(def.thresholds[0]), 1, "%s：到第一道阈值第 1 阶" % id)
			t.eq(def.tier_of(def.thresholds[-1]), def.thresholds.size(), "%s：过了最后一道 = 阈值数" % id)
			t.eq(def.next_threshold(0), def.thresholds[0], "%s：下一道 = 第一道" % id)
			t.eq(def.next_threshold(def.thresholds[-1]), -1, "%s：都过了 = -1" % id)
	# 往返
	var sample := {"id": "probe", "display_name": "试", "thresholds": [2, 5], "deeds": [
		{"type": "battle", "amount": 1, "won_only": true}, {"type": "travel", "amount": 2, "every_steps": 3}, {"type": "event_choice", "amount": 1, "tag": "x"}]}
	var report := ImportReport.new()
	var def := ContentImporter.import_faith(sample, ContentImporter.Context.new(), report)
	t.check(report.ok(), "导入没有错：%s" % report.to_text())
	var text := ContentExporter.to_json(ContentExporter.export_faith(def))
	var back := ContentImporter.import_faith(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_faith(back)), text, "导出 → 导入 → 再导出逐字节相同")
	t.eq(back.deeds.size(), 3, "三个行为")
	t.eq(_expected_gain(back, &"travel", {"steps": 6}), 2, "走到第 6 步：每 3 步 +2")
	t.eq(_expected_gain(back, &"travel", {"steps": 7}), 0, "第 7 步不给")
	t.eq(_expected_gain(back, &"battle", {"won": false}), 0, "只算打赢的")
	t.eq(_expected_gain(back, &"event_choice", {"tags": ["x", "y"]}), 1, "选项带标签 x")
	t.eq(_expected_gain(back, &"event_choice", {"tags": ["y"]}), 0, "不带不给")
	for bad in [
		{"why": "阈值 0", "data": {"id": "p", "display_name": "p", "thresholds": [0]}},
		{"why": "阈值递减", "data": {"id": "p", "display_name": "p", "thresholds": [5, 2]}},
		{"why": "行为 0 点", "data": {"id": "p", "display_name": "p", "deeds": [{"type": "battle", "amount": 0}]}},
		{"why": "认不得的行为", "data": {"id": "p", "display_name": "p", "deeds": [{"type": "pray"}]}},
	]:
		var r := ImportReport.new()
		ContentImporter.import_faith(bad["data"], ContentImporter.Context.new(), r)
		t.check(not r.ok(), "拦下：%s" % bad["why"])
	var r2 := ImportReport.new()
	ContentImporter.import_item({"id": "p", "display_name": "p", "shape": ["1"], "tags": ["gear"], "faith_bonuses": [{"tier": 1, "mods": [{"stat": "armor", "flat": 1.0}]}]}, ContentImporter.Context.new(), r2)
	t.check(not r2.ok(), "拦下：无信仰之物不能有按信力解锁的功能")
	var r3 := ImportReport.new()
	ContentImporter.import_item({"id": "p", "display_name": "p", "shape": ["1"], "tags": ["faith", "faith:skill", "gear"], "faith_bonuses": [{"tier": 0, "mods": [{"stat": "armor", "flat": 1.0}]}]}, ContentImporter.Context.new(), r3)
	t.check(not r3.ok(), "拦下：阶 0")


static func run_credit(t: TestCase) -> void:
	t.begin("信力 · 没激活信仰不记；激活了只记它的池子；行为给几点就加几点；切换后各池各记；一局里的事真的接上了（置入、进账、花钱、走路、打仗、搜索、选项）")
	var db := _db()
	var s := _start(db)
	if s == null:
		t.check(false, "开不了局")
		return
	var defs := FaithDef.load_all()
	t.eq(s.faith_power.credit(&"battle", {"won": true}), 0, "没激活信仰：不记")
	t.eq(s.faith_power.line(), "", "HUD 没有信力那一句")
	# 找两件不同信仰的道具
	var a: ItemDef = null
	var b: ItemDef = null
	for id in defs:
		var d := _item_of_faith(db, id)
		if d == null:
			continue
		if a == null:
			a = d
		elif b == null and FaithDef.id_of_tag(d.faith_tag()) != FaithDef.id_of_tag(a.faith_tag()):
			b = d
	t.not_null(a, "至少一件信仰道具")
	t.not_null(b, "另一个信仰也有道具")
	if a == null or b == null:
		return
	var fa := FaithDef.id_of_tag(a.faith_tag())
	var fb := FaithDef.id_of_tag(b.faith_tag())
	var changes: Array = []
	s.faith_power.changed.connect(func(id: StringName, p: int, tier: int): changes.append([id, p, tier]))
	# 置入 a：激活 fa；置入本身也是一件事（value 按 ItemValue）
	var ia := ItemInstance.create(a, 0)
	s.storage.admit(ia)
	var before_place := _expected_gain(defs[fa], &"place_item", {"value": ItemValue.of(a), "id": String(a.id)})
	t.check(s.equip(ia.uid), "把 %s 放上棋盘" % a.id)
	t.eq(s.active_faith_id(), fa, "激活了 %s" % fa)
	# 注意：置入那一刻激活信仰已经是 fa（先放上再发 placed），所以置入 a 自己也按 fa 的行为记
	t.eq(s.faith_power.points_of(fa), before_place, "置入自己按 %s 的行为记 %d 点" % [fa, before_place])
	var events := [
		[&"battle", {"won": true}], [&"battle", {"won": false}], [&"travel", {"steps": 2}], [&"travel", {"steps": 3}],
		[&"earn_money", {"amount": 30}], [&"spend_money", {"amount": 40}], [&"explore", {}], [&"event_choice", {"tags": ["offering"]}],
	]
	var want := s.faith_power.points_of(fa)
	for ev in events:
		var gain := _expected_gain(defs[fa], ev[0], ev[1])
		t.eq(s.faith_power.credit(ev[0], ev[1]), gain, "%s：%s 给 %d" % [fa, ev[0], gain])
		want += gain
	t.eq(s.faith_power.points_of(fa), want, "累计 %d" % want)
	t.eq(s.faith_power.tier_of(fa), (defs[fa] as FaithDef).tier_of(want), "阶按阈值")
	t.eq(s.faith_power.points_of(fb), 0, "%s 的池子空着" % fb)
	if want > 0:
		t.check(not changes.is_empty() and changes[-1][0] == fa and int(changes[-1][1]) == want, "信号报了最新点数")
		t.check(s.faith_power.line().contains("Lv.%d" % s.faith_power.tier_of(fa)) and s.faith_power.line().contains("　%d" % want), "HUD 一句（093：「神 Lv.n　点 / 下一阈值」）：%s" % s.faith_power.line())
	# 切到 fb：fa 的池子留着
	var ib := ItemInstance.create(b, 0)
	s.storage.admit(ib)
	t.check(s.equip(ib.uid), "放上 %s" % b.id)
	t.eq(s.active_faith_id(), fb, "切到 %s" % fb)
	var kept := s.faith_power.points_of(fa)
	s.faith_power.credit(&"battle", {"won": true})
	t.eq(s.faith_power.points_of(fa), kept, "%s 的池子不动" % fa)
	t.eq(s.faith_power.points_of(fb), _expected_gain(defs[fb], &"place_item", {"value": ItemValue.of(b)}) + _expected_gain(defs[fb], &"battle", {"won": true}), "%s 自己记" % fb)

	# 接线：一局里的事真的进来了（每种事都按当时激活的信仰算期望）
	var p0 := s.faith_power.points_of(fb)
	s.wallet.earn(50, &"probe")
	p0 += _expected_gain(defs[fb], &"earn_money", {"amount": 50})
	t.eq(s.faith_power.points_of(fb), p0, "进账接上了")
	if s.wallet.spend(20, &"probe"):
		p0 += _expected_gain(defs[fb], &"spend_money", {"amount": 20})
	t.eq(s.faith_power.points_of(fb), p0, "花钱接上了")
	if s.phase == RunState.Phase.ON_MAP and not s.travel.available_moves().is_empty():
		var steps_after := s.travel.clock.total + 1
		var moves := s.travel.available_moves()
		s.step_to(moves[0])
		# 走一步可能顺带打仗 / 出事件；只验「走路」这一项至少记上了
		t.check(s.faith_power.points_of(fb) >= p0 + _expected_gain(defs[fb], &"travel", {"steps": steps_after}), "走路接上了")
	var opt := EventOption.new()
	opt.label = "试"
	opt.tags = [&"offering"] as Array[StringName]
	var p1 := s.faith_power.points_of(fb)
	s.events.option_chosen.emit(s.current_node(), opt)
	t.eq(s.faith_power.points_of(fb), p1 + _expected_gain(defs[fb], &"event_choice", {"tags": ["offering"]}), "事件选项接上了")


static func run_compiler_tiers(t: TestCase) -> void:
	t.begin("信力 · 编译器按阶并入信仰道具的功能：阶不够不并、够了并修饰与规则；一局里点数够了 compile_player 自动带上；存档")
	var db := _db()
	var with_bonus: ItemDef = null
	for id in db.ids():
		var d := db.get_def(id)
		if d.has_faith() and not d.faith_bonuses.is_empty() and d.combat != null:
			with_bonus = d
			break
	t.not_null(with_bonus, "作者数据里有带按阶功能的信仰道具")
	if with_bonus == null:
		return
	var tag := with_bonus.faith_tag()
	var board := GridInventory.new(Vector2i(8, 6), 1, true)
	# 铺几个包，长的短的都放得下
	for bag_id in [&"bag_long", &"bag_leather", &"bag_small"]:
		var bag := ItemInstance.create(db.get_def(bag_id), 0)
		board.try_add(bag, true)
	var inst := ItemInstance.create(with_bonus, 0)
	assert(board.try_add(inst, true), "放不下")
	var top := 0
	for b in with_bonus.faith_bonuses:
		top = maxi(top, (b as FaithBonus).tier)
	var base_spec := BattleCompiler.compile_board(board)
	for tier in range(0, top + 1):
		var spec := BattleCompiler.compile_board(board, null, [] as Array[StatModifier], [] as Array[AbilityRule], {tag: tier})
		# 期望：从道具的战斗定义起，把 tier ≤ 现在的加成的修饰逐个施加；规则数 = 自带 + 解锁的
		var want := StatSet.new()
		with_bonus.combat.seed_stats(want)
		var plain := StatSet.new()
		with_bonus.combat.seed_stats(plain)
		var rules := with_bonus.combat.rules.size()
		for b in with_bonus.faith_bonuses:
			var bonus := b as FaithBonus
			if bonus.tier > tier:
				continue
			for mod in bonus.mods:
				(mod as StatModifier).apply_to(want, 1)
			rules += bonus.rules.size()
		for key in want.keys():
			var delta := want.total_of(key) - plain.total_of(key)
			t.eq(spec.stats_of(inst.uid).total_of(key) - base_spec.stats_of(inst.uid).total_of(key), delta, "第 %d 阶：%s 比不带阶多 %d" % [tier, key, delta])
		t.eq(spec.item_of(inst.uid).rules.size(), rules, "第 %d 阶：规则 %d 条" % [tier, rules])
	# 一局里：点数够了自动带上
	var s := _start(db)
	if s == null:
		return
	var fid := FaithDef.id_of_tag(tag)
	var def: FaithDef = s.faith_defs[fid]
	var mine := ItemInstance.create(with_bonus, 0)
	s.storage.admit(mine)
	t.check(s.equip(mine.uid), "放上棋盘")
	var r0 := s.compile_player().item_of(mine.uid).rules.size()
	if not def.thresholds.is_empty():
		s.faith_power.points[String(fid)] = def.thresholds[-1]
		t.eq(s.faith_power.tiers().get(tag, 0), def.thresholds.size(), "tiers() 报最高阶")
		var r1 := s.compile_player().item_of(mine.uid).rules.size()
		var extra := 0
		for b in with_bonus.faith_bonuses:
			extra += (b as FaithBonus).rules.size()
		t.eq(r1, r0 + extra, "compile_player 带上了全部解锁的规则")
	# 存档
	var d := s.to_dict()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var back := RunState.from_dict(d, s.chapter, db, enemies)
	t.eq(back.faith_power.to_dict(), s.faith_power.to_dict(), "信力跟着存档")
	back.faith_defs = s.faith_defs
	t.eq(back.faith_power.tiers(), s.faith_power.tiers(), "读档后阶一样")

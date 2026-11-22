## 372 第一批：局内成长 —— 经验值（原信力）只涨不花、8 + n 的等级表、难度系数、打赢 / 更深一环 / 神坛祷告 / 献祭封顶、
## 每级三选一（同一局同一种子抽到的一样）、刷新 / 删除的次数来自局外科技、以人为本每 5 级多选一次、存档往返、点数里的成长分。
## 期望从数据推：等级表、来源点数都读 `base_rules/level`
extends RefCounted


static func _start(seed_from: int = 1, meta: Array[StringName] = [] as Array[StringName]) -> RunState:
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var chars := GameFlow.load_characters()
	for seed_ in range(seed_from, seed_from + 60):
		var s := RunState.start(chapter, seed_, items, enemies, sets, [] as Array[StringName], RunBuffs.load_all(), meta,
			chars[0] if not chars.is_empty() else null)
		if s != null:
			s.faith_defs = FaithDef.load_all()
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func run_table(t: TestCase) -> void:
	t.begin("372 · 等级表：从 n 级升 n+1 级要 8 + n；上限 30；难度系数 1 + 档 × 0.05")
	var r := LevelRules.load_rules()
	t.eq(r.level_cap, 30, "上限 30")
	t.eq(r.cost_at(1), r.cost_base + r.cost_step, "1 → 2 级")
	t.eq(r.total_for(1), 0, "1 级 = 0 点")
	t.eq(r.total_for(3), r.cost_at(1) + r.cost_at(2), "到 3 级累计")
	t.eq(r.level_of(r.total_for(2) - 0.5), 1, "差一点还是 1 级")
	t.eq(r.level_of(r.total_for(2)), 2, "够数就升")
	t.eq(r.level_of(1.0e9), r.level_cap, "封顶")
	t.check(is_equal_approx(r.mult(0), 1.0) and is_equal_approx(r.mult(12), 1.0 + 12.0 * r.difficulty_step), "A0 = 1、A12 = 1 + 12 档")
	var kinds := {}
	for cid in r.card_ids():
		kinds[r.kind_of(cid)] = true
	t.eq(r.card_ids().size(), 15, "牌池 15 张")
	t.eq(kinds.size(), 3, "三类都有")
	var buffs := RunBuffs.load_all()
	var missing: Array[String] = []
	for cid in r.card_ids():
		var def: RunBuffDef = buffs.get(cid, null)
		if def == null or not def.is_map():
			missing.append(String(cid))
	t.check(missing.is_empty(), "每张牌都是一局的 buff：%s" % ", ".join(missing))


static func run_sources(t: TestCase) -> void:
	t.begin("372 · 经验值来源：打赢按类别给、秒杀不给、神坛祷告每座三次、献祭每座封顶；越难涨得越快")
	var run := _start()
	if run == null:
		t.check(false, "开局")
		return
	var lv := LevelModule.of(run)
	t.not_null(lv, "标准模块里有等级")
	if lv == null:
		return
	var r := lv.rules()
	t.eq(lv.level(), 1, "开局 1 级")
	t.eq(lv.pending(), 0, "不欠选牌")
	var x0 := lv.xp
	run.events.last_battle = {"type": "elite"}
	lv._on_battle(null, null, true)
	t.check(is_equal_approx(lv.xp - x0, r.battle_xp(&"elite") * lv.mult()), "打赢精英给精英那一档")
	var x1 := lv.xp
	lv._on_battle(null, null, false)
	run.events.last_battle = {"type": "battle", "smite": true}
	lv._on_battle(null, null, true)
	t.check(is_equal_approx(lv.xp, x1), "输了、秒杀都不给")
	var node := run.current_node()
	t.eq(lv.prayers_left(node), r.prayers_per_altar, "一座神坛能祷告几次")
	var x2 := lv.xp
	for _i in r.prayers_per_altar + 1:
		lv.pray(node)
	t.check(is_equal_approx(lv.xp - x2, r.prayer * r.prayers_per_altar * lv.mult()), "超过次数不再给")
	t.eq(lv.prayers_left(node), 0, "用完了")
	t.eq(run.hooks.level_prayers_left(node), 0, "钩子读得到")
	var x3 := lv.xp
	lv.offer_at(node, r.offering_cap - 5)
	lv.offer_at(node, 100)
	t.check(is_equal_approx(lv.xp - x3, r.offering_cap * lv.mult()), "献祭每座封顶 %d" % r.offering_cap)
	var hard := _start()
	hard.difficulty = DifficultyDef.new()
	hard.difficulty.level = 12
	var hl := LevelModule.of(hard)
	var got := hl.gain(10.0, LevelModule.SRC_BATTLE)
	t.check(is_equal_approx(got, 10.0 * r.mult(12)), "A12 乘 %.2f" % r.mult(12))
	t.eq(String(hl.history[-1]["source"]), "battle", "记一笔来源")
	run.dispose()
	hard.dispose()


static func run_picks(t: TestCase) -> void:
	t.begin("372 · 每级三选一：同一种子抽到的一样；拿了的牌进 buff；欠几次选几次；以人为本逢 5 级多一次")
	var a := _start(7)
	var b := _start(7)
	var la := LevelModule.of(a)
	var lb := LevelModule.of(b)
	var r := la.rules()
	la.gain(float(r.total_for(2)), LevelModule.SRC_BATTLE)
	lb.gain(float(r.total_for(2)), LevelModule.SRC_BATTLE)
	t.eq(la.level(), 2, "升到 2 级")
	t.eq(la.pending(), 1, "欠一次")
	var offer := la.offer()
	t.eq(offer.size(), r.choices, "摆出三张")
	t.eq(offer, lb.offer(), "同一种子同一批")
	var uniq := {}
	for cid in offer:
		uniq[cid] = true
	t.eq(uniq.size(), offer.size(), "不重样")
	var picked := la.pick(0)
	t.eq(picked, offer[0], "拿第一张")
	t.eq(la.count_of(picked), 1, "记一张")
	t.eq(la.pending(), 0, "选完了")
	t.check(la.offer().is_empty(), "不欠就不摆")
	var row := r.card(picked)
	if String(row.get("echo", "")) == "" and String(row.get("oneshot", "")) == "":
		t.check(a.active_buff_defs().has(a.buff_defs[picked]), "拿到的牌进这一局的 buff")
	t.check(la.card_text(picked) != "", "牌面有一行效果")
	# 以人为本：没奉神，到 5 级多一次
	t.eq(a.active_faith_id(), &"", "没奉神")
	la.gain(float(r.total_for(5)), LevelModule.SRC_BATTLE)
	t.eq(la.bonus_picks, 1, "逢 5 级多一次")
	t.eq(la.pending(), 3 + 1, "2→5 级三次 + 多的一次")
	# 没有科技：刷新、删除都是 0
	t.eq(la.rerolls_left(), 0, "没科技不能刷新")
	t.check(not la.reroll(), "刷新不动")
	t.check(not la.remove(0), "删除不动")
	# 存档往返
	var d := la.to_dict()
	var c := LevelModule.new()
	c.restore(d)
	t.check(is_equal_approx(c.xp, la.xp) and c.picks_done == la.picks_done and c.bonus_picks == la.bonus_picks and c.count_of(picked) == 1, "存档往返")
	a.dispose()
	b.dispose()


static func run_reroll_remove(t: TestCase) -> void:
	t.begin("372 · 局外科技给刷新 / 删除次数：刷新三张一起换，删了的这一局不再出")
	var meta: Array[StringName] = [&"tech_level_reroll_1", &"tech_level_remove_1"]
	var run := _start(3, meta)
	var lv := LevelModule.of(run)
	if lv == null:
		t.check(false, "开局")
		return
	t.eq(lv.rerolls_left(), 1, "刷新 1 次")
	t.eq(lv.removals_left(), 1, "删除 1 次")
	lv.gain(float(lv.rules().total_for(3)), LevelModule.SRC_BATTLE)
	var before := lv.offer()
	t.check(lv.reroll(), "刷新")
	t.eq(lv.rerolls_left(), 0, "用掉了")
	t.eq(lv.offer().size(), before.size(), "还是三张")
	var gone := lv.offer()[1]
	t.check(lv.remove(1), "删第二张")
	t.check(not lv.offer().has(gone), "删掉的不在了")
	t.check(not lv.eligible(gone), "这一局不再出")
	t.eq(lv.removals_left(), 0, "删除用掉了")
	run.dispose()


static func run_echo(t: TestCase) -> void:
	t.begin("372 · 元素回响：本体一条战斗规则（每 8 秒）；「疾」每张减 1 秒、到下限不再出；「重」每张多 1 层")
	var run := _start()
	var lv := LevelModule.of(run)
	var r := lv.rules()
	t.check(lv.echo_def() == null, "没拿本体：没有规则")
	t.check(not lv.eligible(&"card_echo_faster"), "没拿本体：「疾」不进池")
	lv.taken[String(LevelModule.ECHO_BUFF)] = 1
	var def := lv.echo_def()
	t.not_null(def, "拿了本体：拼出一份 buff")
	if def != null:
		t.eq(def.rules.size(), 1, "一条规则")
		t.check(is_equal_approx((def.rules[0].cadence as CooldownCadence).seconds, float(r.echo_seconds)), "间隔 %d 秒" % r.echo_seconds)
	t.check(lv.defs().has(def), "进这一局的 buff")
	lv.taken["card_echo_faster"] = r.echo_seconds - r.echo_min_seconds
	t.eq(lv.echo_seconds(), r.echo_min_seconds, "减到下限")
	t.check(not lv.eligible(&"card_echo_faster"), "到下限不再出")
	lv.taken["card_echo_stacks"] = 2
	t.eq(lv.echo_stacks(), 3, "多两层")
	t.check(lv.card_text(&"card_element_echo").contains("3"), "牌面写现在的层数：%s" % lv.card_text(&"card_element_echo"))
	run.dispose()


static func run_score(t: TestCase) -> void:
	t.begin("372 · 等级进结算点数：每升一级给成长分；1 级不写账单行")
	var rules := ScoreRules.load_rules()
	t.check(rules.per_level > 0, "每级给分")
	t.eq(rules.growth_points(1), 0, "1 级 0 分")
	t.eq(rules.growth_points(4), 3 * rules.per_level, "4 级 = 3 份")


static func run_fixes_v773(t: TestCase) -> void:
	t.begin("372 复测（v7.73）：调息牌面写小数；以人为本只在多给的那一次提示；不奉神的老档迁移补上跨过的逢 5 级")
	var run := _start(11)
	var lv := LevelModule.of(run)
	t.check(lv.card_text(&"card_regen").contains("+0.3"), "调息写 +0.3：%s" % lv.card_text(&"card_regen"))
	t.check(lv.card_text(&"card_hp_flat").contains("+3") and not lv.card_text(&"card_hp_flat").contains("+3.0"), "整数照旧写整数：%s" % lv.card_text(&"card_hp_flat"))
	var r := lv.rules()
	lv.gain(float(r.total_for(11)), LevelModule.SRC_BATTLE)
	t.eq(lv.bonus_levels, [5, 10] as Array[int], "5、10 级各多一次")
	var seen: Array[String] = []
	while lv.pending() > 0:
		var cur := lv.current_pick()
		seen.append("%d%s" % [int(cur["level"]), "+" if bool(cur["extra"]) else ""])
		lv.pick(0)
	t.eq(seen, ["2", "3", "4", "5", "5+", "6", "7", "8", "9", "10", "10+", "11"] as Array[String], "按级排队，多给的那次紧跟在那一级后面")
	run.dispose()
	var xp := float(r.total_for(11)) + 1.0
	var v7 := {"version": 7, "chapter": "chapter_01", "faith_progress": {"brute": {"devotion": xp / RunMigrations.XP_PER_DEVOTION, "prayer": 0}}}
	var row: Dictionary = (RunMigrations.upgrade(v7)["modules"] as Dictionary)["level"]
	t.check(bool(row.get("backfill_bonus", false)), "迁移只标一句，装上时再按有效信仰补")
	# 补不补看装上那一刻的有效信仰（和升级时同一个判断）：不奉神 / 奉了但信物不在棋盘 → 补；信物在棋盘 → 不补
	for case in [["none", 2], ["missing", 2], ["active", 0]]:
		var host := _start(13)
		if String(case[0]) != "none":
			host.selected_faith = &"brute"
		if String(case[0]) == "active":
			for id in host.items.ids():
				var d := host.items.get_def(id)
				if d.is_anchor() and FaithTags.id_of_tag(d.faith_tag()) == &"brute":
					TestSupport.put(host.board, d)
					break
		var c := LevelModule.new()
		c.restore(row)
		c.install(host)
		t.eq(c.bonus_picks, int(case[1]), "迁移到 11 级（%s）：补 %d 次" % [case[0], case[1]])
		t.eq(c.pending(), 10 + int(case[1]), "迁移后欠 10 + %d 次（%s）" % [case[1], case[0]])
		c.install(host)
		t.eq(c.bonus_picks, int(case[1]), "再装一次不重复补（%s）" % case[0])
		host.dispose()

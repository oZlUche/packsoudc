## 372 第一批：局内成长 —— 经验值（原信力）只涨不花、8 + n 的等级表、难度系数、打赢 / 更深一环 / 神坛祷告 / 献祭封顶、
## 每级三选一（同一局同一种子抽到的一样）、刷新 / 删除的次数来自局外科技、388 质变位（开局、6 / 12 / … 级；无信者多选一张通用牌）、存档往返、点数里的成长分。
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
	t.eq(lv.pending(), 1 if lv.rules().qual_opening else 0, "388：开局只欠那一次质变位")
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
	t.begin("372 · 每级三选一：同一种子抽到的一样；拿了的牌进 buff；欠几次选几次；无信者逢 5 级多一次")
	var a := _start(7)
	var b := _start(7)
	var la := LevelModule.of(a)
	var lb := LevelModule.of(b)
	var r := la.rules()
	la.gain(float(r.total_for(2)), LevelModule.SRC_BATTLE)
	lb.gain(float(r.total_for(2)), LevelModule.SRC_BATTLE)
	t.eq(la.level(), 2, "升到 2 级")
	if r.qual_opening:     # 388：开局那一次质变位先选掉（无信者 = 多选一张通用牌）
		t.check(la.current_pick().get("qual", false) and la.current_pick().get("generic", false), "开局那一次排在最前，无信者是通用牌")
		la.offer()
		lb.offer()
		la.pick(0)
		lb.pick(0)
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
	t.check(la.count_of(picked) >= 1, "记下了")
	t.eq(la.pending(), 0, "选完了")
	t.check(la.offer().is_empty(), "不欠就不摆")
	var row := r.card(picked)
	if String(row.get("echo", "")) == "" and String(row.get("oneshot", "")) == "":
		t.check(a.active_buff_defs().has(a.buff_defs[picked]), "拿到的牌进这一局的 buff")
	t.check(la.card_text(picked) != "", "牌面有一行效果")
	# 388：质变位 6 级那一次（无信者多选一张通用牌）
	t.eq(a.active_faith_id(), &"", "没奉神")
	la.gain(float(r.total_for(6)), LevelModule.SRC_BATTLE)
	t.eq(la.pending(), 4 + 1, "2→6 级四次 + 6 级的质变位")
	# 没有科技：刷新、删除都是 0
	t.eq(la.rerolls_left(), 0, "没科技不能刷新")
	t.check(not la.reroll(), "刷新不动")
	t.check(not la.remove(0), "删除不动")
	# 存档往返
	var d := la.to_dict()
	var c := LevelModule.new()
	c.restore(d)
	t.check(is_equal_approx(c.xp, la.xp) and c.picks_done == la.picks_done and c.qual_done == la.qual_done and c.count_of(picked) == la.count_of(picked), "存档往返")
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
	if lv.current_pick().get("qual", false):
		lv.qual_done += 1     # 388：跳过开局那一次，下面看普通选牌
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
	t.begin("372 复测（v7.73）/ 388：调息牌面写小数；选牌按级排队，质变位（开局、6 级）排在那一级的普通牌后面；388 之前的档把无信者多给的那几次挪成用掉的质变位")
	var run := _start(11)
	var lv := LevelModule.of(run)
	t.check(lv.card_text(&"card_regen").contains("+0.3"), "调息写 +0.3：%s" % lv.card_text(&"card_regen"))
	t.check(lv.card_text(&"card_hp_flat").contains("+3") and not lv.card_text(&"card_hp_flat").contains("+3.0"), "整数照旧写整数：%s" % lv.card_text(&"card_hp_flat"))
	var r := lv.rules()
	lv.gain(float(r.total_for(13)), LevelModule.SRC_BATTLE)
	var seen: Array[String] = []
	while lv.pending() > 0:
		var cur := lv.current_pick()
		seen.append("%d%s" % [int(cur["level"]), "q" if bool(cur["qual"]) else ""])
		lv.offer()
		lv.pick(0)
	t.eq(seen, ["1q", "2", "3", "4", "5", "6", "6q", "7", "8", "9", "10", "11", "12", "12q", "13"] as Array[String], "按级排队：开局一次，6、12 级普通牌之后各一次质变位")
	run.dispose()
	# 老档：11 级、无信者多给过两次（5、10 级），picks_done 记的是 12
	var old := {"xp": float(r.total_for(11)) + 1.0, "picks_done": 12, "bonus_picks": 2, "bonus_levels": [5, 10]}
	var c := LevelModule.new()
	c.restore(old)
	t.eq([c.picks_done, c.qual_done], [10, 2], "挪成 10 次普通牌 + 2 个用掉的质变位")
	t.eq(c.pending(), 0, "11 级的质变位（开局、6 级）正好用完，不多欠")


static func frame_pick_cards(t: TestCase, root: Window) -> void:
	t.begin("372 选牌窗（v7.86 正式图）：每张牌的圆章里都有图标；英文大字号下类别条撑宽了也居中（复测 v7.90）")
	var run := _start(17)
	var lv := LevelModule.of(run)
	for cid in lv.rules().card_ids():
		t.check(LevelPickPanel._icon_of_def(run.buff_defs.get(cid, null)) != null, "%s 有图标" % cid)
	var keep_lang := UiText.lang
	var keep_scale := UiTheme.text_scale
	UiText.lang = "en"
	UiTheme.text_scale = 1.3
	lv.gain(float(lv.rules().total_for(4)), LevelModule.SRC_BATTLE)
	var panel := LevelPickPanel.new(lv)
	root.add_child(panel)
	for i in 3:
		var ribbon := panel.find_child("Card%d" % i, true, false).get_node("Ribbon") as Control
		ribbon.size = ribbon.get_combined_minimum_size()     # 进树后字宽才定：这里先撑一下（游戏里下一帧自己撑）
		t.check(absf(ribbon.position.x + ribbon.size.x * 0.5 - LevelPickPanel.CARD_W * 0.5) < 1.0, "第 %d 张的类别条居中（x %.1f，宽 %.1f）" % [i, ribbon.position.x, ribbon.size.x])
	panel.queue_free()
	UiText.lang = keep_lang
	UiTheme.text_scale = keep_scale
	run.dispose()

extends SceneTree
## 测试 v9.15（PR #987）无头：四位神按作者 11-26 牌表 —— 选牌流程与新牌效果
const G := preload("res://tests/run/test_god_cards_388.gd")
const T := preload("res://tests/battle/test_faith_skill.gd")
var pool: EnemyPool
var enemies: EnemyDatabase
var bad_total := 0

func _enemy(run: RunState, strength: int, seed_: int) -> CombatantSpec:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var node := MapNode.new(); node.id = 0; node.type = &"battle"
	for _t in 30:
		var entry := EnemyPlacer.pick(pool, enemies, node, strength, rng)
		if entry == null: continue
		var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, run.items, strength, rng).get("content", {})
		var e := EnemyKit.spec_of(content, enemies, pool, run.items)
		if e != null:
			e.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); e.max_hp = e.baseline.total_of(BattleStats.MAX_HP)
			return e
	return null


const REMOVED := ["god_nature_strong", "god_nature_talk_up"]

func _bad(msg: String) -> void:
	bad_total += 1
	print("GC987 不对：", msg)

## 一局从 0 级升到满级，每批随机挑（prefer 里的有就先挑）；记下摆出来的牌
func _pick_run(god: StringName, seed_: int, prefer: Array, tally: Dictionary) -> void:
	var run := G._start(seed_, god)
	var lv := LevelModule.of(run)
	var r := lv.rules()
	var rng := RandomNumberGenerator.new(); rng.seed = seed_ * 31 + 7
	lv.gain(1000000.0, LevelModule.SRC_EVENT, "test")
	var guard := 0
	while lv.pending() > 0 and guard < 200:
		guard += 1
		var cp := lv.current_pick()
		var cards := lv.offer()
		if cards.is_empty(): break
		if bool(cp.get("seed", false)):
			lv.pick(0); continue
		var qual := bool(cp.get("qual", false))
		tally["offers"] = int(tally.get("offers", 0)) + 1
		var has_fist := false
		for c in cards:
			var g := r.god_of(c)
			tally["seen:" + String(c)] = int(tally.get("seen:" + String(c), 0)) + 1
			if g != &"" and g != god: _bad("%s 局里出了 %s 的牌 %s" % [god, g, c])
			if String(c) in REMOVED: _bad("出了删掉的牌 %s" % c)
			if qual and not r.is_qual(c) and r.card(c).get("upgrade_of", "") == "" and r.god_of(c) != &"": _bad("质变位出了 %s" % c)
			if not qual and r.is_qual(c): _bad("普通位出了质变牌 %s" % c)
			if bool(r.card(c).get("once", false)) and lv.count_of(c) > 0: _bad("拿过的专属牌又出了 %s" % c)
			if String(c).begins_with("god_skill_fist_"):
				has_fist = true
				if lv.count_of(&"god_skill_fist") <= 0: _bad("没拿徒手大师就出了 %s" % c)
		if not qual and lv.count_of(&"god_skill_fist") > 0:
			tally["fist_offers"] = int(tally.get("fist_offers", 0)) + 1
			if not has_fist: _bad("拿了徒手大师，这一批没有拳头牌 %s" % str(cards))
		var idx := rng.randi() % cards.size()
		for i in cards.size():
			if String(cards[i]) in prefer: idx = i; break
		var got := lv.pick(idx)
		tally["took:" + String(got)] = int(tally.get("took:" + String(got), 0)) + 1
	for k in lv.taken:
		var row: Dictionary = r.card(StringName(k))
		if bool(row.get("once", false)) and int(lv.taken[k]) > 1: _bad("专属牌 %s 拿了 %d 次" % [k, lv.taken[k]])
		if int(row.get("max", 0)) > 0 and int(lv.taken[k]) > int(row["max"]): _bad("%s 超过 %d 张" % [k, row["max"]])
	if lv.count_of(&"god_skill_fist_flow") > 0: tally["flow_max"] = maxi(int(tally.get("flow_max", 0)), lv.count_of(&"god_skill_fist_flow"))
	tally["runs"] = int(tally.get("runs", 0)) + 1
	run.dispose()

func _picks() -> void:
	var excl := {"brute": ["god_brute_linger", "god_brute_persist", "god_brute_laurel"], "sun": ["god_sun_dawnlight", "god_sun_dusklight", "god_sun_stars"],
		"nature": ["god_nature_survive", "god_nature_talk"], "skill": ["god_skill_breath", "god_skill_vigor", "god_skill_finish"]}
	for god in ["brute", "sun", "nature", "skill"]:
		var tally := {}
		for s in 30: _pick_run(StringName(god), 900 + s, [], tally)
		var parts := []
		for c in excl[god]: parts.append("%s 出现 %d 次 / 拿 %d 局" % [c, int(tally.get("seen:" + c, 0)), int(tally.get("took:" + c, 0))])
		print("GC987 选牌 %s：30 局 %d 批；%s" % [god, int(tally.get("offers", 0)), "；".join(parts)])
	# 技巧之神：有徒手大师就先挑，有拳头牌就先挑
	var t2 := {}
	for s in 30: _pick_run(&"skill", 950 + s, ["god_skill_fist", "god_skill_fist_flow", "god_skill_fist_edge", "god_skill_fist_shadow", "god_skill_fist_intent"], t2)
	var fparts := []
	for c in ["god_skill_fist", "god_skill_fist_edge", "god_skill_fist_shadow", "god_skill_fist_flow", "god_skill_fist_intent"]:
		fparts.append("%s 拿 %d 次" % [c, int(t2.get("took:" + c, 0))])
	print("GC987 选牌 技巧之神（先挑拳头）：30 局，拿了徒手大师以后的普通批 %d 批，每批都有拳头牌（不对的另列）；拳势最多拿到 %d 张；%s" % [int(t2.get("fist_offers", 0)), int(t2.get("flow_max", 0)), "；".join(fparts)])

func _texts() -> void:
	var run := G._start(5, &"skill")
	var lv := LevelModule.of(run)
	var ids := ["god_brute_linger", "god_brute_persist", "god_brute_laurel", "god_sun_dawnlight", "god_sun_dusklight", "god_sun_stars", "god_sun_humble",
		"god_nature_survive", "god_nature_talk", "god_nature_guard_up", "god_nature_decay_up", "god_skill_breath", "god_skill_vigor", "god_skill_finish",
		"god_skill_fist_edge", "god_skill_fist_shadow", "god_skill_fist_flow", "god_skill_fist_intent", "god_skill_clumsy_up", "god_skill_stream"]
	for lang in ["zh", "en"]:
		UiText.lang = lang
		for c in ids:
			var name := lv.card_def(StringName(c)).display_name if lv.card_def(StringName(c)) != null else "?"
			if lang == "en" and lv.card_def(StringName(c)) != null: name = String(lv.card_def(StringName(c)).display_names.get("en", "?"))
			var txt := lv.card_text(StringName(c))
			if txt == "" or txt.contains("{") or txt.contains("gcard."): _bad("牌面 %s %s：%s" % [lang, c, txt])
			print("GC987 牌面 %s %s【%s】%s" % [lang, c, name, txt])
	UiText.lang = "zh"
	run.dispose()

func _setup(god: StringName, cards: Dictionary, items: Array) -> RunState:
	var run := G._start(77, god)
	var lv := LevelModule.of(run)
	for b in [&"war_pack", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(b))
	for id in items: TestSupport.put(run.board, run.items.get_def(StringName(id)))
	for k in cards: lv.taken[k] = cards[k]
	return run

func _fight(run: RunState, seed_: int, secs: float = 30.0, hp: float = 5000.0) -> BattleResult:
	var me := run.compile_player()
	me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(hp)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	return BattleSim.run(me, _enemy(run, 2, seed_), rng, secs)

func _mech(br: BattleResult, key: String) -> int:
	var n := 0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("key", "")) == key: n += 1
	return n

func _pure_hits(br: BattleResult) -> int:
	var n := 0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and bool(e.payload.get("pure", false)): n += 1
	return n

func _effects() -> void:
	# 众星：真打一场，按换边次数点亮，结算换钱，战败也进局外
	for s in [1, 2]:
		var run := _setup(&"sun", {"god_sun_stars": 1}, ["knife", "knight_plate"])
		var lv := LevelModule.of(run)
		var br := _fight(run, s)
		var shifts := _mech(br, "sun_window")
		lv._on_battle(null, br, true)
		var br2 := _fight(run, s + 10)
		var shifts2 := _mech(br2, "sun_window")
		lv._on_battle(null, br2, false)
		var stars := int(lv.god_state.get(SunCyclePerk.STARS_KEY, 0))
		var res := RunResult.estimate(run, false)
		var meta := MetaState.new()
		var f0 := meta.funds
		meta.absorb(res)
		print("GC987 众星 种子 %d：两场换边 %d + %d 次，星辰 %d 颗；战败结算 star_funds %d、局外钱 %d → %d" % [s, shifts, shifts2, stars, res.star_funds, f0, meta.funds])
		if stars != shifts + shifts2 or res.star_funds != stars * 2 or meta.funds - f0 < stars * 2: _bad("众星对不上")
		run.dispose()
	# 没拿众星：不记
	var run0 := _setup(&"sun", {}, ["knife", "knight_plate"])
	var lv0 := LevelModule.of(run0)
	lv0._on_battle(null, _fight(run0, 1), true)
	print("GC987 众星 没拿：星辰 %d，star_funds %d" % [int(lv0.god_state.get(SunCyclePerk.STARS_KEY, 0)), RunResult.estimate(run0, false).star_funds])
	run0.dispose()
	# 血色桂冠：赢 6 场、输 1 场
	var runb := _setup(&"brute", {"god_brute_laurel": 1}, ["knife", "knight_plate"])
	var lvb := LevelModule.of(runb)
	var m0 := runb.compile_player()
	var hp0 := StatMath.to_float(m0.baseline.total_of(BattleStats.MAX_HP)); var st0 := StatMath.to_float(m0.baseline.total_of(BattleStats.MAX_STAMINA))
	var picks := []
	for i in 6:
		lvb._on_battle(null, BattleResult.new(), true)
	lvb._on_battle(null, BattleResult.new(), false)
	var m1 := runb.compile_player()
	var hp1 := StatMath.to_float(m1.baseline.total_of(BattleStats.MAX_HP)); var st1 := StatMath.to_float(m1.baseline.total_of(BattleStats.MAX_STAMINA))
	var bhp := float(runb.player_baseline.base_stats.get(BattleStats.MAX_HP, 0.0)); var bst := float(runb.player_baseline.base_stats.get(BattleStats.MAX_STAMINA, 0.0))
	print("GC987 血色桂冠：赢 6 场、输 1 场 → 记了 %d 笔；生命上限 %.1f → %.1f（基础 %.0f），耐力上限 %.1f → %.1f（基础 %.0f）" % [int(lvb.god_state.get("brute_laurel_n", 0)), hp0, hp1, bhp, st0, st1, bst])
	var k_hp := roundi((hp1 - hp0) / (bhp * 0.1)) if bhp > 0 else -1
	var k_st := roundi((st1 - st0) / (bst * 0.1)) if bst > 0 else -1
	if int(lvb.god_state.get("brute_laurel_n", 0)) != 6 or k_hp + k_st != 6: _bad("血色桂冠：生命 %d 笔 + 耐力 %d 笔 ≠ 6" % [k_hp, k_st])
	print("GC987 血色桂冠：生命 %d 笔、耐力 %d 笔" % [k_hp, k_st])
	runb.dispose()
	# 收式：大巧若拙 + 收式，对比只有大巧若拙（真实开局、小刀两把，不怎么断连击）
	for s in [1, 2]:
		var a := _setup(&"skill", {"god_skill_clumsy": 1}, ["knife", "knife", "knight_plate"])
		var ba := _fight(a, s, 40.0); a.dispose()
		var b := _setup(&"skill", {"god_skill_clumsy": 1, "god_skill_finish": 1}, ["knife", "knife", "knight_plate"])
		var bb := _fight(b, s, 40.0); b.dispose()
		print("GC987 收式 种子 %d（40 秒）：只有大巧若拙 真清零 %d、真实伤害 %d 下；加收式 真清零 %d、真实伤害 %d 下，最高连击 %d / %d" % [s, _mech(ba, "skill_reset"), _pure_hits(ba), _mech(bb, "skill_reset"), _pure_hits(bb), int(T._combo(ba)[0]), int(T._combo(bb)[0])])
		if _pure_hits(bb) - _pure_hits(ba) < 3: _bad("收式没多打")
	# 大巧若拙升级：重武器耐力不够时
	for s in [1, 2]:
		var c := _setup(&"skill", {"god_skill_clumsy": 1, "god_skill_clumsy_up": 1}, ["steel_greatsword", "spiked_club", "knife", "knight_plate"])
		var bc := _fight(c, s, 40.0); c.dispose()
		var free := 0
		for raw in bc.log:
			var e := raw as BattleEvent
			if e.name == BattleEvent.ITEM_FIRED and e.side == 0 and bool(e.payload.get("free", false)): free += 1
		print("GC987 大巧若拙（升级）种子 %d：真清零 %d 次，补打 %d 次，不耗耐力的出手 %d 次" % [s, _mech(bc, "skill_reset"), _mech(bc, "skill_refire"), free])
		if _mech(bc, "skill_refire") != _mech(bc, "skill_reset"): _bad("补打次数和清零次数不一样")
	# 流水：跟着连击走
	for s in [1, 2]:
		var d := _setup(&"skill", {"god_skill_stream": 1}, ["steel_greatsword", "knife", "knife", "knight_plate"])
		var bd := _fight(d, s, 40.0); d.dispose()
		var cur := {}; var mism := 0; var checks := 0; var top := 0; var drops := 0
		for raw in bd.log:
			var e := raw as BattleEvent
			if e.side != 0: continue
			if e.name == BattleEvent.STATUS_STACKED or e.name == BattleEvent.STATUS_UNSTACKED:
				var bid := e.get_name(&"buff")
				if bid == SkillMomentum.FLOW_ID and e.name == BattleEvent.STATUS_UNSTACKED: drops += 1
				cur[bid] = e.get_int(&"stacks")
			if e.name == BattleEvent.ITEM_FIRED:
				checks += 1
				var c := int(cur.get(SkillMomentum.BUFF_ID, 0)); var fl := int(cur.get(SkillMomentum.FLOW_ID, 0))
				top = maxi(top, fl)
				if c != fl: mism += 1
		print("GC987 流水 种子 %d：真清零 %d 次，流水被清 %d 次；出手 %d 次时对照，流水层数 ≠ 连击层数 %d 次；流水最高 %d 层" % [s, _mech(bd, "skill_reset"), drops, checks, mism, top])
		if mism > 0 or (_mech(bd, "skill_reset") > 0 and drops == 0): _bad("流水没跟着连击")
	# 拳头：没武器，拳锋 2、拳影 1、拳势 5、拳意 1
	var f := _setup(&"skill", {"god_skill_fist": 1, "god_skill_fist_edge": 2, "god_skill_fist_shadow": 1, "god_skill_fist_flow": 5, "god_skill_fist_intent": 1}, ["knight_plate"])
	var bf := _fight(f, 3, 20.0)
	var fired := 0
	for raw in bf.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0: fired += 1
	var cb: Array = T._combo(bf)
	print("GC987 拳头（拳锋 2、拳影、拳势 5、拳意）：20 秒出手 %d 次（约每秒 %.2f 下），最高连击 %d，真清零 %d" % [fired, fired / 20.0, int(cb[0]), _mech(bf, "skill_reset")])
	f.dispose()

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	_picks()
	_texts()
	_effects()
	print("GC987 合计不对 %d 处" % bad_total)
	print("GC987 完")
	quit(0)

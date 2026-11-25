extends SceneTree
## 测试 v8.82（PR #953）无头：技巧之神【连击】在模拟战斗里叠层、清零；流水 / 蓄势 / 行云三个新状态；技巧之神在万神院关着
var FOE := &"knife"
var STA := 0.0     # 我方耐力上限覆盖（0 = 不改）
const G := preload("res://tests/run/test_god_cards_388.gd")
const T := preload("res://tests/battle/test_faith_skill.gd")

func _foe(items: ItemDatabase) -> CombatantSpec:
	var board := GridInventory.new(Vector2i(6, 6))
	TestSupport.put(board, items.get_def(FOE))
	var foe := BattleCompiler.compile(board, CompileInput.new())
	foe.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); foe.max_hp = foe.baseline.total_of(BattleStats.MAX_HP)
	return foe

func _sim(label: String, cards: Dictionary, weapons: Array = [&"knife"], secs: float = 20.0) -> void:
	var run := G._start(53, &"skill")
	var lv := LevelModule.of(run)
	for w in weapons: TestSupport.put(run.board, run.items.get_def(w))
	for k in cards: lv.taken[k] = cards[k]
	var me := run.compile_player()
	me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(5000.0)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
	if STA > 0.0:
		me.baseline.set_base(BattleStats.MAX_STAMINA, StatMath.from_float(STA))
		if "max_stamina" in me: me.max_stamina = me.baseline.total_of(BattleStats.MAX_STAMINA)
	_run_an(label, me, _foe(run.items), secs)
	run.dispose()

func _run_an(label: String, me: CombatantSpec, foe: CombatantSpec, secs: float = 20.0) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 953
	var br := BattleSim.run(me, foe, rng, secs)
	var mx := {}; var last := {}; var ups := {}; var downs := {}; var resets := []; var fired := 0; var skipped := 0
	var first := []; var dmg := {}; var crit := 0
	for e in br.log:
		var t := StatMath.to_float(e.time) if "time" in e else 0.0
		if e.side != 0 and e.name != BattleEvent.DAMAGE: continue
		if e.name == BattleEvent.ITEM_FIRED: fired += 1
		if e.name == BattleEvent.ITEM_SKIPPED: skipped += 1
		if e.name == BattleEvent.STATUS_STACKED or e.name == BattleEvent.STATUS_UNSTACKED:
			var b := String(e.payload.get("buff", ""))
			if not b.begins_with("skill_"): continue
			var s := e.get_int(&"stacks")
			mx[b] = maxi(int(mx.get(b, 0)), s)
			if e.name == BattleEvent.STATUS_STACKED and e.get_int(&"delta") > 0: ups[b] = int(ups.get(b, 0)) + 1
			else:
				downs[b] = int(downs.get(b, 0)) + 1
				if b == "skill_momentum" and resets.size() < 4: resets.append("%.1fs %d→%d" % [t, int(last.get(b, 0)), s])
			if b == "skill_momentum" and first.size() < 6: first.append("%.1fs=%d" % [t, s])
			last[b] = s
		if e.name == BattleEvent.DAMAGE and e.side == 1:
			var k := "%.1f" % StatMath.to_float(e.get_int(&"amount"))
			dmg[k] = int(dmg.get(k, 0)) + 1
			if bool(e.payload.get("crit", false)): crit += 1
	var top := dmg.keys(); top.sort_custom(func(a, b): return int(dmg[a]) > int(dmg[b]))
	print("SK953 %s：出手 %d、耐力不够跳过 %d；连击前几次 %s；清零 %s；各状态 最多 %s / 加 %s / 减 %s；我打出的伤害（多→少前 5）%s；暴击 %d" % [label, fired, skipped, str(first), str(resets), str(mx), str(ups), str(downs), str(top.slice(0, 5).map(func(k): return "%s×%d" % [k, dmg[k]])), crit])

func _init() -> void:
	# 关着：万神院
	var m := MetaState.new()
	print("SK953 万神院：skill temple_ready=%s；god_open=%s（解锁列表里塞进 skill 也一样：%s）；能不能解锁 %s" % [str(Pantheon.temple_ready(&"skill")), str(Pantheon.god_open(m, &"skill")), str((func(): m.temples.append(&"skill"); return Pantheon.god_open(m, &"skill")).call()), str(Pantheon.can_unlock(m, &"skill"))])
	_sim("只有核心，小刀", {})
	_sim("只有核心，小刀，打 40 秒（耐力耗尽）", {}, [&"knife"], 40.0)
	# 用套件里的两件试验武器（10 伤害，1.0 / 1.3 秒，每下 40 耐力），看清零
	_run_an("试验武器每下 40 耐力：只有核心", T._me({}, 40.0), T._dummy())
	_run_an("同上 + 稳手（留 2 层）", T._me({"keep_on_reset": 2}, 40.0), T._dummy())
	_run_an("同上 + 流水（每层 0.5%）", T._me({"flow_per": 0.5}, 40.0), T._dummy())
	_run_an("同上 + 残心 1 件 + 大巧若拙 50%", T._me({"zanshin": 1, "clumsy_pct": 50.0}, 40.0), T._dummy())
	_run_an("试验武器每下 8 耐力：只有核心", T._me({}, 8.0), T._dummy())
	_run_an("同上 + 行云（10 层起 -5%）", T._me({"light_pct": 5.0}, 8.0), T._dummy())
	_sim("蓄势", {"god_skill_poise": 1})
	_sim("锋芒升级", {"god_skill_edge": 1, "god_skill_edge_up": 1})
	_sim("预备", {"god_skill_ready": 1})
	_sim("徒手大师（没武器）", {"god_skill_fist": 1}, [])
	# 牌面
	var run := G._start(53, &"skill")
	var lv := LevelModule.of(run)
	for cid in ["god_skill_stream", "god_skill_poise", "god_skill_cloud", "god_skill_steady", "god_skill_zanshin", "god_skill_see"]:
		var d = run.buff_defs.get(StringName(cid))
		print("SK953 牌面 %s【%s】：%s" % [cid, d.display_name if d != null else "?", lv.card_text(StringName(cid))])
	UiText.lang = "en"
	for cid in ["god_skill_stream", "god_skill_poise", "god_skill_cloud", "god_brute_cornered_more"]:
		print("SK953 en %s：%s" % [cid, lv.card_text(StringName(cid))])
	run.dispose()
	print("SK953 完")
	quit(0)

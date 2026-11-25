extends SceneTree
## 测试 v8.76（PR #947）无头：蛮神怒气、困兽、怒意延绵在模拟战斗里；献祭进池与效果
var FOE := &"iron_spear"
const G := preload("res://tests/run/test_god_cards_388.gd")

func _foe(items: ItemDatabase) -> CombatantSpec:
	var board := GridInventory.new(Vector2i(6, 6))
	TestSupport.put(board, items.get_def(FOE))
	var foe := BattleCompiler.compile(board, CompileInput.new())
	foe.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); foe.max_hp = foe.baseline.total_of(BattleStats.MAX_HP)
	return foe

func _sim(label: String, cards: Dictionary, secs: float = 20.0) -> void:
	var run := G._start(47, &"brute")
	var lv := LevelModule.of(run)
	TestSupport.put(run.board, run.items.get_def(&"knife"))
	for k in cards: lv.taken[k] = cards[k]
	var me := run.compile_player()
	var foe := _foe(run.items)
	var rng := RandomNumberGenerator.new(); rng.seed = 947
	var br := BattleSim.run(me, foe, rng, secs)
	var hpmax := StatMath.to_float(me.max_hp)
	var hp := hpmax
	var rage_max := 0; var rage_sum := 0.0; var samples := 0; var corn_ok := 0; var corn_bad := []; var corn_max := 0
	var dmg := {}; var t_end := 0.0; var rage_at := []; var corn_down := 0; var corn_up := 0
	for e in br.log:
		var t := StatMath.to_float(e.time) if "time" in e else 0.0
		t_end = t
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			hp -= StatMath.to_float(e.get_int(&"amount"))
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0:
			var b := String(e.payload.get("buff", ""))
			var s := e.get_int(&"stacks")
			if b == "brute_rage":
				rage_max = maxi(rage_max, s); rage_sum += s; samples += 1
				if rage_at.size() < 10: rage_at.append("%.1fs=%d" % [t, s])
			if b == "brute_cornered":
				if e.get_int(&"delta") > 0: corn_up += 1
				corn_max = maxi(corn_max, s)
				var want := int(floor((hpmax - hp) * 100.0 / hpmax))
				if absi(want - s) <= 1: corn_ok += 1
				elif corn_bad.size() < 3: corn_bad.append("%.1fs 层 %d 失血 %.1f%%" % [t, s, (hpmax - hp) * 100.0 / hpmax])
		if e.name == BattleEvent.STATUS_UNSTACKED and e.side == 0 and String(e.payload.get("buff", "")) == "brute_cornered": corn_down += 1
		if e.name == BattleEvent.DAMAGE and e.side == 1:
			var k := "%.1f" % StatMath.to_float(e.get_int(&"amount"))
			dmg[k] = int(dmg.get(k, 0)) + 1
	print("GB947 %s：我方生命上限 %.0f，%.1f 秒（%s）；怒气最多 %d 层、样本均 %.1f；怒气前几次 %s；困兽最多 %d 层，和失血%%对得上 %d 次，对不上 %s，加层 %d 次、减层 %d 次；我打出的伤害分布 %s" % [label, hpmax, t_end, "我方倒下" if hp <= 0 else "打满", rage_max, rage_sum / maxf(1, samples), str(rage_at), corn_max, corn_ok, str(corn_bad), corn_up, corn_down, str(dmg)])
	run.dispose()

func _init() -> void:
	_sim("对两把铁矛：只有核心", {})
	FOE = &"knife"
	_sim("只有核心", {})
	_sim("急躁×2", {"god_brute_damage": 2})
	_sim("困兽", {"god_brute_cornered": 1})
	_sim("困兽+犹斗×2", {"god_brute_cornered": 1, "god_brute_cornered_more": 2})
	_sim("怒意延绵", {"god_brute_persist": 1})
	_sim("痛觉残留", {"god_brute_pain": 1})
	# 献祭
	var seen := 0; var offers := 0; var after := []
	for s in 30:
		var run := G._start(300 + s * 7, &"brute")
		if run == null: continue
		var lv := LevelModule.of(run)
		TestSupport.put(run.board, run.items.get_def(&"knife"))
		run.vitality.set_max(10, &"test"); run.vitality.current = 10
		lv.gain(float(lv.rules().total_for(12)), LevelModule.SRC_BATTLE)
		var g := 0
		while lv.pending() > 0 and g < 40:
			g += 1
			var o := lv.offer(); if o.is_empty(): break
			offers += 1
			var at := 0
			for i in o.size():
				if o[i] == &"god_brute_sacrifice": at = i; seen += 1
			var v0 := run.vitality.current; var due0 := lv.sacrifice_due(); var p0 := lv.pending()
			var cid := lv.pick(at)
			if cid == &"god_brute_sacrifice" and after.size() < 5:
				var cur := lv.current_pick()
				after.append("体力 %d→%d，欠质变 %d→%d，欠选 %d→%d，下一张 %s" % [v0, run.vitality.current, due0, lv.sacrifice_due(), p0, lv.pending(), str(cur)])
		run.dispose()
	print("GB947 献祭：30 局、摆出 %d 批里出现 %d 次；拿了以后 %s" % [offers, seen, str(after)])
	var run2 := G._start(999, &"brute")
	var lv2 := LevelModule.of(run2)
	run2.vitality.set_max(10, &"test")
	for v in [1, 2, 3]:
		run2.vitality.current = v
		print("GB947 献祭 体力 %d：进池 %s" % [v, str(lv2.eligible(&"god_brute_sacrifice"))])
	for lang in ["zh", "en"]:
		UiText.lang = lang
		var o := []
		for cid in ["god_brute_sacrifice", "god_brute_persist", "god_brute_cornered", "god_brute_cornered_up", "god_brute_cornered_more", "god_brute_break", "god_brute_break_up", "god_brute_duration", "god_brute_damage", "god_brute_regen", "god_brute_irate", "god_brute_pain", "god_brute_blood"]:
			o.append("%s「%s」" % [Names.of(run2.buff_defs[StringName(cid)]) if run2.buff_defs.has(StringName(cid)) else cid, lv2.card_text(StringName(cid))])
		print("GB947 牌面 %s：%s" % [lang, "；".join(o)])
	UiText.lang = "zh"
	run2.dispose()
	quit(0)

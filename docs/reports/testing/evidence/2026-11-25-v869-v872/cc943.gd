extends SceneTree
## 测试 v8.72（PR #943）无头：【精准】【狠辣】进不进牌池、出现频率、可重复拿、数值叠加；【熟练】改名；名字不和轴状态撞
const L372 := preload("res://tests/run/test_level_372.gd")
func _init() -> void:
	var seen := {}; var runs := 0; var taken_tot := {}
	var last_run: RunState = null
	for s in 20:
		var run := L372._start(100 + s * 61)
		if run == null: continue
		runs += 1
		var lv := LevelModule.of(run)
		TestSupport.put(run.board, run.items.get_def(&"iron_spear"))
		var spec0 := run.compile_player()
		var w0: Array = spec0.items.filter(func(it: CompiledItem) -> bool: return it.tags.has(&"weapon"))
		lv.gain(99999.0, LevelModule.SRC_BATTLE)
		var guard := 0
		while lv.pending() > 0 and guard < 60:
			guard += 1
			var o := lv.offer()
			if o.is_empty(): break
			var at := 0
			for i in o.size():
				seen[String(o[i])] = int(seen.get(String(o[i]), 0)) + 1
				if o[i] in [&"card_crit_chance", &"card_crit_damage"]: at = i
			lv.pick(at)
		for k in [&"card_crit_chance", &"card_crit_damage", &"card_weapon_cost"]: taken_tot[String(k)] = int(taken_tot.get(String(k), 0)) + lv.count_of(k)
		var spec := run.compile_player()
		var w: Array = spec.items.filter(func(it: CompiledItem) -> bool: return it.tags.has(&"weapon"))
		if s < 4 and not w.is_empty():
			var a: CompiledItem = w0[0]; var b: CompiledItem = w[0]
			print("CC943 种子 %d：%d 级，精准 %d 张、狠辣 %d 张；武器 %s 暴击率 %.3f → %.3f（应 +%.2f），暴伤 %.2f → %.2f（应 +%.2f）；状态界面暴击率 %s 暴伤 %s" % [100 + s * 61, lv.level(), lv.count_of(&"card_crit_chance"), lv.count_of(&"card_crit_damage"), String(b.id) if "id" in b else "?",
				StatMath.to_float(a.stats.total_of(BattleStats.CRIT_CHANCE)), StatMath.to_float(b.stats.total_of(BattleStats.CRIT_CHANCE)), 0.02 * lv.count_of(&"card_crit_chance"),
				StatMath.to_float(a.stats.total_of(BattleStats.CRIT_DAMAGE)), StatMath.to_float(b.stats.total_of(BattleStats.CRIT_DAMAGE)), 0.1 * lv.count_of(&"card_crit_damage"),
				str(CharacterCard.stat_row(run, &"crit_chance")), str(CharacterCard.stat_row(run, &"crit_damage"))])
		last_run = run
	print("CC943 %d 局、每局优先挑这两张：摆出次数 精准 %d、狠辣 %d、熟练 %d；拿到合计 %s" % [runs, int(seen.get("card_crit_chance", 0)), int(seen.get("card_crit_damage", 0)), int(seen.get("card_weapon_cost", 0)), str(taken_tot)])
	var lv := LevelModule.of(last_run)
	for lang in ["zh", "en"]:
		UiText.lang = lang
		print("CC943 %s：%s「%s」；%s「%s」；%s「%s」" % [lang, Names.of(last_run.buff_defs[&"card_crit_chance"]), lv.card_text(&"card_crit_chance"), Names.of(last_run.buff_defs[&"card_crit_damage"]), lv.card_text(&"card_crit_damage"), Names.of(last_run.buff_defs[&"card_weapon_cost"]), lv.card_text(&"card_weapon_cost")])
	UiText.lang = "zh"
	quit(0)

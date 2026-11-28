extends SceneTree
## v9.58（PR #1036）蛮神质变牌【竭力】：耐力不够时改扣等量生命。真走 RunState 编译（30 级附近的牌之外只加这一张），对 5 万血木桩打 30 秒
const G := preload("res://tests/run/test_god_cards_388.gd")
var bad := 0

func ok(c: bool, msg: String) -> void:
	print("EX1036 %s %s" % ["OK " if c else "BAD", msg])
	if not c: bad += 1

func _count(res: BattleResult) -> Dictionary:
	var out := {"fired": 0, "exert": 0, "exert_hp": 0, "min_hp": 1e9, "stamina_cost": 0, "rage": 0}
	for raw in res.log:
		var e := raw as BattleEvent
		if e.side != 0: continue
		if e.name == BattleEvent.ITEM_FIRED: out["fired"] += 1
		elif e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("key", "")) == BruteRage.EXERT_KEY:
			out["exert"] += 1; out["exert_hp"] += int(e.payload.get("count", 0))
		elif e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("key", "")) == "faith_mechanic":
			pass
		elif e.name == BattleEvent.RESOURCE_CHANGED:
			var k := String(e.payload.get("key", ""))
			if k == "hp": out["min_hp"] = minf(out["min_hp"], StatMath.to_float(e.get_int(&"current")))
			if k == "stamina" and String(e.get_name(&"reason")) == String(BattleEvent.REASON_COST): out["stamina_cost"] += 1
	return out

func _fight(run: RunState, secs: float) -> Array:
	var me := run.compile_player()
	var dummy := BattleCompiler.compile_board(GridInventory.new(Vector2i(4, 4), 1, false), CombatantBaseline.with_hp(50000.0))
	var rng := RandomNumberGenerator.new(); rng.seed = 1036
	var res := BattleSim.run(me, dummy, rng, secs)
	return [res, _count(res), me]

func _init() -> void:
	var run := G._start(1036, &"brute")
	var lv := LevelModule.of(run)
	ok(run.active_faith_id() == &"brute", "开局奉蛮神")
	var row := lv.rules().card(&"god_brute_exert")
	ok(not row.is_empty() and lv.rules().is_qual(&"god_brute_exert"), "牌表里有竭力，是质变牌：%s" % str(row))
	ok(lv.eligible(&"god_brute_exert"), "开局就能摆出竭力")
	print("EX1036 牌面 zh：%s" % UiText.t("gcard.god_brute_exert"))
	for id in [&"steel_twin_axes", &"felling_axe", &"shortsword"]:
		if TestSupport.put(run.board, run.items.get_def(id)) == null: print("EX1036 放不下 ", id)
	var a := _fight(run, 30.0)
	lv.taken[&"god_brute_exert"] = 1
	var b := _fight(run, 30.0)
	var ca: Dictionary = a[1]; var cb: Dictionary = b[1]
	print("EX1036 没拿：出手 %d、付耐力 %d、竭力 %d、最低生命 %.0f" % [ca["fired"], ca["stamina_cost"], ca["exert"], ca["min_hp"]])
	print("EX1036 拿了：出手 %d、付耐力 %d、竭力 %d（共 %d 生命）、最低生命 %.0f" % [cb["fired"], cb["stamina_cost"], cb["exert"], cb["exert_hp"], cb["min_hp"]])
	ok(ca["exert"] == 0, "没拿牌：不用生命付")
	ok(cb["exert"] > 0 and cb["fired"] > ca["fired"], "拿了：耐力不够时用生命付，出手更多（%d → %d）" % [ca["fired"], cb["fired"]])
	ok(cb["min_hp"] > 0.0, "不会把自己打死（最低 %.0f）" % cb["min_hp"])
	# 战记两种语言
	var res: BattleResult = b[0]
	for lang in ["zh", "en"]:
		UiText.lang = lang
		var hit := ""
		for l in BattleNarrator.lines(res, ["我", "木桩"], [{}, {}], [{}, {}]):
			var p := BattleNarrator.plain(l)
			if p.contains("竭力") or p.contains("overexert"): hit = p; break
		ok(hit != "", "战记 %s：%s" % [lang, hit])
	UiText.lang = "zh"
	run.dispose()
	print("EX1036 完 BAD %d" % bad)
	quit(0)

extends SceneTree
## 模拟：每把匕首单独打 30 秒木桩（生命 99999），数暴击那几下的伤害和普通的比
func _init() -> void:
	var c := TestSupport.load_content("free_mode")
	for id in ["knife", "quenched_dagger", "steel_stiletto", "silent_blade", "flame_fang", "chana"]:
		var def := c.items.get_def(StringName(id))
		var board := GridInventory.new(Vector2i(6, 6))
		var inst := TestSupport.put(board, def)
		var me := BattleCompiler.compile(board, CompileInput.new())
		var foe := CombatantSpec.new(); foe.baseline = StatSet.new(); foe.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); foe.max_hp = foe.baseline.total_of(BattleStats.MAX_HP)
		var rng := RandomNumberGenerator.new(); rng.seed = 928
		var br := BattleSim.run(me, foe, rng, 30.0)
		var crit := {}; var norm := {}; var names := {}
		for e in br.log:
			if names.size() < 0: pass
			if not e.get_bool(&"crit") and not e.payload.has(&"amount") and not e.payload.has("amount"): names[String(e.name)] = 1; continue
			if not (e.payload.has(&"raw") or e.payload.has("raw")): names["noraw:" + String(e.name) + str(e.payload.keys())] = 1; continue
			names[String(e.name)] = 1
			var raw := StatMath.to_float(e.get_int(&"raw"))
			var key := "%.2f" % raw
			if e.get_bool(&"crit"): crit[key] = int(crit.get(key, 0)) + 1
			else: norm[key] = int(norm.get(key, 0)) + 1
		var nc := 0; for k in crit: nc += crit[k]
		var nn := 0; for k in norm: nn += norm[k]
		print("DG928S %s（%s）：暴击 %d 下 %s；普通 %d 下 %s；事件 %s" % [id, Names.of(def), nc, str(crit), nn, str(norm), str(names.keys())])
	quit(0)

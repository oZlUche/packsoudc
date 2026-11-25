extends SceneTree
func _init() -> void:
	var c := TestSupport.load_content("free_mode")
	for e in [&"flame_wolf", &"cave_bear", &"shock_eel", &"frost_mane"]:
		var def = c.enemies.enemy(e)
		var short := 0; var full := 0; var meat := 0; var org := 0
		var M := {&"flame_wolf": ["wolf_shank", "wolf_heart"], &"cave_bear": ["bear_paw", "bear_liver"], &"shock_eel": ["eel_cut", ""], &"frost_mane": ["mane_loin", ""]}
		for i in 1000:
			var rng := RandomNumberGenerator.new(); rng.seed = 92900 + i
			var b: Dictionary = EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng)
			if int(b.get("carry_short", (b["content"] as Dictionary).get("carry_short", 0))) > 0: short += 1
			var ids: Array = b["content"]["items"].map(func(x): return String(x["id"]))
			if ids.has(M[e][0]): meat += 1
			if M[e][1] != "" and ids.has(M[e][1]): org += 1
			var cells := 0
			for x in b["content"]["items"]:
				var d = c.items.get_def(StringName(String(x["id"])))
				if d != null: cells += d.cell_count()
			if cells >= def.board.x * def.board.y: full += 1
		print("BF932C %s：1000 场 肉 %d、器官 %d；有东西没摆下 %d；棋盘占满 %d" % [e, meat, org, short, full])
	quit(0)

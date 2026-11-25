extends SceneTree
func _init() -> void:
	var c := TestSupport.load_content("free_mode")
	for e in [&"flame_wolf", &"pit_viper", &"frost_toad"]:
		var def = c.enemies.enemy(e)
		var short := 0; var full := 0
		for i in 1000:
			var rng := RandomNumberGenerator.new(); rng.seed = 92900 + i
			var b: Dictionary = EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng)
			if int(b.get("carry_short", (b["content"] as Dictionary).get("carry_short", 0))) > 0: short += 1
			var cells := 0
			for x in b["content"]["items"]:
				var d = c.items.get_def(StringName(String(x["id"])))
				if d != null: cells += d.cell_count()
			if cells >= def.board.x * def.board.y: full += 1
		print("BF929C %s：有东西没摆下 %d / 1000；棋盘占满 %d / 1000；键 %s" % [e, short, full, str(EnemyPlacer.build_content(def, c.pool, c.items, def.strength, RandomNumberGenerator.new()).keys())])
	quit(0)

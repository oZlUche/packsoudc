extends SceneTree
func _init() -> void:
	var c := TestSupport.load_content("free_mode")
	for e in [&"flame_wolf", &"cave_bear", &"pit_viper"]:
		var def = c.enemies.enemy(e)
		for base in [94200, 50000, 123456]:
			var n := {}; var N := 4000
			for i in N:
				var rng := RandomNumberGenerator.new(); rng.seed = base + i
				var b: Dictionary = EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng)
				for s in (b["content"] as Dictionary).get("spoils", []): n[String(s)] = int(n.get(String(s), 0)) + 1
			var parts := []
			for k in n: parts.append("%s %.1f%%" % [k, 100.0 * n[k] / N])
			print("GD942W %s 种子起 %d ×%d：%s" % [String(e), base, N, " ".join(parts)])
	quit(0)

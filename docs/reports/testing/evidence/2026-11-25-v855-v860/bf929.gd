extends SceneTree
## 游戏测试 v8.57（PR #929）：十种魔兽各 200 场按种子造对手，数掉肉、器官、招牌是否还在、摆不下的
const BEASTS := {&"flame_wolf": [&"wolf_shank", &"wolf_heart"], &"frost_toad": [&"toad_leg", &""], &"pit_viper": [&"viper_cut", &"viper_gall"], &"tusk_boar": [&"boar_belly", &""], &"shock_eel": [&"eel_cut", &""], &"cave_bear": [&"bear_paw", &"bear_liver"], &"frost_mane": [&"mane_loin", &""], &"molten_lizard": [&"lizard_tail", &""], &"thunder_vulture": [&"vulture_breast", &""], &"miasma_spider": [&"spider_leg_meat", &""]}

func _init() -> void:
	var c := TestSupport.load_content("free_mode")
	for e in BEASTS:
		var def = c.enemies.enemy(e)
		if def == null: print("BF929 没有 %s" % e); continue
		var meat := 0; var organ := 0; var n := 200; var sig_ok := 0; var cnt := 0
		var sig: Array = []
		var sig_miss := 0
		for i in n:
			var rng := RandomNumberGenerator.new(); rng.seed = 92900 + i
			var built: Dictionary = EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng)
			var items: Array = built["content"]["items"]
			var ids: Array = items.filter(func(x): return bool(x.get("carried", false))).map(func(x): return String(x["id"]))
			var all_ids: Array = items.map(func(x): return String(x["id"]))
			if i == 0: sig = all_ids.filter(func(x): return not ids.has(x) or true)
			cnt += items.size()
			for sg in def.signature:
				if not all_ids.has(String(sg)): sig_miss += 1; break
			if ids.has(String(BEASTS[e][0])) or all_ids.has(String(BEASTS[e][0])): meat += 1
			if BEASTS[e][1] != &"" and all_ids.has(String(BEASTS[e][1])): organ += 1
		var it = c.items.get_def(BEASTS[e][0])
		print("BF929 %s（%s，棋盘 %s）：肉 %s 掉了 %d / %d；器官 %s %d / %d（%.0f%%）；每场平均 %.1f 件；招牌 %s 缺过 %d 场；第一场 %s" % [e, Names.of(def), str(def.board), Names.of(it) if it != null else "?", meat, n, String(BEASTS[e][1]), organ, n, 100.0 * organ / n, float(cnt) / n, str(def.signature), sig_miss, str(sig)])
	quit(0)

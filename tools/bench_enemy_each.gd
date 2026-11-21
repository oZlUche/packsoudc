## 365（高级敌人第一批）：一只一只地量敌人。指定敌人按指定档位造出来，打同一段的全部木桩，
## 每只出一行：玩家胜率、平均战斗时长、赢的那些场的余血。只出表，不改数。
##
##     godot --headless --path . --script res://tools/bench_enemy_each.gd -- [--fights=40] [--pool=standard_ruins] [--rows=id:档:段,id:档:段]
##
## 段是木桩的步数段下标（0～3，见 archetypes.json 的 steps）。不给 --rows 就量第一批的新敌人和同档的老敌人。
extends CliTool

const STARTS := [0, 5, 10, 20]
const DEFAULT_ROWS := {
	"standard_ruins": [
		"tusk_boar:0:0", "flame_wolf:0:0", "frost_toad:0:0", "pit_viper:0:0", "shock_eel:1:1",
		"molten_lizard:2:2", "frost_mane:2:2", "thunder_vulture:3:3", "miasma_spider:2:2", "cave_bear:2:2", "adept_mage:2:2",
		"molten_lizard:3:3", "frost_mane:3:3", "miasma_spider:3:3", "cave_bear:3:3", "magus:3:3", "centurion:3:3", "warden:3:3"],
	"clockwork": [
		"steam_turret:1:1", "condenser_automaton:1:1", "arc_coil:1:1", "gear_golem:2:2",
		"condenser_automaton:2:2", "arc_coil:2:2", "pendulum_warden:3:3"],
}


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var fights := int(opts.get("fights", "40"))
	var pool_id := String(opts.get("pool", "standard_ruins"))
	var rows: Array = String(opts["rows"]).split(",") if opts.has("rows") else DEFAULT_ROWS.get(pool_id, [])
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := ContentPaths.load_asset("enemy_pools", pool_id) as EnemyPool
	var dummies := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var md := "| 敌人 | 档 | 木桩段 | 场数 | 玩家胜率 | 平均时长 | 赢时余血 |\n|---|---|---|---|---|---|---|\n"
	for row in rows:
		var parts := String(row).split(":")
		var def := enemies.enemy(StringName(parts[0]))
		if def == null:
			md += "| %s | — | — | 0 | 没有这个敌人 | — | — |\n" % parts[0]
			continue
		var tier := int(parts[1])
		var seg := int(parts[2])
		var specs: Array[CombatantSpec] = []
		for key in dummies:
			var d: Dictionary = dummies[key]
			if int((d.get("steps", [0, 0]) as Array)[0]) == STARTS[seg]:
				specs.append(DummyBuilder.compile(d, items))
		if specs.is_empty():
			continue
		var wins := 0
		var built := 0
		var dur := 0.0
		var hp_left := 0.0
		for i in fights * specs.size():
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:%d:%d" % [def.id, tier, i])
			var content: Dictionary = EnemyPlacer.build_content(def, pool, items, tier, rng).get("content", {})
			var enemy := EnemyKit.spec_of(content, enemies, pool, items)
			if enemy == null:
				continue
			built += 1
			var result := BattleSim.run(specs[i % specs.size()], enemy, rng)
			dur += result.duration_sec()
			if result.winner == 0:
				wins += 1
				var left: Variant = BattleMetrics.hp_ratio(result, 0)
				hp_left += float(left) if left != null else 0.0
		md += "| %s | %d | %d 步起 | %d | %d%% | %.1f 秒 | %s |\n" % [def.display_name, tier, STARTS[seg], built,
			roundi(100.0 * wins / maxi(1, built)), dur / maxi(1, built), "%d%%" % roundi(100.0 * hp_left / wins) if wins > 0 else "—"]
	print(md)
	finish(0)

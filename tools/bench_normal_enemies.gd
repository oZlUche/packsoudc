## 320（十档进阶 A1 / A4）：普通战斗被难度加强以后难了多少。同一段的木桩打同一串普通敌人：
## 生命 × 1 / × --hp 里的每个倍率（A1），再打「更强的一种」（[AdvancedPool]，A4，生命按 --adv-hp）。道具档位都一样。只出表，不改数。
##
##     godot --headless --path . --script res://tools/bench_normal_enemies.gd -- [--fights=30] [--pool=standard_ruins] [--hp=1.05,1.1] [--adv-hp=1.1]
extends CliTool

## （段, 档, 环）：段是木桩的步数段（archetypes.json 的 steps），档是普通战斗想要的档，环决定能出哪些敌人
const ROWS := [[0, 0, "outskirts"], [1, 0, "ruins"], [1, 1, "ruins"], [2, 1, "depths"], [2, 2, "depths"], [3, 2, "core_ring"], [3, 3, "inner"]]
const STARTS := [0, 5, 10, 20]


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var fights := int(opts.get("fights", "30"))
	var hps: Array[float] = []
	for m in String(opts.get("hp", "1.05,1.1")).split(","):
		hps.append(float(m))
	var adv_hp := float(opts.get("adv-hp", "1.1"))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := ContentPaths.load_asset("enemy_pools", String(opts.get("pool", "standard_ruins"))) as EnemyPool
	var dummies := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var md := "| 木桩段 | 档 | 环 | 普通 | %s | 更强的一种 ×%.2f | 更强的有谁 |\n|---|---|---|---|%s---|---|\n" % [
		" | ".join(hps.map(func(m: float) -> String: return "生命 ×%.2f" % m)), adv_hp, "---|".repeat(hps.size())]
	for row in ROWS:
		var seg: int = row[0]
		var tier: int = row[1]
		var node := MapNode.new()
		node.type = &"battle"
		node.layout = {"kind": row[2]}
		var specs: Array[CombatantSpec] = []
		for key in dummies:
			var d: Dictionary = dummies[key]
			if int((d.get("steps", [0, 0]) as Array)[0]) == STARTS[seg]:
				specs.append(DummyBuilder.compile(d, items))
		if specs.is_empty():
			continue
		var n := fights * specs.size()
		var base := _pct(BalanceMatrix.cell(specs, pool, enemies, items, node, tier, n, 1))
		var cells: Array[String] = []
		for m in hps:
			var r := _pct(BalanceMatrix.cell(specs, pool, enemies, items, node, tier, n, 1, BattleSim.DEFAULT_TIME_LIMIT, null, [], {}, {EnemyKit.HP_MULT: m}))
			cells.append("%d%%（%+d）" % [r, r - base])
		var adv_rows: Array = []
		var a := _pct(BalanceMatrix.cell(specs, pool, enemies, items, node, tier, n, 1, BattleSim.DEFAULT_TIME_LIMIT, null, adv_rows, {}, {EnemyKit.HP_MULT: adv_hp}, true))
		var who := {}
		for r in adv_rows:
			who[String((r as Dictionary).get("enemy", "?"))] = true
		var names: Array[String] = []
		for id in who:
			var def := enemies.enemy(StringName(id))
			names.append(def.display_name if def != null else id)
		names.sort()
		var seg_name := "%d～%s 步" % [STARTS[seg], str(STARTS[seg + 1] - 1) if seg + 1 < STARTS.size() else ""]
		md += "| %s | %d | %s | %d%% | %s | %s | %s |\n" % [seg_name, tier, row[2], base, " | ".join(cells),
			"%d%%（%+d）" % [a, a - base] if not adv_rows.is_empty() else "—", "、".join(names) if not names.is_empty() else "（没有）"]
	print(md)
	finish(0)


static func _pct(cell: Dictionary) -> int:
	return roundi(float(cell["rate"]) * 100.0)

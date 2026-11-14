## 320（十档进阶 A3）：猎手跳档时胜率掉多少。上一段的木桩（同一套配装）在段边界前一步、后一步各打一次猎手，
## 「原来」= 不带段内渐变，「渐变后」= 按难度里猎手机制的 hp_from / hp_to（[method HunterMechanic.hp_for_steps]，和正式战斗同一入口）。
## 加 --explore 改成扫倍率：这一档 × --ups、下一档 × --mults。只出表，不改数。
##
##     godot --headless --path . --script res://tools/bench_hunter_ramp.gd -- [--fights=20] [--difficulty=ascension_3] [--explore] [--mults=0.6,0.8,1.0] [--ups=1.2,1.4,1.6]
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var fights := int(opts.get("fights", "20"))
	var explore := opts.has("explore")
	var mults := _floats(String(opts.get("mults", "0.6,0.8,1.0")))
	var ups := _floats(String(opts.get("ups", "1.2,1.4,1.6")))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var diff := ContentPaths.load_asset("difficulties", String(opts.get("difficulty", "ascension_3"))) as DifficultyDef
	var mech: HunterMechanic = null
	for m in diff.mechanics:
		if m is HunterMechanic:
			mech = m
	var hunter: HunterDef = HunterSystem.load_all().get(mech.hunter_ids[0], null)
	var pool := ContentPaths.load_asset("enemy_pools", String(hunter.enemy_pool)) as EnemyPool
	var brackets := mech.bracket_steps
	var dummies := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var node := MapNode.new()
	node.type = &"battle"
	var md := ""
	if explore:
		md = "| 跨到第几步 | 木桩 | 这一档 | %s |\n|---|---|---|%s\n" % [" | ".join(mults.map(func(m: float) -> String: return "下一档 ×%.1f" % m)), "---|".repeat(mults.size())]
	else:
		md = "| 跨到第几步 | 木桩 | 原来：前一步 → 后一步 | 渐变后：前一步 → 后一步 | 渐变倍率 |\n|---|---|---|---|---|\n"
	for k in range(1, brackets.size()):
		var edge := brackets[k]
		var now_tier := hunter.strength_for_bracket(k - 1)
		var next_tier := hunter.strength_for_bracket(k)
		var specs: Array[CombatantSpec] = []
		for key in dummies:
			var d: Dictionary = dummies[key]
			if int((d.get("steps", [0, 0]) as Array)[1]) == edge - 1:
				specs.append(DummyBuilder.compile(d, items))
		if specs.is_empty():
			continue
		var n := fights * specs.size()
		var rate := func(tier: int, m: float) -> int:
			var stamp := {} if m == 1.0 else {EnemyKit.HP_MULT: m}
			return roundi(float(BalanceMatrix.cell(specs, pool, enemies, items, node, tier, n, 1, BattleSim.DEFAULT_TIME_LIMIT, null, [], {}, stamp)["rate"]) * 100.0)
		var head := "%d → %d（档 %d → %d）" % [edge - 1, edge, now_tier, next_tier]
		if explore:
			var cur: Array[String] = []
			for m in ups:
				cur.append("×%.1f %d%%" % [m, rate.call(now_tier, m)])
			var cells: Array[String] = []
			for m in mults:
				cells.append("%d%%" % rate.call(next_tier, m))
			md += "| %s | %d 份 | %d%%（%s） | %s |\n" % [head, specs.size(), rate.call(now_tier, 1.0), "，".join(cur), " | ".join(cells)]
			continue
		var a := mech.hp_for_steps(edge - 1)
		var b := mech.hp_for_steps(edge)
		var r0: int = rate.call(now_tier, 1.0)
		var r1: int = rate.call(next_tier, 1.0)
		var s0: int = rate.call(now_tier, a)
		var s1: int = rate.call(next_tier, b)
		md += "| %s | %d 份 | %d%% → %d%%（%+d） | %d%% → %d%%（%+d） | ×%.2f → ×%.2f |\n" % [head, specs.size(), r0, r1, r1 - r0, s0, s1, s1 - s0, a, b]
	print(md)
	finish(0)


func _floats(raw: String) -> Array[float]:
	var out: Array[float] = []
	for m in raw.split(","):
		out.append(float(m))
	return out

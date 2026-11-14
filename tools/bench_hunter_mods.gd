## 320（十档进阶 A5 / A8）：猎手加生命、加攻击各难了多少。每一段的木桩打这一段的猎手（档位按段位表，生命按段中间那一步的渐变），
## 再分别乘生命（A5）、直接攻击伤害（A8），最后两样一起。只出表，不改数。
##
##     godot --headless --path . --script res://tools/bench_hunter_mods.gd -- [--fights=20] [--difficulty=ascension_3] [--mults=1.05,1.1]
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var fights := int(opts.get("fights", "20"))
	var mults: Array[float] = []
	for m in String(opts.get("mults", "1.05,1.1")).split(","):
		mults.append(float(m))
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
	var heads: Array[String] = ["这一档"]
	for m in mults:
		heads.append("生命 ×%.2f" % m)
	for m in mults:
		heads.append("攻击 ×%.2f" % m)
	var top: float = mults[mults.size() - 1]
	heads.append("生命、攻击都 ×%.2f" % top)
	var md := "| 段 | 步数 | 档 | 渐变 | %s |\n|---|---|---|---|%s\n" % [" | ".join(heads), "---|".repeat(heads.size())]
	for k in brackets.size():
		var lo := brackets[k]
		var hi := brackets[k + 1] - 1 if k + 1 < brackets.size() else lo + mech.hp_last_span
		@warning_ignore("integer_division")
		var mid := (lo + hi) / 2
		var ramp := mech.hp_for_steps(mid)
		var tier := hunter.strength_for_bracket(k)
		var specs: Array[CombatantSpec] = []
		for key in dummies:
			var d: Dictionary = dummies[key]
			if int((d.get("steps", [0, 0]) as Array)[0]) == lo:
				specs.append(DummyBuilder.compile(d, items))
		if specs.is_empty():
			continue
		var n := fights * specs.size()
		var rate := func(hp: float, dmg: float) -> int:
			var stamp := {EnemyKit.HP_MULT: ramp * hp}
			if dmg != 1.0:
				stamp[EnemyKit.DMG_MULT] = dmg
			return roundi(float(BalanceMatrix.cell(specs, pool, enemies, items, node, tier, n, 1, BattleSim.DEFAULT_TIME_LIMIT, null, [], {}, stamp)["rate"]) * 100.0)
		var base: int = rate.call(1.0, 1.0)
		var cells: Array[String] = ["%d%%" % base]
		for m in mults:
			var r: int = rate.call(m, 1.0)
			cells.append("%d%%（%+d）" % [r, r - base])
		for m in mults:
			var r: int = rate.call(1.0, m)
			cells.append("%d%%（%+d）" % [r, r - base])
		var both: int = rate.call(top, top)
		cells.append("%d%%（%+d）" % [both, both - base])
		md += "| %d | %d～%d（取 %d） | %d | ×%.2f | %s |\n" % [k, lo, hi, mid, tier, ramp, " | ".join(cells)]
	print(md)
	finish(0)

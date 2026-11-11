## 平衡检测方案（2026-11-10）§6.1 / §6.3：逐场的扫表实验。每一场一行（造不出来也写一行，带原因），统计全部来自同一份 summary。
##
## 三种抽样，报告分开写：
## - `coverage`（覆盖测试）：显式枚举池里每个敌人 × 每一档，找一边倒的对局；不看节点条件。
## - `frequency`（频率测试）：照正式开局生成几张章节地图，取图上真的战斗点（带类型、地形种类、危险度、它身上已经定好的敌人），
##   按档从这些点里抽；点出现得多就抽得多。随机点、搜索遭遇是揭开时现造的，不在图上，这里没有。
## - `bare_node`（假节点）：沿用旧扫表那个没有地形、危险度 0 的战斗点 —— 只是一张对照表，不能叫真实地图难度。
##
## 同一档同一个序号 i 的敌人与随机源只看（种子, 档, i）（覆盖测试再加敌人），所以同一格里各路木桩打的是同一串敌人：
## 配对标识（pair_id）相同的两场可以直接相减。来源一律是 synthetic。
class_name BalanceExperiment
extends RefCounted

const COVERAGE := "coverage"
const FREQUENCY := "frequency"
const BARE_NODE := "bare_node"
const MODES: Array[String] = [COVERAGE, FREQUENCY, BARE_NODE]
## 只给异常（平局、超时）存完整诊断包，最多这么多份
const DIAG_CAP := 20

const E_NO_CANDIDATE := "no_candidate"
const E_ENEMY_BUILD := "enemy_build_failed"
const E_DUMMY := "dummy_compile_failed"
const E_NO_NODE := "no_real_node"
const E_INVALID := "invalid_result"


## 跑一次。[param ctx]：pool、enemies、items、mode、fights（每格）、seed、time_limit、overtime；
## 频率测试再要 chapter、maps（几张图）、difficulty（[DifficultyDef]，可空）、sets。
## 返回 {cases, packs: [[名字, 包]], seeds, population（频率测试：图上的点）, cells: {格 → 说明}}
static func run(dummies: Dictionary, ctx: Dictionary) -> Dictionary:
	var pool: EnemyPool = ctx["pool"]
	var enemies: EnemyDatabase = ctx["enemies"]
	var items: ItemDatabase = ctx["items"]
	var mode := String(ctx.get("mode", BARE_NODE))
	var fights := maxi(1, int(ctx.get("fights", 100)))
	var p_seed := int(ctx.get("seed", 1))
	var limit := float(ctx.get("time_limit", BattleSim.DEFAULT_TIME_LIMIT))
	var overtime: OvertimeRules = ctx.get("overtime", null)
	var out := {"cases": [], "packs": [], "seeds": {"base": p_seed, "rule": _seed_rule(mode)}, "population": {}, "cells": {}}
	var groups := _groups(dummies, items)
	var mut: Dictionary = ctx.get("mutation", {})     # 303：难度实验的改数（[BalanceMutation]）；空 = 基线
	for g in groups:
		for member in groups[g]:
			BalanceMutation.scale_hp((member as Dictionary)["spec"], mut)
	var population: Array = []
	if mode == FREQUENCY:
		population = real_nodes(ctx)
		out["population"] = population_summary(population)
	var tiers := pool.strengths()
	var bare := MapNode.new()
	bare.type = &"battle"
	var n := 0
	var cache := {}
	for g in groups:
		var members: Array = groups[g]
		for tier in tiers:
			var targets: Array = [&""]
			if mode == COVERAGE:
				targets = coverage_targets(pool, enemies)
				var only: Array = ctx.get("only_enemies", [])     # 303：覆盖测试只跑这几种敌人（空 = 全池）
				if not only.is_empty():
					targets = targets.filter(func(t: StringName) -> bool: return only.has(String(t)))
			for target in targets:
				var cell := "%s/t%d" % [g, tier] + ("/%s" % target if target != &"" else "")
				out["cells"][cell] = {"group": g, "archetype": String(g).get_slice("/", 0), "bracket": int(String(g).get_slice("/", 1)),
					"tier": tier, "enemy": String(target)}
				for i in fights:
					n += 1
					var member: Dictionary = members[i % members.size()]
					var row := _head(n, cell, mode, member, int(String(g).get_slice("/", 1)), tier, i, target)
					var key := "%d|%s|%d" % [tier, target, i]
					if not cache.has(key):     # 敌人只看（种子, 档, 敌人, i），各路木桩共用一份：造一次，连同造完时随机源的状态记下
						var r0 := RandomNumberGenerator.new()
						r0.seed = case_seed(p_seed, tier, i, target)
						var built := _enemy(mode, pool, enemies, items, tier, target, bare, population, r0, mut)
						built["state"] = r0.state
						cache[key] = built
					var made: Dictionary = cache[key]
					var rng := RandomNumberGenerator.new()
					rng.seed = case_seed(p_seed, tier, i, target)
					rng.state = int(made["state"])
					row["rng"] = {"seed": rng.seed}
					row["node"] = made.get("node")
					row["enemy"] = made.get("summary")
					var spec: CombatantSpec = member["spec"]
					var error := String(made.get("error", "")) if spec != null else E_DUMMY
					if error != "":
						row["stage"] = "generate"
						row["error"] = error
						out["cases"].append(row)
						continue
					var foe: CombatantSpec = made["spec"]
					var state := rng.state
					row["rng"]["state"] = str(state)
					var result := BattleSim.run(spec, foe, rng, limit, overtime)
					_fill(row, result, limit, [spec, foe])
					out["cases"].append(row)
					var o := String(row.get("outcome", ""))
					if (o == BattleMetrics.DRAW or o == BattleMetrics.TIMEOUT or not row["valid"]) and (out["packs"] as Array).size() < DIAG_CAP:
						var again := RandomNumberGenerator.new()
						again.seed = rng.seed
						again.state = state
						var pack := BattleDiagPack.capture(spec, foe, again, limit, overtime, {"case_id": row["case_id"], "source": ExperimentManifest.SYNTHETIC})
						pack.expected = BattleDiagPack.summary(result)
						(out["packs"] as Array).append([row["case_id"], pack])
	return out


## 第 i 场的种子：旧扫表同一条（种子:档:i）；覆盖测试再接上敌人
static func case_seed(p_seed: int, tier: int, i: int, target: StringName = &"") -> int:
	return hash("%d:%d:%d" % [p_seed, tier, i]) if target == &"" else hash("%d:%d:%s:%d" % [p_seed, tier, target, i])


static func _seed_rule(mode: String) -> String:
	return "hash(\"种子:档:敌人:i\")" if mode == COVERAGE else "hash(\"种子:档:i\")"


## 覆盖测试要枚举的敌人：池里权重大于 0、库里有的，去重，按 id 排
static func coverage_targets(pool: EnemyPool, enemies: EnemyDatabase) -> Array:
	var ids := {}
	for e in pool.entries:
		if e != null and e.weight > 0.0 and enemies.enemy(e.enemy) != null:
			ids[e.enemy] = true
	var out: Array = ids.keys()
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## 照正式开局生成 [code]ctx.maps[/code] 张图，收图上带敌人的战斗点。每项 {map_seed, node_id, type, kind, danger, map_tier, strength, enemy, content}
static func real_nodes(ctx: Dictionary) -> Array:
	var out: Array = []
	var chapter: ChapterDef = ctx.get("chapter", null)
	if chapter == null:
		return out
	var maps := maxi(1, int(ctx.get("maps", 20)))
	var base := int(ctx.get("seed", 1))
	for k in maps:
		var s := RunState.start(chapter, base * 1000 + k, ctx["items"], ctx["enemies"], ctx.get("sets", null), [] as Array[StringName], {},
			[] as Array[StringName], null, [], ctx.get("difficulty", null))
		if s == null or s.map == null:
			continue
		for id in s.map.node_ids():
			var node := s.map.get_node(id)
			if not EnemyKit.has_enemy(node.content):
				continue
			out.append({"map_seed": base * 1000 + k, "node_id": id, "type": String(node.type), "kind": String(node.layout.get("kind", "")),
				"danger": node.danger, "map_tier": node.tier, "strength": int(node.content.get("strength", 0)),
				"enemy": String(node.content.get("enemy", "")), "content": node.content.duplicate(true)})
	return out


## 图上的点按档、按敌人、按地形种类、按危险度计数
static func population_summary(population: Array) -> Dictionary:
	var by := {"strength": {}, "enemy": {}, "kind": {}, "danger": {}}
	for p in population:
		var d := p as Dictionary
		for key in by:
			var v := str(d.get(key, ""))
			by[key][v] = int(by[key].get(v, 0)) + 1
	by["nodes"] = population.size()
	return by


## 木桩按（流派/段）分组，每份 {key, dummy, spec, budget}
static func _groups(dummies: Dictionary, items: ItemDatabase) -> Dictionary:
	var groups := {}
	var keys: Array = dummies.keys()
	keys.sort()
	for key in keys:
		var d: Dictionary = dummies[key]
		var g := "%s/%d" % [String(d.get("archetype", BalanceMatrix.REAL)), int(d.get("bracket", int(String(key))))]
		(groups.get_or_add(g, []) as Array).append({"key": String(key), "dummy": d, "spec": DummyBuilder.compile(d, items), "budget": ScenarioCheck.budget_of(d, items)})
	return groups


static func _head(n: int, cell: String, mode: String, member: Dictionary, bracket: int, tier: int, i: int, target: StringName) -> Dictionary:
	var d: Dictionary = member["dummy"]
	var row := {
		"case_id": "c%06d" % n, "cell": cell, "pair_id": "t%d/%s/i%d" % [tier, String(target), i] if target != &"" else "t%d/i%d" % [tier, i],
		"replicate": i, "mode": mode, "dummy": member["key"], "archetype": String(d.get("archetype", BalanceMatrix.REAL)),
		"group": String(d.get("group", "")), "bracket": bracket, "steps": d.get("steps", null),
		"character": String(d.get("character", String(ArchetypeBuilder.CHARACTER) if d.has("archetype") else "")), "budget": member["budget"],
		"tier": tier, "stage": "", "error": "", "simulated": false, "valid": false,
	}
	return ExperimentManifest.stamp(row, ExperimentManifest.SYNTHETIC)


## 造这一场的敌人：{spec, summary, node} 或 {error, …}
static func _enemy(mode: String, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase, tier: int, target: StringName,
		bare: MapNode, population: Array, rng: RandomNumberGenerator, mut: Dictionary = {}) -> Dictionary:
	var content := {}
	var node: Variant = null
	match mode:
		COVERAGE:
			content = EnemyPlacer.build_content(enemies.enemy(target), pool, items, tier, rng).get("content", {})
		FREQUENCY:
			var picks: Array = population.filter(func(q: Dictionary) -> bool: return int(q["strength"]) == tier)
			if picks.is_empty():
				return {"error": E_NO_NODE}
			var p: Dictionary = picks[rng.randi_range(0, picks.size() - 1)]
			content = p["content"]
			node = {"map_seed": p["map_seed"], "node_id": p["node_id"], "type": p["type"], "kind": p["kind"], "danger": p["danger"], "map_tier": p["map_tier"]}
		_:
			var entry := EnemyPlacer.pick(pool, enemies, bare, tier, rng)
			if entry == null:
				return {"error": E_NO_CANDIDATE, "node": {"type": "battle", "kind": "", "danger": 0}}
			content = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, items, tier, rng).get("content", {})
			node = {"type": "battle", "kind": "", "danger": 0}
	var summary := {"id": String(content.get("enemy", target)), "strength": int(content.get("strength", tier)),
		"items": EnemyKit.entries_of(content).size(), "digest": ExperimentManifest.canonical_hash(content)}
	if not mut.is_empty() and not content.is_empty():
		content = BalanceMutation.foe_content(content, mut, enemies, pool)     # 303：摘要照原件算（同一个敌人实例），改的是打的那份
	var spec := EnemyKit.spec_of(content, enemies, pool, items) if not content.is_empty() else null
	if spec == null:
		return {"error": E_ENEMY_BUILD, "summary": summary, "node": node}
	BalanceMutation.scale_hp(spec, mut)
	return {"spec": spec, "summary": summary, "node": node}


static func _fill(row: Dictionary, result: BattleResult, limit: float, specs: Array) -> void:
	var m := BattleMetrics.of(result, limit, specs)
	row["simulated"] = true
	row["outcome"] = m["outcome"]
	row["duration"] = m["duration"]
	row["hp_end"] = m["hp_end"]
	m.erase("outcome")
	m.erase("duration")
	m.erase("hp_end")
	row["metrics"] = m
	var ok := is_finite(float(row["duration"])) and (row["hp_end"] as Array)[0] != null and (row["hp_end"] as Array)[1] != null
	row["valid"] = ok
	if not ok:
		row["stage"] = "simulate"
		row["error"] = E_INVALID


## 汇总：全体一份、每格一份；有兵刃变体时变体对它那一组的配对胜率差（同段同档同序号相减）
static func summarize(run_out: Dictionary) -> Dictionary:
	var cases: Array = run_out["cases"]
	var by_cell := {}
	for row in cases:
		var c := String((row as Dictionary)["cell"])
		(by_cell.get_or_add(c, []) as Array).append(row)
	var cells := {}
	for c in by_cell:
		cells[c] = BalanceStatistics.summarize(by_cell[c])
	return {"total": BalanceStatistics.summarize(cases), "cells": cells, "cell_meta": run_out["cells"], "pairs": pairs_of(cases),
		"population": run_out.get("population", {})}


## 兵刃变体（行里 group 不空）对同组对照（archetype == group）：同段、同格（档 / 敌人）、同序号的两场，胜记 1 负记 0，相减
static func pairs_of(cases: Array) -> Array:
	var base := {}
	for r in cases:
		var row := r as Dictionary
		if row["group"] != "" and row["archetype"] == row["group"] and row["valid"]:
			base["%d|%s" % [row["bracket"], row["pair_id"]]] = row
	var acc := {}
	for r in cases:
		var row := r as Dictionary
		if row["group"] == "" or row["archetype"] == row["group"]:
			continue
		var k := "%d|%s" % [row["bracket"], row["pair_id"]]
		if not base.has(k):
			continue
		var b: Dictionary = base[k]
		var key := "%s/%d/t%d" % [row["archetype"], row["bracket"], row["tier"]]
		if not acc.has(key):
			acc[key] = {"variant": row["archetype"], "against": row["group"], "bracket": row["bracket"], "tier": row["tier"], "win": [], "duration": []}
		var won := func(x: Dictionary) -> Variant: return ((1.0 if x["outcome"] == BattleMetrics.WIN else 0.0) as Variant) if x["valid"] else null
		(acc[key]["win"] as Array).append([won.call(row), won.call(b)])
		(acc[key]["duration"] as Array).append([row.get("duration") if row["valid"] else null, b.get("duration")])
	var out: Array = []
	var keys: Array = acc.keys()
	keys.sort()
	for key in keys:
		var a: Dictionary = acc[key]
		out.append({"variant": a["variant"], "against": a["against"], "bracket": a["bracket"], "tier": a["tier"],
			"win_diff": BalanceStatistics.paired_bootstrap(a["win"]), "duration_diff": BalanceStatistics.paired_bootstrap(a["duration"])})
	return out


## 写实验目录：manifest.json、seeds.json、cases.jsonl、summary.json、summary.csv、report.md、diagnostics/。返回写出的文件；写不了返回空
static func write(dir: String, manifest: Dictionary, run_out: Dictionary, summary: Dictionary, title: String) -> Array[String]:
	var files: Array[String] = []
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return files
	var seeds: Dictionary = (run_out["seeds"] as Dictionary).duplicate()
	var per := {}
	for row in run_out["cases"]:
		per[(row as Dictionary)["case_id"]] = (row as Dictionary)["rng"]
	seeds["cases"] = per
	var jsonl: Array[String] = []
	for row in run_out["cases"]:
		jsonl.append(JSON.stringify(row, "", true))
	var texts := {
		"manifest.json": JSON.stringify(manifest, "  ", true) + "\n",
		"seeds.json": JSON.stringify(seeds, "  ", true) + "\n",
		"cases.jsonl": "\n".join(jsonl) + ("\n" if not jsonl.is_empty() else ""),
		"summary.json": JSON.stringify(summary, "  ", true) + "\n",
		"summary.csv": BalanceReport.csv(summary),
		"report.md": BalanceReport.markdown(summary, manifest, title),
	}
	for name in texts:
		var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
		if f == null:
			return [] as Array[String]
		f.store_string(texts[name])
		f.close()
		files.append(dir.path_join(name))
	var diag := dir.path_join("diagnostics")
	for p in run_out["packs"]:
		var path := BattleDiagnostics.write(p[1], String(p[0]), diag, 1 << 20)
		if path != "":
			files.append(path)
	return files


## 影响扫表结果的内容目录（算 manifest 的内容摘要）
const CONTENT_DIRS: Array[String] = ["res://data/items", "res://data/enemies", "res://data/enemy_pools", "res://data/chapters", "res://data/node_rules",
	"res://data/difficulties", "res://data/characters"]


## 一条龙：跑、汇总、开 manifest、写进 [param out_root]/<实验 id>/。[param config] 原样进 manifest（要带 mode / fights / seed / time_limit）。
## 返回 {dir, files, summary, manifest}；写不了时 files 为空
## [param decorate] 拿到 summary 后可以往里加东西（猎手：每段想要的档与最接近五成的档），写盘前调
static func execute(dummies: Dictionary, ctx: Dictionary, config: Dictionary, out_root: String, title: String, decorate: Callable = Callable()) -> Dictionary:
	var run_out := run(dummies, ctx)
	var summary := summarize(run_out)
	if decorate.is_valid():
		decorate.call(summary)
	var manifest := ExperimentManifest.make(ExperimentManifest.SYNTHETIC, config, CONTENT_DIRS, dummies)
	var dir := out_root.path_join(String(manifest["experiment_id"]))
	return {"dir": dir, "files": write(dir, manifest, run_out, summary, title), "summary": summary, "manifest": manifest}


## 敌人池 [param pool_id] 是哪一章的（频率测试照它开局）；没有返回 null
static func chapter_for_pool(pool_id: String) -> ChapterDef:
	var dir := ContentPaths.asset_file("chapters", "x").get_base_dir()
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	for f in names:
		if not String(f).ends_with(".tres"):
			continue
		var c := load(dir.path_join(f)) as ChapterDef
		if c != null and String(c.enemy_pool) == pool_id:
			return c
	return null

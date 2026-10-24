## 扫表（242 §3.2 / §8.1 第 2 项）：木桩 × 敌人池每一档 → 每格 N 场，四张表（胜率、平均时长、赢时余血、同段五路极差）。
##
## [HunterBench] 的推广：造敌同一条路（[method EnemyPlacer.pick] / [method EnemyPlacer.build_content] → [method EnemyKit.spec_of] → [method BattleSim.run]），
## 多记时长与余血。一格 = 同一路同一段的几份木桩（种子）对同一档，场数均摊；第 i 场的敌人与随机源只看（种子, 档, i），
## 所以五路在同一格里打的是同一串敌人 —— 差出来的就是木桩的差。
## 只打印，不改数（073 原则）：表给作者看，作者改 json。
class_name BalanceMatrix
extends RefCounted

const OUT_DIR := "res://docs/reports/balance"
## 难度没有段位表时的退路（241 后猎手的段位表）
const DEFAULT_BRACKETS: Array[int] = [0, 5, 10, 20]
## 真实木桩（[DummyBuilder]）没有流派，记成这一路
const REAL := "real"
## 单调性检查：反着走超过这么多（百分点）才记
const MONO_SLACK := 5.0


## 难度 id 的猎手段位表；没有就 [constant DEFAULT_BRACKETS]
static func brackets_of(difficulty_id: String) -> Array[int]:
	var path := ContentPaths.asset_file("difficulties", difficulty_id)
	if difficulty_id != "" and ResourceLoader.exists(path):
		var d := load(path) as DifficultyDef
		if d != null and not d.hunter_bracket_steps().is_empty():
			return d.hunter_bracket_steps()
	return DEFAULT_BRACKETS.duplicate()


## 一格：[param specs] 轮流上场，共 [param fights] 场。返回 {fights, wins, draws, rate, duration（秒，全部场次平均）, hp_left（赢的那些场的余血比例平均）}
static func cell(specs: Array[CombatantSpec], pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase, node: MapNode,
		tier: int, fights: int, seed: int, time_limit: float = BattleSim.DEFAULT_TIME_LIMIT, overtime: OvertimeRules = null,
		rows: Array = [], head: Dictionary = {}) -> Dictionary:
	var wins := 0
	var draws := 0
	var built := 0
	var dur := 0.0
	var hp_left := 0.0
	for i in maxi(1, fights):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%d:%d" % [seed, tier, i])
		var entry := EnemyPlacer.pick(pool, enemies, node, tier, rng)
		if entry == null:
			continue
		var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, items, tier, rng).get("content", {})
		var enemy := EnemyKit.spec_of(content, enemies, pool, items)
		if enemy == null:
			continue
		built += 1
		var spec := specs[i % specs.size()]
		var result := BattleSim.run(spec, enemy, rng, time_limit, overtime)
		var h := head.duplicate()     # 245：木桩也量一行系数假设（[param rows]），和真人的放一张表上比
		h["tier"] = tier
		h["enemy"] = String(entry.enemy)
		h["stamina_regen"] = AssumptionStats.regen_of(spec)
		rows.append(AssumptionStats.of(result, h))
		dur += result.duration_sec()
		if result.winner == 0:
			wins += 1
			hp_left += hp_ratio(result, 0)
		elif result.is_draw():
			draws += 1
	return {"fights": built, "wins": wins, "draws": draws, "rate": float(wins) / built if built > 0 else 0.0,
		"duration": dur / built if built > 0 else 0.0, "hp_left": hp_left / wins if wins > 0 else 0.0}


## 打完时 [param side] 剩的生命比例（0～1）
static func hp_ratio(result: BattleResult, side: int) -> float:
	var sides: Array = result.final.get("sides", [])
	if side >= sides.size():
		return 0.0
	var res: Dictionary = (sides[side] as Dictionary).get("resources", {})
	var hp: Array = res.get(BattleStats.RES_HP, res.get("hp", [0, 0]))
	return float(hp[0]) / float(hp[1]) if hp.size() >= 2 and float(hp[1]) > 0.0 else 0.0


## 全表。木桩按（流派, 段）分组。返回 {archetypes, brackets, tiers, steps: {段 → [起, 止]}, cells: {"流派/段" → {档 → 格}}}
static func run(dummies: Dictionary, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase, fights: int = 300, seed: int = 1,
		time_limit: float = BattleSim.DEFAULT_TIME_LIMIT, overtime: OvertimeRules = null) -> Dictionary:
	var groups := {}
	var archetypes: Array[String] = []
	var brackets: Array[int] = []
	var steps := {}
	for key in dummies:
		var d: Dictionary = dummies[key]
		var a := String(d.get("archetype", REAL))
		var k := int(d.get("bracket", int(String(key))))
		if not archetypes.has(a):
			archetypes.append(a)
		if not brackets.has(k):
			brackets.append(k)
		steps[k] = d.get("steps", [0, -1])
		var g := "%s/%d" % [a, k]
		if not groups.has(g):
			groups[g] = [] as Array[CombatantSpec]
		(groups[g] as Array[CombatantSpec]).append(DummyBuilder.compile(d, items))
	brackets.sort()
	var node := MapNode.new()
	node.id = 0
	node.type = &"battle"
	var tiers := pool.strengths()
	var cells := {}
	var assumptions: Array = []
	for g in groups:
		var row := {}
		var head := {"bracket": int(String(g).get_slice("/", 1)), "archetype": String(g).get_slice("/", 0)}
		for tier in tiers:
			row[tier] = cell(groups[g], pool, enemies, items, node, tier, fights, seed, time_limit, overtime, assumptions, head)
		cells[g] = row
	return {"archetypes": archetypes, "brackets": brackets, "tiers": tiers, "steps": steps, "cells": cells, "assumptions": assumptions}


## 四张表 + 单调性检查。[param header] 的每一项印成表头的一行（参数、git 短哈希）
static func markdown(result: Dictionary, title: String, header: Array[String]) -> String:
	var lines: Array[String] = ["# " + title, ""]
	for h in header:
		lines.append("- " + h)
	lines.append("")
	lines.append("每格：这一路这一段的木桩对池里这一档的敌人；★ = 同段同档（段 k 的木桩按第 k 档的件数与稀有度配，§3.3 的目标带看这一格）。")
	lines.append("")
	lines.append_array(_table(result, "一 胜率", "玩家赢的比例。随档应下降、随段应上升", func(c: Dictionary) -> String: return "%.0f%%" % (float(c["rate"]) * 100.0)))
	lines.append_array(_table(result, "二 平均时长", "秒（全部场次）。太短 = 一方秒杀；贴着时限 = 谁也打不动", func(c: Dictionary) -> String: return "%.1f" % float(c["duration"])))
	lines.append_array(_table(result, "三 赢时余血", "赢的那些场剩的生命比例。高 = 赢得轻松，低 = 险胜", func(c: Dictionary) -> String:
		return "%.0f%%" % (float(c["hp_left"]) * 100.0) if int(c["wins"]) > 0 else "—"))
	lines.append_array(_spread(result))
	lines.append_array(_monotony(result))
	var rows: Array = result.get("assumptions", [])
	if not rows.is_empty():     # 245：木桩量出来的系数假设，和真人的（tools/assumptions_report.gd）同一张表的样子
		lines.append_array(["## 假设实测（木桩）", "", "每场一行，全部格子一起汇总；和真人对局的表（`tools/assumptions_report.gd`）对着看木桩差在哪。", ""])
		lines.append_array(AssumptionStats.table(rows, PowerWeights.load_from()))
		lines.append("")
		lines.append_array(AssumptionStats.bracket_table(rows))
		lines.append("")
	return "\n".join(lines) + "\n"


static func _steps_text(result: Dictionary, k: int) -> String:
	var s: Array = (result["steps"] as Dictionary).get(k, [0, -1])
	return "%d～%s 步" % [int(s[0]), str(int(s[1])) if int(s[1]) >= 0 else "∞"]


static func _rate(result: Dictionary, a: String, k: int, tier: int) -> float:
	var row: Dictionary = (result["cells"] as Dictionary).get("%s/%d" % [a, k], {})
	return float((row[tier] as Dictionary)["rate"]) if row.has(tier) else -1.0


static func _table(result: Dictionary, name: String, note: String, fmt: Callable) -> Array[String]:
	var tiers: Array = result["tiers"]
	var out: Array[String] = ["## %s" % name, "", note, ""]
	var head := "| 段 | 流派 |"
	var rule := "|---|---|"
	for t in tiers:
		head += " 档 %d |" % t
		rule += "---|"
	out.append(head)
	out.append(rule)
	for k in result["brackets"]:
		for a in result["archetypes"]:
			var row: Dictionary = (result["cells"] as Dictionary).get("%s/%d" % [a, k], {})
			var line := "| %d（%s） | %s |" % [k, _steps_text(result, k), a]
			for t in tiers:
				var mark := "★" if int(t) == int(k) else ""
				line += " %s%s |" % [fmt.call(row[t]), mark] if row.has(t) else " — |"
			out.append(line)
	out.append("")
	return out


## 表四：同段同档里五路胜率的极差（最高 − 最低，百分点），注上最高、最低是哪一路
static func _spread(result: Dictionary) -> Array[String]:
	var tiers: Array = result["tiers"]
	var out: Array[String] = ["## 四 同段五路极差", "", "同一段同一档，各流派胜率最高减最低（百分点）。大 = 某一路的道具偏强或偏弱，回第〇层（151 表）找那一类", ""]
	var head := "| 段 |"
	var rule := "|---|"
	for t in tiers:
		head += " 档 %d |" % t
		rule += "---|"
	out.append(head)
	out.append(rule)
	for k in result["brackets"]:
		var line := "| %d（%s） |" % [k, _steps_text(result, k)]
		for t in tiers:
			var hi := -1.0
			var lo := 2.0
			var hi_a := ""
			var lo_a := ""
			for a in result["archetypes"]:
				var r := _rate(result, a, k, t)
				if r < 0.0:
					continue
				if r > hi:
					hi = r
					hi_a = a
				if r < lo:
					lo = r
					lo_a = a
			if hi < 0.0:
				line += " — |"
			elif hi_a == lo_a:
				line += " 0（都是 %.0f%%） |" % (hi * 100.0)
			else:
				line += " %.0f（%s %.0f%% / %s %.0f%%） |" % [(hi - lo) * 100.0, hi_a, hi * 100.0, lo_a, lo * 100.0]
		out.append(line)
	out.append("")
	return out


## 不单调的格子：同一路同一段，档高了胜率反而升；同一路同一档，段高了胜率反而降（各超过 [constant MONO_SLACK] 个百分点才记）
static func _monotony(result: Dictionary) -> Array[String]:
	var out: Array[String] = ["## 单调性检查", ""]
	var tiers: Array = result["tiers"]
	var brackets: Array = result["brackets"]
	var found := 0
	for a in result["archetypes"]:
		for k in brackets:
			for i in range(1, tiers.size()):
				var prev := _rate(result, a, k, tiers[i - 1])
				var cur := _rate(result, a, k, tiers[i])
				if prev >= 0.0 and cur >= 0.0 and (cur - prev) * 100.0 > MONO_SLACK:
					out.append("- %s 段 %d：档 %d → 档 %d 胜率反升 %.0f%% → %.0f%%" % [a, k, tiers[i - 1], tiers[i], prev * 100.0, cur * 100.0])
					found += 1
		for t in tiers:
			for i in range(1, brackets.size()):
				var prev := _rate(result, a, brackets[i - 1], t)
				var cur := _rate(result, a, brackets[i], t)
				if prev >= 0.0 and cur >= 0.0 and (prev - cur) * 100.0 > MONO_SLACK:
					out.append("- %s 档 %d：段 %d → 段 %d 胜率反降 %.0f%% → %.0f%%" % [a, t, brackets[i - 1], brackets[i], prev * 100.0, cur * 100.0])
					found += 1
	if found == 0:
		out.append("没有反着走超过 %.0f 个百分点的格子。" % MONO_SLACK)
	out.append("")
	return out

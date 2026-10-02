## 猎手校准（069 第七节第 7 条，报告 073）：木桩对着猎手的每一档打几千场，打印胜率，找离 50% 最近的那一档。
##
## 作者：不断和木桩对战保证 50% 胜率。工具只做统计，不改数：每段木桩 × 池里的每个档位 → 胜率；
## 再算一下按现在的强度规则、这一段的探索度会给哪一档（`wanted`），和最接近 50% 的那一档（`best`）并排 —— 差在哪一眼看出来，作者改规则或档位表。
## 敌人按猎手指定的池与规则现造（和一局里一样，`EnemyPlacer`），每一场换一个随机源，同一个种子结果可复现。
class_name HunterBench
extends RefCounted


## 一段木桩对一档：赢的比例
static func win_rate(dummy: CombatantSpec, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase, node: MapNode,
		tier: int, fights: int, seed: int, time_limit: float = BattleSim.DEFAULT_TIME_LIMIT) -> Dictionary:
	var wins := 0
	var draws := 0
	var built := 0
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
		var result := BattleSim.run(dummy, enemy, rng, time_limit)
		if result.winner == 0:
			wins += 1
		elif result.is_draw():
			draws += 1
	return {"fights": built, "wins": wins, "draws": draws, "rate": float(wins) / built if built > 0 else 0.0}


## 全表：{段号 → {steps, samples, wanted, best, rates: {档位 → 胜率}}}
static func run(dummies: Dictionary, hunter: HunterDef, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase,
		fights: int = 200, seed: int = 1, difficulty: int = 0, scale_id: StringName = &"", searches_per_step: float = 0.0,
		brackets: Array[int] = [] as Array[int]) -> Dictionary:
	var out := {}
	var use_pool := pool
	var rule: StrengthRule = hunter.strength_rule if hunter != null and hunter.strength_rule != null else (use_pool.strength_rule if use_pool != null else null)
	var node := MapNode.new()
	node.id = 0
	node.type = &"battle"
	var keys: Array = dummies.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for k in keys:
		var dummy: Dictionary = dummies[k]
		var spec := DummyBuilder.compile(dummy, items)
		var steps_raw: Array = dummy.get("steps", [0, 0])
		var hi := int(steps_raw[1]) if int(steps_raw[1]) >= 0 else int(steps_raw[0]) + 5
		var mid := (int(steps_raw[0]) + hi) / 2
		var exploration := {"steps": mid, "searches": int(round(mid * searches_per_step))}
		# 段位表优先（作者：按段位定档）；没有段位表或猎手没配表才走强度规则
		var wanted := -1
		if hunter != null and not brackets.is_empty():
			wanted = hunter.strength_for_bracket(HunterMechanic.bracket_of_steps(brackets, mid))
		if wanted < 0:
			wanted = use_pool.clamp_strength(rule.wanted(node, 0.5, difficulty, scale_id, exploration)) if rule != null and use_pool != null else 0
		elif use_pool != null:
			wanted = use_pool.clamp_strength(wanted)
		var rates := {}
		var best := -1
		var best_gap := INF
		for tier in use_pool.strengths():
			var r := win_rate(spec, use_pool, enemies, items, node, tier, fights, seed)
			rates[str(tier)] = r
			var gap := absf(float(r["rate"]) - 0.5)
			if gap < best_gap:
				best_gap = gap
				best = tier
		out[k] = {"steps": steps_raw, "samples": int(dummy.get("samples", 0)), "hp": float(dummy.get("hp", 0.0)), "dps": float(dummy.get("dps", 0.0)),
			"wanted": wanted, "best": best, "rates": rates}
	return out


## 给人看的表
static func report_text(result: Dictionary, hunter_id: StringName) -> String:
	var lines: Array[String] = []
	lines.append("猎手 %s 对各段木桩的胜率（玩家赢的比例）；wanted = 猎手表里这一段的档（没配表就是规则给的），best = 最接近 50%% 的那一档" % hunter_id)
	var keys: Array = result.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for k in keys:
		var row: Dictionary = result[k]
		var steps: Array = row["steps"]
		var parts: Array[String] = []
		var tiers: Array = (row["rates"] as Dictionary).keys()
		tiers.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
		for t in tiers:
			var r: Dictionary = (row["rates"] as Dictionary)[t]
			parts.append("档 %s：%.0f%%" % [t, float(r["rate"]) * 100.0])
		var hi_text := str(int(steps[1])) if int(steps[1]) >= 0 else "∞"
		lines.append("第 %s～%s 步（%d 份样本，生命 %.0f，DPS %.1f）　wanted 档 %d　best 档 %d　　%s" % [
			int(steps[0]), hi_text, int(row["samples"]), float(row["hp"]), float(row["dps"]), int(row["wanted"]), int(row["best"]), "　".join(parts)])
	return "\n".join(lines)

## 主题奖励池的抽样统计（事件方案 2026-11-11 §8.4「检测和统计工具」）：池 × 章节 × 深度 × 难度，
## 每格列合格候选数、每件的理论概率、固定种子实抽 N 次的命中率与 95% 区间、偏离与否（±4 个标准差判偏），
## 以及期望的稀有度、定价、重量、格数与「是材料」的比例。生产抽取函数就是 [method RewardPool.draw]，这里不另写一套。
## 命令行外壳 `tools/reward_pool_stats.gd`；单元测试读 [method table] 的结果
class_name RewardPoolStats
extends RefCounted

const DEPTHS: Array[float] = [0.0, 0.5, 1.0]
const LEVELS: Array[int] = [0, 1, 2, 3]


## 一格：{"pool", "chapter", "depth", "level", "eligible", "rows": [{"item", "p", "hits", "rate", "lo", "hi", "off"}], "exp": {...}, "empty": bool}
static func cell(pool: RewardPool, items: ItemDatabase, chapter: StringName, depth: float, level: int, n: int, seed_: int) -> Dictionary:
	var probs := pool.probabilities(items, chapter, depth, level)
	var out := {"pool": String(pool.id), "chapter": String(chapter), "depth": depth, "level": level,
		"eligible": probs.size(), "rows": [], "empty": probs.is_empty(), "exp": {}}
	if probs.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var hits := {}
	for id in pool.draw(items, chapter, depth, level, rng, n):
		hits[id] = int(hits.get(id, 0)) + 1
	var ids: Array = probs.keys()
	Ids.sort(ids)
	var e_rarity := 0.0
	var e_value := 0.0
	var e_weight := 0.0
	var e_cells := 0.0
	var e_material := 0.0
	for id in ids:
		var p := float(probs[id])
		var k := int(hits.get(id, 0))
		var rate := float(k) / float(n)
		var sd := sqrt(p * (1.0 - p) / float(n))
		var half := 1.96 * sqrt(maxf(rate * (1.0 - rate), 1e-9) / float(n))
		(out["rows"] as Array).append({"item": String(id), "p": p, "hits": k, "rate": rate,
			"lo": maxf(0.0, rate - half), "hi": minf(1.0, rate + half), "off": absf(rate - p) > 4.0 * sd + 0.0001})
		var d := items.get_def(id)
		e_rarity += p * float(d.rarity)
		e_value += p * float(ItemValue.of(d))
		e_weight += p * float(ItemWeight.of(d))
		e_cells += p * float(d.cell_count())
		e_material += p * (1.0 if SearchSession.is_material(d) else 0.0)
	out["exp"] = {"rarity": e_rarity, "value": e_value, "weight": e_weight, "cells": e_cells, "material": e_material}
	return out


## 全表：每个池 × [param chapters] × [constant DEPTHS] × [constant LEVELS]
static func table(pools: Dictionary, items: ItemDatabase, chapters: Array, n: int = 10000, seed_: int = 20261111) -> Array:
	var out: Array = []
	var ids: Array = pools.keys()
	Ids.sort(ids)
	for pid in ids:
		for ch in chapters:
			for d in DEPTHS:
				for lv in LEVELS:
					out.append(cell(pools[pid], items, StringName(String(ch)), d, lv, n, hash("%s:%s:%s:%d:%d" % [pid, ch, d, lv, seed_])))
	return out


## 空格（没有合格候选）与偏离理论概率的行，给测试与审计
static func problems(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for c in rows:
		var cd := c as Dictionary
		if bool(cd["empty"]):
			out.append("%s @%s 深度 %.1f 难度 %d：没有合格候选" % [cd["pool"], cd["chapter"], cd["depth"], cd["level"]])
		for r in cd["rows"]:
			if bool((r as Dictionary)["off"]):
				out.append("%s @%s 深度 %.1f 难度 %d：%s 理论 %.4f 实际 %.4f" % [cd["pool"], cd["chapter"], cd["depth"], cd["level"], r["item"], r["p"], r["rate"]])
	return out


## Markdown：每个池一节，深度 × 难度一行一格
static func markdown(rows: Array, n: int) -> String:
	var lines: Array[String] = []
	lines.append("# 主题奖励池抽样统计")
	lines.append("")
	lines.append("每格固定种子有放回抽 %d 次。概率 = 理论（归一化权重），命中 = 实抽比例 [95%% 区间]，偏离 = 超出理论 ±4 个标准差。" % n)
	var cur := ""
	for c in rows:
		var cd := c as Dictionary
		var head := "%s / %s" % [cd["pool"], cd["chapter"]]
		if head != cur:
			cur = head
			lines.append("")
			lines.append("## " + head)
			lines.append("")
			lines.append("| 深度 | 难度 | 候选 | 每件 理论 → 命中 | 期望稀有度 | 期望定价 | 期望重量 | 期望格数 | 材料比例 |")
			lines.append("|---|---|---|---|---|---|---|---|---|")
		if bool(cd["empty"]):
			lines.append("| %.1f | %d | 0 | **没有合格候选** | | | | | |" % [cd["depth"], cd["level"]])
			continue
		var parts: Array[String] = []
		for r in cd["rows"]:
			parts.append("%s %.3f → %.3f [%.3f, %.3f]%s" % [r["item"], r["p"], r["rate"], r["lo"], r["hi"], " **偏离**" if r["off"] else ""])
		var ex: Dictionary = cd["exp"]
		lines.append("| %.1f | %d | %d | %s | %.2f | %.1f | %.1f | %.1f | %.0f%% |" % [cd["depth"], cd["level"], cd["eligible"], "<br>".join(parts),
			ex["rarity"], ex["value"], ex["weight"], ex["cells"], float(ex["material"]) * 100.0])
	return "\n".join(lines) + "\n"

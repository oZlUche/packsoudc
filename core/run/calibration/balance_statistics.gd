## 平衡检测方案（2026-11-10）§6.2～§6.3：扫表、猎手、真人日志共用的统计。纯计算，不碰战斗。
##
## - 比例：Wilson 95% 区间（独立的合成重复才用；固定枚举的集合只算这个集合的表现，报告里另注）。
## - 分位数：R 的第 7 种（线性插值），报告标注样本数与算法。
## - 配对比较：同一个配对标识的两场相减，自助法（bootstrap）给差值的区间；种子固定，可复现。
## - 真人数据按局聚类：自助法抽的是整局，不把同一局的每一步当独立样本。
## - 量不出来的写 null，不写 0；一场有效的都没有时比例也是 null（不是 0% 胜率）。
class_name BalanceStatistics
extends RefCounted

const Z95 := 1.959963984540054
const QUANTILE_METHOD := "R-7（线性插值）"
const PS: Array[float] = [0.1, 0.5, 0.9]
const BOOT_ITERS := 2000
const BOOT_SEED := 20261110
const OUTCOMES: Array[String] = [BattleMetrics.WIN, BattleMetrics.LOSS, BattleMetrics.DRAW, BattleMetrics.TIMEOUT]


## [param k] / [param n] 的 Wilson 区间：{k, n, p, lo, hi}；n 为 0 返回 null
static func wilson(k: int, n: int, z: float = Z95) -> Variant:
	if n <= 0:
		return null
	var p := float(k) / float(n)
	var z2 := z * z
	var den := 1.0 + z2 / n
	var mid := (p + z2 / (2.0 * n)) / den
	var half := z * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n)) / den
	return {"k": k, "n": n, "p": p, "lo": maxf(0.0, mid - half), "hi": minf(1.0, mid + half)}


## 去掉 null，剩下的转成浮点、从小到大
static func clean(values: Array) -> Array[float]:
	var out: Array[float] = []
	for v in values:
		if v == null:
			continue
		var f := float(v)
		if is_finite(f):
			out.append(f)
	out.sort()
	return out


## 排好序的数组的第 [param p] 分位（R-7）：h = (n − 1)p，在相邻两个之间线性插值。空数组返回 null
static func quantile_sorted(sorted: Array[float], p: float) -> Variant:
	var n := sorted.size()
	if n == 0:
		return null
	var h := (n - 1) * clampf(p, 0.0, 1.0)
	var lo := floori(h)
	var hi := mini(lo + 1, n - 1)
	return sorted[lo] + (h - lo) * (sorted[hi] - sorted[lo])


## {n, p10, p50, p90}（null 先去掉，n 是剩下的个数）
static func quantiles(values: Array) -> Dictionary:
	var s := clean(values)
	var out := {"n": s.size()}
	for p in PS:
		out["p%d" % roundi(p * 100.0)] = quantile_sorted(s, p)
	return out


static func mean(values: Array) -> Variant:
	var s := clean(values)
	if s.is_empty():
		return null
	var t := 0.0
	for v in s:
		t += v
	return t / s.size()


## 配对差：[param pairs] 每项 [甲, 乙]（缺一个的整对丢掉），差 = 甲 − 乙。返回 {n, diff, lo, hi, iters, seed}；没有对返回 diff 为 null
static func paired_bootstrap(pairs: Array, iters: int = BOOT_ITERS, p_seed: int = BOOT_SEED) -> Dictionary:
	var d: Array[float] = []
	for pr in pairs:
		var a: Array = pr
		if a.size() < 2 or a[0] == null or a[1] == null:
			continue
		d.append(float(a[0]) - float(a[1]))
	var out := {"n": d.size(), "diff": null, "lo": null, "hi": null, "iters": iters, "seed": p_seed}
	if d.is_empty():
		return out
	out["diff"] = mean(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var stats: Array[float] = []
	for _i in iters:
		var t := 0.0
		for _j in d.size():
			t += d[rng.randi_range(0, d.size() - 1)]
		stats.append(t / d.size())
	stats.sort()
	out["lo"] = quantile_sorted(stats, 0.025)
	out["hi"] = quantile_sorted(stats, 0.975)
	return out


## 按组（真人：一局 / 一个玩家）的自助法：每轮有放回地抽整组，算全部值的平均。[param values] 与 [param clusters] 一一对应。
## 返回 {n, clusters, mean, lo, hi, iters, seed}
static func cluster_bootstrap(values: Array, clusters: Array, iters: int = BOOT_ITERS, p_seed: int = BOOT_SEED) -> Dictionary:
	var by := {}
	var order: Array = []
	for i in mini(values.size(), clusters.size()):
		if values[i] == null:
			continue
		var c: Variant = clusters[i]
		if not by.has(c):
			by[c] = [] as Array[float]
			order.append(c)
		(by[c] as Array[float]).append(float(values[i]))
	var all: Array = []
	for c in order:
		all.append_array(by[c])
	var out := {"n": all.size(), "clusters": order.size(), "mean": mean(all), "lo": null, "hi": null, "iters": iters, "seed": p_seed}
	if order.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var stats: Array[float] = []
	for _i in iters:
		var t := 0.0
		var n := 0
		for _j in order.size():
			var vs: Array[float] = by[order[rng.randi_range(0, order.size() - 1)]]
			for v in vs:
				t += v
			n += vs.size()
		stats.append(t / n)
	stats.sort()
	out["lo"] = quantile_sorted(stats, 0.025)
	out["hi"] = quantile_sorted(stats, 0.975)
	return out


## 一组逐场记录 → 汇总。每行的形状见 [BalanceExperiment]：case_id、stage（失败在哪一步，成功为空）、error、simulated、valid、
## outcome、duration、hp_end、metrics（[method BattleMetrics.of]）。同一 case_id 出现两次只算第一次（记进 duplicates）。
## 计数：requested（请求）= 去重后的行数，generated（造出了双方）、simulated（打完了）、valid（有效）、failed = requested − valid
static func summarize(cases: Array) -> Dictionary:
	var seen := {}
	var dup := 0
	var rows: Array[Dictionary] = []
	for r in cases:
		var row := r as Dictionary
		var id := String(row.get("case_id", ""))
		if id != "" and seen.has(id):
			dup += 1
			continue
		seen[id] = true
		rows.append(row)
	var errors := {}
	var generated := 0
	var simulated := 0
	var valid: Array[Dictionary] = []
	for row in rows:
		if String(row.get("stage", "")) != "generate":
			generated += 1
		if bool(row.get("simulated", false)):
			simulated += 1
		if bool(row.get("valid", false)):
			valid.append(row)
		else:
			var why := String(row.get("error", "invalid"))
			errors[why] = int(errors.get(why, 0)) + 1
	var out := {
		"requested": rows.size(), "generated": generated, "simulated": simulated, "valid": valid.size(),
		"failed": rows.size() - valid.size(), "duplicates": dup, "errors": errors, "quantile_method": QUANTILE_METHOD,
	}
	var counts := {}
	for o in OUTCOMES:
		counts[o] = 0
	for row in valid:
		var o := String(row.get("outcome", ""))
		counts[o] = int(counts.get(o, 0)) + 1
	out["outcomes"] = counts
	out["win_rate"] = wilson(int(counts[BattleMetrics.WIN]), valid.size())
	out["draw_rate"] = wilson(int(counts[BattleMetrics.DRAW]), valid.size())
	out["timeout_rate"] = wilson(int(counts[BattleMetrics.TIMEOUT]), valid.size())
	out["duration"] = _by_outcome(valid, func(row: Dictionary) -> Variant: return row.get("duration"))
	out["hp_end"] = [
		_by_outcome(valid, func(row: Dictionary) -> Variant: return _at(row.get("hp_end"), 0)),
		_by_outcome(valid, func(row: Dictionary) -> Variant: return _at(row.get("hp_end"), 1)),
	]
	var m := func(row: Dictionary, key: String, side: int) -> Variant: return _at((row.get("metrics", {}) as Dictionary).get(key), side)
	var no_hit := [0, 0]
	var with_metrics := 0
	var damage := [{}, {}]
	for row in valid:
		var mt: Dictionary = row.get("metrics", {})
		if mt.is_empty():
			continue
		with_metrics += 1
		for s in 2:
			if _at(mt.get("first_damage"), s) == null:
				no_hit[s] += 1
			var dmg: Dictionary = _at(mt.get("damage"), s) if _at(mt.get("damage"), s) is Dictionary else {}
			for k in dmg:
				damage[s][k] = float(damage[s].get(k, 0.0)) + float(dmg[k])
	out["no_hit"] = [wilson(no_hit[0], with_metrics), wilson(no_hit[1], with_metrics)]
	out["damage"] = [_shares(damage[0]), _shares(damage[1])]
	for key in ["fires", "first_damage", "min_hp", "first_low_hp", "low_hp_time"]:
		var sides: Array = []
		for s in 2:
			var vals: Array = []
			for row in valid:
				vals.append(m.call(row, key, s))
			sides.append(quantiles(vals))
		out[key] = sides
	return out


## 一项按结果分层的分位：{all, win, loss, draw, timeout}
static func _by_outcome(rows: Array[Dictionary], pick: Callable) -> Dictionary:
	var out := {}
	var all: Array = []
	var per := {}
	for o in OUTCOMES:
		per[o] = []
	for row in rows:
		var v: Variant = pick.call(row)
		all.append(v)
		var o := String(row.get("outcome", ""))
		if per.has(o):
			(per[o] as Array).append(v)
	out["all"] = quantiles(all)
	for o in OUTCOMES:
		out[o] = quantiles(per[o])
	return out


## 伤害分类合计 → {total, 各类: {amount, share}}；合计为 0 时占比为 null
static func _shares(d: Dictionary) -> Dictionary:
	var total := 0.0
	for k in d:
		total += float(d[k])
	var out := {"total": total}
	for k in ["direct", "indirect", "true", "unknown"]:
		var a := float(d.get(k, 0.0))
		out[k] = {"amount": a, "share": (a / total as Variant) if total > 0.0 else null}
	return out


static func _at(v: Variant, i: int) -> Variant:
	return (v as Array)[i] if v is Array and i < (v as Array).size() else null

## 难度候选实验（报告 303，材料与难度方案 §7.2）：同一批木桩、同一批敌人实例、同一套种子，基线和每个改数各跑一遍，
## 逐场配对（case_id 一一对应）算胜率差和时长差（配对自助法 95% 区间）。只出候选表，不改资产 —— 正式值等作者定。
##
## 实验：
## - D1 brute 局部：覆盖测试只跑 brute，原值 / 生命 -10% / 格挡 -10% 分开跑（只改 brute 自己的基线，不动档位表）；
## - D3 节奏拉长：频率测试（真实地图上的战斗点），双方最大生命 ×1.15 / ×1.30。
## 命令行外壳 `tools/difficulty_candidates.gd`
class_name DifficultyCandidates
extends RefCounted

const EXPERIMENTS := {
	"D1": {"mode": "coverage", "only_enemies": ["brute"], "variants": {
		"base": {}, "hp_-10%": {"foe": {"brute": {"max_hp": 0.9}}}, "block_-10%": {"foe": {"brute": {"block": 0.9}}}}},
	"D3": {"mode": "frequency", "variants": {"base": {}, "hp_x1.15": {"hp": 1.15}, "hp_x1.30": {"hp": 1.3}}},
}


## 一个实验的全部改数各跑一遍：{变体名: run 的结果}（[BalanceExperiment.run]）
static func run_all(exp_id: String, dummies: Dictionary, ctx: Dictionary) -> Dictionary:
	var spec: Dictionary = EXPERIMENTS[exp_id]
	var out := {}
	for v in spec["variants"]:
		var c := ctx.duplicate()
		c["mode"] = spec["mode"]
		c["only_enemies"] = spec.get("only_enemies", [])
		c["mutation"] = spec["variants"][v]
		out[v] = BalanceExperiment.run(dummies, c)     # 木桩每次现编译（[method BalanceExperiment._groups]），改生命不串
	return out


## 变体对基线逐场配对：按（段, 档）分格（[param by_archetype] 再按流派分）。每格 {archetype, bracket, tier, n, base_win, win, win_diff{diff,lo,hi}, base_dur, dur, dur_diff}
static func compare(base_cases: Array, var_cases: Array, by_archetype: bool = false) -> Array:
	var by_id := {}
	for r in base_cases:
		by_id[String((r as Dictionary)["case_id"])] = r
	var acc := {}
	for r in var_cases:
		var row := r as Dictionary
		var b: Dictionary = by_id.get(String(row["case_id"]), {})
		if b.is_empty():
			continue
		var arch := String(row.get("archetype", "")) if by_archetype else ""
		var key := "%d/%d/%s" % [int(row["bracket"]), int(row["tier"]), arch]
		var a: Dictionary = acc.get_or_add(key, {"archetype": arch, "bracket": int(row["bracket"]), "tier": int(row["tier"]), "win": [], "dur": [], "bw": [], "vw": [], "bd": [], "vd": []})
		var wv: Variant = _won(row)
		var wb: Variant = _won(b)
		(a["win"] as Array).append([wv, wb])
		(a["dur"] as Array).append([row.get("duration") if row["valid"] else null, b.get("duration") if b["valid"] else null])
		(a["bw"] as Array).append(wb)
		(a["vw"] as Array).append(wv)
		(a["bd"] as Array).append(b.get("duration") if b["valid"] else null)
		(a["vd"] as Array).append(row.get("duration") if row["valid"] else null)
	var keys: Array = acc.keys()
	keys.sort_custom(func(x: String, y: String) -> bool:
		var kx := x.get_slice("/", 0).to_int() * 10 + x.get_slice("/", 1).to_int()
		var ky := y.get_slice("/", 0).to_int() * 10 + y.get_slice("/", 1).to_int()
		return kx < ky if kx != ky else x.get_slice("/", 2) < y.get_slice("/", 2))
	var out: Array = []
	for k in keys:
		var a: Dictionary = acc[k]
		out.append({"archetype": a["archetype"], "bracket": a["bracket"], "tier": a["tier"], "n": (a["win"] as Array).size(),
			"base_win": BalanceStatistics.mean(a["bw"]), "win": BalanceStatistics.mean(a["vw"]),
			"win_diff": BalanceStatistics.paired_bootstrap(a["win"]),
			"base_dur": BalanceStatistics.quantiles(a["bd"]).get("p50"), "dur": BalanceStatistics.quantiles(a["vd"]).get("p50"),
			"dur_diff": BalanceStatistics.paired_bootstrap(a["dur"])})
	return out


static func _won(row: Dictionary) -> Variant:
	if not row.get("valid", false):
		return null
	return 1.0 if row.get("outcome", "") == BattleMetrics.WIN else 0.0


static func _pct(v: Variant) -> String:
	return "—" if v == null else "%.0f%%" % (float(v) * 100.0)


static func _diff_pct(d: Dictionary) -> String:
	if d.get("diff") == null:
		return "—"
	return "%+.1f（%+.1f～%+.1f）" % [float(d["diff"]) * 100.0, float(d["lo"]) * 100.0, float(d["hi"]) * 100.0]


static func _diff_s(d: Dictionary) -> String:
	if d.get("diff") == null:
		return "—"
	return "%+.2f（%+.2f～%+.2f）" % [float(d["diff"]), float(d["lo"]), float(d["hi"])]


static func _s(v: Variant) -> String:
	return "—" if v == null else "%.2f" % float(v)


## 一个实验的候选表（markdown）。[param runs] 是 [method run_all] 的结果
static func markdown(exp_id: String, runs: Dictionary, header: Array[String]) -> String:
	var lines: Array[String] = ["## %s" % exp_id, ""]
	lines.append_array(header)
	lines.append("")
	var base: Array = (runs.get("base", {}) as Dictionary).get("cases", [])
	for v in runs:
		if v == "base":
			continue
		lines.append("### %s 对基线" % v)
		lines.append("")
		lines.append("胜率差、时长差为逐场配对的平均差，括号里是 95% 区间（配对自助法）；段 = 木桩所在的段，档 = 敌人强度，段与档相同的是同阶段对照。")
		lines.append("")
		lines.append("| 段 | 档 | 场数 | 基线胜率 | 改后胜率 | 胜率差（百分点） | 基线时长中位 | 改后时长中位 | 时长差（秒） |")
		lines.append("|---|---|---|---|---|---|---|---|---|")
		for row in compare(base, (runs[v] as Dictionary).get("cases", [])):
			var r := row as Dictionary
			var mark := "**" if r["bracket"] == r["tier"] else ""
			lines.append("| %s%d%s | %d | %d | %s | %s | %s | %s | %s | %s |" % [mark, r["bracket"], mark, r["tier"], r["n"], _pct(r["base_win"]), _pct(r["win"]),
				_diff_pct(r["win_diff"]), _s(r["base_dur"]), _s(r["dur"]), _diff_s(r["dur_diff"])])
		lines.append("")
		lines.append("同阶段（段 = 档）按流派分：")
		lines.append("")
		lines.append("| 流派 | 段 | 场数 | 基线胜率 | 改后胜率 | 胜率差（百分点） | 时长差（秒） |")
		lines.append("|---|---|---|---|---|---|---|")
		for row in compare(base, (runs[v] as Dictionary).get("cases", []), true):
			var r := row as Dictionary
			if r["bracket"] != r["tier"]:
				continue
			lines.append("| %s | %d | %d | %s | %s | %s | %s |" % [r["archetype"], r["bracket"], r["n"], _pct(r["base_win"]), _pct(r["win"]),
				_diff_pct(r["win_diff"]), _diff_s(r["dur_diff"])])
		lines.append("")
	return "\n".join(lines) + "\n"

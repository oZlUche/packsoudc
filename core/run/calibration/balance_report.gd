## 平衡检测方案（2026-11-10）§6.4：实验的 summary.csv 与 report.md 都从同一份 summary（[method BalanceExperiment.summarize]）印出来，不各算一遍。
class_name BalanceReport
extends RefCounted

const CSV_HEAD: Array[String] = ["cell", "archetype", "bracket", "tier", "enemy", "requested", "generated", "simulated", "valid", "failed",
	"win", "loss", "draw", "timeout", "win_rate", "win_lo", "win_hi", "dur_p10", "dur_p50", "dur_p90", "hp_win_p50", "foe_hp_loss_p50",
	"no_hit_rate", "min_hp_p50", "low_hp_time_p50", "first_damage_p50"]

const MODE_TEXT := {
	BalanceExperiment.COVERAGE: "覆盖测试：显式枚举池里每个敌人 × 每一档，找一边倒的对局；不看节点条件，不代表一局里遇到的频率",
	BalanceExperiment.FREQUENCY: "频率测试：从照正式开局生成的地图上取真的战斗点（带地形种类与危险度），按档抽；随机点与搜索遭遇不在图上，没算进来",
	BalanceExperiment.BARE_NODE: "假节点对照：没有地形、危险度 0 的战斗点，和旧扫表一样；不能当作真实地图难度",
}


static func csv(summary: Dictionary) -> String:
	var lines: Array[String] = [",".join(CSV_HEAD)]
	for c in _cells(summary):
		var s: Dictionary = summary["cells"][c]
		var meta: Dictionary = (summary.get("cell_meta", {}) as Dictionary).get(c, {})
		var oc: Dictionary = s["outcomes"]
		var wr: Variant = s["win_rate"]
		var vals: Array = [c, meta.get("archetype", ""), meta.get("bracket", ""), meta.get("tier", ""), meta.get("enemy", ""),
			s["requested"], s["generated"], s["simulated"], s["valid"], s["failed"],
			oc[BattleMetrics.WIN], oc[BattleMetrics.LOSS], oc[BattleMetrics.DRAW], oc[BattleMetrics.TIMEOUT],
			_field(wr, "p"), _field(wr, "lo"), _field(wr, "hi"),
			s["duration"]["all"]["p10"], s["duration"]["all"]["p50"], s["duration"]["all"]["p90"],
			s["hp_end"][0][BattleMetrics.WIN]["p50"], s["hp_end"][1][BattleMetrics.LOSS]["p50"],
			_field(s["no_hit"][0], "p"), s["min_hp"][0]["p50"], s["low_hp_time"][0]["p50"], s["first_damage"][0]["p50"]]
		var cols: Array[String] = []
		for v in vals:
			cols.append(_csv_cell(v))
		lines.append(",".join(cols))
	return "\n".join(lines) + "\n"


static func markdown(summary: Dictionary, manifest: Dictionary, title: String) -> String:
	var cfg: Dictionary = manifest.get("config", {})
	var mode := String(cfg.get("mode", ""))
	var lines: Array[String] = ["# " + title, ""]
	lines.append("- 实验 `%s`，来源 `%s`（合成木桩，不是真人），构建 `%s`" % [manifest.get("experiment_id", "?"), manifest.get("source", "?"), manifest.get("build_id", "?")])
	lines.append("- " + String(MODE_TEXT.get(mode, mode)))
	lines.append("- 每格 %s 场，种子 %s，时限 %s 秒；分位数 %s；区间是 Wilson 95%%（每场是独立的合成重复）" % [
		cfg.get("fights", "?"), cfg.get("seed", "?"), cfg.get("time_limit", "?"), BalanceStatistics.QUANTILE_METHOD])
	lines.append("- 「平」是同一刻一起倒下，「超时」是时限到了都还活着；胜率 = 胜 / 有效场数，平和超时另列，不折算")
	lines.append("")
	var t: Dictionary = summary["total"]
	lines.append("## 场数")
	lines.append("")
	lines.append("| 请求 | 造出双方 | 打完 | 有效 | 失败 | 重复 |")
	lines.append("|---:|---:|---:|---:|---:|---:|")
	lines.append("| %d | %d | %d | %d | %d | %d |" % [t["requested"], t["generated"], t["simulated"], t["valid"], t["failed"], t["duplicates"]])
	lines.append("")
	if not (t["errors"] as Dictionary).is_empty():
		var errs: Array[String] = []
		for k in t["errors"]:
			errs.append("%s %d" % [k, t["errors"][k]])
		lines.append("失败原因：" + "，".join(errs) + "。失败的不算输，也不从分母里悄悄去掉：上表的「有效」才是分母。")
		lines.append("")
	lines.append("## 每格")
	lines.append("")
	lines.append("| 格 | 有效 / 请求 | 胜 | 95% 区间 | 平 | 超时 | 时长 p10 / p50 / p90 | 赢时余血 p50 | 输时对方余血 p50 | 我方没打出伤害 | 我方最低血 p50 |")
	lines.append("|---|---:|---:|---|---:|---:|---|---:|---:|---:|---:|")
	for c in _cells(summary):
		var s: Dictionary = summary["cells"][c]
		var oc: Dictionary = s["outcomes"]
		var wr: Variant = s["win_rate"]
		var d: Dictionary = s["duration"]["all"]
		lines.append("| %s | %d / %d | %s | %s | %d | %d | %s / %s / %s | %s | %s | %s | %s |" % [c, s["valid"], s["requested"], _pct(_field(wr, "p")),
			("%s～%s" % [_pct(_field(wr, "lo")), _pct(_field(wr, "hi"))]) if wr != null else "—", oc[BattleMetrics.DRAW], oc[BattleMetrics.TIMEOUT],
			_num(d["p10"]), _num(d["p50"]), _num(d["p90"]), _pct(s["hp_end"][0][BattleMetrics.WIN]["p50"]), _pct(s["hp_end"][1][BattleMetrics.LOSS]["p50"]),
			_pct(_field(s["no_hit"][0], "p")), _pct(s["min_hp"][0]["p50"])])
	lines.append("")
	var pairs: Array = summary.get("pairs", [])
	if not pairs.is_empty():
		lines.append("## 配对：变体减对照")
		lines.append("")
		lines.append("同段、同档、同序号（同一个敌人、同一串随机数）的两场相减；区间是配对自助法 95%%（%d 轮，种子 %d）。区间跨过 0 就是没分出来" % [BalanceStatistics.BOOT_ITERS, BalanceStatistics.BOOT_SEED])
		lines.append("")
		lines.append("| 变体 | 对照 | 段 | 档 | 对数 | 胜率差（百分点） | 区间 | 时长差（秒） |")
		lines.append("|---|---|---:|---:|---:|---:|---|---:|")
		for p in pairs:
			var w: Dictionary = p["win_diff"]
			var dd: Dictionary = p["duration_diff"]
			lines.append("| %s | %s | %d | %d | %d | %s | %s | %s |" % [p["variant"], p["against"], p["bracket"], p["tier"], w["n"],
				_pts(w["diff"]), ("%s～%s" % [_pts(w["lo"]), _pts(w["hi"])]) if w["diff"] != null else "—", _num(dd["diff"])])
		lines.append("")
	var hunter: Dictionary = summary.get("hunter", {})
	if not hunter.is_empty():
		lines.append("## 猎手：每段的档")
		lines.append("")
		lines.append("wanted = 现在的规则给这一段的档；best = 有效场里胜率离五成最近的档（区间宽时这个「最近」分不出来，看区间）")
		lines.append("")
		lines.append("| 段 | wanted | best | best 的胜率 | 95% 区间 |")
		lines.append("|---:|---:|---:|---:|---|")
		var ks: Array = hunter.keys()
		ks.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
		for k in ks:
			var h: Dictionary = hunter[k]
			var r: Variant = h["rate"]
			lines.append("| %s | %s | %s | %s | %s |" % [k, "%d" % int(h["wanted"]) if h["wanted"] != null else "—", "%d" % int(h["best"]) if h["best"] != null else "—",
				_pct(_field(r, "p")), ("%s～%s" % [_pct(_field(r, "lo")), _pct(_field(r, "hi"))]) if r != null else "—"])
		lines.append("")
	var pop: Dictionary = summary.get("population", {})
	if not pop.is_empty():
		lines.append("## 图上的点（频率测试的总体）")
		lines.append("")
		lines.append("共 %d 个带敌人的战斗点。" % int(pop.get("nodes", 0)))
		lines.append("")
		for key in ["strength", "kind", "danger", "enemy"]:
			var d: Dictionary = pop.get(key, {})
			var keys: Array = d.keys()
			keys.sort()
			var parts: Array[String] = []
			for k in keys:
				parts.append("%s %d" % [k if k != "" else "（空）", d[k]])
			lines.append("- %s：%s" % [{"strength": "档", "kind": "地形种类", "danger": "危险度", "enemy": "敌人"}[key], "，".join(parts)])
		lines.append("")
	return "\n".join(lines) + "\n"


static func _cells(summary: Dictionary) -> Array:
	var keys: Array = (summary["cells"] as Dictionary).keys()
	keys.sort()
	return keys


static func _field(d: Variant, key: String) -> Variant:
	return (d as Dictionary).get(key) if d is Dictionary else null


static func _pct(v: Variant) -> String:
	return "—" if v == null else "%.0f%%" % (float(v) * 100.0)


static func _pts(v: Variant) -> String:
	return "—" if v == null else "%+.1f" % (float(v) * 100.0)


static func _num(v: Variant) -> String:
	return "—" if v == null else "%.1f" % float(v)


static func _csv_cell(v: Variant) -> String:
	if v == null:
		return ""
	if v is float or v is int:     # 读回的 JSON 整数会变成浮点：整数一律按整数印，两边才一样
		var f := float(v)
		if not is_finite(f):
			return ""
		return "%d" % int(f) if f == floorf(f) and absf(f) < 1e15 else String.num(f, 6)
	var s := str(v)
	return "\"%s\"" % s.replace("\"", "\"\"") if s.contains(",") or s.contains("\"") else s

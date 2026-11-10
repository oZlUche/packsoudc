## 平衡检测方案（2026-11-10）§8.2：一场战斗的体验诊断。把诊断包重跑出来的结果、观看记录（[ViewingSession]）和战前战后的状态放在一起，
## 分五节写：原因可见性证据、准备有效性、过程节奏、后果差异、未知项。不替玩家下「为什么输」的唯一结论，只摆事实。
##
## 缺什么就写进未知项：没有观看记录就不推算玩家看了多久，没有战后状态就不说得失，复现对不上就整份只作参考。
class_name BattleExperience
extends RefCounted

## 决定这一场的伤害：取落败一方挨的伤害里，最短的、装得下这么多份额的时间窗
const DECISIVE_SHARE := 0.5
const OUTCOME_TEXT := {BattleMetrics.WIN: "我方胜", BattleMetrics.LOSS: "我方负", BattleMetrics.TIMEOUT: "超时", BattleMetrics.DRAW: "平局"}
const WINNER_TEXT := {0: "我方胜", 1: "对方胜"}
## 血线取几个点
const HP_SAMPLES := 10
## 准备有效性最多试几件
const FACTOR_ITEMS := 8


## 主入口。[param result] 是重跑（或原始）的结果，[param specs] 是双方输入（按道具 id 归伤害），[param viewing] 是观看记录（可空），
## [param factors] 是准备有效性那一节（[method factor_rows] 的结果，可空），[param reproduced] = 重跑和包里记的结果一样
static func analyze(result: BattleResult, specs: Array, limit: float, viewing: Dictionary = {}, factors: Array = [], reproduced: Variant = null) -> Dictionary:
	var m := BattleMetrics.of(result, limit, specs)
	var out := {"battle_id": String(viewing.get("battle_id", "")), "outcome": m["outcome"], "duration": m["duration"], "hp_end": m["hp_end"]}
	out["cause"] = _cause(result, m, viewing)
	out["preparation"] = factors
	out["rhythm"] = _rhythm(result, m, viewing)
	out["consequence"] = _consequence(result, viewing)
	out["unknowns"] = _unknowns(viewing, factors, reproduced)
	return out


## 一、原因可见性：双方伤害的主要来源（份额）、关键状态与耐力事件、决定性伤害集中在多短的窗里，那个窗在屏上放了多久
static func _cause(result: BattleResult, m: Dictionary, viewing: Dictionary) -> Dictionary:
	var top: Array = []
	for s in 2:
		var by: Dictionary = (m["damage_by_item"] as Array)[s]
		var total := 0.0
		for k in by:
			total += float(by[k])
		var rows: Array = []
		for k in by:
			rows.append({"item": k, "amount": float(by[k]), "share": (float(by[k]) / total as Variant) if total > 0.0 else null})
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["amount"]) > float(b["amount"]))
		top.append(rows.slice(0, 3))
	var statuses := [{}, {}]
	var stamina_empty: Array = [null, null]
	for e in result.log:
		if e.side != 0 and e.side != 1:
			continue
		if e.name == BattleEvent.STATUS_STACKED and int(e.payload.get("delta", 0)) > 0:
			var id := String(e.payload.get("buff", ""))
			statuses[e.side][id] = int(statuses[e.side].get(id, 0)) + int(e.payload["delta"])
		elif e.name == BattleEvent.RESOURCE_CHANGED and String(e.payload.get("key", "")) == String(BattleStats.RES_STAMINA) \
				and int(e.payload.get("current", 1)) <= 0 and stamina_empty[e.side] == null:
			stamina_empty[e.side] = StatMath.to_float(e.time)
	var window := decisive_window(result)
	if not window.is_empty():
		window["shown"] = _shown(window, viewing)
	return {"top_damage": top, "statuses_taken": statuses, "stamina_empty_at": stamina_empty, "decisive_window": window}


## 落败一方挨的伤害里，装得下 [constant DECISIVE_SHARE] 份额的最短时间窗：{side, start, end, share, total}；没有胜方返回空
static func decisive_window(result: BattleResult) -> Dictionary:
	if result.winner != 0 and result.winner != 1:
		return {}
	var loser := 1 - result.winner
	var hits: Array = []
	var total := 0.0
	for e in result.log:
		if e.name != BattleEvent.DAMAGE or e.side != loser or e.payload.get("cancelled", false):
			continue
		var a := StatMath.to_float(absi(e.get_int(&"amount")))
		if a <= 0.0:
			continue
		hits.append([StatMath.to_float(e.time), a])
		total += a
	if hits.is_empty():
		return {}
	var best := {"side": loser, "start": hits[0][0], "end": hits[hits.size() - 1][0], "share": 1.0, "total": total}
	var j := 0
	var acc := 0.0
	for i in hits.size():     # 双指针：右端每推一格，左端尽量收
		acc += float(hits[i][1])
		while j < i and acc - float(hits[j][1]) >= DECISIVE_SHARE * total:
			acc -= float(hits[j][1])
			j += 1
		if acc >= DECISIVE_SHARE * total and float(hits[i][0]) - float(hits[j][0]) < float(best["end"]) - float(best["start"]):
			best = {"side": loser, "start": hits[j][0], "end": hits[i][0], "share": acc / total, "total": total}
	return best


## 这个窗在屏上：被跳过了没有、按当时的倍速放了多少秒（墙上时间，扣掉暂停另算）。没有观看记录返回 null
static func _shown(window: Dictionary, viewing: Dictionary) -> Variant:
	if viewing.is_empty():
		return null
	var skip_at: Variant = viewing.get("skip_at_sim", null)
	if skip_at != null and float(skip_at) <= float(window["start"]):
		return {"skipped": true, "display_sec": 0.0}
	var end := float(window["end"]) if skip_at == null else minf(float(window["end"]), float(skip_at))
	var speed := _speed_at(viewing, float(window["start"]))
	return {"skipped": skip_at != null and float(skip_at) < float(window["end"]), "speed": speed,
		"display_sec": ((end - float(window["start"])) / speed as Variant) if speed > 0.0 else null}


## 回放走到模拟时刻 [param sim] 时的倍速（最后一次在它之前的切换）
static func _speed_at(viewing: Dictionary, sim: float) -> float:
	var speed := 1.0
	for s in viewing.get("speeds", []):
		var row := s as Dictionary
		if float(row.get("sim", 0.0)) <= sim and row.get("speed", null) != null:
			speed = float(row["speed"])
	return speed


## 三、过程节奏：双方出手数、第一次有意义的交互（谁先打出伤害）、双方血线（等距取点）、跳过与倍速
static func _rhythm(result: BattleResult, m: Dictionary, viewing: Dictionary) -> Dictionary:
	var fd: Array = m["first_damage"]
	var first: Variant = null
	for v in fd:
		if v != null and (first == null or float(v) < float(first)):
			first = v
	var dur := result.duration_sec()
	var lines := [[], []]
	var cur: Array = [1.0, 1.0]
	var marks: Array[float] = []
	for k in HP_SAMPLES + 1:
		marks.append(dur * k / HP_SAMPLES)
	var mi := 0
	for e in result.log:
		var t := StatMath.to_float(e.time)
		while mi < marks.size() and marks[mi] < t:
			for s in 2:
				lines[s].append(cur[s])
			mi += 1
		if e.name == BattleEvent.RESOURCE_CHANGED and String(e.payload.get("key", "")) == "hp" and (e.side == 0 or e.side == 1):
			var mx := float(e.payload.get("max", 0))
			cur[e.side] = float(e.payload.get("current", 0)) / mx if mx > 0.0 else 0.0
	while mi < marks.size():
		for s in 2:
			lines[s].append(cur[s])
		mi += 1
	var out := {"fires": m["fires"], "items_fired": m["items_fired"], "first_interaction": first, "first_damage": fd, "hp_line": lines,
		"hp_marks": marks, "speeds": null, "skipped": null, "skip_at_sim": null, "presentation_elapsed": null}
	if not viewing.is_empty():
		for k in ["speeds", "skipped", "skip_at_sim", "presentation_elapsed"]:
			out[k] = viewing.get(k, null)
	return out


## 四、后果差异：这一场的战果（胜负、余血）；整局的变化（战前战后的体力、钱、件数、步数）；屏上显示了什么这一版不记
static func _consequence(result: BattleResult, viewing: Dictionary) -> Dictionary:
	var before: Dictionary = viewing.get("before", {})
	var after: Dictionary = viewing.get("after", {})
	var delta := {}
	for k in ["vitality", "coins", "items", "steps"]:
		var a: Variant = before.get(k, null)
		var b: Variant = after.get(k, null)
		delta[k] = (float(b) - float(a) as Variant) if a != null and b != null else null
	return {"battle": {"winner": result.winner, "hp_end": [BattleMetrics.hp_ratio(result, 0), BattleMetrics.hp_ratio(result, 1)]},
		"run_before": before, "run_after": after, "run_delta": delta, "ui_shown": null}


## 五、未知项：缺的东西逐条写出来，不默认为正常
static func _unknowns(viewing: Dictionary, factors: Array, reproduced: Variant) -> Array[String]:
	var out: Array[String] = []
	if reproduced == null:
		out.append("没有和原始结果比对过（不是从诊断包重跑的）")
	elif not bool(reproduced):
		out.append("重跑和包里记的结果不一样：这份报告只作参考")
	if viewing.is_empty():
		out.append("没有观看记录：玩家实际看了多久、有没有跳过、倍速都不知道（不能从模拟时长推算）")
	else:
		if not bool(viewing.get("revealed", false)):
			out.append("没看到结果揭晓就离开了")
		if (viewing.get("after", {}) as Dictionary).is_empty():
			out.append("没有战后状态：整局得失不知道")
		if (viewing.get("before", {}) as Dictionary).is_empty():
			out.append("没有战前状态：整局得失不知道")
		elif (viewing.get("after", {}) as Dictionary).size() > 0:
			out.append("战后状态取在离开回放屏时：掉落还没捡、求饶还没定")
	out.append("屏上显示了哪些字段这一版不记")
	if factors.is_empty():
		out.append("没有做准备有效性的配对对照")
	out.append("耐力：引擎没有「耐力不够、这一下没出手」的事件，只记了耐力见底的时刻，不能据此断言停火原因")
	return out


## 二、准备有效性：我方每件（最多 [constant FACTOR_ITEMS] 件，按造成的伤害排）拿掉以后，配对多种子的胜率 / 余血 / 时长差。
## 编译后拿掉做不到单因素：每行带上连带变化
static func factor_rows(me: CombatantSpec, foe: CombatantSpec, limit: float, overtime: OvertimeRules, base_seed: int, n: int = BattleFactor.SEEDS) -> Array:
	var seeds := BattleFactor.seeds_from(base_seed, n)
	var out: Array = []
	var uids: Array[int] = []
	for it in me.items:
		if not uids.has(it.source_uid):
			uids.append(it.source_uid)
	for uid in uids.slice(0, FACTOR_ITEMS):
		var cut := BattleFactor.without_item(me, uid)
		if cut["spec"] == null:
			continue
		var p := BattleFactor.paired(me, cut["spec"], foe, seeds, limit, overtime)
		out.append({"removed": cut["removed"], "uid": uid, "n": p["n"], "win_with": p["win_a"], "win_without": p["win_b"],
			"win_diff": p["win_diff"], "hp_diff": p["hp_diff"], "duration_diff": p["duration_diff"], "collateral": cut["collateral"]})
	return out


## 给人看的 Markdown
static func markdown(r: Dictionary) -> String:
	var bid := String(r.get("battle_id", ""))
	var lines: Array[String] = ["# 战斗体验诊断" + ("" if bid == "" else " " + bid), ""]
	lines.append("结果：%s，%.1f 秒，余血 我方 %s / 对方 %s" % [OUTCOME_TEXT.get(r["outcome"], r["outcome"]), float(r["duration"]), _pct(r["hp_end"][0]), _pct(r["hp_end"][1])])
	lines.append("")
	var c: Dictionary = r["cause"]
	lines.append_array(["## 一 原因可见性", ""])
	for s in 2:
		var parts: Array[String] = []
		for row in c["top_damage"][s]:
			parts.append("%s %.0f（%s）" % [row["item"], float(row["amount"]), _pct(row["share"])])
		lines.append("- %s打出的伤害主要来自：%s" % ["我方" if s == 0 else "对方", "，".join(parts) if not parts.is_empty() else "没有"])
	for s in 2:
		var st: Dictionary = c["statuses_taken"][s]
		var parts: Array[String] = []
		for k in st:
			parts.append("%s ×%d" % [k, st[k]])
		lines.append("- %s身上上过的状态：%s" % ["我方" if s == 0 else "对方", "，".join(parts) if not parts.is_empty() else "没有"])
	lines.append("- 耐力见底：我方 %s，对方 %s" % [_sec(c["stamina_empty_at"][0]), _sec(c["stamina_empty_at"][1])])
	lines.append("- 伤害多的不一定是取胜关键：控制、回复与防御也可能决定结果（看第二节的配对对照）")
	var w: Dictionary = c["decisive_window"]
	if w.is_empty():
		lines.append("- 没有胜方，不算决定性窗口")
	else:
		var shown: Variant = w.get("shown", null)
		var shown_text := "没有观看记录" if shown == null else ("被跳过了" if bool(shown["skipped"]) and float(shown.get("display_sec", 0.0)) <= 0.0 else
			"屏上约 %s 秒（%s 倍速）%s" % [_num(shown.get("display_sec")), _num(shown.get("speed")), "，后半段被跳过" if bool(shown["skipped"]) else ""])
		lines.append("- 落败一方挨的伤害有 %s 集中在 %.1f～%.1f 秒（%.1f 秒内）；%s" % [_pct(w["share"]), float(w["start"]), float(w["end"]),
			float(w["end"]) - float(w["start"]), shown_text])
	lines.append("")
	lines.append_array(["## 二 准备有效性", ""])
	var f: Array = r["preparation"]
	if f.is_empty():
		lines.append("没有做。")
	else:
		lines.append("每行：拿掉我方这一件，同样 %d 个种子配对重打；差 = 带着 − 拿掉（百分点 / 秒），区间是配对自助法 95%%。" % int(f[0]["n"])
			+ "差值是这一场条件下的边际变化，几行不能相加成整体贡献；编译后拿掉不是严格的单因素，连带变化写在最后一列")
		lines.append("")
		lines.append("| 拿掉 | 带着胜率 | 拿掉胜率 | 胜率差 | 区间 | 余血差 | 时长差 | 连带变化 |")
		lines.append("|---|---:|---:|---:|---|---:|---:|---|")
		for row in f:
			var d: Dictionary = row["win_diff"]
			lines.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % [row["removed"], _pct(_p(row["win_with"])), _pct(_p(row["win_without"])),
				_pts(d["diff"]), "%s～%s" % [_pts(d["lo"]), _pts(d["hi"])] if d["diff"] != null else "—", _pts(row["hp_diff"]["diff"]),
				_num(row["duration_diff"]["diff"]), "；".join(row["collateral"])])
	lines.append("")
	var h: Dictionary = r["rhythm"]
	lines.append_array(["## 三 过程节奏", ""])
	lines.append("- 出手：我方 %d 次（%d 件），对方 %d 次（%d 件）" % [h["fires"][0], h["items_fired"][0], h["fires"][1], h["items_fired"][1]])
	lines.append("- 第一次打出伤害：%s（我方 %s，对方 %s）" % [_sec(h["first_interaction"]), _sec(h["first_damage"][0]), _sec(h["first_damage"][1])])
	var hl: Array = h["hp_line"]
	var cells: Array[String] = []
	for k in (hl[0] as Array).size():
		cells.append("%.1fs %s/%s" % [float(h["hp_marks"][k]), _pct(hl[0][k]), _pct(hl[1][k])])
	lines.append("- 血线（我方 / 对方）：" + "，".join(cells))
	lines.append("- 观看：实际看了 %s 秒（扣掉暂停与失焦），跳过 %s，倍速 %s" % [_num(h["presentation_elapsed"]),
		"—" if h["skipped"] == null else ("在 %s 秒处" % _num(h["skip_at_sim"]) if bool(h["skipped"]) else "没有"),
		"—" if h["speeds"] == null else "，".join((h["speeds"] as Array).map(func(s: Dictionary) -> String: return "%s×@%s" % [_num(s.get("speed")), _num(s.get("sim"))]))])
	lines.append("")
	var q: Dictionary = r["consequence"]
	lines.append_array(["## 四 后果差异", ""])
	lines.append("- 这一场：%s，余血 我方 %s / 对方 %s" % [WINNER_TEXT.get(int(q["battle"]["winner"]), "没有胜方"), _pct(q["battle"]["hp_end"][0]), _pct(q["battle"]["hp_end"][1])])
	var dl: Dictionary = q["run_delta"]
	lines.append("- 整局（战前 → 离开回放屏）：体力 %s，钱 %s，包里件数 %s，步数 %s" % [_d(dl["vitality"]), _d(dl["coins"]), _d(dl["items"]), _d(dl["steps"])])
	lines.append("- 屏上显示了什么：不知道（这一版不记）")
	lines.append("")
	lines.append_array(["## 五 未知项", ""])
	for u in r["unknowns"]:
		lines.append("- " + String(u))
	return "\n".join(lines) + "\n"


static func _p(w: Variant) -> Variant:
	return (w as Dictionary).get("p") if w is Dictionary else null


static func _pct(v: Variant) -> String:
	return "—" if v == null else "%.0f%%" % (float(v) * 100.0)


static func _pts(v: Variant) -> String:
	return "—" if v == null else "%+.0f" % (float(v) * 100.0)


static func _num(v: Variant) -> String:
	return "—" if v == null else "%.1f" % float(v)


static func _sec(v: Variant) -> String:
	return "没有" if v == null else "%.1f 秒" % float(v)


static func _d(v: Variant) -> String:
	return "不知道" if v == null else "%+d" % int(v)

## 245（作者 2026-10-24「先保留当前文件，给游戏内添加可以记录这些数据并导出的功能」）：系数表（[PowerWeights]）里的「假设」，
## 从一场真仗的结果里量出来 —— 一场打几秒、一秒挨几下、暴击率、邻居出手频率、低血时间占比、平均层数、对手 DPS……
##
## [method of] 是纯函数：一场的 [BattleResult] + 日志头（[BattleTraceWriter] 的 header：对手、档位、步数、角色、难度……）→ 一行。
## 量不出来的项（没挨过打、没上过可叠层的 buff）不写键，汇总时跳过。
## 真实对局里每打完一场追加一行到 [constant PATH]（[method append]，挂在 [BattleTraceWriter] 写完之后；玩家版照记），
## 「导出平衡数据」整个 `calibration/` 目录一起带走；`tools/assumptions_report.gd` 把许多行汇成一张表（[method markdown]）。
## **不改系数文件**：表里给中位数，改不改作者定
class_name AssumptionStats
extends RefCounted

const PATH := "user://calibration/assumptions.jsonl"
## 低于最大生命的这一成算「低血」（[member PowerWeights.low_hp_share] 说的「低血强化」的门槛）
const LOW_HP := 0.3
## 量得出来的系数（键 = 系数表的键），按表里的顺序列
const KEYS: Array[String] = [
	"fight_sec", "horizon_sec", "hit_rate", "crit_rate", "opponent_dps", "neighbor_hz", "low_hp_share",
	"assumed_stacks", "status_applied_rate", "status_removed_rate", "persist_share", "stamina_regen", "stamina_max", "assumed_hp",
]
## 量不出来的（「条件成立的比例」没有统一的量法），表里标出来
const UNMEASURED: Array[String] = ["threshold_share", "condition_factor"]
## 每行带的筛选字段（日志头里的键）
const META: Array[String] = ["seed", "run_seed", "enemy", "tier", "steps", "bracket", "archetype", "winner", "character", "difficulty"]
## 按段位分的小表列哪几项（全列太宽）
const BRACKET_KEYS: Array[String] = ["fight_sec", "hit_rate", "crit_rate", "opponent_dps", "neighbor_hz", "low_hp_share", "assumed_stacks"]


## 一场 → 一行。我方 = 0 号，对手 = 1 号
static func of(result: BattleResult, head: Dictionary = {}, ver: String = "") -> Dictionary:
	var row := {"version": ver if ver != "" else String(head.get("version", ""))}
	for k in META:
		if head.has(k):
			row[k] = head[k]
	row["seed"] = head.get("rng_seed", head.get("seed", 0))
	if result == null:
		return row
	row["winner"] = result.winner
	var sides: Array = result.initial.get("sides", [])
	if sides.size() >= 2:
		var mine: Array = _res(sides[0], BattleStats.RES_STAMINA)
		if mine.size() >= 2:
			row["stamina_max"] = float(mine[1])
		var foe: Array = _res(sides[1], BattleStats.RES_HP)
		if foe.size() >= 2:
			row["assumed_hp"] = float(foe[1])
	if head.has("stamina_regen"):
		row["stamina_regen"] = float(head["stamina_regen"])
	var dur := result.duration_sec()
	if dur <= 0.0:
		return row
	row["fight_sec"] = dur
	row["horizon_sec"] = dur

	var hits_taken := 0
	var dealt := 0.0
	var my_hits := 0
	var my_crits := 0
	var fires := {}     # uid → 次数
	var applied := 0
	var removed := 0
	for e in result.log:
		match e.name:
			BattleEvent.DAMAGE:
				if bool(e.payload.get("cancelled", false)):
					continue
				var src := int(e.payload.get("source_side", -1))
				if e.side == 0 and src == 1:
					dealt += StatMath.to_float(int(e.payload.get("amount", 0)))
					if bool(e.payload.get("direct", false)):
						hits_taken += 1
				elif e.side == 1 and src == 0 and bool(e.payload.get("direct", false)):
					my_hits += 1
					if bool(e.payload.get("crit", false)):
						my_crits += 1
			BattleEvent.ITEM_FIRED:
				var uid := int(e.payload.get("uid", 0))
				if e.side == 0 and uid != 0:
					fires[uid] = int(fires.get(uid, 0)) + 1
			BattleEvent.STATUS_STACKED:
				if e.side == 0 and int(e.payload.get("delta", 0)) > 0:
					applied += 1
			BattleEvent.STATUS_UNSTACKED:
				if e.side == 0 and int(e.payload.get("delta", 0)) < 0:
					removed += 1
	row["hit_rate"] = float(hits_taken) / dur
	row["opponent_dps"] = dealt / dur
	if my_hits > 0:
		row["crit_rate"] = float(my_crits) / float(my_hits)
	if not fires.is_empty():
		var hz := 0.0
		for uid in fires:
			hz += float(fires[uid]) / dur
		row["neighbor_hz"] = hz / float(fires.size())
	row["status_applied_rate"] = float(applied) / dur
	row["status_removed_rate"] = float(removed) / dur
	row["low_hp_share"] = _low_hp_share(result, sides, dur)
	var stacks := _stack_average(result, 1, dur)
	if stacks > 0.0:
		row["assumed_stacks"] = stacks
	var persist := _persist_share(result, 0, dur)
	if persist >= 0.0:
		row["persist_share"] = persist
	return row


## 我方生命低于 [constant LOW_HP] 的时间 ÷ 时长：按 resource_changed 重放血线（带着变化之后的当前值与上限）
static func _low_hp_share(result: BattleResult, sides: Array, dur: float) -> float:
	var hp: Array = _res(sides[0], BattleStats.RES_HP) if not sides.is_empty() else []
	var low := hp.size() >= 2 and float(hp[1]) > 0.0 and float(hp[0]) / float(hp[1]) < LOW_HP
	var since := 0.0
	var total := 0.0
	for e in result.log:
		if e.name != BattleEvent.RESOURCE_CHANGED or e.side != 0 or String(e.payload.get("key", "")) != String(BattleStats.RES_HP):
			continue
		var t := StatMath.to_float(e.time)
		var mx := float(e.payload.get("max", 0))
		var now_low := mx > 0.0 and float(e.payload.get("current", 0)) / mx < LOW_HP
		if now_low and not low:
			since = t
		elif low and not now_low:
			total += t - since
		low = now_low
	if low:
		total += dur - since
	return clampf(total / dur, 0.0, 1.0)


## [param side] 身上可叠层 buff（我方施加给对手的流血、中毒……）在场时的平均层数：层数 × 秒 ÷ 在场秒。没上过返回 0
static func _stack_average(result: BattleResult, side: int, dur: float) -> float:
	var spans := _spans(result, side, dur, true)
	var area := 0.0
	var present := 0.0
	for id in spans:
		area += float(spans[id]["area"])
		present += float(spans[id]["present"])
	return area / present if present > 0.0 else 0.0


## [param side] 身上不可叠层的 buff 平均在场多久 ÷ 时长（各 buff 取平均）。一个都没上过返回 -1
static func _persist_share(result: BattleResult, side: int, dur: float) -> float:
	var spans := _spans(result, side, dur, false)
	if spans.is_empty():
		return -1.0
	var sum := 0.0
	for id in spans:
		sum += float(spans[id]["present"]) / dur
	return clampf(sum / float(spans.size()), 0.0, 1.0)


## 每个 buff 的 {present: 在场秒, area: 层数 × 秒}；[param stackable] 选可叠层的还是不可叠层的
## （有定义按定义；回放存档读回来没定义的，层数到过 2 就当可叠层）
static func _spans(result: BattleResult, side: int, dur: float, stackable: bool) -> Dictionary:
	var stacks := {}     # id → 当前层数
	var since := {}     # id → 上一次层数变化的时刻
	var out := {}
	var peak := {}
	var start: Dictionary = {}
	var sides: Array = result.initial.get("sides", [])
	if side < sides.size():
		start = (sides[side] as Dictionary).get("buffs", {})
	for id in start:
		stacks[String(id)] = int(start[id])
		since[String(id)] = 0.0
		peak[String(id)] = int(start[id])
	for e in result.log:
		if e.side != side or (e.name != BattleEvent.STATUS_STACKED and e.name != BattleEvent.STATUS_UNSTACKED):
			continue
		var id := String(e.payload.get("buff", ""))
		if id == "":
			continue
		var t := StatMath.to_float(e.time)
		_close(out, id, int(stacks.get(id, 0)), t - float(since.get(id, t)))
		stacks[id] = maxi(0, int(e.payload.get("stacks", 0)))
		since[id] = t
		peak[id] = maxi(int(peak.get(id, 0)), int(stacks[id]))
	for id in stacks:
		_close(out, id, int(stacks[id]), dur - float(since.get(id, dur)))
	var picked := {}
	for id in out:
		var def: BuffDef = result.buffs.get(StringName(id), null)
		var is_stack := def.is_stackable() if def != null else int(peak.get(id, 0)) > 1
		if is_stack == stackable and float(out[id]["present"]) > 0.0:
			picked[id] = out[id]
	return picked


static func _close(out: Dictionary, id: String, n: int, secs: float) -> void:
	if not out.has(id):
		out[id] = {"present": 0.0, "area": 0.0}
	if n <= 0 or secs <= 0.0:
		return
	out[id]["present"] = float(out[id]["present"]) + secs
	out[id]["area"] = float(out[id]["area"]) + secs * float(n)


static func _res(side: Variant, key: StringName) -> Array:
	if not (side is Dictionary):
		return []
	var res: Dictionary = (side as Dictionary).get("resources", {})
	var v: Variant = res.get(key, res.get(String(key), []))
	return v if v is Array else []


## 一方的耐力回复基线（每秒）：日志头带它（我方的 [member CombatantSpec.baseline]）
static func regen_of(spec: CombatantSpec) -> float:
	if spec == null or spec.baseline == null:
		return 0.0
	return StatMath.to_float(spec.baseline.total_of(BattleStats.REGEN_STAMINA))


## 交给 [method BattleTraceWriter.write] 的那个回调：工作线程写完日志后量一行、追加到 [param path]。路径空 = 不量（无效的 Callable）。
## 版本号在这一帧读好（工作线程上不碰项目设置）
static func recorder(path: String) -> Callable:
	if path == "":
		return Callable()
	var ver := CalibrationRecorder.version()
	return func(result: BattleResult, head: Dictionary) -> void: append(path, of(result, head, ver))


## 追加一行（目录没有就建）。写不了返回 false，不影响对局
static func append(path: String, row: Dictionary) -> bool:
	return CalibrationRecorder._append(path, row)


## 读全部行；坏行跳过
static func read_rows(path: String = PATH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var v: Variant = JSON.parse_string(line)
		if v is Dictionary:
			out.append(v as Dictionary)
	f.close()
	return out


#region 汇总
## [param values] 的 [param q] 分位（线性插值）；空返回 NAN
static func quantile(values: Array[float], q: float) -> float:
	if values.is_empty():
		return NAN
	var v := values.duplicate()
	v.sort()
	var pos := clampf(q, 0.0, 1.0) * float(v.size() - 1)
	var lo := floori(pos)
	var hi := mini(lo + 1, v.size() - 1)
	return lerpf(v[lo], v[hi], pos - float(lo))


## 这些行里 [param key] 量到了的值
static func values_of(rows: Array, key: String) -> Array[float]:
	var out: Array[float] = []
	for r in rows:
		if r is Dictionary and (r as Dictionary).has(key):
			out.append(float(r[key]))
	return out


## 一行的段位：难度的段位表里不超过步数的最大那一档（[param tables] 难度 id → 段位表，按需填）
static func bracket_of(row: Dictionary, tables: Dictionary) -> int:
	if row.has("bracket"):     # 木桩（扫表）自己带段号
		return int(row["bracket"])
	var diff := String(row.get("difficulty", ""))
	if not tables.has(diff):
		tables[diff] = BalanceMatrix.brackets_of(diff)
	var steps := int(row.get("steps", 0))
	var best := 0
	for b in tables[diff]:
		if int(b) <= steps:
			best = maxi(best, int(b))
	return best


## 主表：系数 / 现在的值 / 实测中位数 / 四分位 / 场数；量不出来的两项标出来
static func table(rows: Array, weights: PowerWeights) -> Array[String]:
	var out: Array[String] = ["| 系数 | 现在的值 | 实测中位数 | 四分位（25% ～ 75%） | 场数 |", "|---|---:|---:|---:|---:|"]
	for k in KEYS:
		var vals := values_of(rows, k)
		var now := _fmt(float(weights.get(k))) if weights != null and k in weights else "—"
		if vals.is_empty():
			out.append("| `%s` | %s | — | — | 0 |" % [k, now])
		else:
			out.append("| `%s` | %s | %s | %s ～ %s | %d |" % [k, now, _fmt(quantile(vals, 0.5)), _fmt(quantile(vals, 0.25)), _fmt(quantile(vals, 0.75)), vals.size()])
	for k in UNMEASURED:
		var now := _fmt(float(weights.get(k))) if weights != null and k in weights else "—"
		out.append("| `%s` | %s | 无法实测 | — | — |" % [k, now])
	return out


## 按段位分的小表：每格「中位数（场数）」
static func bracket_table(rows: Array) -> Array[String]:
	var tables := {}
	var groups := {}
	for r in rows:
		var b := bracket_of(r as Dictionary, tables)
		if not groups.has(b):
			groups[b] = []
		(groups[b] as Array).append(r)
	var keys: Array = groups.keys()
	keys.sort()
	var head := "| 系数 |"
	var rule := "|---|"
	for b in keys:
		head += " 段 %d（%d 场） |" % [b, (groups[b] as Array).size()]
		rule += "---:|"
	var out: Array[String] = [head, rule]
	for k in BRACKET_KEYS:
		var line := "| `%s` |" % k
		for b in keys:
			var vals := values_of(groups[b], k)
			line += " %s（%d） |" % [_fmt(quantile(vals, 0.5)), vals.size()] if not vals.is_empty() else " — |"
		out.append(line)
	return out


## 整份报告
static func markdown(rows: Array, weights: PowerWeights, title: String, header: Array[String]) -> String:
	var out: Array[String] = ["# " + title, ""]
	for h in header:
		out.append("- " + h)
	out.append("")
	out.append("## 系数 → 实测")
	out.append("")
	out.append("不写回 `power_weights.json`：改不改、取中位数还是四分位，作者定。")
	out.append("")
	out.append_array(table(rows, weights))
	out.append("")
	out.append("## 按段位")
	out.append("")
	out.append_array(bracket_table(rows))
	out.append("")
	return "\n".join(out)


static func _fmt(v: float) -> String:
	if is_nan(v):
		return "—"
	return "%.2f" % v
#endregion

## 平衡检测方案（2026-11-10）§8.2 第 2 条「准备有效性」：一个组件或一次摆位改动，在配对的多个种子下对结果、余血、时长的影响。
##
## 配对：甲、乙两份配装对同一个对手，第 k 场用同一个种子 —— 差出来的就是配装的差。区间是配对自助法（[BalanceStatistics]）。
## 单因素：改棋盘再重新编译（连结、相邻加成、套装跟着重算）才是真的只改一样；编译之后再拿掉一件做不到（编译时的加成还留在别的件上），
## 这时把连带的变化列出来，不假装是单因素。
class_name BattleFactor
extends RefCounted

const SEEDS := 40


## 第 k 个种子：只看（基准, k）
static func seeds_from(base: int, n: int = SEEDS) -> Array[int]:
	var out: Array[int] = []
	for k in n:
		out.append(hash("%d:factor:%d" % [base, k]))
	return out


## 甲、乙各打 [param foe] 一遍，每个种子一对。返回 {n, win_a, win_b（Wilson）, win_diff, hp_diff（我方余血）, duration_diff（甲 − 乙）}
static func paired(a: CombatantSpec, b: CombatantSpec, foe: CombatantSpec, seeds: Array[int], limit: float = BattleSim.DEFAULT_TIME_LIMIT,
		overtime: OvertimeRules = null) -> Dictionary:
	var win := []
	var hp := []
	var dur := []
	var wa := 0
	var wb := 0
	for s in seeds:
		var ra := _run(a, foe, s, limit, overtime)
		var rb := _run(b, foe, s, limit, overtime)
		wa += 1 if ra.winner == 0 else 0
		wb += 1 if rb.winner == 0 else 0
		win.append([1.0 if ra.winner == 0 else 0.0, 1.0 if rb.winner == 0 else 0.0])
		hp.append([BattleMetrics.hp_ratio(ra, 0), BattleMetrics.hp_ratio(rb, 0)])
		dur.append([ra.duration_sec(), rb.duration_sec()])
	return {"n": seeds.size(), "win_a": BalanceStatistics.wilson(wa, seeds.size()), "win_b": BalanceStatistics.wilson(wb, seeds.size()),
		"win_diff": BalanceStatistics.paired_bootstrap(win), "hp_diff": BalanceStatistics.paired_bootstrap(hp),
		"duration_diff": BalanceStatistics.paired_bootstrap(dur)}


static func _run(me: CombatantSpec, foe: CombatantSpec, s: int, limit: float, overtime: OvertimeRules) -> BattleResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return BattleSim.run(me, foe, rng, limit, overtime)


## 编译之后拿掉一件（uid）：经 [BattleInputCodec] 深拷贝一份再删。返回 {spec, collateral}：collateral 列出做不到单因素的地方
static func without_item(spec: CombatantSpec, uid: int) -> Dictionary:
	var rules: Array[AbilityRule] = []
	var d := BattleInputCodec.encode(spec, rules, {})
	var kept: Array = []
	var removed := ""
	var notes: Array[String] = []
	for row in d["items"]:
		var r := row as Dictionary
		if int(r["uid"]) == uid:
			removed = String(r["def_id"])
			continue
		kept.append(r)
		if (r.get("linked", []) as Array).has(uid):
			notes.append("%s 编译时连着它，连结带来的加成还在" % r["def_id"])
	d["items"] = kept
	if removed == "":
		return {"spec": null, "collateral": ["没有 uid %d 这一件" % uid]}
	if not (d.get("set_rules", []) as Array).is_empty():
		notes.append("套装规则按原来的棋盘算，没有重算")
	notes.append("相邻 / 包内加成按原来的棋盘算，没有重算")
	return {"spec": BattleInputCodec.decode(d, rules), "removed": removed, "collateral": notes}


## 两份从棋盘编译出来的配装，除了 [param declared] 里那几种道具以外还有哪些不一样（按道具 id 对：件数、属性、规则数；生命、套装规则数）。
## 空 = 只改了声明的因素
static func collateral(a: CombatantSpec, b: CombatantSpec, declared: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	if a.max_hp != b.max_hp:
		out.append("生命 %s → %s" % [StatMath.to_float(a.max_hp), StatMath.to_float(b.max_hp)])
	if a.set_rules.size() != b.set_rules.size():
		out.append("套装规则 %d → %d" % [a.set_rules.size(), b.set_rules.size()])
	var fa := _fingerprints(a)
	var fb := _fingerprints(b)
	var ids := {}
	for k in fa:
		ids[k] = true
	for k in fb:
		ids[k] = true
	var keys: Array = ids.keys()
	keys.sort()
	for id in keys:
		if declared.has(StringName(id)):
			continue
		var la: Array = fa.get(id, [])
		var lb: Array = fb.get(id, [])
		if la.size() != lb.size():
			out.append("%s 件数 %d → %d" % [id, la.size(), lb.size()])
		elif la != lb:
			out.append("%s 属性或规则变了" % id)
	return out


## 道具 id → 每件的（属性、规则数、威力系数）摘要，排好序
static func _fingerprints(spec: CombatantSpec) -> Dictionary:
	var out := {}
	for it in spec.items:
		var id := String(it.def_id)
		(out.get_or_add(id, []) as Array).append(ExperimentManifest.canonical_hash([BattleInputCodec.stats_to(it.stats), it.rules.size(), it.power_mult]))
	for id in out:
		(out[id] as Array).sort()
	return out

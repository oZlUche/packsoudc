## 耐力消耗评估（084，作者：低 / 中 / 高 / 极高）：一套装备每秒平均花多少耐力、每秒回多少，比一比。
##
## 花的：每条会出手的规则，出手频率（[method Cadence.estimated_hz]，含急速与邻接改的冷却）× 这条规则的耐力消耗（[ResourceCost]，含扳机隐含的）。
## 回的：**单位级**的 `regen_stamina` —— 基线 + 道具（口粮）并起来的那份，和运行时 [method CombatantRuntime.from_spec] 算的同一个数
## （作者反馈：只读基线会让口粮的回复看不见）。都是编译结果上的数（4.2），和真打时一致；不算触发型规则，只做参考。
class_name StaminaEstimate
extends RefCounted

## 消耗 / 回复 的比值分档：< 0.6 低、< 1.0 中、< 1.6 高、其余极高
const RATINGS := [[0.6, "低"], [1.0, "中"], [1.6, "高"]]


## {"cost": 每秒消耗, "regen": 每秒回复, "ratio": 比值, "rating": "低" / "中" / "高" / "极高"}（289：总数取自 [method breakdown]，两边一个数）
static func of(spec: CombatantSpec) -> Dictionary:
	var b := breakdown(spec)
	return {"cost": b["cost"], "regen": b["regen"], "ratio": b["ratio"], "rating": b["rating"]}


## 289（作者 11-07）：拆账 —— `costs` 每件会出手的道具一行 `{uid, def_id, per_sec}`（一件几条规则加一起，0 的不列，大到小、一样大按棋盘顺序）；
## `regen` 第一行基线 `{uid: 0, per_sec}`（单位级回复减去各道具的那份：角色、局外加成、负重减益都折在里面），之后每件带回复的道具一行。
## 另带和 [method of] 一样的 cost / regen / ratio / rating
static func breakdown(spec: CombatantSpec) -> Dictionary:
	var costs: Array[Dictionary] = []
	var regens: Array[Dictionary] = []
	var cost := 0.0
	var regen := 0.0
	if spec != null:
		var rt := CombatantRuntime.from_spec(spec, 0)     # 单位级属性：基线 + 道具（口粮的回复在这里才算进去）
		regen = StatMath.to_float(rt.stat(BattleStats.REGEN_STAMINA))
		var order := 0
		for item in spec.active_items():
			var it := item as CompiledItem
			var per := 0.0
			for r in it.rules:
				var rule := r as AbilityRule
				if rule == null or rule.cadence == null:
					continue
				if rule.free_when_loaded and rt.is_loaded(it.source_uid):
					continue     # 作者 11-04：装着魔晶石的法杖出手不耗耐力（247），估算也不算 —— 和 [RuleEngine] 同一个判断
				var hz := rule.cadence.estimated_hz(it.stats)
				if hz <= 0.0:
					continue
				per += hz * _stamina_of(rule, it.stats)
			if per > 0.0:
				costs.append({"uid": it.source_uid, "def_id": it.def_id, "per_sec": per, "order": order})
				cost += per
			order += 1
		var items_regen := 0.0
		order = 0
		for item in spec.items:
			var it := item as CompiledItem
			var v := StatMath.to_float(it.stats.total_of(BattleStats.REGEN_STAMINA))
			if v != 0.0:
				regens.append({"uid": it.source_uid, "def_id": it.def_id, "per_sec": v, "order": order})
				items_regen += v
			order += 1
		regens.sort_custom(_bigger_first)
		regens.push_front({"uid": 0, "def_id": &"", "per_sec": regen - items_regen, "order": -1})
	costs.sort_custom(_bigger_first)
	var ratio := (cost / regen) if regen > 0.0 else (INF if cost > 0.0 else 0.0)
	return {"costs": costs, "regen_rows": regens, "cost": cost, "regen": regen, "ratio": ratio, "rating": rating_of(ratio)}


static func _bigger_first(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["per_sec"]), float(b["per_sec"])):
		return float(a["per_sec"]) > float(b["per_sec"])
	return int(a["order"]) < int(b["order"])


static func rating_of(ratio: float) -> String:
	for step in RATINGS:
		if ratio < float(step[0]):
			return String(step[1])
	return "极高"


## 221 F5a: player text for a rating id (zh unchanged); same keys as [StatsStrip]
static func rating_label(rating: String) -> String:
	var keys := {"低": "strip.rating_low", "中": "strip.rating_mid", "高": "strip.rating_high", "极高": "strip.rating_max"}
	return UiText.t(keys[rating]) if keys.has(rating) else rating


## 这条规则每次出手花多少耐力（面板数或属性值；扳机隐含的消耗也算）
static func _stamina_of(rule: AbilityRule, stats: StatSet) -> float:
	var total := 0.0
	for c in rule.effective_costs():
		var rc := c as ResourceCost
		if rc == null or rc.resource_key != BattleStats.RES_STAMINA:
			continue
		total += rc.stamina_per_use(stats)     # 256：写死的也吃 `stamina_cost` 的打折（和 [method ResourceCost.pay] 同一套）
	return total


## 289：消耗来源最多列几行、回复来源（不含基线）最多几行，超出的合成一行「其余 N 件」
const MAX_COST_ROWS := 8
const MAX_REGEN_ROWS := 4


## 给悬浮窗的几行：每秒消耗 / 回复、评级；289：下面两段「消耗来源」「回复来源」（[param names] uid → 名字，[method CombatantSpec.item_names]；没给按棋盘上那件取）
static func describe(spec: CombatantSpec, names: Dictionary = {}) -> String:
	var e := breakdown(spec)
	var cap := StatMath.to_float(CombatantRuntime.from_spec(spec, 0).stat(BattleStats.MAX_STAMINA)) if spec != null else 0.0
	var lines: Array[String] = [UiText.t("stat.stamina_tip") % [
		rating_label(String(e["rating"])), e["cost"], e["regen"], "" if e["regen"] > 0.0 else UiText.t("stat.no_regen"), cap]]
	if spec == null:
		return lines[0]
	lines.append("[color=@dim]%s[/color]" % UiText.t("stamina.costs_head"))
	var costs: Array = e["costs"]
	if costs.is_empty():
		lines.append(UiText.t("stamina.no_cost"))
	_rows(lines, costs, MAX_COST_ROWS, spec, names, false)
	lines.append("[color=@dim]%s[/color]" % UiText.t("stamina.regen_head"))
	var regens: Array = e["regen_rows"]
	lines.append(UiText.t("stamina.row") % [UiText.t("stamina.baseline"), float(regens[0]["per_sec"])])
	_rows(lines, regens.slice(1), MAX_REGEN_ROWS, spec, names, true)
	return "\n".join(lines)


static func _rows(lines: Array[String], rows: Array, cap: int, spec: CombatantSpec, names: Dictionary, signed: bool) -> void:
	var shown := rows.size() if rows.size() <= cap else cap - 1     # 超出：留一行给「其余 N 件」
	for i in shown:
		var r: Dictionary = rows[i]
		var v := float(r["per_sec"])
		lines.append(UiText.t("stamina.regen_row" if signed and v > 0.0 else "stamina.row") % [_name_of(spec, int(r["uid"]), StringName(r["def_id"]), names), v])
	if shown < rows.size():
		var rest := 0.0
		for i in range(shown, rows.size()):
			rest += float((rows[i] as Dictionary)["per_sec"])
		lines.append(UiText.t("stamina.rest") % [rows.size() - shown, rest])


static func _name_of(spec: CombatantSpec, uid: int, def_id: StringName, names: Dictionary) -> String:
	if names.has(uid):
		return String(names[uid])
	var inst := spec.board.get_item(uid) if spec.board != null else null
	return Names.of_item(inst) if inst != null and inst.def != null else String(def_id)

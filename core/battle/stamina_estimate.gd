## 耐力消耗评估（084，作者：低 / 中 / 高 / 极高）：一套装备每秒平均花多少耐力、每秒回多少，比一比。
##
## 花的：每条会出手的规则，出手频率（[method Cadence.estimated_hz]，含急速与邻接改的冷却）× 这条规则的耐力消耗（[ResourceCost]，含扳机隐含的）。
## 回的：**单位级**的 `regen_stamina` —— 基线 + 道具（口粮）并起来的那份，和运行时 [method CombatantRuntime.from_spec] 算的同一个数
## （作者反馈：只读基线会让口粮的回复看不见）。都是编译结果上的数（4.2），和真打时一致；不算触发型规则，只做参考。
class_name StaminaEstimate
extends RefCounted

## 消耗 / 回复 的比值分档：< 0.6 低、< 1.0 中、< 1.6 高、其余极高
const RATINGS := [[0.6, "低"], [1.0, "中"], [1.6, "高"]]


## {"cost": 每秒消耗, "regen": 每秒回复, "ratio": 比值, "rating": "低" / "中" / "高" / "极高"}
static func of(spec: CombatantSpec) -> Dictionary:
	var cost := 0.0
	var regen := 0.0
	if spec != null:
		var rt := CombatantRuntime.from_spec(spec, 0)     # 单位级属性：基线 + 道具（口粮的回复在这里才算进去）
		regen = StatMath.to_float(rt.stat(BattleStats.REGEN_STAMINA))
		for item in spec.active_items():
			var it := item as CompiledItem
			for r in it.rules:
				var rule := r as AbilityRule
				if rule == null or rule.cadence == null:
					continue
				var hz := rule.cadence.estimated_hz(it.stats)
				if hz <= 0.0:
					continue
				cost += hz * _stamina_of(rule, it.stats)
	var ratio := (cost / regen) if regen > 0.0 else (INF if cost > 0.0 else 0.0)
	return {"cost": cost, "regen": regen, "ratio": ratio, "rating": rating_of(ratio)}


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
		if rc.amount_stat != &"" and stats != null:
			total += StatMath.to_float(stats.total_of(rc.amount_stat))
		else:
			total += rc.amount
	return total


## 给悬浮窗的几行：每秒消耗 / 回复、评级
static func describe(spec: CombatantSpec) -> String:
	var e := of(spec)
	var cap := StatMath.to_float(CombatantRuntime.from_spec(spec, 0).stat(BattleStats.MAX_STAMINA)) if spec != null else 0.0
	return UiText.t("stat.stamina_tip") % [
		rating_label(String(e["rating"])), e["cost"], e["regen"], "" if e["regen"] > 0.0 else UiText.t("stat.no_regen"), cap]

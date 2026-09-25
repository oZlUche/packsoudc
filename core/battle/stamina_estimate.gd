## 耐力消耗评估（084，作者：低 / 中 / 高 / 极高）：一套装备每秒平均花多少耐力、每秒回多少，比一比。
##
## 花的：每条会出手的规则，出手频率（[method Cadence.estimated_hz]，含急速与邻接改的冷却）× 这条规则的耐力消耗（[ResourceCost]，含扳机隐含的）。
## 回的：基线的 `regen_stamina`。都是编译结果上的数（4.2），和真打时一致；不算触发型规则（出手频率不由自己定），只做参考。
class_name StaminaEstimate
extends RefCounted

## 消耗 / 回复 的比值分档：< 0.6 低、< 1.0 中、< 1.6 高、其余极高
const RATINGS := [[0.6, "低"], [1.0, "中"], [1.6, "高"]]


## {"cost": 每秒消耗, "regen": 每秒回复, "ratio": 比值, "rating": "低" / "中" / "高" / "极高"}
static func of(spec: CombatantSpec) -> Dictionary:
	var cost := 0.0
	var regen := 0.0
	if spec != null:
		if spec.baseline != null:
			regen = StatMath.to_float(spec.baseline.total_of(BattleStats.REGEN_STAMINA))
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


## 这条规则每次出手花多少耐力（面板数或属性值；扳机隐含的消耗也算）
static func _stamina_of(rule: AbilityRule, stats: StatSet) -> float:
	var total := 0.0
	var costs: Array = []
	costs.append_array(rule.costs)
	if rule.trigger != null:
		costs.append_array(rule.trigger.implied_costs())
	for c in costs:
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
	return "耐力消耗：%s\n每秒平均消耗 %.1f　每秒回复 %.1f%s" % [e["rating"], e["cost"], e["regen"], "" if e["regen"] > 0.0 else "（不回复）"]

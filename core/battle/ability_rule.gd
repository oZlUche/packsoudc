## 一条完整规则：什么时候 · 多久一次 · 付什么代价 · 做什么（架构文档 4.4）。
##
## 物品与 buff 都持有 [Array] 形式的规则表，一条规则可以有多个效果 ——
## 它们按声明顺序执行且**共用同一次消耗**：
## 「付一次耐力，同时造成伤害并施加灼烧」是一条规则两个效果，不是两条规则。
class_name AbilityRule
extends Resource

@export var trigger: Trigger
@export var cadence: Cadence
## 可为空。非武器道具通常没有消耗，但检查环节一律保留 ——
## 后期必然出现「消耗 N 层某增益才能触发」的效果。
@export var costs: Array[Cost] = []
## 247：所属的件装载格上站着在供给的东西（[method CombatantRuntime.is_loaded]）时，消耗不收（条件照查）——
## 「装着魔晶石的法杖出手不耗耐力」；空杖照旧付
@export var free_when_loaded: bool = false
## 收窄为 CombatEffect：只有战斗效果依赖扳机，编辑器下拉也只会列出它们
@export var effects: Array[CombatEffect] = []


## 实际生效的消耗 = 显式写的 + 扳机隐含的
func effective_costs() -> Array[Cost]:
	if trigger == null:
		return costs
	var implied := trigger.implied_costs()
	if implied.is_empty():
		return costs
	var out: Array[Cost] = costs.duplicate()
	out.append_array(implied)
	return out


func is_valid() -> bool:
	return trigger != null and cadence != null and not effects.is_empty()


#region 151 战斗力估算
## 一秒触发几次：自发型 = 频率；别的 = 扳机估的次数，有冷却再被冷却封顶
func estimated_rate(ctx: PowerContext) -> float:
	if trigger == null or cadence == null:
		return 0.0
	var hz := cadence.estimated_hz(ctx.stats if ctx.stats != null else StatSet.new())
	if trigger.is_self_driven():
		return hz
	var t := trigger.estimated_rate(ctx, hz)
	return minf(t, hz) if hz > 0.0 else t


## 消耗（[param conditions] 假）或条件（真）的折扣之积
func estimated_factor(ctx: PowerContext, rate: float, conditions: bool) -> float:
	var f := 1.0
	for c in effective_costs():
		if not conditions and free_when_loaded and not (c as Cost).is_condition():
			continue     # 247：估算按装满晶石算（法杖的战斗力本来就按装满估），消耗不打折
		if (c as Cost).is_condition() == conditions:
			f *= clampf((c as Cost).estimated_factor(ctx, rate), 0.0, 1.0)
	return f


## 每秒值多少（buff 自己的规则用；道具的规则由估算器逐项拆开算）
func estimated_value_per_sec(ctx: PowerContext) -> float:
	var c := ctx
	if trigger != null and trigger.estimated_stacks() > 0.0:
		c = ctx.with_stacks(trigger.estimated_stacks())
	var rate := estimated_rate(c)
	if rate <= 0.0:
		return 0.0
	var v := 0.0
	for e in effects:
		var x := (e as CombatEffect).estimated_value(c)
		if not is_nan(x):
			v += x * clampf((e as CombatEffect).estimated_cap(c, rate), 0.0, 1.0)
	return v * rate * estimated_factor(c, rate, false) * estimated_factor(c, rate, true)
#endregion

## 轮读（175 第二批，作者定）：法杖按顺时针逐颗读装载的晶石，颗与颗之间走**单次冷却**，一轮读完到下一轮开始走**总冷却**。
##
## [codeblock]
## 没放晶石      一轮 = 一下（木棍），只有总冷却
## 一颗          一轮 = 一下，只有总冷却（单次冷却被总冷却覆盖）
## 三颗          第一颗 →（单次）→ 第二颗 →（单次）→ 第三颗 →（总）→ 第一颗 …
## [endcodeblock]
## 两种冷却都吃急速（和 [CooldownCadence] 同一个除法），快照语义不变：出手那一刻按当时的速率算死下一时刻。
## 一轮几颗是编译期定的（[member BattleStats.LOAD_STEPS]，[method BattleCompiler] 按装载归属写进法杖的属性）。
## [method commit] 记下这一下读的是第几颗（[constant FIRED]），[FireLoaded] 按它取晶石。
## 继承 [CooldownCadence]：总冷却就是它的冷却（`seconds` / 属性 `cooldown`），回放的冷却扇形照样认 READY_AT
class_name CycleCadence
extends CooldownCadence

## 下一下读第几颗（0 起）
const INDEX := &"cycle_index"
## 刚出手的这一下读的是第几颗（0 起）
const FIRED := &"cycle_fired"

## 单次冷却（颗与颗之间），秒；属性 `step_cooldown` 有值就以属性为准
@export var step_seconds: float = 0.6


## 一轮几下：装了几颗就几下，没装 = 1（木棍）
static func steps_of(stats_value: int) -> int:
	return maxi(1, StatMath.to_int(stats_value))


func _steps(ctx: RuleContext) -> int:
	return steps_of(ctx.item_stat(BattleStats.LOAD_STEPS, 0))


## 单次冷却的实际时长：和总冷却同一套（属性优先、吃急速、下限 0.01 秒）
func _step_duration(ctx: RuleContext) -> int:
	var from_stats := ctx.item_stat(BattleStats.STEP_COOLDOWN, -1)
	var period := from_stats if from_stats > 0 else StatMath.from_float(step_seconds)
	period = maxi(MIN_PERIOD, period)
	if not use_haste:
		return period
	var rate := maxi(1, ctx.item_stat(BattleStats.HASTE, StatMath.ONE))
	return maxi(MIN_PERIOD, (period * StatMath.ONE) / rate)


func commit(ctx: RuleContext, now: int) -> void:
	var st := ctx.state()
	var steps := _steps(ctx)
	var i := int(st.get(INDEX, 0)) % steps
	st[FIRED] = i
	if i < steps - 1:
		st[READY_AT] = now + chilled(ctx, _step_duration(ctx))     # 175 补充四：寒冷也拉长单次冷却
		st[INDEX] = i + 1
	else:
		st[READY_AT] = now + chilled(ctx, _duration(ctx))     # 一轮读完（只有一颗 / 没有时每一下都是）：总冷却
		st[INDEX] = 0


## 估算用的两种冷却（秒，已除急速）：x = 单次、y = 总。悬浮窗和 [method estimated_hz] 共用
func periods(stats: StatSet) -> Vector2:
	var total := StatMath.to_float(stats.total_of(BattleStats.COOLDOWN, StatMath.from_float(seconds))) if stats != null else seconds
	var step := StatMath.to_float(stats.total_of(BattleStats.STEP_COOLDOWN, StatMath.from_float(step_seconds))) if stats != null else step_seconds
	if total <= 0.0:
		total = seconds
	if step <= 0.0:
		step = step_seconds
	var haste := StatMath.to_float(stats.total_of(BattleStats.HASTE, StatMath.ONE)) if use_haste and stats != null else 1.0
	if haste <= 0.0:
		return Vector2.ZERO
	return Vector2(step, total) / haste


## 一秒几下：一轮 n 下，用时 (n − 1) × 单次 + 总
func estimated_hz(stats: StatSet) -> float:
	var n := steps_of(stats.total_of(BattleStats.LOAD_STEPS, 0))
	var p := periods(stats)
	var period := (n - 1) * p.x + p.y
	if period <= 0.0:
		return 0.0
	return n / period

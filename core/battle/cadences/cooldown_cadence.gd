## 冷却：距上次出手满 period 秒后可再次执行。
##
## [b]快照语义[/b]：出手那一刻按**当时**的速率算死下一次时刻，此后不再重算。
## 后来施加的急速只影响再下一次，不会加速正在走的这一轮。
##
## 换来的是：排定时刻永不失效，因此可以放进最小堆（[ScheduleHeap]），
## 推进器 O(log n) 取下一个事件，而不必每跳一步就把全部规则重问一遍。
## 代价是喝下急速药时当前这一轮不变快 —— 这是有意的取舍。
class_name CooldownCadence
extends Cadence

const READY_AT := &"cd_ready_at"

## 冷却下限，防止 period 被改到 0 造成同一时刻无限触发
const MIN_PERIOD := StatMath.ONE / 100  # 0.01 秒

## 基础冷却，秒
@export var seconds: float = 2.0
## 是否吃 haste（速度倍率，1.0 为基准，越大越快）
@export var use_haste: bool = true


## 本次冷却的实际时长：周期 ÷ 速率，按调用当刻的属性算
func _duration(ctx: RuleContext) -> int:
	var from_stats := ctx.item_stat(BattleStats.COOLDOWN, -1)
	var period := from_stats if from_stats > 0 else StatMath.from_float(seconds)
	period = maxi(MIN_PERIOD, period)
	if not use_haste:
		return period
	var rate := maxi(1, ctx.item_stat(BattleStats.HASTE, StatMath.ONE))
	return maxi(MIN_PERIOD, (period * StatMath.ONE) / rate)


## 下一次可执行的时刻。首次调用（尚未出手过）时按 now 起算一个完整冷却。
func next_time(ctx: RuleContext, now: int) -> int:
	var st := ctx.state()
	if not st.has(READY_AT):
		st[READY_AT] = now + _duration(ctx)
	return int(st[READY_AT])


func can_fire(ctx: RuleContext, now: int) -> bool:
	return now >= next_time(ctx, now)


func commit(ctx: RuleContext, now: int) -> void:
	# 从此刻起算新的一轮。不是「上次就绪时刻 + 周期」——
	# 那样在被消耗挡住多次后会积欠一串补偿性触发
	ctx.state()[READY_AT] = now + chilled(ctx, _duration(ctx))


## 175 补充四：寒冷 —— 武器出手时，这一次排定的冷却 × (1 + 层数 × 每层%)（[member BuffDef.decay_halve_on] = `weapon_fired` 的状态），
## 用完层数减半。只对带 `weapon` 标签的道具的规则；别的规则原样返回
static func chilled(ctx: RuleContext, period: int) -> int:
	var uid := ctx.source_uid()
	if uid == 0 or ctx.runtime.buff != null or not ctx.owner.tags_of(uid).has(&"weapon"):
		return period
	var pct := ctx.owner.percent_on(BuffDef.HALVE_WEAPON_FIRED)
	if pct <= 0.0:
		return period
	ctx.owner.halve_on(ctx.battle, BuffDef.HALVE_WEAPON_FIRED)
	return maxi(MIN_PERIOD, StatMath.mul(period, StatMath.ONE + StatMath.from_float(pct / 100.0)))


func estimated_hz(stats: StatSet) -> float:
	var period := stats.total_of(BattleStats.COOLDOWN, StatMath.from_float(seconds))
	if period <= 0:
		return 0.0
	var haste := StatMath.to_float(stats.total_of(BattleStats.HASTE, StatMath.ONE)) if use_haste else 1.0
	return haste / StatMath.to_float(period)

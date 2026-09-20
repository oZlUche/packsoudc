## 冷却：完成一个周期的「工作量」后可执行一次。
##
## 进度以**工作量**计而非时间：每秒推进 haste 点工作量，攒满 period 点即就绪。
## 这样速率变化不会丢失已有进度 —— 变速前把进度结算到当下，之后按新速率外推。
##
## 相比「每帧 += dt」的做法，这里完全没有累积误差：
## 进度只在变速与执行这两个离散时刻被改写。
class_name CooldownCadence
extends Cadence

const PROGRESS := &"cd_work"
const LAST := &"cd_last"

## 冷却下限，防止 period 被改到 0 造成同一时刻无限触发
const MIN_PERIOD := StatMath.ONE / 100  # 0.01 秒

## 基础冷却，秒
@export var seconds: float = 2.0
## 进度累积是否吃 haste（速度倍率，1.0 为基准，越大越快）
@export var use_haste: bool = true


func _period(ctx: RuleContext) -> int:
	var from_stats := ctx.item_stat(BattleStats.COOLDOWN, -1)
	var period := from_stats if from_stats > 0 else StatMath.from_float(seconds)
	return maxi(MIN_PERIOD, period)


func _rate(ctx: RuleContext) -> int:
	if not use_haste:
		return StatMath.ONE
	return maxi(1, ctx.item_stat(BattleStats.HASTE, StatMath.ONE))


## 把进度推进到 now。变速前必须调用。
func flush(ctx: RuleContext, now: int) -> void:
	var st := ctx.state()
	var last := int(st.get(LAST, 0))
	if now <= last:
		st[LAST] = now
		return
	st[PROGRESS] = int(st.get(PROGRESS, 0)) + StatMath.mul(now - last, _rate(ctx))
	st[LAST] = now


func next_time(ctx: RuleContext, now: int) -> int:
	flush(ctx, now)
	var remaining := _period(ctx) - int(ctx.state().get(PROGRESS, 0))
	if remaining <= 0:
		return now
	# 还差 remaining 点工作量，按当前速率还需要 remaining / rate 秒
	var rate := _rate(ctx)
	var wait := (remaining * StatMath.ONE + rate - 1) / rate  # 向上取整，避免早一个最小单位
	return now + maxi(1, wait)


func can_fire(ctx: RuleContext, now: int) -> bool:
	flush(ctx, now)
	return int(ctx.state().get(PROGRESS, 0)) >= _period(ctx)


func commit(ctx: RuleContext, now: int) -> void:
	flush(ctx, now)
	var st := ctx.state()
	# 扣一个周期而不是清零：溢出的进度留给下一次，
	# 否则高速率下每次都浪费掉一点，实际频率永远低于名义值
	st[PROGRESS] = int(st.get(PROGRESS, 0)) - _period(ctx)


func estimated_hz(stats: StatSet) -> float:
	var period := stats.total_of(BattleStats.COOLDOWN, StatMath.from_float(seconds))
	if period <= 0:
		return 0.0
	var haste := StatMath.to_float(stats.total_of(BattleStats.HASTE, StatMath.ONE)) if use_haste else 1.0
	return haste / StatMath.to_float(period)

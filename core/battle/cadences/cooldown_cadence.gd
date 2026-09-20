## 按定点进度累积，满了执行一次并扣除一个周期。配合 [OnTick] 使用。
##
## 进度用定点整数累积（架构文档 4.3／4.7）：浮点会漂移导致回放不一致，
## 纯整数又表达不了 Heat / Cold 的 ±2% 比例叠乘。
class_name CooldownCadence
extends Cadence

const KEY := &"cd_progress"

## 基础冷却，秒
@export var seconds: float = 2.0
## 进度累积是否吃 haste 加成（速度倍率，1.0 为基准，越大越快）
@export var use_haste: bool = true


func _period_fp(ctx: RuleContext) -> int:
	# 冷却也可被属性改写；取不到就用编辑器里配的值
	var from_stats := ctx.item_stat(BattleStats.COOLDOWN, -1)
	var period := from_stats if from_stats > 0 else StatMath.from_float(seconds)
	return maxi(1, period)


func advance(ctx: RuleContext, delta_fp: int) -> void:
	var step := delta_fp
	if use_haste:
		step = StatMath.mul(delta_fp, maxi(0, ctx.item_stat(BattleStats.HASTE, StatMath.ONE)))
	var st := ctx.state()
	st[KEY] = int(st.get(KEY, 0)) + step


func can_fire(ctx: RuleContext) -> bool:
	return int(ctx.state().get(KEY, 0)) >= _period_fp(ctx)


func commit(ctx: RuleContext) -> void:
	var st := ctx.state()
	# 扣一个周期而不是清零：溢出的进度留给下一次，
	# 否则高速度下每帧都会浪费掉一点，实际频率永远低于名义值
	st[KEY] = int(st.get(KEY, 0)) - _period_fp(ctx)


func estimated_hz(stats: StatSet) -> float:
	var period := stats.total_of(BattleStats.COOLDOWN, StatMath.from_float(seconds))
	if period <= 0:
		return 0.0
	var haste := StatMath.to_float(stats.total_of(BattleStats.HASTE, StatMath.ONE))
	return haste / StatMath.to_float(period)

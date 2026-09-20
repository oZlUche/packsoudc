## 组合子：全部子频率都放行才执行。
##
## **两阶段的意义全在这里**：先全体 can_fire，全过才逐个 commit。
## 否则「冷却 2 秒 + 每场一次」在次数用尽时仍会白扣一次冷却。
## 与 [GridInventory] 的「先校验后写入」是同一个不变式。
class_name AllOf
extends Cadence

@export var parts: Array[Cadence] = []


func advance(ctx: RuleContext, delta_fp: int) -> void:
	for p in parts:
		(p as Cadence).advance(ctx, delta_fp)


func on_match(ctx: RuleContext) -> void:
	for p in parts:
		(p as Cadence).on_match(ctx)


func can_fire(ctx: RuleContext) -> bool:
	for p in parts:
		if not (p as Cadence).can_fire(ctx):
			return false
	return not parts.is_empty()


func commit(ctx: RuleContext) -> void:
	for p in parts:
		(p as Cadence).commit(ctx)


func estimated_hz(stats: StatSet) -> float:
	# 取最慢的一环作为上界
	var slowest := 0.0
	for p in parts:
		var hz := (p as Cadence).estimated_hz(stats)
		if hz > 0.0 and (slowest == 0.0 or hz < slowest):
			slowest = hz
	return slowest

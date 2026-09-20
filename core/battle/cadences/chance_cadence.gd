## 按概率执行。
##
## 随机必须走 battle 随机流（架构文档 1.4）——
## 用全局 randf 会让回放与批量模拟失效。
##
## 注意：掷骰发生在 can_fire 里，因此即便最终没执行（例如 AllOf 的另一环没过），
## 随机流也已经推进了一格。结果仍然确定，只是 AllOf 里各环的顺序会影响随机序列，
## 不要随意重排。
class_name ChanceCadence
extends Cadence

## 0..100
@export var percent: int = 50


func can_fire(ctx: RuleContext) -> bool:
	return ctx.rng().randi_range(1, 100) <= clampi(percent, 0, 100)


func commit(_ctx: RuleContext) -> void:
	pass

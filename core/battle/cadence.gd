## 频率：命中之后，这次要不要真的执行（架构文档 4.4）。
##
## 两阶段是为了**多个频率条件组合时的原子性**：[AllOf] 先全体 [method can_fire]，
## 全过才逐个 [method commit]，与 [GridInventory] 的「先校验后写入」是同一个不变式。
##
## [b]资源消耗不在这一层。[/b] 消耗是独立的第四层，且刻意不与冷却原子 ——
## 付不起时冷却照常清零。详见 [Cost]。
@abstract
class_name Cadence
extends Resource

## 时机命中后立刻调用，无论最终是否执行。计数类在这里累加。
##
## 需要它是因为 [method can_fire] 必须只读，而「每 N 次执行一次」得把
## 没执行的那几次也数进去。
func on_match(_ctx: RuleContext) -> void:
	pass


## 这次命中能不能执行。只读，不得改状态。
@abstract func can_fire(ctx: RuleContext) -> bool

## 确认执行，在此扣冷却／计数。
@abstract func commit(ctx: RuleContext) -> void

## 每逻辑帧推进一次，供冷却类累积进度用。默认什么都不做。
func advance(_ctx: RuleContext, _delta_fp: int) -> void:
	pass


## 估算每秒触发次数，供 UI 实时显示预估 DPS。
##
## 默认返回 0 表示「估不出来」。新增频率类型不实现它也不会出错，
## 只是不参与 DPS 预估 —— 这比强迫每个子类都编一个数字诚实。
func estimated_hz(_stats: StatSet) -> float:
	return 0.0

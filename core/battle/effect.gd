## 内容：实际做的事（架构文档 4.4）。
##
## [b]必须同步完成。[/b] 战斗中没有任何玩家操作（4.1），效果不得等待玩家输入，
## 不存在「待玩家选择」的中间状态。想表达「三选一」只能用随机（走 battle 随机流）
## 或确定性规则，不能弹窗。
##
## 效果通过 [RuleContext] 访问战场，不持有 [BattleSim] 的引用 ——
## 这样模拟循环重构时效果无需改动。
@abstract
class_name Effect
extends Resource

@abstract func apply(ctx: RuleContext) -> void

## 估算单次触发造成的伤害，供 UI 实时显示预估 DPS。
##
## 默认返回 0 表示「本效果不产生可估算的伤害」。新增效果类型不实现它也不会出错，
## 只是不参与 DPS 预估 —— 这比强迫每个子类都编一个数字诚实。
func estimated_damage(_stats: StatSet) -> float:
	return 0.0


## 给 UI 用的说明
func describe() -> String:
	return ""

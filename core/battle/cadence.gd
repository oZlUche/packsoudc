## 频率：命中之后，这次要不要真的执行；以及自发型规则下一次何时执行。
##
## [b]模拟是事件驱动的，没有帧。[/b] 帧只是渲染概念，底层直接用定点秒计算出手时刻，
## 在时刻之间跳跃，因此不存在「每帧推进一点进度」那种东西。
##
## [b]排定时刻一经算出就不再改变[/b]（快照语义）：后来施加的增益只影响再下一次。
## 正因如此，自发型规则可以放进最小堆，推进器 O(log n) 取下一个事件。
##
## 两种用法：
## [codeblock]
## OnSchedule + Cooldown(2.0)     自发型：每 2 秒一次，由模拟器排进时间轮
## OnDamageTaken + Cooldown(2.0)  被动型：受击时触发，但最快 2 秒一次（内置冷却）
## [endcodeblock]
## 只有搭配 [OnSchedule] 的规则会进时间轮，其余只在事件到来时被询问。
@abstract
class_name Cadence
extends Resource

## 不自发调度时的返回值
const NEVER := -1


## 自发型：下一次可执行的时刻（定点秒）。返回 [constant NEVER] 表示不自发调度。
##
## 默认不自发 —— 计数、概率、一次性这类频率本身不产生时刻，
## 它们只在被事件触发时作为闸门使用。
func next_time(_ctx: RuleContext, _now: int) -> int:
	return NEVER


## 这次能不能执行。只读，不得改状态。
@abstract func can_fire(ctx: RuleContext, now: int) -> bool


## 确认执行，在此重置冷却／计数。
@abstract func commit(ctx: RuleContext, now: int) -> void


## 估算每秒触发次数，供 UI 实时显示预估 DPS。
##
## 默认返回 0 表示「估不出来」。新增频率类型不实现它也不会出错，
## 只是不参与 DPS 预估 —— 这比强迫每个子类都编一个数字诚实。
func estimated_hz(_stats: StatSet) -> float:
	return 0.0

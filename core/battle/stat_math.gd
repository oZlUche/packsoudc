## 定点数。数值结算的全部约定集中在这里（架构文档 4.3）。
##
## 结算公式（133，作者定：只有一个乘区）：
## [codeblock]
## 终值 = 基础值 × max(0, 1 + 乘算之和) + 加算之和
## [/codeblock]
##
## 所有乘算相加后乘一次，加算在乘法之后相加、不吃任何百分比放大。
class_name StatMath
extends RefCounted

## 定点标度：ONE 代表 1.0，即四位小数。与时间、冷却共用同一套标度。
##
## [b]刻意用十进制而不是 2 的幂。[/b] 2^16 那种写法来自 C／嵌入式，图的是乘除能编译成
## 移位；GDScript 里这个好处根本不存在，代价却是设计师写的每个十进制数都被舍入 ——
## 0.1 在 2^16 下是 6554/65536，三次累加不等于 0.3。换成十进制后这类误差整个消失。
##
## 为什么是一万而不是一百万：[method mul] 会算 a*b，两者都是「值 × ONE」，
## 所以约束是「两个值之积 < 2^63 / ONE²」。ONE = 1e4 时余量是 9.2e10，
## ONE = 1e6 时只剩 9.2e6 —— 百万血乘十倍就溢出了。
## 四位小数对冷却是 0.1 毫秒、对百分比是 0.01%，远够用。
const ONE := 10_000


#region 定点数
static func from_float(v: float) -> int:
	return roundi(v * ONE)


static func to_float(v: int) -> float:
	return float(v) / float(ONE)


## 百分数转定点：from_percent(25) == 0.25
static func from_percent(p: int) -> int:
	return (ONE * p + (50 if p >= 0 else -50)) / 100


## 定点乘法，四舍五入（负数时向远离零的方向舍入，保持对称）。
##
## GDScript 的整数除法朝零截断，直接写 (a*b + ONE/2) / ONE 在负数上会偏，
## 所以分符号处理。
##
## 溢出边界：a*b 必须小于 2^63，换算成原值即「两个值之积 < 9.2e10」。
## 正常量级（伤害上万 × 倍率上百 = 1e6）离这条线还有四个数量级。
static func mul(a: int, b: int) -> int:
	var p := a * b
	if p >= 0:
		return (p + ONE / 2) / ONE
	return -((-p + ONE / 2) / ONE)


## 定点除法，四舍五入、负数对称（和 [method mul] 同一条规矩）。
##
## 连乘轴的负层要它（`1 / 0.97^n`，见 [StatAxes]）。除零返回 0 —— 调用方不该走到这里，
## 静默返回比崩掉好查
static func div(a: int, b: int) -> int:
	if b == 0:
		return 0
	var p := a * ONE
	var q := (absi(p) + absi(b) / 2) / absi(b)
	return -q if (p < 0) != (b < 0) else q


## 定点值转成用于显示或应用伤害的整数。**只在管线末端调用。**
## 中途反复取整会让「两个 +5%」不等于「一个 +10%」，玩家算得出来，会当成 bug。
static func to_int(v: int) -> int:
	if v >= 0:
		return (v + ONE / 2) / ONE
	return -((-v + ONE / 2) / ONE)
#endregion

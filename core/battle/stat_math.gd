## 定点数与乘区枚举。数值结算的全部约定集中在这里（架构文档 4.3）。
##
## 结算公式：
## [codeblock]
## 终值 = 基础值 × (1 + A 类加成之和) × (1 + B 类加成之和) × … + 固定加值之和
## [/codeblock]
##
## 同一乘区内相加，不同乘区之间相乘，固定加值在所有乘法之后相加、不吃任何百分比放大。
class_name StatMath
extends RefCounted

## 定点标度：ONE 代表 1.0。与 BattleSim 的冷却累积共用同一套标度。
const ONE := 65536


## 乘区分类。
##
## [b]追加只能加在末尾。[/b] 定点乘法带取整，乘法顺序会影响末位；枚举声明顺序即乘法
## 顺序，在末尾追加一个空乘区其因子恰为 1、结果逐位不变，而在中间插入会重排乘法顺序，
## 让所有历史数值和存档对不上。
##
## 这里的分类是开发期占位，正式内容确定后替换。一项属性只会收到与它相关的乘区加成，
## 无关乘区保持 0、因子为 1，不影响结果 —— 所以不需要为每种属性各开一套枚举。
enum Buff {
	EMPOWER,  ## 强化：通用增伤
	SHARP,    ## 锐利：物理系
	FIRE,     ## 火焰：元素系
	HASTE,    ## 急速：作用于冷却
}

## 缓存枚举值，避免每次结算都重建数组。顺序即乘法顺序。
static var _categories: Array = Buff.values()


static func categories() -> Array:
	return _categories


static func category_count() -> int:
	return _categories.size()


static func category_name(category: int) -> String:
	var keys := Buff.keys()
	return keys[category] if category >= 0 and category < keys.size() else "?"


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
static func mul(a: int, b: int) -> int:
	var p := a * b
	if p >= 0:
		return (p + ONE / 2) / ONE
	return -((-p + ONE / 2) / ONE)


## 第 tick_index 帧（从 1 起）对应的时长，定点秒。
##
## [b]不能写成 ONE / hz。[/b] 65536 / 20 = 3276.8 会被截断成 3276，
## 20 帧只走 0.9997 秒，冷却永远差一点，而且误差随战斗时长累积。
## 这里用「累计时刻之差」把余数精确摊到各帧上，20 帧之和恰好等于 ONE。
static func tick_delta(tick_index: int, hz: int) -> int:
	if hz <= 0:
		return 0
	return (tick_index * ONE) / hz - ((tick_index - 1) * ONE) / hz


## 定点值转成用于显示或应用伤害的整数。**只在管线末端调用。**
## 中途反复取整会让「两个 +5%」不等于「一个 +10%」，玩家算得出来，会当成 bug。
static func to_int(v: int) -> int:
	if v >= 0:
		return (v + ONE / 2) / ONE
	return -((-v + ONE / 2) / ONE)
#endregion

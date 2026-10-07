## 体力：一局之内「还剩几条命」（架构文档 7.1）。
##
## 战斗输了扣体力，归零才战败。与战斗内的生命、耐力[b]不是一回事[/b] ——
## 那些每场重置，体力跨战斗保留，由休息区之类的东西回复。
##
## [b]本类不知道任何数值。[/b] 扣多少、回多少一律由调用方传进来：
##
## [codeblock]
## vitality.spend(cost, &"battle_lost")     # 输一场普通战斗
## vitality.restore(amount, &"rest")        # 在休息区歇一会儿
## [endcodeblock]
##
## 「普通 −1、精英 −2」「休息回几点」这些是**内容**，属于节点与章节配置，不属于这里。
## 写死在本类里的话，调一次数值就要改一次代码，而且不同角色、不同章节还想给不同的数 ——
## 到那时改起来就是把同一个常量从三个地方各挖一遍。
##
## 上限同理：由调用方给。角色系统落地前用 [constant PLACEHOLDER_MAX]。
class_name Vitality
extends RefCounted

## 体力变动时发出。[param delta] 是**实际**变化量，可能小于请求量 ——
## 「这一下该扣 3 点」和「实际扣掉了 1 点（只剩 1 点了）」是两回事，
## 监听者（结算界面、日志）关心的通常是后者。
signal changed(current: int, maximum: int, delta: int, reason: StringName)
## 140：没有「归零」信号 —— 战败由调用方查 [method is_depleted] 判定（本类不知道「战败」是什么，也不该知道 BOSS 输了要直接战败）

## 角色系统落地前的默认上限。
##
## [b]占位。[/b] 将来不同角色有不同的初始体力，届时由角色定义提供，
## 本类与所有调用方一行不改 —— 它们本来就只从构造参数拿这个数。
## 与 [CombatantBaseline] 是同一种占位：结构先立住，数值等内容定稿。
const PLACEHOLDER_MAX := 5

var current: int = 0
var maximum: int = 0


func _init(p_max: int = PLACEHOLDER_MAX, p_current: int = -1) -> void:
	maximum = maxi(0, p_max)
	current = maximum if p_current < 0 else clampi(p_current, 0, maximum)


#region 查询
func is_depleted() -> bool:
	return current <= 0


func is_full() -> bool:
	return current >= maximum


## 还剩几成。上限为 0 时返回 0，免得调用方各自防一遍除零。
func ratio() -> float:
	return 0.0 if maximum <= 0 else float(current) / float(maximum)
#endregion


#region 变动
## 改变体力，返回**实际**变化量。超出 [0, maximum] 的部分被截断。
##
## 这是唯一真正动手的方法，[method spend] 与 [method restore] 都走它 ——
## 一处改动一处信号，不会出现「某条路径忘了发 changed」。
func change(delta: int, reason: StringName = &"") -> int:
	if delta == 0 or maximum <= 0:
		return 0
	var before := current
	current = clampi(current + delta, 0, maximum)
	var actual := current - before
	if actual == 0:
		return 0
	changed.emit(current, maximum, actual, reason)
	return actual


## 扣体力。[param amount] 取正数，返回实际扣掉的（正数）。
func spend(amount: int, reason: StringName = &"") -> int:
	return -change(-absi(amount), reason)


## 回体力。[param amount] 取正数，返回实际回复的。
func restore(amount: int, reason: StringName = &"") -> int:
	return change(absi(amount), reason)


## 调整上限。
##
## 与 [method ResourcePool.set_max] 保持一致：**上限增加时当前值同量增加**
## （多一格体力立刻能用，反馈即时），上限降低时当前值按新上限截断。
## 连带的当前值变化以 [param reason] 发出，好和「挨了一下」区分开。
func set_max(new_max: int, reason: StringName = &"max_changed") -> void:
	var value := maxi(0, new_max)
	if value == maximum:
		return
	var grew := value - maximum
	var before := current
	maximum = value
	current = clampi(current + maxi(0, grew), 0, maximum)
	if current != before:
		changed.emit(current, maximum, current - before, reason)
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {"current": current, "max": maximum}


static func from_dict(d: Dictionary) -> Vitality:
	return Vitality.new(int(d.get("max", PLACEHOLDER_MAX)), int(d.get("current", -1)))
#endregion

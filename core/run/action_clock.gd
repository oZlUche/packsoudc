## 行动计数：这一局到现在花了多少行动点（架构文档 5.6）。
##
## 这是 [b]run 级的通用设施[/b]，不属于地图模块 —— 走一步花它，将来搜刮、休息、
## 商店也花它，侵蚀按它推进。所以放在 core/run/ 而不是 core/map/。
##
## 它只会加不会减：行动点是流逝的时间，不是可以攒起来再花的资源。
## 花多少由调用方说了算（[MoveIntent] 给出的 action_cost、节点事件自己的开销），
## 本类不认识任何一条边、任何一种事件 —— 和 [Vitality] 同一条原则。
class_name ActionClock
extends RefCounted

## 每花一次发一次。[param delta] 是这一次花的，[param total] 是累计。
## 侵蚀（[ErosionField]）与 HUD 都听它，谁也不用自己去数。
signal advanced(total: int, delta: int)

var total: int = 0


func _init(p_total: int = 0) -> void:
	total = maxi(0, p_total)


## 花 [param n] 个行动点。0 与负数不花、不发信号 ——
## 「这一步免费」是合法的（将来某些移动方式可能就是免费的），但不能倒着走。
func spend(n: int, reason: StringName = &"") -> void:
	if n <= 0:
		return
	total += n
	advanced.emit(total, n)
	_last_reason = reason


## 上一次花的原因。只是给日志与调试看，不是状态 —— 不进存档
var _last_reason: StringName = &""


func last_reason() -> StringName:
	return _last_reason


#region 存档
func to_dict() -> Dictionary:
	return {"total": total}


static func from_dict(d: Dictionary) -> ActionClock:
	return ActionClock.new(int(d.get("total", 0)))
#endregion

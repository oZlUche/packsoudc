## 自发型规则的时间轮：二叉最小堆。
##
## [b]每条规则在堆里至多有一个条目 —— 只排下一次触发，不预排整条时间线。[/b]
##
## 堆之所以可行，前提是**排定时刻永不失效**：冷却在出手那一刻按当时的速率算死，
## 后来施加的增益只影响再下一次。若改成「速率变化立刻作用于正在走的冷却」，
## 每次变速都要重排整个堆，堆就不划算了。
##
## 移除的规则（buff 掉了）不从堆里删 —— 堆删任意元素代价高。改用**惰性删除**：
## 弹出时发现规则已不在其所属单位的规则表里，直接丢弃。
class_name ScheduleHeap
extends RefCounted

## 条目：[时刻, 次序键, RuleRuntime]
const T := 0
const ORDER := 1
const RULE := 2

var _items: Array = []


func is_empty() -> bool:
	return _items.is_empty()


func size() -> int:
	return _items.size()


func clear() -> void:
	_items.clear()


## 堆顶时刻；空堆返回 -1
func peek_time() -> int:
	return -1 if _items.is_empty() else int(_items[0][T])


func push(time: int, rule: RuleRuntime) -> void:
	_items.append([time, rule.order, rule])
	var i := _items.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if not _less(_items[i], _items[parent]):
			break
		var tmp: Array = _items[i]
		_items[i] = _items[parent]
		_items[parent] = tmp
		i = parent


## 弹出最小条目；空堆返回空数组
func pop() -> Array:
	if _items.is_empty():
		return []
	var top: Array = _items[0]
	var last: Array = _items.pop_back()
	if not _items.is_empty():
		_items[0] = last
		_sift_down(0)
	return top


func _sift_down(start: int) -> void:
	var i := start
	var n := _items.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var smallest := i
		if l < n and _less(_items[l], _items[smallest]):
			smallest = l
		if r < n and _less(_items[r], _items[smallest]):
			smallest = r
		if smallest == i:
			return
		var tmp: Array = _items[i]
		_items[i] = _items[smallest]
		_items[smallest] = tmp
		i = smallest


## 先比时刻，再比次序键。
##
## [b]次序键是确定性的唯一保证。[/b] 同刻并列时若靠堆的内部排布决定先后，
## 同一局面就可能因插入历史不同而产生不同结果，回放与批量模拟随之失效。
static func _less(a: Array, b: Array) -> bool:
	if a[T] != b[T]:
		return a[T] < b[T]
	return a[ORDER] < b[ORDER]

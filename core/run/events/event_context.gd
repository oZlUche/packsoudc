## 事件的条件与后果看得见的那一部分一局状态（063）。[NodeEvents] 造它、把后果的旗子接着走。
##
## 直接动的：体力、钱。经由回调动的：地图 buff（在 [RunState] 手里）。给东西不在这里发 —— 记在 [member items_given]，
## [NodeEvents] 用 `event_resolved` 的 detail 报出去，[RunState] 收进暂存区（和以前的事件一样）。
class_name EventContext
extends RefCounted

var node: MapNode = null
var rng: RandomNumberGenerator = null
var vitality: Vitality = null
var wallet: Wallet = null
var items: ItemDatabase = null
var rules: NodeRules = null
var depth: float = 0.0

## 地图 buff 的四个回调：`(id) -> bool` / `(id) -> bool` / `(id) -> bool` / `(tag) -> bool`。没接就当没有
var grant_map_buff: Callable = Callable()
var remove_map_buff: Callable = Callable()
var has_map_buff: Callable = Callable()
var has_buff_tag: Callable = Callable()

## 后果立的旗子，NodeEvents 看着走
var open_search: bool = false
var open_shop: bool = false
var start_battle: bool = false
var next_event: StringName = &""
## 猎手（071）：迎战 / 逃跑
var hunter_fight: bool = false
var hunter_flee: bool = false

## 后果做了什么（给结果页与日志）
var items_given: Array[StringName] = []
var restored: int = 0
var spent: int = 0
var money: int = 0
var buffs_granted: Array[String] = []
var buffs_removed: Array[String] = []
var log: Array[String] = []


func tag_present(tag: StringName) -> bool:
	return has_buff_tag.is_valid() and bool(has_buff_tag.call(tag))


func buff_present(id: StringName) -> bool:
	return has_map_buff.is_valid() and bool(has_map_buff.call(id))


## 只带非空项的账，给 `event_resolved` 的 detail
func detail() -> Dictionary:
	var d := {}
	if not items_given.is_empty():
		var ids: Array = []
		for id in items_given:
			ids.append(String(id))
		d["items"] = ids
	if restored != 0:
		d["restored"] = restored
	if spent != 0:
		d["spent"] = spent
	if money != 0:
		d["money"] = money
	if not buffs_granted.is_empty():
		d["buffs"] = buffs_granted.duplicate()
	if not buffs_removed.is_empty():
		d["buffs_removed"] = buffs_removed.duplicate()
	if not log.is_empty():
		d["log"] = log.duplicate()
	return d

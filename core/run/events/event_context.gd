## 事件的条件与后果看得见的那一部分一局状态（063；8-3 加了地图、步数、容器、段位与侵蚀深度）。[NodeEvents] 造它、把后果的旗子接着走。
##
## 直接动的：体力、钱、棋盘与暂存区里的东西。经由回调动的：地图 buff（在 [RunState] 手里）。给东西不在这里发 —— 记在 [member items_given]，
## [NodeEvents] 用 `event_resolved` 的 detail 报出去，[RunState] 收进暂存区（和以前的事件一样）。
## 挪人、等时间、改类型、照常发生这几件事也只立旗：怎么走由 [NodeEvents] 定（顺序、计数、猎手的回合都在它与持有方手里）。
class_name EventContext
extends RefCounted

var node: MapNode = null
var rng: RandomNumberGenerator = null
var vitality: Vitality = null
var wallet: Wallet = null
var items: ItemDatabase = null
var rules: NodeRules = null
var depth: float = 0.0
## 地图（8-3）：传送要挑目的地、条件要看类型与距离
var graph: MapGraph = null
## 到现在为止花了多少行动点
var steps: int = 0
## 棋盘与暂存区（可以为 null：没接容器的测试）。「有某道具」看它们，「失去道具」从它们拿
var board: ItemContainer = null
var storage: ItemContainer = null
## 091：局外状态（旗标在里面）。沙盒 / 测试里可能为 null：看旗标的条件永远不满足、立旗标的后果什么也不做
var meta: MetaState = null
## 段位（074）：`() -> int`。没接（这一局没有猎手机制）= -1
var bracket: Callable = Callable()
## 某个点被侵蚀了几层（075）：`(node) -> int`，没被侵蚀 -1。没接（没有侵蚀）= -1
var erosion_depth: Callable = Callable()

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
## 8-3：这个点照它的类型照常发生（休息就回体力、商店就开店……）
var proceed: bool = false
## 085：从这个撤离点撤离（事件对话里的「撤离」选项）
var extract: bool = false
## 8-3：这个点从此算这种类型（空 = 不改）
var new_type: StringName = &""
## 8-3：传送到哪个点（-1 = 不传）、花几点
var teleport_to: int = -1
var teleport_cost: int = 0
## 8-3：原地耗掉几个行动点（侵蚀照推进）
var wait_actions: int = 0

## 后果做了什么（给结果页与日志）
var items_given: Array[StringName] = []
var items_lost: Array[String] = []
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


func bracket_now() -> int:
	return int(bracket.call()) if bracket.is_valid() else -1


func depth_at(n: MapNode) -> int:
	return int(erosion_depth.call(n)) if erosion_depth.is_valid() and n != null else -1


## 棋盘 / 暂存区里某道具有几件（id 为空 = 任何道具；tag 给了就只算带这个标签的）。[param where]：0 棋盘、1 暂存区、2 两处
func count_item(id: StringName, where: int = 2, tag: StringName = &"") -> int:
	var n := 0
	for c in containers(where):
		for inst in (c as ItemContainer).items():
			var def := (inst as ItemInstance).def
			if (id == &"" or def.id == id) and (tag == &"" or def.tags.has(tag)):
				n += 1
	return n


func containers(where: int) -> Array:
	var out: Array = []
	if where != 1 and board != null:
		out.append(board)
	if where != 0 and storage != null:
		out.append(storage)
	return out


## 只带非空项的账，给 `event_resolved` 的 detail
func detail() -> Dictionary:
	var d := {}
	if not items_given.is_empty():
		var ids: Array = []
		for id in items_given:
			ids.append(String(id))
		d["items"] = ids
	if not items_lost.is_empty():
		d["items_lost"] = items_lost.duplicate()
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
	if wait_actions > 0:
		d["waited"] = wait_actions
	if new_type != &"":
		d["type_changed"] = String(new_type)
	if teleport_to >= 0:
		d["teleported"] = teleport_to
	if not log.is_empty():
		d["log"] = log.duplicate()
	return d

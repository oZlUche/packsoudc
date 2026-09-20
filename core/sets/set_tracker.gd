## 套装的激活状态跟踪（架构文档第 9 节）。
##
## [b]套装是背包层的独立系统，不是编译期的一步。[/b]
## 物品一拖进棋盘就重新计数，达到档位即激活 —— UI 靠 [signal activation_changed]
## 实时做暗／亮切换，不必等到进入战斗。
##
## 各系统按**作用域**取自己需要的那部分：编译器取 `combat`，
## 掉落系统取 `loot`。彼此不需要认识对方，新增作用域也不牵动已有系统。
class_name SetTracker
extends RefCounted

## 任一套装的件数或激活档位发生变化时发出。UI 据此刷新。
signal activation_changed

var db: SetDatabase = null

var _board: GridInventory = null
## set_id -> 件数
var _counts: Dictionary = {}


static func create(p_db: SetDatabase) -> SetTracker:
	var t := SetTracker.new()
	t.db = p_db
	return t


## 绑定作战棋盘。**只数棋盘上的** —— 暂存区的物品不参战，也不该凑套装，
## 与 3.4 的参战规则一致。
func bind(board: GridInventory) -> void:
	if _board != null and _board.changed.is_connected(recount):
		_board.changed.disconnect(recount)
	_board = board
	if _board != null:
		_board.changed.connect(recount)
	recount()


func recount() -> void:
	var fresh := {}
	if _board != null:
		var seen_defs := {}
		for inst in _board.items():
			var item := inst as ItemInstance
			if item.def == null or item.def.set_id == &"":
				continue
			if _board.acts_as_bag(item.def):
				continue  # 包不算套装部件，它是承载物
			var set_id := item.def.set_id
			var def := db.get_def(set_id) if db != null else null
			if def != null and def.count_mode == ItemSetDef.CountMode.DISTINCT_DEFS:
				var key := "%s/%s" % [set_id, item.def.id]
				if seen_defs.has(key):
					continue
				seen_defs[key] = true
			fresh[set_id] = int(fresh.get(set_id, 0)) + 1

	if fresh == _counts:
		return
	_counts = fresh
	activation_changed.emit()


#region 查询
func count_of(set_id: StringName) -> int:
	return int(_counts.get(set_id, 0))


## 当前有部件在场的套装 id，按字典序 —— 顺序稳定，编译结果才可复现
func tracked_ids() -> Array:
	var k := _counts.keys()
	k.sort()
	return k


func active_tiers(set_id: StringName) -> Array[SetTier]:
	var def := db.get_def(set_id) if db != null else null
	if def == null:
		return [] as Array[SetTier]
	return def.active_tiers(count_of(set_id))


func is_active(set_id: StringName) -> bool:
	return not active_tiers(set_id).is_empty()


## 取所有已激活套装中属于该作用域的效果。
##
## 这是各系统唯一的入口：编译器传 [constant SetScope.COMBAT]，
## 掉落系统传 [constant SetScope.LOOT]。
func effects_in_scope(scope: StringName) -> Array[SetEffect]:
	var out: Array[SetEffect] = []
	for set_id in tracked_ids():
		for tier in active_tiers(set_id):
			out.append_array((tier as SetTier).effects_in(scope))
	return out


## 给 UI 的进度信息：{count, next, active}
func progress_of(set_id: StringName) -> Dictionary:
	var def := db.get_def(set_id) if db != null else null
	var count := count_of(set_id)
	return {
		"count": count,
		"next": def.next_threshold(count) if def != null else -1,
		"active": is_active(set_id),
	}
#endregion

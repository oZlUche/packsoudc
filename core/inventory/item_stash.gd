## 暂存区：一个**列表**，不是一块地方。
##
## 暂存区只回答「这件东西先放着」，摆在第几行不承载任何信息 —— 不参战（3.4）、
## 不参与邻接、不参与套装。把它做成网格容器，就等于凭空发明一套
## 「暂存区也要会整理」的玩法，而那正是这个区域存在的目的所反对的：
## 它是让玩家腾手的地方，不是第二个要动脑子的棋盘。
##
## 因此这里**没有坐标、没有占格、没有旋转**。异形物品进来只是一行，
## 3×1 的长条和 1×1 的钉子占一样的位置。
##
## [member capacity] 为 0 表示不限。上限是留给数值设计的口子 ——
## 「暂存区能放几件」是个正经的平衡杠杆，但该放几件现在还没定，
## 所以默认不限，不在代码里替设计拍板。
class_name ItemStash
extends ItemContainer

## 0 = 不限
var capacity: int = 0

## 容器级准入标签。为空表示不限制。
var accept_tags: Array[StringName] = []

var _list: Array[ItemInstance] = []


func _init(p_id: int = 0, p_capacity: int = 0) -> void:
	id = p_id
	capacity = p_capacity


#region 查询
func get_item(uid: int) -> ItemInstance:
	for inst in _list:
		if inst.uid == uid:
			return inst
	return null


func has_item(uid: int) -> bool:
	return get_item(uid) != null


## 按当前顺序返回。顺序是玩家自己拖出来的，得原样保留。
func items() -> Array:
	return _list.duplicate()


func item_count() -> int:
	return _list.size()


func is_full() -> bool:
	return capacity > 0 and _list.size() >= capacity


func index_of(uid: int) -> int:
	for i in _list.size():
		if _list[i].uid == uid:
			return i
	return -1


## 容器是否接受这件定义（只看标签，列表容器没有空间可言）。
func accepts(def: ItemDef) -> bool:
	if def == null:
		return false
	if accept_tags.is_empty():
		return true
	for tag in def.tags:
		if accept_tags.has(tag):
			return true
	return false
#endregion


#region 增删
## 插到第 [param at] 行。[param at] 越界会被夹到两端 ——
## 拖到列表下方的空白处是个很自然的「放到最后」，不该判失败。
func insert(inst: ItemInstance, at: int = -1) -> bool:
	if inst == null or inst.def == null or is_full() or not accepts(inst.def):
		return false
	if has_item(inst.uid):
		push_warning("ItemStash.insert: uid %d 已在本容器中，应先 remove" % inst.uid)
		return false
	var index := _list.size() if at < 0 else clampi(at, 0, _list.size())
	_list.insert(index, inst)
	# 列表里没有坐标可言，但这两个字段必须与实际归属一致，别的系统会读
	inst.origin = Vector2i.ZERO
	inst.container_id = id
	_notify_changed()
	return true


func admit(inst: ItemInstance) -> bool:
	return insert(inst, -1)


func can_admit(def: ItemDef) -> bool:
	return not is_full() and accepts(def)


func remove(uid: int) -> ItemInstance:
	var i := index_of(uid)
	if i < 0:
		return null
	var inst := _list[i]
	_list.remove_at(i)
	inst.container_id = 0
	_notify_changed()
	return inst


## 把已在表内的一件挪到第 [param to] 行。
##
## 单独一个方法而不是「先 remove 再 insert」：那样会发两次 changed，
## 中间那一帧列表里少一行，看着像闪烁。
func move(uid: int, to: int) -> bool:
	var from := index_of(uid)
	if from < 0:
		return false
	var inst := _list[from]
	_list.remove_at(from)
	_list.insert(clampi(to, 0, _list.size()), inst)
	_notify_changed()
	return true


func clear() -> void:
	if _list.is_empty():
		return
	for inst in _list:
		inst.container_id = 0
	_list.clear()
	_notify_changed()
#endregion


#region 存档
func to_dict() -> Dictionary:
	var out: Array = []
	for inst in _list:
		out.append(inst.to_dict())
	return {"id": id, "capacity": capacity, "items": out}


static func from_dict(d: Dictionary, db: ItemDatabase) -> ItemStash:
	var stash := ItemStash.new(int(d.get("id", 0)), int(d.get("capacity", 0)))
	for raw in (d.get("items", []) as Array):
		var inst := ItemInstance.from_dict(raw as Dictionary, db)
		if inst != null:
			stash.insert(inst, -1)
	return stash
#endregion

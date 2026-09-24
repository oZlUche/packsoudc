## 物品的运行时实例：可变，归属于某个 [GridInventory]。
##
## uid 为进程内自增，0 表示「无」。[member origin] 与 [member container_id]
## 由容器在放置时写入，外部不要直接改 —— 它们必须与容器的占用表保持一致。
class_name ItemInstance
extends RefCounted

const NONE := 0

static var _next_uid: int = 1

var uid: int = NONE
var def: ItemDef = null

## 0..3，顺时针。
##
## [b]一切道具都能转。[/b] 曾经有过一个 `can_rotate` 开关，用来「钉死某些装备的朝向」——
## 但一件占两格的东西横着还是竖着，是玩家在棋盘上的空间取舍，
## 不是内容作者该替他做的决定。开关删了，理由见架构文档 3.1。
var rotation: int = 0

## 在所属容器中的锚点（形状规范化后的左上角）。
var origin: Vector2i = Vector2i.ZERO

## 所属容器的 id，0 表示游离态（拖拽途中）。
var container_id: int = 0
## 置入这个容器时盖的序号（[GridInventory.place] 在道具从别的容器进来时盖；同容器内挪位置不变）。
## 信仰的激活规则看它：最后置入的信仰道具（[FaithState]）。跟着存档走
var placed_seq: int = 0

## 运行时可变状态：耐久、充能、随机词条等。
## 一切「这一件独有」的数据放这里，不要写回 ItemDef。
var state: Dictionary = {}


static func create(p_def: ItemDef, p_rotation: int = 0) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.uid = _next_uid
	_next_uid += 1
	inst.def = p_def
	inst.rotation = posmod(p_rotation, 4)
	return inst


## 开新一局时调用，让 uid 从 1 重新开始。
static func reset_uid_counter() -> void:
	_next_uid = 1


## 读档后调用：保证之后新建的 uid 不会和存档里已有的撞号。
static func reserve_uid_above(value: int) -> void:
	_next_uid = maxi(_next_uid, value + 1)


static func peek_next_uid() -> int:
	return _next_uid


## 当前旋转下的占格集合。返回的数组是 ItemShape 的内部缓存，不得修改。
func cells() -> Array[Vector2i]:
	if def == null:
		return [] as Array[Vector2i]
	return def.cells_rotated(rotation)


## 当前旋转下的包围盒尺寸（格）。
func size() -> Vector2i:
	if def == null or def.shape == null:
		return Vector2i.ZERO
	return def.shape.size_rotated(rotation)


## 一组「相对原点的偏移」在容器里的绝对格坐标，已按当前朝向变换。
##
## 邻接标记格（[AdjacencyProfile]）就是这样一组偏移。抽在这里，是因为
## 编译器要用它算点亮、界面要用它画标记 —— 两边各写一遍的话，
## 迟早出现「界面画在这格、实际生效在那格」这种最难查的错。
func absolute_cells(offsets: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if def == null or def.shape == null:
		return out
	for o in offsets:
		out.append(origin + def.shape.transform_point(o, rotation))
	return out


## 顺时针旋转一步，返回旋转后的值。不检查是否放得下 —— 那是容器的事。
func rotated_step(steps: int = 1) -> int:
	if def == null:
		return 0
	return posmod(rotation + steps, 4)


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"def": String(def.id) if def != null else "",
		"rot": rotation,
		"origin": [origin.x, origin.y],
		"seq": placed_seq,
		"state": state.duplicate(true),
	}


## db 用于把 def id 还原成 ItemDef。返回 null 表示该 def 已不存在（内容被删）。
static func from_dict(d: Dictionary, db: ItemDatabase) -> ItemInstance:
	var def_id := StringName(d.get("def", ""))
	var found := db.get_def(def_id)
	if found == null:
		push_warning("ItemInstance.from_dict: 未知的 def id '%s'，该物品被丢弃" % def_id)
		return null
	var inst := ItemInstance.new()
	inst.uid = int(d.get("uid", NONE))
	inst.def = found
	inst.rotation = int(d.get("rot", 0))
	var o: Array = d.get("origin", [0, 0])
	inst.origin = Vector2i(int(o[0]), int(o[1]))
	inst.placed_seq = int(d.get("seq", 0))
	inst.state = (d.get("state", {}) as Dictionary).duplicate(true)
	reserve_uid_above(inst.uid)
	return inst

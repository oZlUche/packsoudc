## 地上（128，原「地上」）：一个**列表**，外加每件一个「落点」。
##
## 128（作者定）：不画地上框 —— 格子外的整块屏幕就是地上，拖出背包放哪就在哪（[GroundLayer] 画）。
## 落点 [member spots] **只是记个样子**：不占格、不碰撞、不参与任何规则，下面 3.4 的理由原样成立。
##
## 地上只回答「这件东西先放着」，摆在第几行不承载任何信息 —— 不参战（3.4）、
## 不参与邻接、不参与套装。把它做成网格容器，就等于凭空发明一套
## 「地上也要会整理」的玩法，而那正是这个区域存在的目的所反对的：
## 它是让玩家腾手的地方，不是第二个要动脑子的棋盘。
##
## 因此这里**没有坐标、没有占格、没有旋转**。异形物品进来只是一行，
## 3×1 的长条和 1×1 的钉子占一样的位置。
##
## [member capacity] 为 0 表示不限。上限是留给数值设计的口子 ——
## 「地上能放几件」是个正经的平衡杠杆，但该放几件现在还没定，
## 所以默认不限，不在代码里替设计拍板。
class_name ItemStash
extends ItemContainer

## 0 = 不限
var capacity: int = 0

var _list: Array[ItemInstance] = []

## 128：没有落点（[method insert] 不给）
const NO_SPOT := Vector2(-1, -1)
## 自动铺放离屏幕边留的空（归一化）
const SPOT_MARGIN := 0.02
## 128：uid → 落点（归一化到 0～1 的屏幕坐标，道具包围盒的左上角）。只是样子，见类注释
var spots: Dictionary = {}
## 一格在地上占多大（归一化）。[GroundLayer] 按自己的尺寸设；没有地层（测试、沙盒）用默认 1600×900 下的一格（60 像素）
var cell_norm: Vector2 = Vector2(60.0 / 1600.0, 60.0 / 900.0)
## 自动铺放要躲开的区域（归一化矩形，各屏的面板）。[GroundLayer] 设，不存档
var avoid: Array[Rect2] = []
## 134：刚落地的那件从哪落 —— 只是样子，**不存档、不进 [method to_dict]**。界面层写（拖拽放手、顶出），[GroundLayer] 读完即删：
## [code]Vector2[/code] = 从这个全局像素（道具包围盒左上角）落过来；[code]true[/code] = 就地落下（只缩放 + 弹跳）；
## [code]false[/code] = 不播（读档、回到存过东西的点 —— 不是「掉」，是本来就在）。没写 = 从最近的面板边缘落出来
var landing_from: Dictionary = {}


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


## 还装得下 n 件吗。整批塞东西之前先问这一句，免得塞到一半才发现不够。
func room_for(n: int) -> bool:
	return capacity <= 0 or _list.size() + n <= capacity


func index_of(uid: int) -> int:
	for i in _list.size():
		if _list[i].uid == uid:
			return i
	return -1


## 容器是否接受这件定义：地上什么都收（140：容器级准入标签删了，生产从来不设）
func accepts(def: ItemDef) -> bool:
	return def != null
#endregion


#region 增删
## 插到第 [param at] 行。[param at] 越界会被夹到两端 ——
## 拖到列表下方的空白处是个很自然的「放到最后」，不该判失败。
## 128：[param spot] 是落点（归一化屏幕坐标）；不给就 [method next_free_spot] 自动找一个空处
func insert(inst: ItemInstance, at: int = -1, spot: Vector2 = NO_SPOT) -> bool:
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
	spots[inst.uid] = _clamp_spot(spot) if has_spot_value(spot) else next_free_spot(inst)
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
	spots.erase(uid)
	landing_from.erase(uid)
	inst.container_id = 0
	_notify_changed()
	return inst


func clear() -> void:
	if _list.is_empty():
		return
	for inst in _list:
		inst.container_id = 0
	_list.clear()
	spots.clear()
	landing_from.clear()
	_notify_changed()
#endregion


#region 落点（128）
static func has_spot_value(spot: Vector2) -> bool:
	return spot.x >= 0.0 and spot.y >= 0.0


static func _clamp_spot(spot: Vector2) -> Vector2:
	return Vector2(clampf(spot.x, 0.0, 1.0), clampf(spot.y, 0.0, 1.0))


## 这件的落点（不在表里 [constant NO_SPOT]）
func spot_of(uid: int) -> Vector2:
	return spots.get(uid, NO_SPOT)


## 挪一件的落点（从地上拿起又放回地上）。不在表里返回 false
func set_spot(uid: int, spot: Vector2) -> bool:
	if not has_item(uid) or not has_spot_value(spot):
		return false
	spots[uid] = _clamp_spot(spot)
	_notify_changed()
	return true


## 一件在地上占多大（归一化）：按它当前朝向的包围盒
func span_of(inst: ItemInstance) -> Vector2:
	var hi := Vector2i.ZERO
	if inst != null and inst.def != null:
		for c in inst.def.cells_rotated(inst.rotation):
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Vector2(hi + Vector2i.ONE) * cell_norm


## 这件在地上占的那块（归一化）
func spot_rect(inst: ItemInstance) -> Rect2:
	return Rect2(spot_of(inst.uid), span_of(inst))


## 给一件找个空处：从屏幕左下角起，一格一格往右、一行一行往上，找第一块不压着别人、不压着面板（[member avoid]）的地方。
## 满地了就叠在左下角（允许重叠，128 待定 2）
func next_free_spot(inst: ItemInstance) -> Vector2:
	var span := span_of(inst)
	var step := Vector2(maxf(cell_norm.x, 0.005), maxf(cell_norm.y, 0.005))
	var taken: Array[Rect2] = avoid.duplicate()
	for other in _list:
		if other != inst and spots.has(other.uid):
			taken.append(spot_rect(other))
	var y := 1.0 - SPOT_MARGIN - span.y
	while y >= 0.0:
		var x := SPOT_MARGIN
		while x + span.x <= 1.0 - SPOT_MARGIN + 0.0001:
			var r := Rect2(Vector2(x, y), span)
			var free := true
			for t in taken:
				if t.intersects(r):
					free = false
					break
			if free:
				return Vector2(x, y)
			x += step.x
		y -= step.y
	return _clamp_spot(Vector2(SPOT_MARGIN, 1.0 - SPOT_MARGIN - span.y))
#endregion


#region 存档
func to_dict() -> Dictionary:
	var out: Array = []
	var where: Array = []
	for inst in _list:
		out.append(inst.to_dict())
		var at := spot_of(inst.uid)
		where.append([at.x, at.y])
	return {"id": id, "capacity": capacity, "items": out, "spots": where}


static func from_dict(d: Dictionary, db: ItemDatabase) -> ItemStash:
	var stash := ItemStash.new(int(d.get("id", 0)), int(d.get("capacity", 0)))
	# 128：落点和道具一一对应；旧档没有 spots 就全部重新铺
	var where: Array = d.get("spots", []) as Array
	var raws: Array = d.get("items", []) as Array
	for i in raws.size():
		var inst := ItemInstance.from_dict(raws[i] as Dictionary, db)
		if inst != null:
			stash.insert(inst, -1, read_spot(where[i] if i < where.size() else null))
	return stash


## 存档里的一个落点 `[x, y]` → 落点；不合法 [constant NO_SPOT]
static func read_spot(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return NO_SPOT
#endregion

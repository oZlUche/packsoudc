## 物品的异形占格定义。
##
## [member cells] 是相对原点的格子偏移集合，不要求包含 (0, 0)，也不要求连通 ——
## 是否允许不连通的形状由内容设计决定，本类不作限制。
##
## 四个旋转在首次访问时惰性计算并缓存。顺时针 90° 为 (x, y) -> (-y, x)，
## 旋转后平移到 min = (0, 0)，并按字典序排序得到唯一的规范形式，
## 这样同一形状的不同表示可以直接用 == 比较。
class_name ItemShape
extends Resource

# 必须声明在 cells 之前：cells 的 setter 会在资源加载期被调用，
# 那时若 _rot_cache 尚未初始化，赋值会落空。
var _rot_cache: Array = []
## 每一步旋转后减去的平移量。插槽格在轮廓之外，必须跟形状用同一套平移，
## 否则物品一转，标记位置就和实际生效的格子对不上。
var _step_offset: Array = []

@export var cells: Array[Vector2i] = [Vector2i.ZERO]:
	set(value):
		cells = value
		_rot_cache = []
		_step_offset = []


## 取指定旋转下的占格集合。rot 会被折算到 0..3。
##
## [b]返回的数组是内部缓存，调用方不得修改。[/b] 拖拽期间每帧都会调用它做碰撞检测，
## 这里刻意不做防御性拷贝。
func cells_rotated(rot: int) -> Array[Vector2i]:
	if _rot_cache.is_empty():
		_build_cache()
	return _rot_cache[posmod(rot, 4)]


## 指定旋转下的包围盒尺寸（格）。
func size_rotated(rot: int) -> Vector2i:
	var cs := cells_rotated(rot)
	if cs.is_empty():
		return Vector2i.ZERO
	var mx := Vector2i.ZERO
	for c in cs:
		mx.x = maxi(mx.x, c.x)
		mx.y = maxi(mx.y, c.y)
	return mx + Vector2i.ONE


## 占格数量。
func cell_count() -> int:
	return cells.size()


## 本形状有几个在视觉上不同的旋转（1、2 或 4）。
##
## 正方形返回 1，长条返回 2。UI 用它决定要不要显示旋转提示 ——
## 对一个 2x2 方块按 R 键毫无反应会让玩家以为功能坏了。
func distinct_rotation_count() -> int:
	if _rot_cache.is_empty():
		_build_cache()
	var seen: Array = []
	for rot in 4:
		var c: Array[Vector2i] = _rot_cache[rot]
		if not seen.has(c):
			seen.append(c)
	return seen.size()


## 形状是否可用：非空且无重复格。
func is_valid() -> bool:
	if cells.is_empty():
		return false
	var seen := {}
	for c in cells:
		if seen.has(c):
			return false
		seen[c] = true
	return true


## 把一个「相对本形状原点的偏移」按该朝向下形状所经历的同一变换转过去。
##
## 用于插槽格：它们在轮廓之外，`cells_rotated` 的规范化平移对它们同样适用，
## 必须共用同一个平移量，不能各转各的。
func transform_point(p: Vector2i, rot: int) -> Vector2i:
	if _rot_cache.is_empty():
		_build_cache()
	var steps := posmod(rot, 4)
	var q: Vector2i = p - _step_offset[0]
	for i in range(1, steps + 1):
		q = Vector2i(-q.y, q.x) - _step_offset[i]
	return q


## 一组偏移的批量变换。
func transform_points(points: Array[Vector2i], rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in points:
		out.append(transform_point(p, rot))
	return out


func _build_cache() -> void:
	_rot_cache = []
	_step_offset = []
	var cur: Array[Vector2i] = cells.duplicate()
	for i in 4:
		if i > 0:
			cur = _rotate_cw(cur)
		var off := _min_of(cur)
		var shifted: Array[Vector2i] = []
		for c in cur:
			shifted.append(c - off)
		shifted.sort()
		_rot_cache.append(shifted)
		_step_offset.append(off)
		cur = shifted


static func _min_of(cs: Array[Vector2i]) -> Vector2i:
	if cs.is_empty():
		return Vector2i.ZERO
	var mn := cs[0]
	for c in cs:
		mn.x = mini(mn.x, c.x)
		mn.y = mini(mn.y, c.y)
	return mn


static func _rotate_cw(cs: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cs:
		out.append(Vector2i(-c.y, c.x))
	return out


## 平移到 min = (0, 0) 并排序，得到与表示方式无关的规范形式。
static func _normalize(cs: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if cs.is_empty():
		return out
	var mn := cs[0]
	for c in cs:
		mn.x = mini(mn.x, c.x)
		mn.y = mini(mn.y, c.y)
	for c in cs:
		out.append(c - mn)
	out.sort()
	return out


## 从紧凑的文本写法构造形状，便于测试与手写数据：
## "##." 一行代表一列格子，'#' 为占格，其余字符留空。
##     ItemShape.from_ascii(["##", ".#"])  ->  L 形三格
static func from_ascii(rows: Array) -> ItemShape:
	var s := ItemShape.new()
	var cs: Array[Vector2i] = []
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] == "#":
				cs.append(Vector2i(x, y))
	s.cells = cs
	return s

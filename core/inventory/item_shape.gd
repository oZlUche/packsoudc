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
## 正方形返回 1，长条返回 2。[method GridInventory.find_first_fit] 用它剪枝：只试彼此不同的朝向。
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


## [method transform_point] 的逆：把一个「在 rot 朝向下的坐标」折回 rot 0 的坐标系。
##
## 包的内容物要用它：内容物在棋盘上的位置是包**当前**朝向下的坐标，
## 而「相对包的本地坐标」定义在包的 rot 0 坐标系里。先折回本地，再按新朝向正变换，
## 包怎么转内容物就怎么转 —— 这就是本地坐标与全局坐标的区别。
func untransform_point(q: Vector2i, rot: int) -> Vector2i:
	if _rot_cache.is_empty():
		_build_cache()
	var steps := posmod(rot, 4)
	var p := q
	for i in range(steps, 0, -1):
		p = p + _step_offset[i]
		p = Vector2i(p.y, -p.x)      # 顺时针 (x, y) -> (-y, x) 的逆
	return p + _step_offset[0]



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


## 从按行拆开的 0/1 写法构造形状，便于测试与手写数据：一个字符串一行，`1` 为占格，其余字符（`0`、`.`、空格）算空。
##     ItemShape.from_ascii(["11", "01"])  ->  L 形三格
##
## [method from_bits] 是正式记法，拆行后走这里；140 删了旧的 `#` 写法，测试也一律用 0/1。
static func from_ascii(rows: Array) -> ItemShape:
	var s := ItemShape.new()
	var cs: Array[Vector2i] = []
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] == "1":
				cs.append(Vector2i(x, y))
	s.cells = cs
	return s


## 由 0/1 数字串构造，行以换行分隔。**这是形状的正式记法。**
##
## [codeblock]
## ItemShape.from_bits("11\n10")   # L 形三格
## [/codeblock]
##
## 形状本质就是一张布尔矩阵，0/1 串是它所见即所得的写法：
## 读的人不必在脑子里把 `##/#.` 这种压扁的形式还原回二维。
## 文档表格、导入器的 JSON、测试三方共用这一种记法。
static func from_bits(text: String) -> ItemShape:
	var rows: Array = []
	for line in text.strip_edges().split("\n"):
		rows.append((line as String).strip_edges())
	return from_ascii(rows)


## 反向：导出成 0/1 数字串。用于导入器回写、报错信息与调试。
##
## 导出的是**规范化之后**的占格（已平移到 min = (0,0)），
## 因此 `from_bits(s.to_bits())` 与 `s` 的各旋转占格逐一相等。
func to_bits(rot: int = 0) -> String:
	var cs := cells_rotated(rot)
	if cs.is_empty():
		return ""
	var size := size_rotated(rot)
	var rows: Array[PackedByteArray] = []
	for y in size.y:
		var row := PackedByteArray()
		row.resize(size.x)
		row.fill(48)  # '0'
		rows.append(row)
	for c in cs:
		rows[c.y][c.x] = 49  # '1'
	var out: PackedStringArray = []
	for row in rows:
		out.append(row.get_string_from_ascii())
	return "\n".join(out)

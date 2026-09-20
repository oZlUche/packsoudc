extends RefCounted


static func run(t: TestCase) -> void:
	t.begin("ItemShape")

	# --- 构造与基本属性 ---
	var l_shape := ItemShape.from_ascii(["##", "#."])  # L 形三格
	t.eq(l_shape.cell_count(), 3, "L 形应占 3 格")
	t.check(l_shape.is_valid(), "L 形应为合法形状")
	t.eq(l_shape.size_rotated(0), Vector2i(2, 2), "L 形包围盒为 2x2")

	var bar := ItemShape.from_ascii(["#", "#", "#"])  # 竖向 1x3
	t.eq(bar.size_rotated(0), Vector2i(1, 3), "竖条 rot0 包围盒 1x3")
	t.eq(bar.size_rotated(1), Vector2i(3, 1), "竖条 rot1 包围盒 3x1")
	t.eq(bar.size_rotated(2), Vector2i(1, 3), "竖条 rot2 回到 1x3")

	# --- 旋转闭环 ---
	t.eq(bar.cells_rotated(4), bar.cells_rotated(0), "旋转 4 步应回到原状")
	t.eq(bar.cells_rotated(-1), bar.cells_rotated(3), "负数旋转应折算到 0..3")

	# --- 规范化：不同写法的同一形状必须相等 ---
	var at_origin := ItemShape.new()
	at_origin.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	var shifted := ItemShape.new()
	shifted.cells = [Vector2i(5, -3), Vector2i(6, -3)] as Array[Vector2i]
	t.eq(
		at_origin.cells_rotated(0),
		shifted.cells_rotated(0),
		"平移过的同一形状规范化后应完全相等"
	)

	# --- 排序后的规范形式与书写顺序无关 ---
	var reordered := ItemShape.new()
	reordered.cells = [Vector2i(1, 0), Vector2i(0, 0)] as Array[Vector2i]
	t.eq(
		at_origin.cells_rotated(0),
		reordered.cells_rotated(0),
		"书写顺序不同的同一形状规范化后应相等"
	)

	# --- 对称形状的可辨旋转数 ---
	var square := ItemShape.from_ascii(["##", "##"])
	t.eq(square.distinct_rotation_count(), 1, "2x2 方块只有 1 种可辨朝向")
	t.eq(bar.distinct_rotation_count(), 2, "长条有 2 种可辨朝向")
	t.eq(l_shape.distinct_rotation_count(), 4, "L 形有 4 种可辨朝向")

	var single := ItemShape.from_ascii(["#"])
	t.eq(single.distinct_rotation_count(), 1, "单格只有 1 种可辨朝向")

	# --- 缓存随 cells 改写失效 ---
	var mutable := ItemShape.from_ascii(["#"])
	t.eq(mutable.size_rotated(0), Vector2i(1, 1), "改写前为 1x1")
	mutable.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	t.eq(mutable.size_rotated(0), Vector2i(3, 1), "改写 cells 后缓存应失效并重算")

	# --- 非法形状 ---
	var empty := ItemShape.new()
	empty.cells = [] as Array[Vector2i]
	t.check(not empty.is_valid(), "空形状非法")
	t.eq(empty.size_rotated(0), Vector2i.ZERO, "空形状包围盒为 0")

	var dup := ItemShape.new()
	dup.cells = [Vector2i(0, 0), Vector2i(0, 0)] as Array[Vector2i]
	t.check(not dup.is_valid(), "含重复格的形状非法")

	# --- 不连通形状：允许存在，由内容设计决定用不用 ---
	var split := ItemShape.from_ascii(["#.#"])
	t.check(split.is_valid(), "不连通形状在数据层视为合法")
	t.eq(split.cell_count(), 2, "不连通形状占 2 格")

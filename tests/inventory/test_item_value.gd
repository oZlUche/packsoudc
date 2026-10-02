## 道具本身的价值（架构文档 6.4）：稀有度 × 尺寸，可覆盖。
##
## 期望值从 [constant ItemValue.BASE_PER_CELL] 推，不写死具体金额 ——
## 那张表是占位，经济系统一定会改它。这里守的是形状：越稀有越贵、越大越贵、覆盖优先。
extends RefCounted


static func _def(rarity: int, rows: Array, value: int = 0) -> ItemDef:
	var d := ItemDef.new()
	d.id = &"x"
	d.shape = ItemShape.from_ascii(rows)
	d.rarity = rarity
	d.value = value
	return d


static func run(t: TestCase) -> void:
	t.begin("道具价值 · 稀有度 × 尺寸")

	var table := ItemValue.BASE_PER_CELL
	for r in table.size():
		t.eq(ItemValue.of(_def(r, ["#"])), table[r], "稀有度 %d 的 1 格道具 = 表里那一档" % r)
		t.eq(ItemValue.of(_def(r, ["##", "##"])), table[r] * 4, "同档 4 格 = 4 倍")
	for r in range(1, table.size()):
		t.check(ItemValue.of(_def(r, ["#"])) > ItemValue.of(_def(r - 1, ["#"])),
			"稀有度 %d 比 %d 贵 —— 表可以改数，不能改这个形状" % [r, r - 1])

	# --- 越界的稀有度夹到两端，不崩 ---
	t.eq(ItemValue.of(_def(99, ["#"])), table[table.size() - 1], "超出表的稀有度按最高档")
	t.eq(ItemValue.of(_def(-3, ["#"])), table[0], "负的按最低档")

	# --- 覆盖 ---
	t.eq(ItemValue.of(_def(0, ["##", "##"], 999)), 999, "填了 value 就按 value，不再算")
	t.eq(ItemValue.of(null), 0, "空定义值 0")
	var no_shape := ItemDef.new()
	no_shape.rarity = 4
	t.eq(ItemValue.of(no_shape), 0, "没形状就没尺寸，值 0")

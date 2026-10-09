## 棋盘模式与包体系统。
##
## 这是依《背包乱斗》真实机制修正后的空间模型（架构文档 3.2）：
## 棋盘开局全部不可用，可用格来自玩家放上去的包；普通物品只能整件落进单个包内。
extends RefCounted


static func _def(id: String, rows: Array, tags: Array = []) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(rows)
	var t: Array[StringName] = []
	for tag in tags:
		t.append(StringName(tag))
	d.tags = t
	return d


static func _bag(id: String, rows: Array, accept: Array = []) -> ItemDef:
	var d := _def(id, rows)
	d.is_bag = true
	var t: Array[StringName] = []
	for tag in accept:
		t.append(StringName(tag))
	d.bag_accept_tags = t
	return d



## 140：原地转包 = 摘下来、换个朝向放回去（和拖拽中按 R 同一条路）；转不动就原样放回。成功返回脱落的实例，失败 null
static func _turn_bag(board: GridInventory, bag_uid: int, steps: int):
	var bag := board.get_item(bag_uid)
	var origin := bag.origin
	var old_rot := bag.rotation
	var payload := board.detach_bag(bag_uid)
	var result := board.attach_bag_shedding(payload, origin, posmod(old_rot + steps, 4))
	if not result["ok"]:
		board.attach_bag(payload, origin, old_rot)
		return null
	return result["fallen"]

static func run(t: TestCase) -> void:
	t.begin("棋盘与包体")

	ItemInstance.reset_uid_counter()
	var big_bag := _bag("bag6", ["11", "11", "11"])     # 2x3，6 格
	var tiny_bag := _bag("bag1", ["1"])                  # 1x1
	var belt := _bag("belt", ["1", "1"], ["potion"])     # 1x2，只收药水
	var dot := _def("dot", ["1"])
	var bar := _def("bar", ["1", "1", "1"])              # 1x3
	var wide := _def("wide", ["11"])                     # 2x1
	var potion := _def("potion", ["1"], ["potion"])

	# --- 空棋盘：一格都不能用 ---
	var board := GridInventory.new(Vector2i(7, 9), 1, true)
	t.eq(board.usable_cell_count(), 0, "空棋盘没有任何可用格")
	t.eq(board.free_cell_count(), 0, "空棋盘没有任何空闲格")
	t.check(not board.is_covered(Vector2i(0, 0)), "未放包时格子未被覆盖")
	var loose := ItemInstance.create(dot)
	t.check(not board.place(loose, Vector2i(0, 0), 0), "空棋盘上放不下普通物品")
	t.eq(board.item_count(), 0, "被拒后棋盘仍为空")

	# --- 放包后才有可用格 ---
	var b1 := ItemInstance.create(big_bag)
	t.check(board.place(b1, Vector2i(0, 0), 0), "包可以直接放在空棋盘上")
	t.eq(board.usable_cell_count(), 6, "2x3 的包提供 6 个可用格")
	t.eq(board.free_cell_count(), 6, "包内目前全空")
	t.check(board.is_covered(Vector2i(1, 2)), "包覆盖范围内的格子可用")
	t.check(not board.is_covered(Vector2i(2, 0)), "包外的格子仍不可用")
	t.eq(board.bag_at(Vector2i(0, 0)), b1.uid, "格子记录了覆盖它的包")
	t.eq(board.cell_uid(Vector2i(0, 0)), GridInventory.EMPTY_UID, "包不占普通物品的占用表")

	# --- 包内放物品 ---
	var d1 := ItemInstance.create(dot)
	t.check(board.place(d1, Vector2i(0, 0), 0), "包内可以放物品")
	t.eq(board.free_cell_count(), 5, "放入 1 格后剩 5")
	t.eq(board.bag_of(d1.uid), b1.uid, "物品归属于覆盖它的包")
	t.eq(board.contents_of(b1.uid), [d1.uid] as Array[int], "包的内容物列表")
	t.eq(board.bag_of(b1.uid), GridInventory.EMPTY_UID, "包本身不属于任何包")

	var out_of_bag := ItemInstance.create(dot)
	t.check(not board.place(out_of_bag, Vector2i(3, 3), 0), "包外仍放不下物品")

	var overhang := ItemInstance.create(bar)
	t.check(not board.place(overhang, Vector2i(1, 1), 0), "1x3 从 y=1 起会伸出包外，应被拒绝")
	t.check(board.place(overhang, Vector2i(1, 0), 0), "1x3 沿包的整列放得下")
	t.eq(board.free_cell_count(), 2, "6 格用掉 4 格")

	# --- 包之间不能重叠 ---
	var b2 := ItemInstance.create(big_bag)
	t.check(not board.place(b2, Vector2i(1, 1), 0), "包与已有的包重叠，应被拒绝")
	t.check(board.place(b2, Vector2i(2, 0), 0), "错开后可以放第二个包")
	t.eq(board.usable_cell_count(), 12, "两个 2x3 的包共 12 格")

	# --- 可以横跨两个包，但谁的内容物都不算 ---
	board.remove(overhang.uid)   # 它占着 (1,2)，先挪开腾出跨包的位置
	var straddle := ItemInstance.create(wide)
	t.check(board.place(straddle, Vector2i(1, 2), 0),
		"2x1 横跨两个相邻的包，放得下 —— 每格有包覆盖就行")
	t.eq(board.bag_of(straddle.uid), GridInventory.EMPTY_UID,
		"**跨包的物品不属于任何包**：两边的加成都拿不到，这是用空间换加成的取舍")
	t.eq(board.bags_touching(straddle.uid), [b1.uid, b2.uid] as Array[int], "但碰到了两个包")
	t.check(not board.contents_of(b1.uid).has(straddle.uid), "不在第一个包的内容物里")
	t.eq(board.straddlers_of(b1.uid), [straddle.uid] as Array[int], "在第一个包的跨包名单里")
	t.eq(board.straddlers_of(b2.uid), [straddle.uid] as Array[int], "也在第二个包的")
	board.remove(straddle.uid)
	board.place(overhang, Vector2i(1, 0), 0)   # 放回去，后面的用例按原状态写
	t.check(board.place(straddle, Vector2i(2, 0), 0), "整件落在第二个包内也可以")
	t.eq(board.bag_of(straddle.uid), b2.uid, "这时归属于第二个包")

	# --- 非空的包不能直接移除 ---
	t.check(board.is_bag_with_contents(b1.uid), "第一个包有内容物")
	t.is_null(board.remove(b1.uid), "非空的包 remove 应返回 null")
	t.check(board.has_item(b1.uid), "被拒后包仍在棋盘上")

	# --- 空包可以旋转 ---
	var empty_board := GridInventory.new(Vector2i(6, 6), 9, true)
	var eb := ItemInstance.create(big_bag)
	empty_board.place(eb, Vector2i(0, 0), 0)
	empty_board.remove(eb.uid)
	t.check(empty_board.place(eb, Vector2i(0, 0), 1), "空包可以换个朝向放回去")
	t.eq(eb.rotation, 1, "旋转生效")
	t.check(empty_board.is_covered(Vector2i(2, 1)), "旋转后覆盖范围跟着变（3x2）")
	t.check(not empty_board.is_covered(Vector2i(0, 2)), "旋转后原先的覆盖已释放")

	# --- 摘下与放回 ---
	var payload := board.detach_bag(b1.uid)
	t.check(not payload.is_empty(), "detach_bag 应返回载荷")
	t.eq((payload["contents"] as Array).size(), 2, "载荷含 2 件内容物")
	t.check(not board.has_item(b1.uid), "摘下后包不在棋盘上")
	t.check(not board.has_item(d1.uid), "内容物也一并摘下")
	t.eq(board.usable_cell_count(), 6, "只剩第二个包的 6 格")

	t.check(board.attach_bag(payload, Vector2i(0, 3), 0), "载荷可以整体放到别处")
	t.eq(board.bag_of(d1.uid), b1.uid, "内容物仍属于原来的包")
	t.eq(d1.origin, Vector2i(0, 3), "内容物保持相对位置")
	t.eq(board.item_count(), 5, "两个包 + 三件物品")

	# --- 换朝向放回：内容物按本地坐标跟着转，一件不少，严格版也放得回 ---
	var p2 := board.detach_bag(b1.uid)
	var turned := board.bag_fit_report(p2, Vector2i(0, 3), 1)
	t.check(turned["ok"] and (turned["fallen"] as Array).is_empty(),
		"换个朝向放回也一件不少 —— 竖着的 1x3 跟着包一起变横")
	t.check(board.attach_bag(p2, Vector2i(0, 3), 0), "原朝向放回成功")

	# --- 包体准入标签 ---
	var belt_board := GridInventory.new(Vector2i(4, 4), 2, true)
	var belt_inst := ItemInstance.create(belt)
	belt_board.place(belt_inst, Vector2i(0, 0), 0)
	t.check(not belt_board.place(ItemInstance.create(dot), Vector2i(0, 0), 0), "药水带不收普通物品")
	t.check(belt_board.place(ItemInstance.create(potion), Vector2i(0, 0), 0), "药水带收药水")

	# --- 包在自由容器里只是普通物品 ---
	var loot := GridInventory.new(Vector2i(6, 6), 3)  # requires_bag = false
	var looted_bag := ItemInstance.create(big_bag)
	t.check(not loot.acts_as_bag(big_bag), "自由容器里包不作为包生效")
	t.check(loot.place(looted_bag, Vector2i(0, 0), 0), "包可以作为战利品躺在尸体里")
	t.eq(loot.cell_uid(Vector2i(0, 0)), looted_bag.uid, "此时它占的是普通物品占用表")
	t.eq(loot.bag_at(Vector2i(0, 0)), GridInventory.EMPTY_UID, "它不提供覆盖")
	t.eq(loot.bag_of(looted_bag.uid), GridInventory.EMPTY_UID, "自由容器无容纳关系")
	t.check(not loot.place(ItemInstance.create(dot), Vector2i(0, 0), 0), "它像普通物品一样挡住格子")
	t.check(loot.place(ItemInstance.create(dot), Vector2i(3, 3), 0), "空处照常可放")

	# --- 自动装填要认覆盖 ---
	var fit_board := GridInventory.new(Vector2i(5, 5), 4, true)
	t.check(not fit_board.find_first_fit(dot)["found"], "空棋盘上找不到落点")
	var fb := ItemInstance.create(tiny_bag)
	fit_board.place(fb, Vector2i(2, 2), 0)
	var fit := fit_board.find_first_fit(dot)
	t.check(fit["found"], "放了 1x1 的包后能找到落点")
	t.eq(fit["origin"], Vector2i(2, 2), "落点就是那个包所在的格子")
	t.check(not fit_board.find_first_fit(bar)["found"], "1 格的包装不下 1x3")

	# --- 包不参与邻接 ---
	var adj := GridInventory.new(Vector2i(5, 5), 5, true)
	var ab := ItemInstance.create(big_bag)
	adj.place(ab, Vector2i(0, 0), 0)
	var n1 := ItemInstance.create(dot)
	var n2 := ItemInstance.create(dot)
	adj.place(n1, Vector2i(0, 0), 0)
	adj.place(n2, Vector2i(1, 0), 0)
	t.eq(adj.cell_uid(Vector2i(0, 0)), n1.uid, "包上放的东西占的是物品层，包在包层（容纳关系与邻接关系是两回事）")


static func run_bag_move(t: TestCase) -> void:
	t.begin("包的跨容器搬运")

	ItemInstance.reset_uid_counter()
	var big_bag := _bag("bag6", ["11", "11", "11"])
	var dot := _def("dot", ["1"])

	var src := GridInventory.new(Vector2i(6, 6), 1, true)
	var dst := GridInventory.new(Vector2i(6, 6), 2, true)
	var bag := ItemInstance.create(big_bag)
	src.place(bag, Vector2i(0, 0), 0)
	var a := ItemInstance.create(dot)
	var b := ItemInstance.create(dot)
	src.place(a, Vector2i(0, 0), 0)
	src.place(b, Vector2i(1, 2), 0)

	# --- 跨棋盘搬运，内容物跟着走并保持相对位置 ---
	t.check(InventoryService.move(src, bag.uid, dst, Vector2i(2, 1), 0), "带内容物的包可跨棋盘搬运")
	t.eq(src.item_count(), 0, "源棋盘清空")
	t.eq(dst.item_count(), 3, "目标棋盘收到包与两件内容物")
	t.eq(bag.origin, Vector2i(2, 1), "包落到新位置")
	t.eq(a.origin, Vector2i(2, 1), "内容物保持相对偏移 (0,0)")
	t.eq(b.origin, Vector2i(3, 3), "内容物保持相对偏移 (1,2)")
	t.eq(dst.bag_of(a.uid), bag.uid, "容纳关系保持")

	# --- 目标放不下时整体退回 ---
	var blocker := ItemInstance.create(big_bag)
	var src2 := GridInventory.new(Vector2i(6, 6), 3, true)
	src2.place(blocker, Vector2i(0, 0), 0)
	t.check(
		not InventoryService.move(dst, bag.uid, src2, Vector2i(0, 0), 0),
		"目标位置已被别的包占据，搬运应失败"
	)
	t.eq(dst.item_count(), 3, "失败后包与内容物全部留在原处")
	t.eq(bag.origin, Vector2i(2, 1), "失败后位置不变")
	t.eq(a.origin, Vector2i(2, 1), "失败后内容物位置不变")
	t.eq(dst.bag_of(b.uid), bag.uid, "失败后容纳关系不变")

	# --- 自由容器收不下带内容物的包 ---
	var storage := GridInventory.new(Vector2i(6, 6), 4)
	t.check(
		not InventoryService.move(dst, bag.uid, storage, Vector2i(0, 0), 0),
		"自由容器没有覆盖概念，收不下带内容物的包"
	)
	t.eq(dst.item_count(), 3, "被拒后仍全部留在棋盘上")
	t.eq(storage.item_count(), 0, "自由容器没有残留")

	# --- 掏空后就能搬进自由容器 ---
	InventoryService.move(dst, a.uid, storage, Vector2i(0, 0), 0)
	InventoryService.move(dst, b.uid, storage, Vector2i(1, 0), 0)
	t.check(not dst.is_bag_with_contents(bag.uid), "包已掏空")
	t.check(
		InventoryService.move(dst, bag.uid, storage, Vector2i(0, 1), 0),
		"空包可以作为普通物品搬进自由容器"
	)
	t.eq(storage.item_count(), 3, "自由容器收下三件")
	t.check(not storage.acts_as_bag(big_bag), "它在这里不提供覆盖")


static func run_board_serialization(t: TestCase) -> void:
	t.begin("棋盘序列化")

	ItemInstance.reset_uid_counter()
	var big_bag := _bag("bag6", ["11", "11", "11"])
	var dot := _def("dot", ["1"])
	var db := ItemDatabase.new()
	db.register(big_bag)
	db.register(dot)

	var board := GridInventory.new(Vector2i(7, 9), 42, true)
	var bag := ItemInstance.create(big_bag)
	board.place(bag, Vector2i(1, 1), 0)
	var a := ItemInstance.create(dot)
	board.place(a, Vector2i(2, 3), 0)

	var dict := board.to_dict()
	t.check(dict["requires_bag"], "棋盘模式应写进存档")

	var back := GridInventory.from_dict(dict, db)
	t.check(back.requires_bag, "读档后仍是棋盘模式")
	t.eq(back.item_count(), 2, "包与物品都还原了")
	t.eq(back.usable_cell_count(), 6, "包的覆盖由放置推导，不需单独存")
	t.eq(back.bag_of(a.uid), bag.uid, "容纳关系还原")
	t.eq(back.get_item(a.uid).origin, Vector2i(2, 3), "物品位置还原")
	t.eq(back.to_dict(), dict, "二次序列化与首次一致")

	# 内容物在存档里排在包前面时也必须能还原（from_dict 要先放包）
	var shuffled := dict.duplicate(true)
	(shuffled["items"] as Array).reverse()
	var back2 := GridInventory.from_dict(shuffled, db)
	t.eq(back2.item_count(), 2, "存档条目顺序颠倒时仍应完整还原")
	t.eq(back2.bag_of(a.uid), bag.uid, "顺序颠倒后容纳关系仍正确")


## 包也能转。转过之后内容物不跟着转，依附不上的脱落并交还给调用方。
##
## 「内容物跟着包一起转」是另一条路，但那样转一下包会同时改掉包里每一件东西的朝向，
## 玩家摆好的布局被整个搅乱；脱落是局部的、看得见的、放手前可以撤回的。
static func run_rotate_shedding(t: TestCase) -> void:
	t.begin("棋盘与包 · 包旋转：内容物按本地坐标跟着转，跨包的脱落")

	ItemInstance.reset_uid_counter()
	var big_bag := _bag("bag6", ["11", "11", "11"])   # 2 宽 3 高
	var dot := _def("dot", ["1"])
	var bar := _def("bar", ["1", "1", "1"])            # 竖 1x3
	var board := GridInventory.new(Vector2i(8, 8), 1, true)

	var bag := ItemInstance.create(big_bag)
	board.place(bag, Vector2i(1, 1), 0)              # 占 (1..2, 1..3)
	var corner := ItemInstance.create(dot)
	var column := ItemInstance.create(bar)
	board.place(corner, Vector2i(1, 1), 0)           # 包的左上角
	board.place(column, Vector2i(2, 1), 0)           # 包的右列，竖着占满

	# --- 本地坐标往返 ---
	var local := GridInventory.to_local(bag, column)
	t.eq(local["origin"], Vector2i(1, 0), "右列在本地坐标里是 (1,0)")
	t.eq(int(local["rot"]), 0, "本地朝向 0")
	var back := GridInventory.to_global(bag, local, column, bag.origin, bag.rotation)
	t.eq(back["origin"], Vector2i(2, 1), "本地 → 全局回到原处")
	t.eq(int(back["rot"]), 0, "朝向也回来")

	# --- 原地转：内容物跟着转，一件不掉 ---
	var fallen = _turn_bag(board, bag.uid, 1)
	t.not_null(fallen, "非空的包能转")
	t.eq(bag.rotation, 1, "包转了一步（2x3 → 3x2，占 (1..3, 1..2)）")
	t.eq((fallen as Array).size(), 0, "**整件在包里的东西不脱落**")
	t.check(board.has_item(corner.uid) and board.has_item(column.uid), "两件都还在棋盘上")
	t.eq(board.bag_of(corner.uid), bag.uid, "小方块仍归这个包")
	t.eq(board.bag_of(column.uid), bag.uid, "长条仍归这个包")
	t.eq(column.rotation, 1, "**长条跟着包转了 90°**，竖的变横的")
	t.eq(column.origin, Vector2i(1, 2), "横着躺在包转过之后的底行")
	t.eq(corner.origin, Vector2i(3, 1), "左上角的方块转到了右上角")
	for c in column.cells():
		t.eq(board.bag_at(column.origin + c), bag.uid, "长条的每一格都仍被这个包覆盖")

	# --- 转回去：完全复原 ---
	_turn_bag(board, bag.uid, -1)
	t.eq(column.origin, Vector2i(2, 1), "转回去长条回到右列")
	t.eq(column.rotation, 0, "朝向也回来")
	t.eq(corner.origin, Vector2i(1, 1), "方块回到左上角")

	# --- 跨包的那件才会脱落 ---
	# 邻包放在【下面】：2x3 转成 3x2 会向右长一格，放右边会撞上
	var other := ItemInstance.create(big_bag)
	board.place(other, Vector2i(1, 4), 0)            # 占 (1..2, 4..6)
	board.remove(column.uid)
	var bridge := ItemInstance.create(_def("tall", ["1", "1"]))
	t.check(board.place(bridge, Vector2i(2, 3), 0), "竖 1x2 横跨两个包放得下：(2,3) 在上面的包，(2,4) 在下面的包")
	t.eq(board.bag_of(bridge.uid), GridInventory.EMPTY_UID, "它谁的都不是")

	var payload := board.detach_bag(bag.uid)
	t.eq((payload["contents"] as Array).size(), 1, "内容物只有整件在里面的方块")
	t.eq((payload["straddlers"] as Array).size(), 1, "跨包的另记一笔")
	t.check(not board.has_item(bridge.uid), "跨包的也被摘了下来（少了一半依托）")

	var report := board.bag_fit_report(payload, Vector2i(1, 1), 0)
	t.check(report["ok"] and (report["fallen"] as Array).is_empty(),
		"原样放回：跨包的那件能回到原处，不脱落")
	report = board.bag_fit_report(payload, Vector2i(1, 1), 1)
	t.eq((report["fallen"] as Array).size(), 1, "换个朝向放回：跨包的那件没了依托，脱落")
	t.eq(((report["fallen"] as Array)[0] as ItemInstance).uid, bridge.uid, "脱落的就是它")
	t.check(board.attach_bag(payload, Vector2i(1, 1), 0), "严格版原样放回")
	t.check(board.has_item(bridge.uid), "跨包的那件回来了")
	t.eq(bridge.origin, Vector2i(2, 3), "回到原处")

	var shed = _turn_bag(board, bag.uid, 1)
	t.eq((shed as Array).size(), 1, "原地转：跨包的脱落")
	t.check(not board.has_item(bridge.uid), "离开了棋盘")
	t.check(board.has_item(corner.uid), "整件在里面的跟着转，没掉")

	# --- 转不动时原样不动，一件不掉 ---
	var edge_bag := ItemInstance.create(big_bag)
	var edge_board := GridInventory.new(Vector2i(3, 3), 2, true)
	edge_board.place(edge_bag, Vector2i(1, 0), 0)      # 2x3 占 (1..2, 0..2)
	var inside := ItemInstance.create(dot)
	edge_board.place(inside, Vector2i(1, 0), 0)
	t.is_null(_turn_bag(edge_board, edge_bag.uid, 1), "转成 3x2 会出界，转不动")
	t.eq(edge_bag.rotation, 0, "朝向没变")
	t.check(edge_board.has_item(inside.uid), "**内容物一件不掉**")
	t.eq(inside.origin, Vector2i(1, 0), "位置也没动")


static func run_bag_accept_touching(t: TestCase) -> void:
	t.begin("棋盘与包 · 跨包时每个碰到的包都得接受")

	ItemInstance.reset_uid_counter()
	var big_bag := _bag("bag6", ["11", "11", "11"])
	var belt := _bag("belt", ["11", "11", "11"])
	belt.bag_accept_tags = [&"potion"] as Array[StringName]
	var rifle := _def("rifle", ["11"], ["weapon"])
	var potion := _def("potion", ["11"], ["potion"])
	var board := GridInventory.new(Vector2i(6, 6), 1, true)
	board.place(ItemInstance.create(big_bag), Vector2i(0, 0), 0)
	board.place(ItemInstance.create(belt), Vector2i(2, 0), 0)

	t.check(not board.place(ItemInstance.create(rifle), Vector2i(1, 0), 0),
		"步枪一格压在药水带上，药水带不收 —— 哪怕只压一格")
	t.check(board.place(ItemInstance.create(potion), Vector2i(1, 0), 0),
		"药水横跨普通包与药水带，两边都收")

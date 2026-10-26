## 224 补充二（作者 17:22–17:23）：结算屏第二版 —— 没有标题刻线的板边、第一页 ×1.2（2 倍图缩着画）、
## 撤离时保险箱在账单右边（皮带框）、第二页带回的棋盘格子 72 + 仓库贴右上；战败保险箱直接进仓库、放不下的才进待置入棋盘
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Steps := preload("res://tests/ui/test_result_steps_177.gd")


static func _small(c) -> ItemDef:
	for d: ItemDef in Steps._defs(c):
		if d.shape.size_rotated(0) == Vector2i.ONE and MetaState.keeps(d):
			return d
	return null


static func _defeat(def: ItemDef, n: int) -> RunResult:
	var r := RunResult.new()
	r.outcome = &"defeated"
	r.reason = &"vitality_depleted"
	var items: Array[ItemInstance] = []
	var layout: Array[Dictionary] = []
	for i in n:
		items.append(ItemInstance.create(def))
		layout.append({"def": def, "origin": Vector2i(i, 0), "rotation": 0})
	r.safe_items = items
	r.safe_layout = layout
	return r


static func run_defeat_safe_to_warehouse(t: TestCase) -> void:
	t.begin("224 补充二 · 战败：保险箱带出的直接进仓库；仓库放不下的才进待置入的棋盘")
	var c = NodeScreens._content()
	var small := _small(c)
	if small == null:
		t.check(false, "道具库里找不到 1×1 的")
		return
	var rules := MetaRules.new()
	rules.warehouse_size = Vector2i(4, 4)
	var m := MetaState.new(rules)
	var got := m.absorb(_defeat(small, 2))
	t.eq(m.warehouse.item_count(), 2, "两件进了仓库")
	t.check(m.board == null and not m.has_pending_board(), "没有待置入的棋盘")
	t.eq(int(got["safe"]), 2, "记两件保险箱带出")

	var tight := MetaRules.new()
	tight.warehouse_size = Vector2i(1, 1)
	var m2 := MetaState.new(tight)
	m2.absorb(_defeat(small, 2))
	t.eq(m2.warehouse.item_count(), 1, "仓库只放得下一件")
	t.check(m2.has_pending_board() and m2.board.item_count() == 1, "放不下的那件进了待置入的棋盘（基地「仓库」页清）")


static func frame_result_v2(t: TestCase, root: Window) -> void:
	t.begin("224 补充二 · 结算屏第二版：板边没有刻线、第一页 ×1.2、保险箱在账单右边；第二页棋盘格子 72、仓库靠右上；英文继续小一号")
	var c = NodeScreens._content()
	var f := Support.flow(c, "s224v2", 10000.0)
	var gun: ItemDef = Steps._defs(c)[0]
	var r := Steps._extracted_result(gun)
	r.safe_size = Vector2i(3, 3)
	f.last_absorbed = {"lit": 0}
	f.meta.board = GridInventory.new(Vector2i(4, 3), 0, false)
	f.meta.board.try_add(ItemInstance.create(gun), true)
	var screen = load("res://ui/game/result_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.RESULT
	root.add_child(screen)
	screen.open({"result": r})
	var slab := screen.find_child("ScreenSlab", true, false) as PanelContainer
	var box := slab.get_theme_stylebox("panel") if slab != null else null
	t.check(box is SlabStyle and (box as SlabStyle).edge.texture == UiTheme.art_cached("slab_edge_plain"), "板边换 slab_edge_plain（没有顶上那道刻线）")
	var ledger: LedgerView = screen.ledger()
	t.eq(ledger.size, Vector2(864, 576), "账单 864 × 576")
	t.eq(Vector2(ledger.offset_left, ledger.offset_top), Vector2(368, 210) - Vector2(800, 500), "账单摆在 368, 210")
	t.eq(ledger.rows().size(), 12, "十一行 + 合计")
	var plate := screen.find_child("TitlePlate", true, false) as TextureRect
	t.check(plate != null and plate.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "标题牌按 1x 大小缩着画（图是 2 倍）")
	t.eq(plate.size, Vector2(398, 86), "标题牌图 398 × 86")
	t.check(plate.texture != null and plate.texture.get_width() == 796, "标题牌是 2 倍图")
	var cont: Button = screen.continue_button()
	t.eq(cont.custom_minimum_size, Vector2(252, 77), "继续 252 × 77")
	t.eq(cont.get_theme_font_size("font_size"), 34, "继续字 34")
	var safe := screen.find_child("SafeFrame", true, false) as PanelContainer
	t.check(safe != null and is_equal_approx(safe.offset_left, 1280.0 - 800.0) and is_equal_approx(safe.offset_top, 160.0 - 500.0), "保险箱框摆在账单右边 1280, 160")
	t.check(safe != null and safe.offset_left > ledger.offset_right, "不压账单")
	t.check(safe != null and safe.offset_right <= 1498.0 - 800.0, "不出石板内沿")
	t.check(safe != null and safe.get_theme_stylebox("panel") is StyleBoxTexture, "皮带框（同背包棋盘）")
	t.check(not screen.safe_view().seams.is_empty(), "有格缝")
	ledger.reveal_all()
	screen.to_step(2)
	var wh = screen.get("_wh")
	t.check(wh != null and is_equal_approx(wh.board_view().cell_px, 72.0), "带回来的棋盘格子 72")
	t.check(wh.get_parent().get_child(0) == wh, "仓库面板在最上面（保险箱与分隔线都没了）")
	var shelf: WarehousePages = wh.shelf()
	var row: Node = shelf.get_parent().get_parent()
	var last := row.get_child_count() - 2     # 228 补一：最后一件是离右沿 24 的空位
	t.check(row.get_child(last) == shelf.get_parent() and row.get_child(last - 1).size_flags_horizontal == Control.SIZE_EXPAND_FILL and (row.get_child(last + 1) as Control).custom_minimum_size.x == preload("res://ui/game/warehouse_panel.gd").RESULT_SHELF_RIGHT, "仓库在那一行最右（前面一块撑开的空，后面空 24）")
	var wide := Control.new()
	wide.size = Vector2(1500, 700)     # 255 补充一：带回来的棋盘占九格宽的位子，宽的那档给到石板内容区实际那么宽
	screen._fit_shelf(wide)
	var big: float = shelf.view.cell_px
	wide.size = Vector2(700, 300)
	screen._fit_shelf(wide)
	t.check(big > shelf.view.cell_px and big <= WarehousePages.CELL_MAX, "仓库格子按剩下的宽高放大（宽 %.0f > 窄 %.0f）" % [big, shelf.view.cell_px])
	wide.free()
	for b: Button in Steps._buttons(screen, "一键置入"):
		t.eq(b.custom_minimum_size, Vector2(180, 67), "第二页小钮 180 × 67")
	screen.queue_free()

	UiText.lang = "en"
	var en = load("res://ui/game/result_screen.gd").new()
	en.flow = f
	en.font = UiPalette.cjk_font()
	root.add_child(en)
	UiText.lang = "en"
	en.open({"result": r})
	t.eq(en.continue_button().get_theme_font_size("font_size"), 28, "英文「Continue」小一号")
	t.check(en.ledger().rows()[3]["label"] == "Elites defeated" and en.ledger().rows()[4]["label"] == "Bosses defeated", "英文精英 / 首领两行")
	en.queue_free()
	UiText.lang = "zh"
	f.meta.board = null
	Support.cleanup("s224v2")

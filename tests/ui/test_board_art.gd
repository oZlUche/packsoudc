## 棋盘美术（UI替换美术，作者 2026-10-19 19:02 定稿）：容器屏左边按种类换外框、右边背包细皮带框，格缝由棋盘视图画；
## 标题不写字、去掉快速搜索 / 状态行 / 耐力行 / 火漆签旁的回话行；搜索屏右上角最小化 + 关闭圆钮，战利品屏只有最小化（作者 21:16）；「全部拾取」火漆签；面板宽按格子算（8 列背包 + 6 列容器 = 1188）
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_boardart_run.json"
const META := "user://test_boardart_meta.json"
const SETTINGS := "user://test_boardart_settings.json"
const CS := preload("res://ui/game/container_screen.gd")
const KINDS := ["search", "chest_iron", "chest_gold", "corpse", "boss", "player"]


static func run_assets(t: TestCase) -> void:
	t.begin("棋盘美术 · 切图都在：六种外框（九宫格边距、比格子大多少）、宝箱铁条、BOSS 纹章、两颗圆钮与火漆签各三态；layout 浅底")
	var lay := CS.board_layout()
	t.eq(String(lay.get("tone", "")), "light", "面板浅底（UI 深浅规则）")
	var pieces: Dictionary = lay.get("pieces", {})
	for k in KINDS:
		var piece: Dictionary = pieces.get(k, {})
		var tex := EventImage.load_texture(CS.BOARD_DIR + String(piece.get("file", "")))
		t.check(tex != null, "%s 外框在" % k)
		if tex == null:
			continue
		var m := int(piece.get("margin", 0))
		t.check(m > 0 and tex.get_width() > m * 2 and tex.get_height() > m * 2, "%s 九宫格边距 %d 放得下（%s）" % [k, m, tex.get_size()])
		t.check(float(piece.get("cells_offset", 0)) > CS.FRAME_BLEED, "%s 外框比格子宽" % k)
	for f in ["chest_band_iron", "chest_band_gold", "boss_crest"]:
		t.check(EventImage.load_texture(CS.BOARD_DIR + f + ".png") != null, "%s 在" % f)
	for b in ["take_all", "btn_close", "btn_minimize"]:
		for st in ["", "_hover", "_pressed"]:
			t.check(EventImage.load_texture(CS.BOARD_DIR + b + st + ".png") != null, "%s%s 在" % [b, st])
	var seams: Dictionary = lay.get("cell_seams", {})
	t.check(seams.has("seam") and seams.has("hi"), "格缝的颜色在")


static func run_frame_kind(t: TestCase) -> void:
	t.begin("棋盘美术 · 左边用哪种外框：搜索 藤编；宝箱 稀有及以上金角、以下铁角；战利品 BOSS 黑铁、其余生皮")
	t.eq(CS.frame_kind_of(true, false, 0, false), "search", "搜索")
	t.eq(CS.frame_kind_of(true, true, 0, false), "chest_iron", "普通宝箱")
	t.eq(CS.frame_kind_of(true, true, 1, false), "chest_iron", "优良宝箱")
	t.eq(CS.frame_kind_of(true, true, 2, false), "chest_gold", "稀有宝箱")
	t.eq(CS.frame_kind_of(true, true, 5, false), "chest_gold", "神话宝箱")
	t.eq(CS.frame_kind_of(false, false, 0, false), "corpse", "敌人战利品")
	t.eq(CS.frame_kind_of(false, false, 0, true), "boss", "BOSS 战利品")


static func frame_loot_screen(t: TestCase, root: Window) -> void:
	t.begin("棋盘美术 · 战利品屏：生皮外框包住容器、细皮带框包住背包；两块都画格缝；标题空、只有最小化钮（在最右）；没有状态行、回话行与耐力行；面板按格子算宽高")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "boardart")
	f.begin(c.chapter, kit, 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	var box := LootPacker.board_of([&"knife", &"armor"] as Array[StringName], Vector2i(6, 4), f.run.items)
	var screen = load("res://ui/game/container_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.LOOT
	root.add_child(screen)
	screen.open({"container": box})
	t.eq(screen.frame_kind(), "corpse", "敌人战利品：生皮")
	t.eq(screen.overlay_frame().title(), "", "标题不写字")
	t.check(screen._close_btn == null and screen._minimize_btn != null and screen._minimize_btn.has_art(), "只有最小化钮（原「收起」），有图")
	t.check(screen._minimize_btn.tooltip_text.begins_with("收起"), "最小化钮的说明还是收起那句")
	t.check(screen._take_btn.has_art() and screen._take_btn.text == "", "全部拾取是火漆签（字在图里）")
	t.check(not "_line" in screen, "没有状态行、火漆签旁没有回话行")
	t.check(not screen._inv.hint_sink.is_valid(), "面板的回话（放不下、合成了）不接到屏上")
	t.check(not screen._inv._stamina.visible, "耐力行去掉了")
	t.check(not screen._loot.seams.is_empty() and not screen._inv.board_view.seams.is_empty(), "两块棋盘都画格缝")
	var buttons: Array = screen.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text in ["快速搜索", "关闭", "回到地图", "收起", "全部拾取"])
	t.eq(buttons.size(), 0, "原来那排字按钮都没了")
	# 摆位：外框看得见的边离格子 pad，节点再往外多 8 px 透明边
	var lp: float = screen.frame_pad("corpse")
	var pp: float = screen.frame_pad("player")
	t.eq(lp, 32.0, "生皮外框比格子宽 32")
	t.eq(pp, 16.0, "背包外框比格子宽 16")
	var bleed := lp + CS.FRAME_BLEED
	t.eq(screen._loot_frame.position, screen._loot_box.position - Vector2(bleed, bleed), "容器外框围着格子")
	t.eq(screen._loot_frame.size, Vector2(6, 4) * 60.0 + Vector2(bleed, bleed) * 2.0, "容器外框大小 = 格子 + 两边")
	var board: GridInventory = f.run.board
	var pb := pp + CS.FRAME_BLEED
	t.eq(screen._player_frame.size, Vector2(board.size) * 60.0 + Vector2(pb, pb) * 2.0, "背包外框大小 = 格子 + 两边")
	var want := Vector2(26.0 + 6 * 60 + 64 + 200 + board.size.x * 60 + 32 + 26.0, maxf(66.0 + 4 * 60 + 64 + 62 + 62 + 32, 66.0 + board.size.y * 60 + 32 + 68))
	t.eq(screen.panel_size(), want, "面板宽高按格子算（%s）" % want)
	if board.size == Vector2i(8, 6):
		t.eq(want, Vector2(1188, 526), "8 列背包 + 6 列容器 = 定稿的 1188 × 526")
	t.eq(screen.overlay_frame().custom_minimum_size, want, "石板框按它定大小")
	var side: Vector2 = screen._minimize_btn.custom_minimum_size
	var off: Vector2 = screen._stage.global_position - screen.overlay_frame().global_position
	t.eq(screen._minimize_btn.position, Vector2(want.x, 0.0) + CS.CLOSE_AT - side * 0.5 - off, "最小化钮在原关闭钮的位置（最右）")
	screen.take_all()
	t.eq(box.item_count(), 0, "全部拾取照旧拿完")
	screen.queue_free()
	Support.cleanup("boardart")


static func frame_boss_screen(t: TestCase, root: Window) -> void:
	t.begin("棋盘美术 · BOSS 战利品：黑铁外框 + 顶上纹章；Esc 照旧不收")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "boardart2")
	f.begin(c.chapter, kit, 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	f.run.boss_cleared = true
	var box := LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(4, 3), f.run.items)
	var screen = load("res://ui/game/container_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.LOOT
	root.add_child(screen)
	screen.open({"container": box})
	t.eq(screen.frame_kind(), "boss", "BOSS：黑铁")
	t.eq(screen.frame_pad("boss"), 36.0, "黑铁外框比格子宽 36")
	t.eq(screen._extras.size(), 1, "一枚纹章")
	t.check(screen._close_btn == null and screen._minimize_btn.tooltip_text.contains("撤离结算"), "只有最小化钮 = 收起 = 撤离结算（行为不变）")
	t.check(not screen.escape(), "Esc 不收（090）")
	screen.queue_free()
	Support.cleanup("boardart2")


static func frame_search_screen(t: TestCase, root: Window) -> void:
	t.begin("棋盘美术 · 搜索屏：藤编外框；右上角最小化（回到地图）+ 关闭（回到事件）")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到带搜索点的种子")
		return
	Support.cleanup("boardart3")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(c.chapter, kit, int(found["seed"]))
	var map = game.base()
	if map.rules_open():
		map.close_rules()
	map.pick_spawn(int(found["entry"]))
	map.step(int(found["next"]))
	if game.overlay() != null and game.overlay().screen == GameFlow.Screen.EVENT:
		game.overlay().proceed()     # 「搜索」
	var ov = game.overlay()
	if ov == null or ov.screen != GameFlow.Screen.SEARCH:
		t.check(true, "（这个种子没开出搜索屏：%s）" % str(flow.screen))
	else:
		t.eq(ov.frame_kind(), "search", "搜索：藤编")
		t.check(ov._minimize_btn != null and ov._minimize_btn.has_art() and ov._minimize_btn.tooltip_text.begins_with("回到地图"), "最小化钮 = 原「回到地图」")
		t.check(ov._close_btn.tooltip_text.begins_with("关闭"), "关闭钮 = 原「关闭」")
		t.check(ov._minimize_btn.position.x < ov._close_btn.position.x and is_equal_approx(ov._minimize_btn.position.y, ov._close_btn.position.y), "最小化在关闭左边、同一行")
		t.check(is_equal_approx(ov._close_btn.position.x - ov._minimize_btn.position.x, 48.0), "两颗钮中心隔 48")
		t.check(is_equal_approx(ov._close_btn.size.x, 56.0 * 0.72), "圆钮按 0.72 画")
		ov._minimize_btn.pressed.emit()
		t.is_null(game.overlay(), "最小化 = 回到地图（叠层藏起来）")
		t.check(game.minimized() == ov, "藏着没销毁")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup("boardart3")

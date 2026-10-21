## 178（作者 2026-10-16）：基地左列加「仓库」页签 —— 带回来的背包（一键置入 / 整理）从家页搬到这页；
## 图鉴 / 成就页收起右半边的仓库、中列吃满；从结算屏回来、带回来的还没清空就落在「仓库」页
extends RefCounted

const META := "user://test_178_meta.json"
const SETTINGS := "user://test_178_settings.json"


static func _flow() -> GameFlow:
	var db := ItemDatabase.new()
	db.load_dir()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	return f


static func _screen(f: GameFlow, root: Window, payload: Dictionary = {}) -> Control:
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open(payload)
	return screen


static func _cleanup() -> void:
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _with_board(f: GameFlow) -> ItemInstance:
	f.meta.board = GridInventory.new(Vector2i(6, 4), MetaState.BOARD_ID, false)
	var inst := ItemInstance.create(f.items.get_def(&"knife"))
	f.meta.board.try_add(inst)
	return inst


static func frame_warehouse_page(t: TestCase, root: Window) -> void:
	t.begin("178 · 「仓库」页：有带回来的背包时它在这页、家页没有；没有就一行字；show_tab(\"warehouse\") 不再算家；Esc 回家")
	ItemInstance.reset_uid_counter()
	var f := _flow()
	_with_board(f)
	var screen = _screen(f, root)
	t.eq(screen._tab_btns.keys(), ["warehouse", "sell", "tech", "codex", "achievements"], "五个页签：仓库 / 出售 / 科技 / 图鉴 / 成就")
	t.eq((screen._tab_btns["warehouse"] as Button).text, "仓库", "页签字")
	var page: Control = screen._pages["warehouse"]
	t.check(page.is_ancestor_of(screen._wh), "带回来的背包在「仓库」页")
	t.check(not (screen._pages["home"] as Control).is_ancestor_of(screen._wh), "家页没有")
	t.check(screen._wh._store_btn.visible, "有棋盘：一键置入在")
	t.check(screen.pending_text().contains("「仓库」页"), "提示指向「仓库」页（%s）" % screen.pending_text())
	t.eq((screen._tab_btns["warehouse"] as Button).tooltip_text, screen.pending_text(), "226 批二：那句提示在「仓库」页签的悬浮窗里，左列不再写字")
	screen.show_tab("warehouse")
	t.eq(screen.tab(), "warehouse", "不再被改成家")
	t.check(page.is_visible_in_tree() and screen.shelf().is_visible_in_tree(), "仓库页与右半边都在")
	t.check(screen.escape(), "Esc 接住")
	t.eq(screen.tab(), "home", "Esc：仓库页回家")
	screen.queue_free()

	var g := _flow()
	var bare = _screen(g, root)
	t.check(bare.get("_no_board") == null, "226 批二：空态那一行删了")
	t.eq(bare.pending_text(), "", "没棋盘：不提示")
	t.check(not bare._wh._store_btn.visible and bare._wh._tidy_btn.visible, "没棋盘：不摆一键置入，整理还在")
	bare.queue_free()
	_cleanup()


static func frame_shelf_hidden(t: TestCase, root: Window) -> void:
	t.begin("178 · 图鉴 / 成就页收起右半边，中列宽 = 全宽减左列；切回出售页右半边回来、翻到的那页不变；调试台箭头还在")
	var f := _flow()
	f.meta.tech_levels["warehouse"] = 3
	f.derive_techs()
	var screen = _screen(f, root)
	var full: Vector2 = root.get_visible_rect().size
	var shelf: WarehousePages = screen.shelf()
	screen.show_tab("sell")
	screen.layout()
	t.check(screen._sell_pick.get_parent().get_combined_minimum_size().x <= screen.middle_width(full), "出售那一行不撑宽中列（%.0f ≤ %.0f；游戏测试 v3.84：右边仓库被挤出屏）" % [screen._sell_pick.get_parent().get_combined_minimum_size().x, screen.middle_width(full)])
	t.check(shelf.tab_count() > 1, "有好几页（%d）" % shelf.tab_count())
	shelf.show_page(1)
	var shown_w: float = screen.middle_width(full)
	for k in ["codex", "achievements"]:
		screen.show_tab(k)
		screen.layout()
		t.check(not screen._right.visible, "%s：右半边收起" % k)
		t.eq(screen.middle_width(full), full.x - 2.0 * screen.MARGIN - screen.LEFT_W - screen.COL_GAP - screen.right_gutter(), "%s：中列 = 全宽减左列（右边只留箭头一条）" % k)
		t.check(screen.right_gutter() > 0.0 and screen.right_gutter() < 80.0, "%s：箭头那条窄（%.0f）" % [k, screen.right_gutter()])
		t.check(screen.middle_width(full) > shown_w, "%s：比有右半边时宽" % k)
		t.check(screen.dev_drawer().arrow.is_visible_in_tree(), "%s：调试台箭头还在" % k)
	screen.fit_codex_to_width(screen.middle_width(full))
	var wide: int = screen.codex_columns()
	screen.fit_codex_to_width(shown_w)
	t.check(wide > screen.codex_columns(), "图鉴吃满宽多排几列（%d > %d）" % [wide, screen.codex_columns()])
	screen.show_tab("sell")
	screen.layout()
	t.check(screen._right.visible and shelf.is_visible_in_tree(), "切回出售：右半边回来")
	t.eq(shelf.current(), 1, "翻到的那页不变")
	t.eq(screen.middle_width(full), shown_w, "中列宽回原样")
	screen.queue_free()
	_cleanup()


static func frame_initial_tab(t: TestCase, root: Window) -> void:
	t.begin("178 · 进基地落哪页：从结算屏回来、带回来的还没清空 → 「仓库」页；清空了、或不是从结算屏来 → 家")
	var f := _flow()
	_with_board(f)
	var result := RunResult.new()
	var s1 = _screen(f, root, {"result": result})
	t.eq(s1.tab(), "warehouse", "结算后带着棋盘回来：仓库页")
	s1.queue_free()
	var s2 = _screen(f, root)
	t.eq(s2.tab(), "home", "不是从结算屏来：家")
	s2.queue_free()
	f.meta.store_all()
	t.check(not f.meta.has_pending_board(), "一键置入清空了")
	var s3 = _screen(f, root, {"result": result})
	t.eq(s3.tab(), "home", "清空了再进：家")
	s3.queue_free()
	var s4 = _screen(f, root, {"result": result, "tab": "tech"})
	t.eq(s4.tab(), "tech", "指定页签照旧优先")
	s4.queue_free()
	_cleanup()

## 164（作者定）：基地三列 —— 左列页签竖排（178 起五个）（再点一次回「家」）、左下角「再来一局」「回主菜单」；中列当前页（默认家）；
## 右半边分页仓库（178：图鉴 / 成就页收起），双击按当前页分派（178：仓库 → 置入带回来的背包、出售 → 卖、科技 → 上交、家 / 图鉴 / 成就 → 不做事）；
## 出售 / 科技页不再自己画仓库；「家」套件（背景、木牌按钮、粗布框、木架）接进主题，每张图标了深浅
extends RefCounted

const META := "user://test_164_meta.json"
const SETTINGS := "user://test_164_settings.json"


static func _flow() -> GameFlow:
	var db := ItemDatabase.new()
	db.load_dir()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	return f


static func _screen(f: GameFlow, root: Window) -> Control:
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	return screen


static func _cleanup() -> void:
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _put(f: GameFlow, id: StringName) -> ItemInstance:
	var inst := ItemInstance.create(f.items.get_def(id))
	return inst if f.meta.warehouse.try_add(inst) else null


static func frame_layout(t: TestCase, root: Window) -> void:
	t.begin("164 · 三列：左列页签竖排（木牌按钮）、底下再来一局 / 回主菜单；默认在家；再点一次选中的页签回家；右半边是分页仓库")
	var f := _flow()
	var screen = _screen(f, root)
	t.eq(screen.tab(), "home", "默认在家页")
	var keys: Array = screen._tab_btns.keys()
	t.eq(keys, ["warehouse", "sell", "tech", "codex", "achievements"], "178：五个页签：仓库、出售、科技、图鉴、成就")
	var first: Button = screen._tab_btns["codex"]
	var col: Node = first.get_parent()
	t.check(col is VBoxContainer, "页签竖排")
	for k in keys:
		t.eq((screen._tab_btns[k] as Button).get_parent(), col, "%s 在左列" % k)
		t.eq((screen._tab_btns[k] as Button).theme_type_variation, UiTheme.BUTTON_HOME, "%s 是木牌按钮" % k)
	t.eq(screen._new_run_btn.theme_type_variation, UiTheme.BUTTON_HOME_PRIMARY, "再来一局是主档木牌")
	t.eq(screen._new_run_btn.get_parent(), col, "再来一局在左列")
	t.check(screen._new_run_btn.get_index() > first.get_index(), "在页签下面（左下角）")
	screen.toggle_tab("codex")
	t.eq(screen.tab(), "codex", "点图鉴：切过去")
	t.check(first.button_pressed, "图鉴页签按下")
	screen.toggle_tab("codex")
	t.eq(screen.tab(), "home", "再点一次：回家")
	t.check(not first.button_pressed, "页签抬起")
	screen.show_tab("warehouse")
	t.eq(screen.tab(), "warehouse", "178：「仓库」是自己的一页，不再算家")
	var shelf: WarehousePages = screen.shelf()
	t.not_null(shelf, "右半边有分页仓库")
	t.check(screen._right.is_ancestor_of(shelf), "仓库在右列")
	for k in ["home", "warehouse", "sell", "tech"]:
		screen.show_tab(k)
		t.check(shelf.is_visible_in_tree(), "%s 页时仓库照常显示" % k)
	for k in ["codex", "achievements"]:
		screen.show_tab(k)
		t.check(not shelf.is_visible_in_tree(), "178：%s 页收起仓库" % k)
	screen.show_tab("sell")
	screen.layout()
	t.check(screen._right.custom_minimum_size.x >= root.get_visible_rect().size.x * 0.5 - screen.MARGIN - 1.0, "右列占半个屏宽")
	t.eq(screen._shelf_frame.theme_type_variation, UiTheme.PANEL_SHELF, "仓库套木架框")
	screen.queue_free()
	_cleanup()


static func frame_double_click(t: TestCase, root: Window) -> void:
	t.begin("164 · 双击右边仓库一件按当前页：仓库（178，原来是家）→ 置入带回来的背包；出售 → 卖；科技 → 上交；家 / 图鉴 → 不做事；出售 / 科技页没有自己的仓库")
	ItemInstance.reset_uid_counter()
	var f := _flow()
	f.meta.tech_levels["warehouse"] = 3
	f.derive_techs()
	f.meta.board = GridInventory.new(Vector2i(6, 4), MetaState.BOARD_ID, false)
	var keep := ItemInstance.create(f.items.get_def(&"knife"))
	f.meta.board.try_add(keep)
	var screen = _screen(f, root)
	var view: InventoryView = screen.shelf().view
	var a := _put(f, &"knife")
	screen.show_tab("codex")
	screen._on_shelf_double_clicked(view, a.uid)
	t.check(f.meta.warehouse.has_item(a.uid), "图鉴页：不做事")
	screen.show_tab("home")
	screen._on_shelf_double_clicked(view, a.uid)
	t.check(f.meta.warehouse.has_item(a.uid), "178：家页不做事")
	screen.show_tab("warehouse")
	screen._on_shelf_double_clicked(view, a.uid)
	t.check(f.meta.board.has_item(a.uid), "178：仓库页：进了带回来的背包")
	var b := _put(f, &"knife")
	screen.show_tab("sell")
	var funds := f.meta.funds
	screen._on_shelf_double_clicked(view, b.uid)
	t.check(not f.meta.warehouse.has_item(b.uid) and f.meta.funds > funds, "出售页：卖了（钱 %d → %d）" % [funds, f.meta.funds])
	t.check(not ("_sell_view" in screen), "出售页不再自己画仓库")
	var ingot := _put(f, &"steel_ingot")
	screen.show_tab("tech")
	var tech = screen.tech_panel()
	tech.select(&"warehouse")
	screen._on_shelf_double_clicked(view, ingot.uid)
	t.eq(TechService.deposited(f.meta, &"warehouse", &"steel_ingot"), 1, "科技页：上交了一块钢锭")
	t.check(not ("_warehouse_view" in tech), "科技页没有收起式仓库")
	t.eq(tech.drag_layer(), screen.drag_layer(), "上交区登记在整屏那一层拖拽上（从右边拖得进）")
	screen.queue_free()
	_cleanup()


static func run_home_art(t: TestCase) -> void:
	t.begin("164 · 家的套件：每张图的 json 写了深浅；粗布框浅、木架深；木牌按钮是九宫格、墨色字；背景铺满")
	var dir := DirAccess.open("res://assets/ui/home/")
	t.not_null(dir, "assets/ui/home 在")
	if dir == null:
		return
	var n := 0
	for f in dir.get_files():
		if f.ends_with(".png"):
			n += 1
			var tone := String(UiTheme.art_meta("home/" + f.get_basename()).get("tone", ""))
			t.check(tone == "dark" or tone == "light", "%s 的 json 写了 tone（%s）" % [f, tone])
	t.eq(n, 9, "九张图")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_HOME_BOX), UiTheme.TONE_LIGHT, "粗布框：浅（墨字）")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_SHELF), UiTheme.TONE_DARK, "木架：深")
	var th := UiTheme.current()
	t.check(th.get_stylebox("normal", UiTheme.BUTTON_HOME) is StyleBoxTexture, "木牌按钮是九宫格")
	t.check(th.get_stylebox("disabled", UiTheme.BUTTON_HOME) is StyleBoxTexture, "禁用态也有图")
	t.eq(th.get_color("font_color", UiTheme.BUTTON_HOME), UiTheme.INK, "浅木墨字")
	t.eq(th.get_font_size("font_size", UiTheme.BUTTON_HOME_PRIMARY), UiTheme.HOME_PRIMARY_SIZE, "再来一局字号大一档")
	var rect := ColorRect.new()
	t.not_null(UiTheme.dress_home_backdrop(rect), "背景铺上了")
	t.eq((rect.get_node(^"HomeBackdrop") as TextureRect).stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "按比例铺满、多的裁掉")
	rect.free()
	var saved := UiTheme.asset_root
	UiTheme.asset_root = "res://tests/fixtures/no_such_ui/"
	var bare := UiTheme.build()
	t.check(bare.get_stylebox("normal", UiTheme.BUTTON_HOME) is StyleBoxFlat, "没图：木牌按钮回落成平面按钮")
	var rect2 := ColorRect.new()
	t.is_null(UiTheme.dress_home_backdrop(rect2), "没图：不铺背景")
	rect2.free()
	UiTheme.asset_root = saved

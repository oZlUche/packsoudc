## 264（作者 2026-10-29 16:43「按推荐来」）：基地 —— 出征页（军功碑 + 上回出征 + 军需 + 【开始探索】，页签第一、默认选中、单选，Esc 两段）、
## 书架次级菜单（五颗小键 = 开那扇窗，窗开着按下）、仓库页左边工具列（筛选牌压灰不匹配的格、页签写匹配数；账牌三数；没棋盘时窄布）
extends RefCounted

const Records := preload("res://tests/ui/test_records_board_260.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")


static func _flow() -> GameFlow:
	var f := Records._flow()
	f.difficulties = GameFlow.load_difficulties()
	return f


static func frame_expedition_page(t: TestCase, root: Window) -> void:
	t.begin("264 §二 · 出征页：第一个页签、默认选中；碑在左、上回出征 / 军需两块木牌与【开始探索】在右；左下只剩回主菜单；单选；Esc 别页回出征、出征回主菜单")
	var f := _flow()
	var screen = Records._screen(f, root)
	t.eq(screen._tab_btns.keys()[0], "expedition", "出征是第一个页签")
	t.eq((screen._tab_btns["expedition"] as Button).text, "出征", "页签写「出征」")
	t.eq(screen.tab(), "expedition", "默认选中")
	var page: Control = screen._pages["expedition"]
	var board: ExpeditionBoard = screen.expedition_board()
	t.check(page.is_ancestor_of(screen._stele) and page.is_ancestor_of(board), "碑与木牌都在出征页")
	t.check(page is HBoxContainer and screen._stele.get_parent().get_index() < board.get_parent().get_index(), "碑在左、木牌在右（一行）")
	t.eq(board.start_btn.text, "开始探索", "【开始探索】")
	t.eq(board.start_btn.theme_type_variation, UiTheme.BUTTON_HOME_PRIMARY, "主档木牌")
	t.check(board.start_btn.custom_minimum_size == ExpeditionBoard.START, "360 × 96")
	t.check(board.last_plate.custom_minimum_size == Vector2(560, 200) and board.supply_plate.custom_minimum_size == Vector2(560, 260), "两块木牌 560 × 200、560 × 260")
	var left: Control = (screen._tab_btns["expedition"] as Button).get_parent()
	var keys: Array = left.find_children("*", "Button", true, false).filter(func(b): return (b as Button).is_visible_in_tree()).map(func(b): return (b as Button).text)
	t.check(not keys.has("再来一局") and not keys.has("开始探索") and keys.has("回主菜单"), "左列：页签 + 回主菜单（%s）" % [keys])
	t.check(not screen._right.visible, "出征页收起右半边（碑 + 木牌要整个中列）")
	var full: Vector2 = root.get_visible_rect().size
	t.check(page.get_combined_minimum_size().x <= screen.middle_width(full), "碑 + 木牌放得进中列（%.0f ≤ %.0f）" % [page.get_combined_minimum_size().x, screen.middle_width(full)])
	t.eq(board.last_lines(), [] as Array[String], "没出征过：上回出征写「尚无」")
	t.eq(Bare.audit(page, "expedition"), [] as Array[String], "出征页没有裸字")
	screen.toggle_tab("expedition")
	t.eq(screen.tab(), "expedition", "再点选中的不动")
	# 木牌定稿（plaque264）：大木牌 + 挂牌标题、浅羊皮小签；都是浅底
	t.check(board.last_plate.theme_type_variation == UiTheme.PANEL_HOME_PLAQUE and board.supply_plate.theme_type_variation == UiTheme.PANEL_HOME_PLAQUE, "两块大木牌")
	var hangs: Array = board.find_children("*", "HeaderTag", true, false).filter(func(h): return (h as HeaderTag).hang)
	t.eq(hangs.size(), 3, "标题是三枚挂牌（267 加了「倾向」）")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_HOME_PLAQUE), UiTheme.TONE_LIGHT, "木牌浅底")
	# 264 §三：集市 / 铁匠铺换整屏背景，别的页回基地底图；这两页不垫粗布
	t.eq(screen.backdrop_name(), UiTheme.ART_HOME_BG, "出征页：基地底图")
	for pair in [["market", "market/scene"], ["smithy", "smithy/scene"], ["warehouse", UiTheme.ART_HOME_BG]]:
		screen.show_tab(pair[0])
		t.eq(screen.backdrop_name(), pair[1], "%s 页的背景" % pair[0])
	t.check((screen._pages["market"] as Control).get_theme_stylebox("panel") is StyleBoxEmpty, "集市页不垫粗布")
	t.check(not ((screen._pages["warehouse"] as Control).get_theme_stylebox("panel") is StyleBoxEmpty), "仓库页照旧粗布")
	screen.show_tab("warehouse")
	t.eq(screen.backdrop_name(), UiTheme.ART_HOME_BG, "回仓库：基地底图")
	t.check(screen.escape() and screen.tab() == "expedition", "Esc：别页回出征页")
	board.start_btn.pressed.emit()
	t.check(f.screen in [GameFlow.Screen.SETUP, GameFlow.Screen.MAP], "按【开始探索】出发（开局屏；教程没通直接进图）")
	screen.free()
	var g := _flow()
	var s2 = Records._screen(g, root)
	s2.escape()
	t.eq(g.screen, GameFlow.Screen.MAIN_MENU, "出征页 Esc：回主菜单")
	s2.free()
	Records._cleanup()


static func frame_last_and_supplies(t: TestCase, root: Window) -> void:
	t.begin("264 §二 · 上回出征（角色肖像 + 名、地图 · 规模、难度）与军需（随身技能圆槽 + 数量、局外加成小牌）；没有写「尚无」")
	var f := _flow()
	var ch: CharacterDef = f.characters[0]
	var chapter: ChapterDef = f.chapters[0]
	for c in f.chapters:
		if c.id == &"free_mode":
			chapter = c
	f.meta.last_character = ch.id
	f.meta.set_flag(&"last_map", chapter.order + 1)
	var opts: Array[Dictionary] = chapter.map_source.scale_options() if chapter.map_source != null else [] as Array[Dictionary]
	if not opts.is_empty():
		f.meta.set_flag(&"last_scale", 1)
	var hard: DifficultyDef = null
	for d in f.difficulties:
		if d.level > 0 and (hard == null or d.level < hard.level):
			hard = d
	if hard != null:
		f.meta.set_flag(&"last_difficulty", hard.level)
	f.meta.belt_grants = {&"smoke_bomb": 2}
	var buff := load(ContentPaths.asset_file("run_buffs", "tech_luck_1")) as RunBuffDef
	if buff != null:
		f.buff_defs[buff.id] = buff
		f.meta.tech_buffs.append(buff.id)
	var screen = Records._screen(f, root)
	var board: ExpeditionBoard = screen.expedition_board()
	var lines := board.last_lines()
	t.eq(lines[0] if lines.size() > 0 else "", Names.of(ch), "第一行：角色名")
	var portraits: Array = board.last_plate.find_children("*", "PortraitSlot", true, false)
	t.check(portraits.size() == 1 and (portraits[0] as PortraitSlot).custom_minimum_size == Vector2(72, 72), "肖像小框 72")
	t.check(lines.size() > 1 and lines[1].begins_with(Names.of(chapter)), "第二行：地图（%s）" % [lines[1] if lines.size() > 1 else ""])
	if not opts.is_empty():
		t.check(lines[1].ends_with(String(opts[0]["display_name"])), "· 规模")
	if hard != null:
		t.check(lines.size() > 2 and lines[2].begins_with(Names.of(hard)), "第三行：难度（%s）" % [lines[2] if lines.size() > 2 else ""])
	t.eq(board.belt_supplies(), [[&"smoke_bomb", 2]], "军需：随身技能 × 2")
	var slots: Array = board.supply_plate.find_children("*", "", true, false).filter(func(n): return n is ExpeditionBoard.BeltSlot)
	t.check(slots.size() == 1 and (slots[0] as ExpeditionBoard.BeltSlot)._icon != null, "一枚圆槽，画定稿图标")
	if buff != null:
		t.check(board.buff_supplies().has(buff.id), "局外加成列出来")
		var tags: Array = board.supply_plate.find_children("*", "Label", true, false).map(func(h): return (h as Label).text)
		t.check(tags.has(Names.of(buff)), "加成小牌写名字（%s）" % [tags])
	t.eq(Bare.audit(screen._pages["expedition"], "expedition"), [] as Array[String], "没有裸字")
	screen.free()
	Records._cleanup()


static func frame_shelf_sub_tabs(t: TestCase, root: Window) -> void:
	t.begin("264 §四 · 书架次级菜单：选中书架时滑出五颗小键（图鉴 / 对局记录 / 特殊道具 / 成就 / 科技）；点一颗开那扇窗、按下；关窗弹起；点书架格同步")
	var f := Records._flow()
	f.achievement_defs = GameFlow.load_achievements()
	var screen = Records._screen(f, root)
	var subs: Dictionary = screen.sub_tab_buttons("shelf")
	t.eq(subs.keys(), ["codex", "records", "keepsakes", "achievements", "tech"], "五颗，书架格的顺序")
	t.eq((subs["tech"] as Button).text, "科技", "字不带计数")
	t.check(not (subs["codex"] as Button).is_visible_in_tree(), "不在书架：收着")
	screen.toggle_tab("shelf")
	t.check(subs.values().all(func(b: Button) -> bool: return b.is_visible_in_tree()), "选中书架：露出来")
	t.check(not screen.sub_tab_buttons()["market"].is_visible_in_tree(), "后勤的小键收着")
	(subs["tech"] as Button).pressed.emit()
	t.check(screen.tab() == "shelf" and screen.shelf_open() == "tech", "点科技：书架 + 科技窗")
	t.check((subs["tech"] as Button).button_pressed and not (subs["codex"] as Button).button_pressed, "科技那颗按下")
	screen.close_shelf()
	t.check(not (subs["tech"] as Button).button_pressed, "关窗：弹起")
	(screen.shelf_view().buttons()["records"] as Button).pressed.emit()
	t.check(screen.shelf_open() == "records" and (subs["records"] as Button).button_pressed, "点书架格开窗：小键同步按下")
	screen.show_tab("warehouse")
	t.check(not (subs["records"] as Button).is_visible_in_tree() and not (subs["records"] as Button).button_pressed, "换页签：收起、弹起")
	var left: Control = (screen._tab_btns["shelf"] as Button).get_parent()
	screen.show_tab("shelf")
	t.eq(Bare.audit(left, "shelf264"), [] as Array[String], "左列没有裸字")
	var h := left.get_combined_minimum_size().y
	t.check(h <= 1000.0 - 2.0 * screen.MARGIN, "左列放得下（%.0f）" % h)
	screen.free()
	Records._cleanup()


static func frame_warehouse_tools(t: TestCase, root: Window) -> void:
	t.begin("264 §六 · 仓库页左边：包架下面筛选牌（标签 / 稀有度 / 清除）压灰不匹配的格、页签写匹配数；账牌（件数 / 总价值 / 空格）；没棋盘时窄布")
	ItemInstance.reset_uid_counter()
	var f := Records._flow()
	var knife := ItemInstance.create(f.items.get_def(&"knife"), f.meta.allocate_uid())
	var ore := ItemInstance.create(f.items.get_def(&"iron_ore"), f.meta.allocate_uid())
	var plank := ItemInstance.create(f.items.get_def(&"hardwood_plank"), f.meta.allocate_uid())
	for inst in [knife, ore, plank]:
		f.meta.warehouse.try_add(inst, true)
	var screen = Records._screen(f, root)
	screen.show_tab("warehouse")
	var tools: WarehouseTools = screen.warehouse_tools()
	t.not_null(tools, "有工具列")
	t.check(screen._wh._rack_col.is_ancestor_of(tools) and tools.get_index() > screen._wh._rack_box.get_index(), "在包架下面")
	t.check(tools.filter_plate.custom_minimum_size == Vector2(228, 150) and tools.ledger_plate.custom_minimum_size == Vector2(228, 120), "筛选牌 228 × 150、账牌 228 × 120")
	t.eq(tools.filter_plate.theme_type_variation, UiTheme.PANEL_HOME_PLAQUE_SMALL, "小木牌")
	var shelf: WarehousePages = screen.shelf()
	t.check(not shelf.filtering() and tools.clear_btn.disabled, "起手不筛，「清除」灰")
	var ore_tag: StringName = &""
	for tg in ore.def.tags:
		if not knife.def.tags.has(tg) and f.meta.sell_tags().has(tg):
			ore_tag = tg
			break
	t.check(ore_tag != &"", "找到一个矿石有、刀没有的标签（%s）" % ore_tag)
	tools.set_filter(ore_tag, -1)
	t.check(shelf.filtering() and not tools.clear_btn.disabled, "筛上了，「清除」亮")
	t.check(shelf.matches(ore) and not shelf.matches(knife), "矿石合、刀不合")
	t.check(shelf.view.dim_filter.is_valid(), "格子按筛选压灰")
	var expect := [knife, ore, plank].filter(func(it): return shelf.matches(it)).size()
	t.eq(shelf.match_count(0), expect, "页签数 = 匹配件数")
	t.check(shelf.tab(0).text.ends_with(UiText.t("wh.tab_count") % expect), "页签第二行写匹配数（%s）" % shelf.tab(0).text.replace("\n", " "))
	tools.set_filter(&"", 0)
	t.eq(shelf.filter_rarity, 0, "稀有度上限")
	tools.clear()
	t.check(not shelf.filtering() and not shelf.view.dim_filter.is_valid(), "清除：不筛、不压灰")
	t.eq(shelf.match_count(0), 3, "页签回到全部件数")
	var lines := tools.ledger_lines()
	t.eq(lines[0], UiText.t("meta.ledger_items") % 3, "件数 3")
	t.eq(lines[1], f.meta.warehouse_value(), "总价值 = 仓库总价值（碑额同一个数）")
	var free := 0
	for i in f.meta.warehouse.page_count():
		free += f.meta.warehouse.page(i).free_cell_count()
	t.eq(lines[2], UiText.t("meta.ledger_free") % free, "空格")
	f.meta.warehouse.remove(knife.uid)
	t.eq(tools.ledger_lines()[0], UiText.t("meta.ledger_items") % 2, "仓库变了跟着变")
	screen.layout()
	t.check(screen._wh_page.size.x <= screen.WH_NARROW + 60.0, "没带回来的棋盘：窄布（%.0f）" % screen._wh_page.size.x)
	t.eq(Bare.audit(screen._pages["warehouse"], "warehouse264"), [] as Array[String], "仓库页没有裸字")
	screen.free()
	var g := Records._flow()
	g.meta.board = GridInventory.new(Vector2i(6, 4), MetaState.BOARD_ID, false)
	g.meta.board.try_add(ItemInstance.create(g.items.get_def(&"knife"), g.meta.allocate_uid()))
	var s2 = Records._screen(g, root)
	s2.show_tab("warehouse")
	t.eq(s2._wh_page.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "有带回来的棋盘：粗布铺满")
	s2.free()
	Records._cleanup()


static func run_last_character_round_trip(t: TestCase) -> void:
	t.begin("264 §2.4 · MetaState.last_character 存读往返；老存档没有 = 空")
	var db := ItemDatabase.new()
	db.load_dir()
	var m := MetaState.new(GameFlow.load_meta_rules())
	t.eq(m.last_character, &"", "起手空")
	m.last_character = &"marcus"
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.eq(back.last_character, &"marcus", "存读往返")
	var old := m.to_dict()
	old.erase("last_character")
	t.eq(MetaState.from_dict(old, db, GameFlow.load_meta_rules()).last_character, &"", "老存档：空")

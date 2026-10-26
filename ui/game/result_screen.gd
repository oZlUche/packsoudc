## 结算（M6，架构文档 8 节 / 8.2；058 第 7 条）：撤离了棋盘原样带回来，在这里拖或一键置入仓库；战败什么都没有。
## 账（图鉴、价值、钱）在进这一屏之前就记好了（`GameFlow` 一局结束时 absorb）；「继续」去局外。
## 177（作者定）：撤离分两步 —— 第 1 步看账，「继续」屏内换到第 2 步置入仓库，第 2 步的「继续」才离开这一屏；战败一步到底
## 224（作者定）：第 1 步是一张逐行显出的账单（[LedgerView]，十行 + 合计，大理石碑板直接画在石板上），全显之前「继续」不可点；
## 两页的「继续」同一款石键图按钮（作者 16:06 定），第 2 步「一键置入」「整理」是同款石键小钮、和「继续」同一行
## 224 补充二（作者 17:22–17:23）：两页的石板换没有标题刻线的板边；第一页整体 ×1.2（图 2 倍分辨率缩着画）；撤离时保险箱在账单右边
## （皮带框 + 格缝，同背包棋盘），第二页只剩带回的棋盘（格子 72）和贴右上角的仓库；战败只有标题牌、账单、继续，没有第二页
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")

var _wh = null
var _safe_view: InventoryView = null
## 224 补充二：撤离第一页的保险箱 —— 框左上（账单右边），框最宽到石板内沿，格子最大 [constant SAFE_CELL]
const SAFE_AT := Vector2(1280, 160)
const SAFE_MAX_W := 218.0
const SAFE_CELL := 60.0
## 224 补充二：第二页带回来的棋盘格子（同背包窗）
const BOARD_CELL := 72.0
## 224 补充二：结算屏两页的板边（没有顶上那道标题刻线）
const SLAB_EDGE := "slab_edge_plain"
## 第 2 步内容离石板内沿的边距
const PAGE_MARGIN := 32
## 第 2 步的内容区（量仓库格子用；228 起是整屏那幅基地库间画）
var _area: Control = null
## 228：第 2 步的标题木牌
var _plank: Control = null
## 177（作者 2026-10-16「将撤离界面分为两部」）：撤离分两步 —— 1 看账，2 置入仓库；战败只有一步
var _step: int = 1
var _r: RunResult = null
## 224：第 1 步的账单与「继续」
var _ledger: LedgerView = null
var _continue: Button = null
## 224：设计稿（1600 × 1000）上的摆位 —— 账面左上、继续钮左上（账单下居中）。补充二按美术 v2 `layout.json`（×1.2）
const LEDGER_AT := Vector2(368, 210)
const CONTINUE_AT := Vector2(674, 834)
const CONTINUE_SIZE := Vector2(252, 77)
## 224：「继续」的图（`assets/ui/result/<它>_*.png`）与字心。作者 16:06 定石键（罗马式箭头），两页同款；第 2 页的小钮也是石键。
## 补充二：英文小一号、字心左移（字尾离箭头的圆头留 25 px）
const CONTINUE_ART := "result/btn_stone"
const CONTINUE_LABEL_AT := Vector2(110, 38)
const CONTINUE_LABEL_AT_EN := Vector2(100, 38)
const CONTINUE_BLEED := 7.0
## 224（作者 16:32）：第一页的标题牌 —— 牌左上、大小；图比牌四周各大 7（2 倍分辨率，按图的 1x 大小缩着画）
const TITLE_PLATE_ART := "result/title_plate"
const TITLE_PLATE_AT := Vector2(608, 92)
const TITLE_PLATE_SIZE := Vector2(384, 72)
const TITLE_PLATE_ORIGIN := Vector2(-7, -7)
const TITLE_SIZE := 43
## 228（作者 17:33 选第三案）：第二页是回到基地的木头库间 —— 整屏一幅画（tone dark），标题刻在挂着的浅木牌上（墨字），「继续」换琥珀木牌
const STOREROOM_ART := "result/bg_storeroom"
const STORE_CONTINUE_ART := "result/btn_wood_continue"
## 228：标题木牌（`title_plank.json`）：图 396 × 114，牌在图内 (6, 36) 384 × 72，九宫格两头 60 不拉伸；字号 40
const PLANK_ART := "result/title_plank"
const PLANK_TITLE_SIZE := 40
## 228：第一页 → 第二页交叉淡出（从营门走回家里）
const PAGE_FADE_SEC := 0.35


func open(payload: Dictionary) -> void:
	_r = payload.get("result", flow.result)
	_step = 1
	_build()


## 177：撤离时第 1 步的「继续」—— 屏内重建成第 2 步（不加屏、不改 GameFlow）
func to_step(n: int) -> void:
	_step = n
	# 228：旧页挪进一层盖在新页上、淡出后丢掉；不动的时候（测试、关了动效）当场清
	var old: Control = null
	if UiMotion.enabled(flow.settings if flow != null else null) and is_inside_tree():
		old = Control.new()
		old.name = "PageFadeOut"
		old.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for c in get_children():
			if c != _own_notices:
				c.reparent(old, false)
	else:
		UiTheme.clear_children(self)
	_build()
	if old != null:
		add_child(old)
		UiMotion.fade(old, true, 1.0, 0.0, PAGE_FADE_SEC).finished.connect(old.queue_free)


## 现在第几步（战败、没账都算 1）
func step() -> int:
	return _step


## 账单的行名 → 到位的数（第 2 步没有账单：空）
func numbers() -> Dictionary:
	return _ledger.numbers() if _ledger != null else {}


## 224：第 1 步的账单（第 2 步 null）
func ledger() -> LedgerView:
	return _ledger


## 224：这一步离开 / 往下走的那颗「继续」
func continue_button() -> Button:
	return _continue


func _build() -> void:
	_wh = null
	_area = null
	_plank = null
	_safe_view = null
	_ledger = null
	_continue = null
	_backdrop()
	if _r != null and not (_has_store_step() and _step == 2):
		_slab_screen(Vector2.ZERO, SLAB_EDGE)     # 157 补充三：内容在一整块石板上
		_build_summary()
		return
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.margins(margin, PAGE_MARGIN, PAGE_MARGIN, PAGE_MARGIN, PAGE_MARGIN)
	_area = _painted_screen(STOREROOM_ART) if _r != null else _slab_screen(Vector2.ZERO, SLAB_EDGE)     # 228：第二页是基地的木头库间
	_area.add_child(margin)
	# 反馈：仓库面板按自己的最小高度占满，把底部的继续按钮挤出窗口。内容放进竖向滚动，按钮钉在底下
	var outer := _vbox(10)
	margin.add_child(outer)
	if _r != null:
		_plank = _title_plank(UiText.t("result.store_title"))
		outer.add_child(_plank)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var col := _vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	if _r == null:
		col.add_child(_label(UiText.t("result.none"), 18, UiPalette.FG))
		col.add_child(_button(UiText.t("setup.main_menu"), flow.to_main_menu, 14))
		return
	_build_store(col, outer)


## 有没有第 2 步（置入仓库）：撤离了才有。224 补充二（作者 17:23）：战败永远没有第二页 —— 保险箱带出的直接进了仓库
## （[method MetaState.absorb]），放不下的才留在待置入的棋盘上、基地「仓库」页清
func _has_store_step() -> bool:
	return _r != null and _r.is_extracted()


## 224：按设计稿（1600 × 1000，屏幕正中对齐）摆一块
func _place(c: Control, at: Vector2, sz: Vector2) -> Control:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = at.x - 800.0
	c.offset_top = at.y - 500.0
	c.offset_right = c.offset_left + sz.x
	c.offset_bottom = c.offset_top + sz.y
	return c


## 224：「继续」图按钮（字由代码写）；228：第一页石键、第二页琥珀木牌（同尺寸、同字心）
func _continue_button(handler: Callable, art: String = CONTINUE_ART) -> Button:
	var en := UiText.lang == "en"
	return UiTheme.make_art_text_button(UiText.t("menu.continue"), handler, art, CONTINUE_SIZE,
		CONTINUE_LABEL_AT_EN if en else CONTINUE_LABEL_AT, 28 if en else 34, CONTINUE_BLEED)


## 228：第二页顶上挂着的标题木牌 —— 九宫格（两头不拉伸），字写在牌面正中；牌是浅木（tone light）、墨字。
## 牌宽按字撑（至少图上那块 384），图上方 36 是两根麻绳
func _title_plank(text: String) -> Control:
	var meta := UiTheme.art_meta(PLANK_ART)
	var rect: Array = meta.get("plank_rect_in_image", [6, 36, 384, 72])
	var m: Array = meta.get("margin", [60, 54, 60, 20])
	var box := Control.new()
	box.name = "TitlePlank"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.set_tone(box, StringName(String(meta.get("tone", "light"))))
	var title := UiTheme.make_title_label(text, PLANK_TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var text_w := title.get_minimum_size().x
	var plank := Vector2(maxf(float(rect[2]), text_w + float(m[0]) + float(m[2])), float(rect[3]))
	var img := Vector2(plank.x + 2.0 * float(rect[0]), plank.y + float(rect[1]) + 6.0)
	box.custom_minimum_size = img
	var tex := UiTheme.art_cached(PLANK_ART)
	if tex != null:
		var n := NinePatchRect.new()
		n.texture = tex
		n.patch_margin_left = int(m[0])
		n.patch_margin_top = int(m[1])
		n.patch_margin_right = int(m[2])
		n.patch_margin_bottom = int(m[3])
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.size = Vector2(img.x, tex.get_size().y)
		box.add_child(n)
	title.position = Vector2(float(rect[0]), float(rect[1]))
	title.size = plank
	box.add_child(title)
	return box


## 177 第 1 步（撤离）/ 唯一一步（战败）：标题牌，下面账单（224），账单下居中「继续」（全显之前不可点）。
## 224 补充二：撤离时保险箱摆在账单右边；战败只有这三样
func _build_summary() -> void:
	var r := _r
	var extracted := r.is_extracted()
	var page := Control.new()
	page.name = "Page1"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	UiTheme.set_tone(page, UiTheme.TONE_LIGHT)     # 石板是浅底：标题墨字
	# 作者 16:32「去掉所有界面里的裸露文字」：标题刻进标题牌（半透明，直接画在石板上），副标题（章节 · 结局）删掉
	var plate := TextureRect.new()
	plate.name = "TitlePlate"
	plate.texture = UiTheme.art_cached(TITLE_PLATE_ART)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE     # 补充二：图是 2 倍分辨率，按牌的 1x 大小缩着画
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_place(plate, TITLE_PLATE_AT + TITLE_PLATE_ORIGIN, TITLE_PLATE_SIZE - TITLE_PLATE_ORIGIN * 2.0))
	var title := UiTheme.make_title_label(UiText.t("result.extracted") if extracted else UiText.t("result.defeat"), TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_meta(&"exempt_bare_text", "TitlePlate")     # 226 守门：字摆在同位置那块标题牌图上
	page.add_child(_place(title, TITLE_PLATE_AT, TITLE_PLATE_SIZE))
	# 104：信力节奏的量尺（数值都是占位，作者打几局对着这一行调表）；开发版可以导 CSV
	if r.faith_pace != "" and GameSettings.dev_build():     # 作者 2026-10-17：调表用的量尺只在开发环境
		var pace_row := _hbox(12)
		pace_row.set_meta(&"exempt_bare_text", "dev")     # 226 守门：开发量尺
		pace_row.add_child(_label(r.faith_pace, 13, LedgerView.INK_DIM))
		var pace_note := _label("", 12, LedgerView.INK_DIM)
		var export_csv := func():
			var path := r.export_faith_csv()
			pace_note.text = ("已写到 " + ProjectSettings.globalize_path(path)) if path != "" else "没写成"
		pace_row.add_child(_button("导出信力 CSV", export_csv, 12, UiPalette.Tier.MINOR))
		pace_row.add_child(pace_note)
		page.add_child(_place(pace_row, Vector2(80, 900), Vector2(1440, 40)))
	_ledger = LedgerView.new()
	_ledger.setup(r, int(flow.last_absorbed.get("lit", 0)))
	page.add_child(_place(_ledger, LEDGER_AT, LedgerView.LEDGER_SIZE))
	if extracted:
		_add_safe(page)
	_continue = _continue_button(to_step.bind(2) if _has_store_step() else proceed)
	page.add_child(_place(_continue, CONTINUE_AT, CONTINUE_SIZE))
	_continue.disabled = not _ledger.is_revealed()
	_ledger.revealed.connect(func():
		if is_instance_valid(_continue):
			_continue.disabled = false)


## 177 第 2 步：带回来的棋盘（靠左）与仓库（贴右上角）；不写说明字。224 补充二：保险箱挪到第一页，中间那道分隔线删了
func _build_store(col: VBoxContainer, outer: VBoxContainer) -> void:
	_add_warehouse(col)
	_add_proceed(outer)


## 224：第 2 步的仓库面板 —— 石键小钮，「继续」放进同一行的右端（右沿对齐仓库区右沿）。
## 补充二：带回来的棋盘格子 72，仓库格子按剩下的宽高放大（[method WarehousePages.fit]）
func _add_warehouse(col: VBoxContainer) -> void:
	_wh = WarehousePanelScript.new()
	_wh.art_buttons = true
	_wh.board_cell = BOARD_CELL
	_wh.setup(flow, font)
	_wh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_wh)
	if _area != null:     # 量石板内容区（锚在屏上，不随内容变）；量滚动区会被仓库撑宽、越放越大
		_area.resized.connect(_fit_shelf.bind(_area))
		_fit_shelf(_area)


## 补充二：仓库格子吃满带回来的棋盘右边剩下的宽、按钮行上面剩下的高（[param area] = 石板内容区，扣掉四边 [constant PAGE_MARGIN]）
func _fit_shelf(area: Control) -> void:
	if _wh == null or not is_instance_valid(area) or area.size.x <= 0.0:
		return
	var used: float = _wh.rack_room()
	if flow.meta.board != null:
		used += BOARD_CELL * maxi(CharacterDef.BOARD_MAX_W, flow.meta.board.size.x) + 2.0 * WarehousePanelScript.BOARD_FRAME_PAD + WarehousePanelScript.ROW_GAP     # 255 补充一：带回来的棋盘占九格宽的位子
	used += WarehousePanelScript.ROW_GAP + 4.0     # 228：仓库右对齐那块空位两边各一道行距（原来少算一道，第二页铺满整屏后仓库顶出右沿）
	used += WarehousePanelScript.RESULT_SHELF_RIGHT + WarehousePanelScript.ROW_GAP     # 木架框离右沿那块空，和它前面那道行距
	var w := area.size.x - 2.0 * PAGE_MARGIN - used
	var top := _plank.custom_minimum_size.y + 10.0 if is_instance_valid(_plank) else 0.0     # 228：标题木牌那一行
	var h := area.size.y - 2.0 * PAGE_MARGIN - top - CONTINUE_SIZE.y - 2.0 * CONTINUE_BLEED - 10.0 - 12.0 - WarehousePanelScript.RESULT_SHELF_TOP     # 按钮行、行距、分页签顶上那点空、离挂钉板那点空
	_wh.shelf().fit(w, h)


## 092：保险箱单独一格（放进去的视为已带出，战败也在）。224 补充二：只在撤离的第一页、账单右边，
## 皮带框 + 格缝同背包棋盘（227 清单那行 `plain` → `player`）；格子按框能占的宽缩（最大 [constant SAFE_CELL]）
func _add_safe(page: Control) -> void:
	var r := _r
	if r.safe_items.is_empty():
		return
	_safe_view = InventoryView.new()
	_safe_view.label_font = font
	_safe_view.inventory = _safe_display(r)
	_safe_view.show_adjacency = false
	var pad := 2.0 * WarehousePanelScript.BOARD_FRAME_PAD
	_safe_view.cell_px = minf(SAFE_CELL, floorf((SAFE_MAX_W - pad) / float(maxi(1, r.safe_size.x))))
	var frame := WarehousePanelScript.framed(_safe_view, "SafeFrame")
	BoardFrame.mark(_safe_view, frame)     # 227：皮带框 + 浅色格缝
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := Vector2(_safe_view.cell_px * r.safe_size.x, _safe_view.cell_px * r.safe_size.y) + Vector2(pad, pad)
	page.add_child(_place(frame, SAFE_AT, sz))


## 「继续」（[method proceed]）：224 起放进仓库面板按钮行的右端（作者 16:32：序章之间那句「下面直接进…」也删了）
func _add_proceed(outer: VBoxContainer) -> void:
	_continue = _continue_button(proceed, STORE_CONTINUE_ART)     # 228：琥珀木牌
	var row: HBoxContainer = _wh.button_row() if _wh != null else null
	if row == null:
		outer.add_child(_continue)
		return
	# 按钮行挪到滚动区外、钉在底下（反馈：仓库别把它挤出窗口），宽度跟着仓库面板 —— 「继续」右沿对齐仓库区右沿
	row.get_parent().remove_child(row)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	outer.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_continue)
	var wh: Control = _wh
	var follow := func():
		if is_instance_valid(row) and is_instance_valid(wh):
			row.custom_minimum_size.x = wh.size.x
	wh.resized.connect(follow)
	follow.call()


## 092：结算屏上画的保险箱：按 RunResult 记下的布局重摆一份只看的（实例已经进了局外，这里另造）
static func _safe_display(r: RunResult) -> GridInventory:
	var grid := GridInventory.new(r.safe_size, 0, false)
	for entry in r.safe_layout:
		var inst := ItemInstance.create(entry["def"], int(entry["rotation"]))
		if not grid.place(inst, entry["origin"], int(entry["rotation"])):
			grid.try_add(inst, true)
	return grid


## 结算屏上的保险箱格子（测试直接读）
func safe_view() -> InventoryView:
	return _safe_view


## 一键置入（测试直接调）
func store_all() -> Dictionary:
	return _wh.store_all() if _wh != null else {"moved": 0, "left": 0, "stuck": ""}


## 「继续」：有下一张教学图就直接进（085），否则去局外
func proceed() -> void:
	if flow.next_chapter() != null:
		flow.start_next_chapter()
	else:
		flow.finish_result()


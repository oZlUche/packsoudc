## 结算（M6，架构文档 8 节 / 8.2；058 第 7 条）：撤离了棋盘原样带回来，在这里拖或一键置入仓库；战败什么都没有。
## 账（图鉴、价值、钱）在进这一屏之前就记好了（`GameFlow` 一局结束时 absorb）；「继续」去局外。
## 177（作者定）：撤离分两步 —— 第 1 步看账，「继续」屏内换到第 2 步置入仓库，第 2 步的「继续」才离开这一屏；战败一步到底
## 224（作者定）：第 1 步是一张逐行显出的账单（[LedgerView]，十行 + 合计，大理石碑板直接画在石板上），全显之前「继续」不可点；
## 两页的「继续」同一款石键图按钮（作者 16:06 定），第 2 步「一键置入」「整理」是同款石键小钮、和「继续」同一行
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")

var _wh = null
var _safe_view: InventoryView = null
## 157：战败时保险箱放大居中 —— 格子按这个画（撤离时照旧是视图的默认格）
const DEFEAT_SAFE_CELL := 60.0
## 177（作者 2026-10-16「将撤离界面分为两部」）：撤离分两步 —— 1 看账，2 置入仓库；战败只有一步
var _step: int = 1
var _r: RunResult = null
## 224：第 1 步的账单与「继续」
var _ledger: LedgerView = null
var _continue: Button = null
## 224：设计稿（1600 × 1000）上的摆位 —— 账面左上、继续钮左上（账单下居中）
const LEDGER_AT := Vector2(440, 190)
const CONTINUE_AT := Vector2(695, 690)
const CONTINUE_SIZE := Vector2(210, 64)
## 224：「继续」的图（`assets/ui/result/<它>_*.png`）与字心。作者 16:06 定石键（罗马式箭头），两页同款；第 2 页的小钮也是石键
const CONTINUE_ART := "result/btn_stone"
const CONTINUE_LABEL_AT := Vector2(92, 32)
## 224（作者 16:32）：第一页的标题牌 —— 牌左上、大小；图比牌四周各大 6
const TITLE_PLATE_ART := "result/title_plate"
const TITLE_PLATE_AT := Vector2(640, 84)
const TITLE_PLATE_SIZE := Vector2(320, 60)
const TITLE_PLATE_ORIGIN := Vector2(-6, -6)


func open(payload: Dictionary) -> void:
	_r = payload.get("result", flow.result)
	_step = 1
	_build()


## 177：撤离时第 1 步的「继续」—— 屏内重建成第 2 步（不加屏、不改 GameFlow）
func to_step(n: int) -> void:
	_step = n
	UiTheme.clear_children(self)
	_build()


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
	_safe_view = null
	_ledger = null
	_continue = null
	_backdrop()
	if _r != null and not (_has_store_step() and _step == 2):
		_slab_screen()     # 157 补充三：内容在一整块石板上
		_build_summary()
		return
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_slab_screen().add_child(margin)
	# 反馈：仓库面板按自己的最小高度占满，把底部的继续按钮挤出窗口。内容放进竖向滚动，按钮钉在底下
	var outer := _vbox(10)
	margin.add_child(outer)
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


## 有没有第 2 步（置入仓库）：撤离了有；224：战败但带回来的背包里有东西（保险箱带出的、上一局没置入的）也有 —— 账单占了第一页，放不下仓库
func _has_store_step() -> bool:
	return _r != null and (_r.is_extracted() or flow.meta.has_pending_board())


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


## 224：两页同一款「继续」图按钮（字由代码写）
func _continue_button(handler: Callable) -> Button:
	return UiTheme.make_art_text_button(UiText.t("menu.continue"), handler, CONTINUE_ART, CONTINUE_SIZE, CONTINUE_LABEL_AT, 28)


## 177 第 1 步（撤离）/ 唯一一步（战败）：标题、章节 · 结局，下面账单（224），账单下居中「继续」（全显之前不可点）。
## 战败另把保险箱放大摆在账单右边、「全丢了」一句在账单下
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
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_place(plate, TITLE_PLATE_AT + TITLE_PLATE_ORIGIN, TITLE_PLATE_SIZE - TITLE_PLATE_ORIGIN * 2.0))
	var title := UiTheme.make_title_label(UiText.t("result.extracted") if extracted else UiText.t("result.defeat"), 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page.add_child(_place(title, TITLE_PLATE_AT, TITLE_PLATE_SIZE))
	# 104：信力节奏的量尺（数值都是占位，作者打几局对着这一行调表）；开发版可以导 CSV
	if r.faith_pace != "" and GameSettings.dev_build():     # 作者 2026-10-17：调表用的量尺只在开发环境
		var pace_row := _hbox(12)
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
	if not extracted:
		var lost := _wrapped(UiText.t("result.lost_all") + (UiText.t("result.lost_safe") % r.safe_items.size() if not r.safe_items.is_empty() else ""), 15, UiTheme.INK, 720)
		lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(_place(lost, Vector2(440, 772), Vector2(720, 40)))     # 「继续」下面
		var safe_col := _vbox(6)
		_add_safe(safe_col, false)
		page.add_child(_place(safe_col, Vector2(1200, 190), Vector2(320, 260)))
	_continue = _continue_button(to_step.bind(2) if _has_store_step() else proceed)
	page.add_child(_place(_continue, CONTINUE_AT, CONTINUE_SIZE))
	_continue.disabled = not _ledger.is_revealed()
	_ledger.revealed.connect(func():
		if is_instance_valid(_continue):
			_continue.disabled = false)


## 177 第 2 步：保险箱小格 + 带回来的棋盘（靠左）与仓库（224：右对齐）；不写说明字
func _build_store(col: VBoxContainer, outer: VBoxContainer) -> void:
	_add_safe(col, true)     # 224（作者 16:32 去掉裸露文字）：顶上那行「置入仓库 / 总价值 · 带出」删了
	col.add_child(HSeparator.new())
	_add_warehouse(col)
	_add_proceed(outer)


## 224：第 2 步的仓库面板 —— 石键小钮，「继续」放进同一行的右端（右沿对齐仓库区右沿）
func _add_warehouse(col: VBoxContainer) -> void:
	_wh = WarehousePanelScript.new()
	_wh.art_buttons = true
	_wh.setup(flow, font)
	_wh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_wh)


## 092：保险箱单独一格（放进去的视为已带出，战败也在）
## 157：战败时这是唯一带出来的东西 —— 居中、放大（格子 60），字也大一号
func _add_safe(col: VBoxContainer, extracted: bool) -> void:
	var r := _r
	if r.safe_items.is_empty():
		return
	var safe_row := _hbox(16)
	var safe_col := _vbox(4)
	if not extracted:
		safe_row.alignment = BoxContainer.ALIGNMENT_CENTER
		safe_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		safe_col.alignment = BoxContainer.ALIGNMENT_CENTER
	if not extracted:     # 224：第 2 步不写说明字（作者 16:32）；战败第一页那句在账单右边、保险箱上
		var safe_label := _label(UiText.t("result.safe_line") % [r.safe_items.size(), r.safe_value], 16, LedgerView.INK_LABEL)
		safe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		safe_col.add_child(safe_label)
	_safe_view = InventoryView.new()
	_safe_view.label_font = font
	_safe_view.inventory = _safe_display(r)
	_safe_view.show_adjacency = false
	_safe_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if extracted else Control.SIZE_SHRINK_CENTER
	if not extracted:
		_safe_view.cell_px = DEFEAT_SAFE_CELL
	safe_col.add_child(_safe_view)
	safe_row.add_child(safe_col)
	col.add_child(safe_row)


## 「继续」（[method proceed]）：224 起放进仓库面板按钮行的右端（作者 16:32：序章之间那句「下面直接进…」也删了）
func _add_proceed(outer: VBoxContainer) -> void:
	_continue = _continue_button(proceed)
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


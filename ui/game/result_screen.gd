## 结算（M6，架构文档 8 节 / 8.2；058 第 7 条）：撤离了棋盘原样带回来，在这里拖或一键置入仓库；战败什么都没有。
## 账（图鉴、价值、钱）在进这一屏之前就记好了（`GameFlow` 一局结束时 absorb）；「继续」去局外。
## 177（作者定）：撤离分两步 —— 第 1 步大字看账（总价值、图鉴新点亮、带出金币），「继续」屏内换到第 2 步置入仓库，
## 第 2 步的「继续」才离开这一屏；战败一步到底
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")

var _wh = null
var _safe_view: InventoryView = null
var _stash_line: Label = null
## 157：战败时保险箱放大居中 —— 格子按这个画（撤离时照旧是视图的默认格）
const DEFEAT_SAFE_CELL := 60.0
## 177（作者 2026-10-16「将撤离界面分为两部」）：撤离分两步 —— 1 看账（大字），2 置入仓库；战败只有一步
var _step: int = 1
var _r: RunResult = null
## 177：大数的字号（总价值 / 其余两块）。方案写 48 / 32；马善政的数字字面只占字号的七成左右，实画偏小，放大到 64 / 44
const BIG_NUMBER_PX := 64
const NUMBER_PX := 44
## 177：这一步画出来的大数（名 → 数字标签，测试读）
var _numbers: Dictionary = {}


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


## 177：这一步画出来的大数（「总价值」「图鉴新点亮」「带出金币」「保险箱带出」→ 数字标签）
func numbers() -> Dictionary:
	return _numbers


func _build() -> void:
	_wh = null
	_safe_view = null
	_stash_line = null
	_numbers = {}
	_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_slab_screen().add_child(margin)     # 157 补充三：内容在一整块石板上
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
		col.add_child(_label("没有可结算的一局", 18, UiPalette.FG))
		col.add_child(_button("回主菜单", flow.to_main_menu, 14))
		return
	if _r.is_extracted() and _step == 2:
		_build_store(col, outer)
	else:
		_build_summary(col, outer)


## 177 第 1 步（撤离）/ 唯一一步（战败）：账 —— 标题、读数行、三块大数、件数与遗落提示，居中
func _build_summary(col: VBoxContainer, outer: VBoxContainer) -> void:
	var r := _r
	var extracted := r.is_extracted()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_centered(_label("撤离成功" if extracted else "战败", 28, UiPalette.HEAL if extracted else UiPalette.HP)))
	col.add_child(_centered(_label("%s　%s" % [r.chapter_name, _reason_text(r.reason)], 13, UiPalette.DIM)))     # 作者 2026-10-17：种子不给玩家看
	col.add_child(_centered(_label("走了 %d 步　踩过 %d 个点　打赢 %d 场　打输 %d 场" % [r.steps, r.visited, r.battles_won, r.battles_lost], 14, UiPalette.FG)))
	# 104：信力节奏的量尺（数值都是占位，作者打几局对着这一行调表）；开发版可以导 CSV
	if r.faith_pace != "" and GameSettings.dev_build():     # 作者 2026-10-17：调表用的量尺只在开发环境
		var pace_row := _hbox(12)
		pace_row.alignment = BoxContainer.ALIGNMENT_CENTER
		pace_row.add_child(_label(r.faith_pace, 13, UiPalette.DIM))
		var pace_note := _label("", 12, UiPalette.DIM)
		var export_csv := func():
			var path := r.export_faith_csv()
			pace_note.text = ("已写到 " + ProjectSettings.globalize_path(path)) if path != "" else "没写成"
		pace_row.add_child(_button("导出信力 CSV", export_csv, 12, UiPalette.Tier.MINOR))
		pace_row.add_child(pace_note)
		col.add_child(pace_row)
	var lit := int(flow.last_absorbed.get("lit", 0))
	var row := _hbox(48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if extracted:
		# 177 待定 1 选 A：总价值 = 背出来的 + 保险箱里的
		row.add_child(_number_block("总价值", r.value + r.safe_value, BIG_NUMBER_PX, UiPalette.HEAL))
		row.add_child(_number_block("图鉴新点亮", lit, NUMBER_PX, UiPalette.FG if lit > 0 else UiPalette.DIM))
		row.add_child(_number_block("带出金币", r.balance, NUMBER_PX, UiPalette.STAMINA))
	else:
		# 177 §2.3：战败只画保险箱那块（有图鉴点亮再画一块）；钱是 0，不画
		if not r.safe_items.is_empty():
			row.add_child(_number_block("保险箱带出", r.safe_value, BIG_NUMBER_PX, UiPalette.HEAL))
		if lit > 0:
			row.add_child(_number_block("图鉴新点亮", lit, NUMBER_PX, UiPalette.FG))
	if row.get_child_count() > 0:
		col.add_child(row)
	if extracted:
		col.add_child(_centered(_label("背出来 %d 件、保险箱 %d 件" % [r.carried.size(), r.safe_items.size()], 13, UiPalette.DIM)))
		# 092（作者定）：地上没背出来的，离开这一屏时一键出售 —— 先说清楚（177：第 1 步就说）
		if r.left_behind > 0:
			var sale := flow.stash_sale_preview()
			_stash_line = _wrapped("地上还有 %d 件（值 %d 币）没背出来：离开这一屏时会一键出售，得 %d 币（按基地出售比例）。" % [r.left_behind, r.left_value, int(sale["funds"])], 13, UiPalette.STAMINA, 700)
			_stash_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(_centered(_stash_line))
		col.add_child(_centered(_button("继续", to_step.bind(2), 16, UiPalette.Tier.PRIMARY)))
		return
	var lost := _wrapped("背包、地上、钱，全都留在了里面。" + ("保险箱里的 %d 件带出来了。" % r.safe_items.size() if not r.safe_items.is_empty() else ""), 14, UiPalette.FG, 600)
	lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_centered(lost))
	_add_safe(col, false)
	if flow.meta.has_pending_board():
		col.add_child(HSeparator.new())
		_add_warehouse(col)
	_add_proceed(outer)


## 177 第 2 步（只有撤离）：回看一行账（待定 2 选 A）+ 保险箱小格 + 带回来的棋盘与仓库（原来的下半截）
func _build_store(col: VBoxContainer, outer: VBoxContainer) -> void:
	var r := _r
	var head := _hbox(16)
	head.add_child(_label("置入仓库", 18, UiPalette.FG))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label("总价值 %d · 带出 %d 币" % [r.value + r.safe_value, r.balance], 13, UiPalette.DIM))
	col.add_child(head)
	_add_safe(col, true)
	col.add_child(HSeparator.new())
	_add_warehouse(col)
	_add_proceed(outer)


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
	var safe_label := _label("保险箱带出 %d 件、值 %d 币" % [r.safe_items.size(), r.safe_value], 13 if extracted else 16, UiPalette.HEAL)
	if not extracted:
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


func _add_warehouse(col: VBoxContainer) -> void:
	_wh = WarehousePanelScript.new()
	_wh.setup(flow, font)
	_wh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_wh)


## 底下钉住的「继续」/「进入下一张：X」（[method proceed]）
func _add_proceed(outer: VBoxContainer) -> void:
	var next := flow.next_chapter()
	if next != null:
		outer.add_child(_wrapped("带回来的东西会进仓库。序章一张接一张：下面直接进「%s」。" % next.display_name, 13, UiPalette.DIM, 600))
		outer.add_child(_button("进入下一张：%s" % next.display_name, proceed, 16, UiPalette.Tier.PRIMARY))
	else:
		outer.add_child(_button("继续", proceed, 16, UiPalette.Tier.PRIMARY))


## 177：一块大数 —— 上数（马善政）下名，竖排居中
func _number_block(name: String, value: int, px: int, color: Color) -> VBoxContainer:
	var box := _vbox(2)
	box.alignment = BoxContainer.ALIGNMENT_END     # 名字一排对齐（数字大小不一）
	var num := _label(str(value), px, color)
	num.add_theme_font_override("font", UiPalette.display_font())
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(num)
	var cap := _label(name, 13, UiPalette.DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	_numbers[name] = num
	return box


## 竖排里横向居中的一行
static func _centered(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


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


func _reason_text(reason: StringName) -> String:
	match reason:
		&"extract":
			return "从撤离点出来"
		&"vitality_depleted":
			return "体力耗尽"
		&"boss_lost":
			return "核心一战失利"
		&"fatal_loss":
			return "输了一场不能输的仗"
		&"boss":
			return "击败了核心的 BOSS，直接撤离"
		&"time_out":
			return "倒计时归零：行动失败"
	return String(reason)

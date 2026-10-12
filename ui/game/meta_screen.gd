## 局外 / 基地（M6，架构文档 8.2；058 第 4 / 7 条）：页签（088 作者定）—— **仓库**（格子、带回来还没清空的背包）与**图鉴**（带出过的道具点亮、
## 记累计件数，停上去看属性；特殊道具另列），后来又加了成就、出售、科技。
## 139（作者定）：开发开关、局外解锁、科技等级、最近几局收进「调试台」抽屉（[DevDrawer]，箭头在右上角）。
## 带回来的背包没清空之前「再来一局」是灰的（作者：提示玩家清空背包再配置）。
##
## 164（作者定）：三列 —— 左列（[constant LEFT_W]）：「基地」、四个页签竖排（图鉴、成就、出售、科技；再点一次选中的回「家」），
## 左下角「再来一局」（主档）与「回主菜单」；中列：当前页，默认「家」（这一局、战绩、带回来的背包与一键置入 / 整理）；
## 右半边：仓库（163 的 [WarehousePages]）常驻，10 × 8 整块可见（格子按宽高取小，40 ～ 80）。双击仓库一件按当前页：家 → 置入带回来的背包、
## 出售 → 卖、科技 → 上交、图鉴 / 成就 → 不做事。整屏一层拖拽，中列与右半边之间能拖。背景、按钮、文本框、仓库木架用「家」套件（`assets/ui/home/`）
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")
const TechPanelScript := preload("res://ui/game/tech_panel.gd")
## 图鉴缩略图之间的空隙；一行几个按宽度算（139）
const CODEX_GAP := 8
## 左列宽、整屏外边距、三列之间的空
const LEFT_W := 220.0
const MARGIN := 24.0
const COL_GAP := 24.0
## 右半边标题行的高（「仓库　N 件」与调试台箭头）
const SHELF_HEAD := 44.0
## 左列四个页签（页签名、字）；「家」不在里面 —— 再点一次选中的页签回家
const TABS := [["codex", "图鉴"], ["achievements", "成就"], ["sell", "出售"], ["tech", "科技"]]

var _wh = null
var _new_run_btn: Button
var _hint: Label
var _buff_btns: Dictionary = {}
var _unlock_btns: Dictionary = {}
## 119：开发区的科技等级数字框，科技 id → SpinBox（导出包里空）
var _tech_spins: Dictionary = {}
## 页签名 → 那一页的控件；`_tab_btns` 页签名 → 按钮
var _pages: Dictionary = {}
var _tab_btns: Dictionary = {}
var _tab: String = ""
## 164：页签选中时左上角挂的小木牌（`home/tab_mark.png`；没图不挂）
var _tab_mark: TextureRect = null
## 图鉴页的缩略图与它的悬浮窗
var _codex_tiles: Array[CodexTile] = []
## 095：异体弹窗
var _variants_popup: Control = null
var _variant_tiles: Array[CodexTile] = []
var _codex_tip: HoverTip = null
## 091：成就页的筛选（"all" / "done" / "todo"）、列表与现在列着的行
var _ach_filter: String = "all"
var _ach_filter_btns: Dictionary = {}
var _ach_list: VBoxContainer = null
var _ach_hint: Label = null
var _ach_rows: Array = []
## 139：调试台抽屉
var _drawer: DevDrawer = null
var _debug_btn: Button = null
var _codex_grids: Array[GridContainer] = []
## 164：三列与右半边的仓库（整屏的拖拽层是 [member GameScreen._drag]）
var _cols: HBoxContainer = null
var _middle: VBoxContainer = null
var _right: VBoxContainer = null
var _shelf: WarehousePages = null
var _shelf_frame: PanelContainer = null
var _shelf_title: Label = null


func open(payload: Dictionary) -> void:
	var m := flow.meta
	UiTheme.dress_home_backdrop(_backdrop())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(MARGIN))
	add_child(margin)
	_cols = _hbox(int(COL_GAP))
	margin.add_child(_cols)
	_drag = DragLayer.new()
	_drag.label_font = font

	# 左列：标题、四个页签竖排；底下「再来一局」「回主菜单」
	var left := _vbox(12)
	left.custom_minimum_size.x = LEFT_W
	_cols.add_child(left)
	left.add_child(_label("基地", 30, UiPalette.FG))
	for pair in TABS:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(pair[1], func(): toggle_tab(key))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(LEFT_W * 0.8, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_tab_btns[key] = b
		left.add_child(b)
	var tex := UiTheme.art(UiTheme.ART_TAB_MARK)
	if tex != null:
		_tab_mark = TextureRect.new()
		_tab_mark.texture = tex
		_tab_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tab_mark.position = Vector2(-10, -14)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_hint = _wrapped("", 13, UiPalette.STAMINA, LEFT_W)
	left.add_child(_hint)
	_new_run_btn = UiTheme.make_home_button("再来一局", flow.new_run, true)
	_new_run_btn.custom_minimum_size = Vector2(LEFT_W, 76)
	left.add_child(_new_run_btn)
	var menu_btn := UiTheme.make_home_button("回主菜单", flow.to_main_menu)
	menu_btn.custom_minimum_size = Vector2(LEFT_W * 0.8, 56)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(menu_btn)

	# 中列：当前页
	_middle = _vbox(10)
	_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cols.add_child(_middle)

	# 右半边：仓库（先建 —— 家页的带回来背包、科技页的上交区都要和它同一层拖拽）
	_right = _vbox(8)
	_cols.add_child(_right)
	var head := _hbox(8)
	head.custom_minimum_size.y = SHELF_HEAD
	_right.add_child(head)
	_shelf_title = _label("仓库", 20, UiPalette.FG)
	_shelf_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_shelf_title)
	_drawer = DevDrawer.new()
	head.add_child(_drawer.arrow)
	_shelf_frame = UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_SHELF)
	_shelf_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_right.add_child(_shelf_frame)
	_shelf = WarehousePages.new()
	_shelf_frame.add_child(_shelf)
	_shelf.setup(m.warehouse, font, _drag, TechWarehousePages.plan_of(flow.tech_defs))
	_drag.register_view(_shelf.view)
	_shelf.view.item_double_clicked.connect(_on_shelf_double_clicked)
	m.warehouse.changed.connect(_refresh_shelf_title)

	# 家页：这一局、战绩（粗布框里），带回来的背包与一键置入 / 整理
	var home := _vbox(12)
	home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.add_child(home)
	_pages["home"] = home
	var box := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_BOX)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	home.add_child(box)
	var info := _vbox(6)
	box.add_child(info)
	var tone := UiTheme.tone_of(UiTheme.PANEL_HOME_BOX)
	var just: RunResult = payload.get("result", null)
	if just != null:
		var c := UiPalette.HEAL if just.is_extracted() else UiPalette.HP
		info.add_child(_wrapped("刚才这一局：%s" % ("撤离，背出来 %d 件、值 %d 币、带出 %d 币" % [just.carried.size(), just.value, just.balance]
			if just.is_extracted() else ("战败，保险箱里的 %d 件带出来了" % just.safe_items.size() if not just.safe_items.is_empty() else "战败，什么都没带出来")), 15,
			UiTheme.ink_color(c) if tone == UiTheme.TONE_LIGHT else c, 460))
	# 092：离开结算屏时地上一键出售了 —— 提示一句
	var sold: Dictionary = payload.get("stash_sold", {})
	if int(sold.get("count", 0)) > 0:
		info.add_child(_wrapped("上一局地上没背出来的 %d 件已一键出售，得 %d 币。" % [int(sold["count"]), int(sold["funds"])], 14, UiPalette.STAMINA, 460))
	info.add_child(_wrapped("%d 局　撤离 %d　战败 %d　累计价值 %d　单局最高 %d\n钱 %d　图鉴 %d / %d" % [
		m.runs, m.extractions, m.deaths, m.score, m.best_value, m.funds, m.codex.size(), flow.items.ids(true).size()], 15, UiPalette.FG, 460))
	_wh = WarehousePanelScript.new()
	_wh.setup(flow, font, _shelf, _drag)
	_wh.changed.connect(_refresh)
	var wh_box := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_BOX)
	wh_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wh_box.add_child(_wh)
	home.add_child(wh_box)

	# 调试台（139：原来仓库页的右列）
	var right := _drawer.content
	# 150 补 2：头部写着现在的调试模式，点一下切（和设置页那个勾选是同一个开关）
	_debug_btn = _button("", toggle_debug_mode, 13, UiPalette.Tier.MINOR)
	_debug_btn.text = _debug_text()
	right.add_child(_debug_btn)
	# 开发开关：只在非导出包显示。科技给的局外 buff 由「科技」页的等级决定（写进 tech_buffs），不在这里重复开关
	if not OS.has_feature("template"):
		right.add_child(_label("开发：局外 buff 开关（科技给的在下面「科技等级」里改）", 15, UiPalette.DIM))
		var ids_b: Array = flow.buff_defs.keys()
		ids_b.sort()
		var from_tech := {}
		for t in flow.tech_defs:
			if t.effect is TechRunBuff:
				for tid in (t.effect as TechRunBuff).buffs:
					from_tech[tid] = true
		var any_meta := false
		for id in ids_b:
			var def: RunBuffDef = flow.buff_defs[id]
			if not def.is_meta() or from_tech.has(id):
				continue
			any_meta = true
			var bid: StringName = id
			var b := _button("%s　%s" % [def.display_name, def.summary()], func(): toggle_buff(bid), 13, UiPalette.Tier.MINOR)
			b.toggle_mode = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.set_pressed_no_signal(m.active_buffs.has(bid))
			_buff_btns[bid] = b
			right.add_child(b)
		if not any_meta:
			right.add_child(_label("（没有局外 buff 的内容）", 12, UiPalette.DIM))
	# 局外解锁（069，占位开关）：难度定义里要求的解锁 id 各一个开关；085：章节通关给的解锁也列（关掉 = 教程重新顶上）
	var unlock_ids: Array[StringName] = []
	for d in flow.difficulties:
		if d.requires_unlock != &"" and not unlock_ids.has(d.requires_unlock):
			unlock_ids.append(d.requires_unlock)
	for c in flow.chapters:
		if c.grants_unlock != &"" and not unlock_ids.has(c.grants_unlock):
			unlock_ids.append(c.grants_unlock)
	if not unlock_ids.is_empty():
		right.add_child(_label("局外解锁　占位：开关列表，将来由成长系统决定", 15, UiPalette.DIM))
		for uid in unlock_ids:
			var names: Array[String] = []
			for d in flow.difficulties:
				if d.requires_unlock == uid:
					names.append("难度：" + d.display_name)
			for c in flow.chapters:
				if c.grants_unlock == uid:
					names.append("通关：" + c.display_name)
				elif c.requires_unlock == uid:
					names.append("开放：" + c.display_name)
			var key: StringName = uid
			var ub := _button("%s　%s" % [uid, "、".join(names)], func(): toggle_unlock(key), 13, UiPalette.Tier.MINOR)
			ub.toggle_mode = true
			ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ub.set_pressed_no_signal(m.has_unlock(key))
			_unlock_btns[key] = ub
			right.add_child(ub)
	# 119：开发区手改进度表（存档的 tech_levels）—— 每个科技一个数字框，导出包里没有
	if not OS.has_feature("template") and not flow.tech_defs.is_empty():
		right.add_child(_label("科技等级　开发：直接改存档里点到几级（0 = 没点亮），效果跟着重算", 15, UiPalette.DIM))
		var grid := GridContainer.new()
		grid.columns = 2     # 139：抽屉窄，一行一个科技
		grid.add_theme_constant_override("h_separation", 12)
		right.add_child(grid)
		for t in flow.tech_defs:
			var tid: StringName = t.id
			grid.add_child(_label(Names.of(t), 13, UiPalette.FG))
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = t.max_level()
			spin.step = 1
			spin.rounded = true
			spin.set_value_no_signal(TechService.level(m, tid))
			spin.value_changed.connect(func(v: float): set_tech_level(tid, int(v)))
			_tech_spins[tid] = spin
			grid.add_child(spin)
	right.add_child(_label("最近几局", 15, UiPalette.DIM))
	var log := _log_box(13)
	for h in m.history:
		var extracted := String(h.get("outcome", "")) == "extracted"
		log.append_text("[color=#%s]%s[/color]　种子 %d　行动点 %d　打赢 %d　%s\n" % [
			(UiPalette.HEAL if extracted else UiPalette.HP).to_html(false), "撤离" if extracted else "战败",
			int(h.get("seed", 0)), int(h.get("steps", 0)), int(h.get("battles_won", 0)),
			"%d 件、值 %d 币、带出 %d 币" % [(h.get("items", []) as Array).size(), int(h.get("value", 0)), int(h.get("balance", 0))] if extracted else ""])
	if m.history.is_empty():
		log.append_text("[color=#8b93a1]还没有打过[/color]")
	log.fit_content = true     # 抽屉自己滚，日志按内容撑高
	right.add_child(log)

	# 图鉴页、成就页（091）
	# 164：中列的页都垫一块粗布（浅底墨字）—— 直接写在背景上，炉火那块亮处看不清
	for pair in [["codex", _build_codex], ["achievements", _build_achievements], ["sell", _build_sell], ["tech", _build_tech]]:
		var cloth := _cloth()
		(pair[1] as Callable).call(cloth)     # 110：科技页（仓库扩建）与上交
		_pages[pair[0]] = cloth
	# 139：抽屉盖在右半边上（后加 = 画在上面），贴右缘、标题行下面
	_drawer.wrap_contents()
	add_child(_drawer)
	_drawer.dock(MARGIN + SHELF_HEAD + 8.0, MARGIN)
	add_child(_drag)     # 164：整屏一层拖拽，盖在三列上（残影画在最上面）
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(layout)
	show_tab(String(payload.get("tab", "home")))
	_refresh()
	_refresh_shelf_title()
	layout()


#region 三列与仓库的大小（164）
## 中列一页的底：一块粗布，占满中列
func _cloth() -> PanelContainer:
	var cloth := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_BOX)
	cloth.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cloth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle.add_child(cloth)
	return cloth



## 按屏幕大小排：右半边占屏宽一半，仓库格子按右半边的宽高取小（40 ～ 80）；带回来的背包与右边同一个格子大小（中列放不下再缩）
func layout() -> void:
	if _right == null:
		return
	var screen := size if size.x > 0.0 and size.y > 0.0 else (get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080))
	# 科技页（树 + 说明板 + 上交区）最窄要多宽先让给它；别的页按中列宽自己排（图鉴按宽算列数，不能拿它的最小宽来挤）
	var mid_min: float = (_pages["tech"] as Control).get_combined_minimum_size().x if _tab == "tech" and _pages.has("tech") else 0.0
	var half := maxf(0.0, minf(screen.x * 0.5 - MARGIN, screen.x - 2.0 * MARGIN - LEFT_W - 2.0 * COL_GAP - mid_min))
	_right.custom_minimum_size.x = half
	var frame := _frame_margins()
	var c := _shelf.fit(half - frame.x, screen.y - 2.0 * MARGIN - SHELF_HEAD - 8.0 - frame.y)
	var mid_w := screen.x - 2.0 * MARGIN - LEFT_W - half - 2.0 * COL_GAP
	if _wh != null and flow.meta.board != null:
		_wh.set_board_cell(minf(c, maxf(WarehousePages.CELL_MIN, floorf((mid_w - 50.0) / float(maxi(1, flow.meta.board.size.x))))))


## 木架框的左右、上下内边距之和
func _frame_margins() -> Vector2:
	var box := _shelf_frame.get_theme_stylebox("panel") if _shelf_frame != null else null
	if box == null:
		return Vector2.ZERO
	return Vector2(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT), box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))


## 右半边的仓库（测试看）
func shelf() -> WarehousePages:
	return _shelf


func drag_layer() -> DragLayer:
	return _drag


func _refresh_shelf_title() -> void:
	if _shelf_title != null:
		_shelf_title.text = "仓库　%d 件　%d 页" % [flow.meta.warehouse.item_count(), flow.meta.warehouse.page_count()]


## 双击右边仓库的一件：按当前页 —— 家 → 置入带回来的背包；出售 → 卖；科技 → 上交；图鉴 / 成就 → 不做事
func _on_shelf_double_clicked(view: ContainerView, uid: int) -> void:
	match _tab:
		"home":
			_wh.quick_move(view, uid)
		"sell":
			sell(uid)
		"tech":
			if _tech != null:
				_tech.submit(uid)
#endregion


#region 调试台（139）
## 150 补 2：调试模式开关（存盘）
func toggle_debug_mode() -> bool:
	flow.settings.debug_mode = not flow.settings.debug_mode
	flow.save_settings()
	if _debug_btn != null:
		_debug_btn.text = _debug_text()
	return flow.settings.debug_mode


func _debug_text() -> String:
	return "调试模式：%s（地图上的事件日志）" % ("开" if flow.settings.debug_mode else "关")


func dev_drawer() -> DevDrawer:
	return _drawer


## 点箭头：开 / 关。返回开着没
func toggle_dev_drawer() -> bool:
	return _drawer.toggle() if _drawer != null else false
#endregion


#region 科技（110）
var _tech = null


func _build_tech(root: Control) -> Control:
	_tech = TechPanelScript.new()
	_tech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tech.setup(flow, font, _drag)
	_tech.changed.connect(_refresh)
	root.add_child(_tech)
	return _tech


## 科技页（测试看）
func tech_panel():
	return _tech
#endregion


#region 出售（091，作者定：基地内商店）
## 「白色 / 绿色及以下 / … / 全部」→ 稀有度上限（-1 = 全部）
const SELL_FILTERS := [["白色", 0], ["绿色及以下", 1], ["蓝色及以下", 2], ["紫色及以下", 3], ["金色及以下", 4], ["全部", -1]]
var _sell_filter: int = 0
var _sell_pick: OptionButton = null
var _sell_preview: Label = null
var _sell_line: Label = null


## 基地商店：卖掉仓库里的东西 —— 双击右边仓库的一件卖一件（164：这一页不再自己画仓库），或按稀有度一键卖。得的钱进局外的钱（作者：暂无出售效果，先攒着）
func _build_sell(root: Control) -> Control:
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	page.add_child(_wrapped("出售　双击右边仓库里的一件卖掉；或选一档稀有度一键卖。回定价的 %d%%，钱进局外（现在还没处花）" % int(round(flow.sell_ratio() * 100)), 15, UiPalette.DIM, 460))
	var row := _hbox(10)
	page.add_child(row)
	row.add_child(_label("一键出售", 13, UiPalette.DIM))
	_sell_pick = OptionButton.new()
	for i in SELL_FILTERS.size():
		_sell_pick.add_item(String(SELL_FILTERS[i][0]), i)
	_sell_pick.item_selected.connect(set_sell_filter)
	row.add_child(_sell_pick)
	_sell_preview = _label("", 13, UiPalette.FG)
	row.add_child(_sell_preview)
	row.add_child(_button("一键出售", func(): sell_filtered(), 13, UiPalette.Tier.PRIMARY))
	_sell_line = _label("", 13, UiPalette.STAMINA)
	page.add_child(_sell_line)
	flow.meta.warehouse.changed.connect(_refresh_sell)
	set_sell_filter(0)
	return page


## 选一档（SELL_FILTERS 的下标）
func set_sell_filter(i: int) -> void:
	_sell_filter = clampi(i, 0, SELL_FILTERS.size() - 1)
	if _sell_pick != null:
		_sell_pick.select(_sell_filter)
	_refresh_sell()


func sell_filter_max() -> int:
	return int(SELL_FILTERS[_sell_filter][1])


## 卖掉仓库里的一件；返回得了多少（没这件 -1）
func sell(uid: int) -> int:
	var inst := flow.meta.warehouse.get_item(uid)
	var name := Names.of(inst.def) if inst != null else ""
	var got := flow.sell_item(uid)
	if got >= 0 and _sell_line != null:
		_sell_line.text = "卖掉「%s」，得 %d 币；现在有 %d 币" % [name, got, flow.meta.funds]
	return got


## 按当前那一档一键卖；返回 {"count", "funds"}
func sell_filtered() -> Dictionary:
	var got := flow.sell_where(sell_filter_max())
	if _sell_line != null:
		_sell_line.text = "卖掉 %d 件，得 %d 币；现在有 %d 币" % [int(got["count"]), int(got["funds"]), flow.meta.funds] if int(got["count"]) > 0 else "这一档没有可卖的"
	return got


func sell_preview_text() -> String:
	return _sell_preview.text if _sell_preview != null else ""


func _refresh_sell() -> void:
	if _sell_preview == null:
		return
	var p := flow.meta.sell_preview(sell_filter_max(), flow.sell_ratio())
	_sell_preview.text = "会卖 %d 件，得 %d 币" % [int(p["count"]), int(p["funds"])]
#endregion


#region 成就页（091，作者定）
## 成就页：每枚一行 —— 名字、解锁途径、进度、完成给什么；「全部 / 已解锁 / 未解锁」切
func _build_achievements(root: Control) -> Control:
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var head := _hbox(8)
	page.add_child(head)
	head.add_child(_label("成就　完成了给解锁（道具 / 地图 / 难度）；途径写在每一条上", 15, UiPalette.DIM))
	for pair in [["all", "全部"], ["done", "已解锁"], ["todo", "未解锁"]]:
		var key: String = pair[0]
		var b := _button(pair[1], func(): show_achievement_filter(key), 13, UiPalette.Tier.MINOR)
		b.toggle_mode = true
		_ach_filter_btns[key] = b
		head.add_child(b)
	_ach_hint = _label("", 12, UiPalette.STAMINA)
	page.add_child(_ach_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 300
	page.add_child(scroll)
	_ach_list = _vbox(8)
	_ach_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ach_list)
	show_achievement_filter("all")
	return page


## 切「全部 / 已解锁 / 未解锁」（"all" / "done" / "todo"）并重列
func show_achievement_filter(key: String) -> void:
	if not _ach_filter_btns.has(key):
		key = "all"
	_ach_filter = key
	for k in _ach_filter_btns:
		(_ach_filter_btns[k] as Button).set_pressed_no_signal(k == key)
	_fill_achievements()


func achievement_filter() -> String:
	return _ach_filter


## 现在列着的：[{id, done}]（测试看）
func achievement_rows() -> Array:
	return _ach_rows.duplicate()


func _fill_achievements() -> void:
	if _ach_list == null:
		return
	UiTheme.clear_children(_ach_list)
	_ach_rows.clear()
	var m := flow.meta
	var total := flow.achievement_defs.size()
	var done_n := 0
	for def in flow.achievement_defs:
		if m.has_achievement(def.id):
			done_n += 1
	if _ach_hint != null:
		_ach_hint.text = ("全部解锁开着：成就不计　" if flow.settings != null and flow.settings.unlock_all else "") + "完成 %d / %d" % [done_n, total]
	if total == 0:
		_ach_list.add_child(_label("（没有成就的内容：data/authoring/achievements/）", 12, UiPalette.DIM))
		return
	for def in flow.achievement_defs:
		var done := m.has_achievement(def.id)
		if _ach_filter == "done" and not done or _ach_filter == "todo" and done:
			continue
		_ach_rows.append({"id": def.id, "done": done})
		_ach_list.add_child(_achievement_row(def, done))
	if _ach_rows.is_empty():
		_ach_list.add_child(_label("（这一栏空着）", 12, UiPalette.DIM))


func _achievement_row(def: AchievementDef, done: bool) -> Control:
	var m := flow.meta
	var panel := _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _vbox(4)
	panel.add_child(col)
	var secret := def.hidden and not done
	var head := _hbox(12)
	col.add_child(head)
	head.add_child(_label(("？？？" if secret else Names.of(def)), 16, UiPalette.HEAL if done else UiPalette.FG))
	var status := ""
	if done:
		var t := m.achievement_time(def.id)
		status = "✓ 已完成" + ("　%s" % Time.get_date_string_from_unix_time(t) if t > 0 else "")
	elif secret:
		status = "未完成"
	else:
		status = "未完成　进度 %s" % def.progress_text(m)
	head.add_child(_label(status, 13, UiPalette.HEAL if done else UiPalette.DIM))
	col.add_child(_wrapped("途径：" + ("？？？" if secret else Names.description_of(def)), 13, UiPalette.FG, 700))
	var opens: Array[String] = []
	for g in def.grants:
		opens.append_array(flow.unlock_names(g))
		if flow.unlock_names(g).is_empty():
			opens.append("解锁 %s" % g)
	col.add_child(_wrapped("解锁：" + ("、".join(opens) if not opens.is_empty() else "无（只是一枚徽章）"), 12, UiPalette.DIM, 700))
	return panel
#endregion


## 088 / 089：图鉴页 —— 跟棋盘的格子无关：所有能获得的道具按稀有度排成**缩略图网格**（一行几个按宽度算，139；能上下滚），
## 带出过的亮着（右上角写累计件数），没获得的灰的；停在一格上开悬浮窗看属性。特殊道具另起一段
func _build_codex(root: Control) -> Control:
	var m := flow.meta
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var ids: Array = flow.items.ids(true)     # 091：锁着的也列（灰的，写着怎么解锁）
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da := flow.items.get_def(a)
		var db := flow.items.get_def(b)
		return da.rarity < db.rarity if da.rarity != db.rarity else String(a) < String(b))
	# 095（作者定）：派生的赐福版并进原件那一格（ids() 本来就不列赐福版），格子叠影 + 角标，点开弹异体列表
	var lit_n := 0
	var total_n := 0
	for id in ids:
		for vid in flow.items.variants_of(id):
			total_n += 1
			if m.codex_lit(vid):
				lit_n += 1
	page.add_child(_label("图鉴　带出过的点亮（%d / %d，含赐福版），右上角是累计件数；停在一格上看属性，叠着的格子点开看异体" % [lit_n, total_n], 15, UiPalette.DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED     # 139：按宽度定列数，不横向滚
	scroll.custom_minimum_size.y = 300
	page.add_child(scroll)
	var inner := _vbox(10)
	scroll.add_child(inner)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", CODEX_GAP)
	grid.add_theme_constant_override("v_separation", CODEX_GAP)
	inner.add_child(grid)
	_codex_grids.clear()
	_codex_grids.append(grid)
	_codex_tiles.clear()
	for id in ids:
		var def := flow.items.get_def(id)
		var tile := _codex_tile_for(def)
		grid.add_child(tile)
		_codex_tiles.append(tile)
	# 特殊道具（088）：不进背包、不能生成，拿到过的点亮
	var keeps: Array = flow.items.keepsake_ids()
	if not keeps.is_empty():
		keeps.sort()
		inner.add_child(_label("特殊道具　不占背包，代表一种能力", 14, UiPalette.DIM))
		var kgrid := GridContainer.new()
		kgrid.add_theme_constant_override("h_separation", CODEX_GAP)
		inner.add_child(kgrid)
		_codex_grids.append(kgrid)
		for id in keeps:
			var def := flow.items.get_def(id)
			var tile := CodexTile.new(def, m.has_keepsake(id), 0, font)
			_wire_tile(tile)
			kgrid.add_child(tile)
			_codex_tiles.append(tile)
	_codex_tip = HoverTip.new()
	add_child(_codex_tip)
	fit_codex_to_width(1100.0)     # 进树之前先给个列数，布局好了按真宽度重算
	scroll.resized.connect(func(): fit_codex_to_width(scroll.size.x))
	return page


## 139：图鉴一行放几个 —— 让缩略图占满 [param width]（扣掉竖滚动条），至少一个
static func codex_columns_for(width: float) -> int:
	return maxi(1, floori((width - 14.0 + CODEX_GAP) / (CodexTile.SIZE.x + CODEX_GAP)))


func fit_codex_to_width(width: float) -> void:
	var cols := codex_columns_for(width)
	for g in _codex_grids:
		g.columns = cols


func codex_columns() -> int:
	return _codex_grids[0].columns if not _codex_grids.is_empty() else 0


## 095：一件（含它的异体）的格子：原件在前、各神的赐福版按 id 排；任一点亮格子就亮
func _codex_tile_for(def: ItemDef) -> CodexTile:
	var m := flow.meta
	var variants: Array[ItemDef] = [def]
	for vid in flow.items.variants_of(def.id):
		if vid != def.id:
			variants.append(flow.items.get_def(vid))
	var any_lit := false
	var tile := CodexTile.new(def, m.codex_lit(def.id), m.codex_count(def.id), font)
	for v in variants:
		var on := m.codex_lit(v.id)
		any_lit = any_lit or on
		tile.variant_lit.append(on)
		tile.variant_counts.append(m.codex_count(v.id))
	tile.variants = variants
	tile.lit = any_lit
	_wire_tile(tile)
	tile.pressed.connect(func(t: CodexTile): show_variants(t))
	return tile


## 图鉴格的悬浮接线：停上去显示说明、离开就藏
func _wire_tile(tile: CodexTile) -> void:
	tile.hovered.connect(_on_tile_hovered)
	tile.unhovered.connect(func(_t: CodexTile): _codex_tip.hide_tip())


## 095：点开一格：有异体就弹出列表（原件、蛮神版、日神版……各一小格，点亮的亮着），再点关闭 / 别处关掉
func show_variants(tile: CodexTile) -> void:
	close_variants()
	if tile == null or tile.variant_count() == 0:
		return
	var box := _panel(10)
	box.name = "VariantsPopup"
	var col := _vbox(6)
	box.add_child(col)
	col.add_child(_label("%s　的异体（%d / %d 点亮）" % [Names.of(tile.def), tile.variants_lit(), tile.variants.size()], 14, UiPalette.FG))
	var row := _hbox(8)
	col.add_child(row)
	_variant_tiles.clear()
	for i in tile.variants.size():
		var v: ItemDef = tile.variants[i]
		var vt := CodexTile.new(v, tile.variant_lit[i] if i < tile.variant_lit.size() else false, tile.variant_counts[i] if i < tile.variant_counts.size() else 0, font)
		_wire_tile(vt)
		var cell := _vbox(2)
		cell.add_child(_label(_variant_kind(v), 11, UiPalette.DIM))
		cell.add_child(vt)
		row.add_child(cell)
		_variant_tiles.append(vt)
	col.add_child(_button("关闭", close_variants, 12, UiPalette.Tier.MINOR))
	add_child(box)
	box.position = (tile.global_position + Vector2(0, tile.size.y + 6)).clamp(Vector2.ZERO, get_viewport_rect().size - Vector2(400, 200))
	_variants_popup = box


func close_variants() -> void:
	if _variants_popup != null:
		_variants_popup.queue_free()
		_variants_popup = null
	_variant_tiles.clear()


func variants_open() -> bool:
	return _variants_popup != null


func variant_tiles() -> Array[CodexTile]:
	return _variant_tiles


## 「原件」/「蛮神版」……
func _variant_kind(def: ItemDef) -> String:
	if def == null or not def.is_blessed():
		return "原件"
	var fid := FaithTags.id_of_tag(def.faith_tag())
	var fd: FaithDef = flow.faith_defs.get(fid, null) if flow.faith_defs != null else null
	return "%s版" % (Names.of(fd) if fd != null else String(fid))


## 停在一格上：点亮的开完整的道具说明；没获得的只写名字与「未获得」
func _on_tile_hovered(tile: CodexTile) -> void:
	if _codex_tip == null or tile.def == null:
		return
	var at := tile.global_position + Vector2(tile.size.x, 0)
	if tile.lit:
		var full := ItemTooltip.describe_full(ItemInstance.create(tile.def, 0))
		_codex_tip.show_text(String(full["text"]), at, null, full["terms"])
	elif tile.def.requires_unlock != &"" and not flow.unlocked(tile.def.requires_unlock):
		# 091：锁着的写怎么解锁（哪一枚成就）
		var ach := flow.achievement_granting(tile.def.requires_unlock)
		var how := "完成成就「%s」：%s" % [Names.of(ach), Names.description_of(ach)] if ach != null else "解锁 %s" % tile.def.requires_unlock
		_codex_tip.show_text("[b]%s[/b]\n[color=#8b93a1]未解锁：%s[/color]" % [Names.of(tile.def), how], at)
	else:
		_codex_tip.show_text("[b]%s[/b]\n[color=#8b93a1]未获得：撤离成功时背包里的会点亮[/color]" % Names.of(tile.def), at)


func codex_tiles() -> Array[CodexTile]:
	return _codex_tiles


## 切页："home"（家，默认）/ "codex" / "achievements" / "sell" / "tech"。老名字 "warehouse" 算家（164 之前仓库是一页）
func show_tab(name: String) -> void:
	if name == "warehouse" or not _pages.has(name):
		name = "home"
	_tab = name
	for key in _pages:
		(_pages[key] as Control).visible = key == name
	for key in _tab_btns:
		var b := _tab_btns[key] as Button
		b.set_pressed_no_signal(key == name)
	layout.call_deferred()     # 中列换了页，最窄宽度可能变了
	if _tab_mark != null:
		if _tab_mark.get_parent() != null:
			_tab_mark.get_parent().remove_child(_tab_mark)
		if _tab_btns.has(name):
			(_tab_btns[name] as Button).add_child(_tab_mark)


## 164：点左列一个页签 —— 已经选着它就回家，否则切过去
func toggle_tab(key: String) -> void:
	show_tab("home" if _tab == key else key)


func tab() -> String:
	return _tab


## 090：Esc = 返回上一级 —— 在别的页先回家，家里再回主菜单
func escape() -> bool:
	if _tab != "home":
		show_tab("home")
		return true
	flow.to_main_menu()
	return true


func toggle_buff(id: StringName) -> bool:
	var on := flow.toggle_meta_buff(id)
	if _buff_btns.has(id):
		(_buff_btns[id] as Button).set_pressed_no_signal(on)
	return on


## 119 开发区：改某个科技的级数（数字框与测试都走它）。返回实际的级数（夹在 0 ～ 满级）
func set_tech_level(id: StringName, level: int) -> int:
	var lv := flow.dev_set_tech_level(id, level)
	if _tech_spins.has(id):
		(_tech_spins[id] as SpinBox).set_value_no_signal(lv)
	return lv


## 开发区的科技等级数字框（测试看）；导出包里没有，返回 null
func tech_level_spin(id: StringName) -> SpinBox:
	return _tech_spins.get(id, null)


func toggle_unlock(id: StringName) -> bool:
	var on := flow.toggle_unlock(id)
	if _unlock_btns.has(id):
		(_unlock_btns[id] as Button).set_pressed_no_signal(on)
	return on


func _refresh() -> void:
	# 090：带回来的没清不再拦，只提示（开局屏里到地上，出发就没了）
	_hint.text = flow.pending_hint()
	for id in _tech_spins:     # 119：科技页点亮 / 升级了，开发区的数字框跟上
		(_tech_spins[id] as SpinBox).set_value_no_signal(TechService.level(flow.meta, id))

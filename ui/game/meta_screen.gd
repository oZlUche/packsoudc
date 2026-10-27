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
const MarketPanelScript := preload("res://ui/game/market_panel.gd")     # 251
const SmithyPanelScript := preload("res://ui/game/smithy_panel.gd")     # 251
## 图鉴缩略图之间的空隙；一行几个按宽度算（139）
const CODEX_GAP := 8
## 左列宽、整屏外边距、三列之间的空
const LEFT_W := 220.0
const MARGIN := 24.0
const COL_GAP := 24.0
## 右半边标题行的高（「仓库　N 件」与调试台箭头）
const SHELF_HEAD := 44.0
## 仓库分页签（挂牌）多高，同开局屏第二页
const SHELF_TAB_H := 60.0
## 基地页签字左边的图标（`home/tabs/tab_<页签名>`，36 × 36 墨色剪影；没图就只有字）
const TAB_ICON_ART := "home/tabs/tab_"
## 左列五个页签（页签名、字）；「家」不在里面 —— 再点一次选中的页签回家。
## 178（作者 2026-10-16，待定 1 选 A）：加「仓库」，顺序 仓库 / 出售 / 科技 / 图鉴 / 成就 —— 右半边有仓库的三页挨着
## 251：集市、铁匠铺（科技点出来才露页签，[member FACILITY_TABS]）排在出售后面 —— 右半边都有仓库
const TABS := [["warehouse", "meta.tab_warehouse"], ["sell", "meta.tab_sell"], ["market", "meta.tab_market"], ["smithy", "meta.tab_smithy"], ["tech", "meta.tab_tech"], ["shelf", "meta.tab_shelf"]]
## 178：这几页不显示右半边的仓库，中列吃满
const NO_SHELF_TABS := ["shelf", "tech"]     # 229：科技页也收起右半边
## 261（作者 14:13）：「图鉴」页签改「书架」—— 两层三格，前四格点开各一扇窗（图鉴 / 对局记录 / 特殊道具 / 成就，成就页签并进来），后两格空着摆静物
const SHELF_CELLS := ["codex", "records", "keepsakes", "achievements", "", ""]
const SHELF_CELL := Vector2(400, 400)
const SHELF_GAP := 24
const SHELF_WIN := Vector2(1100, 820)
## 书架格里画的东西（`home/shelf/<格>`，UI替换美术 出图前用页签剪影放大）
const SHELF_ART := "home/shelf/"
const SHELF_ICON := 160.0
## 251 补充二 §12.1（作者 10-25 14:20「集市里不需要显示仓库，铁匠铺里也不需要」）：整页的两页 —— 右列（仓库木架 + 挂牌）收起、中列吃满。
## 只是藏：仓库视图照旧在，买下 / 打好的照样进仓库
const FULL_TABS := ["market", "smithy"]
## 251：页签 → 哪一间铺子（0 级不露页签）
const FACILITY_TABS := {"market": Market.ID, "smithy": Smithy.ID}

var _wh = null
## 260：家页的军功碑
var _stele: RecordsStele = null
var _new_run_btn: Button
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
## 261：书架格 → 格上的小牌（按钮）；窗（压暗层）；开着的那扇
var _shelf_btns: Dictionary = {}
var _shelf_windows: Dictionary = {}
var _shelf_open: String = ""
var _records: RunRecordsWindow = null
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
var _ach_warn: HeaderTag = null
var _ach_rows: Array = []
## 139：调试台抽屉
var _drawer: DevDrawer = null
var _debug_btn: Button = null
var _codex_grids: Array[GridContainer] = []
## 164：三列与右半边的仓库（整屏的拖拽层是 [member GameScreen._drag]）
var _cols: HBoxContainer = null
var _margin: MarginContainer = null
var _middle: VBoxContainer = null
var _right: VBoxContainer = null
var _shelf: WarehousePages = null
var _shelf_frame: PanelContainer = null
var _shelf_title: HeaderTag = null
## 178：「仓库」页没有带回来的棋盘时那一行


func open(payload: Dictionary) -> void:
	var m := flow.meta
	flow.ensure_market()     # 251：有集市却没货（老档、开发区改了级数）先上一次
	UiTheme.dress_home_backdrop(_backdrop())
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, int(MARGIN))
	add_child(_margin)
	_cols = _hbox(int(COL_GAP))
	_margin.add_child(_cols)
	_drag = DragLayer.new()
	_drag.label_font = font

	# 左列：标题、五个页签竖排；底下「再来一局」「回主菜单」
	var left := _vbox(12)
	left.custom_minimum_size.x = LEFT_W
	_cols.add_child(left)
	# 226 批二：「基地」二字删了（页签已说明在哪）
	for pair in TABS:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(UiText.t(pair[1]), func(): toggle_tab(key))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(LEFT_W * 0.8, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var icon := UiTheme.art_cached(TAB_ICON_ART + key)     # 作者 2026-10-24 选乙 平墨图标：字左边一枚墨色小图
		if icon == null and key == "shelf":
			icon = UiTheme.art_cached(TAB_ICON_ART + "codex")     # 261：书架剪影没到前先用图鉴那枚
		if icon != null:
			b.icon = icon
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_tab_btns[key] = b
		left.add_child(b)
	var tab_w := LEFT_W * 0.8     # 英文「Achievements」加了图标放不下：七个页签一样宽，取最宽的那个
	for key in _tab_btns:
		tab_w = maxf(tab_w, (_tab_btns[key] as Button).get_combined_minimum_size().x)
	for key in _tab_btns:
		(_tab_btns[key] as Button).custom_minimum_size.x = tab_w
	var tex := UiTheme.art(UiTheme.ART_TAB_MARK)
	if tex != null:
		_tab_mark = TextureRect.new()
		_tab_mark.texture = tex
		_tab_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tab_mark.position = Vector2(-10, -14)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	# 226 批二：左下「带回来的背包还有 N 件……」那句删了（[method pending_text] 留给「仓库」页签的悬浮窗）
	_new_run_btn = UiTheme.make_home_button(UiText.t("meta.new_run"), flow.new_run, true)
	_new_run_btn.custom_minimum_size = Vector2(LEFT_W, 76)
	left.add_child(_new_run_btn)
	var menu_btn := UiTheme.make_home_button(UiText.t("setup.main_menu"), flow.to_main_menu)
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
	_shelf_title = HeaderTag.hanging(UiText.t("meta.tab_warehouse"))     # 226 批三：木架顶一块挂牌只写「仓库」，件数与页数进它的悬浮窗（每页件数页签上有）
	_shelf_title.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_shelf_title)
	if DevGate.on():     # 186：调试台只在开发包里有
		_drawer = DevDrawer.new()
		# 178：箭头钉在屏幕右上（原来在仓库标题行的右端，同一个位置）—— 图鉴 / 成就页收起右半边时它还在
		var arrow_w := _drawer.arrow.get_combined_minimum_size().x
		_drawer.arrow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_drawer.arrow.offset_left = -MARGIN - arrow_w
		_drawer.arrow.offset_right = -MARGIN
		_drawer.arrow.offset_top = MARGIN
		_drawer.arrow.offset_bottom = MARGIN + SHELF_HEAD
	_shelf_frame = UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_SHELF)
	_shelf_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_right.add_child(_shelf_frame)
	_shelf = WarehousePages.new()
	_shelf.tab_variation = UiTheme.BUTTON_SETUP_TAB     # 乙 石刻：分页签同开局、结算那款挂牌木签
	_shelf.tab_height = SHELF_TAB_H
	_shelf_frame.add_child(_shelf)
	_shelf.setup(m.warehouse, font, _drag, TechWarehousePages.plan_of(flow.tech_defs))
	_drag.register_view(_shelf.view)
	_shelf.view.item_double_clicked.connect(_on_shelf_double_clicked)
	_shelf.view.actions_for = func(uid: int) -> Array: return _wh.warehouse_actions(uid, _tab == "warehouse") if _wh != null else []     # 230
	m.warehouse.changed.connect(_refresh_shelf_title)

	# 家页：这一局、战绩（粗布框里）。178：带回来的背包搬到「仓库」页
	var home := _vbox(12)
	home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.add_child(home)
	_pages["home"] = home
	# 260（作者 14:13 选 B 军功碑，「最后对局不再显示」）：家页只立一座碑；碑顶山墙上沿在设计坐标 y 52
	var stele_gap := Control.new()
	stele_gap.custom_minimum_size.y = 16.0     # 家页 vbox 间距 12：24 + 16 + 12 = 52
	home.add_child(stele_gap)
	_stele = RecordsStele.new()
	_stele.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home.add_child(_stele)
	_stele.setup(flow)
	# 178：「仓库」页 —— 带回来的背包（一键置入 / 整理 / 提示行）；没有带回来的就一行字（整理照旧管右边当前页）
	var wh_page := _cloth()
	_pages["warehouse"] = wh_page
	var wh_col := _vbox(10)
	wh_page.add_child(wh_col)
	# 226 批二：空态「没有带回来的东西」删了
	_wh = WarehousePanelScript.new()
	_wh.sell_one = sell
	_wh.setup(flow, font, _shelf, _drag)
	_wh.changed.connect(_refresh)
	wh_col.add_child(_wh)

	if _drawer != null:
		_build_dev_drawer(m)

	# 图鉴页、成就页（091）
	# 164：中列的页都垫一块粗布（浅底墨字）—— 直接写在背景上，炉火那块亮处看不清
	for pair in [["shelf", _build_shelf], ["sell", _build_sell], ["market", _build_market], ["smithy", _build_smithy], ["tech", _build_tech]]:
		var cloth := _cloth()
		(pair[1] as Callable).call(cloth)     # 110：科技页（仓库扩建）与上交
		_pages[pair[0]] = cloth
	# 139：抽屉盖在右半边上（后加 = 画在上面），贴右缘、标题行下面
	if _drawer != null:
		_drawer.wrap_contents()
		add_child(_drawer)
		_drawer.dock(MARGIN + SHELF_HEAD + 8.0, MARGIN)
		add_child(_drawer.arrow)
	add_child(_drag)     # 164：整屏一层拖拽，盖在三列上（残影画在最上面）
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shelf_windows()     # 261：书架的四扇窗盖在最上面，先藏着
	resized.connect(layout)
	show_tab(String(payload.get("tab", initial_tab(payload))))
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
	# 229：科技页也收起右半边，中列的页都按中列宽自己排（图鉴按宽算列数），右半边只按半屏算
	var half := maxf(0.0, minf(screen.x * 0.5 - MARGIN, screen.x - 2.0 * MARGIN - LEFT_W - 2.0 * COL_GAP))
	var frame := _frame_margins()
	var c := _shelf.fit(half - frame.x, screen.y - 2.0 * MARGIN - SHELF_HEAD - 8.0 - frame.y)     # 收起时也按半屏算，切回来格子不变
	if not _right.visible:
		half = 0.0     # 178：图鉴 / 成就页（229：科技页）收起右半边，中列吃满
	_right.custom_minimum_size.x = half
	_margin.add_theme_constant_override("margin_right", int(MARGIN + right_gutter()))
	var mid_w := middle_width(screen)
	if _wh != null and flow.meta.board != null:
		_wh.set_board_cell(minf(c, maxf(WarehousePages.CELL_MIN, floorf((mid_w - 50.0 - _wh.rack_room() - 2.0 * _wh.BOARD_FRAME_PAD) / float(maxi(CharacterDef.BOARD_MAX_W, flow.meta.board.size.x))))))


## 178：右半边收起时，右边空出调试台箭头那一条（箭头钉在屏幕右上，别压在中列上）
func right_gutter() -> float:
	if _right.visible or _drawer == null:
		return 0.0
	return _drawer.arrow.get_combined_minimum_size().x + 8.0


## 178：中列的宽（右半边收起时 = 全宽减左列、减箭头那一条）
func middle_width(screen: Vector2) -> float:
	if not _right.visible:
		return screen.x - 2.0 * MARGIN - LEFT_W - COL_GAP - right_gutter()
	return screen.x - 2.0 * MARGIN - LEFT_W - _right.custom_minimum_size.x - 2.0 * COL_GAP


## 178（待定 2 选 A）：进基地落哪一页 —— 从结算屏回来、带回来的背包还没清空 → 「仓库」页；否则家
func initial_tab(payload: Dictionary) -> String:
	return "warehouse" if payload.has("result") and flow.meta.has_pending_board() else "home"


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
		_shelf_title.tooltip_text = UiText.t("meta.shelf_title") % [UiText.count(flow.meta.warehouse.item_count(), "unit.item"), UiText.count(flow.meta.warehouse.page_count(), "unit.page")]


## 双击右边仓库的一件：按当前页 —— 仓库 → 置入带回来的背包（178：原来在家页）；出售 → 卖；家 → 不做事（229：科技页收起了仓库，上交走材料行的【交 k】）
func _on_shelf_double_clicked(view: ContainerView, uid: int) -> void:
	match _tab:
		"warehouse":
			_wh.quick_move(view, uid)
		"sell":
			sell(uid)
#endregion


#region 调试台（139）
## 139：调试台（原来仓库页的右列）。186：整个是开发物 —— 只在开发包里造（[DevGate]）
func _build_dev_drawer(m: MetaState) -> void:
	var right := _drawer.content
	# 150 补 2：头部写着现在的调试模式，点一下切（和设置页那个勾选是同一个开关）
	_debug_btn = _button("", toggle_debug_mode, 13, UiPalette.Tier.MINOR)
	_debug_btn.text = _debug_text()
	right.add_child(_debug_btn)
	# 开发开关：只在开发包显示（200：DevGate，开发版导出也有）。科技给的局外 buff 由「科技」页的等级决定（写进 tech_buffs），不在这里重复开关
	if DevGate.on():
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
		right.add_child(_label("开发：局外解锁开关", 15, UiPalette.DIM))
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
	# 119：开发区手改进度表（存档的 tech_levels）—— 每个科技一个数字框，玩家版里没有
	if DevGate.on() and not flow.tech_defs.is_empty():
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
		log.append_text("[color=#%s]%s[/color]　走了 %d 步　打赢 %d　%s\n" % [
			(UiPalette.HEAL if extracted else UiPalette.HP).to_html(false), "撤离" if extracted else "战败",
			int(h.get("steps", 0)), int(h.get("battles_won", 0)),
			"%d 件、值 %d 币、带出 %d 币" % [(h.get("items", []) as Array).size(), int(h.get("value", 0)), int(h.get("balance", 0))] if extracted else ""])
	if m.history.is_empty():
		log.append_text("[color=#8b93a1]还没有打过[/color]")
	log.fit_content = true     # 抽屉自己滚，日志按内容撑高
	right.add_child(log)


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
	_tech.setup(flow, font)
	_tech.changed.connect(_refresh)
	root.add_child(_tech)
	return _tech


## 科技页（测试看）
func tech_panel():
	return _tech
#endregion


#region 集市、铁匠铺（251）
var _market = null
var _smithy = null


func _build_market(root: Control) -> Control:
	_market = MarketPanelScript.new()
	_market.setup(flow, font, say)
	_market.changed.connect(_refresh)
	root.add_child(_market)
	return _market


func _build_smithy(root: Control) -> Control:
	_smithy = SmithyPanelScript.new()
	_smithy.setup(flow, font, say)
	_smithy.changed.connect(_refresh)
	root.add_child(_smithy)
	return _smithy


## 测试看
func market_panel():
	return _market


func smithy_panel():
	return _smithy


## 铺子 0 级不露页签；正翻着的那间没了就回家
func _sync_facility_tabs() -> void:
	for key in FACILITY_TABS:
		var b := _tab_btns.get(key, null) as Button
		if b == null:
			continue
		b.visible = flow.meta.facility_level(FACILITY_TABS[key]) > 0
		if not b.visible and _tab == key:
			show_tab("home")
#endregion


#region 出售（091，作者定：基地内商店）
## 「白色 / 绿色及以下 / … / 全部」→ 稀有度上限（-1 = 全部）
const SELL_FILTERS := [["meta.sell_white", 0], ["meta.sell_green", 1], ["meta.sell_blue", 2], ["meta.sell_purple", 3], ["meta.sell_gold", 4], ["meta.all", -1]]
## 乙 石刻：「一键出售」主档木牌两行字、成就筛选木牌的字号
const SELL_BTN_FONT := 20
const ACH_FILTER_FONT := 16
var _sell_filter: int = 0
var _sell_pick: OptionButton = null
## 177 补 1.2：标签下拉（单选，待定补 1 选 A；&"" = 不限标签）
var _sell_tag: StringName = &""
var _sell_tag_pick: OptionButton = null
var _sell_btn: Button = null
var _sell_preview := ""
## 225：出售页的包架（双击卖一只）
var _sell_rack: Control = null


## 基地商店：卖掉仓库里的东西 —— 双击右边仓库的一件卖一件（164：这一页不再自己画仓库），或按稀有度一键卖。得的钱进局外的钱（作者：暂无出售效果，先攒着）
func _build_sell(root: Control) -> Control:
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var row := HFlowContainer.new()     # 游戏测试 v3.84：一行排不下时折行，不把中列撑宽、把右边仓库挤出屏
	page.add_child(row)
	_sell_pick = OptionButton.new()
	for i in SELL_FILTERS.size():
		_sell_pick.add_item(UiText.t(String(SELL_FILTERS[i][0])), i)
	_sell_pick.item_selected.connect(set_sell_filter)
	UiTheme.dress_wood_option(_sell_pick)     # 乙 石刻：木牌框 + 箭头 + 浅纸弹出单
	row.add_child(_sell_pick)
	_sell_tag_pick = OptionButton.new()
	_sell_tag_pick.item_selected.connect(func(i: int): set_sell_tag(StringName(String(_sell_tag_pick.get_item_metadata(i)))))
	UiTheme.dress_wood_option(_sell_tag_pick)
	row.add_child(_sell_tag_pick)
	# 美术设计 20:38：一行放不下（两个下拉 + 预览 + 大按钮把中列撑宽，右边仓库被挤出屏幕）—— 预览与按钮另起一行
	var row2 := _hbox(10)
	row2.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(row2)
	var sell_btn := UiTheme.make_home_button(UiText.t("meta.sell_all"), func(): sell_filtered(), true, Vector2.ZERO, SELL_BTN_FONT)     # 乙 石刻：主档木牌
	_sell_btn = sell_btn     # 226 批三：「会卖 N 件，得 N 币」写在按钮第二行
	sell_btn.tooltip_text = UiText.t("meta.sell_intro") % int(round(flow.sell_ratio() * 100))     # 226 批二：说明那段与行首「一键出售」删了，卖价比例进按钮悬浮窗
	row2.add_child(sell_btn)
	# 225：包架也是货源 —— 双击一只卖掉（一键出售不碰包：包是装备不是战利品）
	_sell_rack = BagRackView.boxed(flow.meta.rack, font)
	_sell_rack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(_sell_rack)
	BagRackView.view_in(_sell_rack).item_double_clicked.connect(func(_v: ContainerView, uid: int): sell_bag(uid))
	BagRackView.view_in(_sell_rack).actions_for = func(uid: int) -> Array:     # 230：出售页的包架 = 出售 N 币
		var inst := flow.meta.rack.get_item(uid)
		return [ItemActions.sell(inst, MetaState.sell_price_of(inst, flow.sell_ratio()), sell_bag)] if inst != null else []
	flow.meta.warehouse.changed.connect(_on_sell_stock_changed)
	_rebuild_sell_tags()
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


## 177 补 1.2：选一个标签（&"" = 不限）；仓库里已经没有这个标签的道具就回「不限」
func set_sell_tag(tag: StringName) -> void:
	_sell_tag = tag if flow.meta.sell_tags().has(tag) else &""
	_sync_sell_tag_pick()
	_refresh_sell()


func sell_filter_tag() -> StringName:
	return _sell_tag


## 标签下拉现在列的标签（不含「不限标签」，测试读）
func sell_tag_options() -> Array:
	var out: Array = []
	if _sell_tag_pick == null:
		return out
	for i in _sell_tag_pick.item_count:
		var tag := String(_sell_tag_pick.get_item_metadata(i)) if not _sell_tag_pick.is_item_separator(i) else ""
		if tag != "":
			out.append(StringName(tag))
	return out


## 仓库变了：标签下拉重建，预览重算
func _on_sell_stock_changed() -> void:
	_rebuild_sell_tags()
	_refresh_sell()


## 按仓库里现有的标签重建下拉（按大类分组，组间一条分隔）；选中的没了回「不限」
func _rebuild_sell_tags() -> void:
	if _sell_tag_pick == null:
		return
	var tags := flow.meta.sell_tags()
	if not tags.has(_sell_tag):
		_sell_tag = &""
	_sell_tag_pick.clear()
	_sell_tag_pick.add_item(UiText.t("meta.sell_any_tag"))
	_sell_tag_pick.set_item_metadata(0, "")
	var last_rank := -1
	for t in tags:
		var rank := TagRegistry.category_rank(t)
		if last_rank >= 0 and rank != last_rank:
			_sell_tag_pick.add_separator()
		last_rank = rank
		_sell_tag_pick.add_item(Glossary.tag_name(t))
		_sell_tag_pick.set_item_metadata(_sell_tag_pick.item_count - 1, String(t))
	_sync_sell_tag_pick()


## 下拉上显示的跟着 [member _sell_tag]
func _sync_sell_tag_pick() -> void:
	if _sell_tag_pick == null:
		return
	for i in _sell_tag_pick.item_count:
		if not _sell_tag_pick.is_item_separator(i) and String(_sell_tag_pick.get_item_metadata(i)) == String(_sell_tag):
			if _sell_tag_pick.selected != i:
				_sell_tag_pick.select(i)
			return


## 卖掉仓库里的一件；返回得了多少（没这件 -1）
func sell(uid: int) -> int:
	var inst := flow.meta.warehouse.get_item(uid)
	var name := Names.of(inst.def) if inst != null else ""
	var got := flow.sell_item(uid)
	if got >= 0:
		say(UiText.t("meta.sold_one") % [name, got, flow.meta.funds])     # 226 批一：卖出回话走告示卷轴
	return got


## 225：卖包架上的一只；返回得了多少（没这只 -1）
func sell_bag(uid: int) -> int:
	var inst := flow.meta.rack.get_item(uid)
	var name := Names.of(inst.def) if inst != null else ""
	var got := flow.sell_bag(uid)
	if got >= 0:
		say(UiText.t("meta.sold_one") % [name, got, flow.meta.funds])
	return got


## 225：出售页的包架视图（测试看）
func sell_rack_view() -> BagRackView:
	return BagRackView.view_in(_sell_rack) if _sell_rack != null else null


## 按当前那一档一键卖；返回 {"count", "funds"}
func sell_filtered() -> Dictionary:
	var got := flow.sell_where(sell_filter_max(), _sell_tag)
	var text := UiText.t("meta.sold_many") % [int(got["count"]), int(got["funds"]), flow.meta.funds] if int(got["count"]) > 0 else UiText.t("meta.nothing_to_sell")
	var skipped := flow.meta.locked_matching(sell_filter_max(), _sell_tag)
	if skipped > 0:
		text += UiText.t("meta.sell_skipped") % skipped     # 230
	say(text)
	return got


func sell_preview_text() -> String:
	return _sell_preview


func _refresh_sell() -> void:
	if _sell_btn == null:
		return
	var p := flow.meta.sell_preview(sell_filter_max(), flow.sell_ratio(), _sell_tag)
	_sell_preview = UiText.t("meta.sell_preview") % [int(p["count"]), int(p["funds"])]
	_sell_btn.text = UiText.t("meta.sell_all") + "\n" + _sell_preview
#endregion


#region 成就页（091，作者定）
## 成就页：每枚一行 —— 名字、解锁途径、进度、完成给什么；「全部 / 已解锁 / 未解锁」切
func _build_achievements(root: Control) -> Control:
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var head := _hbox(8)
	page.add_child(head)
	for pair in [["all", "meta.all"], ["done", "meta.ach_filter_done"], ["todo", "meta.ach_filter_todo"]]:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(UiText.t(pair[1]), func(): show_achievement_filter(key), false, Vector2.ZERO, ACH_FILTER_FONT)     # 乙 石刻：木牌，选中 = 按下的那块
		b.toggle_mode = true
		_ach_filter_btns[key] = b
		head.add_child(b)
	_ach_warn = HeaderTag.new(UiText.t("meta.ach_unlock_all_on"))     # 226 批三：「全部解锁开着」改一枚警示签；「完成 N / N」进「全部」钮
	_ach_warn.visible = false
	head.add_child(_ach_warn)
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
	if _ach_warn != null:
		_ach_warn.visible = flow.settings != null and flow.settings.unlock_all
	if _ach_filter_btns.has("all"):
		(_ach_filter_btns["all"] as Button).text = UiText.t("meta.ach_all_count") % [done_n, total]
	if total == 0:
		return     # 226 批二：空态的字删了
	for def in flow.achievement_defs:
		var done := m.has_achievement(def.id)
		if _ach_filter == "done" and not done or _ach_filter == "todo" and done:
			continue
		_ach_rows.append({"id": def.id, "done": done})
		_ach_list.add_child(_achievement_row(def, done))


func _achievement_row(def: AchievementDef, done: bool) -> Control:
	var m := flow.meta
	var panel := _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _vbox(4)
	panel.add_child(col)
	var secret := def.hidden and not done
	var head := _hbox(12)
	col.add_child(head)
	head.add_child(_label((UiText.t("meta.secret") if secret else Names.of(def)), 16, UiPalette.HEAL if done else UiPalette.FG))
	var status := ""
	if done:
		var t := m.achievement_time(def.id)
		status = UiText.t("meta.ach_done") + (UiText.t("meta.ach_done_date") % Time.get_date_string_from_unix_time(t) if t > 0 else "")
	elif secret:
		status = UiText.t("meta.ach_not_done")
	else:
		status = UiText.t("meta.ach_progress") % def.progress_text(m)
	head.add_child(_label(status, 13, UiPalette.HEAL if done else UiPalette.DIM))
	col.add_child(_wrapped(UiText.t("meta.ach_how") % (UiText.t("meta.secret") if secret else Names.description_of(def)), 13, UiPalette.FG, 700))
	var opens: Array[String] = []
	for g in def.grants:
		opens.append_array(flow.unlock_names(g))
		if flow.unlock_names(g).is_empty():
			opens.append(UiText.t("meta.unlock_id") % g)
	col.add_child(_wrapped(UiText.t("meta.ach_grants") % (UiText.t("hud.buff_sep").join(opens) if not opens.is_empty() else UiText.t("meta.ach_badge_only")), 12, UiPalette.DIM, 700))
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
	# 226 批二：说明行（「图鉴　带出过的点亮 N / N……」）删了
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
	_codex_tip = HoverTip.new()
	add_child(_codex_tip)
	fit_codex_to_width(SHELF_WIN.x)     # 进树之前先给个列数，布局好了按真宽度重算
	scroll.resized.connect(func(): fit_codex_to_width(scroll.size.x))
	return page


## 特殊道具（088）：不进背包、不能生成，拿到过的点亮。261：原来在图鉴页底下一段，搬进书架上自己那一格的窗
func _build_keepsakes(root: Control) -> Control:
	var m := flow.meta
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var keeps: Array = flow.items.keepsake_ids()
	keeps.sort()
	var kgrid := UiTheme.grid(codex_columns_for(SHELF_WIN.x), CODEX_GAP)
	page.add_child(kgrid)
	_codex_grids.append(kgrid)
	for id in keeps:
		var def := flow.items.get_def(id)
		var tile := CodexTile.new(def, m.has_keepsake(id), 0, font)
		_wire_tile(tile)
		kgrid.add_child(tile)
		_codex_tiles.append(tile)
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
	tile.mask_name = not flow.names_revealed()     # 作者 10-26：没点亮的写「？」，悬浮窗同样
	_wire_tile(tile)
	tile.pressed.connect(func(t: CodexTile): show_variants(t))
	return tile


## 图鉴格的悬浮接线：停上去显示说明、离开就藏
func _wire_tile(tile: CodexTile) -> void:
	tile.hovered.connect(_on_tile_hovered)
	tile.unhovered.connect(func(_t: CodexTile): _codex_tip.release())


## 095：点开一格：有异体就弹出列表（原件、蛮神版、日神版……各一小格，点亮的亮着），再点关闭 / 别处关掉
func show_variants(tile: CodexTile) -> void:
	close_variants()
	if tile == null or tile.variant_count() == 0:
		return
	var box := _panel(10)
	box.name = "VariantsPopup"
	var col := _vbox(6)
	box.add_child(col)
	col.add_child(_label(UiText.t("meta.variants_title") % [tile.shown_name(), tile.variants_lit(), tile.variants.size()], 14, UiPalette.FG))
	var row := _hbox(8)
	col.add_child(row)
	_variant_tiles.clear()
	for i in tile.variants.size():
		var v: ItemDef = tile.variants[i]
		var vt := CodexTile.new(v, tile.variant_lit[i] if i < tile.variant_lit.size() else false, tile.variant_counts[i] if i < tile.variant_counts.size() else 0, font)
		vt.mask_name = tile.mask_name
		_wire_tile(vt)
		var cell := _vbox(2)
		cell.add_child(_label(_variant_kind(v), 11, UiPalette.DIM))
		cell.add_child(vt)
		row.add_child(cell)
		_variant_tiles.append(vt)
	col.add_child(_button(UiText.t("meta.close"), close_variants, 12, UiPalette.Tier.MINOR))
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
		return UiText.t("meta.variant_base")
	var fid := FaithTags.id_of_tag(def.faith_tag())
	var fd: FaithDef = flow.faith_defs.get(fid, null) if flow.faith_defs != null else null
	return UiText.t("meta.variant_blessed") % (Names.of(fd) if fd != null else String(fid))


## 停在一格上：点亮的开完整的道具说明；没获得的只写名字与「未获得」
func _on_tile_hovered(tile: CodexTile) -> void:
	if _codex_tip == null or tile.def == null:
		return
	var at := tile.global_position + Vector2(tile.size.x, 0)
	if tile.lit:
		var full := ItemTooltip.describe_full(ItemInstance.create(tile.def, 0))
		_codex_tip.show_item(full, at, tile.get_global_rect())     # 作者 10-26：贴着格子摆
	elif tile.def.requires_unlock != &"" and not flow.unlocked(tile.def.requires_unlock):
		# 091：锁着的写怎么解锁（哪一枚成就）
		var ach := flow.achievement_granting(tile.def.requires_unlock)
		var how := UiText.t("meta.codex_how_ach") % [Names.of(ach), Names.description_of(ach)] if ach != null else UiText.t("meta.unlock_id") % tile.def.requires_unlock
		_codex_tip.show_text(UiText.t("meta.codex_locked_tip") % [tile.shown_name(), how], at)
	else:
		_codex_tip.show_text(UiText.t("meta.codex_unseen_tip") % tile.shown_name(), at)


func codex_tiles() -> Array[CodexTile]:
	return _codex_tiles


#region 书架（261）
## 书架页：两层三格；前四格各开一扇窗，后两格空着
func _build_shelf(root: Control) -> Control:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var grid := UiTheme.grid(3, SHELF_GAP)
	center.add_child(grid)
	_shelf_btns.clear()
	for key in SHELF_CELLS:
		grid.add_child(_shelf_cell(key))
	return center


## 一格：木格（占位用仓库那块木架的皮）里一件东西 + 一块小木牌（格名与数）；整格能点
func _shelf_cell(key: String) -> Control:
	var cell := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_SHELF)
	cell.custom_minimum_size = SHELF_CELL
	cell.name = "Shelf_" + (key if key != "" else "empty")
	if key == "":
		return cell
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			open_shelf(key))
	var col := _vbox(16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(col)
	var art := UiTheme.art_cached(SHELF_ART + key)
	if art == null:
		art = UiTheme.art_cached(TAB_ICON_ART + ("achievements" if key == "achievements" else "codex" if key != "records" else "tech"))
	if art != null:
		var pic := TextureRect.new()
		pic.texture = art
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2.ONE * SHELF_ICON
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(pic)
	var plate := UiTheme.make_home_button(shelf_label(key), open_shelf.bind(key))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(plate)
	_shelf_btns[key] = plate
	return cell


## 格上小牌写什么：图鉴 40 / 153、对局记录 N 场、特殊道具 N / N、成就 N / N
func shelf_label(key: String) -> String:
	var m := flow.meta
	match key:
		"codex":
			return UiText.t("shelf.codex") % [m.codex.size(), flow.items.ids(true).size()]
		"records":
			return UiText.t("shelf.records") % m.history.size()
		"keepsakes":
			var keeps: Array = flow.items.keepsake_ids()
			return UiText.t("shelf.keepsakes") % [keeps.filter(func(id): return m.has_keepsake(id)).size(), keeps.size()]
		"achievements":
			var done := 0
			for def in flow.achievement_defs:
				if m.has_achievement(def.id):
					done += 1
			return UiText.t("shelf.achievements") % [done, flow.achievement_defs.size()]
	return ""


func shelf_buttons() -> Dictionary:
	return _shelf_btns


## 四扇窗：压暗的底 + 居中一块石板（1100 × 820），标题 + 右上「关」；内容照原来那几页
func _build_shelf_windows() -> void:
	_shelf_windows.clear()
	for pair in [["codex", _build_codex], ["records", _build_records], ["keepsakes", _build_keepsakes], ["achievements", _build_achievements]]:
		var key: String = pair[0]
		var shade := ColorRect.new()
		shade.name = "ShelfWindow_" + key
		shade.color = Color(0.04, 0.05, 0.07, OVERLAY_SHADE)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.gui_input.connect(func(e: InputEvent):     # 点窗外 = 关
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				close_shelf())
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var frame := OverlayFrame.new(16)
		frame.custom_minimum_size = SHELF_WIN
		frame.set_title(UiText.t("shelf.title_" + key))
		frame.add_slot(UiTheme.make_home_button(UiText.t("meta.close"), close_shelf))
		center.add_child(frame)
		var cloth := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_BOX)     # 窗里垫原来那块粗布（浅底墨字），内容照旧
		cloth.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cloth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.content.add_child(cloth)
		(pair[1] as Callable).call(cloth)
		shade.visible = false
		_shelf_windows[key] = shade
	if _codex_tip != null:
		move_child(_codex_tip, -1)     # 悬浮窗压在窗上面


func _build_records(root: Control) -> Control:
	_records = RunRecordsWindow.new()
	_records.setup(flow, font)
	root.add_child(_records)
	return _records


func records_window() -> RunRecordsWindow:
	return _records


## 开书架上一格的窗（"codex" / "records" / "keepsakes" / "achievements"）；不在书架页就先切过去
func open_shelf(key: String) -> void:
	if not _shelf_windows.has(key):
		return
	if _tab != "shelf":
		show_tab("shelf")
	close_shelf()
	_shelf_open = key
	(_shelf_windows[key] as Control).visible = true
	if key == "records" and _records != null:
		_records.show_list()


func close_shelf() -> void:
	close_variants()
	if _codex_tip != null:
		_codex_tip.release()
	for k in _shelf_windows:
		(_shelf_windows[k] as Control).visible = false
	_shelf_open = ""


func shelf_open() -> String:
	return _shelf_open


func shelf_window(key: String) -> Control:
	return _shelf_windows.get(key, null)
#endregion


## 切页："home"（家，默认）/ "warehouse" / "sell" / "tech" / "shelf"；261：老名字 "codex" / "achievements" = 书架 + 开那扇窗。
## 178：图鉴 / 成就页收起右半边的仓库（翻到的那页不变）
func show_tab(name: String) -> void:
	if _shelf_windows.has(name):
		show_tab("shelf")
		open_shelf(name)
		return
	close_shelf()
	if not _pages.has(name):
		name = "home"
	if _tab != "" and name != _tab:
		notice_layer().clear()     # 游戏测试 v4.34：上一页的告示（「买不了：钱不够」）不跟到下一页
	_tab = name
	for key in _pages:
		(_pages[key] as Control).visible = key == name
	if _right != null:
		_right.visible = not (NO_SHELF_TABS.has(name) or FULL_TABS.has(name))
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
	if _shelf_open != "":
		close_shelf()
		return true
	if _tab != "home":
		show_tab("home")
		return true
	flow.to_main_menu()
	return true


## 178：「再来一局」上面那句 —— 带回来的背包还没清空就指向「仓库」页（点一下过去）
func pending_text() -> String:
	if not flow.meta.has_pending_board():
		return ""
	return UiText.t("meta.pending") % flow.meta.board.item_count()


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
	_sync_facility_tabs()     # 251：科技页刚点出集市 / 铁匠铺
	# 090：带回来的没清不再拦，只提示（开局屏里到地上，出发就没了）
	if _tab_btns.has("warehouse"):
		(_tab_btns["warehouse"] as Button).tooltip_text = pending_text()     # 226 批二：那句提示挪进页签的悬浮窗
	for id in _tech_spins:     # 119：科技页点亮 / 升级了，开发区的数字框跟上
		(_tech_spins[id] as SpinBox).set_value_no_signal(TechService.level(flow.meta, id))

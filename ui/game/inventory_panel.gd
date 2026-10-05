## 背包整理面板（M6）：一局里的作战棋盘，同一套拖拽（M1 的 [DragLayer]）。
## 128：不再画地上框 —— 棋盘外的整块屏幕就是「地上」（导演持有的那一层 [GroundLayer]），拖出棋盘放哪就落在哪。
##
## 拖一下就重新编译一次读数（生命、预估 DPS、套装进度）—— 编译是纯函数（4.2），这条读数永远和真打出来的一致。
## 地图屏把它叠在地图上；出发前、走到哪都能开。战斗中不会开：战斗在开打那一瞬就算完了，回放是叠层，挡着它。
##
## 是个 MarginContainer：容器按内容定大小，拖拽层作为它的第二个子节点自然铺满同一块矩形 —— 一个普通 Control
## 不会从子节点算最小尺寸，放进竖排布局里会被压成零高。
extends MarginContainer

var _run: RunState = null
var _font: Font
var _drag: DragLayer
var _readout: Label
## 087：信仰那一句单独一个标签，停上去开悬浮窗（具体效果、信力怎么涨）
var _faith_label: Label
var _hint: Label
var board_view: InventoryView
## 128：导演那一层地（没有 = null：测试里单开面板）
var ground: GroundLayer = null
var tip: HoverTip
var _stamina: Label
## 084：棋盘上双击的东西优先去这里（容器屏设成战利品 / 收获箱）；null = 放到地上
var quick_target: ItemContainer = null
## 双击之后的提示回调（容器屏想自己写）：`func(text: String)`
var hint_sink: Callable = Callable()


## [param drag] 给了就把两个视图登记到那一层（战利品屏要一层盖住三个容器）；不给就自己造一层盖在面板上
func setup(run: RunState, font: Font, drag: DragLayer = null) -> void:
	_run = run
	_font = font
	_drag = drag
	_build()
	_run.board.changed.connect(_refresh_readout)
	_refresh_readout()


func _build() -> void:
	# 128：只剩棋盘与读数；地上是整块屏幕
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(_label("作战棋盘　只有包里的东西参战　拖出棋盘 = 放在地上", 13, UiPalette.DIM))
	board_view = InventoryView.new()
	board_view.label_font = _font
	board_view.inventory = _run.board
	board_view.show_adjacency = true
	board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(board_view)
	_faith_label = _label("", 14, UiPalette.FG)
	_faith_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_faith_label.mouse_entered.connect(func():
		if tip != null:
			tip.show_text(FaithTooltip.describe(_run.active_faith(), _run.faith_power, _run.items), _faith_label.global_position + Vector2(0, _faith_label.size.y)))
	_faith_label.mouse_exited.connect(func():
		if tip != null:
			tip.hide_tip())
	left.add_child(_faith_label)
	_readout = _label("", 14, UiPalette.FG)
	left.add_child(_readout)
	# 084：耐力消耗评估（低 / 中 / 高 / 极高），停上去看每秒消耗与回复
	_stamina = _label("", 13, UiPalette.STAMINA)
	_stamina.mouse_filter = Control.MOUSE_FILTER_STOP
	_stamina.mouse_entered.connect(func():
		if tip != null:
			tip.show_text(StaminaEstimate.describe(_run.compile_player()), _stamina.global_position + Vector2(0, _stamina.size.y)))
	_stamina.mouse_exited.connect(func():
		if tip != null:
			tip.hide_tip())
	left.add_child(_stamina)
	_hint = _label("左键拖动　双击快速置入　R 旋转　右键 / Esc 取消　右键信物 = 奉为主信仰　拖到能合成的那件上 = 合成　压着别人放手会把人顶出来　放到棋盘外就放在地上（放哪落哪）", 11, UiPalette.DIM)
	left.add_child(_hint)

	left.add_child(_label("地上（不限件数）　不参战、留在这个点（回来还在原处）、撤离不带出去", 11, UiPalette.DIM))

	if _drag == null:
		_drag = DragLayer.new()
		_drag.label_font = _font
		add_child(_drag)     # 容器把它铺到和 row 一样大，盖在上面
	_drag.register_view(board_view)
	_drag.stash = _run.storage
	_drag.drop_outside_to_stash = true     # 084 / 128：棋盘外的空间全都是地上
	_attach_ground()
	_drag.items_displaced.connect(_on_displaced)
	# 114 合成（作者定）：拖到上面立刻合 —— 拖起一件时能合的那几件高光；压到其中一件上放手，两件立刻变成产物
	var crafting := CraftingModule.of(_run)     # 101：合成是一局的模块
	_drag.craft = func(a: ItemInstance, b: ItemInstance) -> ItemDef:
		return crafting.output_of(a.def, b.def) if crafting != null else null
	if crafting != null:
		_drag.craft_grid = _run.board
		_drag.craft_drop = func(a: ItemInstance, b_uid: int) -> bool:
			return bool(crafting.craft(a, b_uid)["ok"])
		crafting.done.connect(_on_crafted)
	# 084：停在道具上的悬浮说明（名、稀有度、标签、效果、武器的冷却与 DPS、槽）
	tip = HoverTip.new(_font)
	add_child(tip)
	tip.watch(board_view)
	board_view.item_double_clicked.connect(quick_move)
	board_view.item_context.connect(func(_v: ContainerView, uid: int): reseat_anchor(uid))     # 099：右键信物 = 奉为主信仰


## 128：接上导演那一层地（画的是这一局的 storage 才接）：地上的东西能拿起来拖、双击进棋盘；面板占的地方登记上，地上的东西不压着面板
func _attach_ground() -> void:
	var g := GroundLayer.current()
	if g == null or g.stash != _run.storage:
		return
	ground = g
	_drag.register_view(g)
	g.attach(_drag)
	g.item_double_clicked.connect(_on_ground_double)
	g.reserve(self)
	tree_exiting.connect(func():
		if is_instance_valid(g):
			g.detach(_drag)
			if g.item_double_clicked.is_connected(_on_ground_double):
				g.item_double_clicked.disconnect(_on_ground_double))


## 地上双击：只有最上面那块面板接（地图上的背包浮窗被叠层盖着时不抢）
func _on_ground_double(view: ContainerView, uid: int) -> void:
	if ground != null and ground.top_drag() == _drag:
		quick_move(view, uid)


## 099（作者定）：右键棋盘上的信物 = 奉它为主信仰（不弹菜单）。不是信物的右键什么也不做。返回切没切
func reseat_anchor(uid: int) -> bool:
	var inst := _run.board.get_item(uid) if _run != null and _run.board != null else null
	if inst == null or inst.def == null or not inst.def.is_anchor():
		return false
	if not _run.board.reseat(uid):
		return false
	_hint_text("奉「%s」为主信仰" % Names.of(inst.def))
	return true


## 084：双击快速置入。地上 → 棋盘（放不下就提示）；棋盘 → quick_target（容器屏的战利品 / 收获箱），没有就 → 地上。返回挪了没有
func quick_move(view: ContainerView, uid: int) -> bool:
	var from := view.container()
	var inst := from.get_item(uid) if from != null else null
	if inst == null:
		return false
	if from == _run.storage:
		if InventoryService.transfer_auto(_run.storage, uid, _run.board):
			return true
		_hint_text("背包里没有空间放「%s」" % Names.of(inst.def))
		return false
	if from == _run.board:
		if quick_target != null and InventoryService.transfer_auto(_run.board, uid, quick_target):
			return true
		if InventoryService.transfer_auto(_run.board, uid, _run.storage):
			if quick_target != null:
				_hint_text("容器里放不下「%s」，放在了地上" % Names.of(inst.def))
			return true
	return false


## 114：合成了：提示一句产物（装不下落在地上也说）
func _on_crafted(detail: Dictionary) -> void:
	if not is_inside_tree():
		return
	_hint_text(" ".join(PackedStringArray(detail.get("log", []))))


func _hint_text(text: String) -> void:
	_hint.text = text
	if hint_sink.is_valid():
		hint_sink.call(text)


func _refresh_readout() -> void:
	var spec := _run.compile_player()
	if _stamina != null:
		var e := StaminaEstimate.of(spec)
		_stamina.text = "耐力消耗：%s（每秒 %.1f，回 %.1f）　停上去看细节" % [e["rating"], e["cost"], e["regen"]]
	var lines: Array[String] = []
	if _run.tracker != null:
		for set_id in _run.tracker.tracked_ids():
			var p := _run.tracker.progress_of(set_id)
			lines.append("%s %d/%s%s" % [set_id, p["count"], "—" if p["next"] < 0 else str(p["next"]), "　已激活" if p["active"] else ""])
	var dormant := FaithState.dormant_uids(_run.board).size()
	var power := _run.faith_power.line() if _run.faith_power != null else ""
	if _faith_label != null:
		_faith_label.text = "%s%s%s　停上去看效果与信力怎么涨" % [_run.faith_line(), "（%d 件休眠）" % dormant if dormant > 0 else "", "　" + power if power != "" else ""]
	_readout.text = "生命 %d　预估 DPS %.1f　参战 %d 件（%d 件会出手）　可用格 %d（空 %d）%s" % [
		spec.max_hp_int(), spec.rough_dps(), spec.items.size(), spec.active_items().size(),
		_run.board.usable_cell_count(), _run.board.free_cell_count(),
		"　套装：" + "、".join(lines) if not lines.is_empty() else ""]


func _on_displaced(instances: Array, grabbed: bool) -> void:
	var names: Array[String] = []
	for inst in instances:
		var item := inst as ItemInstance
		names.append(Names.of(item.def) if item.def != null else "?")
	_hint.text = "顶出了「%s」，已经拿在手上" % names[0] if grabbed else "顶出了 %d 件（%s），都放在地上了" % [names.size(), "、".join(names)]


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.label(l, font_size, color)     # 121：字体在主题里，颜色先选变体
	return l

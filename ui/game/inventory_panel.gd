## 背包整理面板（M6）：一局里的作战棋盘，同一套拖拽（M1 的 [DragLayer]）。
## 128：不再画地上框 —— 棋盘外的整块屏幕就是「地上」（导演持有的那一层 [GroundLayer]），拖出棋盘放哪就落在哪。
##
## 拖一下就重新编译一次读数（216：棋盘下的数值栏 [StatsStrip] —— 耐力 / DPS / 负重）—— 编译是纯函数（4.2），这条读数永远和真打出来的一致。
## 188（作者 2026-10-17）：操作提示、地上说明、参战 / 可用格读数、信仰行都删了；信仰的悬浮窗在顶端栏的徽记上。
## 面板自己的回话（顶出来了、放不下、合成了）交给宿主（[member hint_sink]）；没接就走告示层（226 批一）
## 地图屏把它叠在地图上；出发前、走到哪都能开。战斗中不会开：战斗在开打那一瞬就算完了，回放是叠层，挡着它。
##
## 是个 MarginContainer：容器按内容定大小，拖拽层作为它的第二个子节点自然铺满同一块矩形 —— 一个普通 Control
## 不会从子节点算最小尺寸，放进竖排布局里会被压成零高。
extends MarginContainer

var _run: RunState = null
var _font: Font
var _drag: DragLayer
## 188：最近一句回话（测试看；面板上不再写字）
var last_hint := ""
var board_view: InventoryView
## 棋盘一格多大（[method setup] 之前设；背包浮窗 72，别处默认 60）
var cell_px: float = InventoryView.CELL
## 128：导演那一层地（没有 = null：测试里单开面板）
var ground: GroundLayer = null
var tip: HoverTip
## 216：棋盘下的数值栏（容器屏把它摘出去摆到「全部拾取」那一行，[method detach_strip]）
var strip: StatsStrip
var _strip_box: MarginContainer
## 数值栏上沿离棋盘格子下沿（让开棋盘外框，精修稿 22）
const STRIP_GAP := 22.0
## 084：棋盘上双击的东西优先去这里（容器屏设成战利品 / 收获箱）；null = 放到地上
var quick_target: ItemContainer = null
## 双击之后的提示回调（容器屏想自己写）：`func(text: String)`
var hint_sink: Callable = Callable()
## 230：悬浮窗按钮里「双击做的那件事」叫什么（有 [member quick_target] 的屏给：`func(inst) -> ItemActions.Action`，出售区写「出售 N 币」……）；
## 不给 = 「放进去」；没有 quick_target = 「放到地上」
var quick_action: Callable = Callable()
## 230：这一屏另加的按钮（`func(inst) -> Array`，排在锁定后面）
var extra_actions: Callable = Callable()
## 249（作者 2026-10-24）：这一屏棋盘上的东西出不去（战前屏：开战前不丢东西）—— 非空就是那句原因：拖出棋盘弹回、右键「放到地上」灰着、
## 双击不搬、顶替不往地上挤。地上的照样能拾进棋盘，地上拿起放回地上不拦；「不参战」照旧。[method setup] 前后设都行
var ground_exit_notice: String = "":
	set(v):
		ground_exit_notice = v
		_guard_ground_exit()
var _exit_guarded := false


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
	# 160：腰带不在背包里了（屏幕右下角 [BeltSlots]）。188：棋盘上面那行玩法说明也删了
	board_view = InventoryView.new()
	board_view.label_font = _font
	board_view.inventory = _run.board
	board_view.cell_px = cell_px
	board_view.show_adjacency = true
	board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(board_view)
	# 216：耐力 / DPS / 负重三张火漆签（原耐力行、负重行）；各自停上去看细节
	_strip_box = MarginContainer.new()
	_strip_box.add_theme_constant_override("margin_top", int(STRIP_GAP) - 8)     # 竖排本身隔 8
	_strip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_strip_box)
	strip = StatsStrip.new()
	strip.set_width(float(_run.board.size.x) * board_view.cell_px)
	_strip_box.add_child(strip)

	if _drag == null:
		_drag = DragLayer.new()
		_drag.label_font = _font
		add_child(_drag)     # 容器把它铺到和 row 一样大，盖在上面
	_drag.register_view(board_view)
	_drag.stash = _run.storage
	_drag.drop_outside_to_stash = true     # 084 / 128：棋盘外的空间全都是地上
	_attach_ground()
	_drag.items_displaced.connect(_on_displaced)
	_drag.grab_refused.connect(func(_uid: int): _hint_text(UiText.t(DragLayer.ROOTED_NOTICE)))     # 207
	# 114 合成（作者定）：拖到上面立刻合 —— 拖起一件时能合的那几件高光；压到其中一件上放手，两件立刻变成产物
	var crafting := CraftingModule.of(_run)     # 101：合成是一局的模块
	_drag.craft = func(a: ItemInstance, b: ItemInstance) -> ItemDef:
		return crafting.output_of(a.def, b.def) if crafting != null else null
	if crafting != null:
		_drag.craft_grid = _run.board
		_drag.craft_drop = func(a: ItemInstance, b_uid: int) -> bool:
			return bool(crafting.craft(a, b_uid)["ok"])
		_drag.craft_note = func(a: ItemInstance, b: ItemInstance) -> String:     # 140：预览旁边那行小字
			return crafting.note_of(a.def, b.def)
		crafting.done.connect(_on_crafted)
	# 175 第三批：铸牌压到武器上放手 = 附魔（任何格子容器里都行；铸牌已经拿在手上）
	_drag.enchant_drop = func(token: ItemInstance, grid: GridInventory, weapon_uid: int) -> bool:
		return InventoryService.enchant(token, null, grid, weapon_uid)
	# 084：停在道具上的悬浮说明（名、稀有度、标签、效果、武器的冷却与 DPS、槽）
	tip = HoverTip.new()
	add_child(tip)
	tip.watch(board_view)
	strip.tip = tip
	board_view.item_double_clicked.connect(quick_move)
	board_view.actions_for = board_actions     # 230：右键 = 钉住悬浮窗（信物奉为主信仰改成按钮）
	_guard_ground_exit()


## 249：给拖拽层挂上「棋盘上的不许去地上」那一道门（包在这一屏原有的过滤器外面），松手被拦时说那一句
func _guard_ground_exit() -> void:
	if _drag == null or _run == null or ground_exit_notice == "" or _exit_guarded:
		return
	_exit_guarded = true
	var prior := _drag.drop_filter
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		if ground_exit_notice != "" and target == _run.storage and _drag.source() == _run.board:
			return false
		return not prior.is_valid() or bool(prior.call(inst, target))
	_drag.displace_to_stash = false
	_drag.drop_refused.connect(func(_uid: int):
		if ground_exit_notice != "":
			_hint_text(ground_exit_notice))


## 216：容器屏把数值栏摘出去，自己摆到「全部拾取」那一行；面板里那格空位一起拿掉
func detach_strip() -> StatsStrip:
	if _strip_box != null:
		_strip_box.remove_child(strip)
		_strip_box.queue_free()
		_strip_box = null
	return strip


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


## 230：棋盘上一件的按钮 —— 双击做的那件事（放到地上 / 送去这一屏的容器）→ 锁定 → 奉为主信仰（信物）→ 这一屏另加的
func board_actions(uid: int) -> Array:
	var inst := _run.board.get_item(uid) if _run != null else null
	if inst == null:
		return []
	var out: Array = []
	var first: ItemActions.Action = null
	if quick_target != null and quick_action.is_valid():
		first = quick_action.call(inst)
	if first == null:
		first = ItemActions.make(&"quick", UiText.t("act.into_box" if quick_target != null else "act.drop"),
			func(): quick_move(board_view, uid), quick_target == null)
	if ground_exit_notice != "" and quick_target == null:
		ItemActions.disable(first, ground_exit_notice)     # 249：开战前不丢东西
	elif inst.is_locked_by_player() and (quick_target == null or not _quick_allows(inst)):
		ItemActions.disable(first, UiText.t("act.locked"))
	elif _run.board.is_locked(uid):
		ItemActions.disable(first, UiText.t(DragLayer.ROOTED_NOTICE))
	out.append(first)
	out.append(ItemActions.lock(inst, _run.board))
	if inst.def.is_anchor():
		out.append(ItemActions.anchor(inst, _run.board, reseat_anchor))
	if can_bench(inst):
		out.append(ItemActions.bench(inst, _run.board))     # 2026-10-22：不参战（战前整备用）
	if extra_actions.is_valid():
		out.append_array(extra_actions.call(inst))
	return out


## 2026-10-22（作者）：哪些能给「不参战」—— 会参与战斗的那几件（有战斗定义：武器、护甲、会出手的器官）。
## 信物不算：标了它会把信仰一起熄掉，那是另一件事，不该藏在「不参战」这个按钮里
static func can_bench(inst: ItemInstance) -> bool:
	return inst != null and inst.def != null and inst.def.combat != null and not inst.def.is_anchor()


## 099（作者定）：信物奉为主信仰（230 起走悬浮窗按钮，右键改成钉住悬浮窗）。不是信物什么也不做。返回切没切
func reseat_anchor(uid: int) -> bool:
	var inst := _run.board.get_item(uid) if _run != null and _run.board != null else null
	if inst == null or inst.def == null or not inst.def.is_anchor():
		return false
	if not _run.board.reseat(uid):
		return false
	_hint_text(UiText.t("bag.reseat") % Names.of(inst.def))
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
		say_no_room(inst)
		return false
	if from == _run.board:
		if _run.board.is_locked(uid):
			_hint_text(UiText.t(DragLayer.ROOTED_NOTICE))     # 207：扎了根的双击也搬不走
			return false
		if inst.is_locked_by_player() and not _quick_allows(inst):
			_hint_text(UiText.t("item.locked_no") % Names.of(inst.def))     # 230：锁住的不丢地上、不卖、不献
			return false
		if quick_target != null and InventoryService.transfer_auto(_run.board, uid, quick_target):
			return true
		if inst.is_locked_by_player():
			_hint_text(UiText.t("item.locked_no") % Names.of(inst.def))
			return false
		if ground_exit_notice != "":
			_hint_text(ground_exit_notice)     # 249：开战前不丢东西
			return false
		if InventoryService.transfer_auto(_run.board, uid, _run.storage):
			if quick_target != null:
				_hint_text(UiText.t("bag.no_room_container") % Names.of(inst.def))
			return true
	return false




## 230：锁住的这件能不能双击送去 [member quick_target]（那一屏的落点规矩说了算：出售区、祭品台不收锁住的）
func _quick_allows(inst: ItemInstance) -> bool:
	return quick_target != null and (not _drag.drop_filter.is_valid() or bool(_drag.drop_filter.call(inst, quick_target)))


## 地上那件进不了背包：提示一句（134：地图 / 事件屏双击地上、放不下只开背包时也用这句）
func say_no_room(inst: ItemInstance) -> void:
	if inst != null and inst.def != null:
		_hint_text(UiText.t("bag.no_room") % Names.of(inst.def))


## 114：合成了：提示一句产物（装不下落在地上也说）
func _on_crafted(detail: Dictionary) -> void:
	if not is_inside_tree():
		return
	_hint_text(" ".join(PackedStringArray(detail.get("log", []))))


func _hint_text(text: String) -> void:
	last_hint = text
	if hint_sink.is_valid():
		hint_sink.call(text)
	else:
		NoticeLayer.post(self, text)     # 226 批一：默认走宿主屏的告示


func _refresh_readout() -> void:
	if strip != null:
		strip.set_width(float(_run.board.size.x) * board_view.cell_px)     # 包撑大了棋盘，签跟着宽
		strip.refresh(_run.compile_player(), _run)     # 129：超重那张的档名变色由数值栏管


func _on_displaced(instances: Array, grabbed: bool) -> void:
	_hint_text(DragLayer.displaced_text(instances, grabbed))     # 188：原来写在面板的提示行上，现在交给宿主

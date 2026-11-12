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
## 306：合成确认窗（第一次点锤时才造）
var fuse_note: FuseNote = null
## 216：棋盘下的数值栏（容器屏把它摘出去摆到「全部拾取」那一行，[method detach_strip]）
var strip: StatsStrip
var _strip_box: MarginContainer
## 255 补充一：棋盘坐的九格宽位子（[method hold_nine] 之后才有）
var nine: BoardNine = null
## 数值栏上沿离棋盘格子下沿（让开棋盘外框，精修稿 22）
const STRIP_GAP := 22.0
## 084：棋盘上双击的东西优先去这里（容器屏设成战利品 / 收获箱）；null = 放到地上
var quick_target: ItemContainer = null
## 双击之后的提示回调（容器屏想自己写）：`func(text: String)`
var hint_sink: Callable = Callable()
## 审查 A1 / 310：这件许不许拿去合成 `func(inst: ItemInstance) -> bool`（商店给还没成交的货返回 false：合掉就结不了账）。
## 不许的那件旁边不浮小锤、点了也不合。不给 = 都许
var fuse_filter: Callable = Callable()
## 230：悬浮窗按钮里「双击做的那件事」叫什么（有 [member quick_target] 的屏给：`func(inst) -> ItemActions.Action`，出售区写「出售 N 币」……）；
## 不给 = 「放进去」；没有 quick_target = 「放到地上」
var quick_action: Callable = Callable()
## 300 §2.4：按件挑落点（`func(inst) -> ItemContainer`，铁炉屏先砧后炉）；给了就盖过 [member quick_target]，挑不出 = 不收，说 [member quick_refused]
var quick_pick: Callable = Callable()
var quick_refused := ""
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
	_run.board.changed.connect(refresh_fusions)
	_refresh_readout()
	refresh_fusions()


## 这块面板用的拖拽层（279：砧的槽也登记到这一层）
func drag_layer() -> DragLayer:
	return _drag


## 279 拼接：贴着、配得上的两件接缝上画小锤（棋盘一变就重找；持有方改了 [member fuse_filter] 的判断时自己再调一次）
func refresh_fusions() -> void:
	var crafting := CraftingModule.of(_run)
	if board_view == null:
		return
	var pairs: Array[Dictionary] = []
	if crafting != null:
		for p in crafting.fusion_pairs():
			if _fusable(int(p["a"])) and _fusable(int(p["b"])):
				pairs.append(p)
	board_view.fusions = pairs


func _fusable(uid: int) -> bool:
	return not fuse_filter.is_valid() or bool(fuse_filter.call(_run.board.get_item(uid)))


func _build() -> void:
	# 128：只剩棋盘与读数；地上是整块屏幕
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	# 160：腰带不在背包里了（屏幕右下角 [BeltSlots]）。188：棋盘上面那行玩法说明也删了
	board_view = InventoryView.make(_run.board, _font, true)
	board_view.cell_px = cell_px
	board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(board_view)
	# 216：耐力 / DPS / 负重三张火漆签（原耐力行、负重行）；各自停上去看细节
	_strip_box = MarginContainer.new()
	_strip_box.add_theme_constant_override("margin_top", int(STRIP_GAP) - 8)     # 竖排本身隔 8
	_strip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_strip_box)
	strip = StatsStrip.new()
	strip.set_width(strip_width())
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
	_drag.grab_refused.connect(func(uid: int): _hint_text(DragLayer.refused_notice(_run.board, uid)))     # 207 / 255
	# 279 / 310：合成只有一种 —— 贴着放、点接缝上的小锤、确认（114 的拖上去合已删）
	var crafting := CraftingModule.of(_run)     # 101：合成是一局的模块
	if crafting != null:
		crafting.done.connect(_on_crafted)
		board_view.fuse_requested.connect(func(_v: InventoryView, a: int, b: int) -> void: ask_fuse(a, b))     # 279：点锤；305：先看再合
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
	elif _run.board.keeps(uid):
		ItemActions.disable(first, DragLayer.refused_notice(_run.board, uid))
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
	return inst != null and inst.def != null and inst.def.combat != null and not inst.def.is_anchor() and not inst.is_pinned()     # 255：随身之物不能标


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
		if _run.board.keeps(uid):
			_hint_text(DragLayer.refused_notice(_run.board, uid))     # 207：扎了根的双击也搬不走（255 随身之物同理）
			return false
		if inst.is_locked_by_player() and not _quick_allows(inst):
			_hint_text(UiText.t("item.locked_no") % Names.of(inst.def))     # 230：锁住的不丢地上、不卖、不献
			return false
		var target := quick_target
		if quick_pick.is_valid() and quick_target != null:
			target = quick_pick.call(inst)
			if target == null:
				_hint_text(quick_refused)     # 300：这一屏哪个槽都不收这件，也不往地上丢
				return false
		if target != null and _drag != null and _drag.drop_filter.is_valid() and not bool(_drag.drop_filter.call(inst, target)):
			return false     # 290：这一屏不收这件（商店：独一的、券、装着东西的包）—— 原因由过滤器说，也不往地上丢
		if target != null and InventoryService.transfer_auto(_run.board, uid, target):
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
## 305（改造 A，方案 §6.2 / §6.3）：点锤先开确认窗 —— 成品（不认识就是问号）、两件的图、会丢掉的附魔 / 品质 / 成长；
## 按「合成」才合（合的那一下再查一遍两件还贴着、没锁），「取消」什么都不动。拼不了 = false
## 306 定稿：窗是 [FuseNote]（纸条），摆在两件右边、尖角和小锤同高；开着时那一对照悬停那一档画
func ask_fuse(a_uid: int, b_uid: int) -> bool:
	var crafting := CraftingModule.of(_run)
	var pv := crafting.fuse_preview(a_uid, b_uid) if crafting != null and _fusable(a_uid) and _fusable(b_uid) else {}
	if pv.is_empty():
		return false
	var a := pv["a"] as ItemInstance
	var b := pv["b"] as ItemInstance
	var res: Dictionary = pv.get("resolution", {})
	var can_fuse := String(res.get("status", FusionResolve.READY)) == FusionResolve.READY
	var lines := _faith_lines(res)
	for inst in ([a, b] if can_fuse else []):
		var lost: Array[String] = []
		if not Forge.enchant_of(inst).is_empty():
			lost.append(UiText.t("fuse.enchant"))
		if (inst as ItemInstance).quality() > 0:
			lost.append(UiText.t("fuse.quality"))
		if (inst as ItemInstance).runs() > 0:
			lost.append(UiText.t("fuse.growth"))
		if not lost.is_empty():
			lines.append(UiText.t("fuse.loses") % [Names.of((inst as ItemInstance).def), UiText.t("tip.list_sep").join(PackedStringArray(lost))])
	if fuse_note == null:
		fuse_note = FuseNote.new()
		add_child(fuse_note)
		fuse_note.closed = func() -> void: board_view.held_fusion = Vector2i(-1, -1)
	if tip != null:
		tip.hide_tip()
	var xf := board_view.get_global_transform()
	var pair := xf * board_view.item_rect(a_uid).merge(board_view.item_rect(b_uid))
	var hammer_y := board_view.get_global_mouse_position().y
	for f in board_view.fusions:
		if (int(f["a"]) == a_uid and int(f["b"]) == b_uid) or (int(f["a"]) == b_uid and int(f["b"]) == a_uid):
			hammer_y = (xf * (Vector2(f["seam"]) * board_view.cell_px)).y
	var expect := StringName(res.get("output_id", &""))
	var on_go := Callable()     # 312 §8.1：禁忌待办没有合成键
	if can_fuse:
		on_go = func() -> void:
			if _fusable(a_uid) and _fusable(b_uid) and bool(crafting.fuse(a_uid, b_uid, expect).get("changed", false)):
				ask_fuse(a_uid, b_uid)     # 312 §3：确认后结果变了（信仰换了等）：不合，按新结果重开
	fuse_note.open(a.def, b.def, pv["output"] as ItemDef, int(pv["known"]) > 0, "\n".join(PackedStringArray(lines)), pair, hammer_y, on_go)
	board_view.held_fusion = Vector2i(a_uid, b_uid)
	return true


## 312（方案 §3、§8.1）：信仰后果那几句 —— 禁忌待办只说一句（不说成品会丢什么）；择神说保留谁；没那位神的赐福版说不保留
func _faith_lines(res: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if String(res.get("status", "")) == FusionResolve.UNAVAILABLE:
		out.append(UiText.t("fuse.forbidden"))
		return out
	var warnings: Array = res.get("warnings", [])
	if warnings.has(FusionResolve.FAITH_DROPPED):
		out.append(UiText.t("fuse.faith_dropped") % [_faith_name(StringName(res["selected_faith"])), _faith_name(StringName(res["dropped_faith"]))])
	if warnings.has(FusionResolve.BLESSING_LOST):
		out.append(UiText.t("fuse.blessing_lost"))
	return out


func _faith_name(id: StringName) -> String:
	var def: Object = _run.faith_defs.get(id, null)
	return Names.of(def) if def != null else String(id)


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


## 255 补充一（作者 10:51）：棋盘连框坐进九格宽的位子（[BoardFrame] 套好之后叫；自己摆框的屏也叫，没框 = 缩进 0），面板不随棋盘宽窄变
func hold_nine() -> BoardNine:
	var outer: Control = board_view.get_parent() if board_view.get_parent() is BoardFrame else board_view
	nine = BoardNine.hold(outer, board_view, (outer as BoardFrame).inset() if outer is BoardFrame else 0.0)
	return nine


## 数值栏多宽：九格（棋盘比九格还宽按它自己的）
func strip_width() -> float:
	return maxi(CharacterDef.BOARD_MAX_W, _run.board.size.x) * board_view.cell_px


func _refresh_readout() -> void:
	if strip != null:
		strip.set_width(strip_width())
		strip.refresh(_run.compile_player(), _run)     # 129：超重那张的档名变色由数值栏管


func _on_displaced(instances: Array, grabbed: bool) -> void:
	_hint_text(DragLayer.displaced_text(instances, grabbed))     # 188：原来写在面板的提示行上，现在交给宿主

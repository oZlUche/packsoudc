## 开局（M6，架构文档 8 节；058 第 2 条，报告 067）：挑一章、挑角色、往初始包里拖仓库的东西、定个种子，出发。
##
## 左边章节与角色，中间是这个角色的棋盘（初始包已经摆好），右边是仓库的格子：从仓库往包里拖，**放得进的就是带的** ——
## 带入的真正限制是初始包的空间；件数 / 稀有度上限是角色的字段（默认不限），出发时查。
## 包不能带入：仓库里本来没有包（局外只收非包，`MetaState.keeps`），仓库的格子也不收包（同一条规则接在 `accept_filter` 上）。
## 拖上棋盘那一刻东西就离开了仓库；出发时存 meta，回主菜单就放回去。
## 所有动作都是公开方法（[method choose_chapter]、[method choose_character]、[method carry_in]、[method depart]、[method cancel]），按钮只是调它们；测试直接调。
##
## 没有角色定义（老内容、测试）时退回老路：按第一套开局装备开。
extends GameScreen

var chapter_index: int = 0
var character_index: int = 0
var difficulty_index: int = 0
var run_seed: int = 1
## 这个角色的棋盘，初始包摆好；从仓库拖进来的东西就在上面。出发时整块记成 layout 交给 RunState
var board: GridInventory = null

var _chapter_btns: Array[Button] = []
var _character_btns: Array[Button] = []
var _difficulty_btns: Array[Button] = []
var _board_host: VBoxContainer
var _board_view: InventoryView = null
var _warehouse_view: InventoryView = null
var _drag: DragLayer = null
var _desc: Label
var _readout: RichTextLabel = null
var _status: Label
var _seed_spin: SpinBox


func open(_payload: Dictionary) -> void:
	_backdrop()
	run_seed = randi() % 1000000
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var row := _hbox(28)
	margin.add_child(row)

	# 左：章节、角色、种子
	var left := _vbox(8)
	left.custom_minimum_size.x = 300
	row.add_child(left)
	left.add_child(_label("开局", 26, UiPalette.FG))
	left.add_child(_label("章节", 15, UiPalette.DIM))
	for i in flow.chapters.size():
		var c := flow.chapters[i]
		var idx := i
		var b := _button("%s（难度 %d）" % [c.display_name if c.display_name != "" else String(c.id), c.difficulty],
			func(): choose_chapter(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_chapter_btns.append(b)
		left.add_child(b)
	if flow.chapters.is_empty():
		left.add_child(_label("没有章节：先跑 tools/import_content.gd", 13, UiPalette.HP))
	left.add_child(_label("角色", 15, UiPalette.DIM))
	for i in flow.characters.size():
		var ch := flow.characters[i]
		var idx := i
		var b := _button(ch.display_name if ch.display_name != "" else String(ch.id), func(): choose_character(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_character_btns.append(b)
		left.add_child(b)
	if flow.characters.is_empty():
		left.add_child(_label("没有角色定义：按第一套开局装备开（老路）", 12, UiPalette.DIM))
	var avail := flow.available_difficulties()
	if not avail.is_empty():
		left.add_child(_label("难度", 15, UiPalette.DIM))
		for i in avail.size():
			var d := avail[i]
			var idx := i
			var b := _button(d.display_name if d.display_name != "" else String(d.id), func(): choose_difficulty(idx))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_difficulty_btns.append(b)
			left.add_child(b)
	_desc = _wrapped("", 12, UiPalette.DIM, 280)
	left.add_child(_desc)
	var seed_row := _hbox(8)
	seed_row.add_child(_label("种子", 13, UiPalette.DIM))
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 999999
	_seed_spin.value = run_seed
	_seed_spin.value_changed.connect(func(v: float): run_seed = int(v))
	seed_row.add_child(_seed_spin)
	seed_row.add_child(_button("随机", func(): set_run_seed(randi() % 1000000), 12))
	left.add_child(seed_row)
	left.add_child(HSeparator.new())
	left.add_child(_button("出发", func(): depart(), 18))
	left.add_child(_button("回主菜单", cancel, 12))
	_status = _wrapped("", 12, UiPalette.HP, 280)
	left.add_child(_status)

	# 中 + 右：棋盘与仓库在同一块矩形里，拖拽层盖在上面
	var play := MarginContainer.new()
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(play)
	var grids := _hbox(28)
	play.add_child(grids)

	_board_host = _vbox(6)
	grids.add_child(_board_host)

	var right := _vbox(6)
	grids.add_child(right)
	var w := flow.meta.warehouse
	right.add_child(_label("仓库　%d × %d 格，%d 件" % [w.size.x, w.size.y, w.item_count()], 15, UiPalette.DIM))
	right.add_child(_wrapped("往左边的包里拖，放得进的就是带的；带进去的从仓库拿走，撤离了回来，死了就没了", 12, UiPalette.DIM, 480))
	_warehouse_view = InventoryView.new()
	_warehouse_view.label_font = font
	_warehouse_view.inventory = w
	_warehouse_view.show_adjacency = false
	_warehouse_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(_warehouse_view)

	_drag = DragLayer.new()
	_drag.label_font = font
	play.add_child(_drag)     # 容器把它铺到和 grids 一样大，盖在两块格子上
	_drag.register_view(_warehouse_view)
	w.changed.connect(_refresh)

	choose_chapter(0)
	choose_character(0)
	choose_difficulty(0)


#region 公开动作
func choose_chapter(i: int) -> void:
	if flow.chapters.is_empty():
		return
	chapter_index = clampi(i, 0, flow.chapters.size() - 1)
	for k in _chapter_btns.size():
		_chapter_btns[k].add_theme_color_override("font_color", UiPalette.FG if k == chapter_index else UiPalette.DIM)
	_refresh()


## 换角色：带上的先放回仓库，按新角色的棋盘尺寸与初始包重摆
func choose_character(i: int) -> void:
	_return_carried()
	if not flow.characters.is_empty():
		character_index = clampi(i, 0, flow.characters.size() - 1)
	for k in _character_btns.size():
		_character_btns[k].add_theme_color_override("font_color", UiPalette.FG if k == character_index else UiPalette.DIM)
	_rebuild_board()
	_refresh()


## 挑难度（只在能选的里挑：没有解锁要求的和已解锁的）
func choose_difficulty(i: int) -> void:
	var avail := flow.available_difficulties()
	if avail.is_empty():
		return
	difficulty_index = clampi(i, 0, avail.size() - 1)
	for k in _difficulty_btns.size():
		_difficulty_btns[k].add_theme_color_override("font_color", UiPalette.FG if k == difficulty_index else UiPalette.DIM)
	_refresh()


func difficulty() -> DifficultyDef:
	var avail := flow.available_difficulties()
	return avail[difficulty_index] if difficulty_index < avail.size() else null


func chapter() -> ChapterDef:
	return flow.chapters[chapter_index] if chapter_index < flow.chapters.size() else null


func character() -> CharacterDef:
	return flow.characters[character_index] if character_index < flow.characters.size() else null


## 把仓库里的一件带上（自动找位置，和拖进包里一样）。放不进返回 false
func carry_in(uid: int) -> bool:
	if board == null or flow.meta.warehouse.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(flow.meta.warehouse, uid, board)
	_refresh()
	return ok


## 把棋盘上的一件放回仓库。包不行（它是初始包，不是仓库的东西）
func carry_out(uid: int) -> bool:
	if board == null:
		return false
	var inst := board.get_item(uid)
	if inst == null or not MetaState.keeps(inst.def):
		return false
	var ok := InventoryService.transfer_auto(board, uid, flow.meta.warehouse)
	_refresh()
	return ok


## 现在带上的（非包）
func carried() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if board == null:
		return out
	for inst in board.items():
		if MetaState.keeps((inst as ItemInstance).def):
			out.append(inst)
	return out


func set_run_seed(v: int) -> void:
	run_seed = v
	if _seed_spin != null:
		_seed_spin.set_value_no_signal(v)


## 能不能出发；空串 = 能，否则是原因
func can_depart() -> String:
	if chapter() == null:
		return "没有章节可开"
	var why := flow.can_begin()
	if why != "":
		return why
	var ch := character()
	if ch != null:
		var defs: Array = []
		for inst in carried():
			defs.append(inst.def)
		return ch.carry_problem(defs)
	return ""


## 出发。开不了（生成不出图、超上限）返回 false，留在这一屏说明原因
func depart() -> bool:
	var why := can_depart()
	if why != "":
		_status.text = why
		return false
	var c := chapter()
	var ch := character()
	var run: RunState = null
	if ch != null:
		run = flow.begin(c, null, run_seed, [] as Array[int], ch, RunState.layout_of(board), difficulty())
	else:
		run = flow.begin(c, flow.loadouts[0] if not flow.loadouts.is_empty() else null, run_seed, [] as Array[int], null, [], difficulty())
	if run == null:
		_status.text = "这一章生成不出图：%s" % (c.map_source.last_error if c.map_source != null else "没有地图来源")
		return false
	return true


## 不开了：带上的放回仓库，回主菜单
func cancel() -> void:
	_return_carried()
	flow.to_main_menu()
#endregion


func _return_carried() -> void:
	if board == null:
		return
	for inst in carried():
		board.remove(inst.uid)
		if not flow.meta.take_back(inst):
			push_warning("setup: %s 放不回仓库，丢弃" % inst.def.id)


## 按角色造棋盘：初始包摆好。包的 uid 走局外的号段，免得和从仓库拖来的撞号
func _rebuild_board() -> void:
	for c in _board_host.get_children():
		_board_host.remove_child(c)
		c.queue_free()
	if _board_view != null and _drag != null:
		_drag.unregister_view(_board_view)
	_board_view = null
	_readout = null
	board = null
	var ch := character()
	if ch == null:
		_board_host.add_child(_label("（老路：按第一套开局装备开，出发后在地图上按「背包」整理）", 12, UiPalette.DIM))
		return
	board = GridInventory.new(ch.board_size, RunState.BOARD_ID, true)
	board.begin_batch()
	for id in ch.starting_bags:
		var def := flow.items.get_def(id)
		if def == null:
			continue
		var inst := ItemInstance.create(def, 0)
		inst.uid = flow.meta.allocate_uid()
		board.try_add(inst, true)
	board.end_batch()
	_board_host.add_child(_label("棋盘　%d × %d 格，初始包 %d 个" % [ch.board_size.x, ch.board_size.y, ch.starting_bags.size()], 15, UiPalette.DIM))
	_board_view = InventoryView.new()
	_board_view.label_font = font
	_board_view.inventory = board
	_board_view.show_adjacency = true
	_board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_board_host.add_child(_board_view)
	_readout = _log_box(13)
	_readout.custom_minimum_size = Vector2(ch.board_size.x * InventoryView.CELL, 140)
	_readout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_board_host.add_child(_readout)
	_board_host.add_child(_label("左键拖动　R 旋转　右键 / Esc 取消", 11, UiPalette.DIM))
	_drag.register_view(_board_view)
	board.changed.connect(_refresh)


func _refresh() -> void:
	var c := chapter()
	var ch := character()
	if _desc != null:
		var lines: Array[String] = []
		if c != null:
			lines.append("%s　难度 %d　敌人池 %s" % [c.display_name, c.difficulty, String(c.enemy_pool) if c.enemy_pool != &"" else "无"])
		if ch != null:
			lines.append(ch.description)
			var caps: Array[String] = []
			caps.append("体力 %d" % ch.vitality_max)
			caps.append("生命 %d" % int(ch.baseline().value_of(&"max_hp")))
			if ch.carry_max_items >= 0:
				caps.append("最多带 %d 件" % ch.carry_max_items)
			if ch.carry_rarity_cap >= 0:
				caps.append("稀有度不超过 %d" % ch.carry_rarity_cap)
			lines.append("　".join(caps))
		var d := difficulty()
		if d != null:
			lines.append("难度「%s」：%s" % [d.display_name, d.summary()])
		_desc.text = "\n".join(lines)
	if _readout != null and board != null:
		_readout.clear()
		var value := 0
		var cells := 0
		var taken := carried()
		for inst in taken:
			value += ItemValue.of(inst.def)
			cells += inst.def.shape.cell_count() if inst.def.shape != null else 0
			_readout.append_text("　" + _item_line(inst.def) + "\n")
		if taken.is_empty():
			_readout.append_text("[color=#8b93a1]什么都还没带[/color]\n")
		_readout.append_text("\n带 %d 件，占 %d 格，值 %d 币　包里还有 %d 格" % [taken.size(), cells, value, board.free_cell_count()])
	if _status != null:
		var why := can_depart()
		_status.text = why if why != "" and not carried().is_empty() else ""

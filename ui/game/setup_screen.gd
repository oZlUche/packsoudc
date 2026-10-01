## 开局（M6，架构文档 8 节；058 第 2 条，报告 067）：挑一章、挑角色、往初始包里拖仓库的东西、定个种子，出发。
##
## 左边章节与角色，中间是这个角色的棋盘（初始包已经摆好），右边是仓库的格子：从仓库往包里拖，**放得进的就是带的** ——
## 带入的真正限制是初始包的空间；件数 / 稀有度上限是角色的字段（默认不限），出发时查。
## 包不能带入：仓库里本来没有包（局外只收非包，`MetaState.keeps`），仓库的格子也不收包（同一条规则接在 `accept_filter` 上）。
## 拖上棋盘那一刻东西就离开了仓库；出发时存 meta，回主菜单就放回去。
## 所有动作都是公开方法（[method choose_chapter]、[method choose_character]、[method carry_in]、[method store]、[method depart]、[method cancel]），按钮只是调它们；测试直接调。
##
## **暂存区**（090，作者定）：上一局带回来、还没置入的东西（`MetaState.board`）进这一屏时挪进中间的暂存区（记住各自原位）。
## 往包里拖 = 带上、往仓库拖 = 置入、留着的**出发就没了**；回主菜单则原样放回带回来的棋盘（视为没发生过移动）。
## 仓库的东西进不了暂存区（会丢）。
##
## 没有角色定义（老内容、测试）时退回老路：按第一套开局装备开。
##
## **预设装备**（096，作者定）：角色之下一栏「预设装备」—— 不带 / 强攻（伤害高）/ 坚守（防御高）……（`LoadoutDef.preset`，数据里加一份就多一套）。
## 挑一套就把它的道具免费放进初始包：不从仓库拿、不算带入预算与件数上限、拖不进仓库 / 暂存区（只能在棋盘上挪），出发时带着走。
## 预设是底线（094）：仓库空也有一套能打的
extends GameScreen

## 暂存区容器的 id（局外的 100 / 101 之外）
const STASH_ID := 110

var chapter_index: int = 0
var character_index: int = 0
var difficulty_index: int = 0
## 096：挑的预设套在 [method GameFlow.presets] 里的下标；-1 = 不带
var preset_index: int = -1
## 096：棋盘上预设套的实例 uid → true（不算带入、不能拖去仓库）
var _preset_uids: Dictionary = {}
var _preset_btns: Array[Button] = []
var _preset_box: VBoxContainer = null
## 085：地图规模（随机一局可选）；空 = 章节默认
var scale_id: StringName = &""
var _scale_btns: Dictionary = {}
var _scale_box: VBoxContainer
var run_seed: int = 1
## 这个角色的棋盘，初始包摆好；从仓库拖进来的东西就在上面。出发时整块记成 layout 交给 RunState
var board: GridInventory = null
## 090：暂存区 —— 上一局带回来、还没置入的东西
var stash: ItemStash = null
## 090：暂存区里那些东西的来处：uid → {"origin", "rot"}（回主菜单按原位放回）
var _pending: Dictionary = {}
var _stash_box: VBoxContainer = null
var _stash_view: StashView = null
var _stash_title: Label = null

## 083：开局屏列的章节（按解锁过滤、按 order 排）与这一章能选的角色
var _chapters: Array[ChapterDef] = []
var _characters: Array[CharacterDef] = []
var _char_box: VBoxContainer = null
var _warehouse_box: VBoxContainer = null
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
	left.custom_minimum_size.x = 340
	row.add_child(left)
	left.add_child(_label("开局", 26, UiPalette.FG))
	left.add_child(_label("章节", 15, UiPalette.DIM))
	_chapters = flow.available_chapters()
	for i in _chapters.size():
		var c := _chapters[i]
		var idx := i
		var b := _button("%s（难度 %d）" % [c.display_name if c.display_name != "" else String(c.id), c.difficulty],
			func(): choose_chapter(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_chapter_btns.append(b)
		left.add_child(b)
	if _chapters.is_empty():
		left.add_child(_label("没有章节：先跑 tools/import_content.gd", 13, UiPalette.HP))
	left.add_child(_label("角色", 15, UiPalette.DIM))
	_char_box = _vbox(8)
	left.add_child(_char_box)
	if flow.characters.is_empty():
		left.add_child(_label("没有角色定义：按第一套开局装备开（老路）", 12, UiPalette.DIM))
	if not flow.presets().is_empty():
		left.add_child(_label("预设装备", 15, UiPalette.DIM))
		_preset_box = _vbox(6)
		left.add_child(_preset_box)
		_rebuild_presets()
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
	_scale_box = _vbox(6)
	left.add_child(_scale_box)
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
	seed_row.add_child(_button("随机", func(): set_run_seed(randi() % 1000000), 12, UiPalette.Tier.MINOR))
	left.add_child(seed_row)
	left.add_child(HSeparator.new())
	left.add_child(_button("出发", func(): depart(), 18, UiPalette.Tier.PRIMARY))
	left.add_child(_button("回主菜单", cancel, 12, UiPalette.Tier.MINOR))
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

	# 090：中间是暂存区（有上一局带回来的东西才显示）
	_stash_box = _vbox(6)
	grids.add_child(_stash_box)

	_warehouse_box = _vbox(6)
	var right := _warehouse_box
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
	_build_stash()

	choose_chapter(0)
	choose_difficulty(0)


## 090：暂存区那一栏。上一局带回来、还没置入的东西从带回来的棋盘挪进来，记住各自原位（回主菜单原样放回）
func _build_stash() -> void:
	stash = ItemStash.new(STASH_ID, 0)
	_pending.clear()
	var back := flow.meta.board
	if back != null:
		for inst in back.items():
			var it := inst as ItemInstance
			var origin := it.origin
			var rot := it.rotation
			if back.remove(it.uid) != null and stash.insert(it):
				_pending[it.uid] = {"origin": origin, "rot": rot}
	_stash_title = _label("", 15, UiPalette.DIM)
	_stash_box.add_child(_stash_title)
	_stash_box.add_child(_wrapped("上一局带回来、还没置入的东西先放在这儿。往包里拖 = 带上；往仓库拖 = 收进仓库；留在这儿的出发就没了；回主菜单则原样放回带回来的背包", 12, UiPalette.DIM, 240))
	_stash_view = StashView.new()
	_stash_view.label_font = font
	_stash_view.custom_minimum_size.x = 240
	_stash_view.stash = stash
	_stash_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stash_box.add_child(_stash_view)
	_drag.register_view(_stash_view)
	_drag.drop_filter = _allow_drop
	stash.changed.connect(_refresh)
	_stash_box.visible = not _pending.is_empty()


## 090：落点规则。仓库的东西进不了暂存区（进去就等于出发时丢掉）；暂存区的东西上棋盘要这一章允许带入
func _allow_drop(inst: ItemInstance, target: ItemContainer) -> bool:
	if inst == null:
		return false
	if target == stash:
		return _pending.has(inst.uid)
	if target == board and _pending.has(inst.uid):
		var c := chapter()
		return c == null or c.allow_carry_in
	if _preset_uids.has(inst.uid) and target != board:
		return false     # 096：预设套的东西只能在棋盘上挪，进不了仓库 / 暂存区
	return true


#region 公开动作
func choose_chapter(i: int) -> void:
	if _chapters.is_empty():
		return
	chapter_index = clampi(i, 0, _chapters.size() - 1)
	for k in _chapter_btns.size():
		_chapter_btns[k].add_theme_color_override("font_color", UiPalette.FG if k == chapter_index else UiPalette.DIM)
	# 083：这一章能选的角色、能不能从仓库带东西，都跟着章节变
	_rebuild_characters()
	_rebuild_scales()
	if _warehouse_box != null:
		_warehouse_box.visible = chapter().allow_carry_in
	choose_character(0)


## 角色按钮按这一章能选的重排
## 085：这一章的随机图有哪些规模（环形生成器的 `scales`）；预设图没有
func _rebuild_scales() -> void:
	for c in _scale_box.get_children():
		c.queue_free()
	_scale_btns.clear()
	scale_id = &""
	var ch := chapter()
	var options := ch.map_source.scale_options() if ch != null and ch.map_source != null else [] as Array[Dictionary]
	if options.is_empty():
		return
	_scale_box.add_child(_label("地图规模", 15, UiPalette.DIM))
	var def_btn := _button("默认（章节配置）", func(): choose_scale(&""), 13)
	def_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_scale_btns[&""] = def_btn
	_scale_box.add_child(def_btn)
	for o in options:
		var sid: StringName = o["id"]
		var limit := int(o.get("step_limit", 0))
		var b := _button(String(o["display_name"]) + ("　倒计时 %d" % limit if limit > 0 else ""), func(): choose_scale(sid), 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_scale_btns[sid] = b
		_scale_box.add_child(b)
	choose_scale(&"")


func choose_scale(id: StringName) -> void:
	scale_id = id if _scale_btns.has(id) else &""
	for k in _scale_btns:
		(_scale_btns[k] as Button).add_theme_color_override("font_color", UiPalette.FG if k == scale_id else UiPalette.DIM)


func scale_options() -> Array:
	return _scale_btns.keys()


func _rebuild_characters() -> void:
	_characters = flow.characters_for(chapter())
	_character_btns.clear()
	if _char_box == null:
		return
	for c in _char_box.get_children():
		_char_box.remove_child(c)
		c.queue_free()
	for i in _characters.size():
		var ch := _characters[i]
		var idx := i
		var b := _button(ch.display_name if ch.display_name != "" else String(ch.id), func(): choose_character(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_character_btns.append(b)
		_char_box.add_child(b)


## 096：预设套那一栏：「不带」+ 每套一个按钮（悬停看说明）
func _rebuild_presets() -> void:
	_preset_btns.clear()
	if _preset_box == null:
		return
	for c in _preset_box.get_children():
		_preset_box.remove_child(c)
		c.queue_free()
	var none := _button("不带预设", func(): choose_preset(-1))
	none.alignment = HORIZONTAL_ALIGNMENT_LEFT
	none.tooltip_text = "只带角色的初始包，其余从仓库拖"
	_preset_btns.append(none)
	_preset_box.add_child(none)
	var sets := flow.presets()
	for i in sets.size():
		var def := sets[i]
		var idx := i
		var b := _button(Names.of(def), func(): choose_preset(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = Names.description_of(def)
		_preset_btns.append(b)
		_preset_box.add_child(b)
	_color_presets()


func _color_presets() -> void:
	for k in _preset_btns.size():
		_preset_btns[k].add_theme_color_override("font_color", UiPalette.FG if k == preset_index + 1 else UiPalette.DIM)


## 096：挑一套预设（-1 = 不带）：棋盘上原来那套拿掉，新的免费放进初始包（放不下的在状态栏说）。从仓库带上的不动
func choose_preset(i: int) -> void:
	var sets := flow.presets()
	preset_index = clampi(i, -1, sets.size() - 1)
	_clear_preset()
	_apply_preset()
	_color_presets()
	_refresh()


func preset() -> LoadoutDef:
	var sets := flow.presets()
	return sets[preset_index] if preset_index >= 0 and preset_index < sets.size() else null


func _clear_preset() -> void:
	if board != null:
		for uid in _preset_uids:
			if board.get_item(int(uid)) != null:
				board.remove(int(uid))
	_preset_uids.clear()


## 把预设套的道具放上棋盘（和拖进包里一样自动找位置）。放不下的记在状态栏
func _apply_preset() -> void:
	var def := preset()
	if def == null or board == null:
		return
	var missed: Array[String] = []
	for id in def.items:
		var idef := flow.items.get_def(id)
		if idef == null:
			continue
		var inst := ItemInstance.create(idef, 0)
		inst.uid = flow.meta.allocate_uid()
		if board.try_add(inst, true):
			_preset_uids[inst.uid] = true
		else:
			missed.append(Names.of(idef))
	if not missed.is_empty() and _status != null:
		_status.text = "预设里放不下：%s（包太满；拿掉几件再选）" % "、".join(missed)


## 096：棋盘上预设套的实例
func preset_items() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if board == null:
		return out
	for inst in board.items():
		if _preset_uids.has((inst as ItemInstance).uid):
			out.append(inst)
	return out


## 换角色：带上的先放回仓库，按新角色的棋盘尺寸与初始包重摆
func choose_character(i: int) -> void:
	_return_carried()
	if not _characters.is_empty():
		character_index = clampi(i, 0, _characters.size() - 1)
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
	return _chapters[chapter_index] if chapter_index < _chapters.size() else null


func character() -> CharacterDef:
	return _characters[character_index] if character_index < _characters.size() else null


## 把仓库（或 090 暂存区）里的一件带上（自动找位置，和拖进包里一样）。放不进返回 false
func carry_in(uid: int) -> bool:
	if board == null:
		return false
	var from: ItemContainer = flow.meta.warehouse if flow.meta.warehouse.get_item(uid) != null else stash
	if from == null or from.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(from, uid, board)
	_refresh()
	return ok


## 090：把暂存区里的一件收进仓库（= 置入）。放不下返回 false
func store(uid: int) -> bool:
	if stash == null or stash.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(stash, uid, flow.meta.warehouse)
	_refresh()
	return ok


## 把棋盘上的一件放回仓库。包不行（它是初始包，不是仓库的东西）
func carry_out(uid: int) -> bool:
	if board == null:
		return false
	var inst := board.get_item(uid)
	if inst == null or not MetaState.keeps(inst.def) or _preset_uids.has(uid):
		return false     # 096：预设套的不进仓库
	var ok := InventoryService.transfer_auto(board, uid, flow.meta.warehouse)
	_refresh()
	return ok


## 094：现在带上的东西的总价值（预算按它算）
func carry_value() -> int:
	var v := 0
	for inst in carried():
		v += ItemValue.of(inst.def)
	return v


## 094：预算那一行：「带入预算 600：已带 420」/「超出 150 → 倒计时 −3（36 → 33）」
static func carry_text(c: ChapterDef, sid: StringName, value: int) -> String:
	var budget := CountdownModule.budget_for(c, sid)
	if budget <= 0:
		return ""
	var over := CountdownModule.over_for(c, sid, value)
	if over <= 0:
		return "[color=#5cb85c]带入预算 %d：已带 %d[/color]" % [budget, value]
	var penalty := CountdownModule.penalty_for(c, sid, value)
	var base := CountdownModule.base_limit_for(c, sid)
	if base > 0 and penalty > 0:
		return "[color=#f0ad4e]带入预算 %d：已带 %d，超出 %d → 倒计时 −%d（%d → %d）[/color]" % [budget, value, over, penalty, base, CountdownModule.limit_for(c, sid, value)]
	return "[color=#f0ad4e]带入预算 %d：已带 %d，超出 %d（这一章没有倒计时，只提示）[/color]" % [budget, value, over]


## 现在带上的（非包；096：预设套的不算 —— 它不占预算、不受件数上限）
func carried() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if board == null:
		return out
	for inst in board.items():
		if MetaState.keeps((inst as ItemInstance).def) and not _preset_uids.has((inst as ItemInstance).uid):
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
		run = flow.begin(c, null, run_seed, [] as Array[int], ch, RunState.layout_of(board), difficulty(), scale_id, carry_value())
	else:
		run = flow.begin(c, flow.default_loadout(), run_seed, [] as Array[int], null, [], difficulty(), scale_id)
	if run == null:
		_status.text = "这一章生成不出图：%s" % (c.map_source.last_error if c.map_source != null else "没有地图来源")
		return false
	# 090：进了游戏，留在暂存区的就没了（带回来的棋盘 begin 里已经清掉）
	if stash != null:
		stash.clear()
	_pending.clear()
	return true


## 不开了：带上的放回仓库，回主菜单。090：上一局带回来的原样放回带回来的棋盘（视为没发生过移动）
func cancel() -> void:
	_restore_pending()
	flow.to_main_menu()


## 090：Esc = 回主菜单（同「回主菜单」按钮）
func escape() -> bool:
	cancel()
	return true
#endregion


## 棋盘上带着的都下来：仓库来的回仓库；090 暂存区来的回暂存区
func _return_carried() -> void:
	if board == null:
		return
	for inst in carried():
		board.remove(inst.uid)
		if _pending.has(inst.uid) and stash != null:
			stash.insert(inst)
		elif not flow.meta.take_back(inst):
			push_warning("setup: %s 放不回仓库，丢弃" % inst.def.id)


## 090：回主菜单 —— 上一局带回来的（不管还在暂存区还是已经拖上了棋盘）按原位放回带回来的棋盘；
## 原位放不下（不该发生）就找位置，再不行进仓库。玩家已经拖进仓库的留在仓库（那是他自己置入的）
func _restore_pending() -> void:
	_return_carried()
	if stash == null:
		return
	var back := flow.meta.board
	for inst in stash.items():
		var it := inst as ItemInstance
		stash.remove(it.uid)
		if back == null:
			back = GridInventory.new(RunState.BOARD_SIZE, MetaState.BOARD_ID, false)
			flow.meta.board = back
		var rec: Dictionary = _pending.get(it.uid, {})
		var placed := rec.has("origin") and back.place(it, rec["origin"], int(rec.get("rot", 0)))
		if not placed and not back.try_add(it, true) and not flow.meta.take_back(it):
			push_warning("setup: %s 放不回带回来的棋盘也放不进仓库，丢弃" % it.def.id)
	_pending.clear()
	if back != null and back.item_count() == 0:
		flow.meta.board = null


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
	_preset_uids.clear()
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
	_board_host.add_child(_label("左键拖动　R 旋转　右键 / Esc 取消　右键信物 = 奉为主信仰", 11, UiPalette.DIM))
	_drag.register_view(_board_view)
	_board_view.item_context.connect(func(_v: ContainerView, uid: int): reseat_anchor(uid))     # 099：开局屏的棋盘同一套
	board.changed.connect(_refresh)
	_apply_preset()     # 096：挑着的预设套跟着角色换过来


## 099（作者定）：右键棋盘上的信物 = 奉它为主信仰（出发带走的就是这个顺序）。不是信物什么也不做
func reseat_anchor(uid: int) -> bool:
	var inst := board.get_item(uid) if board != null else null
	if inst == null or inst.def == null or not inst.def.is_anchor():
		return false
	return board.reseat(uid)


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
			if ch.skills_summary() != "":
				lines.append("技能：" + ch.skills_summary())
		var pre := preset()
		if pre != null:
			lines.append("预设「%s」：%s" % [Names.of(pre), Names.description_of(pre)])
		var d := difficulty()
		if d != null:
			lines.append("难度「%s」：%s" % [d.display_name, d.summary()])
		_desc.text = "\n".join(lines)
	if _readout != null and board != null:
		_readout.clear()
		# 091（作者定）：和背包面板一样的读数 —— 按这个角色的基线把棋盘编译一遍，预估 DPS 与耐力消耗实时变
		if ch != null:
			var spec := BattleCompiler.compile(board, ch.baseline(), [] as Array[StatModifier], [] as Array[AbilityRule], {})
			var est := StaminaEstimate.of(spec)
			_readout.append_text("生命 %d　预估 DPS %.1f　耐力消耗：%s（每秒 %.1f，回 %.1f）　%d 件会出手\n" % [
				spec.max_hp_int(), spec.rough_dps(), est["rating"], est["cost"], est["regen"], spec.active_items().size()])
		var value := 0
		var cells := 0
		var taken := carried()
		for inst in taken:
			value += ItemValue.of(inst.def)
			cells += inst.def.shape.cell_count() if inst.def.shape != null else 0
			_readout.append_text("　" + _item_line(inst.def) + "\n")
		if taken.is_empty():
			_readout.append_text("[color=#8b93a1]什么都还没带[/color]\n")
		if not preset_items().is_empty():
			_readout.append_text("[color=#8b93a1]预设套 %d 件（不算预算）[/color]\n" % preset_items().size())
		_readout.append_text("\n带 %d 件，占 %d 格，值 %d 币　包里还有 %d 格" % [taken.size(), cells, value, board.free_cell_count()])
		if c != null and CountdownModule.budget_for(c, scale_id) > 0:
			_readout.append_text("\n" + carry_text(c, scale_id, value))
	if _stash_title != null and stash != null:
		_stash_title.text = "暂存区　%d 件" % stash.item_count()
	if _status != null:
		var why := can_depart()
		_status.text = why if why != "" and not carried().is_empty() else ""

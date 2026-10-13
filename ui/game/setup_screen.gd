## 开局（M6，架构文档 8 节；058 第 2 条，报告 067）：挑一章、挑角色、往初始包里拖仓库的东西、定个种子，出发。
##
## 161（作者定）：拆成三页，一次只看一页、状态都在屏的字段里（换页不丢）：
## **一 选角色**（角色列表、角色卡 —— 名牌 + 生命 / 耐力方块 + 体力爱心 + 技能、这个角色的棋盘预览只看不拖）→
## **二 配道具**（预设装备、可拖的棋盘、地上、仓库 —— 仓库只在这一页）→ **三 选地图与难度**（模式、规模、难度、种子、出发摘要）。
## 每页右下角两颗大按钮：继续 / 出发（Enter）、返回（Esc；第一页的返回 = 回主菜单）。[method page] / [method next_page] / [method prev_page]。
##
## 第二页：中间是这个角色的棋盘（初始包已经摆好），右边是仓库的格子：从仓库往包里拖，**放得进的就是带的** ——
## 带入的真正限制是初始包的空间；件数 / 稀有度上限是角色的字段（默认不限），出发时查。
## 包不能带入：仓库里本来没有包（局外只收非包，`MetaState.keeps`），仓库的格子也不收包（同一条规则接在 `accept_filter` 上）。
## 拖上棋盘那一刻东西就离开了仓库；出发时存 meta，回主菜单就放回去。
## 所有动作都是公开方法（[method choose_chapter]、[method choose_character]、[method carry_in]、[method store]、[method depart]、[method cancel]），按钮只是调它们；测试直接调。
##
## **地上**（090，作者定）：上一局带回来、还没置入的东西（`MetaState.board`）进这一屏时挪进中间的地上（记住各自原位）。
## 往包里拖 = 带上、往仓库拖 = 置入、留着的**出发就没了**；回主菜单则原样放回带回来的棋盘（视为没发生过移动）。
## 仓库的东西进不了地上（会丢）。
##
## 没有角色定义时和没有章节一样：一条红字，开不了（140：作者数据里有三个角色，「按第一套开局装备开」的老路只留在 core 给测试）。
##
## **预设装备**（096，作者定）：角色之下一栏「预设装备」—— 不带 / 强攻（伤害高）/ 坚守（防御高）……（`LoadoutDef.preset`，数据里加一份就多一套）。
## 挑一套就把它的道具免费放进初始包：不从仓库拿、不算带入预算与件数上限、拖不进仓库 / 地上（只能在棋盘上挪），出发时带着走。
## 预设是底线（094）：仓库空也有一套能打的
extends GameScreen

## 地上容器的 id（局外的 100 / 101 之外）
const STASH_ID := 110

var chapter_index: int = 0
var character_index: int = 0
var difficulty_index: int = 0
## 096：挑的预设套在 [method GameFlow.presets] 里的下标；-1 = 不带
var preset_index: int = -1
## 096：棋盘上预设套的实例 uid → true（不算带入、不能拖去仓库）
var _preset_uids: Dictionary = {}
var _preset_btns: Array[Button] = []
var _preset_box: BoxContainer = null
## 085：地图规模（随机一局可选）；空 = 章节默认
var scale_id: StringName = &""
var _scale_btns: Dictionary = {}
var _scale_box: VBoxContainer
var run_seed: int = 1
## 这个角色的棋盘，初始包摆好；从仓库拖进来的东西就在上面。出发时整块记成 layout 交给 RunState
var board: GridInventory = null
## 090：地上 —— 上一局带回来、还没置入的东西
var stash: ItemStash = null
## 090：地上那些东西的来处：uid → {"origin", "rot"}（回主菜单按原位放回）
var _pending: Dictionary = {}
var _stash_box: VBoxContainer = null
var _stash_view: GroundLayer = null
var _stash_title: Label = null

## 083：开局屏列的章节（按解锁过滤、按 order 排）与这一章能选的角色
var _chapters: Array[ChapterDef] = []
var _characters: Array[CharacterDef] = []
var _char_box: VBoxContainer = null
var _warehouse_box: VBoxContainer = null
var _chapter_btns: Array[Button] = []
## 168：第三页顶上的章节名（大标题）
var _chapter_title: Label = null
var _character_btns: Array[Button] = []
var _difficulty_btns: Array[Button] = []
var _board_host: VBoxContainer
var _board_view: InventoryView = null
var _warehouse_view: InventoryView = null
## 163：仓库分页（[member _warehouse_view] 是它当前页的视图）
var _warehouse_pages: WarehousePages = null
var _desc: Label
var _readout: RichTextLabel = null
var _status: Label
## 161：右下角「继续 / 出发」与「返回」
var _enter_btn: Button
var _back_btn: Button
var _seed_spin: SpinBox
## 161：三页（0 选角色、1 配道具、2 选地图与难度）与现在是哪页
const PAGE_NAMES: Array[String] = ["选角色", "配道具", "选地图与难度"]
var _pages: Array[Control] = []
var _page: int = 0
var _title: Label = null
## 161：第一页的角色卡与棋盘预览、第三页的出发摘要
var _card: VBoxContainer = null
var _preview_host: VBoxContainer = null
var _preview_view: InventoryView = null
var _summary: RichTextLabel = null
## 157 补充三：石板里的内容区（[method GameScreen._slab_screen]）
var _area: Control = null


func open(_payload: Dictionary) -> void:
	_backdrop()
	run_seed = randi() % 1000000
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_bottom", 140)     # 161：底下留给右下角那两颗大按钮
	_area = _slab_screen()     # 157 补充三：三页都在一整块石板上
	_area.add_child(margin)
	var col := _vbox(14)
	margin.add_child(col)
	_title = _label("", 26, UiPalette.FG)
	col.add_child(_title)
	_chapters = flow.available_chapters()
	_pages.clear()
	for build in [_build_character_page, _build_kit_page, _build_map_page]:
		var page: Control = build.call()
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(page)
		_pages.append(page)
	_build_nav()
	choose_chapter(0)
	choose_difficulty(0)
	show_page(0)


## 161 第一页：角色列表 | 角色卡 | 棋盘预览（只看不拖）
func _build_character_page() -> Control:
	var row := _hbox(36)
	var left := _vbox(8)
	left.custom_minimum_size.x = 260
	row.add_child(left)
	left.add_child(_label("角色", 15, UiPalette.DIM))
	_char_box = _vbox(8)
	left.add_child(_char_box)
	if flow.characters.is_empty():
		left.add_child(_label("没有角色：先跑 tools/import_content.gd", 13, UiPalette.HP))
	_card = _vbox(10)
	_card.custom_minimum_size.x = 420
	row.add_child(_card)
	_preview_host = _vbox(6)
	row.add_child(_preview_host)
	return row


## 161 第二页：预设装备一行 + 棋盘（可拖）/ 地上 / 仓库，拖拽层盖在下面那一块上
func _build_kit_page() -> Control:
	var page := _vbox(12)
	if not flow.presets().is_empty():
		var presets := _hbox(8)
		presets.add_child(_label("预设装备", 15, UiPalette.DIM))
		_preset_box = presets
		page.add_child(presets)
		_rebuild_presets()

	# 棋盘与仓库在同一块矩形里，拖拽层盖在上面
	var play := MarginContainer.new()
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(play)
	var grids := _hbox(28)
	play.add_child(grids)

	_board_host = _vbox(6)
	grids.add_child(_board_host)

	# 090：中间是地上（有上一局带回来的东西才显示）
	_stash_box = _vbox(6)
	grids.add_child(_stash_box)

	_warehouse_box = _vbox(6)
	var right := _warehouse_box
	grids.add_child(right)
	var w := flow.meta.warehouse
	right.add_child(_label("仓库　%d 页，%d 件" % [w.page_count(), w.item_count()], 15, UiPalette.DIM))
	right.add_child(_wrapped("往左边的包里拖，放得进的就是带的；带进去的从仓库拿走，撤离了回来，死了就没了", 12, UiPalette.DIM, 480))

	_drag = DragLayer.new()
	_drag.label_font = font
	# 163：仓库分页 —— 左边竖排页签，拖着东西停在页签上切页
	_warehouse_pages = WarehousePages.new()
	right.add_child(_warehouse_pages)
	_warehouse_pages.setup(w, font, _drag, TechWarehousePages.plan_of(flow.tech_defs))
	_warehouse_view = _warehouse_pages.view
	play.add_child(_drag)     # 容器把它铺到和 grids 一样大，盖在两块格子上
	_drag.register_view(_warehouse_view)
	_warehouse_view.item_double_clicked.connect(quick_move)     # 109：双击 = 快速置入，和局内一样
	w.changed.connect(_refresh)
	_build_stash()
	return page


## 161 第三页：模式 | 说明、规模、难度、种子 | 出发摘要
func _build_map_page() -> Control:
	var row := _hbox(36)
	var left := _vbox(8)
	left.custom_minimum_size.x = 300
	row.add_child(left)
	left.add_child(_label("模式", 15, UiPalette.DIM))     # 114：序章之后只有自由模式（将来加章再长）
	var chapter_names: Array[String] = []
	for c in _chapters:
		chapter_names.append("%s（难度 %d）" % [c.display_name if c.display_name != "" else String(c.id), c.difficulty])
	_chapter_btns = _choice_column(left, chapter_names, choose_chapter)
	if _chapters.is_empty():
		left.add_child(_label("没有章节：先跑 tools/import_content.gd", 13, UiPalette.HP))

	var mid := _vbox(8)
	mid.custom_minimum_size.x = 380
	row.add_child(mid)
	_chapter_title = UiTheme.make_display("")     # 168：挑中的那一章，大标题（马善政）
	mid.add_child(_chapter_title)
	_desc = _wrapped("", 13, UiPalette.DIM, 380)
	mid.add_child(_desc)
	_scale_box = _vbox(6)
	mid.add_child(_scale_box)
	var avail := flow.available_difficulties()
	if not avail.is_empty():
		mid.add_child(_label("难度", 15, UiPalette.DIM))
		var difficulty_names: Array[String] = []
		for d in avail:
			difficulty_names.append(d.display_name if d.display_name != "" else String(d.id))
		_difficulty_btns = _choice_column(mid, difficulty_names, choose_difficulty)
	var seed_row := _hbox(8)
	seed_row.add_child(_label("种子", 13, UiPalette.DIM))
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 999999
	_seed_spin.value = run_seed
	_seed_spin.value_changed.connect(func(v: float): run_seed = int(v))
	seed_row.add_child(_seed_spin)
	seed_row.add_child(_button("随机", func(): set_run_seed(randi() % 1000000), 12, UiPalette.Tier.MINOR))
	mid.add_child(seed_row)

	var right := _vbox(8)
	right.custom_minimum_size.x = 340
	row.add_child(right)
	right.add_child(_label("出发摘要", 15, UiPalette.DIM))
	_summary = _log_box(14)
	_summary.scroll_following = false
	_summary.custom_minimum_size = Vector2(340, 200)
	right.add_child(_summary)
	return row


#region 161：翻页
func page() -> int:
	return _page


## 换到第 [param i] 页（0..2）：只显示那一页，标题与右下角按钮跟着变
func show_page(i: int) -> void:
	_page = clampi(i, 0, PAGE_NAMES.size() - 1)
	for k in _pages.size():
		_pages[k].visible = k == _page
	if _title != null:
		_title.text = "开局 · %s / 三　%s" % [["一", "二", "三"][_page], PAGE_NAMES[_page]]
	if _enter_btn != null:
		_enter_btn.text = "出发" if _page == PAGE_NAMES.size() - 1 else "继续"
	if _back_btn != null:
		_back_btn.text = "回主菜单" if _page == 0 else "返回"
	_refresh()


## 继续（最后一页 = 出发）。第一页没角色走不了
func next_page() -> bool:
	if _page >= PAGE_NAMES.size() - 1:
		return depart()
	if _page == 0 and character() == null:
		return false
	show_page(_page + 1)
	return true


## 返回（第一页 = 回主菜单）
func prev_page() -> void:
	if _page == 0:
		cancel()
	else:
		show_page(_page - 1)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		next_page()
		get_viewport().set_input_as_handled()
#endregion


## 090：地上那一栏。上一局带回来、还没置入的东西从带回来的棋盘挪进来，记住各自原位（回主菜单原样放回）
func _build_stash() -> void:
	stash = ItemStash.new(STASH_ID, 0)
	_pending = flow.meta.take_board_to_stash(stash)     # 101 第 4 刀：挪与记原位的账在 MetaState 里
	_stash_title = _label("", 15, UiPalette.DIM)
	_stash_box.add_child(_stash_title)
	_stash_box.add_child(_wrapped("上一局带回来、还没置入的东西先放在这儿。往包里拖 = 带上；往仓库拖 = 收进仓库；留在这儿的出发就没了；回主菜单则原样放回带回来的背包", 12, UiPalette.DIM, 240))
	_stash_view = GroundLayer.new()     # 128：一块地，放手在哪就落在哪
	_stash_view.label_font = font
	_stash_view.custom_minimum_size = Vector2(240, 320)
	_stash_view.stash = stash
	_stash_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stash_box.add_child(_stash_view)
	_drag.register_view(_stash_view)
	_stash_view.item_double_clicked.connect(quick_move)
	_drag.drop_filter = _allow_drop
	stash.changed.connect(_refresh)
	_stash_box.visible = not _pending.is_empty()


## 090：落点规则。仓库的东西进不了地上（进去就等于出发时丢掉）；地上的东西上棋盘要这一章允许带入
func _allow_drop(inst: ItemInstance, target: ItemContainer) -> bool:
	if inst == null:
		return false
	if target == stash:
		return _pending.has(inst.uid)
	if target == board and _pending.has(inst.uid):
		var c := chapter()
		return c == null or c.allow_carry_in
	if _preset_uids.has(inst.uid) and target != board:
		return false     # 096：预设套的东西只能在棋盘上挪，进不了仓库 / 地上
	return true


## 一列单选按钮（章节 / 难度 / 角色 / 预设 / 规模各一列）：每个名字一个左对齐的按钮，按下调 `on_pick(序号)`；
## 选中的是哪个由 [method _mark_choice] 标。返回这一列的按钮，顺序同 [param names]
func _choice_column(box: Control, names: Array[String], on_pick: Callable, size: int = 14) -> Array[Button]:
	var btns: Array[Button] = []
	for i in names.size():
		var idx := i
		var b := _button(names[i], func(): on_pick.call(idx), size)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btns.append(b)
		box.add_child(b)
	return btns


## 121：一列里第 [param index] 个是选中的（前景色），其余暗色（[method UiTheme.mark]）
func _mark_choice(btns: Array, index: int) -> void:
	for k in btns.size():
		UiTheme.mark(btns[k], k == index)


#region 公开动作
func choose_chapter(i: int) -> void:
	if _chapters.is_empty():
		return
	chapter_index = clampi(i, 0, _chapters.size() - 1)
	_mark_choice(_chapter_btns, chapter_index)
	if _chapter_title != null:
		_chapter_title.text = chapter().display_name if chapter().display_name != "" else String(chapter().id)
	# 083：这一章能选的角色、能不能从仓库带东西，都跟着章节变。
	# 161：章节在第三页才挑 —— 已经挑好的角色这一章也能用就留着（棋盘上带的东西不动），不能用才换回第一个
	var keep := character()
	_rebuild_characters()
	_rebuild_scales()
	if _warehouse_box != null:
		_warehouse_box.visible = chapter().allow_carry_in
	var at := _characters.find(keep) if keep != null else -1
	if at < 0 or board == null:
		choose_character(0)
		return
	character_index = at
	_mark_choice(_character_btns, character_index)
	if not chapter().allow_carry_in:
		_return_carried()
	_refresh()


## 角色按钮按这一章能选的重排
## 085：这一章的随机图有哪些规模（环形生成器的 `scales`）；预设图没有
func _rebuild_scales() -> void:
	UiTheme.clear_children(_scale_box)
	_scale_btns.clear()
	scale_id = &""
	var ch := chapter()
	var options := ch.map_source.scale_options() if ch != null and ch.map_source != null else [] as Array[Dictionary]
	if options.is_empty():
		return
	_scale_box.add_child(_label("地图规模", 15, UiPalette.DIM))
	var ids: Array[StringName] = [&""]
	var names: Array[String] = ["默认（章节配置）"]
	for o in options:
		var sid: StringName = o["id"]
		var limit := int(o.get("step_limit", 0))
		ids.append(sid)
		names.append(String(o["display_name"]) + ("　倒计时 %d" % limit if limit > 0 else ""))
	var btns := _choice_column(_scale_box, names, func(i: int): choose_scale(ids[i]), 13)
	for i in btns.size():
		_scale_btns[ids[i]] = btns[i]
	choose_scale(&"")


func choose_scale(id: StringName) -> void:
	scale_id = id if _scale_btns.has(id) else &""
	_mark_choice(_scale_btns.values(), _scale_btns.keys().find(scale_id))


func scale_options() -> Array:
	return _scale_btns.keys()


func _rebuild_characters() -> void:
	_characters = flow.characters_for(chapter())
	_character_btns.clear()
	if _char_box == null:
		return
	UiTheme.clear_children(_char_box)
	var names: Array[String] = []
	for ch in _characters:
		names.append(ch.display_name if ch.display_name != "" else String(ch.id))
	_character_btns = _choice_column(_char_box, names, choose_character)


## 096：预设套那一栏：「不带」+ 每套一个按钮（悬停看说明）
func _rebuild_presets() -> void:
	_preset_btns.clear()
	if _preset_box == null:
		return
	UiTheme.clear_children(_preset_box)
	var names: Array[String] = ["不带预设"]
	var tips: Array[String] = ["只带角色的初始包，其余从仓库拖"]
	for def in flow.presets():
		names.append(Names.of(def))
		tips.append(Names.description_of(def))
	_preset_btns = _choice_column(_preset_box, names, func(i: int): choose_preset(i - 1))     # 第 0 个是「不带」
	for i in _preset_btns.size():
		_preset_btns[i].tooltip_text = tips[i]
	_color_presets()


func _color_presets() -> void:
	_mark_choice(_preset_btns, preset_index + 1)     # 第 0 个是「不带」


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
	_mark_choice(_character_btns, character_index)
	_rebuild_board()
	_rebuild_card()
	_refresh()


## 挑难度（只在能选的里挑：没有解锁要求的和已解锁的）
func choose_difficulty(i: int) -> void:
	var avail := flow.available_difficulties()
	if avail.is_empty():
		return
	difficulty_index = clampi(i, 0, avail.size() - 1)
	_mark_choice(_difficulty_btns, difficulty_index)
	_refresh()


func difficulty() -> DifficultyDef:
	var avail := flow.available_difficulties()
	return avail[difficulty_index] if difficulty_index < avail.size() else null


func chapter() -> ChapterDef:
	return _chapters[chapter_index] if chapter_index < _chapters.size() else null


## 129：出发前就看见负重（带太多直接显示级数，不拦）。这一章不算负重 / 角色没配上限 → 空
func encumbrance_text() -> String:
	var c := chapter()
	var ch := character()
	if c == null or ch == null or c.encumbrance_rules == &"" or ch.weight_capacity <= 0 or board == null:
		return ""
	var path := ContentPaths.asset_file("encumbrance_rules", String(c.encumbrance_rules))
	var rules := load(path) as EncumbranceRules if ResourceLoader.exists(path) else null
	if rules == null:
		return ""
	var defs: Array = []
	for id in flow.meta_buffs():
		if flow.buff_defs.has(id):
			defs.append(flow.buff_defs[id])
	var cap := RunBuffs.context(defs).carry_capacity_of(ch.weight_capacity)     # 149：科技按百分比
	var w := ItemWeight.total(board)
	var lv := rules.level_of(w, cap)
	return "负重 %d / %d　%s%s" % [w, cap, rules.name_of(lv), "　" + rules.effect_text(lv) if lv > 0 else ""]


func character() -> CharacterDef:
	return _characters[character_index] if character_index < _characters.size() else null


## 把仓库（或 090 地上）里的一件带上（自动找位置，和拖进包里一样）。放不进返回 false
func carry_in(uid: int) -> bool:
	if board == null:
		return false
	var from: ItemContainer = flow.meta.warehouse if flow.meta.warehouse.get_item(uid) != null else stash
	if from == null or from.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(from, uid, board)
	_refresh()
	return ok


## 109（作者定）：开局屏的双击快速置入，和局内（084 [method InventoryPanel.quick_move]）同一个形状：
## 仓库 / 地上 → 初始包的棋盘；棋盘 → 仓库（初始包自己、预设套的不行）。放不下原地不动，状态行说一句。拖拽那套不动
func quick_move(view: ContainerView, uid: int) -> bool:
	var from := view.container() if view != null else null
	var inst := from.get_item(uid) if from != null else null
	if inst == null:
		return false
	var why := ""
	var ok := false
	if flow.meta.warehouse.owns(from) or from == stash:
		if board == null:
			return false
		if not _allow_drop(inst, board):
			why = "这一章不许把带回来的东西带进去"
		else:
			ok = carry_in(uid)
			why = "" if ok else "包里没有空间放「%s」" % Names.of(inst.def)
	elif from == board:
		if not MetaState.keeps(inst.def):
			why = "「%s」是初始包，留在棋盘上" % Names.of(inst.def)
		elif _preset_uids.has(uid):
			why = "预设套的东西只能在棋盘上挪"
		else:
			ok = carry_out(uid)
			why = "" if ok else "仓库放不下「%s」" % Names.of(inst.def)
	if why != "" and _status != null:
		_status.text = why
	return ok


## 090：把地上的一件收进仓库（= 置入）。放不下返回 false
func store(uid: int) -> bool:
	if stash == null or stash.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(stash, uid, flow.meta.warehouse)
	if ok and _warehouse_pages != null:
		_warehouse_pages.show_item(uid)
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
	if ok and _warehouse_pages != null:
		_warehouse_pages.show_item(uid)     # 163：放回落到哪页就翻到哪页
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
	var ch := character()
	if ch == null:
		return "没有角色可选"
	var defs: Array = []
	for inst in carried():
		defs.append(inst.def)
	return ch.carry_problem(defs)


## 反馈（紧急）：左边那一列比窗口还高，原来放在列尾的「出发」按钮被挤出了屏幕，开局没有入口。
## 按钮钉在屏幕右下角（不跟着列走），又大又醒目；开不了的原因（超上限、生成不出图）也写在它上面，窗口再矮都看得见。
## 161：两颗并排 —— 「返回」（次档）与「继续 / 出发」（主档），一样大
func _build_nav() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -36
	box.offset_bottom = -36
	_status = _wrapped("", 13, UiPalette.HP, 520)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_status)
	var row := _hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_END
	_back_btn = _button("返回", prev_page, 24, UiPalette.Tier.MINOR)
	_back_btn.custom_minimum_size = Vector2(240, 76)
	row.add_child(_back_btn)
	_enter_btn = _button("继续", func(): next_page(), 24, UiPalette.Tier.PRIMARY)
	_enter_btn.custom_minimum_size = Vector2(280, 76)
	row.add_child(_enter_btn)
	box.add_child(row)
	_area.add_child(box)


## 出发。开不了（生成不出图、超上限）返回 false，留在这一屏说明原因
func depart() -> bool:
	var why := can_depart()
	if why != "":
		_status.text = why
		return false
	var c := chapter()
	var ch := character()
	var run := flow.begin(c, null, run_seed, [] as Array[int], ch, RunState.layout_of(board), difficulty(), scale_id, carry_value())
	if run == null:
		_status.text = "这一章生成不出图：%s" % (c.map_source.last_error if c.map_source != null else "没有地图来源")
		return false
	# 090：进了游戏，留在地上的就没了（带回来的棋盘 begin 里已经清掉）
	if stash != null:
		stash.clear()
	_pending.clear()
	return true


## 不开了：带上的放回仓库，回主菜单。090：上一局带回来的原样放回带回来的棋盘（视为没发生过移动）
func cancel() -> void:
	_restore_pending()
	flow.to_main_menu()


## 090：Esc = 回主菜单（同「回主菜单」按钮）。161：第二、三页的 Esc = 回上一页
func escape() -> bool:
	prev_page()
	return true
#endregion


## 棋盘上带着的都下来：仓库来的回仓库；090 地上来的回地上
func _return_carried() -> void:
	if board == null:
		return
	for inst in carried():
		board.remove(inst.uid)
		if _pending.has(inst.uid) and stash != null:
			stash.insert(inst)
		elif not flow.meta.take_back(inst):
			push_warning("setup: %s 放不回仓库，丢弃" % inst.def.id)


## 090：回主菜单 —— 上一局带回来的（不管还在地上还是已经拖上了棋盘）按原位放回带回来的棋盘；
## 原位放不下（不该发生）就找位置，再不行进仓库。玩家已经拖进仓库的留在仓库（那是他自己置入的）
func _restore_pending() -> void:
	_return_carried()
	if stash == null:
		return
	for id in flow.meta.return_stash(stash, _pending):     # 101 第 4 刀：放回的账在 MetaState 里
		push_warning("setup: %s 放不回带回来的棋盘也放不进仓库，丢弃" % id)
	_pending.clear()


## 按角色造棋盘：初始包摆好。包的 uid 走局外的号段，免得和从仓库拖来的撞号
func _rebuild_board() -> void:
	UiTheme.clear_children(_board_host)
	if _board_view != null and _drag != null:
		_drag.unregister_view(_board_view)
	_board_view = null
	_readout = null
	board = null
	_preset_uids.clear()
	var ch := character()
	if ch == null:     # 140：没有角色就没有棋盘（左栏那条红字说明了）
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
	_board_view.item_double_clicked.connect(quick_move)     # 109：每次重建棋盘视图都要重新接
	board.changed.connect(_refresh)
	_apply_preset()     # 096：挑着的预设套跟着角色换过来


## 161：第一页的角色卡（名牌、生命 / 耐力方块、体力爱心、技能）与棋盘预览（只看不拖）
func _rebuild_card() -> void:
	if _card == null:
		return
	UiTheme.clear_children(_card)
	UiTheme.clear_children(_preview_host)
	_preview_view = null
	var ch := character()
	if ch == null:
		return
	_card.add_child(Nameplate.new().setup(Names.of(ch), "角色", Nameplate.character_face(ch.id)))
	_card.add_child(_wrapped(Names.description_of(ch), 13, UiPalette.DIM, 420))
	var base := ch.baseline()
	_card.add_child(_stat_row("生命", StatBlocks.new().setup(StatBlocks.HP, base.value_of(&"max_hp"))))
	var stamina := _stat_row("耐力", StatBlocks.new().setup(StatBlocks.STAMINA, base.value_of(&"max_stamina")))
	stamina.add_child(_label("每秒回 %s" % _num(base.value_of(&"regen_stamina")), 12, UiPalette.DIM))     # 161 待定 1：三人唯一不同的第三个数
	_card.add_child(stamina)
	_card.add_child(_stat_row("体力", StatBlocks.new().setup(StatBlocks.VITALITY, ch.vitality_max)))
	_card.add_child(_label("一块 10 点；角色自己的底子，不含科技加成", 11, UiPalette.DIM))
	_card.add_child(_wrapped(caps_text(ch), 13, UiPalette.DIM, 420))
	for line in ch.skill_lines():
		_card.add_child(_wrapped(line, 13, UiPalette.FG, 420))
	if board == null:
		return
	_preview_host.add_child(_label("棋盘　%d × %d 格" % [ch.board_size.x, ch.board_size.y], 15, UiPalette.DIM))
	_preview_view = InventoryView.new()
	_preview_view.label_font = font
	_preview_view.inventory = board
	_preview_view.show_adjacency = false
	_preview_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_preview_host.add_child(_preview_view)
	_preview_host.add_child(_label("背包：%s" % bags_text(ch), 13, UiPalette.DIM))


## 角色卡上方块之外的那几项：负重上限、棋盘、开局钱、带入上限（136 / 149；161 从说明栏挪到角色卡）
static func caps_text(ch: CharacterDef) -> String:
	var caps: Array[String] = []
	if ch.weight_capacity > 0:
		caps.append("负重上限 %d" % ch.weight_capacity)
	caps.append("棋盘 %d × %d" % [ch.board_size.x, ch.board_size.y])
	if ch.starting_funds >= 0:
		caps.append("开局钱 %d" % ch.starting_funds)
	if ch.carry_max_items >= 0:
		caps.append("最多带 %d 件" % ch.carry_max_items)
	if ch.carry_rarity_cap >= 0:
		caps.append("稀有度不超过 %d" % ch.carry_rarity_cap)
	return "　".join(caps)


## 161：「皮革包 × 2、小包」
func bags_text(ch: CharacterDef) -> String:
	var counts := {}
	var order: Array[StringName] = []
	for id in ch.starting_bags:
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	var parts: Array[String] = []
	for id in order:
		var def := flow.items.get_def(id)
		var name := Names.of(def) if def != null else String(id)
		parts.append(name if int(counts[id]) == 1 else "%s × %d" % [name, counts[id]])
	return "、".join(parts) if not parts.is_empty() else "无"


func _stat_row(title: String, blocks: StatBlocks) -> HBoxContainer:
	var row := _hbox(10)
	var l := _label(title, 15, UiPalette.FG)
	l.custom_minimum_size.x = 44
	row.add_child(l)
	row.add_child(blocks)
	return row


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## 161：第三页的出发摘要（角色、带了几件、负重、模式与难度）
func summary_text() -> String:
	var lines: Array[String] = []
	var ch := character()
	if ch != null:
		lines.append("角色　%s" % Names.of(ch))
	var taken := carried().size()
	var pre := preset_items().size()
	lines.append("带上　%d 件%s" % [taken, "（另有预设 %d 件）" % pre if pre > 0 else ""])
	var enc := encumbrance_text()
	if enc != "":
		lines.append(enc)
	var c := chapter()
	if c != null:
		lines.append("模式　%s" % (c.display_name if c.display_name != "" else String(c.id)))
	var d := difficulty()
	if d != null:
		lines.append("难度　%s" % d.display_name)
	return "\n".join(lines)


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
			var spec := BattleCompiler.compile_board(board, ch.baseline(), [] as Array[StatModifier], [] as Array[AbilityRule], {})
			var est := StaminaEstimate.of(spec)
			_readout.append_text("生命 %d　预估 DPS %.1f　耐力消耗：%s（每秒 %.1f，回 %.1f）　%d 件会出手\n" % [
				spec.max_hp_int(), spec.rough_dps(), est["rating"], est["cost"], est["regen"], spec.active_items().size()])
		var value := 0
		var cells := 0
		var taken := carried()
		for inst in taken:
			value += ItemValue.of(inst.def)
			cells += inst.def.cell_count()
			_readout.append_text("　" + _item_line(inst.def) + "\n")
		if taken.is_empty():
			_readout.append_text("[color=#8b93a1]什么都还没带[/color]\n")
		var preset_count := preset_items().size()
		if preset_count > 0:
			_readout.append_text("[color=#8b93a1]预设套 %d 件（不算预算）[/color]\n" % preset_count)
		_readout.append_text("\n带 %d 件，占 %d 格，值 %d 币　包里还有 %d 格" % [taken.size(), cells, value, board.free_cell_count()])
		if c != null and CountdownModule.budget_for(c, scale_id) > 0:
			_readout.append_text("\n" + carry_text(c, scale_id, value))
		var enc_line := encumbrance_text()
		if enc_line != "":
			_readout.append_text("\n" + enc_line)
	if _stash_title != null and stash != null:
		_stash_title.text = "地上　%d 件" % stash.item_count()
	if _summary != null:
		_summary.text = summary_text()
	if _enter_btn != null:
		_enter_btn.disabled = _page == 0 and ch == null
	if _status != null:
		var why := can_depart()
		_status.text = why if why != "" and not carried().is_empty() else ""


## 读数里一件道具的一行：名字（按稀有度上色）、几格、值多少
func _item_line(def: ItemDef) -> String:
	if def == null:
		return "?"
	var cells := def.cell_count()
	return "[color=#%s]%s[/color]  %d 格  %d 币" % [ItemPainter.rarity_color(def).to_html(false), def.display_name, cells, ItemValue.of(def)]

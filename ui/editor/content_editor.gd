## 道具编辑器（架构文档 10.4）—— 给开发者与 MOD 作者。
##
## 左边选道具，中间改属性，右边画形状、看校验、看 JSON。存盘存的是
## `data/authoring/items/<id>.json`，跟命令行导入器吃的是同一种文件 ——
## **界面不是另一条通路，只是同一条通路的另一个入口。**
##
## 三件事让它对 MOD 作者成立：
##
## 1. 表单**由反射生成**（[PropertyForm]），效果类型下拉框来自 [EffectRegistry]。
##    新增一种效果＝加一个脚本 + 登记一行，编辑器自动认得，本文件不用改。
## 2. **实时校验走的就是导入器本身**，不是另写一份规则 ——
##    界面上说没问题，命令行就一定过得去。
## 3. **JSON 预览始终可见**，而且能直接改了套用：作者随时看得见自己在写什么文件，
##    界面覆盖不到的角落也不会把人挡在外面。
##
## 保存**同时产出 JSON 与 .tres**，不需要再手动跑一次命令行导入器。
## 产出 .tres 走的就是导入器那条路（先导出成 JSON、再导入回来），
## 所以界面存出来的东西和命令行存出来的逐字节相同 ——
## 「省一步」不能以「两条路产出不同的资产」为代价。
##
## 列表 / 草稿 / 判脏 / 存盘这一段与别的三个内容编辑器共用，在 [AuthoringEditor]（141）。这里多的是分类页签、形状画板与战斗力面板。
##
## 151（作者定）：右栏的「战斗力」面板（[PowerPanel]）—— 表单一改就按 [PowerEstimate] 重算，列逐项贡献，给推荐稀有度与价值，「采用」才写回。
## 「新建武器」：先画形状，第一次改形状时按格数预填一套能打的攻击力、冷却与耐力（默认战斗力），之后改哪个数战斗力跟着走
extends AuthoringEditor

## 作者数据目录。资产目录见 [ContentPaths]。
const ITEM_DIR := ContentPaths.AUTHORING_ITEMS

## 分类页签的三种形态。
##
## 不用「哨兵字符串」表示「无标签」那一页：标签是作者自己起的名字，
## 挑哪个词当哨兵都可能撞上，而撞上的表现是某个标签页莫名其妙变成了另一页。
enum Filter { ALL, TAG, UNTAGGED }

## 144：标签页签上面的一级分组。「有效果」由 [method ItemDef.has_effect] 算，不是标签
enum Group { ALL, EFFECT, PLAIN }

## 当前分类筛选之后，列表里实际显示的 id，**按显示顺序**。
##
## 与 [member _ids] 分开：ItemList 的行号对应的是这一份，不是全集。
## 两者混用的表现是「点第三行打开了第五件」—— 一加筛选就错，而且错得很隐蔽。
var _shown: Array[String] = []

## 分类筛选。[constant Filter.TAG] 时看 [member _filter_tag]。
var _filter: Filter = Filter.ALL
var _filter_tag: String = ""
var _group: Group = Group.ALL

## 列表键 → 名字（显示名 + 各语言名）/ 有没有效果。和 [member _tags_of] 一样在列表重读时从盘上读一次
var _names_of: Dictionary = {}
var _effect_of: Dictionary = {}

## 列表键 → 它的标签。标签是**从数据里读出来的**，不是写死的表 ——
## MOD 作者加一个新标签，分类页签就该自己多出来一个。
var _tags_of: Dictionary = {}

var _tab_host: VBoxContainer
var _group_host: HBoxContainer
var _search: LineEdit
var _form_host: VBoxContainer
var _shape: ShapeEditor
var _id_edit: LineEdit
## JSON 预览（就是基类的 [member _json]，测试按这个名字读）
var _preview: TextEdit
## 151：战斗力面板
var _power: PowerPanel
var _power_weights: PowerWeights = null
## 151：新建的武器还没画形状：第一次改形状时预填（记着刚建好时的形状，和它不一样就是改过了）
var _weapon_shape_at_bind: String = ""
var _layer_buttons: Array[Button] = []


func _init() -> void:
	_kind = "items"


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_build_ui()
	_start()


#region 界面
func _build_ui() -> void:
	UiTheme.prepare_root(self)     # 091 / 121：底色跟设置走、装上界面主题

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var columns := HSplitContainer.new()
	margin.add_child(columns)

	# --- 左：分类页签 + 道具列表 ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 290
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(UiTheme.make_label("道具", 16, UiPalette.FG))

	# 144：分组行横跨整个总览，标签页签在当前分组里长出来
	_group_host = HBoxContainer.new()
	for g in [Group.ALL, Group.EFFECT, Group.PLAIN]:
		_group_host.add_child(_group_button(g))
	left.add_child(_group_host)

	var browse := HBoxContainer.new()
	browse.add_theme_constant_override("separation", 6)
	browse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(browse)

	# 页签竖排。标签数量由内容决定，可能比窗口高 —— 套个滚动容器，
	# 不然加到第十几个标签时最后几个就够不着了
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size.x = 104
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browse.add_child(tab_scroll)
	_tab_host = VBoxContainer.new()
	_tab_host.add_theme_constant_override("separation", 2)
	_tab_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(_tab_host)

	var list_col := VBoxContainer.new()
	list_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse.add_child(list_col)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索 id / 名字 / 标签"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _repaint_list())
	_search.gui_input.connect(_on_search_input)
	list_col.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 空列表那一行灰字不在 _shown 里
	_list.item_selected.connect(func(i: int) -> void:
		if i < _shown.size():
			_open(_shown[i]))
	list_col.add_child(_list)
	var list_buttons := HBoxContainer.new()
	list_buttons.add_child(UiTheme.make_button("新建", _new_item, UiTheme.TIER_PLAIN, 13))
	list_buttons.add_child(UiTheme.make_button("新建武器", new_weapon, UiTheme.TIER_PLAIN, 13))
	list_buttons.add_child(UiTheme.make_button("刷新列表", _on_rescan, UiTheme.TIER_PLAIN, 13))
	list_buttons.add_child(UiTheme.make_button("放弃改动", _on_discard, UiTheme.TIER_PLAIN, 13))
	left.add_child(list_buttons)

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_split)

	# --- 中：表单 ---
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(mid)

	var id_row := HBoxContainer.new()
	id_row.add_child(UiTheme.make_label("id", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 150
	_id_edit.text_changed.connect(_on_id_changed)
	id_row.add_child(_id_edit)
	id_row.add_child(UiTheme.make_button("保存", _save, UiTheme.TIER_PLAIN, 13))
	id_row.add_child(UiTheme.make_button("另存为新 id", _save_as, UiTheme.TIER_PLAIN, 13))
	mid.add_child(id_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form_host)

	# --- 右：形状 / 校验 / 预览 ---
	var side_col := VBoxContainer.new()
	side_col.custom_minimum_size.x = 330
	side_col.add_theme_constant_override("separation", 8)
	right_split.add_child(side_col)

	side_col.add_child(UiTheme.make_label("形状与邻接标记", 14, UiPalette.FG))

	# 画哪一层。标记格和形状必须在同一张网格上 ——
	# 「加成的是上下相邻那一格」是条相对偏移，脱离形状就看不出来。
	var layer_row := HBoxContainer.new()
	layer_row.add_theme_constant_override("separation", 4)
	for spec in [
		[ShapeEditor.Layer.SHAPE, "占格", UiPalette.FG],
		[ShapeEditor.Layer.GRANT, "增益格", UiPalette.GRANT],
		[ShapeEditor.Layer.RECEIVE, "受益格", UiPalette.RECEIVE],
	]:
		var which: int = spec[0]
		var b := UiTheme.make_button(spec[1], func(): _set_layer(which), UiTheme.TIER_PLAIN, 13)
		b.add_theme_color_override("font_color", spec[2])
		_layer_buttons.append(b)
		layer_row.add_child(b)
	side_col.add_child(layer_row)

	_shape = ShapeEditor.new()
	_shape.label_font = _font
	_shape.changed.connect(_refresh)
	side_col.add_child(_shape)

	var grid_row := HBoxContainer.new()
	grid_row.add_child(UiTheme.make_label("画板", 12, UiPalette.DIM))
	for wh in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4), Vector2i(2, 4), Vector2i(4, 2)]:
		var size := wh as Vector2i
		grid_row.add_child(UiTheme.make_button(
			"%dx%d" % [size.x, size.y], func(): _shape.grow_to(size.x, size.y), UiTheme.TIER_PLAIN, 13
		))
	side_col.add_child(grid_row)

	_power = PowerPanel.new()
	_power.adopt_requested.connect(adopt_power)
	side_col.add_child(_power)

	side_col.add_child(UiTheme.make_label("校验", 14, UiPalette.FG))
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size.y = 100
	_status.add_theme_font_override("normal_font", _font)
	_status.add_theme_font_size_override("normal_font_size", 12)
	side_col.add_child(_status)

	side_col.add_child(UiTheme.make_label("JSON（可直接改）", 12, UiPalette.DIM))
	_preview = TextEdit.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.add_theme_font_size_override("font_size", 12)
	side_col.add_child(_preview)
	_json = _preview
	side_col.add_child(UiTheme.make_button("套用上面的 JSON", _apply_json, UiTheme.TIER_PLAIN, 13))


func _set_layer(which: int) -> void:
	_shape.layer = which as ShapeEditor.Layer
	for i in _layer_buttons.size():
		_layer_buttons[i].flat = i != which
	_shape.queue_redraw()
#endregion


#region 文件
## 列表重读之后读一遍各件的标签、名字和有没有效果（页签、分组与搜索用）
func _on_list_reloaded() -> void:
	_tags_of.clear()
	_names_of.clear()
	_effect_of.clear()
	for id in _ids:
		_read_meta(id)


## 标签和名字走 JSON 而不是导入器：这里不关心内容对不对，
## 一件配错的道具照样得出现在列表里，否则作者就没法进去修它。
## 有没有效果得看定义，才过一遍导入器；导不进来的算没效果（照样列出来）
func _read_meta(id: String) -> void:
	var tags: Array[String] = []
	var names: Array[String] = []
	var parsed = JSON.parse_string(
		FileAccess.get_file_as_string(ITEM_DIR + "/" + id + ".json"))
	var effect := false
	if parsed is Dictionary:
		var data := parsed as Dictionary
		for t in (data.get("tags", []) as Array):
			tags.append(String(t))
		names.append(String(data.get("display_name", "")))
		var by_lang = data.get("display_names", {})
		if by_lang is Dictionary:
			for lang in by_lang:
				names.append(String(by_lang[lang]))
		var def = _import(data, ImportReport.new())
		effect = def != null and (def as ItemDef).has_effect()
	_tags_of[id] = tags
	_names_of[id] = names
	_effect_of[id] = effect


## 内存里那一份（当前打开的、草稿）；没有返回 null
func _live(id: String) -> ItemDef:
	if id == _draft_key() and _def != null:
		return _def
	return _drafts.get(id, null)


## 内存里那一份的标签盖掉盘上的 —— 作者刚加的标签，页签就该跟着变。
func _tags_for(id: String) -> Array[String]:
	var live := _live(id)
	if live == null:
		return _tags_of.get(id, [] as Array[String])
	var out: Array[String] = []
	for t in live.tags:
		out.append(String(t))
	return out


func _has_effect(id: String) -> bool:
	var live := _live(id)
	return live.has_effect() if live != null else bool(_effect_of.get(id, false))


func _in_group(id: String, group: Group) -> bool:
	match group:
		Group.EFFECT:
			return _has_effect(id)
		Group.PLAIN:
			return not _has_effect(id)
		_:
			return true


## 144：搜索 = 不分大小写的子串，对 id、各语言名字、标签 id 与标签显示名（说明文字不搜，太散）
func _matches_search(id: String) -> bool:
	var q := _search.text.strip_edges().to_lower() if _search != null else ""
	if q == "":
		return true
	var hay: Array[String] = [id]
	var live := _live(id)
	if live != null:
		hay.append(live.display_name)
		for lang in live.display_names:
			hay.append(String(live.display_names[lang]))
	else:
		hay.append_array(_names_of.get(id, [] as Array[String]))
	for t in _tags_for(id):
		hay.append(t)
		hay.append(TagRegistry.name_of(StringName(t)))
	for s in hay:
		if s.to_lower().contains(q):
			return true
	return false


## 分组 + 搜索之后还在的（页签计数按这一份算）
func _visible_base(id: String) -> bool:
	return _in_group(id, _group) and _matches_search(id)


## 当前分组里出现过的标签，按名字排序。**从内容里长出来，不是写死的枚举** ——
## MOD 作者加一个标签，这里自己就多一页。
func _all_tags() -> Array[String]:
	var seen := {}
	for id in _ids:
		if not _in_group(id, _group):
			continue
		for t in _tags_for(id):
			seen[t] = true
	var out: Array[String] = []
	for t in seen:
		out.append(t)
	out.sort()
	return out


## 分组 AND 搜索 AND 标签页签
func _matches_filter(id: String) -> bool:
	if not _visible_base(id):
		return false
	match _filter:
		Filter.ALL:
			return true
		Filter.UNTAGGED:
			return _tags_for(id).is_empty()
		_:
			return _tags_for(id).has(_filter_tag)


## 重建分类页签。只在标签集合真的变了时才拆重建 ——
## 每次刷新都重建的话，点下去的那一瞬按钮就被换掉，焦点和悬停全丢。
func _rebuild_tabs() -> void:
	# 每一页记成 [模式, 标签名]，顺序就是显示顺序
	var wanted: Array = [[Filter.ALL, ""]]
	for t in _all_tags():
		wanted.append([Filter.TAG, t])
	for id in _ids:
		if _in_group(id, _group) and _tags_for(id).is_empty():
			wanted.append([Filter.UNTAGGED, ""])
			break

	var current: Array = []
	for child in _tab_host.get_children():
		current.append((child as Button).get_meta("page"))
	if current != wanted:
		UiTheme.clear_children(_tab_host)
		for page in wanted:
			_tab_host.add_child(_tab_button(page))

	# 选中的那一页可能刚刚没了（最后一件带该标签的被改了标签）
	if not wanted.has([_filter, _filter_tag]):
		_filter = Filter.ALL
		_filter_tag = ""

	for child in _tab_host.get_children():
		var b := child as Button
		var page: Array = b.get_meta("page")
		b.button_pressed = page == [_filter, _filter_tag]
		b.text = "%s %d" % [_tab_label(page), _count_of(page)]

	for child in _group_host.get_children():
		var b := child as Button
		var g: Group = b.get_meta("group")
		b.button_pressed = g == _group
		var n := 0
		for id in _ids:
			if _in_group(id, g) and _matches_search(id):
				n += 1
		b.text = "%s %d" % [GROUP_LABELS[g], n]


## 计数按「分组 + 搜索」算：搜着的时候「武器 3」就是搜到的三把
func _count_of(page: Array) -> int:
	var n := 0
	for id in _ids:
		if not _visible_base(id):
			continue
		match page[0]:
			Filter.ALL:
				n += 1
			Filter.UNTAGGED:
				if _tags_for(id).is_empty():
					n += 1
			_:
				if _tags_for(id).has(String(page[1])):
					n += 1
	return n


func _tab_label(page: Array) -> String:
	match page[0]:
		Filter.ALL:
			return "全部"
		Filter.UNTAGGED:
			return "无标签"
		_:
			return String(page[1])


func _tab_button(page: Array) -> Button:
	var b := Button.new()
	b.set_meta("page", page)
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		_filter = page[0]
		_filter_tag = String(page[1])
		_repaint_list()
	)
	return b


const GROUP_LABELS := {Group.ALL: "全部", Group.EFFECT: "有效果", Group.PLAIN: "无效果"}


func _group_button(g: Group) -> Button:
	var b := Button.new()
	b.set_meta("group", g)
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		_group = g
		_repaint_list()
	)
	return b


func _on_search_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_search.clear()
		_repaint_list()
		_search.accept_event()


## 有未保存改动的条目前面加一个点。没有这个标记，作者就得靠记忆。
func _repaint_list() -> void:
	_rebuild_tabs()
	_shown.clear()
	_list.clear()
	for id in _ids:
		if _matches_filter(id):
			_shown.append(id)
			_list.add_item(("● " if _drafts.has(id) else "") + id)
	if _shown.is_empty():
		var row := _list.add_item("没有匹配的道具")
		_list.set_item_selectable(row, false)
		_list.set_item_custom_fg_color(row, UiPalette.DIM)
	# 按 id 选回去，不按行号 —— 换一页之后行号指向的是另一件东西
	var i := _shown.find(_draft_key())
	if i >= 0:
		_list.select(i)


func _on_id_changed(text: String) -> void:
	if _def != null:
		_def.id = StringName(text)
	_refresh()


func _export(d) -> Dictionary:
	return ContentExporter.export_item(d)


## 道具每次都用一份新的上下文（不对着别的内容查）
func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_item(data, ContentLibrary.context(), report)     # 146：道具里按 id 引用的 buff、「@构件」得查得到


func _on_bound() -> void:
	_id_edit.text = String(_def.id)
	_shape.set_from(_def.shape, _def.adjacency)
	_set_layer(ShapeEditor.Layer.SHAPE)
	_rebuild_form()


func _new_def() -> Resource:
	var def := ItemDef.new()
	def.id = &"new_item"
	def.display_name = "新道具"
	def.shape = ItemShape.from_bits("1")
	return def


func _new_item() -> void:
	_new_entry()
	_select_in_list(_draft_key())


## 151：新建一件武器 —— 带 weapon 标签、先画形状；第一次改形状时预填默认那一套（[method PowerEstimate.default_weapon]）
func new_weapon() -> void:
	_new_entry()
	_def.tags.append(&"weapon")
	_weapon_shape_at_bind = _def.shape.to_bits() if _def.shape != null else ""
	_set_layer(ShapeEditor.Layer.SHAPE)
	_rebuild_form()
	_refresh()
	_select_in_list(_draft_key())


## 新建的武器、还没有战斗数据、形状和刚建好时不一样了 → 预填
func _maybe_prefill_weapon() -> void:
	if _current_id != "" or _def.combat != null or not _def.tags.has(&"weapon") or _def.shape == null:
		return
	if _def.shape.to_bits() == _weapon_shape_at_bind:
		return
	var d := PowerEstimate.default_weapon(_def.cell_count(), _weights())
	var prof := CombatProfile.new()
	prof.base_stats = {"damage": d["damage"]}
	var rule := AbilityRule.new()
	rule.trigger = OnSchedule.new()
	var cd := CooldownCadence.new()
	cd.seconds = d["cooldown"]
	rule.cadence = cd
	var cost := ResourceCost.new()
	cost.amount = d["stamina"]
	rule.costs.append(cost)
	rule.effects.append(DealDamage.new())
	prof.rules.append(rule)
	_def.combat = prof
	_rebuild_form()


func _weights() -> PowerWeights:
	if _power_weights == null:
		_power_weights = PowerWeights.load_from()
	return _power_weights


## 151：「采用」—— 把推荐的稀有度与价值写进道具
func adopt_power() -> void:
	var est := _power.estimate
	if _def == null or est == null or est.rarity < 0:
		return
	_def.rarity = est.rarity
	_def.value = est.value
	_rebuild_form()
	_refresh()


## 151：现在这件的战斗力明细（测试读）
func power_estimate() -> PowerEstimate.Breakdown:
	return _power.estimate


func _select_in_list(id: String) -> void:
	# 当前筛选里没有它，就把分组、搜索、标签页签全退回去：选中一件看不见的东西等于没选
	if not _matches_filter(id):
		_group = Group.ALL
		_search.text = ""
		_filter = Filter.ALL
		_filter_tag = ""
		_repaint_list()
	var i := _shown.find(id)
	if i >= 0 and i < _list.item_count:
		_list.select(i)


#endregion


#region 刷新
func _rebuild_form() -> void:
	UiTheme.clear_children(_form_host)
	if _def == null:
		return
	# id 在顶栏、形状有画板 —— 表单里跳过，免得两处能改同一个值
	# 画板上能画的东西，表单里一律不给第二个入口
	_form_host.add_child(_form_for(_def, {
		"ItemDef": ["id", "shape"],
		"AdjacencyProfile": ["grant_cells", "receive_cells"],
	}))


## 把画板上的标记格写回 adjacency。
##
## profile 按需创建，但**从不自动删除** —— 把标记格清空不代表作者想丢掉
## 已经配好的 filter 与 mods，那是两件事。
func _sync_adjacency() -> void:
	var grant := _shape.grant_cells()
	var receive := _shape.receive_cells()
	if _def.adjacency == null:
		if grant.is_empty() and receive.is_empty():
			return
		_def.adjacency = AdjacencyProfile.new()
	_def.adjacency.grant_cells = grant
	_def.adjacency.receive_cells = receive


## 形状画板不走信号：刷新之前收回对象里
func _collect() -> void:
	_def.shape = _shape.to_shape()
	_sync_adjacency()
	_maybe_prefill_weapon()


func _on_refreshed() -> void:
	# 151：战斗力（估算是纯函数，表单一改就重算）。buff 按 id 查内容库
	_power.show_estimate(PowerEstimate.estimate(_def, _weights(), ContentLibrary.context().buffs))
#endregion


## 截图工具的钩子：打开一件既有邻接标记又有战斗数据的道具
func demo_fill() -> void:
	if _ids.has("mag"):
		_open("mag")
		_select_in_list("mag")
		_set_layer(ShapeEditor.Layer.GRANT)

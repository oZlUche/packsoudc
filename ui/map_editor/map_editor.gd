## 地图编辑器：**先按参数随机生成，再手动改，最后存成预设**（架构文档 5.3.1）。
##
## [b]它不认识任何具体的生成器。[/b] 左边的参数表单是把生成器给的默认配置反射出来的
## （[PropertyForm]），中间的画法问 [MapLayout]。于是新增一种地图形态 ——
## 注册表登记一行生成器、一行布局 —— 这个文件一行都不用改。
##
## 一切改图的动作都是公开方法（[method toggle_edge]、[method add_node_at]……），
## 鼠标只是调它们；测试也直接调它们，不必伪造输入事件。
extends Control

const SIDE_WIDTH := 340
const INFO_WIDTH := 300

var _font: Font
var _graph: MapGraph = null
var _gen_id: StringName = &""
var _gen: MapGenerator = null
var _cfg: Resource = null
var _dirty: bool = false
var _selected: int = -1

var _view: MapView
var _gen_pick: OptionButton
var _seed_box: SpinBox
var _status: Label
var _form_host: VBoxContainer
var _name_edit: LineEdit
var _preset_pick: OptionButton
var _props: VBoxContainer
var _report: RichTextLabel


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_build()
	var ids := MapGeneratorRegistry.ids()
	if not ids.is_empty():
		use_generator(ids[0])
		generate()


func has_unsaved_changes() -> bool:
	return _dirty


func graph() -> MapGraph:
	return _graph


func selected_id() -> int:
	return _selected


#region 生成
func use_generator(id: StringName) -> void:
	_gen_id = id
	_gen = MapGeneratorRegistry.create(id)
	_cfg = _gen.default_config() if _gen != null else null
	for child in _form_host.get_children():
		child.queue_free()
	if _cfg != null:
		_form_host.add_child(PropertyForm.create(_cfg, _font))


func config() -> Resource:
	return _cfg


## 按当前参数与种子生成一张。失败时旧图原样留着，状态栏说明哪条规则在咬。
func generate() -> bool:
	if _gen == null:
		return false
	var made := _gen.generate(_cfg, int(_seed_box.value))
	if made == null:
		_say("生成失败（试了 %d 次）：%s" % [_gen.attempts_used, str(_gen.failure_tally)], true)
		return false
	_say("种子 %d，第 %d 次尝试生成成功；%d 个点、%d 条路"
		% [int(_seed_box.value), _gen.attempts_used, made.node_count(), made.edges.size()], false)
	_set_graph(made)
	_dirty = true
	return true


func generate_with_new_seed() -> bool:
	_seed_box.value = randi() % 1000000
	return generate()


func _set_graph(g: MapGraph) -> void:
	_graph = g
	_view.graph = g
	select(-1)
	_revalidate()
#endregion


#region 改图
func select(id: int) -> void:
	_selected = id if _graph != null and _graph.has_node(id) else -1
	_view.selected_id = _selected
	_rebuild_props()


func set_node_type(id: int, type: StringName) -> void:
	var n := _node(id)
	if n != null and n.type != type:
		n.type = type
		_touch()


func set_node_danger(id: int, danger: int) -> void:
	var n := _node(id)
	if n != null:
		n.danger = clampi(danger, 0, 2)
		_touch()


## 改所属的高危区。`graph.zones` 是从节点上的 zone 字段重建的，两处不会对不上。
func set_node_zone(id: int, zone: int) -> void:
	var n := _node(id)
	if n != null:
		n.zone = maxi(0, zone)
		_sync_zones()
		_touch()


func toggle_entry(id: int) -> void:
	if _node(id) == null:
		return
	if _graph.entry_ids.has(id):
		_graph.entry_ids.erase(id)
	else:
		_graph.entry_ids.append(id)
		_graph.entry_ids.sort()
	_touch()


func toggle_goal(id: int) -> void:
	if _node(id) == null:
		return
	if _graph.goal_ids.has(id):
		_graph.goal_ids.erase(id)
	else:
		_graph.goal_ids.append(id)
		_graph.goal_ids.sort()
	_touch()


## 两点之间有路就断开，没有就连上。返回操作之后是否相连。
func toggle_edge(a: int, b: int) -> bool:
	if _node(a) == null or _node(b) == null or a == b:
		return false
	var e := _graph.edge_between(a, b)
	if e == null:
		e = _graph.edge_between(b, a)
	if e != null:
		_graph.remove_edge(e)
	else:
		var layout := MapLayout.for_graph(_graph)
		_graph.connect_nodes(a, b, layout.edge_kind(_graph, a, b) if layout != null else &"")
	_sync_zones()
	_touch()
	return e == null


func remove_edge(edge: MapEdge) -> void:
	if _graph == null or edge == null:
		return
	_graph.remove_edge(edge)
	_sync_zones()
	_touch()


## 在布局给出的一个空位上加点。返回新点的 id。
func add_node_at(slot: Dictionary) -> int:
	if _graph == null or slot.is_empty():
		return -1
	var n := MapNode.new()
	n.id = _graph.next_free_id()
	n.type = &"battle"
	n.tier = int(slot.get("tier", 0))
	n.erosion_band = int(slot.get("erosion_band", 0))
	n.content_seed = hash("manual:%d" % n.id)
	n.layout = (slot.get("layout", {}) as Dictionary).duplicate(true)
	_graph.add_node(n)
	_touch()
	select(n.id)
	return n.id


func delete_node(id: int) -> void:
	if _graph == null or not _graph.remove_node(id):
		return
	if _selected == id:
		select(-1)
	_sync_zones()
	_touch()


## 路线是生成器留下的标注。手改之后它多半对不上了 —— 要么修图让它重新走通，要么清掉。
func clear_routes() -> void:
	if _graph != null:
		_graph.routes = [] as Array[Dictionary]
		_touch()


func _node(id: int) -> MapNode:
	return _graph.get_node(id) if _graph != null else null


## 从节点的 zone 字段重建 graph.zones；入口 = 区内唯一一个有对外边的点（不唯一则 -1）。
func _sync_zones() -> void:
	var members := {}
	for id in _graph.node_ids():
		var z := _graph.get_node(id).zone
		if z != 0:
			if not members.has(z):
				members[z] = [] as Array[int]
			(members[z] as Array[int]).append(id)
	var zones := {}
	for z in members:
		var gates := {}
		for e in _graph.edges:
			var a_in: bool = (members[z] as Array).has(e.from_id)
			var b_in: bool = (members[z] as Array).has(e.to_id)
			if a_in != b_in:
				gates[e.from_id if a_in else e.to_id] = true
		zones[z] = {"node_ids": members[z], "gate_id": int(gates.keys()[0]) if gates.size() == 1 else -1}
	_graph.zones = zones


func _touch() -> void:
	_dirty = true
	_view.refresh()
	_rebuild_props()
	_revalidate()
#endregion


#region 校验
## 两档：**通用规矩**不过就不能当预设用（[MapSource] 载入时会拒）；
## **形态自己的规矩**只是提醒 —— 那是给生成器的约束，手绘的图有权不守。
func validation() -> Dictionary:
	var blocking := MapValidation.new()
	MapGenerator.validate_common(_graph, blocking)
	var advisory: Array[Dictionary] = []
	var checker := MapGeneratorRegistry.create(_graph.layout_kind) \
		if _graph != null and MapGeneratorRegistry.has(_graph.layout_kind) else null
	if checker != null:
		var full := MapValidation.new()
		checker.validate(_graph, full)
		var known := {}
		for f in blocking.failures:
			known["%s|%s" % [f["rule"], f["message"]]] = true
		for f in full.failures:
			if not known.has("%s|%s" % [f["rule"], f["message"]]):
				advisory.append(f)
	return {"blocking": blocking, "advisory": advisory}


func _revalidate() -> void:
	if _report == null:
		return
	_report.clear()
	if _graph == null:
		return
	var result := validation()
	var blocking: MapValidation = result["blocking"]
	var advisory: Array = result["advisory"]
	if blocking.ok() and advisory.is_empty():
		_report.push_color(UiPalette.HEAL)
		_report.add_text("✓ 全部校验通过")
		_report.pop()
		return
	for f in blocking.failures:
		_report.push_color(UiPalette.HP)
		_report.add_text("✗ [%s] %s\n" % [f["rule"], f["message"]])
		_report.pop()
	if not blocking.ok():
		_report.add_text("↑ 这些不修，这张图不能当预设用\n\n")
	for f in advisory:
		_report.push_color(UiPalette.STAMINA)
		_report.add_text("! [%s] %s\n" % [f["rule"], f["message"]])
		_report.pop()
	if not advisory.is_empty():
		_report.add_text("↑ 这些是生成器的规矩，手绘的图可以不守")
#endregion


#region 预设
func save_preset(preset_name: String) -> Error:
	var clean := preset_name.strip_edges()
	if _graph == null or clean == "" or not clean.is_valid_filename():
		_say("存不了：名字是空的，或者不能当文件名", true)
		return ERR_INVALID_PARAMETER
	var err := MapPreset.save(_graph, MapPreset.path_for(clean))
	if err == OK:
		_dirty = false
		_say("已存到 %s" % MapPreset.path_for(clean), false)
		_refresh_presets()
	else:
		_say("存盘失败：%s" % error_string(err), true)
	return err


func load_preset(preset_name: String) -> bool:
	var g := MapPreset.load_graph(MapPreset.path_for(preset_name))
	if g == null:
		_say("载入失败：%s" % preset_name, true)
		return false
	_set_graph(g)
	_name_edit.text = preset_name
	_dirty = false
	_say("已载入 %s" % preset_name, false)
	return true


func _refresh_presets() -> void:
	_preset_pick.clear()
	for n in MapPreset.list():
		_preset_pick.add_item(n)
#endregion


#region 界面
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	row.add_child(_build_side())
	_view = MapView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.show_free_slots = true
	_view.node_pressed.connect(_on_node_pressed)
	_view.edge_pressed.connect(_on_edge_pressed)
	_view.slot_pressed.connect(add_node_at)
	_view.empty_pressed.connect(func(): select(-1))
	row.add_child(_view)
	row.add_child(_build_info())


func _build_side() -> Control:
	var panel := _panel(SIDE_WIDTH)
	var col: VBoxContainer = panel.get_child(0)
	col.add_child(_label("地图编辑器", 18, UiPalette.FG))

	_gen_pick = OptionButton.new()
	_style(_gen_pick)
	for id in MapGeneratorRegistry.ids():
		_gen_pick.add_item(String(id))
	_gen_pick.item_selected.connect(func(i: int):
		use_generator(StringName(_gen_pick.get_item_text(i))))
	col.add_child(_pair("生成器", _gen_pick))

	_seed_box = SpinBox.new()
	_seed_box.max_value = 999999999
	_seed_box.value = 1
	col.add_child(_pair("种子", _seed_box))

	var buttons := HBoxContainer.new()
	buttons.add_child(_button("生成", func(): generate()))
	buttons.add_child(_button("换个种子生成", func(): generate_with_new_seed()))
	col.add_child(buttons)

	_status = _label("", 12, UiPalette.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.custom_minimum_size.x = SIDE_WIDTH - 30
	col.add_child(_status)
	col.add_child(HSeparator.new())

	col.add_child(_label("预设", 14, UiPalette.FG))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "预设名（存到 data/maps/）"
	_style(_name_edit)
	col.add_child(_name_edit)
	var save_row := HBoxContainer.new()
	save_row.add_child(_button("保存", func(): save_preset(_name_edit.text)))
	_preset_pick = OptionButton.new()
	_preset_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(_preset_pick)
	save_row.add_child(_preset_pick)
	save_row.add_child(_button("载入", func():
		if _preset_pick.selected >= 0:
			load_preset(_preset_pick.get_item_text(_preset_pick.selected))))
	col.add_child(save_row)
	_refresh_presets()
	col.add_child(HSeparator.new())

	col.add_child(_label("生成参数", 14, UiPalette.FG))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form_host)
	col.add_child(scroll)
	return panel


func _build_info() -> Control:
	var panel := _panel(INFO_WIDTH)
	var col: VBoxContainer = panel.get_child(0)
	# 右上角是 DevNav 的「← 主界面」按钮，让出一行
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26
	col.add_child(spacer)
	var hint := _label(
		"左键点：选中　　空位：加点\n选中后 Shift+左键另一点：连 / 断\n右键路：断开　　Delete：删点",
		12, UiPalette.DIM)
	col.add_child(hint)
	col.add_child(HSeparator.new())
	_props = VBoxContainer.new()
	_props.add_theme_constant_override("separation", 6)
	col.add_child(_props)
	col.add_child(HSeparator.new())
	col.add_child(_label("校验", 14, UiPalette.FG))
	_report = RichTextLabel.new()
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.add_theme_font_override("normal_font", _font)
	_report.add_theme_font_size_override("normal_font_size", 12)
	col.add_child(_report)
	return panel


func _rebuild_props() -> void:
	if _props == null:
		return
	for child in _props.get_children():
		child.queue_free()
	if _graph == null:
		return
	var n := _node(_selected)
	if n == null:
		_props.add_child(_label("%d 个点　%d 条路　%d 个出生点　%d 片高危区"
			% [_graph.node_count(), _graph.edges.size(), _graph.entry_ids.size(), _graph.zones.size()],
			12, UiPalette.DIM))
		_props.add_child(_button("清空路线标注（%d 条）" % _graph.routes.size(), clear_routes))
		return

	var id := n.id
	_props.add_child(_label("节点 %d　tier %d　%s" % [id, n.tier, str(n.layout)], 12, UiPalette.DIM))
	var type_pick := OptionButton.new()
	_style(type_pick)
	for i in MapNodeTypes.ALL.size():
		var t := MapNodeTypes.ALL[i]
		type_pick.add_item("%s（%s）" % [MapNodeStyle.of(t)["label"], t])
		if t == n.type:
			type_pick.select(i)
	type_pick.item_selected.connect(func(i: int): set_node_type(id, MapNodeTypes.ALL[i]))
	_props.add_child(_pair("类型", type_pick))
	_props.add_child(_pair("危险等级", _spin(n.danger, 0, 2, func(v: int): set_node_danger(id, v))))
	_props.add_child(_pair("高危区编号", _spin(n.zone, 0, 99, func(v: int): set_node_zone(id, v))))

	var entry := CheckBox.new()
	entry.text = "出生点"
	entry.button_pressed = _graph.entry_ids.has(id)
	_style(entry)
	entry.toggled.connect(func(_on: bool): toggle_entry(id))
	var goal := CheckBox.new()
	goal.text = "终点"
	goal.button_pressed = _graph.goal_ids.has(id)
	_style(goal)
	goal.toggled.connect(func(_on: bool): toggle_goal(id))
	var flags := HBoxContainer.new()
	flags.add_child(entry)
	flags.add_child(goal)
	_props.add_child(flags)
	_props.add_child(_button("删除这个点", func(): delete_node(id)))


func _on_node_pressed(id: int, button: int, shift: bool) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	if shift and _selected >= 0 and _selected != id:
		toggle_edge(_selected, id)
	else:
		select(id)


func _on_edge_pressed(edge: MapEdge, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		remove_edge(edge)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_DELETE and _selected >= 0:
		delete_node(_selected)
		get_viewport().set_input_as_handled()


func _say(text: String, is_error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiPalette.HP if is_error else UiPalette.DIM)


func _panel(width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PANEL
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _style(c: Control) -> void:
	c.add_theme_font_override("font", _font)
	c.add_theme_font_size_override("font_size", 13)


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	_style(b)
	b.pressed.connect(handler)
	return b


func _pair(text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var l := _label(text, 13, UiPalette.DIM)
	l.custom_minimum_size.x = 90
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _spin(value: int, lo: int, hi: int, apply: Callable) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.value = value
	sb.value_changed.connect(func(v: float): apply.call(int(v)))
	return sb
#endregion

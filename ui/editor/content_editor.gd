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
extends Control

const ITEM_DIR := "res://data/authoring/items"

var _font: Font
var _ids: Array[String] = []
var _current_id: String = ""
var _def: ItemDef = null

var _list: ItemList
var _form_host: VBoxContainer
var _shape: ShapeEditor
var _id_edit: LineEdit
var _status: RichTextLabel
var _preview: TextEdit
var _dps: Label
var _layer_buttons: Array[Button] = []


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_build_ui()
	_reload_list()
	if _ids.is_empty():
		_new_item()
	else:
		_open(_ids[0])


#region 界面
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var columns := HSplitContainer.new()
	margin.add_child(columns)

	# --- 左：道具列表 ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 180
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(_label("道具", 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_override("font", _font)
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var list_buttons := HBoxContainer.new()
	list_buttons.add_child(_button("新建", _new_item))
	list_buttons.add_child(_button("重载", _on_reload))
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
	id_row.add_child(_label("id", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 150
	_id_edit.add_theme_font_override("font", _font)
	_id_edit.text_changed.connect(_on_id_changed)
	id_row.add_child(_id_edit)
	id_row.add_child(_button("保存", _save))
	id_row.add_child(_button("另存为新 id", _save_as))
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

	side_col.add_child(_label("形状与邻接标记", 14, UiPalette.FG))

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
		var b := _button(spec[1], func(): _set_layer(which))
		b.add_theme_color_override("font_color", spec[2])
		_layer_buttons.append(b)
		layer_row.add_child(b)
	side_col.add_child(layer_row)

	_shape = ShapeEditor.new()
	_shape.label_font = _font
	_shape.changed.connect(_refresh)
	side_col.add_child(_shape)

	var grid_row := HBoxContainer.new()
	grid_row.add_child(_label("画板", 12, UiPalette.DIM))
	for wh in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4), Vector2i(2, 4), Vector2i(4, 2)]:
		var size := wh as Vector2i
		grid_row.add_child(_button(
			"%dx%d" % [size.x, size.y], func(): _shape.grow_to(size.x, size.y)
		))
	side_col.add_child(grid_row)

	_dps = _label("", 13, UiPalette.DIM)
	side_col.add_child(_dps)

	side_col.add_child(_label("校验", 14, UiPalette.FG))
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size.y = 100
	_status.add_theme_font_override("normal_font", _font)
	_status.add_theme_font_size_override("normal_font_size", 12)
	side_col.add_child(_status)

	side_col.add_child(_label("JSON（可直接改）", 12, UiPalette.DIM))
	_preview = TextEdit.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.add_theme_font_override("font", _font)
	_preview.add_theme_font_size_override("font_size", 12)
	side_col.add_child(_preview)
	side_col.add_child(_button("套用上面的 JSON", _apply_json))


func _set_layer(which: int) -> void:
	_shape.layer = which as ShapeEditor.Layer
	for i in _layer_buttons.size():
		_layer_buttons[i].flat = i != which
	_shape.queue_redraw()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(handler)
	return b
#endregion


#region 文件
func _reload_list() -> void:
	_ids.clear()
	_list.clear()
	var d := DirAccess.open(ITEM_DIR)
	if d != null:
		var files := d.get_files()
		files.sort()  # 顺序稳定，列表才不会每次打开都换位置
		for f in files:
			if f.ends_with(".json"):
				_ids.append(f.get_basename())
	for id in _ids:
		_list.add_item(id)


func _on_reload() -> void:
	_reload_list()
	if _current_id != "":
		_open(_current_id)


func _on_id_changed(text: String) -> void:
	if _def != null:
		_def.id = StringName(text)
	_refresh()


func _open(id: String) -> void:
	var text := FileAccess.get_file_as_string("%s/%s.json" % [ITEM_DIR, id])
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]读不出 %s.json[/color]" % id
		return
	_load_dict(parsed, id)


func _load_dict(data: Dictionary, id: String) -> void:
	var report := ImportReport.new()
	report.source = id
	_def = ContentImporter.import_item(data, ContentImporter.Context.new(), report)
	_current_id = id
	_id_edit.text = String(_def.id)
	_shape.set_from(_def.shape, _def.adjacency)
	_set_layer(ShapeEditor.Layer.SHAPE)
	_rebuild_form()
	_refresh()


func _new_item() -> void:
	_def = ItemDef.new()
	_def.id = &"new_item"
	_def.display_name = "新道具"
	_def.shape = ItemShape.from_bits("1")
	_current_id = ""
	_id_edit.text = "new_item"
	_shape.set_from(_def.shape, null)
	_set_layer(ShapeEditor.Layer.SHAPE)
	_rebuild_form()
	_refresh()


func _save() -> void:
	if _def == null:
		return
	var id := String(_def.id).strip_edges()
	if id == "":
		_status.text = "[color=#d9534f]id 不能为空[/color]"
		return
	var report := _validate()
	if not report.ok():
		# 有错就不写盘：半套内容比没内容更难查，游戏照样跑得起来，只是悄悄不对
		_status.text = "[color=#d9534f]有错误，没有保存[/color]\n" + _status_text(report)
		return
	DirAccess.make_dir_recursive_absolute(ITEM_DIR)
	var err := ContentExporter.save(
		ContentExporter.export_item(_def), "%s/%s.json" % [ITEM_DIR, id]
	)
	if err != OK:
		_status.text = "[color=#d9534f]写入失败[/color]"
		return
	_current_id = id
	_reload_list()
	_select_in_list(id)
	_refresh()
	_status.text = "[color=#5cb85c]已保存 %s.json[/color]\n" % id + _status_text(report)


## 改了 id 再保存就是另一个文件；旧的留着，删不删由作者决定
func _save_as() -> void:
	_current_id = ""
	_save()


func _select_in_list(id: String) -> void:
	var i := _ids.find(id)
	if i >= 0:
		_list.select(i)


## 让作者直接改 JSON：界面覆盖不到的角落不该把人挡在外面
func _apply_json() -> void:
	var parsed = JSON.parse_string(_preview.text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]JSON 语法错误[/color]"
		return
	_load_dict(parsed, _current_id)
#endregion


#region 刷新
func _rebuild_form() -> void:
	for c in _form_host.get_children():
		c.queue_free()
	if _def == null:
		return
	# id 在顶栏、形状有画板 —— 表单里跳过，免得两处能改同一个值
	# 画板上能画的东西，表单里一律不给第二个入口
	var form := PropertyForm.create(_def, _font, {
		"ItemDef": ["id", "shape", "icon"],
		"AdjacencyProfile": ["grant_cells", "receive_cells"],
	})
	form.changed.connect(_refresh)
	_form_host.add_child(form)


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


## 校验走的就是导入器本身。
##
## [b]不另写一份规则[/b] —— 那样界面和命令行迟早给出不同的答案，
## 而作者会相信先看到的那个。
func _validate() -> ImportReport:
	var report := ImportReport.new()
	report.source = String(_def.id)
	ContentImporter.import_item(
		ContentExporter.export_item(_def), ContentImporter.Context.new(), report
	)
	return report


func _status_text(report: ImportReport) -> String:
	var lines: Array[String] = []
	for e in report.errors:
		lines.append("[color=#d9534f]✗ %s：%s[/color]" % [e["path"], e["message"]])
	for w in report.warnings:
		lines.append("[color=#f0ad4e]! %s：%s[/color]" % [w["path"], w["message"]])
	if lines.is_empty():
		lines.append("[color=#5cb85c]✓ 没有问题[/color]")
	return "\n".join(lines)


func _refresh() -> void:
	if _def == null:
		return
	_def.shape = _shape.to_shape()
	_sync_adjacency()
	_preview.text = ContentExporter.to_json(ContentExporter.export_item(_def))
	_status.text = _status_text(_validate())

	# 预估 DPS：编译是纯函数，所以这条读数和真打出来的一致
	var item := CompiledItem.new()
	item.source_uid = 1
	item.def_id = _def.id
	item.stats = StatSet.new()
	if _def.combat != null:
		_def.combat.seed_stats(item.stats)
		item.rules = _def.combat.rules
	_dps.text = "占 %d 格　预估 DPS %.1f" % [_shape.cell_count(), item.estimated_dps()]
#endregion


## 截图工具的钩子：打开一件既有邻接标记又有战斗数据的道具
func demo_fill() -> void:
	if _ids.has("mag"):
		_open("mag")
		_select_in_list("mag")
		_set_layer(ShapeEditor.Layer.GRANT)

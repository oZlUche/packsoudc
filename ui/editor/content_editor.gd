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
extends Control

## 作者数据目录。资产目录见 [ContentPaths]。
const ITEM_DIR := ContentPaths.AUTHORING_ITEMS

## 分类页签的三种形态。
##
## 不用「哨兵字符串」表示「无标签」那一页：标签是作者自己起的名字，
## 挑哪个词当哨兵都可能撞上，而撞上的表现是某个标签页莫名其妙变成了另一页。
enum Filter { ALL, TAG, UNTAGGED }

var _font: Font
var _ids: Array[String] = []
var _current_id: String = ""
var _def: ItemDef = null

## 改过但还没存盘的道具：列表键 → 正在编辑的对象。
##
## [b]切走不该丢改动。[/b] 对着一件道具改到一半，想去看另一件的形状是什么样，
## 回来发现全没了 —— 这种事发生一次，作者就再也不敢点列表了。
##
## 只在内存里，关掉编辑器就没了（所以叫草稿，不叫自动保存）。
var _drafts: Dictionary = {}

## 列表键 → 该道具在盘上的规范化 JSON 文本，用来判断脏没脏。
##
## 存的是**规范化之后**的文本（读进来再导出一遍），这样手改过格式的文件
## 不会一打开就被当成「改过了」。
var _baseline: Dictionary = {}

## 当前分类筛选之后，列表里实际显示的 id，**按显示顺序**。
##
## 与 [member _ids] 分开：ItemList 的行号对应的是这一份，不是全集。
## 两者混用的表现是「点第三行打开了第五件」—— 一加筛选就错，而且错得很隐蔽。
var _shown: Array[String] = []

## 分类筛选。[constant Filter.TAG] 时看 [member _filter_tag]。
var _filter: Filter = Filter.ALL
var _filter_tag: String = ""

## 列表键 → 它的标签。标签是**从数据里读出来的**，不是写死的表 ——
## MOD 作者加一个新标签，分类页签就该自己多出来一个。
var _tags_of: Dictionary = {}

var _tab_host: VBoxContainer
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
	UiPalette.apply(GameSettings.load_from())     # 091：底色跟设置走
	bg.color = UiPalette.bg()
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

	# --- 左：分类页签 + 道具列表 ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 290
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(_label("道具", 16, UiPalette.FG))

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

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_override("font", _font)
	_list.item_selected.connect(func(i: int): _open(_shown[i]))
	browse.add_child(_list)
	var list_buttons := HBoxContainer.new()
	list_buttons.add_child(_button("新建", _new_item))
	list_buttons.add_child(_button("刷新列表", _on_rescan))
	list_buttons.add_child(_button("放弃改动", _on_discard))
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
	_tags_of.clear()
	_list.clear()
	var d := DirAccess.open(ITEM_DIR)
	if d != null:
		var files := d.get_files()
		files.sort()  # 顺序稳定，列表才不会每次打开都换位置
		for f in files:
			if not f.ends_with(".json"):
				continue
			var id := f.get_basename()
			_ids.append(id)
			_tags_of[id] = _tags_in_file(f)
	# 草稿里可能有还没存过盘的新道具，它们不在目录里但得看得见
	for key in _drafts:
		if not _ids.has(key):
			_ids.append(key)
			_ids.sort()
	_repaint_list()


## 只为了标签读一遍文件。走 JSON 而不是导入器：这里不关心内容对不对，
## 一件配错的道具照样得出现在列表里，否则作者就没法进去修它。
func _tags_in_file(file_name: String) -> Array[String]:
	var out: Array[String] = []
	var parsed = JSON.parse_string(
		FileAccess.get_file_as_string(ITEM_DIR + "/" + file_name))
	if not (parsed is Dictionary):
		return out
	for t in ((parsed as Dictionary).get("tags", []) as Array):
		out.append(String(t))
	return out


## 内存里那一份的标签盖掉盘上的 —— 作者刚加的标签，页签就该跟着变。
func _tags_for(id: String) -> Array[String]:
	var live: ItemDef = null
	if id == _draft_key() and _def != null:
		live = _def
	elif _drafts.has(id):
		live = _drafts[id]
	if live == null:
		return _tags_of.get(id, [] as Array[String])
	var out: Array[String] = []
	for t in live.tags:
		out.append(String(t))
	return out


## 全部出现过的标签，按名字排序。**从内容里长出来，不是写死的枚举** ——
## MOD 作者加一个标签，这里自己就多一页。
func _all_tags() -> Array[String]:
	var seen := {}
	for id in _ids:
		for t in _tags_for(id):
			seen[t] = true
	var out: Array[String] = []
	for t in seen:
		out.append(t)
	out.sort()
	return out


func _matches_filter(id: String) -> bool:
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
		if _tags_for(id).is_empty():
			wanted.append([Filter.UNTAGGED, ""])
			break

	var current: Array = []
	for child in _tab_host.get_children():
		current.append((child as Button).get_meta("page"))
	if current != wanted:
		for child in _tab_host.get_children():
			_tab_host.remove_child(child)
			child.queue_free()
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


func _count_of(page: Array) -> int:
	var n := 0
	for id in _ids:
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
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		_filter = page[0]
		_filter_tag = String(page[1])
		_repaint_list()
	)
	return b


## 有未保存改动的条目前面加一个点。没有这个标记，作者就得靠记忆。
func _repaint_list() -> void:
	_rebuild_tabs()
	_shown.clear()
	_list.clear()
	for id in _ids:
		if _matches_filter(id):
			_shown.append(id)
			_list.add_item(("● " if _drafts.has(id) else "") + id)
	# 按 id 选回去，不按行号 —— 换一页之后行号指向的是另一件东西
	var i := _shown.find(_draft_key())
	if i >= 0:
		_list.select(i)


func _on_rescan() -> void:
	_stash_current()
	_reload_list()


## 丢掉当前这件的草稿，从盘上重读。**只影响当前这一件** ——
## 一键清空所有草稿太容易误点。
func _on_discard() -> void:
	var key := _draft_key()
	_drafts.erase(key)
	_baseline.erase(key)
	# 先把当前状态清掉再重读：否则 _open 会认出「点的就是当前这件」而直接返回，
	# 而且 _stash_current 会在基准刚被删掉的情况下把它又标成脏的。
	_def = null
	_current_id = ""
	if FileAccess.file_exists(ContentPaths.authoring_file("items", key)):
		_open(key)
	else:
		_reload_list()
		_new_item()
	_repaint_list()


func _on_id_changed(text: String) -> void:
	if _def != null:
		_def.id = StringName(text)
	_refresh()


## 当前这件在草稿表里的键。
##
## 用**打开时的那个 id**，不是输入框里的当前值 —— 否则边改 id 边切走，
## 草稿会散落在一堆半成品名字下面。新建的还没有来源文件，就用当前 id。
func _draft_key() -> String:
	if _current_id != "":
		return _current_id
	return String(_def.id) if _def != null else ""


## 当前内容与盘上不一致时，把它收进草稿；一致就把草稿撤掉。
##
## 比对的是规范化后的 JSON 文本，所以「改了又改回去」不会留下假的脏标记。
func _stash_current() -> void:
	if _def == null:
		return
	var key := _draft_key()
	if key == "":
		return
	var now := ContentExporter.to_json(ContentExporter.export_item(_def))
	if _baseline.has(key) and _baseline[key] == now:
		_drafts.erase(key)
	else:
		_drafts[key] = _def


func _open(id: String) -> void:
	if id == _draft_key() and _def != null:
		return  # 点的就是当前这件，不用重来
	_stash_current()

	# 有草稿就接着改那一份，不要从盘上覆盖回去
	if _drafts.has(id):
		_bind(_drafts[id], id)
		return

	var text := FileAccess.get_file_as_string(ContentPaths.authoring_file("items", id))
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]读不出 %s.json[/color]" % id
		return
	var report := ImportReport.new()
	report.source = id
	var def := ContentImporter.import_item(parsed, ContentImporter.Context.new(), report)
	# 基准必须在 _bind 之前写好：_bind 会走一遍 _refresh，
	# 而 _refresh 里的脏判断「没有基准」就当作改过了 —— 刚打开就被标成脏。
	# 只有【从盘上读】才刷新基准；套用 JSON、切回草稿都不算。
	_baseline[id] = ContentExporter.to_json(ContentExporter.export_item(def))
	_bind(def, id)


## 套用 JSON 预览里的内容。算一次编辑，不刷新基准。
func _load_dict(data: Dictionary, id: String) -> void:
	var report := ImportReport.new()
	report.source = id
	_bind(ContentImporter.import_item(data, ContentImporter.Context.new(), report), id)


## 把一个对象接到界面上
func _bind(def: ItemDef, id: String) -> void:
	_def = def
	_current_id = id
	_id_edit.text = String(_def.id)
	_shape.set_from(_def.shape, _def.adjacency)
	_set_layer(ShapeEditor.Layer.SHAPE)
	_rebuild_form()
	_refresh()
	_repaint_list()


func _new_item() -> void:
	_stash_current()
	var def := ItemDef.new()
	def.id = &"new_item"
	def.display_name = "新道具"
	def.shape = ItemShape.from_bits("1")
	_bind(def, "")


func _save() -> void:
	if _def == null:
		return
	var id := String(_def.id).strip_edges()
	if id == "":
		_status.text = "[color=#d9534f]id 不能为空[/color]"
		return
	# 校验顺带把资产也建出来了 —— 它走的就是「导出成 JSON 再导入回来」那条路，
	# 与命令行导入器完全一致，不是另算一遍
	var data := ContentExporter.export_item(_def)
	var report := ImportReport.new()
	report.source = id
	var built := ContentImporter.import_item(data, ContentImporter.Context.new(), report)
	if not report.ok():
		# 有错就不写盘：半套内容比没内容更难查，游戏照样跑得起来，只是悄悄不对
		_status.text = "[color=#d9534f]有错误，没有保存[/color]\n" + _status_text(report)
		return

	DirAccess.make_dir_recursive_absolute(ITEM_DIR)
	if ContentExporter.save(data, ContentPaths.authoring_file("items", id)) != OK:
		_status.text = "[color=#d9534f]作者数据写入失败[/color]"
		return

	# 顺手把引擎资产也产出来，省掉「改完还要记得跑一次导入」这一步。
	# 忘了跑的表现是「改了没生效」，而界面上一切正常 —— 最容易让人怀疑人生。
	DirAccess.make_dir_recursive_absolute(ContentPaths.ITEMS)
	if ResourceSaver.save(built, ContentPaths.asset_file("items", id)) != OK:
		_status.text = "[color=#f0ad4e]JSON 存了，但资产写入失败 —— 跑一次 import_content[/color]"
		return

	# 存下去了，草稿就没有意义了；基准换成刚写出去的那份
	_drafts.erase(_draft_key())
	_drafts.erase(id)
	_baseline[id] = ContentExporter.to_json(data)
	_current_id = id
	_reload_list()
	_select_in_list(id)
	_refresh()
	_status.text = "[color=#5cb85c]已保存 %s.json，并生成 %s.tres[/color]\n" % [id, id] \
		+ _status_text(report)


## 改了 id 再保存就是另一个文件；旧的留着，删不删由作者决定
func _save_as() -> void:
	_current_id = ""
	_save()


func _select_in_list(id: String) -> void:
	# 当前分类里没有它，就退回「全部」：选中一件看不见的东西等于没选
	if not _matches_filter(id):
		_filter = Filter.ALL
		_filter_tag = ""
		_repaint_list()
	var i := _shown.find(id)
	if i >= 0 and i < _list.item_count:
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


## 每次改动都更新脏标记，这样列表上的点是实时的。
##
## 只在「与基准不同」时才记草稿 —— 否则打开看一眼就被标成改过，
## 点满屏都是，标记也就没意义了。
func _track_draft() -> void:
	var key := _draft_key()
	if key == "":
		return
	var dirty := false
	# 091（作者反馈）：新建的道具还没存盘时草稿键就是它的 id；作者边敲边改 id，旧键下那份是同一个对象，不能留成孤儿 ——
	# 否则每敲一个字列表里就多一条「t / ti / tib…」。盘上没有的旧名字也从列表里撤掉
	for k in _drafts.keys():
		if k != key and _drafts[k] == _def:
			_drafts.erase(k)
			if not _baseline.has(k) and not FileAccess.file_exists(ITEM_DIR + "/" + k + ".json"):
				_ids.erase(k)
			dirty = true
	var now := ContentExporter.to_json(ContentExporter.export_item(_def))
	var was := _drafts.has(key)
	if _baseline.has(key) and _baseline[key] == now:
		_drafts.erase(key)
	else:
		_drafts[key] = _def
		if not _ids.has(key):
			_ids.append(key)
			_ids.sort()
			dirty = true
	if dirty or was != _drafts.has(key):
		_repaint_list()


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
	_track_draft()
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


## [DevNav] 会问这一句再决定要不要拦一下返回。
##
## 草稿只在内存里，切走场景就没了 —— 而「点了返回、改了一下午的东西没了」
## 是这类工具最不能有的失败。
func has_unsaved_changes() -> bool:
	_stash_current()
	return not _drafts.is_empty()


## 截图工具的钩子：打开一件既有邻接标记又有战斗数据的道具
func demo_fill() -> void:
	if _ids.has("mag"):
		_open("mag")
		_select_in_list("mag")
		_set_layer(ShapeEditor.Layer.GRANT)

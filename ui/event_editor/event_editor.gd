## 事件编辑器（架构文档 10.5，报告 064）—— 给作者写事件：标题、正文、配图、选项与它们的条件 / 后果。
##
## 和道具编辑器同一条原则：**它不是另一条通路，只是同一条通路的另一个入口。**
## 存的是 `data/authoring/events/<id>.json`，校验走导入器本身，选项的条件 / 后果由 [PropertyForm] 反射生成、
## 类型下拉来自注册表 —— 加一种条件或后果，这里自动多一项。保存同时产出 `.tres`。
##
## 比道具编辑器多的三件事：
## 1. **导入配图**：系统文件对话框挑一张图，复制到 `assets/events/<id>.<ext>`，路径写进事件。
##    事件屏与这里的预览都用 [EventImage] 装，引擎还没导入时也画得出来。
## 2. **预览**：右边照着事件屏的样子画一遍 —— 标题、图、正文、选项，每个选项底下写它的条件与后果（构件的 describe）。
## 3. **挂进节点规则**：选一份节点规则、一种点、一个权重，写进 `events_by_type`。这一步也走导入器
##    （引用不存在的事件会被拦下），所以先保存再挂。
##
## 为什么不做成 Godot 之外的独立程序：构件的种类、字段、校验、道具与 buff 的 id 全在注册表与导入器里，
## 独立程序要么复制一份（迟早对不上），要么不校验；这里一行都不用复制。
## 真要单独发给作者，用导出预设把项目导出成 exe，启动选择器就是入口。
extends Control

const KIND := "events"
const EVENT_DIR := ContentPaths.AUTHORING_EVENTS
## 配图落在这里；路径写进事件的 `image`
const IMAGE_DIR := "res://assets/events"
const RULES_KIND := "node_rules"

var _font: Font
var _ids: Array[String] = []
var _current_id: String = ""
var _def: EventDef = null
## 改过但还没存盘的：列表键 → 正在编辑的对象（只在内存里，见道具编辑器）
var _drafts: Dictionary = {}
## 列表键 → 盘上的规范化 JSON 文本，判断脏没脏
var _baseline: Dictionary = {}
## 校验用的上下文：道具、buff、盘上的事件。导入器「对着别的东西查」的那些校验只在上下文非空时生效
var _ctx: ContentImporter.Context = null
## 绑定时改控件文字会触发 changed，这个标志让处理器忽略那一下
var _syncing: bool = false

var _list: ItemList
var _id_edit: LineEdit
var _title_edit: LineEdit
var _text_edit: TextEdit
var _image_edit: LineEdit
var _thumb: TextureRect
var _form_host: VBoxContainer
var _preview_host: VBoxContainer
var _status: RichTextLabel
var _json: TextEdit
var _rules_pick: OptionButton
var _type_pick: OptionButton
var _weight: SpinBox
var _placement: Label
var _file_dialog: FileDialog
## 091：正在编辑的语言（"zh" = 原文 title / text；别的写进 titles / texts）与事件链视图
var _lang: String = "zh"
var _lang_pick: OptionButton
var _chain: Tree


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_ctx = _build_context()
	_build_ui()
	_reload_list()
	if _ids.is_empty():
		_new_event()
	else:
		_open(_ids[0])


## 道具从资产装（`ItemDatabase`），buff 走 `GameFlow.load_run_buffs`，事件从作者数据读 —— 都是现成的路
static func _build_context() -> ContentImporter.Context:
	var ctx := ContentImporter.Context.new()
	var items := ItemDatabase.new()
	items.load_dir()
	for id in items.ids():
		ctx.register_item(items.get_def(id))
	var buffs := GameFlow.load_run_buffs()
	for id in buffs:
		ctx.register_run_buff(buffs[id])
	for id in _ids_on_disk():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file(KIND, id)))
		if parsed is Dictionary:
			ContentImporter.import_event(parsed, ctx, ImportReport.new())
	return ctx


static func _ids_on_disk() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(EVENT_DIR)
	if d == null:
		return out
	var files := d.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out


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

	# --- 左：事件列表 ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 240
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(_label("事件", 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_override("font", _font)
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var list_buttons := HBoxContainer.new()
	list_buttons.add_child(_button("新建", _new_event))
	list_buttons.add_child(_button("刷新列表", _on_rescan))
	list_buttons.add_child(_button("放弃改动", _on_discard))
	left.add_child(list_buttons)

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_split)

	# --- 中：文字、配图、选项 ---
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(mid)

	var id_row := HBoxContainer.new()
	id_row.add_child(_label("id", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 180
	_id_edit.add_theme_font_override("font", _font)
	_id_edit.text_changed.connect(_on_id_changed)
	id_row.add_child(_id_edit)
	id_row.add_child(_button("保存", _save))
	id_row.add_child(_button("另存为新 id", _save_as))
	# 091：语言切换 —— 标题 / 正文按这个语言编辑；中文是原文，别的语言写进 titles / texts（空 = 用中文）
	id_row.add_child(_label("语言", 13, UiPalette.DIM))
	_lang_pick = OptionButton.new()
	_lang_pick.add_theme_font_override("font", _font)
	for i in UiText.LANGS.size():
		_lang_pick.add_item(UiText.LANGS[i], i)
	_lang_pick.item_selected.connect(func(i: int): set_lang(UiText.LANGS[i]))
	id_row.add_child(_lang_pick)
	mid.add_child(id_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	var title_row := HBoxContainer.new()
	title_row.add_child(_label("标题", 13, UiPalette.DIM))
	_title_edit = LineEdit.new()
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_edit.add_theme_font_override("font", _font)
	_title_edit.text_changed.connect(_on_title_changed)
	title_row.add_child(_title_edit)
	body.add_child(title_row)

	body.add_child(_label("正文", 13, UiPalette.DIM))
	_text_edit = TextEdit.new()
	_text_edit.custom_minimum_size.y = 120
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.add_theme_font_override("font", _font)
	_text_edit.add_theme_font_size_override("font_size", 14)
	_text_edit.text_changed.connect(_on_text_changed)
	body.add_child(_text_edit)

	var image_row := HBoxContainer.new()
	image_row.add_child(_label("配图", 13, UiPalette.DIM))
	_image_edit = LineEdit.new()
	_image_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_edit.placeholder_text = "res://assets/events/<id>.png（可以直接填，或点导入）"
	_image_edit.add_theme_font_override("font", _font)
	_image_edit.text_changed.connect(_on_image_changed)
	image_row.add_child(_image_edit)
	image_row.add_child(_button("导入图片…", _pick_image))
	image_row.add_child(_button("清除", _clear_image))
	body.add_child(image_row)
	_thumb = TextureRect.new()
	_thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_thumb.custom_minimum_size = Vector2(0, 0)
	body.add_child(_thumb)

	body.add_child(HSeparator.new())
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_form_host)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.use_native_dialog = true
	_file_dialog.title = "选一张配图"
	_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片"])
	_file_dialog.file_selected.connect(func(path: String): _import_image(path))
	add_child(_file_dialog)

	# --- 右：预览 / 校验 / 挂进节点规则 / JSON ---
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 400
	side.add_theme_constant_override("separation", 8)
	right_split.add_child(side)

	side.add_child(_label("预览（事件屏的样子）", 14, UiPalette.FG))
	var preview_scroll := ScrollContainer.new()
	preview_scroll.custom_minimum_size.y = 260
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(preview_scroll)
	var preview_panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = UiPalette.PANEL
	st.border_color = UiPalette.LINE
	st.set_border_width_all(1)
	st.set_content_margin_all(12)
	preview_panel.add_theme_stylebox_override("panel", st)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.add_child(preview_panel)
	_preview_host = VBoxContainer.new()
	_preview_host.add_theme_constant_override("separation", 8)
	preview_panel.add_child(_preview_host)

	side.add_child(_label("校验", 14, UiPalette.FG))
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size.y = 80
	_status.add_theme_font_override("normal_font", _font)
	_status.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(_status)

	# 091：事件链 —— 从这个事件出去的（选项 → next_event，递归）和引用它的（别的事件 / 节点规则 / 预设图 / 章节开场）；双击一行打开那个事件
	side.add_child(_label("事件链（双击跳过去）", 14, UiPalette.FG))
	_chain = Tree.new()
	_chain.hide_root = true
	_chain.custom_minimum_size.y = 150
	_chain.add_theme_font_override("font", _font)
	_chain.add_theme_font_size_override("font_size", 12)
	_chain.item_activated.connect(_open_from_chain)
	side.add_child(_chain)

	side.add_child(_label("挂进节点规则（先保存）", 14, UiPalette.FG))
	_placement = _label("", 12, UiPalette.DIM)
	_placement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placement.custom_minimum_size.x = 380
	side.add_child(_placement)
	var attach_row := HBoxContainer.new()
	attach_row.add_theme_constant_override("separation", 6)
	_rules_pick = OptionButton.new()
	_rules_pick.add_theme_font_override("font", _font)
	for rid in _rules_ids():
		_rules_pick.add_item(rid)
	attach_row.add_child(_rules_pick)
	_type_pick = OptionButton.new()
	_type_pick.add_theme_font_override("font", _font)
	for i in MapNodeTypes.ALL.size():
		_type_pick.add_item(String(MapNodeTypes.ALL[i]), i)
		if MapNodeTypes.ALL[i] == &"event":
			_type_pick.select(i)
	attach_row.add_child(_type_pick)
	_weight = SpinBox.new()
	_weight.min_value = 0
	_weight.max_value = 999
	_weight.step = 1
	_weight.value = 1
	_weight.add_theme_font_override("font", _font)
	attach_row.add_child(_weight)
	attach_row.add_child(_button("挂上", _on_attach))
	attach_row.add_child(_button("摘下", _on_detach))
	side.add_child(attach_row)

	side.add_child(_label("JSON（可直接改）", 12, UiPalette.DIM))
	_json = TextEdit.new()
	_json.custom_minimum_size.y = 160
	_json.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json.add_theme_font_override("font", _font)
	_json.add_theme_font_size_override("font_size", 12)
	side.add_child(_json)
	side.add_child(_button("套用上面的 JSON", _apply_json))


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrapped(text: String, font_size: int, color: Color, width: float) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(handler)
	return b
#endregion


#region 列表与草稿
func _reload_list() -> void:
	_ids = _ids_on_disk()
	_repaint_list()


## 有未保存改动的条目前面加一个点
func _repaint_list() -> void:
	_list.clear()
	for id in _ids:
		_list.add_item(("● " if _drafts.has(id) else "") + id)


func _select_in_list(id: String) -> void:
	var i := _ids.find(id)
	if i >= 0 and i < _list.item_count:
		_list.select(i)


func _on_rescan() -> void:
	_stash_current()
	_reload_list()
	_select_in_list(_draft_key())


## 丢掉当前这件的草稿，从盘上重读。只影响当前这一件
func _on_discard() -> void:
	var key := _draft_key()
	_drafts.erase(key)
	if _ids.has(key):
		_def = null
		_current_id = ""
		_open(key)
		_select_in_list(key)
	else:
		_def = null
		_current_id = ""
		_new_event()


## 当前这件在草稿表里的键：打开时的那个 id；新建的用当前 id
func _draft_key() -> String:
	if _current_id != "":
		return _current_id
	return String(_def.id) if _def != null else ""


func _stash_current() -> void:
	if _def == null:
		return
	var key := _draft_key()
	if key == "":
		return
	var now := ContentExporter.to_json(ContentExporter.export_event(_def))
	if _baseline.has(key) and _baseline[key] == now:
		_drafts.erase(key)
	else:
		_drafts[key] = _def


func _track_draft() -> void:
	var key := _draft_key()
	if key == "":
		return
	var now := ContentExporter.to_json(ContentExporter.export_event(_def))
	var was := _drafts.has(key)
	if _baseline.has(key) and _baseline[key] == now:
		_drafts.erase(key)
	else:
		_drafts[key] = _def
	if was != _drafts.has(key):
		_repaint_list()


func _open(id: String) -> void:
	if id == _draft_key() and _def != null:
		return
	_stash_current()
	if _drafts.has(id):
		_bind(_drafts[id], id)
		return
	var text := FileAccess.get_file_as_string(ContentPaths.authoring_file(KIND, id))
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]读不出 %s.json[/color]" % id
		return
	var report := ImportReport.new()
	report.source = id
	var def := ContentImporter.import_event(parsed, _ctx, report)
	# 基准必须在 _bind 之前写好，否则刚打开就被标成脏
	_baseline[id] = ContentExporter.to_json(ContentExporter.export_event(def))
	_bind(def, id)


func _load_dict(data: Dictionary, id: String) -> void:
	var report := ImportReport.new()
	report.source = id
	_bind(ContentImporter.import_event(data, _ctx, report), id)


func _bind(def: EventDef, id: String) -> void:
	_def = def
	_current_id = id
	_syncing = true
	_id_edit.text = String(_def.id)
	_image_edit.text = _def.image
	_syncing = false
	_sync_fields()
	_rebuild_form()
	_refresh()
	_repaint_list()


## 091：标题 / 正文两个框按当前语言填
func _sync_fields() -> void:
	if _def == null:
		return
	_syncing = true
	if _lang == "zh":
		_title_edit.text = _def.title
		_text_edit.text = _def.text
		_title_edit.placeholder_text = ""
		_text_edit.placeholder_text = ""
	else:
		_title_edit.text = String(_def.titles.get(_lang, ""))
		_text_edit.text = String(_def.texts.get(_lang, ""))
		_title_edit.placeholder_text = "（%s 标题，空 = 用中文：%s）" % [_lang, _def.title]
		_text_edit.placeholder_text = "（%s 正文，空 = 用中文）" % _lang
	_syncing = false


## 091：切编辑的语言
func set_lang(lang: String) -> void:
	if not UiText.LANGS.has(lang):
		lang = "zh"
	_lang = lang
	if _lang_pick != null:
		_lang_pick.select(UiText.LANGS.find(lang))
	_sync_fields()


func lang() -> String:
	return _lang


static func _put_lang(table: Dictionary, lang: String, text: String) -> void:
	if text == "":
		table.erase(lang)
	else:
		table[lang] = text


func _new_event() -> void:
	_stash_current()
	var def := EventDef.new()
	def.id = &"new_event"
	def.title = "新事件"
	def.text = "……"
	var leave := EventOption.new()
	leave.label = "离开"
	def.options.append(leave)
	_bind(def, "")
#endregion


#region 字段
func _on_id_changed(text: String) -> void:
	if _syncing or _def == null:
		return
	if _current_id == "":
		_drafts.erase(String(_def.id))   # 新建的按当前 id 记草稿，改 id 就换键，别留下旧名字
	_def.id = StringName(text)
	_refresh()


func _on_title_changed(text: String) -> void:
	if _syncing or _def == null:
		return
	if _lang == "zh":
		_def.title = text
	else:
		_put_lang(_def.titles, _lang, text)
	_refresh()


func _on_text_changed() -> void:
	if _syncing or _def == null:
		return
	if _lang == "zh":
		_def.text = _text_edit.text
	else:
		_put_lang(_def.texts, _lang, _text_edit.text)
	_refresh()


func _on_image_changed(text: String) -> void:
	if _syncing or _def == null:
		return
	_def.image = text.strip_edges()
	_refresh()


func _pick_image() -> void:
	_file_dialog.popup_centered_ratio(0.6)


## 把一张图复制到 `assets/events/<id>.<ext>`，路径写进事件。返回写进去的路径，失败返回空串并在校验栏说原因
func _import_image(src: String) -> String:
	if _def == null:
		return ""
	var id := String(_def.id).strip_edges()
	if id == "":
		_status.text = "[color=#d9534f]先给事件一个 id，配图按 id 命名[/color]"
		return ""
	if not EventImage.is_image_file(src):
		_status.text = "[color=#d9534f]只认 %s[/color]" % ", ".join(EventImage.EXTENSIONS)
		return ""
	var dest := "%s/%s.%s" % [IMAGE_DIR, id, src.get_extension().to_lower()]
	var dest_abs := ProjectSettings.globalize_path(dest)
	if src.simplify_path() != dest_abs.simplify_path():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMAGE_DIR))
		var err := DirAccess.copy_absolute(src, dest_abs)
		if err != OK:
			_status.text = "[color=#d9534f]复制图片失败（%s）[/color]" % error_string(err)
			return ""
	_def.image = dest
	_syncing = true
	_image_edit.text = dest
	_syncing = false
	_refresh()
	return dest


func _clear_image() -> void:
	if _def == null:
		return
	_def.image = ""
	_syncing = true
	_image_edit.text = ""
	_syncing = false
	_refresh()
#endregion


#region 保存
func _save() -> void:
	if _def == null:
		return
	var id := String(_def.id).strip_edges()
	if id == "":
		_status.text = "[color=#d9534f]id 不能为空[/color]"
		return
	# 校验顺带把资产也建出来了：导出成 JSON 再导入回来，和命令行导入器完全一致
	var data := ContentExporter.export_event(_def)
	var report := ImportReport.new()
	report.source = id
	var built := ContentImporter.import_event(data, _ctx, report)
	if not report.ok():
		_status.text = "[color=#d9534f]有错误，没有保存[/color]\n" + _status_text(report)
		return
	DirAccess.make_dir_recursive_absolute(EVENT_DIR)
	if ContentExporter.save(data, ContentPaths.authoring_file(KIND, id)) != OK:
		_status.text = "[color=#d9534f]作者数据写入失败[/color]"
		return
	DirAccess.make_dir_recursive_absolute(ContentPaths.EVENTS)
	if ResourceSaver.save(built, ContentPaths.asset_file(KIND, id)) != OK:
		_status.text = "[color=#f0ad4e]JSON 存了，但资产写入失败 —— 跑一次 import_content[/color]"
		return
	_drafts.erase(_draft_key())
	_drafts.erase(id)
	_baseline[id] = ContentExporter.to_json(data)
	_current_id = id
	_reload_list()
	_select_in_list(id)
	_refresh()
	_status.text = "[color=#5cb85c]已保存 %s.json，并生成 %s.tres[/color]\n" % [id, id] + _status_text(report)


func _save_as() -> void:
	_current_id = ""
	_save()


func _apply_json() -> void:
	var parsed = JSON.parse_string(_json.text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]JSON 语法错误[/color]"
		return
	_load_dict(parsed, _current_id)
#endregion


#region 挂进节点规则
static func _rules_ids() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(ContentPaths.AUTHORING_NODE_RULES)
	if d == null:
		return out
	var files := d.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out


## 这个事件现在挂在哪些规则的哪些点下：从作者数据里读，不是记在事件里的
func _placement_text() -> String:
	if _def == null:
		return ""
	var id := String(_def.id)
	var found: Array[String] = []
	for rid in _rules_ids():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file(RULES_KIND, rid)))
		if not (parsed is Dictionary):
			continue
		var ebt = (parsed as Dictionary).get("events_by_type", {})
		if not (ebt is Dictionary):
			continue
		for type in ebt:
			var table = ebt[type]
			if table is Dictionary and (table as Dictionary).has(id):
				var w := float(table[id])
				found.append("%s · %s（权重 %s）" % [rid, type, str(int(w)) if w == floorf(w) else str(w)])
	return "现在挂在：" + ("、".join(found) if not found.is_empty() else "（没有）")


## 把当前事件按权重写进某份节点规则的某种点；权重 0 = 摘下。走导入器校验，写 JSON 与 .tres
func _attach(rules_id: String, type: String, weight: float) -> ImportReport:
	var report := ImportReport.new()
	report.source = rules_id
	if _def == null:
		report.error("", "没有打开的事件")
		return report
	var id := String(_def.id).strip_edges()
	if not _ids.has(id):
		report.error("id", "先保存事件 '%s' 再挂：节点规则只能引用盘上有的事件" % id)
		return report
	var path := ContentPaths.authoring_file(RULES_KIND, rules_id)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		report.error("", "读不出 %s.json" % rules_id)
		return report
	var data := parsed as Dictionary
	var ebt: Dictionary = data.get("events_by_type", {}) if data.get("events_by_type", {}) is Dictionary else {}
	var table: Dictionary = ebt.get(type, {}) if ebt.get(type, {}) is Dictionary else {}
	if weight > 0.0:
		table[id] = int(weight) if weight == floorf(weight) else weight
		ebt[type] = table
	else:
		table.erase(id)
		if table.is_empty():
			ebt.erase(type)
		else:
			ebt[type] = table
	if ebt.is_empty():
		data.erase("events_by_type")
	else:
		data["events_by_type"] = ebt
	# 和保存事件一样：导入回来校验（引用不存在的事件、负权重都会被拦下），再按导出器的格式写
	var built := ContentImporter.import_node_rules(data, _ctx, report)
	if not report.ok():
		return report
	var out := ContentExporter.export_node_rules(built)
	if ContentExporter.save(out, path) != OK:
		report.error("", "写入失败")
		return report
	if ResourceSaver.save(built, ContentPaths.asset_file(RULES_KIND, rules_id)) != OK:
		report.warn("", "JSON 存了，但资产写入失败 —— 跑一次 import_content")
	return report


func _on_attach() -> void:
	if _rules_pick.item_count == 0:
		return
	var report := _attach(_rules_pick.get_item_text(_rules_pick.selected), _type_pick.get_item_text(_type_pick.selected), _weight.value)
	_status.text = ("[color=#5cb85c]已挂上[/color]\n" if report.ok() else "") + _status_text(report)
	_placement.text = _placement_text()


func _on_detach() -> void:
	if _rules_pick.item_count == 0:
		return
	var report := _attach(_rules_pick.get_item_text(_rules_pick.selected), _type_pick.get_item_text(_type_pick.selected), 0.0)
	_status.text = ("[color=#5cb85c]已摘下[/color]\n" if report.ok() else "") + _status_text(report)
	_placement.text = _placement_text()
#endregion


#region 刷新
func _rebuild_form() -> void:
	for c in _form_host.get_children():
		_form_host.remove_child(c)
		c.queue_free()
	if _def == null:
		return
	# 标题、正文、配图在上面有专门的控件，表单里跳过，免得两处能改同一个值
	var form := PropertyForm.create(_def, _font, {"EventDef": ["id", "title", "titles", "text", "texts", "image"]})
	form.changed.connect(_refresh)
	_form_host.add_child(form)


## 照着事件屏画（两栏：左边图，右边标题、正文、选项）；每个选项底下写条件与后果
func _rebuild_preview() -> void:
	# 先摘下来再 free：queue_free 到帧末才真的走，同一帧里数子节点会把旧的也数进去
	for c in _preview_host.get_children():
		_preview_host.remove_child(c)
		c.queue_free()
	if _def == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_preview_host.add_child(row)
	var title := _def.title if _def.title != "" else String(_def.id)
	row.add_child(_image_control(_def.image, title, Vector2(150, 240)))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	col.add_child(_label(title, 17, UiPalette.FG))
	col.add_child(HSeparator.new())
	if _def.text != "":
		col.add_child(_wrapped(_def.text, 12, UiPalette.FG, 190))
	for i in _def.options.size():
		var opt := _def.options[i] as EventOption
		if opt == null:
			continue
		var b := Button.new()
		b.text = opt.label if opt.label != "" else "（没有字）"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 13)
		b.set_meta("option", i)
		col.add_child(b)
		var notes: Array[String] = []
		for c in opt.requires:
			var cond := c as EventCondition
			if cond != null:
				notes.append("条件：" + _describe(cond))
		for o in opt.outcomes:
			var outcome := o as EventOutcome
			if outcome != null:
				notes.append("后果：" + _describe(outcome))
		if opt.hide_when_locked:
			notes.append("条件不满足时不显示")
		if notes.is_empty():
			notes.append("（什么也不做，点了就走）")
		col.add_child(_wrapped("　".join(notes), 11, UiPalette.DIM, 190))


static func _describe(construct: Object) -> String:
	var s := String(construct.call("describe"))
	return s if s != "" else String(ContentSchema.registry_name_of(construct))


## 左栏的图：铺满、按比例裁，和事件屏一个画法；没有图就深底色写占位
func _image_control(path: String, title: String, size: Vector2) -> Control:
	var area := Control.new()
	area.clip_contents = true
	area.custom_minimum_size = size
	var tex2d := EventImage.load_texture(path)
	if tex2d != null:
		var rect := TextureRect.new()
		rect.texture = tex2d
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		area.add_child(rect)
		return area
	var bg := ColorRect.new()
	bg.color = Color("0d0f12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(center)
	var col := VBoxContainer.new()
	center.add_child(col)
	var big := _label(title, 13, UiPalette.DIM.darkened(0.35))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(big)
	var hint := _label("（没有配图）" if path == "" else "（图读不到）", 10, UiPalette.DIM.darkened(0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	return area


## 校验走的就是导入器本身
func _validate() -> ImportReport:
	var report := ImportReport.new()
	report.source = String(_def.id)
	ContentImporter.import_event(ContentExporter.export_event(_def), _ctx, report)
	if _def.image != "" and EventImage.load_texture(_def.image) == null:
		report.warn("image", "配图 '%s' 读不到，事件屏上会画一块占位" % _def.image)
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
	_track_draft()
	_json.text = ContentExporter.to_json(ContentExporter.export_event(_def))
	_status.text = _status_text(_validate())
	_thumb.texture = EventImage.load_texture(_def.image)
	_thumb.custom_minimum_size = Vector2(0, 120) if _thumb.texture != null else Vector2(0, 0)
	_rebuild_preview()
	_placement.text = _placement_text()
	_rebuild_chain()
#endregion


#region 事件链（091）
## 事件链的行：[{depth, text, id}]。先是从这个事件出去的（选项 → next_event，递归、防环、最深 6 层），再是「被引用」——
## 别的事件的 next_event、节点规则的表、预设图的节点、章节的开场。id 空 = 不能跳
func chain_lines() -> Array:
	var out: Array = []
	if _def == null:
		return out
	out.append({"depth": 0, "text": "%s（%s）" % [_def.title if _def.title != "" else "（无题）", _def.id], "id": String(_def.id)})
	_walk_chain(_def, 1, [String(_def.id)], out)
	var refs := referrers(String(_def.id))
	out.append({"depth": 0, "text": "被引用" + ("：（没有）" if refs.is_empty() else "（%d 处）" % refs.size()), "id": ""})
	for r in refs:
		out.append({"depth": 1, "text": String(r["text"]), "id": String(r.get("id", ""))})
	return out


func _walk_chain(def: EventDef, depth: int, seen: Array, out: Array) -> void:
	if depth > 6:
		return
	for i in def.options.size():
		var opt := def.options[i] as EventOption
		if opt == null:
			continue
		for o in opt.outcomes:
			if not (o is NextEvent):
				continue
			var nid := String((o as NextEvent).event)
			var target: EventDef = _def if nid == String(_def.id) else _ctx.events.get(StringName(nid), null)
			var label := opt.label if opt.label != "" else "选项 %d" % (i + 1)
			var line := "「%s」→ %s" % [label, nid]
			if target == null:
				line += "（找不到）"
			elif seen.has(nid):
				line += "（回到前面：环）"
			out.append({"depth": depth, "text": line, "id": nid})
			if target != null and not seen.has(nid):
				var next_seen := seen.duplicate()
				next_seen.append(nid)
				_walk_chain(target, depth + 1, next_seen, out)


## 谁引用了这个事件：[{text, id?}]
func referrers(id: String) -> Array:
	var out: Array = []
	for eid in _ctx.events:
		if String(eid) == id:
			continue
		var e := _ctx.events[eid] as EventDef
		for opt in e.options:
			for o in (opt as EventOption).outcomes:
				if o is NextEvent and String((o as NextEvent).event) == id:
					out.append({"text": "事件 %s 的「%s」" % [eid, (opt as EventOption).label], "id": String(eid)})
	for rid in _rules_ids():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file(RULES_KIND, rid)))
		if not (parsed is Dictionary):
			continue
		var ebt = (parsed as Dictionary).get("events_by_type", {})
		if ebt is Dictionary:
			for type in ebt:
				var table = ebt[type]
				if table is Dictionary and (table as Dictionary).has(id):
					out.append({"text": "节点规则 %s · %s（权重 %s）" % [rid, type, str(table[id])]})
	var maps := DirAccess.open(MapPreset.DIR)
	if maps != null:
		for f in maps.get_files():
			if not f.ends_with(".json"):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(MapPreset.DIR + "/" + f))
			if not (parsed is Dictionary):
				continue
			var nodes = (parsed as Dictionary).get("nodes", [])
			var rows: Array = nodes if nodes is Array else ((nodes as Dictionary).values() if nodes is Dictionary else [])
			for n in rows:
				if n is Dictionary and String(((n as Dictionary).get("content", {}) as Dictionary).get("event", "")) == id:
					out.append({"text": "预设图 %s 的节点 %s" % [f.get_basename(), str((n as Dictionary).get("id", "?"))]})
	var chapters := DirAccess.open(ContentPaths.AUTHORING_CHAPTERS)
	if chapters != null:
		for f in chapters.get_files():
			if not f.ends_with(".json"):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.AUTHORING_CHAPTERS + "/" + f))
			if parsed is Dictionary and String((parsed as Dictionary).get("intro_event", "")) == id:
				out.append({"text": "章节 %s 的开场" % f.get_basename()})
	return out


func _rebuild_chain() -> void:
	if _chain == null:
		return
	_chain.clear()
	var root := _chain.create_item()
	var parents: Array = [root]
	for line in chain_lines():
		var depth := mini(int(line["depth"]), parents.size() - 1)
		var it := _chain.create_item(parents[depth])
		it.set_text(0, String(line["text"]))
		it.set_metadata(0, String(line["id"]))
		parents.resize(depth + 1)
		parents.append(it)


## 双击链里的一行：那个事件在盘上就打开它
func _open_from_chain() -> void:
	var it := _chain.get_selected()
	if it == null:
		return
	var id := String(it.get_metadata(0))
	if id == "" or id == _current_id or not _ids.has(id):
		return
	_stash_current()
	_open(id)
	_select_in_list(id)
#endregion


## [DevNav] 会问这一句再决定要不要拦一下返回
func has_unsaved_changes() -> bool:
	_stash_current()
	return not _drafts.is_empty()


## 截图工具的钩子：打开一个带条件与后果的事件
func demo_fill() -> void:
	var want := "event_stranger" if _ids.has("event_stranger") else (_ids[0] if not _ids.is_empty() else "")
	if want != "":
		_open(want)
		_select_in_list(want)

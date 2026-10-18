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
## 真要单独发给作者，用导出预设把项目导出成 exe，启动选择器就是入口。列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。
extends AuthoringEditor

## 176：带整个库的导入上下文（不写 class_name，按路径取）
const AuthoringContext := preload("res://core/authoring/authoring_context.gd")

const KIND := "events"
const EVENT_DIR := ContentPaths.AUTHORING_EVENTS
## 配图落在这里；路径写进事件的 `image`
const IMAGE_DIR := "res://assets/events"
const RULES_KIND := "node_rules"

var _id_edit: LineEdit
var _title_edit: LineEdit
var _text_edit: TextEdit
var _image_edit: LineEdit
## 196：用哪一屏演（空 = 通用事件屏 / 营地）
var _scene_pick: OptionButton
var _thumb: TextureRect
var _form_host: VBoxContainer
var _preview_host: VBoxContainer
var _rules_pick: OptionButton
var _type_pick: OptionButton
var _weight: SpinBox
var _placement: Label
var _file_dialog: FileDialog
## 091：正在编辑的语言（"zh" = 原文 title / text；别的写进 titles / texts）与事件链视图
var _lang: String = "zh"
var _lang_pick: OptionButton
var _chain: Tree


func _init() -> void:
	_kind = KIND


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_ctx = _build_context()     # 校验用的上下文：道具、buff、盘上的事件（导入器「对着别的东西查」的校验只在上下文非空时生效）
	_build_ui()
	_start()


## 道具从资产装（`ItemDatabase`），buff 走 `RunBuffs.load_all`，事件从作者数据读 —— 都是现成的路
static func _build_context() -> ContentImporter.Context:
	var ctx := AuthoringContext.context()     # 146：带上库里的 buff 与构件
	var items := ItemDatabase.new()
	items.load_dir()
	for id in items.ids():
		ctx.register_item(items.get_def(id))
	var buffs := RunBuffs.load_all()
	for id in buffs:
		ctx.register_run_buff(buffs[id])
	for id in ContentPaths.ids_in(EVENT_DIR):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file(KIND, id)))
		if parsed is Dictionary:
			ContentImporter.import_event(parsed, ctx, ImportReport.new())
	return ctx


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

	# --- 左：事件列表 ---
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 240
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(UiTheme.make_label("事件", 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var list_buttons := HBoxContainer.new()
	list_buttons.add_child(UiTheme.make_button("新建", _new_event, UiTheme.TIER_PLAIN, 13))
	list_buttons.add_child(UiTheme.make_button("刷新列表", _on_rescan, UiTheme.TIER_PLAIN, 13))
	list_buttons.add_child(UiTheme.make_button("放弃改动", _on_discard, UiTheme.TIER_PLAIN, 13))
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
	id_row.add_child(UiTheme.make_label("id", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 180
	_id_edit.text_changed.connect(_on_id_changed)
	id_row.add_child(_id_edit)
	id_row.add_child(UiTheme.make_button("保存", _save, UiTheme.TIER_PLAIN, 13))
	id_row.add_child(UiTheme.make_button("另存为新 id", _save_as, UiTheme.TIER_PLAIN, 13))
	# 091：语言切换 —— 标题 / 正文按这个语言编辑；中文是原文，别的语言写进 titles / texts（空 = 用中文）
	id_row.add_child(UiTheme.make_label("语言", 13, UiPalette.DIM))
	_lang_pick = OptionButton.new()
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
	title_row.add_child(UiTheme.make_label("标题", 13, UiPalette.DIM))
	_title_edit = LineEdit.new()
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_edit.text_changed.connect(_on_title_changed)
	title_row.add_child(_title_edit)
	body.add_child(title_row)

	body.add_child(UiTheme.make_label("正文", 13, UiPalette.DIM))
	_text_edit = TextEdit.new()
	_text_edit.custom_minimum_size.y = 120
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.add_theme_font_size_override("font_size", 14)
	_text_edit.text_changed.connect(_on_text_changed)
	body.add_child(_text_edit)

	var image_row := HBoxContainer.new()
	image_row.add_child(UiTheme.make_label("配图", 13, UiPalette.DIM))
	_image_edit = LineEdit.new()
	_image_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_edit.placeholder_text = "res://assets/events/<id>.png（可以直接填，或点导入）"
	_image_edit.text_changed.connect(_on_image_changed)
	image_row.add_child(_image_edit)
	image_row.add_child(UiTheme.make_button("导入图片…", _pick_image, UiTheme.TIER_PLAIN, 13))
	image_row.add_child(UiTheme.make_button("清除", _clear_image, UiTheme.TIER_PLAIN, 13))
	body.add_child(image_row)
	var scene_row := HBoxContainer.new()
	scene_row.add_child(UiTheme.make_label("场景", 13, UiPalette.DIM))
	_scene_pick = OptionButton.new()
	for sc in EventDef.SCENES:
		_scene_pick.add_item(SCENE_NAMES.get(sc, String(sc)))
	_scene_pick.item_selected.connect(_on_scene_selected)
	scene_row.add_child(_scene_pick)
	body.add_child(scene_row)
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

	side.add_child(UiTheme.make_label("预览（事件屏的样子）", 14, UiPalette.FG))
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

	side.add_child(UiTheme.make_label("校验", 14, UiPalette.FG))
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size.y = 80
	_status.add_theme_font_override("normal_font", _font)
	_status.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(_status)

	# 091：事件链 —— 从这个事件出去的（选项 → next_event，递归）和引用它的（别的事件 / 节点规则 / 预设图 / 章节开场）；双击一行打开那个事件
	side.add_child(UiTheme.make_label("事件链（双击跳过去）", 14, UiPalette.FG))
	_chain = Tree.new()
	_chain.hide_root = true
	_chain.custom_minimum_size.y = 150
	_chain.add_theme_font_size_override("font_size", 12)
	_chain.item_activated.connect(_open_from_chain)
	side.add_child(_chain)

	side.add_child(UiTheme.make_label("挂进节点规则（先保存）", 14, UiPalette.FG))
	_placement = UiTheme.make_label("", 12, UiPalette.DIM)
	_placement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placement.custom_minimum_size.x = 380
	side.add_child(_placement)
	var attach_row := HBoxContainer.new()
	attach_row.add_theme_constant_override("separation", 6)
	_rules_pick = OptionButton.new()
	for rid in _rules_ids():
		_rules_pick.add_item(rid)
	attach_row.add_child(_rules_pick)
	_type_pick = OptionButton.new()
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
	attach_row.add_child(_weight)
	attach_row.add_child(UiTheme.make_button("挂上", _on_attach, UiTheme.TIER_PLAIN, 13))
	attach_row.add_child(UiTheme.make_button("摘下", _on_detach, UiTheme.TIER_PLAIN, 13))
	side.add_child(attach_row)

	side.add_child(UiTheme.make_label("JSON（可直接改）", 12, UiPalette.DIM))
	_json = TextEdit.new()
	_json.custom_minimum_size.y = 160
	_json.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json.add_theme_font_size_override("font_size", 12)
	side.add_child(_json)
	side.add_child(UiTheme.make_button("套用上面的 JSON", _apply_json, UiTheme.TIER_PLAIN, 13))
#endregion


#region 列表与草稿（公共的在 AuthoringEditor）
func _export(d) -> Dictionary:
	return ContentExporter.export_event(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_event(data, _ctx, report)


func _on_bound() -> void:
	_syncing = true
	_id_edit.text = String(_def.id)
	_image_edit.text = _def.image
	_scene_pick.select(maxi(0, EventDef.SCENES.find(_def.scene)))
	_syncing = false
	_sync_fields()
	_rebuild_form()


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
	_new_entry()


func _new_def() -> Resource:
	var def := EventDef.new()
	def.id = &"new_event"
	def.title = "新事件"
	def.text = "……"
	var leave := EventOption.new()
	leave.label = "离开"
	def.options.append(leave)
	return def
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


## 196：场景下拉里的名字
const SCENE_NAMES := {&"": "通用事件屏", &"rest_camp": "营地（休息点）"}


func _on_scene_selected(i: int) -> void:
	if _syncing or _def == null:
		return
	_def.scene = EventDef.SCENES[i]
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
		var groups = (parsed as Dictionary).get("event_groups", {})
		if groups is Dictionary:
			for gname in groups:
				var g = groups[gname]
				if g is Dictionary and (g as Dictionary).get("events", {}) is Dictionary and ((g as Dictionary)["events"] as Dictionary).has(id):
					found.append("%s · 组「%s」（每图最多 %d）" % [rid, gname, int((g as Dictionary).get("max_per_map", 1))])
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
	_status.text = ("[color=#5cb85c]已挂上[/color]\n" if report.ok() else "") + report.bbcode()
	_placement.text = _placement_text()


func _on_detach() -> void:
	if _rules_pick.item_count == 0:
		return
	var report := _attach(_rules_pick.get_item_text(_rules_pick.selected), _type_pick.get_item_text(_type_pick.selected), 0.0)
	_status.text = ("[color=#5cb85c]已摘下[/color]\n" if report.ok() else "") + report.bbcode()
	_placement.text = _placement_text()
#endregion


#region 刷新
func _rebuild_form() -> void:
	UiTheme.clear_children(_form_host)
	if _def == null:
		return
	# 标题、正文、配图在上面有专门的控件，表单里跳过，免得两处能改同一个值
	_form_host.add_child(_form_for(_def, {"EventDef": ["id", "title", "titles", "text", "texts", "image"]}))


## 照着事件屏画（两栏：左边图，右边标题、正文、选项）；每个选项底下写条件与后果
func _rebuild_preview() -> void:
	UiTheme.clear_children(_preview_host)
	if _def == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_preview_host.add_child(row)
	var title := TextTemplate.plain(_def.title) if _def.title != "" else String(_def.id)     # 112：{item:} {enemy:} 换成名字
	row.add_child(EventImage.area(_def.image, title, Vector2(150, 240), 13, 10, "（图读不到）", 4))     # 和事件屏一个画法
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	col.add_child(UiTheme.make_label(title, 17, UiPalette.FG))
	col.add_child(HSeparator.new())
	if _def.text != "":
		col.add_child(UiTheme.make_wrapped(TextTemplate.plain(_def.text), 12, UiPalette.FG, 190))
	for i in _def.options.size():
		var opt := _def.options[i] as EventOption
		if opt == null:
			continue
		var b := Button.new()
		b.text = opt.label if opt.label != "" else "（没有字）"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		col.add_child(UiTheme.make_wrapped("　".join(notes), 11, UiPalette.DIM, 190))


static func _describe(construct: Object) -> String:
	var s := String(construct.call("describe"))
	return s if s != "" else String(ContentSchema.registry_name_of(construct))


## 校验走的就是导入器本身
func _validate() -> ImportReport:
	var report := super()
	if _def.image != "" and EventImage.load_texture(_def.image) == null:
		report.warn("image", "配图 '%s' 读不到，事件屏上会画一块占位" % _def.image)
	return report


func _on_refreshed() -> void:
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


## 截图工具的钩子：打开一个带条件与后果的事件
func demo_fill() -> void:
	var want := "event_stranger" if _ids.has("event_stranger") else (_ids[0] if not _ids.is_empty() else "")
	if want != "":
		_open(want)
		_select_in_list(want)

## Buff 制作器（085，作者定）：可否叠层 / 叠层上限、是否永续 / 持续时长、具体效果（从预设里挑，或开代码编辑器直接改 JSON）。
##
## 和道具 / 事件编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/buffs/<id>.json`，
## 校验走导入器（含「可叠层的永续、不许填时长」那条规矩），效果构件由 [PropertyForm] 反射生成、类型下拉来自注册表；保存同时产出 `.tres`。
## 道具里按 id 引用（`"buff": "<id>"`），内联的 buff 照旧可以在道具编辑器里写。
## 界面文字走 [UiText]：主菜单切了语言这里跟着变。
extends Control

const KIND := "buffs"
const BUFF_DIR := ContentPaths.AUTHORING_BUFFS

var _font: Font
var _ids: Array[String] = []
var _current_id: String = ""
var _def: BuffDef = null
var _drafts: Dictionary = {}
var _baseline: Dictionary = {}
var _ctx: ContentImporter.Context = null
var _syncing: bool = false

var _list: ItemList
var _id_edit: LineEdit
var _name_edit: LineEdit
var _debuff: CheckBox
var _stackable: CheckBox
var _cap: SpinBox
var _permanent: CheckBox
var _seconds: SpinBox
var _rule_note: Label
var _form_host: VBoxContainer
var _summary: Label
var _status: RichTextLabel
var _json: TextEdit


func _ready() -> void:
	_font = UiPalette.cjk_font()
	var settings := GameSettings.load_from()
	UiText.apply(settings)
	UiPalette.apply(settings)
	_ctx = ContentImporter.Context.new()
	_build_ui()
	_reload_list()
	if _ids.is_empty():
		_new_buff()
	else:
		_open(_ids[0])


static func _ids_on_disk() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(BUFF_DIR)
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

	# 左：列表
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 220
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(_label(UiText.t("buff.title"), 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_override("font", _font)
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var lb := HBoxContainer.new()
	lb.add_child(_button(UiText.t("buff.new"), _new_buff))
	lb.add_child(_button(UiText.t("buff.rescan"), _on_rescan))
	lb.add_child(_button(UiText.t("buff.discard"), _on_discard))
	left.add_child(lb)

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_split)

	# 中：字段
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(mid)
	var id_row := HBoxContainer.new()
	id_row.add_child(_label(UiText.t("buff.id"), 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 180
	_id_edit.add_theme_font_override("font", _font)
	_id_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.id = StringName(text.strip_edges())
		_refresh())
	id_row.add_child(_id_edit)
	id_row.add_child(_button(UiText.t("buff.save"), _save))
	id_row.add_child(_button(UiText.t("buff.save_as"), _save_as))
	mid.add_child(id_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	var name_row := HBoxContainer.new()
	name_row.add_child(_label(UiText.t("buff.name"), 13, UiPalette.DIM))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_override("font", _font)
	_name_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.display_name = text
		_refresh())
	name_row.add_child(_name_edit)
	_debuff = CheckBox.new()
	_debuff.text = UiText.t("buff.debuff")
	_debuff.add_theme_font_override("font", _font)
	_debuff.toggled.connect(func(on: bool):
		if _syncing or _def == null:
			return
		_def.is_debuff = on
		_refresh())
	name_row.add_child(_debuff)
	body.add_child(name_row)

	body.add_child(_label(UiText.t("buff.stacking"), 14, UiPalette.FG))
	var stack_row := HBoxContainer.new()
	stack_row.add_theme_constant_override("separation", 12)
	_stackable = CheckBox.new()
	_stackable.text = UiText.t("buff.stackable")
	_stackable.add_theme_font_override("font", _font)
	_stackable.toggled.connect(func(on: bool):
		if _syncing or _def == null:
			return
		set_stackable(on))
	stack_row.add_child(_stackable)
	stack_row.add_child(_label(UiText.t("buff.cap"), 12, UiPalette.DIM))
	_cap = SpinBox.new()
	_cap.min_value = 0
	_cap.max_value = 999
	_cap.add_theme_font_override("font", _font)
	_cap.value_changed.connect(func(v: float):
		if _syncing or _def == null:
			return
		set_cap(int(v)))
	stack_row.add_child(_cap)
	body.add_child(stack_row)

	body.add_child(_label(UiText.t("buff.duration"), 14, UiPalette.FG))
	var dur_row := HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", 12)
	_permanent = CheckBox.new()
	_permanent.text = UiText.t("buff.permanent")
	_permanent.add_theme_font_override("font", _font)
	_permanent.toggled.connect(func(on: bool):
		if _syncing or _def == null:
			return
		set_permanent(on))
	dur_row.add_child(_permanent)
	dur_row.add_child(_label(UiText.t("buff.seconds"), 12, UiPalette.DIM))
	_seconds = SpinBox.new()
	_seconds.min_value = 0
	_seconds.max_value = 600
	_seconds.step = 0.1
	_seconds.add_theme_font_override("font", _font)
	_seconds.value_changed.connect(func(v: float):
		if _syncing or _def == null:
			return
		set_seconds(v))
	dur_row.add_child(_seconds)
	body.add_child(dur_row)
	_rule_note = _label("", 12, UiPalette.DIM)
	body.add_child(_rule_note)

	body.add_child(HSeparator.new())
	body.add_child(_label(UiText.t("buff.effects"), 14, UiPalette.FG))
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_form_host)

	# 右：摘要 / 校验 / 代码
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 380
	side.add_theme_constant_override("separation", 8)
	right_split.add_child(side)
	_summary = _label("", 13, UiPalette.FG)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 360
	side.add_child(_summary)
	side.add_child(_label(UiText.t("buff.validation"), 14, UiPalette.FG))
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size.y = 90
	_status.add_theme_font_override("normal_font", _font)
	_status.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(_status)
	side.add_child(_label(UiText.t("buff.code"), 12, UiPalette.DIM))
	_json = TextEdit.new()
	_json.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json.add_theme_font_override("font", _font)
	_json.add_theme_font_size_override("font_size", 12)
	side.add_child(_json)
	side.add_child(_button(UiText.t("buff.apply_code"), _apply_json))


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


#region 字段（公开：测试直接调）
## 可叠层 = 层数上限不是 1。勾上 → 上限归 0（不限，通常如此）、时长清掉；取消 → 上限 1
func set_stackable(on: bool) -> void:
	if on:
		if _def.max_stacks == 1:
			_def.max_stacks = 0
		_def.duration_sec = 0.0
	else:
		_def.max_stacks = 1
	_sync_fields()
	_rebuild_form()
	_refresh()


func set_cap(v: int) -> void:
	_def.max_stacks = maxi(0, v)
	if _def.max_stacks != 1:
		_def.duration_sec = 0.0
	_sync_fields()
	_refresh()


func set_permanent(on: bool) -> void:
	if on:
		_def.duration_sec = 0.0
	elif _def.duration_sec <= 0.0 and not _def.is_stackable():
		_def.duration_sec = 5.0
	_sync_fields()
	_refresh()


func set_seconds(v: float) -> void:
	if _def.is_stackable():
		_def.duration_sec = 0.0
	else:
		_def.duration_sec = maxf(0.0, v)
	_sync_fields()
	_refresh()


func def() -> BuffDef:
	return _def
#endregion


#region 列表与草稿
func _reload_list() -> void:
	_ids = _ids_on_disk()
	_repaint_list()


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


func _on_discard() -> void:
	var key := _draft_key()
	_drafts.erase(key)
	_def = null
	_current_id = ""
	if _ids.has(key):
		_open(key)
		_select_in_list(key)
	else:
		_new_buff()


func _draft_key() -> String:
	if _current_id != "":
		return _current_id
	return String(_def.id) if _def != null else ""


func _dump() -> String:
	return ContentExporter.to_json(ContentExporter.export_buff(_def))


func _stash_current() -> void:
	if _def == null:
		return
	var key := _draft_key()
	if key == "":
		return
	var now := _dump()
	if _baseline.has(key) and _baseline[key] == now:
		_drafts.erase(key)
	else:
		_drafts[key] = _def


func _track_draft() -> void:
	var key := _draft_key()
	if key == "":
		return
	var was := _drafts.has(key)
	# 新建的 buff 还没存盘时草稿键就是它的 id；作者改了 id，旧键下那份就是同一个对象，不能留成孤儿
	for k in _drafts.keys():
		if k != key and _drafts[k] == _def:
			_drafts.erase(k)
	var now := _dump()
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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file(KIND, id)))
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]%s.json ?[/color]" % id
		return
	var report := ImportReport.new()
	report.source = id
	var def := ContentImporter.import_buff(parsed, _ctx, report)
	_baseline[id] = ContentExporter.to_json(ContentExporter.export_buff(def))
	_bind(def, id)


func _new_buff() -> void:
	_stash_current()
	var def := BuffDef.new()
	def.id = &"new_buff"
	def.display_name = "新 buff" if UiText.lang == "zh" else "New buff"
	def.max_stacks = 0     # 作者定：通常不限层，且可叠层的永续
	_bind(def, "")


func _bind(def: BuffDef, id: String) -> void:
	_def = def
	_current_id = id
	_sync_fields()
	_rebuild_form()
	_refresh()
	_repaint_list()


func _sync_fields() -> void:
	_syncing = true
	_id_edit.text = String(_def.id)
	_name_edit.text = _def.display_name
	_debuff.button_pressed = _def.is_debuff
	var stackable := _def.is_stackable()
	_stackable.button_pressed = stackable
	_cap.value = _def.max_stacks
	_cap.editable = stackable
	_permanent.button_pressed = _def.is_permanent()
	_permanent.disabled = stackable
	_seconds.value = _def.duration_sec
	_seconds.editable = not stackable and not _def.is_permanent()
	_rule_note.text = UiText.t("buff.permanent_forced") if stackable else ""
	_syncing = false


func _rebuild_form() -> void:
	for c in _form_host.get_children():
		_form_host.remove_child(c)
		c.queue_free()
	if _def == null:
		return
	var form := PropertyForm.create(_def, _font, {"BuffDef": ["id", "display_name", "is_debuff", "max_stacks", "duration_sec", "refresh_on_restack"]})
	form.changed.connect(_refresh)
	_form_host.add_child(form)
#endregion


#region 保存与校验
func _validate() -> ImportReport:
	var report := ImportReport.new()
	report.source = String(_def.id)
	ContentImporter.import_buff(ContentExporter.export_buff(_def), _ctx, report)
	return report


func _status_text(report: ImportReport) -> String:
	var lines: Array[String] = []
	for e in report.errors:
		lines.append("[color=#d9534f]✗ %s：%s[/color]" % [e["path"], e["message"]])
	for w in report.warnings:
		lines.append("[color=#f0ad4e]! %s：%s[/color]" % [w["path"], w["message"]])
	if lines.is_empty():
		lines.append("[color=#5cb85c]%s[/color]" % UiText.t("buff.ok"))
	return "\n".join(lines)


func summary_text() -> String:
	if _def == null:
		return ""
	var stacks := UiText.t("buff.stacks_single") if not _def.is_stackable() else (UiText.t("buff.stacks_unlimited") if _def.max_stacks == 0 else UiText.t("buff.stacks_cap") % _def.max_stacks)
	var dur := (UiText.t("buff.permanent") if _def.is_permanent() else "%s %.1f" % [UiText.t("buff.seconds"), _def.duration_sec])
	return "%s\n%s\n%s" % [UiText.t("buff.summary") % [stacks, dur], "%d mods · %d rules · %d on_apply · %d on_expire" % [_def.mods.size(), _def.rules.size(), _def.on_apply.size(), _def.on_expire.size()], UiText.t("buff.usage") % String(_def.id)]


func _refresh() -> void:
	if _def == null:
		return
	_track_draft()
	_json.text = _dump()
	_status.text = _status_text(_validate())
	_summary.text = summary_text()


func _save() -> void:
	if _def == null:
		return
	var id := String(_def.id).strip_edges()
	if id == "":
		_status.text = "[color=#d9534f]%s[/color]" % UiText.t("buff.err_id")
		return
	var data := ContentExporter.export_buff(_def)
	var report := ImportReport.new()
	report.source = id
	var built := ContentImporter.import_buff(data, _ctx, report)
	if not report.ok():
		_status.text = "[color=#d9534f]%s[/color]\n" % UiText.t("buff.err_save") + _status_text(report)
		return
	DirAccess.make_dir_recursive_absolute(BUFF_DIR)
	if ContentExporter.save(data, ContentPaths.authoring_file(KIND, id)) != OK:
		_status.text = "[color=#d9534f]%s[/color]" % UiText.t("buff.err_write")
		return
	DirAccess.make_dir_recursive_absolute(ContentPaths.BUFFS)
	if ResourceSaver.save(built, ContentPaths.asset_file(KIND, id)) != OK:
		_status.text = "[color=#f0ad4e]%s[/color]" % UiText.t("buff.warn_asset")
		return
	_drafts.erase(_draft_key())
	_drafts.erase(id)
	_baseline[id] = ContentExporter.to_json(data)
	_current_id = id
	_reload_list()
	_select_in_list(id)
	_refresh()
	_status.text = "[color=#5cb85c]%s[/color]\n" % (UiText.t("buff.saved") % [id, id]) + _status_text(report)


func _save_as() -> void:
	_current_id = ""
	_save()


func _apply_json() -> void:
	var parsed = JSON.parse_string(_json.text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]%s[/color]" % UiText.t("buff.err_json")
		return
	var report := ImportReport.new()
	report.source = _current_id
	_bind(ContentImporter.import_buff(parsed, _ctx, report), _current_id)


## [DevNav] 会问这一句再决定要不要拦一下返回
func has_unsaved_changes() -> bool:
	_stash_current()
	return not _drafts.is_empty()
#endregion

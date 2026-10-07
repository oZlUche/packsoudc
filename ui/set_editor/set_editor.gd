## 套装编辑器（091，作者定）：给作者做套装 —— id、名字、计数方式、各档位（集齐几件生效什么：属性修饰 / 规则 / 别的作用域的效果）。
##
## 和道具 / 事件 / buff 编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/sets/<id>.json`，
## 校验走导入器（`import_set`），档位与效果构件由 [PropertyForm] 反射生成（字段中文 + 悬浮说明走 [FieldText]）；保存同时产出 `.tres`。
## 哪些道具属于这套看右边的「成员」：道具的 `set_id` 写这个 id 就算（在道具编辑器里改）。
extends Control

const KIND := "sets"
const SET_DIR := ContentPaths.AUTHORING_SETS
const PropertyFormScript := preload("res://ui/editor/property_form.gd")

var _font: Font
var _ids: Array[String] = []
var _current_id: String = ""
var _def: ItemSetDef = null
var _drafts: Dictionary = {}
var _baseline: Dictionary = {}
var _ctx: ContentImporter.Context = null
var _items: ItemDatabase = null
var _syncing: bool = false

var _list: ItemList
var _id_edit: LineEdit
var _name_edit: LineEdit
var _form_host: VBoxContainer
var _summary: Label
var _members: Label
var _status: RichTextLabel
var _json: TextEdit


func _ready() -> void:
	_font = UiPalette.cjk_font()
	var settings := GameSettings.load_from()
	UiText.apply(settings)
	UiPalette.apply(settings)
	_ctx = ContentImporter.Context.new()
	_items = ItemDatabase.new()
	_items.load_dir()
	_build_ui()
	_reload_list()
	if _ids.is_empty():
		_new_set()
	else:
		_open(_ids[0])


static func _ids_on_disk() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(SET_DIR)
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
	UiTheme.prepare_root(self, false)     # 121：装上界面主题、铺底色（设置在 _ready 里已经读过、apply 过）
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
	left.add_child(UiTheme.make_label("套装", 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_override("font", _font)
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var lb := HBoxContainer.new()
	lb.add_child(UiTheme.make_button("新建", _new_set, UiTheme.TIER_PLAIN, 13))
	lb.add_child(UiTheme.make_button("刷新列表", _on_rescan, UiTheme.TIER_PLAIN, 13))
	lb.add_child(UiTheme.make_button("放弃改动", _on_discard, UiTheme.TIER_PLAIN, 13))
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
	id_row.add_child(UiTheme.make_label("id", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 180
	_id_edit.add_theme_font_override("font", _font)
	_id_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.id = StringName(text.strip_edges())
		_refresh())
	id_row.add_child(_id_edit)
	id_row.add_child(UiTheme.make_button("保存", _save, UiTheme.TIER_PLAIN, 13))
	id_row.add_child(UiTheme.make_button("另存为新 id", _save_as, UiTheme.TIER_PLAIN, 13))
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
	name_row.add_child(UiTheme.make_label("名字", 13, UiPalette.DIM))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_override("font", _font)
	_name_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.display_name = text
		_refresh())
	name_row.add_child(_name_edit)
	body.add_child(name_row)
	body.add_child(UiTheme.make_wrapped("档位按件数升序、**累加**生效：4 件套同享 2 件档与 4 件档；要互斥就把高档写成增量。每档三个列表：属性修饰（编译期并入）、规则（要扳机）、别的作用域的效果（激活即生效）。", 12, UiPalette.DIM, 520))
	body.add_child(HSeparator.new())
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_form_host)

	# 右：摘要 / 成员 / 校验 / 代码
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 380
	side.add_theme_constant_override("separation", 8)
	right_split.add_child(side)
	_summary = UiTheme.make_wrapped("", 13, UiPalette.FG, 360)
	side.add_child(_summary)
	side.add_child(UiTheme.make_label("成员（道具的 set_id 写这个 id；在道具编辑器里改）", 13, UiPalette.DIM))
	_members = UiTheme.make_wrapped("", 12, UiPalette.FG, 360)
	side.add_child(_members)
	side.add_child(UiTheme.make_label("校验", 14, UiPalette.FG))
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size.y = 90
	_status.add_theme_font_override("normal_font", _font)
	_status.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(_status)
	side.add_child(UiTheme.make_label("JSON（可直接改）", 12, UiPalette.DIM))
	_json = TextEdit.new()
	_json.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json.add_theme_font_override("font", _font)
	_json.add_theme_font_size_override("font_size", 12)
	side.add_child(_json)
	side.add_child(UiTheme.make_button("套用上面的 JSON", _apply_json, UiTheme.TIER_PLAIN, 13))

#endregion


#region 公开（测试直接调）
func def() -> ItemSetDef:
	return _def


## 属于这套的道具 id（道具的 set_id == 当前 id）
func members() -> Array[String]:
	var out: Array[String] = []
	if _def == null or _items == null:
		return out
	for id in _items.all_ids():
		if _items.get_def(id).set_id == _def.id:
			out.append(String(id))
	out.sort()
	return out


func summary_text() -> String:
	if _def == null:
		return ""
	var parts: Array[String] = []
	for t in _def.tiers:
		var tier := t as SetTier
		if tier != null:
			parts.append("%d 件：%d 修饰 / %d 规则 / %d 效果" % [tier.pieces, tier.mods.size(), tier.rules.size(), tier.effects.size()])
	var mode := "同一定义只算一次" if _def.count_mode == ItemSetDef.CountMode.DISTINCT_DEFS else "每件实例算一件"
	return "%s（%s）　%s\n%s" % [_def.display_name, _def.id, mode, "　".join(parts) if not parts.is_empty() else "（还没有档位）"]


## 加一档（集齐 [param pieces] 件）；测试与「新建」用
func add_tier(pieces: int) -> SetTier:
	var tier := SetTier.new()
	tier.pieces = pieces
	_def.tiers.append(tier)
	_def.tiers.sort_custom(func(a: SetTier, b: SetTier) -> bool: return a.pieces < b.pieces)
	_rebuild_form()
	_refresh()
	return tier
#endregion


#region 列表与草稿
func _reload_list() -> void:
	_ids = _ids_on_disk()
	for key in _drafts:
		if not _ids.has(key):
			_ids.append(key)
	_ids.sort()
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
	if _ids.has(key) and FileAccess.file_exists(ContentPaths.authoring_file(KIND, key)):
		_open(key)
		_select_in_list(key)
	else:
		_reload_list()
		if _ids.is_empty():
			_new_set()
		else:
			_open(_ids[0])


func _draft_key() -> String:
	if _current_id != "":
		return _current_id
	return String(_def.id) if _def != null else ""


func _dump() -> String:
	return ContentExporter.to_json(ContentExporter.export_set(_def))


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
	var dirty := false
	for k in _drafts.keys():
		if k != key and _drafts[k] == _def:
			_drafts.erase(k)
			if not FileAccess.file_exists(ContentPaths.authoring_file(KIND, k)):
				_ids.erase(k)
			dirty = true
	var now := _dump()
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


func _open(id: String) -> void:
	if id == _draft_key() and _def != null:
		return
	_stash_current()
	if _drafts.has(id):
		_bind(_drafts[id], id)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file(KIND, id)))
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]%s.json 读不到[/color]" % id
		return
	var report := ImportReport.new()
	report.source = id
	var def := ContentImporter.import_set(parsed, _ctx, report)
	_baseline[id] = ContentExporter.to_json(ContentExporter.export_set(def))
	_bind(def, id)


func _new_set() -> void:
	_stash_current()
	var def := ItemSetDef.new()
	def.id = &"new_set"
	def.display_name = "新套装"
	var tier := SetTier.new()
	tier.pieces = 2
	def.tiers.append(tier)
	_bind(def, "")


func _bind(def: ItemSetDef, id: String) -> void:
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
	_syncing = false


func _rebuild_form() -> void:
	UiTheme.clear_children(_form_host)
	if _def == null:
		return
	var form = PropertyFormScript.create(_def, _font, {"ItemSetDef": ["id", "display_name"]})
	form.changed.connect(_refresh)
	_form_host.add_child(form)
#endregion


#region 保存与校验
func _validate() -> ImportReport:
	var report := ImportReport.new()
	report.source = String(_def.id)
	ContentImporter.import_set(ContentExporter.export_set(_def), _ctx, report)
	return report


func _status_text(report: ImportReport) -> String:
	var lines: Array[String] = []
	for e in report.errors:
		lines.append("[color=#d9534f]✗ %s：%s[/color]" % [e["path"], e["message"]])
	for w in report.warnings:
		lines.append("[color=#f0ad4e]! %s：%s[/color]" % [w["path"], w["message"]])
	if lines.is_empty():
		lines.append("[color=#5cb85c]没有问题[/color]")
	return "\n".join(lines)


func _refresh() -> void:
	if _def == null:
		return
	_track_draft()
	_json.text = _dump()
	_status.text = _status_text(_validate())
	_summary.text = summary_text()
	var who := members()
	_members.text = "、".join(who) if not who.is_empty() else "（还没有道具的 set_id 写着这个 id）"


func _save() -> void:
	if _def == null:
		return
	var id := String(_def.id).strip_edges()
	if id == "":
		_status.text = "[color=#d9534f]先给一个 id[/color]"
		return
	var data := ContentExporter.export_set(_def)
	var report := ImportReport.new()
	report.source = id
	var built := ContentImporter.import_set(data, _ctx, report)
	if not report.ok():
		_status.text = "[color=#d9534f]有错，没存[/color]\n" + _status_text(report)
		return
	DirAccess.make_dir_recursive_absolute(SET_DIR)
	if ContentExporter.save(data, ContentPaths.authoring_file(KIND, id)) != OK:
		_status.text = "[color=#d9534f]写不进作者目录[/color]"
		return
	DirAccess.make_dir_recursive_absolute(ContentPaths.SETS)
	if ResourceSaver.save(built, ContentPaths.asset_file(KIND, id)) != OK:
		_status.text = "[color=#f0ad4e]JSON 存了，.tres 没写成[/color]"
		return
	_drafts.erase(_draft_key())
	_drafts.erase(id)
	_baseline[id] = ContentExporter.to_json(data)
	_current_id = id
	_reload_list()
	_select_in_list(id)
	_refresh()
	_status.text = "[color=#5cb85c]已存：sets/%s.json 与 .tres[/color]\n" % id + _status_text(report)


func _save_as() -> void:
	_current_id = ""
	_save()


func _apply_json() -> void:
	var parsed = JSON.parse_string(_json.text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]JSON 读不通[/color]"
		return
	var report := ImportReport.new()
	report.source = _current_id
	_bind(ContentImporter.import_set(parsed, _ctx, report), _current_id)


## [DevNav] 会问这一句再决定要不要拦一下返回
func has_unsaved_changes() -> bool:
	_stash_current()
	return not _drafts.is_empty()
#endregion

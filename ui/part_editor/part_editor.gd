## 146：构件编辑器 —— 规则构件库（`data/authoring/rule_parts`）：填好数值、起了名字的扳机 / 节奏 / 消耗与检查 / 效果。
##
## 别的编辑器里「添加」的下拉有一组「库：」列的就是这里的东西；选了 = 复制一份、来自库（只读，「断开」才能改）。
## 改了库里的一份、存盘，所有引用它的规则下次导入一起变 —— 删之前看右边「谁在用」。
## 左边按类分页（144 的分组行做法）+ 搜索；列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。
extends AuthoringEditor

const KIND := "rule_parts"
## 分组：标题、构件的字段（空 = 全部）
const GROUPS := [["全部", ""], ["扳机", "trigger"], ["节奏", "cadence"], ["消耗与检查", "cost"], ["效果", "effect"]]
const PART_TEXTS := {
	"ok": "没有问题", "unreadable": "%s.json 读不到", "err_id": "先给一个 id", "err_save": "有错，没存",
	"err_write": "写不进作者目录", "warn_asset": "JSON 存了，.tres 没写成", "err_json": "JSON 读不通",
}

## 列表里实际显示的 id（按显示顺序；ItemList 的行号对它）
var _shown: Array[String] = []
var _group: int = 0
## 列表键 → 它是哪一类（构件的字段名）/ 名字。列表重读时从盘上读
var _slot_of: Dictionary = {}
var _name_of: Dictionary = {}

var _group_host: HBoxContainer
var _search: LineEdit
var _id_edit: LineEdit
var _name_edit: LineEdit
var _slot_pick: OptionButton
var _preview: Label
var _form_host: VBoxContainer
var _users: Label


func _init() -> void:
	_kind = KIND


func _ready() -> void:
	_font = UiPalette.cjk_font()
	var settings := GameSettings.load_from()
	UiText.apply(settings)
	UiPalette.apply(settings)
	_ctx = ContentLibrary.context()     # 构件里的施加状态按 id 引用库里的 buff
	_build_ui()
	_start()


#region 界面
func _build_ui() -> void:
	UiTheme.prepare_root(self, false)
	var pad := PanelContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.panel(pad, 14)
	add_child(pad)
	var columns := HSplitContainer.new()
	pad.add_child(columns)

	# 左：分组 + 搜索 + 列表
	var left := UiTheme.vbox(6)
	left.custom_minimum_size.x = 300
	columns.add_child(left)
	left.add_child(UiTheme.make_label("规则构件", 16, UiPalette.FG))
	_group_host = UiTheme.hbox(4)
	for i in GROUPS.size():
		var gi := i
		var b := Button.new()
		b.toggle_mode = true
		b.set_meta("group", gi)
		b.pressed.connect(func() -> void:
			_group = gi
			_repaint_list())
		_group_host.add_child(b)
	left.add_child(_group_host)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索 id / 名字"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _repaint_list())
	left.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void:
		if i < _shown.size():
			_open(_shown[i]))
	left.add_child(_list)
	var lb := UiTheme.hbox(4)
	lb.add_child(UiTheme.make_button("新建", _new_part, UiTheme.TIER_PLAIN, 13))
	lb.add_child(UiTheme.make_button("刷新列表", _on_rescan, UiTheme.TIER_PLAIN, 13))
	lb.add_child(UiTheme.make_button("放弃改动", _on_discard, UiTheme.TIER_PLAIN, 13))
	left.add_child(lb)

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_split)

	# 中：id、名字、类别、预览、字段
	var mid := UiTheme.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(mid)
	var id_row := UiTheme.hbox(6)
	id_row.add_child(UiTheme.make_label("id", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 180
	_id_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.id = StringName(text.strip_edges())
		_refresh())
	id_row.add_child(_id_edit)
	id_row.add_child(UiTheme.make_button("保存", _save, UiTheme.TIER_PLAIN, 13))
	id_row.add_child(UiTheme.make_button("另存为新 id", _save_as, UiTheme.TIER_PLAIN, 13))
	mid.add_child(id_row)
	var name_row := UiTheme.hbox(6)
	name_row.add_child(UiTheme.make_label("名字", 13, UiPalette.DIM))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.display_name = text
		_refresh())
	name_row.add_child(_name_edit)
	mid.add_child(name_row)
	var slot_row := UiTheme.hbox(6)
	slot_row.add_child(UiTheme.make_label("类别", 13, UiPalette.DIM))
	_slot_pick = OptionButton.new()
	for i in range(1, GROUPS.size()):
		_slot_pick.add_item(GROUPS[i][0], i)
	_slot_pick.item_selected.connect(func(idx: int) -> void:
		if _syncing or _def == null:
			return
		set_slot(String(GROUPS[_slot_pick.get_item_id(idx)][1])))
	slot_row.add_child(_slot_pick)
	mid.add_child(slot_row)
	_preview = UiTheme.make_wrapped("", 14, UiPalette.FG, 420)
	mid.add_child(_preview)
	mid.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_form_host = UiTheme.vbox(8)
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form_host)

	# 右：谁在用 / 校验 / JSON
	var side := UiTheme.vbox(8)
	side.custom_minimum_size.x = 360
	right_split.add_child(side)
	side.add_child(UiTheme.make_label("谁在用（改了它这些都跟着变）", 13, UiPalette.DIM))
	_users = UiTheme.make_wrapped("", 12, UiPalette.FG, 340)
	side.add_child(_users)
	side.add_child(UiTheme.make_label("校验", 14, UiPalette.FG))
	_status = UiTheme.rich_block(340, 12)
	_status.custom_minimum_size.y = 90
	side.add_child(_status)
	side.add_child(UiTheme.make_label("JSON（可直接改）", 12, UiPalette.DIM))
	_json = TextEdit.new()
	_json.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_json)
	side.add_child(UiTheme.make_button("套用上面的 JSON", _apply_json, UiTheme.TIER_PLAIN, 13))
#endregion


#region 公开（测试直接调）
func def() -> RulePartDef:
	return _def


## 换类别：别的三个字段清掉（一份构件只装一样东西），表单只露这一类
func set_slot(slot: String) -> void:
	if _def == null:
		return
	for key in RulePartDef.SLOTS:
		if key != slot:
			_def.set(key, null)
	_def.set_meta(&"slot", slot)
	_rebuild_form()
	_refresh()


## 当前这份是哪一类（字段名）：填了的那一个；都没填看「类别」下拉
func slot() -> String:
	if _def == null:
		return ""
	for key in RulePartDef.SLOTS:
		if _def.get(key) != null:
			return key
	return String(_def.get_meta(&"slot", "effect"))


## 引用这份构件（`"@id"`）的作者数据：「种类/id」
func users(id: String = "") -> Array[String]:
	if id == "":
		id = String(_def.id) if _def != null else ""
	var out: Array[String] = []
	if id == "":
		return out
	var needle := "\"@%s\"" % id
	for kind in ContentPaths.ORDER:
		if kind == KIND:
			continue
		var dir: String = ContentPaths.KINDS[kind][0]
		for fid in ContentPaths.ids_in(dir):
			if FileAccess.get_file_as_string("%s/%s.json" % [dir, fid]).contains(needle):
				out.append("%s/%s" % [kind, fid])
	return out
#endregion


#region 列表、分组、搜索
func _on_list_reloaded() -> void:
	_slot_of.clear()
	_name_of.clear()
	for id in _ids:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_file_of(id)))
		if parsed is Dictionary:
			_name_of[id] = String(parsed.get("display_name", ""))
			for key in RulePartDef.SLOTS:
				if parsed.has(key):
					_slot_of[id] = key


func _slot_for(id: String) -> String:
	if id == _draft_key() and _def != null:
		return slot()
	if _drafts.has(id):
		var d: RulePartDef = _drafts[id]
		for key in RulePartDef.SLOTS:
			if d.get(key) != null:
				return key
		return ""
	return String(_slot_of.get(id, ""))


func _matches(id: String, group: int) -> bool:
	var want := String(GROUPS[group][1])
	if want != "" and _slot_for(id) != want:
		return false
	var q := _search.text.strip_edges().to_lower()
	return q == "" or id.to_lower().contains(q) or String(_name_of.get(id, "")).to_lower().contains(q)


func _repaint_list() -> void:
	for child in _group_host.get_children():
		var b := child as Button
		var g: int = b.get_meta("group")
		var n := 0
		for id in _ids:
			if _matches(id, g):
				n += 1
		b.text = "%s %d" % [GROUPS[g][0], n]
		b.button_pressed = g == _group
	_shown.clear()
	_list.clear()
	for id in _ids:
		if _matches(id, _group):
			_shown.append(id)
			var name := String(_name_of.get(id, ""))
			_list.add_item(("● " if _drafts.has(id) else "") + id + ("　" + name if name != "" and name != id else ""))
	if _shown.is_empty():
		var row := _list.add_item("没有匹配的构件")
		_list.set_item_selectable(row, false)
	var i := _shown.find(_draft_key())
	if i >= 0:
		_list.select(i)


func _select_in_list(id: String) -> void:
	if not _matches(id, _group):
		_group = 0
		_search.text = ""
		_repaint_list()
	var i := _shown.find(id)
	if i >= 0 and i < _list.item_count:
		_list.select(i)
#endregion


#region 草稿与表单（公共的在 AuthoringEditor）
func _export(d) -> Dictionary:
	return ContentExporter.dump(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_rule_part(data, _ctx, report)


func _new_def() -> Resource:
	var def := RulePartDef.new()
	def.id = &"new_part"
	def.display_name = "新构件"
	def.set_meta(&"slot", "effect")
	return def


func _new_part() -> void:
	_new_entry()
	_select_in_list(_draft_key())


func _on_bound() -> void:
	_syncing = true
	_id_edit.text = String(_def.id)
	_name_edit.text = _def.display_name
	var s := slot()
	for i in _slot_pick.item_count:
		if String(GROUPS[_slot_pick.get_item_id(i)][1]) == s:
			_slot_pick.select(i)
	_syncing = false
	_rebuild_form()


func _rebuild_form() -> void:
	UiTheme.clear_children(_form_host)
	if _def == null:
		return
	var form := _form_for(_def, {})
	form.parts_allowed = false     # 构件不套构件
	form.only = [slot(), "display_names"]
	_form_host.add_child(form)


func _on_refreshed() -> void:
	var text := (_def as RulePartDef).preview()
	_preview.text = text if text != "" else "（还没填：在下面「添加」一个）"
	var who := users()
	_users.text = "\n".join(who) if not who.is_empty() else "（没有）"


func _t(key: String) -> String:
	return String(PART_TEXTS.get(key, key))


func _saved_text(id: String) -> String:
	return "已存：rule_parts/%s.json 与 .tres" % id
#endregion

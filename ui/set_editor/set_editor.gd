## 套装编辑器（091，作者定）：给作者做套装 —— id、名字、计数方式、各档位（集齐几件生效什么：属性修饰 / 规则 / 别的作用域的效果）。
##
## 和道具 / 事件 / buff 编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/sets/<id>.json`，
## 校验走导入器（`import_set`），档位与效果构件由 [PropertyForm] 反射生成（字段中文 + 悬浮说明走 [FieldText]）；保存同时产出 `.tres`。
## 哪些道具属于这套看右边的「成员」：道具的 `set_id` 写这个 id 就算（在道具编辑器里改）。列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。
extends AuthoringEditor

const KIND := "sets"
const SET_TEXTS := {
	"ok": "没有问题", "unreadable": "%s.json 读不到", "err_id": "先给一个 id", "err_save": "有错，没存",
	"err_write": "写不进作者目录", "warn_asset": "JSON 存了，.tres 没写成", "err_json": "JSON 读不通",
}

var _items: ItemDatabase = null

var _id_edit: LineEdit
var _name_edit: LineEdit
var _form_host: VBoxContainer
var _summary: Label
var _members: Label


func _init() -> void:
	_kind = KIND


func _ready() -> void:
	_font = UiPalette.cjk_font()
	var settings := GameSettings.load_from()
	UiText.apply(settings)
	UiPalette.apply(settings)
	_ctx = ContentLibrary.context()     # 146：档位的规则可以引用库里的 buff 与构件
	_items = ItemDatabase.new()
	_items.load_dir()
	_build_ui()
	_start()


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
	var mode: String = "同一定义只算一次" if _def.count_mode == ItemSetDef.CountMode.DISTINCT_DEFS else "每件实例算一件"
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


#region 列表与草稿（公共的在 AuthoringEditor）
func _export(d) -> Dictionary:
	return ContentExporter.export_set(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_set(data, _ctx, report)


func _new_def() -> Resource:
	var def := ItemSetDef.new()
	def.id = &"new_set"
	def.display_name = "新套装"
	var tier := SetTier.new()
	tier.pieces = 2
	def.tiers.append(tier)
	return def


func _new_set() -> void:
	_new_entry()


func _on_bound() -> void:
	_sync_fields()
	_rebuild_form()


func _sync_fields() -> void:
	_syncing = true
	_id_edit.text = String(_def.id)
	_name_edit.text = _def.display_name
	_syncing = false


func _rebuild_form() -> void:
	UiTheme.clear_children(_form_host)
	if _def == null:
		return
	_form_host.add_child(_form_for(_def, {"ItemSetDef": ["id", "display_name"]}))
#endregion


#region 刷新与提示语
func _t(key: String) -> String:
	return String(SET_TEXTS.get(key, key))


func _saved_text(id: String) -> String:
	return "已存：sets/%s.json 与 .tres" % id


func _on_refreshed() -> void:
	_summary.text = summary_text()
	var who := members()
	_members.text = "、".join(who) if not who.is_empty() else "（还没有道具的 set_id 写着这个 id）"
#endregion

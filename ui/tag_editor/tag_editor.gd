## 标签制作器（171，作者定）：标签不是道具随手写的，得先在这里建 —— id、名字、多语言、说明、大类（用途 / 属性 / 材料 / 归属 / 来源 / 内部）、
## 弹不弹词条、是不是内部标签。道具编辑器的标签栏只能从登记过的标签里挑（按大类分组的下拉）。
## 193：一栏「图标」—— `assets/ui/tags/` 下的文件名（空 = 用 id），右边按悬浮窗的大小（`FaithTooltip.ICON_SIZE`）预览，读不出写「无图」
##
## 和别的编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/tags/<id>.json`，
## 校验走导入器（`import_tag`：得有名字、得归一类），字段由 [PropertyForm] 反射生成；保存同时产出 `.tres`、登记进 [TagRegistry]。
## 列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。右边看哪些道具带着它。
extends AuthoringEditor

## 176：带整个库的导入上下文（不写 class_name，按路径取）
const AuthoringContext := preload("res://core/authoring/authoring_context.gd")

const KIND := "tags"
const TAG_TEXTS := {
	"ok": "没有问题", "unreadable": "%s.json 读不到", "err_id": "先给一个 id", "err_save": "有错，没存",
	"err_write": "写不进作者目录", "warn_asset": "JSON 存了，.tres 没写成", "err_json": "JSON 读不通",
}

var _items: ItemDatabase = null

var _id_edit: LineEdit
var _name_edit: LineEdit
var _icon_edit: LineEdit
var _icon_preview: TextureRect
var _icon_note: Label
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
	_ctx = AuthoringContext.context()
	_items = ItemDatabase.new()
	_items.load_dir()
	_build_ui()
	_start()


#region 界面
func _build_ui() -> void:
	UiTheme.prepare_root(self, false)
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
	left.add_child(UiTheme.make_label("标签", 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var lb := HBoxContainer.new()
	lb.add_child(UiTheme.make_button("新建", _new_tag, UiTheme.TIER_PLAIN, 13))
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
	var icon_row := HBoxContainer.new()
	icon_row.add_child(UiTheme.make_label("图标", 13, UiPalette.DIM))
	_icon_edit = LineEdit.new()
	_icon_edit.placeholder_text = "空 = 用 id"
	_icon_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.icon = text.strip_edges()
		_refresh())
	icon_row.add_child(_icon_edit)
	_icon_preview = TextureRect.new()
	_icon_preview.custom_minimum_size = Vector2.ONE * FaithTooltip.ICON_SIZE
	_icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_row.add_child(_icon_preview)
	_icon_note = UiTheme.make_label("", 12, UiPalette.DIM)
	icon_row.add_child(_icon_note)
	body.add_child(icon_row)
	body.add_child(UiTheme.make_wrapped("大类：用途（武器、防具……）/ 属性（火焰、毒……）/ 材料（金属、木制……）/ 归属（帝国、蛮族……）/ 来源（工艺、自然、魔法：每件材料恰好一个）/ 内部（只给内容逻辑用，玩家看不到）。悬浮窗的标签行按这个顺序排。", 12, UiPalette.DIM, 520))
	body.add_child(HSeparator.new())
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_form_host)

	# 右：摘要 / 用到它的道具 / 校验 / 代码
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 380
	side.add_theme_constant_override("separation", 8)
	right_split.add_child(side)
	_summary = UiTheme.make_wrapped("", 13, UiPalette.FG, 360)
	side.add_child(_summary)
	side.add_child(UiTheme.make_label("带着它的道具", 13, UiPalette.DIM))
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
func def() -> TagDef:
	return _def


## 带着这个标签的道具 id
func members() -> Array[String]:
	var out: Array[String] = []
	if _def == null or _items == null:
		return out
	for id in _items.all_ids():
		if _items.get_def(id).tags.has(_def.id):
			out.append(String(id))
	out.sort()
	return out


## 193：图标预览读的那张图（`assets/ui/tags/<图标或 id>.png`）；没图空串
func icon_preview_path() -> String:
	if _def == null:
		return ""
	return TagRegistry.icon_path_of_file(_def.icon if _def.icon != "" else String(_def.id))


func summary_text() -> String:
	if _def == null:
		return ""
	var cat := FieldText.enum_label(_def.category) if _def.category != "" else "（还没归类）"
	return "%s（%s）　%s%s" % [_def.display_name, _def.id, cat, "　内部" if _def.internal else ""]
#endregion


#region 列表与草稿（公共的在 AuthoringEditor）
func _export(d) -> Dictionary:
	return ContentExporter.export_tag(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_tag(data, _ctx, report)


func _new_def() -> Resource:
	var def := TagDef.new()
	def.id = &"new_tag"
	def.display_name = "新标签"
	def.category = "purpose"
	def.tip = false
	return def


func _new_tag() -> void:
	_new_entry()


func _on_bound() -> void:
	_sync_fields()
	_rebuild_form()


func _sync_fields() -> void:
	_syncing = true
	_id_edit.text = String(_def.id)
	_name_edit.text = _def.display_name
	_icon_edit.text = _def.icon
	_syncing = false


func _rebuild_form() -> void:
	UiTheme.clear_children(_form_host)
	if _def == null:
		return
	_form_host.add_child(_form_for(_def, {"TagDef": ["id", "display_name", "icon"]}))


func _after_save(built: Resource) -> void:
	TagRegistry.register(built as TagDef)
#endregion


#region 刷新与提示语
func _t(key: String) -> String:
	return String(TAG_TEXTS.get(key, key))


func _saved_text(id: String) -> String:
	return "已存：tags/%s.json 与 .tres" % id


func _on_refreshed() -> void:
	_summary.text = summary_text()
	var path := icon_preview_path()
	_icon_preview.texture = load(path) as Texture2D if path != "" else null
	_icon_note.text = "" if path != "" else "无图"
	var who := members()
	_members.text = "、".join(who) if not who.is_empty() else "（还没有道具带着它）"
#endregion

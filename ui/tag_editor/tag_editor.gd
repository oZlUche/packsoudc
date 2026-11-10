## 标签制作器（171，作者定）：标签不是道具随手写的，得先在这里建 —— id、名字、多语言、说明、大类（用途 / 属性 / 材料 / 归属 / 来源 / 内部）、
## 弹不弹词条、是不是内部标签。道具编辑器的标签栏只能从登记过的标签里挑（按大类分组的下拉）。
## 193：一栏「图标」—— `assets/ui/tags/` 下的文件名（空 = 用 id），右边按悬浮窗的大小（`FaithTooltip.ICON_SIZE`）预览，读不出写「无图」
##
## 和别的编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/tags/<id>.json`，
## 校验走导入器（`import_tag`：得有名字、得归一类），字段由 [PropertyForm] 反射生成；保存同时产出 `.tres`、登记进 [TagRegistry]。
## 列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。右边看哪些道具带着它。
extends AuthoringEditor

const KIND := "tags"

var _items: ItemDatabase = null

var _icon_edit: LineEdit
var _icon_preview: TextureRect
var _icon_note: Label
var _summary: Label
var _members: Label


func _init() -> void:
	_kind = KIND
	_texts = LIBRARY_TEXTS


func _before_build() -> void:
	_items = ItemDatabase.new()
	_items.load_dir()


#region 界面
func _build_ui() -> void:
	UiTheme.prepare_root(self, false)
	# 左：列表
	var left := _left_column(220)
	_list_block(left, "标签")

	# 中：字段
	var mid := _mid_column(left)
	mid.add_child(_id_row())
	var body := _scroll_body(mid)

	body.add_child(_name_row())
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
	var side := _side_column(mid, 380)
	_summary = UiTheme.make_wrapped("", 13, UiPalette.FG, 360)
	side.add_child(_summary)
	side.add_child(UiTheme.make_label("带着它的道具", 13, UiPalette.DIM))
	_members = UiTheme.make_wrapped("", 12, UiPalette.FG, 360)
	side.add_child(_members)
	_status_block(side)
	_json_block(side)

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
	return ContentExporter.dump(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_tag(data, _ctx, report)


func _new_def() -> Resource:
	var def_ := TagDef.new()
	def_.id = &"new_tag"
	def_.display_name = "新标签"
	def_.category = "kind"
	def_.tip = false
	return def_


func _fill_fields() -> void:
	_icon_edit.text = _def.icon


func _form_skip() -> Dictionary:
	return {"TagDef": ["id", "display_name", "icon"]}


func _after_save(built: Resource) -> void:
	TagRegistry.register(built as TagDef)
#endregion


#region 刷新
func _on_refreshed() -> void:
	_summary.text = summary_text()
	var path := icon_preview_path()
	_icon_preview.texture = load(path) as Texture2D if path != "" else null
	_icon_note.text = "" if path != "" else "无图"
	var who := members()
	_members.text = "、".join(who) if not who.is_empty() else "（还没有道具带着它）"
#endregion

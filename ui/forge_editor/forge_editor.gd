## 铸炉映射表编辑器（175 第三批，内容编辑器的「铸炉」一页）：三张表 —— 时机 / 效果 / 数值，每张按材质、用途、稀有度三列，
## 每列一组行（key = 标签 id 或稀有度 0–4，`default` 兜底）。和别的编辑器同一条通路：存的是 `data/authoring/forge/<槽>.json`，
## 校验走导入器（`import_forge_table`），字段由 [PropertyForm] 反射生成；保存同时产出 `.tres`、登记进 [Forge]。
## 右边「试铸」：挑三件道具，看铸出来的那一枚（前缀与那一句）
extends AuthoringEditor

## 176：带整个库的导入上下文（不写 class_name，按路径取）
const AuthoringContext := preload("res://core/authoring/authoring_context.gd")

const KIND := "forge"
const FORGE_TEXTS := {
	"ok": "没有问题", "unreadable": "%s.json 读不到", "err_id": "id 只能是 timing / effect / value", "err_save": "有错，没存",
	"err_write": "写不进作者目录", "warn_asset": "JSON 存了，.tres 没写成", "err_json": "JSON 读不通",
}

var _items: ItemDatabase = null
var _item_ids: Array = []

var _id_edit: LineEdit
var _form_host: VBoxContainer
var _summary: Label
var _picks: Array[OptionButton] = []
var _trial: Label


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
	_item_ids = _items.ids(true)
	_item_ids.sort()
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

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 200
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(UiTheme.make_label("铸炉映射表", 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var lb := HBoxContainer.new()
	lb.add_child(UiTheme.make_button("刷新列表", _on_rescan, UiTheme.TIER_PLAIN, 13))
	lb.add_child(UiTheme.make_button("放弃改动", _on_discard, UiTheme.TIER_PLAIN, 13))
	left.add_child(lb)

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_split)

	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(mid)
	var id_row := HBoxContainer.new()
	id_row.add_child(UiTheme.make_label("槽", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.editable = false     # 三张表是固定的
	_id_edit.custom_minimum_size.x = 140
	id_row.add_child(_id_edit)
	id_row.add_child(UiTheme.make_button("保存", _save, UiTheme.TIER_PLAIN, 13))
	mid.add_child(id_row)
	mid.add_child(UiTheme.make_wrapped("每一行的 key：材质列写材质类标签（metal、bone……），用途列写用途类标签（weapon、shield……），稀有度列写 0–4；都要有一行 default。时机表读「扳机 / 方向 / 节奏」，效果表读「效果 / 给谁 / 几阶」与前缀，数值表读「系数 / 几档」。", 12, UiPalette.DIM, 520))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form_host)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 400
	side.add_theme_constant_override("separation", 8)
	right_split.add_child(side)
	_summary = UiTheme.make_wrapped("", 13, UiPalette.FG, 380)
	side.add_child(_summary)
	side.add_child(UiTheme.make_label("试铸（用已保存的三张表）", 14, UiPalette.FG))
	for slot in ForgeTable.SLOTS:
		var row := HBoxContainer.new()
		row.add_child(UiTheme.make_label("【%s】" % Forge.slot_name(slot), 13, UiPalette.DIM))
		var pick := OptionButton.new()
		for id in _item_ids:
			pick.add_item(String(id))
		pick.item_selected.connect(func(_i: int): _refresh_trial())
		row.add_child(pick)
		side.add_child(row)
		_picks.append(pick)
	_trial = UiTheme.make_wrapped("", 13, UiPalette.HEAL, 380)
	side.add_child(_trial)
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
func def() -> ForgeTable:
	return _def


## 试铸：三件道具（id）铸出来的那一枚 ——「铸牌 · 前缀：那一句」；挑不全返回空串
func trial(timing: StringName, effect: StringName, value: StringName) -> String:
	if not (_items.has_def(timing) and _items.has_def(effect) and _items.has_def(value)):
		return ""
	var ench := Forge.forge(_items.get_def(timing), _items.get_def(effect), _items.get_def(value))
	if ench.is_empty():
		return "铸不出来（三张表没齐）"
	return "铸牌 · %s：%s（数值 %d）" % [Forge.prefix(ench), Glossary.strip_bbcode(Forge.sentence(ench)), int(ench.get("magnitude", 0))]


func summary_text() -> String:
	if _def == null:
		return ""
	return "%s（%s）　材质 %d 行、用途 %d 行、稀有度 %d 行" % [Names.of(_def), _def.id, _def.material.size(), _def.purpose.size(), _def.rarity.size()]
#endregion


#region 列表与草稿（公共的在 AuthoringEditor）
func _export(d) -> Dictionary:
	return ContentExporter.dump(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_forge_table(data, _ctx, report)


func _new_def() -> Resource:
	var def := ForgeTable.new()
	def.id = &"timing"
	return def


func _on_bound() -> void:
	_syncing = true
	_id_edit.text = String(_def.id)
	_syncing = false
	UiTheme.clear_children(_form_host)
	_form_host.add_child(_form_for(_def, {"ForgeTable": ["id"]}))


func _after_save(built: Resource) -> void:
	Forge.register(built as ForgeTable)
	_refresh_trial()
#endregion


func _t(key: String) -> String:
	return String(FORGE_TEXTS.get(key, key))


func _saved_text(id: String) -> String:
	return "已存：forge/%s.json 与 .tres" % id


func _on_refreshed() -> void:
	_summary.text = summary_text()
	_refresh_trial()


func _refresh_trial() -> void:
	if _trial == null or _picks.size() < 3 or _item_ids.is_empty():
		return
	var ids: Array[StringName] = []
	for p in _picks:
		ids.append(StringName(String(_item_ids[maxi(0, p.selected)])))
	_trial.text = trial(ids[0], ids[1], ids[2])

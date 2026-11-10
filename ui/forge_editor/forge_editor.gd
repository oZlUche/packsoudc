## 铸炉映射表编辑器（175 第三批，内容编辑器的「铸炉」一页）：三张表 —— 时机 / 效果 / 数值，每张按材质、用途、稀有度三列，
## 每列一组行（key = 标签 id 或稀有度 0–4，`default` 兜底）。和别的编辑器同一条通路：存的是 `data/authoring/forge/<槽>.json`，
## 校验走导入器（`import_forge_table`），字段由 [PropertyForm] 反射生成；保存同时产出 `.tres`、登记进 [Forge]。
## 右边「试铸」：挑三件道具，看铸出来的那一枚（前缀与那一句）
extends AuthoringEditor

const KIND := "forge"

var _items: ItemDatabase = null
var _item_ids: Array = []

var _summary: Label
var _picks: Array[OptionButton] = []
var _trial: Label


func _init() -> void:
	_kind = KIND
	_texts = LIBRARY_TEXTS.merged({"err_id": "id 只能是 timing / effect / value"}, true)


func _before_build() -> void:
	_items = ItemDatabase.new()
	_items.load_dir()
	_item_ids = _items.ids(true)
	_item_ids.sort()


#region 界面
func _build_ui() -> void:
	UiTheme.prepare_root(self, false)
	var left := _left_column(200)
	_list_block(left, "铸炉映射表", false)

	var mid := _mid_column(left)
	var id_row := HBoxContainer.new()
	id_row.add_child(UiTheme.make_label("槽", 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.editable = false     # 三张表是固定的
	_id_edit.custom_minimum_size.x = 140
	id_row.add_child(_id_edit)
	id_row.add_child(UiTheme.make_button("保存", _save, UiTheme.TIER_PLAIN, 13))
	mid.add_child(id_row)
	mid.add_child(UiTheme.make_wrapped("每一行的 key：材质列写材质类标签（metal、bone……），用途列写用途类标签（weapon、shield……），稀有度列写 0–4；都要有一行 default。时机表读「扳机 / 方向 / 节奏」，效果表读「效果 / 给谁 / 几阶」与前缀，数值表读「系数 / 几档」。", 12, UiPalette.DIM, 520))
	_form_host = _scroll_body(mid, -1)

	var side := _side_column(mid, 400)
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
	_status_block(side)
	_json_block(side)
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
	var def_ := ForgeTable.new()
	def_.id = &"timing"
	return def_


func _form_skip() -> Dictionary:
	return {"ForgeTable": ["id"]}


func _after_save(built: Resource) -> void:
	Forge.register(built as ForgeTable)
	_refresh_trial()
#endregion


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

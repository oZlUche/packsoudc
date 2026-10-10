## Buff 制作器（085，作者定）：可否叠层 / 叠层上限、是否永续 / 持续时长、具体效果（从预设里挑，或开代码编辑器直接改 JSON）。
##
## 和道具 / 事件编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/buffs/<id>.json`，
## 校验走导入器（含「可叠层的永续、不许填时长」那条规矩），效果构件由 [PropertyForm] 反射生成、类型下拉来自注册表；保存同时产出 `.tres`。
## 道具里按 id 引用（`"buff": "<id>"`），内联的 buff 照旧可以在道具编辑器里写。
## 界面文字走 [UiText]：主菜单切了语言这里跟着变。列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。
extends AuthoringEditor

const KIND := "buffs"

var _id_edit: LineEdit
var _name_edit: LineEdit
var _debuff: CheckBox
var _stackable: CheckBox
var _permanent: CheckBox
var _seconds: SpinBox
var _rule_note: Label
var _form_host: VBoxContainer
var _summary: Label


func _init() -> void:
	_kind = KIND


func _ready() -> void:
	_font = UiPalette.cjk_font()
	var settings := GameSettings.load_from()
	UiText.apply(settings)
	UiPalette.apply(settings)
	_ctx = ContentLibrary.context()     # 146：buff 的效果可以按 id 引用库里别的 buff
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
	left.add_child(UiTheme.make_label(UiText.t("buff.title"), 16, UiPalette.FG))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int): _open(_ids[i]))
	left.add_child(_list)
	var lb := HBoxContainer.new()
	lb.add_child(UiTheme.make_button(UiText.t("buff.new"), _new_buff, UiTheme.TIER_PLAIN, 13))
	lb.add_child(UiTheme.make_button(UiText.t("buff.rescan"), _on_rescan, UiTheme.TIER_PLAIN, 13))
	lb.add_child(UiTheme.make_button(UiText.t("buff.discard"), _on_discard, UiTheme.TIER_PLAIN, 13))
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
	id_row.add_child(UiTheme.make_label(UiText.t("buff.id"), 13, UiPalette.DIM))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 180
	_id_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.id = StringName(text.strip_edges())
		_refresh())
	id_row.add_child(_id_edit)
	id_row.add_child(UiTheme.make_button(UiText.t("buff.save"), _save, UiTheme.TIER_PLAIN, 13))
	id_row.add_child(UiTheme.make_button(UiText.t("buff.save_as"), _save_as, UiTheme.TIER_PLAIN, 13))
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
	name_row.add_child(UiTheme.make_label(UiText.t("buff.name"), 13, UiPalette.DIM))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(text: String):
		if _syncing or _def == null:
			return
		_def.display_name = text
		_refresh())
	name_row.add_child(_name_edit)
	_debuff = CheckBox.new()
	_debuff.text = UiText.t("buff.debuff")
	_debuff.toggled.connect(func(on: bool):
		if _syncing or _def == null:
			return
		_def.is_debuff = on
		_refresh())
	name_row.add_child(_debuff)
	body.add_child(name_row)

	body.add_child(UiTheme.make_label(UiText.t("buff.stacking"), 14, UiPalette.FG))
	var stack_row := HBoxContainer.new()
	stack_row.add_theme_constant_override("separation", 12)
	_stackable = CheckBox.new()
	_stackable.text = UiText.t("buff.stackable")
	_stackable.toggled.connect(func(on: bool):
		if _syncing or _def == null:
			return
		set_stackable(on))
	stack_row.add_child(_stackable)
	stack_row.add_child(UiTheme.make_label(UiText.t("buff.stacks_unlimited"), 12, UiPalette.DIM))     # 137：可叠层就是不限层，没有上限框
	body.add_child(stack_row)

	body.add_child(UiTheme.make_label(UiText.t("buff.duration"), 14, UiPalette.FG))
	var dur_row := HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", 12)
	_permanent = CheckBox.new()
	_permanent.text = UiText.t("buff.permanent")
	_permanent.toggled.connect(func(on: bool):
		if _syncing or _def == null:
			return
		set_permanent(on))
	dur_row.add_child(_permanent)
	dur_row.add_child(UiTheme.make_label(UiText.t("buff.seconds"), 12, UiPalette.DIM))
	_seconds = SpinBox.new()
	_seconds.min_value = 0
	_seconds.max_value = 600
	_seconds.step = 0.1
	_seconds.value_changed.connect(func(v: float):
		if _syncing or _def == null:
			return
		set_seconds(v))
	dur_row.add_child(_seconds)
	body.add_child(dur_row)
	_rule_note = UiTheme.make_label("", 12, UiPalette.DIM)
	body.add_child(_rule_note)

	body.add_child(HSeparator.new())
	body.add_child(UiTheme.make_label(UiText.t("buff.effects"), 14, UiPalette.FG))
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_form_host)

	# 右：摘要 / 校验 / 代码
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 380
	side.add_theme_constant_override("separation", 8)
	right_split.add_child(side)
	_summary = UiTheme.make_label("", 13, UiPalette.FG)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 360
	side.add_child(_summary)
	side.add_child(UiTheme.make_label(UiText.t("buff.validation"), 14, UiPalette.FG))
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.custom_minimum_size.y = 90
	_status.add_theme_font_override("normal_font", _font)
	_status.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(_status)
	side.add_child(UiTheme.make_label(UiText.t("buff.code"), 12, UiPalette.DIM))
	_json = TextEdit.new()
	_json.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json.add_theme_font_size_override("font_size", 12)
	side.add_child(_json)
	side.add_child(UiTheme.make_button(UiText.t("buff.apply_code"), _apply_json, UiTheme.TIER_PLAIN, 13))

#endregion


#region 字段（公开：测试直接调）
## 137：可叠层（不限层）/ 不可叠层（固定一层）。勾上 → 时长清掉（可叠层的永续）
func set_stackable(on: bool) -> void:
	_def.stackable = on
	if on:
		_def.duration_sec = 0.0
	_sync_fields()
	_rebuild_form()
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


#region 列表与草稿（公共的在 AuthoringEditor）
func _export(d) -> Dictionary:
	return ContentExporter.export_buff(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_buff(data, _ctx, report)


func _new_def() -> Resource:
	var def := BuffDef.new()
	def.id = &"new_buff"
	def.display_name = "新 buff" if UiText.lang == "zh" else "New buff"
	def.stackable = true     # 作者定：通常可叠层（137：可叠就是不限层），且可叠层的永续
	return def


func _new_buff() -> void:
	_new_entry()


func _on_bound() -> void:
	_sync_fields()
	_rebuild_form()


func _sync_fields() -> void:
	_syncing = true
	_id_edit.text = String(_def.id)
	_name_edit.text = _def.display_name
	_debuff.button_pressed = _def.is_debuff
	var stackable: bool = _def.is_stackable()
	_stackable.button_pressed = stackable
	_permanent.button_pressed = _def.is_permanent()
	_permanent.disabled = stackable
	_seconds.value = _def.duration_sec
	_seconds.editable = not stackable and not _def.is_permanent()
	_rule_note.text = UiText.t("buff.permanent_forced") if stackable else ""
	_syncing = false


func _rebuild_form() -> void:
	UiTheme.clear_children(_form_host)
	if _def == null:
		return
	_form_host.add_child(_form_for(_def, {"BuffDef": ["id", "display_name", "is_debuff", "stackable", "duration_sec", "refresh_on_restack"]}))
#endregion


#region 保存与校验
func _t(key: String) -> String:
	return "%s.json ?" if key == "unreadable" else UiText.t("buff." + key)


func _saved_text(id: String) -> String:
	return UiText.t("buff.saved") % [id, id]


func summary_text() -> String:
	if _def == null:
		return ""
	var stacks: String = UiText.t("buff.stacks_single") if not _def.is_stackable() else UiText.t("buff.stacks_unlimited")
	var dur: String = (UiText.t("buff.permanent") if _def.is_permanent() else "%s %.1f" % [UiText.t("buff.seconds"), _def.duration_sec])
	var counts := "%d axes · %d mods · %d rules · %d on_apply · %d on_expire" % [_def.axes.size(), _def.mods.size(), _def.rules.size(), _def.on_apply.size(), _def.on_expire.size()]
	var lines: Array[String] = [UiText.t("buff.summary") % [stacks, dur], counts]
	var axes := axes_text()
	if axes != "":
		lines.append(axes)
	lines.append(UiText.t("buff.usage") % String(_def.id))
	return "\n".join(lines)


## 152：每层带的标准轴，一句话（「每层带【强攻】1 层、【加速】1 层」）；没有就空串
func axes_text() -> String:
	if _def == null or _def.axes.is_empty():
		return ""
	return Glossary.describe_buff(_def).split("\n")[1]


func _on_refreshed() -> void:
	_summary.text = summary_text()
#endregion

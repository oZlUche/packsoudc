## Buff 制作器（085，作者定）：可否叠层 / 叠层上限、是否永续 / 持续时长、具体效果（从预设里挑，或开代码编辑器直接改 JSON）。
##
## 和道具 / 事件编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/buffs/<id>.json`，
## 校验走导入器（含「可叠层的永续、不许填时长」那条规矩），效果构件由 [PropertyForm] 反射生成、类型下拉来自注册表；保存同时产出 `.tres`。
## 道具里按 id 引用（`"buff": "<id>"`），内联的 buff 照旧可以在道具编辑器里写。
## 界面文字走 [UiText]：主菜单切了语言这里跟着变。列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。
extends AuthoringEditor

const KIND := "buffs"

var _debuff: CheckBox
var _stackable: CheckBox
var _permanent: CheckBox
var _seconds: SpinBox
var _rule_note: Label
var _summary: Label


func _init() -> void:
	_kind = KIND


#region 界面
func _build_ui() -> void:
	UiTheme.prepare_root(self, false)     # 121：装上界面主题、铺底色（设置在 _ready 里已经读过、apply 过）
	# 左：列表
	var left := _left_column(220)
	_list_block(left, UiText.t("buff.title"))

	# 中：字段
	var mid := _mid_column(left)
	mid.add_child(_id_row())
	var body := _scroll_body(mid)

	var name_row := _name_row()
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
	var side := _side_column(mid, 380)
	_summary = UiTheme.make_label("", 13, UiPalette.FG)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 360
	side.add_child(_summary)
	_status_block(side)
	_json_block(side)

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
	return ContentExporter.dump(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_buff(data, _ctx, report)


func _new_def() -> Resource:
	var def_ := BuffDef.new()
	def_.id = &"new_buff"
	def_.display_name = "新 buff" if UiText.lang == "zh" else "New buff"
	def_.stackable = true     # 作者定：通常可叠层（137：可叠就是不限层），且可叠层的永续
	return def_


func _fill_fields() -> void:
	_debuff.button_pressed = _def.is_debuff
	var stackable: bool = _def.is_stackable()
	_stackable.button_pressed = stackable
	_permanent.button_pressed = _def.is_permanent()
	_permanent.disabled = stackable
	_seconds.value = _def.duration_sec
	_seconds.editable = not stackable and not _def.is_permanent()
	_rule_note.text = UiText.t("buff.permanent_forced") if stackable else ""


func _form_skip() -> Dictionary:
	return {"BuffDef": ["id", "display_name", "is_debuff", "stackable", "duration_sec", "refresh_on_restack"]}
#endregion


#region 保存与校验
## 提示语与界面上那几个固定的字都走 [UiText]（`buff.<键>`）
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
	lines.append_array(Glossary.buff_rule_lines(_def).slice(1))     # 185：机制说明只在作者工具里看（玩家的窗不写）
	lines.append(UiText.t("buff.usage") % String(_def.id))
	return "\n".join(lines)


## 152：每层带的标准轴，一句话（185 起只写折成多少：「每层：造成的伤害 +15%、攻速 +15%」）；没有就空串
func axes_text() -> String:
	if _def == null or _def.axes.is_empty():
		return ""
	var parts: Array[String] = []
	for a in _def.axes:
		var ba := a as BuffAxis
		if ba != null:
			parts.append(StatAxes.effect_text(ba.axis, ba.stacks))
	return "每层：" + "、".join(parts)


func _on_refreshed() -> void:
	_summary.text = summary_text()
#endregion

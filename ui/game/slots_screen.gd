## 读取存档（089，作者定）：三个存档位各一行 —— 摘要（第几局、撤离 / 战败、有没有进行中的一局、是不是当前位）、
## 「载入」（切过去接着玩）、空位是「在这一位开新的游戏」、「删除」（点两次确认）。三位都满了从「新的游戏」进来时顶上一句提示。
extends GameScreen

var _rows: Dictionary = {}
var _armed_delete: int = -1


func open(payload: Dictionary) -> void:
	_backdrop()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slab_screen().add_child(center)     # 157 补充三：内容在一整块石板上
	var col := _vbox(12)
	col.custom_minimum_size.x = 860
	center.add_child(col)
	var plate := TitlePlate.new(UiText.t("slots.title"))     # 226 批二：标题刻在标题牌上（整屏石板，同结算屏）
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(plate)
	# 098：读不出来的存档已备份 —— 这一句比「三位都满了」更要紧，优先写它
	var notice := flow.backup_notice()
	if notice != "":
		warn(notice)     # 226 批一：提示句走告示卷轴
	elif bool(payload.get("full", false)):
		say(UiText.t("slots.full"))
	var repaired := flow.repair_notice()     # 173：读档修复报告（和 098 的备份提示同一处）
	if repaired != "":
		var note := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_SUMMARY_NOTE)     # 226 批四：修复报告写在一张便条上
		note.name = "RepairNote"
		note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(note)
		note.add_child(_wrapped(repaired, 15, UiTheme.INK_WARN, 840))
	for n in range(1, SaveSlots.COUNT + 1):
		col.add_child(_row(n))
	col.add_child(HSeparator.new())
	var back := ScrollKey.make(UiText.t("slots.back"), flow.to_main_menu)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(back)


func _row(n: int) -> Control:
	var panel := _panel(12)
	var row := _hbox(12)
	panel.add_child(row)
	var summary := flow.slots.summary(n, flow.items, flow.meta_rules) if flow.slots != null else {"exists": false}
	var exists := bool(summary.get("exists", false))
	var text := UiText.t("slots.slot") % n + UiText.t("slots.sep")
	if exists:
		text += UiText.t("slots.summary") % [int(summary.get("runs", 0)) + 1, int(summary.get("extractions", 0)), int(summary.get("deaths", 0)),
			UiText.t("slots.in_run") if bool(summary.get("has_run", false)) else ""]
		if int(summary.get("newer", 0)) > 0:
			text += UiText.t("slots.newer_tag")
	else:
		text += UiText.t("slots.empty")
	if flow.slot == n:
		text += UiText.t("slots.current")
	var l := _label(text, 14, UiPalette.FG if exists else UiPalette.DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var slot := n
	if exists:
		row.add_child(ScrollKey.primary(UiText.t("slots.load"), func(): load_slot(slot)))     # 乙 石刻：读、开新档是主键，删是矮键
		var del := ScrollKey.short(UiText.t("slots.delete"), func(): delete_slot(slot))
		row.add_child(del)
	else:
		row.add_child(ScrollKey.primary(UiText.t("slots.new_here"), func(): new_game_here(slot)))
	_rows[n] = panel
	return panel


func load_slot(n: int) -> bool:
	return flow.load_slot(n)


func new_game_here(n: int) -> bool:
	return flow.new_game_in(n)


## 点两次才删：第一次只是武装起来、提示一句
func delete_slot(n: int) -> bool:
	if _armed_delete != n:
		_armed_delete = n
		warn(UiText.t("slots.confirm_delete_slot") % (UiText.t("slots.slot") % n))
		return false
	_armed_delete = -1
	flow.delete_slot(n)
	_rebuild()
	return true


func armed_delete() -> int:
	return _armed_delete


## 090：Esc = 回主菜单
func escape() -> bool:
	flow.to_main_menu()
	return true


func _rebuild() -> void:
	_rows.clear()
	_reopen()

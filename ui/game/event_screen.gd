## 事件屏（063）：每个配了事件的点踩上去先到这里 —— 标题、图像、正文、几个选项；条件没过的灰掉并写原因。
## 选了之后如果后果做了什么（给东西、回体力、给 buff、说了话），再显示一页结果，「继续」往下走。
##
## 两种模式由 payload 决定：带 `def` 是选项页，带 `detail` 是结果页。
extends GameScreen

var _def: EventDef = null
var _node: MapNode = null
var _option_btns: Array[Button] = []


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	var def = payload.get("def", null)
	if def is EventDef:
		_def = def
		_open_options()
	else:
		_open_result(payload)


func _open_options() -> void:
	var panel := _centered_panel(Vector2(640, 0), 20)
	var col := _vbox(10)
	panel.add_child(col)
	col.add_child(_label(_def.title if _def.title != "" else String(_def.id), 20, UiPalette.FG))
	col.add_child(_image(_def.image))
	if _def.text != "":
		col.add_child(_wrapped(_def.text, 14, UiPalette.FG, 600))
	col.add_child(HSeparator.new())
	for i in _def.options.size():
		var opt := _def.options[i] as EventOption
		var state := flow.run.events.option_state(i)
		var ok := bool(state["ok"])
		if not ok and opt.hide_when_locked:
			continue
		var idx := i
		var b := _button(opt.label + ("　（%s）" % state["why"] if not ok else ""), func(): choose(idx), 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not ok
		_option_btns.append(b)
		col.add_child(b)


func _open_result(payload: Dictionary) -> void:
	var detail: Dictionary = payload.get("detail", {})
	var panel := _centered_panel(Vector2(560, 0), 20)
	var col := _vbox(10)
	panel.add_child(col)
	col.add_child(_label(String(payload.get("outcome", "事件")), 18, UiPalette.FG))
	var lines: Array[String] = []
	for text in detail.get("log", []):
		lines.append(String(text))
	var names: Array[String] = []
	for id in detail.get("items", []):
		var d := flow.items.get_def(StringName(String(id)))
		names.append(d.display_name if d != null else String(id))
	if not names.is_empty():
		lines.append("得到：%s（已放进暂存区）" % "、".join(names))
	if int(detail.get("restored", 0)) != 0:
		lines.append("体力 +%d" % int(detail["restored"]))
	if int(detail.get("spent", 0)) != 0:
		lines.append("体力 -%d" % int(detail["spent"]))
	if int(detail.get("money", 0)) != 0:
		lines.append("钱 %+d" % int(detail["money"]))
	for id in detail.get("buffs", []):
		var bd: RunBuffDef = flow.buff_defs.get(StringName(String(id)), null)
		lines.append("获得「%s」" % (bd.display_name if bd != null else String(id)))
	for id in detail.get("buffs_removed", []):
		var bd2: RunBuffDef = flow.buff_defs.get(StringName(String(id)), null)
		lines.append("失去「%s」" % (bd2.display_name if bd2 != null else String(id)))
	if lines.is_empty():
		lines.append("什么也没发生。")
	for line in lines:
		col.add_child(_wrapped(line, 14, UiPalette.FG, 520))
	col.add_child(_button("继续", proceed, 14))


## 图像占位：有文件就画，没有就一块底色写着路径（或「没有配图」）
func _image(path: String) -> Control:
	var loaded := EventImage.load_texture(path)
	if loaded != null:
		var tex := TextureRect.new()
		tex.texture = loaded
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.custom_minimum_size = Vector2(600, 180)
		return tex
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("14161a")
	st.border_color = UiPalette.LINE
	st.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", st)
	box.custom_minimum_size = Vector2(600, 120)
	var l := _label("（图像占位：%s）" % path if path != "" else "（没有配图）", 12, UiPalette.DIM.darkened(0.2))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


#region 公开动作
## 选第 i 项。选不了返回 false
func choose(i: int) -> bool:
	return flow.choose_event(i)


## 通用的「往下走」：选项页选第一个能选的，结果页继续
func proceed() -> void:
	if _def != null and flow.run != null and flow.run.events.pending_event() == _def:
		for i in _def.options.size():
			if bool(flow.run.events.option_state(i)["ok"]):
				choose(i)
				return
		return
	flow.resume()


func is_options_page() -> bool:
	return _def != null
#endregion

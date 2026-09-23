## 事件屏（063）：每个配了事件的点踩上去先到这里 —— 标题、图像、正文、几个选项；条件没过的灰掉并写原因。
## 选了之后如果后果做了什么（给东西、回体力、给 buff、说了话），再显示一页结果，「继续」往下走。
##
## 两种模式由 payload 决定：带 `def` 是选项页，带 `detail` 是结果页。
extends GameScreen

## 整块框的大小（视口 1600×1000）：占大半个屏幕，左栏是图
const PANEL_SIZE := Vector2(1320, 760)
const IMAGE_WIDTH := 640.0
const TEXT_WIDTH := 560.0

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
	var col := _frame(_def.image, _def.title if _def.title != "" else String(_def.id), _def.text)
	for i in _def.options.size():
		var opt := _def.options[i] as EventOption
		var state := flow.run.events.option_state(i)
		var ok := bool(state["ok"])
		if not ok and opt.hide_when_locked:
			continue
		var idx := i
		var b := _option_button(opt.label, func(): choose(idx))
		b.disabled = not ok
		_option_btns.append(b)
		col.add_child(b)
		if not ok:
			col.add_child(_label("　" + String(state["why"]), 13, UiPalette.DIM))


func _open_result(payload: Dictionary) -> void:
	var detail: Dictionary = payload.get("detail", {})
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
	# 结果页配图沿用这个点的事件（结果只是同一件事的下一页）；老路的事件点没有定义，画占位
	var image := ""
	if _node != null and flow.event_defs != null:
		var def: EventDef = flow.event_defs.get(StringName(String(_node.content.get("event", ""))), null)
		if def != null:
			image = def.image
	var col := _frame(image, String(payload.get("outcome", "事件")), "\n".join(lines))
	col.add_child(_option_button("继续", proceed))


## 两栏的框（参考杀戮尖塔的事件屏）：左边整块是图，右边标题、正文、选项。占掉大半个屏幕，底下的地图压暗。
##
## 返回右栏底部放选项的容器，调用方往里加按钮；正文在可滚的区域里，选项贴在底部
func _frame(image_path: String, title: String, body: String) -> VBoxContainer:
	var panel := _centered_panel(PANEL_SIZE, 0)
	var row := _hbox(0)
	panel.add_child(row)
	row.add_child(_image_area(image_path, title))

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	row.add_child(margin)
	var col := _vbox(14)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	col.add_child(_label(title, 28, UiPalette.FG))
	col.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	if body != "":
		var text := _wrapped(body, 17, UiPalette.FG, TEXT_WIDTH)
		text.add_theme_constant_override("line_spacing", 6)
		scroll.add_child(text)
	var options := _vbox(8)
	options.name = "Options"
	col.add_child(options)
	return options


## 左栏：图铺满、按比例裁；没有图就一块深底色写着占位
func _image_area(path: String, title: String) -> Control:
	var area := Control.new()
	area.clip_contents = true
	area.custom_minimum_size = Vector2(IMAGE_WIDTH, 0)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var loaded := EventImage.load_texture(path)
	if loaded != null:
		var tex := TextureRect.new()
		tex.texture = loaded
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		area.add_child(tex)
		return area
	var bg := ColorRect.new()
	bg.color = Color("0d0f12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(center)
	var col := _vbox(6)
	center.add_child(col)
	var big := _label(title, 22, UiPalette.DIM.darkened(0.35))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(big)
	var hint := _label("（图像占位：%s）" % path if path != "" else "（没有配图）", 12, UiPalette.DIM.darkened(0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	return area


## 一个选项：整行宽、左对齐、够高
func _option_button(text: String, handler: Callable) -> Button:
	var b := _button(text, handler, 17)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 48
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


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

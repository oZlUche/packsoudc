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


const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")
var _payload: Dictionary = {}
var _bag: Control = null


func open(payload: Dictionary) -> void:
	_payload = payload
	_node = payload.get("node", null)
	var def = payload.get("def", null)
	if def is EventDef:
		_def = def
		_open_options()
	else:
		_open_result(payload)


func _open_options() -> void:
	# 084：文字里的 {char_name} 这类占位符与 {c:hp}…{/c} 样式码在这里替换（docs/text-placeholders.md）
	var ctx := TextTemplate.context_for(flow.run, _node, _payload.get("extra", {}))
	var title := TextTemplate.plain(_def.title_for() if _def.title_for() != "" else String(_def.id), ctx)
	# 101 第 5 刀：文本层只产出带颜色名的样式码，画之前在这里查表换成真颜色
	var body := UiPalette.resolve_styles(TextTemplate.render(_def.text_for(), ctx))
	var col := _frame(_def.image, title, body)
	for i in _def.options.size():
		var opt := _def.options[i] as EventOption
		var state := flow.run.events.option_state(i)
		var ok := bool(state["ok"])
		if not ok and opt.hide_when_locked:
			continue
		var idx := i
		var b := _option_button(TextTemplate.plain(opt.label_for(), ctx), func(): choose(idx))
		b.disabled = not ok
		_option_btns.append(b)
		col.add_child(b)
		if not ok:
			col.add_child(_label("　" + String(state["why"]), 13, UiPalette.DIM))
	# 083：事件屏上也能整理背包（教程的「先整理再开打」要在这里做；15 节第 7 项的尾巴）
	if flow.run != null:
		col.add_child(_button("整理背包（B）", toggle_bag, 13, UiPalette.Tier.MINOR))


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
	var lost: Array[String] = []
	for name in detail.get("items_lost", []):
		lost.append(String(name))
	if not lost.is_empty():
		lines.append("失去：%s" % "、".join(lost))
	if int(detail.get("waited", 0)) > 0:
		lines.append("耗了 %d 个行动点" % int(detail["waited"]))
	if String(detail.get("type_changed", "")) != "":
		lines.append("这里变成了%s点" % MapNodeStyle.of(StringName(String(detail["type_changed"])))["label"])
	if int(detail.get("teleported", -1)) >= 0:
		lines.append("被传送到了点 %d" % int(detail["teleported"]))
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
		# RichTextLabel：正文里能变色、加粗（BBCode，TextTemplate 的样式码也翻成它）
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = TEXT_WIDTH
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_override("normal_font", font)
		text.add_theme_font_override("bold_font", font)
		text.add_theme_font_override("italics_font", font)
		for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
			text.add_theme_font_size_override(k, 17)
		text.add_theme_color_override("default_color", UiPalette.FG)
		text.add_theme_constant_override("line_separation", 6)
		text.text = body
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
	var b := _button(text, handler, 17)     # 090：200% = 34 号（选项是整行的，300% 会把长句挤成两三行）
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 64
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


## 背包整理面板叠在事件上；收起时重画选项（条件可能因为整理过了而满足）
func toggle_bag() -> void:
	if _bag != null:
		_bag.queue_free()
		_bag = null
		_rebuild()
		return
	if flow.run == null:
		return
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_bag = shade
	# 084：背包是能拖着走的浮窗，不锁在一个地方；关掉再开还在上次放的位置
	var win := FloatingWindow.new()
	win.setup("bag", "背包", font, toggle_bag, "收起（B）")
	shade.add_child(win)
	var inv := InventoryPanelScript.new()
	inv.setup(flow.run, font)
	win.body().add_child(inv)


func bag_open() -> bool:
	return _bag != null


## 090：Esc —— 开着背包就关背包；结果页就「继续」；等着选的事件不接（必须选）
func escape() -> bool:
	if _bag != null:
		toggle_bag()
		return true
	if not is_options_page():
		proceed()
		return true
	return false


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_option_btns.clear()
	open(_payload)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_B or not is_options_page():
		return
	toggle_bag()
	get_viewport().set_input_as_handled()
#endregion

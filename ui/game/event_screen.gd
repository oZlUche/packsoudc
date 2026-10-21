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
## 113：藏起来的选项要说的那几句（[member EventOption.hint_when_hidden]），排在选项下面
var _hints: Array[String] = []


var _payload: Dictionary = {}
var _bag: Control = null
var _bag_panel: Control = null
## 157：结果页的「收获」行（这次给的、还在地上的那几件，能直接拖进棋盘）与它用的那层拖拽
var _harvest: HarvestRow = null
## 157：结果页有收获时自动开过一次背包（关了背包重画这一页时不再自动开）
var _bag_auto_opened := false


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
	_hints.clear()
	var title := TextTemplate.plain(_def.title_for() if _def.title_for() != "" else String(_def.id), ctx)
	# 101 第 5 刀：文本层只产出带颜色名的样式码；169：颜色名由富文本块按所在的底换（浅石板暗字）
	var body := TextTemplate.render(_def.text_for(), ctx)
	var col := _frame(_def.image, title, body)
	for i in _def.options.size():
		var opt := _def.options[i] as EventOption
		var state := {"ok": true, "why": ""} if is_briefing() else flow.run.events.option_state(i)
		var ok := bool(state["ok"])
		var hint := TextTemplate.plain(opt.hint_for(), ctx) if opt.hint_when_hidden != "" else ""
		if not ok and opt.hide_when_locked:
			if hint != "":
				_hints.append(hint)     # 113：藏起来的选项说一句为什么（排在选项之后）
			continue
		var idx := i
		# 104：选项文字里的数写成 {change_money_amount|abs} 这类，取这个选项自己的结果 / 条件的字段（TextParams）；193 加 {rest_total}
		var b := _option_button(TextTemplate.plain(opt.label_for(), TextTemplate.option_context(ctx, opt)), func(): choose(idx))
		b.disabled = not ok
		EventCostIcons.attach(b, opt)     # 157：选项前一排代价图标（只画会花掉什么）
		_option_btns.append(b)
		col.add_child(b)
		if not ok:
			col.add_child(_label("　" + (hint if hint != "" else String(state["why"])), 13, UiPalette.DIM))
	for line in _hints:
		col.add_child(_wrapped(line, 13, UiPalette.DIM, 420))
	# 083：事件屏上也能整理背包（教程的「先整理再开打」要在这里做；15 节第 7 项的尾巴）
	if flow.run != null and not is_briefing():     # 218 补充一：交代时局还没开
		col.add_child(_button(UiText.t("event.sort_pack"), toggle_bag, 13, UiPalette.Tier.MINOR))


func _open_result(payload: Dictionary) -> void:
	var detail: Dictionary = payload.get("detail", {})
	var lines: Array[String] = []
	for text in detail.get("log", []):
		lines.append(String(text))
	# 157：给的东西画成下面的「收获」行（还在地上的那几件，能直接拖进棋盘）；认不出是哪几件（老存档）才写成一行字
	var harvest := _harvest_uids(detail)
	var names: Array[String] = []
	for id in detail.get("items", []):
		var d := flow.items.get_def(StringName(String(id)))
		names.append(Names.of(d) if d != null else String(id))
	if not names.is_empty() and harvest.is_empty():
		lines.append(UiText.t("event.got_items") % UiText.t("setup.list_sep").join(names))
	if int(detail.get("restored", 0)) != 0:
		lines.append(UiText.t("event.vitality_up") % int(detail["restored"]))
	if int(detail.get("spent", 0)) != 0:
		lines.append(UiText.t("event.vitality_down") % int(detail["spent"]))
	if int(detail.get("money", 0)) != 0:
		lines.append(UiText.t("event.money") % int(detail["money"]))
	for id in detail.get("buffs", []):
		var bd: RunBuffDef = flow.buff_defs.get(StringName(String(id)), null)
		lines.append(UiText.t("event.buff_gained") % (Names.of(bd) if bd != null else String(id)))
	for id in detail.get("buffs_removed", []):
		var bd2: RunBuffDef = flow.buff_defs.get(StringName(String(id)), null)
		lines.append(UiText.t("event.buff_lost") % (Names.of(bd2) if bd2 != null else String(id)))
	for got in detail.get("belt", []):
		lines.append(UiText.t("event.belt_got") % String(got))     # 160 补一
	var lost: Array[String] = []
	for name in detail.get("items_lost", []):
		lost.append(String(name))
	if not lost.is_empty():
		lines.append(UiText.t("event.items_lost") % UiText.t("setup.list_sep").join(lost))
	if int(detail.get("waited", 0)) > 0:
		lines.append(UiText.t("event.waited") % int(detail["waited"]))
	if String(detail.get("type_changed", "")) != "":
		lines.append(UiText.t("event.type_changed") % MapNodeStyle.of(StringName(String(detail["type_changed"])))["label"])
	if int(detail.get("teleported", -1)) >= 0:
		lines.append(UiText.t("event.teleported"))
	if lines.is_empty():
		lines.append(UiText.t("event.nothing"))
	# 结果页配图沿用这个点的事件（结果只是同一件事的下一页）；老路的事件点没有定义，画占位
	var image := ""
	if _node != null and flow.event_defs != null:
		var def: EventDef = flow.event_defs.get(StringName(String(_node.content.get("event", ""))), null)
		if def != null:
			image = def.image
	var col := _frame(image, String(payload.get("outcome", UiText.t("event.default_title"))), "\n".join(lines))
	_harvest = null
	if not harvest.is_empty():
		col.add_child(_label(UiText.t("event.harvest"), 13, UiPalette.DIM))
		_harvest = HarvestRow.new()
		_harvest.label_font = font
		_harvest.setup(flow.run.storage, harvest)
		_harvest.item_double_clicked.connect(func(_v: ContainerView, uid: int): _ground_to_bag(uid, func():
			if _bag == null:
				toggle_bag()
			return bag_panel()))     # 双击 = 进包（背包开着也进）
		_tip_double(_harvest, "act.take")     # 230
		col.add_child(_harvest)
		_drag = DragLayer.new()
		_drag.label_font = font
		_drag.stash = flow.run.storage
		_drag.drop_outside_to_stash = true
		_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_drag)
		_drag.register_view(_harvest)
	col.add_child(_option_button(UiText.t("menu.continue"), proceed))
	if _harvest != null and not _bag_auto_opened:
		_bag_auto_opened = true
		toggle_bag()     # 157：有收获就把背包打开，拖过去就进棋盘


## 157：这次给的东西里还在地上的那几件（[RunState] 收到地上时把 uid 记进了 detail）
func _harvest_uids(detail: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if flow.run == null or flow.run.storage == null:
		return out
	for uid in detail.get("item_uids", []):
		if flow.run.storage.get_item(int(uid)) != null:
			out.append(int(uid))
	return out


## 157：结果页的收获行（测试看；没有 null）
func harvest_row() -> HarvestRow:
	return _harvest if _harvest != null and is_instance_valid(_harvest) else null


## 两栏的框（参考杀戮尖塔的事件屏）：左边整块是图，右边标题、正文、选项。占掉大半个屏幕，底下的地图压暗。
##
## 返回右栏底部放选项的容器，调用方往里加按钮；正文在可滚的区域里，选项贴在底部
func _frame(image_path: String, title: String, body: String) -> VBoxContainer:
	var panel := _centered_panel(PANEL_SIZE, 0, false, true)
	if _overlay_frame.book:
		return _book_page(panel, image_path, title, body)
	var row := _hbox(0)
	panel.add_child(row)
	var image := EventImage.area(image_path, title, Vector2(IMAGE_WIDTH, 0))     # 左栏：图铺满、按比例裁；没有图就一块深底色写着占位
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(image)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	row.add_child(margin)
	var col := _vbox(14)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	_frame_title(title)     # 157：标题在石板框的标题条上（横跨图与正文）
	var heading := intro_heading()
	if heading != "":
		col.add_child(UiTheme.make_display(heading))     # 168：开场事件先写章节名（马善政大标题）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	if body != "":
		# RichTextLabel：正文里能变色、加粗（BBCode，TextTemplate 的样式码也翻成它）；121：17 号、行距 6
		var text := UiTheme.rich_block(TEXT_WIDTH, UiTheme.RICH_BODY_SIZE, body)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(text)
	var options := _vbox(8)
	options.name = "Options"
	col.add_child(options)
	return options


## 232（作者 19:23 选 1）：书皮 —— 插图摆在左页 `image_rect`，右页 `text_rect` 里一列：标题（`title_h` 高，墨色居中）→ 章节名 → 正文 → 选项
func _book_page(panel: Container, image_path: String, title: String, body: String) -> VBoxContainer:
	var meta := OverlayFrame.book_meta()
	var page := Control.new()
	page.name = "Book"
	page.custom_minimum_size = PANEL_SIZE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(page)
	var ir := _rect(meta.get("image_rect", [14, 44, 640, 672]))
	var image := EventImage.area(image_path, title, ir.size, 22, 12, "", 6, true)
	image.name = "Image"
	image.position = ir.position
	image.size = ir.size
	page.add_child(image)
	var tr := _rect(meta.get("text_rect", [704, 44, 560, 672]))
	var col := _vbox(14)
	col.name = "Page"
	col.position = tr.position
	col.size = tr.size
	col.custom_minimum_size = tr.size
	page.add_child(col)
	var head := _frame_title(title)
	head.custom_minimum_size.y = float(meta.get("title_h", 52))
	col.add_child(head)
	var under := Control.new()     # 花饰线在图里：正文从 title_h + 22 起
	under.custom_minimum_size.y = 22.0 - 14.0
	col.add_child(under)
	var heading := intro_heading()
	if heading != "":
		col.add_child(UiTheme.make_display(heading))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	if body != "":
		var text := UiTheme.rich_block(tr.size.x, UiTheme.RICH_BODY_SIZE, body)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(text)
	var options := _vbox(8)
	options.name = "Options"
	col.add_child(options)
	return options


static func _rect(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


## 168：这一屏是这一章的开场事件 → 章节名；别的事件空
func intro_heading() -> String:
	var ch: ChapterDef = flow.run.chapter if flow.run != null else null
	if _def == null or ch == null or ch.intro_event == &"" or _def.id != ch.intro_event:
		return ""
	return Names.of(ch) if ch.display_name != "" else String(ch.id)


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
	if is_briefing():
		flow.close_briefing()
		return true
	return flow.choose_event(i)


## 通用的「往下走」：选项页选第一个能选的，结果页继续
func proceed() -> void:
	if is_briefing():
		flow.close_briefing()
		return
	if _def != null and flow.run != null and flow.run.events.pending_event() == _def:
		for i in _def.options.size():
			if bool(flow.run.events.option_state(i)["ok"]):
				choose(i)
				return
		return
	flow.resume()


func is_options_page() -> bool:
	return _def != null


## 218 补充一：这一屏是开局屏「出发」之前的交代（[method GameFlow.show_briefing]）—— 局还没开，选项都是「知道了，出发」
func is_briefing() -> bool:
	return bool(_payload.get("briefing", false))


## 背包整理面板叠在事件上；收起时重画选项（条件可能因为整理过了而满足）
func toggle_bag() -> void:
	if _bag != null:
		_bag.hide()     # 134：先藏起来 —— 这一帧里它的拖拽层就不再算「接地上的面板」
		_bag.queue_free()
		_bag = null
		_rebuild()
		return
	if flow.run == null:
		return
	_bag = _shade(0.7)
	# 084：背包是能拖着走的浮窗，不锁在一个地方；关掉再开还在上次放的位置
	var win := BagWindow.new()
	_bag.add_child(win)
	# 157：结果页有收获行时和它共用一层拖拽（从收获行拖进棋盘）；拖拽层挪到最上面，残影画在背包浮窗之上
	var shared := _drag if _harvest != null and is_instance_valid(_drag) else null
	_bag_panel = win.setup_bag(flow.run, font, toggle_bag, shared)
	win.maybe_coach(flow, _bag)     # 218 补充一：序章一第一次开背包窗放教程
	if shared != null:
		move_child(shared, -1)


func bag_open() -> bool:
	return _bag != null


## 134：开着的背包浮窗里那块面板（没开 null）
func bag_panel() -> Control:
	return _bag_panel if _bag != null and is_instance_valid(_bag_panel) else null


## 134（作者定）：地上双击 —— 背包开着就交给背包面板；没开就进包并打开背包（放不下只开背包、面板里提示）
func ground_double_clicked(uid: int) -> bool:
	if _bag != null:
		return false
	return _ground_to_bag(uid, func():
		if _bag == null:
			toggle_bag()
		return bag_panel())


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
	_option_btns.clear()
	_reopen(_payload)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_B or not is_options_page() or is_briefing():
		return
	toggle_bag()
	get_viewport().set_input_as_handled()
#endregion

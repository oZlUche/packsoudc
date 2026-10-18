## 悬浮窗（084）：跟着鼠标的一小块面板，写 BBCode。两处用：容器视图里停在一件道具上（[ItemTooltip]），地图上停在一个点上（[NodeTooltip]）。
##
## 170（作者定）：**十字军之王式的固定悬浮窗** —— 深底白字（[constant UiTheme.ART_TOOLTIP]），道具说明分块（头 / 分隔线 / 正文 / 虚线 / 脚注）。
## - 跟随：停在道具上出现、跟着鼠标；鼠标离开道具后给 [constant GRACE_SEC] 秒宽限，这期间进了悬浮窗就留下（不换、不收）；往窗外走就不等（[constant AWAY_PX]）。
## - 钉住：作者 2026-10-17 —— 悬浮窗出来后，鼠标还停在**叫出它的源**上（道具 / 关键词 / 地图点）或在窗里，满 [constant PIN_SEC] 秒就钉 ——
##   一道黄铜线从左上角沿外框**顺时针**走一圈，走完即钉；源和窗都离开了归零。钉住后右上角一颗钉子，窗不再动；源换了也不换窗。
## - 关键词：钉住的窗里带下划线的词（`[url=term:<id>]`，[method Glossary.mark]）停 [constant TERM_SEC] 秒开**子窗**（同样可钉、可再开），深度封顶 [constant MAX_DEPTH]。
## - 收起：离开钉住的窗与它所有子窗 [constant AWAY_SEC] 秒、按 Esc、点窗外（开始拖拽也是先点下去）→ 整串收掉。
## 087 的词条侧窗取消：词条只以下划线关键词存在，`terms` 是 `{id: {"name", "text"}}`（[method ItemTooltip.describe_full]）供子窗查。
##
## 加进一个铺满的宿主控件里（叠层 / 屏），自己不挡鼠标（窗本身挡）。登记容器视图后，鼠标在视图里动就查底下是哪件、显示说明；
## 别的来源（地图）直接调 [method show_text] / [method hide_tip]。计时都在 [method tick]（测试直接喂时间与鼠标位置）
class_name HoverTip
extends Control

const MAX_WIDTH := 360.0     # 170 定稿：字大一号后 340 放不下武器那一行
## 185：只写文字的主窗按内容收窄，下限这么宽（道具窗固定 [constant MAX_WIDTH]）
const MIN_WIDTH := 220.0
const CHILD_WIDTH := 260.0
## 170 §3：离开道具后的宽限、钉住要停多久、关键词开子窗要停多久、离开钉住的窗多久收、子窗最多几层（含主窗）
const GRACE_SEC := 0.15
const PIN_SEC := 0.6
const TERM_SEC := 0.25
const AWAY_SEC := 0.4
## 作者 2026-10-16（移开道具后悬浮窗消失有延迟）：宽限只留给往悬浮窗去的鼠标 —— 宽限期里离窗比刚离开时远出这么多像素就立刻收 / 换
const AWAY_PX := 2.0
const MAX_DEPTH := 3
## 钉住进度线：2 px 黄铜色
const RING_WIDTH := 2.0
const RING_COLOR := Color("d4a84f")

## 一扇悬浮窗（主窗或子窗）：头 / 分隔线 / 正文 / 虚线 / 脚注（只写文字时只有正文），外框上画钉住进度与钉子
class TipWindow extends PanelContainer:
	var depth := 0
	var head: RichTextLabel
	var sep: ColorRect
	var body: RichTextLabel
	var foot_sep: Control
	var foot_row: HBoxContainer
	var foot: RichTextLabel
	var set_label: Label
	var col: VBoxContainer
	## 词条 id → {"name", "text"}（停在关键词上开子窗时查）
	var terms: Dictionary = {}
	var pinned := false
	## 鼠标在窗里停了多久（钉住进度 = dwell / PIN_SEC）
	var dwell := 0.0
	## 离开计时（主窗：离开道具后的宽限；子窗：离开它和开它的那个词）；< 0 = 没在离开
	var leave_t := -1.0
	## 鼠标正停在哪个关键词上（`term:<id>`）、停了多久
	var hover_term := ""
	var hover_t := 0.0
	## 子窗：是父窗的哪个关键词开的
	var origin_term := ""
	var item_mode := false
	## 钉子图标在建窗时就读好 —— 兼容渲染器下第一次在 `_draw` 里才读的贴图会画成白块
	var _pin_tex: Texture2D

	func _init(width: float) -> void:
		UiTheme.panel(self, -1, UiTheme.PANEL_TOOLTIP)
		# 185：皮革窗是深底，挂亮字 —— 嵌在浅石板（战斗屏）里也不继承墨字（名牌同款）
		theme = UiTheme.bright_text_theme()
		full_width = width
		var pin_path := UiTheme.TIP_ICON_DIR + "pin.png"
		_pin_tex = load(pin_path) as Texture2D if ResourceLoader.exists(pin_path) else null
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(col)
		head = _rich(width)
		col.add_child(head)
		sep = ColorRect.new()
		sep.color = UiPalette.LINE.lightened(0.3)     # 170：分隔线比底色提亮一档
		sep.custom_minimum_size = Vector2(width, 1)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sep)
		body = _rich(width)
		col.add_child(body)
		foot_sep = dashed(width)
		col.add_child(foot_sep)
		foot_row = HBoxContainer.new()
		foot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(foot_row)
		foot = _rich(0)
		foot.autowrap_mode = TextServer.AUTOWRAP_OFF
		foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot_row.add_child(foot)
		set_label = UiTheme.make_label("", 12, UiPalette.DIM)
		set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		set_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot_row.add_child(set_label)

	## 一条虚线（脚注上面那条；188 信仰窗的分段也用）
	func dashed(width: float) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(width, 3)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func():
			c.draw_dashed_line(Vector2(0, 1), Vector2(c.size.x, 1), UiPalette.LINE.lightened(0.3), 1.0, 4.0))
		return c

	func _rich(width: float) -> RichTextLabel:
		var r := UiTheme.rich_block(width, UiTheme.RICH_SMALL_SIZE)
		r.mouse_filter = Control.MOUSE_FILTER_PASS     # 关键词要收得到鼠标（meta 悬停），点击照样往上传给窗
		r.meta_underlined = false     # 下划线由 BBCode 自己写（[u]），url 不再额外画
		r.meta_hover_started.connect(func(meta): hover(String(meta)))
		r.meta_hover_ended.connect(func(_meta): hover(""))
		return r

	## 鼠标停到 / 离开一个关键词（`term:<id>`；空 = 离开）
	func hover(meta: String) -> void:
		if meta != hover_term:
			hover_term = meta if meta.begins_with("term:") else ""
			hover_t = 0.0

	## 185：排版宽（只写文字的主窗按内容收窄时改它）
	var full_width := 0.0

	func set_width(w: float) -> void:
		head.custom_minimum_size.x = w
		body.custom_minimum_size.x = w
		sep.custom_minimum_size.x = w
		foot_sep.custom_minimum_size.x = w

	func content_width() -> float:
		var w := float(body.get_content_width())
		if head.visible:
			w = maxf(w, float(head.get_content_width()))
		return w

	## 185：状态说明 —— 名字行 / 分隔线 / 效果（[method Glossary.buff_tip_parts]）
	func set_status(head_bb: String, body_bb: String) -> void:
		item_mode = false
		set_width(full_width)
		head.visible = true
		sep.visible = true
		foot_sep.visible = false
		foot_row.visible = false
		UiTheme.set_rich(head, head_bb)
		UiTheme.set_rich(body, body_bb)

	## 只写一段文字（地图上的点、子窗）
	func set_text(bbcode: String) -> void:
		item_mode = false
		set_width(full_width)
		head.visible = false
		sep.visible = false
		foot_sep.visible = false
		foot_row.visible = false
		UiTheme.set_rich(body, bbcode)

	## 170：道具说明分块
	func set_item(full: Dictionary) -> void:
		item_mode = true
		set_width(full_width)
		head.visible = true
		sep.visible = true
		foot_sep.visible = true
		foot_row.visible = true
		UiTheme.set_rich(head, String(full.get("head", "")))
		UiTheme.set_rich(body, String(full.get("body", "")))
		UiTheme.set_rich(foot, String(full.get("foot", "")))
		set_label.text = String(full.get("set", ""))

	func text() -> String:
		if not item_mode:
			return (head.text + "\n" + body.text) if head.visible else body.text
		return "\n".join([head.text, body.text, foot.text + ("　" + set_label.text if set_label.text != "" else "")])

	func reset_state() -> void:
		pinned = false
		dwell = 0.0
		leave_t = -1.0
		hover_term = ""
		hover_t = 0.0
		queue_redraw()

	func global_rect() -> Rect2:
		return Rect2(global_position, size)

	## 钉住进度（顺时针沿外框）与钉子
	func _draw() -> void:
		var r := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		if pinned:
			if _pin_tex != null:
				draw_texture_rect(_pin_tex, Rect2(Vector2(size.x - 20, 4), Vector2(16, 16)), false)
			else:
				draw_rect(Rect2(Vector2(size.x - 12, 6), Vector2(6, 6)), HoverTip.RING_COLOR)
			return
		var p := clampf(dwell / HoverTip.PIN_SEC, 0.0, 1.0)
		if p <= 0.0:
			return
		draw_polyline(HoverTip.ring_points(r, p), HoverTip.RING_COLOR, HoverTip.RING_WIDTH)


var _windows: Array[TipWindow] = []
## 主窗（[member _windows] 的第一扇）与它的正文（老代码、测试按这两个名字找）
var _panel: TipWindow
var _text: RichTextLabel
var _extra: Control = null
## 188：信仰窗插进主窗里的件（名字行下的进度条、各段之间的虚线与段落）—— 换窗时一起摘
var _faith_parts: Array[Control] = []
var _views: Array[ContainerView] = []
## 可选：`func(view, uid) -> bool`，假就不显示（容器屏：没亮出来的不说）
var can_show: Callable = Callable()
var _uid: int = -1
var _for_view: ContainerView = null
## 离开当前道具后、宽限期满时要看的那个位置（视图与视图里的坐标；视图为 null = 出了视图）
var _pending_view: ContainerView = null
var _pending_local := Vector2.ZERO
## 离开钉住的那一串窗多久了
var _away := 0.0
## 鼠标还在叫出主窗的源上（作者 2026-10-17：停在源上也走钉住进度；钉住后在源上也不算离开）。源离开时调 [method release]
var _on_source := false
## 宽限开始时鼠标离主窗多远（-1 = 还没记）
var _leave_d := -1.0
## 最后一次摆放用的鼠标位置（全局）：排版完再量一次尺寸后照这个重摆
var _last_at := Vector2.ZERO
var _refit_queued := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60     # 128：画在地上（盖在各屏上面的那一层）的东西之上；相对自己那一屏（作者 2026-10-13：导演给叠层整屏抬高，地图的悬浮窗不再盖住叠层）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = _new_window(0, MAX_WIDTH)
	_text = _panel.body
	# 富文本换了字要等排版完才知道真高：最小尺寸一变就下一帧缩回去重摆，不留旧文字的高度
	_panel.minimum_size_changed.connect(_queue_refit)
	_text.minimum_size_changed.connect(_queue_refit)


func _new_window(depth: int, width: float) -> TipWindow:
	var w := TipWindow.new(width)
	w.depth = depth
	add_child(w)
	_windows.append(w)
	return w


## 087：给一个容器视图找它该用的悬浮窗并登记上去：沿祖先往上找，谁的直接子节点里有 HoverTip 就用它（屏 / 面板自己造的那个）；
## 一路没有就在最顶层的 Control 祖先下造一个。返回用的那个（视图不在树里返回 null）
static func ensure_for(view: ContainerView) -> HoverTip:
	if view == null or not view.is_inside_tree():
		return null
	var node: Node = view.get_parent()
	var top: Control = null
	while node != null:
		for c in node.get_children():
			if c is HoverTip:
				(c as HoverTip).watch(view)
				return c
		if node is Control:
			top = node
		node = node.get_parent()
	if top == null:
		return null
	var tip := HoverTip.new()
	top.add_child(tip)
	tip.watch(view)
	return tip


## 登记一个容器视图：停在道具上就显示 [ItemTooltip]
func watch(view: ContainerView) -> void:
	if _views.has(view):
		return
	_views.append(view)
	view.gui_input.connect(func(event: InputEvent): _on_view_input(view, event))
	view.mouse_exited.connect(func():
		if _for_view != view:
			return
		_on_source = false
		if not _panel.pinned:
			_begin_leave(null, Vector2.ZERO))     # 170：出视图（多半是往悬浮窗里去）先给宽限


## 直接显示一段文字（地图上的点）；[param extra] 是文字下面再放的一个控件（对手的棋盘），可为 null；
## [param terms] 是关键词的词条（`{id: {"name", "text"}}`，或老的 `[{name, text}]`），钉住后停在关键词上开子窗
func show_text(bbcode: String, at: Vector2, extra: Control = null, terms = {}) -> void:
	if _panel.visible and _panel.pinned:
		return     # 钉住的窗不被别的源换掉（离开它才收，[constant AWAY_SEC]）
	_close_from(1)
	_panel.reset_state()
	_panel.set_text(bbcode)
	_panel.terms = _terms_dict(terms)
	_drop_extra()
	if extra != null:
		_extra = extra
		_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.col.add_child(_extra)
	_open_main(at)


## 185：显示一个状态的说明（名字行 / 分隔线 / 效果，[method Glossary.buff_tip_parts]）；钉住的窗不换
func show_status(parts: Dictionary, at: Vector2) -> void:
	if _panel.visible and _panel.pinned:
		return
	_close_from(1)
	_panel.reset_state()
	_drop_extra()
	_panel.set_status(String(parts.get("head", "")), String(parts.get("body", "")))
	_panel.terms = _terms_dict(parts.get("terms", {}))
	_open_main(at)


## 185 补充一：开着的状态窗只换字（还剩几秒在走）—— 不重摆、不动钉住
func update_status(parts: Dictionary) -> void:
	if not _panel.visible or _panel.item_mode:
		return
	UiTheme.set_rich(_panel.head, String(parts.get("head", "")))
	UiTheme.set_rich(_panel.body, String(parts.get("body", "")))


## 188：信仰窗（[method FaithTooltip.describe_full]）：名字行 + 信力行 / 分段进度条（补充一：一段一级，满阶也挂）/ 分隔线 / 第一段 / 虚线 / 下一段……
## 宽固定 [constant MAX_WIDTH]（和道具窗一样，不按内容收窄）；钉住的窗不换；空字典（没有信仰）不开
func show_faith(full: Dictionary, at: Vector2) -> void:
	if full.is_empty() or (_panel.visible and _panel.pinned):
		return
	_close_from(1)
	_panel.reset_state()
	_drop_extra()
	var sections: Array = full.get("sections", [])
	_panel.set_status(String(full.get("head", "")), String(sections[0]) if not sections.is_empty() else "")
	_panel.body.visible = not sections.is_empty()
	_panel.terms = {}
	var bar_data: Dictionary = full.get("bar", {})
	if not (bar_data.get("thresholds", []) as Array).is_empty():
		var bar := FaithBar.new()     # 188 补充一：分段，满阶也挂（全满）
		bar.thresholds.assign(bar_data["thresholds"])
		bar.points = int(bar_data.get("points", 0))
		bar.custom_minimum_size = Vector2(_panel.full_width, FaithBar.HEIGHT)
		_insert_part(bar, _panel.head.get_index() + 1)
	for i in range(1, sections.size()):
		_insert_part(_panel.dashed(_panel.full_width), _panel.foot_sep.get_index())
		var r := _panel._rich(_panel.full_width)
		_insert_part(r, _panel.foot_sep.get_index())
		UiTheme.set_rich(r, String(sections[i]))
	_open_main(at)


func _insert_part(c: Control, at: int) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE if not (c is RichTextLabel) else c.mouse_filter
	_panel.col.add_child(c)
	_panel.col.move_child(c, at)
	_faith_parts.append(c)


## 188：信仰窗名字行下那条进度条。补充一（作者 2026-10-18「分段式，一段代表一个等级，长度和需要的信力对应」）：
## 一段 = 一级，段宽按这一级要涨的信力（阈值差）成比例，最窄 [constant MIN_SEG]；段间 1 px 分隔；填到现在的信力（已到的级整段、正在涨的按比例）
class FaithBar extends Control:
	const HEIGHT := 8.0
	const MIN_SEG := 12.0
	const SLOT := Color("1a1512")
	var thresholds: Array[int] = []
	var points := 0

	## 各段 [起点, 宽]（按 [param width] 排；最窄 MIN_SEG，多出的从别的段按比例扣）
	func segments(width: float) -> Array[Vector2]:
		var out: Array[Vector2] = []
		var n := thresholds.size()
		if n == 0:
			return out
		var gaps: Array[float] = []
		var prev := 0
		for th in thresholds:
			gaps.append(float(maxi(1, th - prev)))
			prev = th
		var usable := maxf(0.0, width - float(n - 1))     # 段间 1 px
		var total := 0.0
		for g in gaps:
			total += g
		var widths: Array[float] = []
		var small := 0.0
		var rest := 0.0
		for g in gaps:
			var w := usable * g / total
			widths.append(w)
			if w < MIN_SEG:
				small += MIN_SEG - w
			else:
				rest += w
		if small > 0.0 and rest > 0.0:
			for i in n:
				widths[i] = MIN_SEG if widths[i] < MIN_SEG else widths[i] - small * widths[i] / rest
		var x := 0.0
		for w in widths:
			out.append(Vector2(x, w))
			x += w + 1.0
		return out

	## 第 [param i] 段填了几成
	func fill_of(i: int) -> float:
		var from := thresholds[i - 1] if i > 0 else 0
		return clampf(float(points - from) / float(maxi(1, thresholds[i] - from)), 0.0, 1.0)

	func _draw() -> void:
		var segs := segments(size.x)
		for i in segs.size():
			var seg := segs[i]
			draw_rect(Rect2(seg.x, 0.0, seg.y, size.y), SLOT, true)
			var f := fill_of(i)
			if f > 0.0:
				draw_rect(Rect2(seg.x, 0.0, seg.y * f, size.y), UiPalette.FAITH, true)
			if i > 0:
				draw_rect(Rect2(seg.x - 1.0, 0.0, 1.0, size.y), UiPalette.LINE, true)


## 188：主窗里现在挂着的进度条（测试看；没有 null）
func faith_bar() -> Control:
	for c in _faith_parts:
		if c is FaithBar:
			return c
	return null


## 170：显示一件道具的分块说明（[method ItemTooltip.describe_full] 的结果）
func show_item(full: Dictionary, at: Vector2) -> void:
	_close_from(1)
	_panel.reset_state()
	_drop_extra()
	_panel.set_item(full)
	_panel.terms = _terms_dict(full.get("terms", {}))
	_open_main(at)


func _open_main(at: Vector2) -> void:
	_on_source = true
	_panel.visible = true
	_panel.reset_size()
	_place(at)
	_queue_refit()


static func _terms_dict(terms) -> Dictionary:
	if terms is Dictionary:
		return terms
	var out := {}
	if terms is Array:
		for t in terms:
			var d := t as Dictionary
			out[String(d.get("id", d["name"]))] = {"name": d["name"], "text": d["text"]}
	return out


## 旧的下挂控件先摘下来再 free：queue_free 到帧末才走，留在列里会把这一帧的 reset_size 撑高（悬浮窗下方大段空白）
func _drop_extra() -> void:
	for c in _faith_parts:
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
		c.queue_free()
	_faith_parts.clear()
	_panel.body.visible = true
	if _extra == null:
		return
	if _extra.get_parent() != null:
		_extra.get_parent().remove_child(_extra)
	_extra.queue_free()
	_extra = null


func _queue_refit() -> void:
	if _refit_queued or not _panel.visible:
		return
	_refit_queued = true
	_refit.call_deferred()


## 排版完再按实际内容缩一次尺寸，照最后的鼠标位置重摆（钉住了就不挪）
func _refit() -> void:
	_refit_queued = false
	if not _panel.visible:
		return
	var at := _panel.position
	_shrink_to_text()
	_panel.reset_size()
	if _panel.pinned:
		_panel.position = at
	else:
		_place(_last_at)


## 185：只写文字的主窗按内容收窄（[constant MIN_WIDTH]～[constant MAX_WIDTH]）；道具窗、下面挂了控件的不收
func _shrink_to_text() -> void:
	if _panel.item_mode or _extra != null or not _faith_parts.is_empty():
		return
	var w := clampf(ceilf(_panel.content_width()) + 1.0, MIN_WIDTH, _panel.full_width)
	if absf(_panel.body.custom_minimum_size.x - w) > 0.5:
		_panel.set_width(w)


## 主窗的宽（测试看）
func window_width() -> float:
	return _panel.size.x


func tone() -> StringName:
	return UiTheme.tone_of(UiTheme.PANEL_TOOLTIP)


## 跟着鼠标走（地图上的浮窗：节点不变时也要跟）；钉住了不跟
func follow(global_at: Vector2) -> void:
	if _panel.visible and not _panel.pinned:
		_place(global_at)


## 整串收掉
func hide_tip() -> void:
	_close_from(1)
	_panel.visible = false
	_panel.reset_state()
	_uid = -1
	_for_view = null
	_pending_view = null
	_away = 0.0
	_on_source = false


## 作者 2026-10-17：叫出悬浮窗的源（按钮、图鉴格、地图点、buff 图标）鼠标离开时调这个 —— 没钉住就收；钉住了留着，离开窗 [constant AWAY_SEC] 秒才收
func release() -> void:
	_on_source = false
	if not _panel.pinned:
		hide_tip()


func is_showing() -> bool:
	return _panel.visible


## 主窗的文字（道具：头 / 正文 / 脚注连起来）
func text() -> String:
	return _panel.text()


func is_pinned() -> bool:
	return _panel.visible and _panel.pinned


## 开着的窗（主窗 + 子窗），测试看
func windows() -> Array[TipWindow]:
	var out: Array[TipWindow] = []
	for w in _windows:
		if w.visible:
			out.append(w)
	return out


func _process(delta: float) -> void:
	if _panel.visible:
		tick(delta, get_global_mouse_position())


## 170 §3 的全部计时：宽限、钉住进度、关键词停留、子窗的去留、离开收起。[param mouse] 是全局坐标
func tick(delta: float, mouse: Vector2) -> void:
	if not _panel.visible:
		return
	if not _panel.pinned:
		var in_panel := _panel.global_rect().has_point(mouse)
		if in_panel:
			_panel.leave_t = -1.0
		if in_panel or (_on_source and _panel.leave_t < 0.0):
			_panel.dwell += delta
			if _panel.dwell >= PIN_SEC:
				pin(_panel)
		elif _panel.leave_t < 0.0:
			_panel.dwell = 0.0
		else:     # 宽限里（往窗里去的路上）：进度停着不归零
			if _panel.leave_t >= 0.0:
				var d := rect_distance(_panel.global_rect(), mouse)
				if _leave_d < 0.0:
					_leave_d = d
				_panel.leave_t += delta
				if _panel.leave_t >= GRACE_SEC or d > _leave_d + AWAY_PX:
					_panel.leave_t = -1.0
					_resolve_pending()
		_panel.queue_redraw()
		return
	var open := windows()
	var inside := _on_source
	for w in open:
		if w.global_rect().has_point(mouse):
			inside = true
	if inside:
		_away = 0.0
	else:
		_away += delta
		if _away >= AWAY_SEC:
			hide_tip()
			return
	for i in open.size():
		var w := open[i]
		if w.depth > 0 and not w.pinned:
			var on_word := open[i - 1].hover_term == w.origin_term     # 还停在开它的那个词上（作者 2026-10-17：也走钉住进度）
			if w.global_rect().has_point(mouse) or on_word:
				w.leave_t = -1.0
				w.dwell += delta
				if w.dwell >= PIN_SEC:
					pin(w)
					return
			else:
				w.dwell = 0.0
				w.leave_t = maxf(w.leave_t, 0.0) + delta
				if w.leave_t >= GRACE_SEC:
					_close_from(i)
					return
			w.queue_redraw()
		if w.pinned and w.hover_term != "":
			w.hover_t += delta
			var child: TipWindow = open[i + 1] if i + 1 < open.size() else null
			if w.hover_t >= TERM_SEC and (child == null or child.origin_term != w.hover_term):
				open_child(w, w.hover_term)
				return


## 钉住一扇窗：进度走满，右上角画钉子；主窗不再跟鼠标
func pin(w: TipWindow) -> void:
	w.pinned = true
	w.dwell = PIN_SEC
	w.leave_t = -1.0
	_away = 0.0
	w.queue_redraw()


## 从钉住的 [param parent] 的关键词 [param meta]（`term:<id>`）开一扇子窗；深度到顶或查不到词条返回 null。
## 位置：父窗右边，放不下换下面，再夹回屏幕里
func open_child(parent: TipWindow, meta: String) -> TipWindow:
	var at := _windows.find(parent)
	if at < 0 or not parent.pinned or parent.depth + 1 >= MAX_DEPTH:
		return null
	var id := meta.trim_prefix("term:")
	if not parent.terms.has(id):
		return null
	_close_from(at + 1)
	var entry: Dictionary = parent.terms[id]
	var w: TipWindow = null
	for c in _windows:
		if not c.visible and c.depth == parent.depth + 1:
			w = c
			break
	if w == null:
		w = _new_window(parent.depth + 1, CHILD_WIDTH)
	_windows.erase(w)
	_windows.insert(at + 1, w)
	w.reset_state()
	w.origin_term = meta
	# 子窗里的说明也可能提到别的词条：父窗认得的 + 固定词条（不含自己）
	var extra := {}
	for k in parent.terms:
		if k != id:
			extra[String(parent.terms[k]["name"])] = {"id": k, "text": parent.terms[k]["text"], "style": String((parent.terms[k] as Dictionary).get("style", "term"))}
	var found := Glossary.terms_in(String(entry["text"]), extra).filter(func(f): return String(f["id"]) != id and String(f["name"]) != String(entry["name"]))
	w.terms = {}
	for k in parent.terms:
		w.terms[k] = parent.terms[k]
	for f in found:
		w.terms[String(f["id"])] = {"name": f["name"], "text": f["text"], "style": String(f.get("style", "term"))}
	w.set_text("%s\n[color=@tip_fg]%s[/color]" % [UiTheme.outline("[b][color=@%s]%s[/color][/b]" % [String((entry as Dictionary).get("style", "term")), String(entry["name"])]), Glossary.mark_rich(String(entry["text"]), found)])     # 170 定稿：只有名字描边；175 补 5.4：伤害字带色
	w.visible = true
	w.reset_size()
	_place_child(w, parent)
	return w


## 关掉第 [param index] 扇起（含）往后的窗
func _close_from(index: int) -> void:
	for i in range(maxi(index, 1), _windows.size()):
		_windows[i].visible = false
		_windows[i].reset_state()
		_windows[i].origin_term = ""


func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE and _panel.pinned:
		hide_tip()
		get_viewport().set_input_as_handled()     # Esc 先收悬浮窗，不再往下开菜单
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		click_at(mb.global_position)


## 点下去：点在开着的窗外（含开始拖拽）→ 钉住的整串收掉；没钉住的跟随窗照旧（点道具时它本来就在别处）
func click_at(global_at: Vector2) -> void:
	if not _panel.pinned:
		return
	for w in windows():
		if w.global_rect().has_point(global_at):
			return
	hide_tip()


func _on_view_input(view: ContainerView, event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	var uid := _uid_under(view, mm.position)
	if _panel.pinned:
		_on_source = _panel.visible and view == _for_view and uid == _uid     # 钉住了：只记还在不在源上
		return
	var inst := _shown_item(view, uid)
	if not _panel.visible:
		if inst != null:
			_show_for(view, uid, inst, mm.position)
		return
	if inst != null and view == _for_view and uid == _uid:
		_panel.leave_t = -1.0
		_on_source = true
		_place(view.get_global_position() + mm.position)
		return
	_begin_leave(view, mm.position)     # 170：离开这件（换到别的、空格）先给宽限 —— 这期间进了悬浮窗就留下


## 视图里这个 uid 能不能显示（有东西、can_show 放行）；不能返回 null
func _shown_item(view: ContainerView, uid: int) -> ItemInstance:
	if uid < 0 or uid == GridInventory.EMPTY_UID:
		return null
	var inst := view.container().get_item(uid)
	if inst == null or (can_show.is_valid() and not bool(can_show.call(view, uid))):
		return null
	return inst


func _show_for(view: ContainerView, uid: int, inst: ItemInstance, local: Vector2) -> void:
	_for_view = view
	_uid = uid
	var board: GridInventory = null
	if view is InventoryView:
		board = (view as InventoryView).inventory
	show_item(ItemTooltip.describe_full(inst, board), view.get_global_position() + local)


func _begin_leave(view: ContainerView, local: Vector2) -> void:
	_on_source = false
	_pending_view = view
	_pending_local = local
	if _panel.leave_t < 0.0:
		_panel.leave_t = 0.0
		_leave_d = -1.0     # 下一拍 tick 记下离窗多远


## 宽限期满、鼠标没进悬浮窗：照最后那个位置办 —— 底下有能显示的就换成它，没有就收
func _resolve_pending() -> void:
	var view := _pending_view
	_pending_view = null
	if view == null or not is_instance_valid(view):
		hide_tip()
		return
	var uid := _uid_under(view, _pending_local)
	var inst := _shown_item(view, uid)
	if inst == null:
		hide_tip()
	elif view != _for_view or uid != _uid:
		_show_for(view, uid, inst, _pending_local)


## 点到矩形的距离（在里面是 0）
static func rect_distance(r: Rect2, p: Vector2) -> float:
	return p.distance_to(p.clamp(r.position, r.end))


func _uid_under(view: ContainerView, local: Vector2) -> int:
	if view is InventoryView:
		var iv := view as InventoryView
		if iv.inventory == null:
			return -1
		var c := iv.cell_at_local(local)
		var uid := iv.inventory.cell_uid(c)
		return uid if uid != GridInventory.EMPTY_UID else iv.inventory.bag_at(c)
	if view.has_method("uid_at_local"):
		return view.uid_at_local(local)     # 128：地上；157：事件的收获行
	return -1


## 主窗放在鼠标右下，出屏就翻到左 / 上，再夹回屏里。「屏」是真正的视口，不是本控件的尺寸（背包浮窗那种比屏窄的宿主里也要按屏算）
func _place(global_at: Vector2) -> void:
	_last_at = global_at
	var local := global_at - global_position
	var s := _panel.size
	var lo := -global_position
	var hi := lo + (get_viewport_rect().size if is_inside_tree() else size)
	var px := local.x + 16
	if px + s.x > hi.x:
		px = local.x - s.x - 8
	px = clampf(px, lo.x, maxf(lo.x, hi.x - s.x))
	var py := local.y + 16
	if py + s.y > hi.y:
		py = local.y - s.y - 8
	py = clampf(py, lo.y, maxf(lo.y, hi.y - s.y))
	_panel.position = Vector2(px, py)


## 子窗：父窗右边（顶对齐），放不下换父窗下面，再夹回屏幕里
func _place_child(w: TipWindow, parent: TipWindow) -> void:
	var lo := -global_position
	var hi := lo + (get_viewport_rect().size if is_inside_tree() else size)
	var s := w.size
	var p := Vector2(parent.position.x + parent.size.x + 6, parent.position.y)
	if p.x + s.x > hi.x:
		p = Vector2(parent.position.x, parent.position.y + parent.size.y + 6)
	p.x = clampf(p.x, lo.x, maxf(lo.x, hi.x - s.x))
	p.y = clampf(p.y, lo.y, maxf(lo.y, hi.y - s.y))
	w.position = p


## 钉住进度线：从左上角起沿 [param r] 的外框顺时针走 [param p]（0..1）那么长 —— 上边、右边、下边、左边依次
static func ring_points(r: Rect2, p: float) -> PackedVector2Array:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	var total := 2.0 * (r.size.x + r.size.y)
	var left := clampf(p, 0.0, 1.0) * total
	var pts := PackedVector2Array([corners[0]])
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var seg := a.distance_to(b)
		if left >= seg:
			pts.append(b)
			left -= seg
		else:
			pts.append(a + (b - a) * (left / maxf(seg, 0.001)))
			break
	return pts

## 悬浮窗（084）：跟着鼠标的一小块面板，写 BBCode。两处用：容器视图里停在一件道具上（[ItemTooltip]），地图上停在一个点上（[NodeTooltip]）。
##
## 170（作者定）：**十字军之王式的固定悬浮窗** —— 深底白字（[constant UiTheme.ART_TOOLTIP]），道具说明分块（头 / 分隔线 / 正文 / 虚线 / 脚注）。
## - 跟随：停在道具上出现、跟着鼠标；鼠标离开道具后给 [constant GRACE_SEC] 秒宽限，这期间进了悬浮窗就留下（不换、不收）。
## - 钉住：鼠标在悬浮窗里停满 [constant PIN_SEC] 秒 —— 一道黄铜线从左上角沿外框**顺时针**走一圈，走完即钉；中途移出归零。钉住后右上角一颗钉子，窗不再动。
## - 关键词：钉住的窗里带下划线的词（`[url=term:<id>]`，[method Glossary.mark]）停 [constant TERM_SEC] 秒开**子窗**（同样可钉、可再开），深度封顶 [constant MAX_DEPTH]。
## - 收起：离开钉住的窗与它所有子窗 [constant AWAY_SEC] 秒、按 Esc、点窗外（开始拖拽也是先点下去）→ 整串收掉。
## 087 的词条侧窗取消：词条只以下划线关键词存在，`terms` 是 `{id: {"name", "text"}}`（[method ItemTooltip.describe_full]）供子窗查。
##
## 加进一个铺满的宿主控件里（叠层 / 屏），自己不挡鼠标（窗本身挡）。登记容器视图后，鼠标在视图里动就查底下是哪件、显示说明；
## 别的来源（地图）直接调 [method show_text] / [method hide_tip]。计时都在 [method tick]（测试直接喂时间与鼠标位置）
class_name HoverTip
extends Control

const MAX_WIDTH := 360.0     # 170 定稿：字大一号后 340 放不下武器那一行
const CHILD_WIDTH := 260.0
## 170 §3：离开道具后的宽限、钉住要停多久、关键词开子窗要停多久、离开钉住的窗多久收、子窗最多几层（含主窗）
const GRACE_SEC := 0.15
const PIN_SEC := 0.6
const TERM_SEC := 0.25
const AWAY_SEC := 0.4
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
		foot_sep = Control.new()
		foot_sep.custom_minimum_size = Vector2(width, 3)
		foot_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot_sep.draw.connect(func():
			foot_sep.draw_dashed_line(Vector2(0, 1), Vector2(foot_sep.size.x, 1), UiPalette.LINE.lightened(0.3), 1.0, 4.0))
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

	## 只写一段文字（地图上的点、子窗）
	func set_text(bbcode: String) -> void:
		item_mode = false
		head.visible = false
		sep.visible = false
		foot_sep.visible = false
		foot_row.visible = false
		UiTheme.set_rich(body, bbcode)

	## 170：道具说明分块
	func set_item(full: Dictionary) -> void:
		item_mode = true
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
			return body.text
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
		if _for_view == view and not _panel.pinned:
			_begin_leave(null, Vector2.ZERO))     # 170：出视图（多半是往悬浮窗里去）先给宽限


## 直接显示一段文字（地图上的点）；[param extra] 是文字下面再放的一个控件（对手的棋盘），可为 null；
## [param terms] 是关键词的词条（`{id: {"name", "text"}}`，或老的 `[{name, text}]`），钉住后停在关键词上开子窗
func show_text(bbcode: String, at: Vector2, extra: Control = null, terms = {}) -> void:
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


## 170：显示一件道具的分块说明（[method ItemTooltip.describe_full] 的结果）
func show_item(full: Dictionary, at: Vector2) -> void:
	_close_from(1)
	_panel.reset_state()
	_drop_extra()
	_panel.set_item(full)
	_panel.terms = _terms_dict(full.get("terms", {}))
	_open_main(at)


func _open_main(at: Vector2) -> void:
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
	_panel.reset_size()
	if _panel.pinned:
		_panel.position = at
	else:
		_place(_last_at)


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
		if _panel.global_rect().has_point(mouse):
			_panel.leave_t = -1.0
			_panel.dwell += delta
			if _panel.dwell >= PIN_SEC:
				pin(_panel)
		else:
			_panel.dwell = 0.0
			if _panel.leave_t >= 0.0:
				_panel.leave_t += delta
				if _panel.leave_t >= GRACE_SEC:
					_panel.leave_t = -1.0
					_resolve_pending()
		_panel.queue_redraw()
		return
	var open := windows()
	var inside := false
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
			if w.global_rect().has_point(mouse):
				w.leave_t = -1.0
				w.dwell += delta
				if w.dwell >= PIN_SEC:
					pin(w)
			else:
				w.dwell = 0.0
				if open[i - 1].hover_term == w.origin_term:
					w.leave_t = -1.0     # 还停在开它的那个词上
				else:
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
			extra[String(parent.terms[k]["name"])] = {"id": k, "text": parent.terms[k]["text"]}
	var found := Glossary.terms_in(String(entry["text"]), extra).filter(func(f): return String(f["id"]) != id and String(f["name"]) != String(entry["name"]))
	w.terms = {}
	for k in parent.terms:
		w.terms[k] = parent.terms[k]
	for f in found:
		w.terms[String(f["id"])] = {"name": f["name"], "text": f["text"]}
	w.set_text("%s\n[color=@tip_fg]%s[/color]" % [UiTheme.outline("[b][color=@term]%s[/color][/b]" % String(entry["name"])), Glossary.mark(String(entry["text"]), found)])     # 170 定稿：只有名字描边
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
	if mm == null or _panel.pinned:
		return
	var uid := _uid_under(view, mm.position)
	var inst := _shown_item(view, uid)
	if not _panel.visible:
		if inst != null:
			_show_for(view, uid, inst, mm.position)
		return
	if inst != null and view == _for_view and uid == _uid:
		_panel.leave_t = -1.0
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
	_pending_view = view
	_pending_local = local
	if _panel.leave_t < 0.0:
		_panel.leave_t = 0.0


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

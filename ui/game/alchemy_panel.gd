## 354：后勤「炼金」页（[Alchemy]）。作者 2026-11-21 选 C 炼成阵、尘图标 A（UI设计，`assets/ui/alchemy/layout.json`）：
## 顶上一块小木牌写现有的尘；地上一个炼成阵，三角的三个角各放一件勾了的素材（多于三件轮流叠到三个角上，角下 ×n）；
## 阵心是要得的尘（叠在光晕上，没勾时不画）；下面一张纸条：「→ 尘 +N」、「卖掉 金币 N · 折损 N%」、【全选】【炼化】（两步确认）。
## 右边仓库进勾选模式，只勾得上能炼的素材（[method rule]）。不垫粗布，墙透出来；版面按中列宽等比缩（同苗圃页）
extends VBoxContainer

signal changed()
## 有话要说（炼了多少；不能炼的原因）
signal said(text: String, warn: bool)

const ART := "alchemy/"
const CONFIRM_SEC := 2.0
## 版面（layout.json，中列宽 392）
const W := 392.0
const TOP_Y := 24.0
const CIRCLE := 340.0
const CIRCLE_CY := 330.0
const RADIUS := 136.0
const ANGLES: Array[float] = [-90.0, 30.0, 150.0]
const NODE := 76.0
const ITEM := 60.0
const PEEK := 6.0
const GLOW := 128.0
const CENTER_DUST := 70.0
const SLIP_Y := 590.0
const SLIP_H := 232.0
const H := SLIP_Y + SLIP_H + 20.0
const LIGHT := Color("f1e3c2")
const LOSS_RED := Color("9a2f22")

var flow: GameFlow = null
var shelf: WarehousePages = null
var go_btn: Button = null
var all_btn: Button = null
var confirm_left := 0.0
var _frame: Control = null
var _stage: Control = null
var _have: Label = null
var _nodes: Array[Control] = []
var _center: Control = null
var _gain: Label = null
var _funds: CoinLabel = null
var _loss: Label = null


func setup(p_flow: GameFlow, p_shelf: WarehousePages) -> void:
	flow = p_flow
	shelf = p_shelf
	name = "AlchemyPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_frame = Control.new()
	_frame.name = "StageFrame"
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.custom_minimum_size = Vector2(0, H)
	scroll.add_child(_frame)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = Vector2(W, H)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.set_tone(_stage, UiTheme.TONE_DARK)
	_frame.add_child(_stage)
	_frame.resized.connect(_fit)
	_build()
	shelf.selection_changed.connect(refresh)
	shelf.filter_changed.connect(refresh)
	visibility_changed.connect(_reset_confirm)
	refresh()


## 版面按中列宽等比缩（最大 1 倍），横向居中
func _fit() -> void:
	var k := clampf(_frame.size.x / W, 0.3, 1.0) if _frame.size.x > 0.0 else 1.0
	_stage.scale = Vector2(k, k)
	_stage.position = Vector2((_frame.size.x - W * k) * 0.5, 0.0)
	_frame.custom_minimum_size.y = H * k


func _build() -> void:
	var plaque := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 18, 6, 18, 6)     # 顶上一小块：现有的尘
	plaque.name = "Have"
	UiTheme.set_tone(plaque, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	var head := UiTheme.hbox(8)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(dust_icon(42.0))
	_have = UiTheme.make_label("", 30, UiTheme.INK)
	_have.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	head.add_child(_have)
	plaque.add_child(head)
	plaque.tooltip_text = UiText.t("alchemy.dust")
	plaque.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.add_child(plaque)
	plaque.resized.connect(func(): plaque.position = Vector2((W - plaque.size.x) * 0.5, TOP_Y))
	var c := Vector2(W * 0.5, CIRCLE_CY)
	_stage.add_child(_pic("circle", Rect2(c - Vector2(CIRCLE, CIRCLE) * 0.5, Vector2(CIRCLE, CIRCLE))))
	for a in ANGLES:
		var at := c + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * RADIUS
		var n := Control.new()
		n.name = "Node%d" % _nodes.size()
		n.position = at - Vector2(NODE, NODE) * 0.5
		n.size = Vector2(NODE, NODE)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(_pic("node", Rect2(Vector2.ZERO, Vector2(NODE, NODE))))
		_stage.add_child(n)
		_nodes.append(n)
	_center = Control.new()
	_center.name = "Center"
	_center.position = c - Vector2(GLOW, GLOW) * 0.5
	_center.size = Vector2(GLOW, GLOW)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_pic("center_glow", Rect2(Vector2.ZERO, Vector2(GLOW, GLOW))))
	var cd := dust_icon(CENTER_DUST)
	cd.position = Vector2(GLOW - CENTER_DUST, GLOW - CENTER_DUST) * 0.5
	cd.size = Vector2(CENTER_DUST, CENTER_DUST)
	_center.add_child(cd)
	_stage.add_child(_center)
	var slip := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 20, 16, 20, 16)     # 纸条
	slip.name = "Slip"
	UiTheme.set_tone(slip, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	slip.position = Vector2(20, SLIP_Y)
	slip.size = Vector2(W - 40.0, SLIP_H)
	_stage.add_child(slip)
	var col := UiTheme.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	slip.add_child(col)
	var gain := UiTheme.hbox(8)
	gain.name = "Gain"
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	gain.add_child(UiTheme.make_label("→", 28, UiTheme.INK_SOFT))
	gain.add_child(dust_icon(44.0))
	_gain = UiTheme.make_label("", 32, UiTheme.INK)
	_gain.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	gain.add_child(_gain)
	col.add_child(gain)
	var line2 := UiTheme.hbox(6)
	line2.alignment = BoxContainer.ALIGNMENT_CENTER
	line2.add_child(UiTheme.make_label(UiText.t("alchemy.or_sell"), 18, UiTheme.INK_SOFT))
	_funds = CoinLabel.make(0, UiTheme.sz(18), UiTheme.INK_SOFT)
	_funds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line2.add_child(_funds)
	line2.add_child(UiTheme.make_label("·", 18, UiTheme.INK_SOFT))
	_loss = UiTheme.make_label("", 18, LOSS_RED)
	_loss.name = "Loss"
	_loss.mouse_filter = Control.MOUSE_FILTER_PASS
	line2.add_child(_loss)
	col.add_child(line2)
	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	all_btn = UiTheme.make_home_button(UiText.t("sell.select_all"), toggle_all, false, Vector2(120, 48), 18)
	all_btn.name = "AlchemyAll"
	row.add_child(all_btn)
	go_btn = UiTheme.make_home_button(UiText.t("alchemy.go"), press_go, true, Vector2(140, 52), 20)
	go_btn.name = "AlchemyGo"
	row.add_child(go_btn)
	col.add_child(row)


static func dust_icon(side: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.art(ART + "dust")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(side, side)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.tooltip_text = UiText.t("alchemy.dust")
	return r


func _pic(file: String, rect: Rect2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.art(ART + file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = rect.position
	r.size = rect.size
	return r


## 勾选模式里能勾哪件（[method WarehousePages.set_select_mode] 的规矩）
static func rule() -> Callable:
	return func(it: ItemInstance) -> bool: return Alchemy.can_dissolve(it)


func toggle_all() -> void:
	if shelf.all_matching_selected():
		shelf.deselect_matching()
	else:
		shelf.select_matching()


## 【炼化】：第一下变「再点一次」，再点才炼。返回 {"count", "dust"}（只点了第一下 = 空）
func press_go() -> Dictionary:
	if shelf.selected.is_empty():
		return {}
	if confirm_left <= 0.0:
		confirm_left = CONFIRM_SEC
		go_btn.text = UiText.t("act.confirm")
		return {}
	_reset_confirm()
	var got := flow.dissolve_items(shelf.selected.keys())
	shelf.clear_selection()
	if int(got["count"]) > 0:
		said.emit(UiText.t("alchemy.done") % [int(got["count"]), int(got["dust"])], false)
	refresh()
	changed.emit()
	return got


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if confirm_left <= 0.0:
		return
	confirm_left -= delta
	if confirm_left <= 0.0:
		_reset_confirm()


func _reset_confirm() -> void:
	confirm_left = 0.0
	if go_btn != null:
		go_btn.text = UiText.t("alchemy.go")


func preview() -> Dictionary:
	return flow.alchemy_preview(shelf.selected.keys())


## 勾了的几件按勾的先后轮流分到三个角：角号 → [ItemInstance]（后勾的在后）
func corners() -> Array:
	var out: Array = [[], [], []]
	var k := 0
	for uid in shelf.selected:
		var it := flow.meta.warehouse.get_item(int(uid))
		if it == null:
			continue
		(out[k % 3] as Array).append(it)
		k += 1
	return out


func refresh() -> void:
	if flow == null or flow.meta == null or _have == null:
		return
	_have.text = str(flow.meta.dust)
	var groups := corners()
	for i in _nodes.size():
		_fill_node(_nodes[i], groups[i] as Array)
	var p := preview()
	_center.visible = int(p["count"]) > 0
	_gain.text = "+%d" % int(p["dust"])
	_funds.amount = int(p["funds"])
	_loss.text = UiText.t("alchemy.loss") % roundi(Alchemy.loss(flow.meta) * 100.0)
	_loss.tooltip_text = UiText.t("alchemy.loss_tip")
	all_btn.text = UiText.t("sell.select_none" if shelf.all_matching_selected() else "sell.select_all")
	go_btn.disabled = shelf.selected.is_empty()
	if go_btn.disabled:
		_reset_confirm()


## 一个角：最新的一件在最上，前面的往左上各错 [constant PEEK]（最多画三件）；两件以上角下写 ×n
func _fill_node(n: Control, items: Array) -> void:
	for c in n.get_children().slice(1):
		n.remove_child(c)
		c.queue_free()
	var shown := items.slice(maxi(0, items.size() - 3))
	for j in shown.size():
		var it := shown[j] as ItemInstance
		var back := shown.size() - 1 - j
		var r := TextureRect.new()
		r.texture = ShelfView.item_art(it.def)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.position = Vector2(NODE - ITEM, NODE - ITEM) * 0.5 - Vector2(PEEK, PEEK) * back
		r.size = Vector2(ITEM, ITEM)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = "%s · %d" % [Names.of(it.def), Alchemy.dust_value(it.def)]
		if back > 0:
			r.modulate = Color(0.8, 0.8, 0.8)
		n.add_child(r)
	if items.size() >= 2:
		var l := UiTheme.make_label("×%d" % items.size(), 16, LIGHT)
		l.name = "Count"
		l.set_meta(&"exempt_bare_text", true)     # 写在墙上的小字（版面如此）
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, NODE + 2.0)
		l.size = Vector2(NODE, 20)
		n.add_child(l)

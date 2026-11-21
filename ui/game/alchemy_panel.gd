## 354：后勤「炼金」页（[Alchemy]）—— 占位版，等 UI设计 出样张再换。
## 右边仓库进勾选模式（只勾得上能炼的素材，别的压灰）；这一页写：现有的尘、勾了的几件（小图）、会得多少尘、卖掉能得多少金币、折损；
## 【全选】【炼化】（两步：第一下「再点一次」，[constant CONFIRM_SEC] 秒不点回弹）
extends VBoxContainer

signal changed()
## 有话要说（炼了多少；不能炼的原因）
signal said(text: String, warn: bool)

const CONFIRM_SEC := 2.0
const DUST_ART := "alchemy/dust"
const ICON := 40.0
const SMALL := 34.0

var flow: GameFlow = null
var shelf: WarehousePages = null
var go_btn: Button = null
var all_btn: Button = null
var confirm_left := 0.0
var _have: Label = null
var _picked: HFlowContainer = null
var _gain: Label = null
var _funds: CoinLabel = null
var _loss: Label = null


func setup(p_flow: GameFlow, p_shelf: WarehousePages) -> void:
	flow = p_flow
	shelf = p_shelf
	name = "AlchemyPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paper := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 30, 24, 30, 24)     # 占位：一张羊皮纸，等样张
	paper.name = "AlchemyPaper"
	UiTheme.set_tone(paper, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	add_child(paper)
	var col := UiTheme.vbox(18)
	paper.add_child(col)
	var head := UiTheme.hbox(10)     # 现有的尘
	head.name = "Have"
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(dust_icon(56.0))
	_have = UiTheme.make_label("", 34, UiTheme.INK)
	_have.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	head.add_child(_have)
	head.tooltip_text = UiText.t("alchemy.dust")
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(head)
	_picked = HFlowContainer.new()     # 炼金锅（占位）：勾了的几件
	_picked.name = "Picked"
	_picked.custom_minimum_size = Vector2(0, 90)
	col.add_child(_picked)
	var gain := UiTheme.hbox(8)     # → 尘 +N · 卖掉 金币 N
	gain.name = "Gain"
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	gain.add_child(UiTheme.make_label("→", 24, UiTheme.INK_SOFT))
	gain.add_child(dust_icon(ICON))
	_gain = UiTheme.make_label("", 26, UiTheme.INK)
	gain.add_child(_gain)
	var sep := UiTheme.make_label(UiText.t("alchemy.or_sell"), 16, UiTheme.INK_SOFT)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gain.add_child(sep)
	_funds = CoinLabel.make(0, UiTheme.sz(16), UiTheme.INK_SOFT)
	_funds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gain.add_child(_funds)
	col.add_child(gain)
	_loss = UiTheme.make_label("", 16, UiTheme.INK_SOFT)
	_loss.name = "Loss"
	_loss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loss.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_loss)
	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	all_btn = UiTheme.make_home_button(UiText.t("sell.select_all"), toggle_all, false, Vector2(120, 48), 18)
	all_btn.name = "AlchemyAll"
	row.add_child(all_btn)
	go_btn = UiTheme.make_home_button(UiText.t("alchemy.go"), press_go, true, Vector2(140, 52), 20)
	go_btn.name = "AlchemyGo"
	row.add_child(go_btn)
	col.add_child(row)
	shelf.selection_changed.connect(refresh)
	shelf.filter_changed.connect(refresh)
	visibility_changed.connect(_reset_confirm)
	refresh()


static func dust_icon(side: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTheme.art(DUST_ART)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(side, side)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.tooltip_text = UiText.t("alchemy.dust")
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


func refresh() -> void:
	if flow == null or flow.meta == null or _have == null:
		return
	_have.text = str(flow.meta.dust)
	for c in _picked.get_children():
		_picked.remove_child(c)
		c.queue_free()
	for uid in shelf.selected:
		var it := flow.meta.warehouse.get_item(int(uid))
		if it == null:
			continue
		var r := TextureRect.new()
		r.texture = ShelfView.item_art(it.def)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(SMALL, SMALL)
		r.tooltip_text = "%s · %d" % [Names.of(it.def), Alchemy.dust_value(it.def)]
		_picked.add_child(r)
	var p := preview()
	_gain.text = "+%d" % int(p["dust"])
	_funds.amount = int(p["funds"])
	var pct := roundi(Alchemy.loss(flow.meta) * 100.0)
	_loss.text = UiText.t("alchemy.loss") % pct
	_loss.tooltip_text = UiText.t("alchemy.loss_tip")
	all_btn.text = UiText.t("sell.select_none" if shelf.all_matching_selected() else "sell.select_all")
	go_btn.disabled = shelf.selected.is_empty()
	if go_btn.disabled:
		_reset_confirm()

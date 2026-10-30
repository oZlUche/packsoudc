## 268 补充一（作者 2026-10-30 15:27 / 15:28）：仓库页「快速出售」模式的「出售单」木牌 —— 大木牌 [constant UiTheme.PANEL_HOME_PLAQUE]（浅底墨字）+ 挂牌标题。
## 第一行 标签下拉 + 稀有度下拉（筛选牌那一对的独立一份：只管【全选】选哪些、右边仓库哪些压灰）；
## 第二行【全选 / 全不选】+「已选 N 件 · 金币 N」，下面合筛选却不卖的（锁定 / 收藏）件数小字；第三行【出售】（两步：第一下「再点一次」，[constant CONFIRM_SEC] 秒不点回弹）+【取消】。
## 勾选本身在 [WarehousePages]（单击格子）；开 / 关模式由 [MetaScreen] 管（[method open] / [method close]）
class_name SellSheet
extends VBoxContainer

## 点了【取消】
signal cancelled

const WIDTH := 560.0
const MIN_WIDTH := 300.0
const HEIGHT := 300.0
const FONT := 16
const SMALL_FONT := 14
const ALL_SIZE := Vector2(120, 44)
const SELL_SIZE := Vector2(200, 60)
const CANCEL_SIZE := Vector2(140, 60)
const CONFIRM_SEC := 2.0
## 挂牌：木牌左边往里 18、高出木牌 34（同出征页的木牌）
const TAG_X := 18
const TAG_RISE := 34.0

var flow: GameFlow = null
var shelf: WarehousePages = null
var plate: PanelContainer = null
var tag_pick: OptionButton = null
var rarity_pick: OptionButton = null
var all_btn: Button = null
var sell_btn: Button = null
var cancel_btn: Button = null
var _picked: Label = null
var _coins: CoinLabel = null
var _skipped: Label = null
var _say: Callable = Callable()
## 开模式前筛选牌的筛选（关了还原）：[标签, 稀有度上限, 只看收藏]
var _saved_filter: Array = []
var _tag := &""
var _rarity := -1
var confirm_left := 0.0


func setup(p_flow: GameFlow, p_shelf: WarehousePages, say: Callable = Callable()) -> SellSheet:
	flow = p_flow
	shelf = p_shelf
	_say = say
	add_theme_constant_override("separation", -int(HeaderTag.HANG_HEIGHT - TAG_RISE))
	var hold := MarginContainer.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold.add_theme_constant_override("margin_left", TAG_X)
	hold.z_index = 1     # 挂牌压在木牌框上
	hold.add_child(HeaderTag.hanging(UiText.t("sell.sheet_title")))
	add_child(hold)
	plate = UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_PLAQUE)
	plate.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	add_child(plate)
	var col := UiTheme.vbox(12)
	plate.add_child(col)
	var row1 := HFlowContainer.new()     # 窄屏放不下一行就折
	row1.add_theme_constant_override("h_separation", 10)
	row1.add_theme_constant_override("v_separation", 8)
	col.add_child(row1)
	tag_pick = OptionButton.new()
	tag_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_pick.item_selected.connect(func(i: int): set_filter(StringName(String(tag_pick.get_item_metadata(i))), _rarity))
	UiTheme.dress_wood_option(tag_pick, FONT)
	row1.add_child(tag_pick)
	rarity_pick = OptionButton.new()
	rarity_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in WarehouseTools.RARITIES.size():
		rarity_pick.add_item(UiText.t(String(WarehouseTools.RARITIES[i][0])), i)
	rarity_pick.item_selected.connect(func(i: int): set_filter(_tag, int(WarehouseTools.RARITIES[i][1])))
	UiTheme.dress_wood_option(rarity_pick, FONT)
	row1.add_child(rarity_pick)
	var row2 := UiTheme.hbox(12)     # 【全选】紧挨着筛选（下拉名字长，和两个下拉挤一行要截字），右边写已选几件
	col.add_child(row2)
	all_btn = UiTheme.make_home_button(UiText.t("sell.select_all"), toggle_all, false, ALL_SIZE, FONT)
	row2.add_child(all_btn)
	_picked = UiTheme.make_label("", FONT + 2, UiTheme.INK)
	_picked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(_picked)
	_coins = CoinLabel.make(0, UiTheme.sz(FONT + 2), UiTheme.INK)
	_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(_coins)
	_skipped = UiTheme.make_label("", SMALL_FONT, UiTheme.INK_SOFT)
	col.add_child(_skipped)
	var spring := Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spring)
	var row3 := UiTheme.hbox(10)
	row3.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row3)
	sell_btn = UiTheme.make_home_button(UiText.t("sell.go"), press_sell, true, SELL_SIZE, FONT + 2)
	row3.add_child(sell_btn)
	cancel_btn = UiTheme.make_home_button(UiText.t("sell.cancel"), func(): cancelled.emit(), false, CANCEL_SIZE, FONT + 2)
	row3.add_child(cancel_btn)
	shelf.selection_changed.connect(refresh)
	flow.meta.warehouse.changed.connect(_rebuild_tags)
	return self


## 木牌宽（窄屏缩，不小于 [constant MIN_WIDTH]）
func fit_width(w: float) -> void:
	plate.custom_minimum_size.x = clampf(w, MIN_WIDTH, WIDTH)


## 进模式：记下筛选牌的筛选，换成出售单的（默认 不限 / 全部），仓库进勾选模式
func open() -> void:
	_saved_filter = [shelf.filter_tag, shelf.filter_rarity, shelf.filter_fav]
	_tag = &""
	_rarity = -1
	_reset_confirm()
	shelf.set_select_mode(true)
	_rebuild_tags()
	set_filter(&"", -1)


## 退模式：勾选全清、筛选牌的筛选还原
func close() -> void:
	_reset_confirm()
	shelf.set_select_mode(false)
	if _saved_filter.size() == 3:
		var tag: StringName = _saved_filter[0]
		shelf.set_filter(tag if tag == &"" or flow.meta.sell_tags().has(tag) else &"", int(_saved_filter[1]), bool(_saved_filter[2]))
	_saved_filter = []


func set_filter(tag: StringName, rarity_max: int) -> void:
	_tag = tag if tag == &"" or flow.meta.sell_tags().has(tag) else &""
	_rarity = rarity_max
	shelf.set_filter(_tag, _rarity, false)
	_sync_picks()
	refresh()


## 【全选】：合筛选、能卖的全勾；都勾了再点 = 全不选（都只动合筛选的，筛选外已勾的留着）
func toggle_all() -> void:
	if shelf.all_matching_selected():
		shelf.deselect_matching()
	else:
		shelf.select_matching()


## 【出售】：第一下变「再点一次」，[constant CONFIRM_SEC] 秒里再点才卖。返回卖了的 {"count", "funds"}（只点了第一下 = 空）
func press_sell() -> Dictionary:
	if shelf.selected.is_empty():
		return {}
	if confirm_left <= 0.0:
		confirm_left = CONFIRM_SEC
		sell_btn.text = UiText.t("act.confirm")
		return {}
	_reset_confirm()
	var got := flow.sell_selected(shelf.selected.keys())
	shelf.clear_selection()
	if _say.is_valid():
		_say.call(UiText.t("meta.sold_many") % [int(got["count"]), int(got["funds"]), flow.meta.funds])
	return got


## 正等着第二下
func confirming() -> bool:
	return confirm_left > 0.0


func _process(delta: float) -> void:
	tick(delta)


## 两步确认的倒计时（测试直接喂时间）
func tick(delta: float) -> void:
	if confirm_left <= 0.0:
		return
	confirm_left -= delta
	if confirm_left <= 0.0:
		_reset_confirm()


func _reset_confirm() -> void:
	confirm_left = 0.0
	if sell_btn != null:
		sell_btn.text = UiText.t("sell.go")


## 「已选 N 件 · 金币 N」、跳过小字、【全选 / 全不选】、【出售】亮灭
func refresh() -> void:
	if shelf == null or _picked == null:
		return
	var n := shelf.selected.size()
	_picked.text = UiText.t("sell.picked") % n
	_coins.amount = shelf.selected_value(flow.sell_ratio())
	var skip: Array = shelf.skipped_matching()
	var note := ""
	if int(skip[0]) > 0:
		note += UiText.t("meta.sell_skipped") % int(skip[0])
	if int(skip[1]) > 0:
		note += UiText.tn("meta.sell_skip_fav", int(skip[1])) % int(skip[1])
	_skipped.text = note.strip_edges()
	_skipped.visible = note != ""
	all_btn.text = UiText.t("sell.select_none" if shelf.all_matching_selected() else "sell.select_all")
	sell_btn.disabled = n == 0
	if n == 0:
		_reset_confirm()


## 「已选 N 件 ·」那行字（测试看）
func summary_text() -> String:
	return _picked.text


func coin_amount() -> int:
	return _coins.amount


func skipped_text() -> String:
	return _skipped.text if _skipped.visible else ""


## 标签下拉：仓库里有的标签按大类分组（同筛选牌）
func _rebuild_tags() -> void:
	if tag_pick == null:
		return
	tag_pick.clear()
	tag_pick.add_item(UiText.t("meta.sell_any_tag"))
	tag_pick.set_item_metadata(0, "")
	var last_rank := -1
	for t in flow.meta.sell_tags():
		var rank := TagRegistry.category_rank(t)
		if last_rank >= 0 and rank != last_rank:
			tag_pick.add_separator()
		last_rank = rank
		tag_pick.add_item(Glossary.tag_name(t))
		tag_pick.set_item_metadata(tag_pick.item_count - 1, String(t))
	if _tag != &"" and not flow.meta.sell_tags().has(_tag) and shelf.select_mode:
		set_filter(&"", _rarity)
		return
	_sync_picks()


func _sync_picks() -> void:
	for i in tag_pick.item_count:
		if not tag_pick.is_item_separator(i) and String(tag_pick.get_item_metadata(i)) == String(_tag):
			tag_pick.select(i)
	for i in WarehouseTools.RARITIES.size():
		if int(WarehouseTools.RARITIES[i][1]) == _rarity:
			rarity_pick.select(i)

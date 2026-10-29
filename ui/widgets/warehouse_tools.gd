## 264 §六（作者 16:43「按推荐来」= A 工具列）：基地「仓库」页包架下面两块牌 —— 筛选牌（标签下拉 + 稀有度下拉 + 「清除」小键，
## 右边仓库不匹配的格压灰、页签计数改匹配数，[method WarehousePages.set_filter]）与账牌（件数 / 总价值（金币）/ 空格）。
## 木牌定稿（UI替换美术 plaque264）：小木牌 [constant UiTheme.PANEL_HOME_PLAQUE_SMALL]（橡木框 + 羊皮面，浅底墨字）
class_name WarehouseTools
extends VBoxContainer

const WIDTH := 228.0
const FILTER_H := 150.0
const LEDGER_H := 120.0
const FONT := 16
const CLEAR_SIZE := Vector2(96, 36)
## 稀有度下拉：[文本键, 稀有度上限]，第一项「全部」（出售页那几档反过来摆）
const RARITIES := [["meta.all", -1], ["meta.sell_white", 0], ["meta.sell_green", 1], ["meta.sell_blue", 2], ["meta.sell_purple", 3], ["meta.sell_gold", 4]]

var meta: MetaState = null
var shelf: WarehousePages = null
var tag_pick: OptionButton = null
var rarity_pick: OptionButton = null
var clear_btn: Button = null
var filter_plate: PanelContainer = null
var ledger_plate: PanelContainer = null
var _items: Label = null
var _worth: CoinLabel = null
var _free: Label = null


func setup(p_meta: MetaState, p_shelf: WarehousePages) -> WarehouseTools:
	meta = p_meta
	shelf = p_shelf
	add_theme_constant_override("separation", 20)
	filter_plate = _plate(FILTER_H)
	var fcol := _col(filter_plate)
	fcol.add_child(HeaderTag.new(UiText.t("meta.filter")))
	tag_pick = OptionButton.new()
	tag_pick.item_selected.connect(func(i: int): set_filter(StringName(String(tag_pick.get_item_metadata(i))), shelf.filter_rarity))
	UiTheme.dress_wood_option(tag_pick, FONT)
	fcol.add_child(tag_pick)
	rarity_pick = OptionButton.new()
	for i in RARITIES.size():
		rarity_pick.add_item(UiText.t(String(RARITIES[i][0])), i)
	rarity_pick.item_selected.connect(func(i: int): set_filter(shelf.filter_tag, int(RARITIES[i][1])))
	UiTheme.dress_wood_option(rarity_pick, FONT)
	fcol.add_child(rarity_pick)
	clear_btn = UiTheme.make_home_button(UiText.t("meta.filter_clear"), clear, false, CLEAR_SIZE, FONT)
	clear_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	fcol.add_child(clear_btn)
	ledger_plate = _plate(LEDGER_H)
	var lcol := _col(ledger_plate)
	lcol.add_child(HeaderTag.new(UiText.t("meta.ledger")))
	_items = UiTheme.make_label("", FONT, UiTheme.INK)
	lcol.add_child(_items)
	var worth_row := UiTheme.hbox(8)
	lcol.add_child(worth_row)
	worth_row.add_child(UiTheme.make_label(UiText.t("meta.ledger_worth"), FONT, UiTheme.INK))
	_worth = CoinLabel.make(0, UiTheme.sz(FONT), UiTheme.INK)
	worth_row.add_child(_worth)
	_free = UiTheme.make_label("", FONT, UiTheme.INK)
	lcol.add_child(_free)
	meta.warehouse.changed.connect(refresh)
	meta.changed.connect(refresh)
	refresh()
	return self


## 一块小木牌（内边距是九宫格的框宽）；返回牌，[method _col] 取里面那一列
func _plate(h: float) -> PanelContainer:
	var p := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_PLAQUE_SMALL)
	p.custom_minimum_size = Vector2(WIDTH, h)
	add_child(p)
	p.add_child(UiTheme.vbox(6))
	return p


static func _col(p: PanelContainer) -> VBoxContainer:
	return p.get_child(0)


## 设筛选（标签已经不在仓库里了就回「不限」）
func set_filter(tag: StringName, rarity_max: int) -> void:
	if tag != &"" and not meta.sell_tags().has(tag):
		tag = &""
	shelf.set_filter(tag, rarity_max)
	_sync_picks()
	_refresh_clear()


func clear() -> void:
	set_filter(&"", -1)


## 仓库变了：标签下拉重建（按大类分组，组间一条分隔，同出售页）、账牌重算
func refresh() -> void:
	if meta == null:
		return
	var tags := meta.sell_tags()
	if shelf.filter_tag != &"" and not tags.has(shelf.filter_tag):
		shelf.set_filter(&"", shelf.filter_rarity)
	tag_pick.clear()
	tag_pick.add_item(UiText.t("meta.sell_any_tag"))
	tag_pick.set_item_metadata(0, "")
	var last_rank := -1
	for t in tags:
		var rank := TagRegistry.category_rank(t)
		if last_rank >= 0 and rank != last_rank:
			tag_pick.add_separator()
		last_rank = rank
		tag_pick.add_item(Glossary.tag_name(t))
		tag_pick.set_item_metadata(tag_pick.item_count - 1, String(t))
	_sync_picks()
	_refresh_clear()
	_items.text = UiText.t("meta.ledger_items") % item_count()
	_worth.amount = meta.warehouse_value()
	_free.text = UiText.t("meta.ledger_free") % free_cells()


func _sync_picks() -> void:
	for i in tag_pick.item_count:
		if not tag_pick.is_item_separator(i) and String(tag_pick.get_item_metadata(i)) == String(shelf.filter_tag):
			tag_pick.select(i)
	for i in RARITIES.size():
		if int(RARITIES[i][1]) == shelf.filter_rarity:
			rarity_pick.select(i)


func _refresh_clear() -> void:
	clear_btn.disabled = not shelf.filtering()


## 账牌三数：仓库件数、总价值（仓库 + 包架上的包，[method MetaState.warehouse_value]）、各页空格合计
func item_count() -> int:
	return meta.warehouse.item_count()


func worth() -> int:
	return meta.warehouse_value()


func free_cells() -> int:
	var n := 0
	for i in meta.warehouse.page_count():
		n += meta.warehouse.page(i).free_cell_count()
	return n


## 测试看：账牌上三行写的字（件数行、总价值的数、空格行）
func ledger_lines() -> Array:
	return [_items.text, _worth.amount, _free.text]

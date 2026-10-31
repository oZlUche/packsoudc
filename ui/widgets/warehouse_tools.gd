## 264 §六（作者 16:43「按推荐来」= A 工具列）：基地「仓库」页包架下面两块牌 —— 筛选牌（标签下拉 + 稀有度下拉 + 「清除」小键，
## 右边仓库不匹配的格压灰、页签计数改匹配数，[method WarehousePages.set_filter]）。作者 10-31：账牌不要了（「仓库不需要账目栏」）。
## 木牌定稿（UI替换美术 plaque264）：小木牌 [constant UiTheme.PANEL_HOME_PLAQUE_SMALL]（橡木框 + 羊皮面，浅底墨字）
## 268（作者 10-30 15:23 定 C；补充一 15:27）：出售页删了 —— 筛选牌下面一颗【快速出售】主档木牌键（按下态 = 出售模式开着：
## 键下面露出「出售条」[SellStrip]、右边仓库单击勾选；开关由 [MetaScreen] 接 [signal sell_mode_toggled]）。
## 268 补充二（作者 10-31 11:25）：快速出售只改右边仓库的勾选状态 —— 模式里筛选牌照常可用，就是出售的筛选（压灰与【全选】的范围跟着它）
class_name WarehouseTools
extends VBoxContainer

## 268：【快速出售】按下 / 抬起
signal sell_mode_toggled(on: bool)

const WIDTH := 228.0
const FILTER_H := 150.0
const FONT := 16
const CLEAR_SIZE := Vector2(96, 36)
## 268：【快速出售】
const QUICK_SIZE := Vector2(228, 56)
const QUICK_FONT := 18
## 稀有度下拉：[文本键, 稀有度上限]，第一项「全部」（出售页那几档反过来摆）
const RARITIES := [["meta.all", -1], ["meta.sell_white", 0], ["meta.sell_green", 1], ["meta.sell_blue", 2], ["meta.sell_purple", 3], ["meta.sell_gold", 4]]

var flow: GameFlow = null
var meta: MetaState = null
var shelf: WarehousePages = null
var tag_pick: OptionButton = null
var rarity_pick: OptionButton = null
var clear_btn: Button = null
## 265：「只看收藏」（按下 = 只看）
var fav_btn: Button = null
var filter_plate: PanelContainer = null
## 268：快速出售（按下态 = 出售模式开着）
var quick_btn: Button = null


func setup(p_flow: GameFlow, p_shelf: WarehousePages) -> WarehouseTools:
	flow = p_flow
	meta = p_flow.meta
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
	var keys := UiTheme.hbox(8)
	fcol.add_child(keys)
	fav_btn = UiTheme.make_home_button(UiText.t("meta.filter_fav"), func(): set_filter(shelf.filter_tag, shelf.filter_rarity, fav_btn.button_pressed), false, Vector2(0, CLEAR_SIZE.y), FONT)
	fav_btn.toggle_mode = true
	fav_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.add_child(fav_btn)
	clear_btn = UiTheme.make_home_button(UiText.t("meta.filter_clear"), clear, false, CLEAR_SIZE, FONT)
	clear_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	keys.add_child(clear_btn)
	quick_btn = UiTheme.make_home_button(UiText.t("wh.quick_sell"), func(): sell_mode_toggled.emit(quick_btn.button_pressed), true, QUICK_SIZE, QUICK_FONT)
	quick_btn.toggle_mode = true
	quick_btn.tooltip_text = UiText.t("wh.quick_sell_tip")
	add_child(quick_btn)
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
func set_filter(tag: StringName, rarity_max: int, fav_only: bool = shelf.filter_fav if shelf != null else false) -> void:
	if tag != &"" and not meta.sell_tags().has(tag):
		tag = &""
	shelf.set_filter(tag, rarity_max, fav_only)
	_sync_picks()
	_refresh_clear()


func clear() -> void:
	set_filter(&"", -1, false)


## 仓库变了：标签下拉重建（按大类分组，组间一条分隔，同出售页）
func refresh() -> void:
	if meta == null:
		return
	var tags := meta.sell_tags()
	if shelf.filter_tag != &"" and not tags.has(shelf.filter_tag):
		shelf.set_filter(&"", shelf.filter_rarity)
	elif shelf.filter_fav:
		shelf.set_filter(shelf.filter_tag, shelf.filter_rarity, true)     # 265：收藏变了，页签上的匹配数重算
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


func _sync_picks() -> void:
	for i in tag_pick.item_count:
		if not tag_pick.is_item_separator(i) and String(tag_pick.get_item_metadata(i)) == String(shelf.filter_tag):
			tag_pick.select(i)
	for i in RARITIES.size():
		if int(RARITIES[i][1]) == shelf.filter_rarity:
			rarity_pick.select(i)
	fav_btn.set_pressed_no_signal(shelf.filter_fav)


func _refresh_clear() -> void:
	clear_btn.disabled = not shelf.filtering()


## 268：出售模式开 / 关 —— 键的按下态跟着、出售条 [param strip] 挂在键下面露出来；筛选牌不动（补充二）
func set_sell_mode(on: bool, strip: Control = null) -> void:
	quick_btn.set_pressed_no_signal(on)
	if strip != null:
		if strip.get_parent() != self:
			add_child(strip)
		move_child(strip, quick_btn.get_index() + 1)
		strip.visible = on


## 标签下拉现在列的标签（不含「不限标签」，测试读）
func tag_options() -> Array:
	var out: Array = []
	for i in tag_pick.item_count:
		var tag := String(tag_pick.get_item_metadata(i)) if not tag_pick.is_item_separator(i) else ""
		if tag != "":
			out.append(StringName(tag))
	return out

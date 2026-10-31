## 268 补充二（作者 2026-10-31 11:25）：仓库页「快速出售」模式的「出售条」—— 【快速出售】键下面一块小木牌 [constant UiTheme.PANEL_HOME_PLAQUE_SMALL]（浅底墨字），模式里才露。
## 「已选 N 件 · 金币 N」，下面合筛选却不卖的（锁定 / 收藏）件数小字；【全选 / 全不选】；【出售】（两步：第一下「再点一次」，[constant CONFIRM_SEC] 秒不点回弹）+【取消】。
## 筛选不自存：用筛选牌当前的筛选（[member WarehousePages.filter_tag] / [member WarehousePages.filter_rarity] / [member WarehousePages.filter_fav]），
## 改了筛选 = 压灰与【全选】的范围跟着改，筛选外已勾的留着。勾选本身在 [WarehousePages]（单击格子）；开 / 关模式由 [MetaScreen] 管
class_name SellStrip
extends PanelContainer

## 点了【取消】
signal cancelled

const WIDTH := 228.0
const FONT := 16
const SMALL_FONT := 14
const ALL_H := 44.0
const SELL_H := 52.0
const CANCEL_W := 88.0
const CONFIRM_SEC := 2.0

var flow: GameFlow = null
var shelf: WarehousePages = null
var all_btn: Button = null
var sell_btn: Button = null
var cancel_btn: Button = null
var _picked: Label = null
var _coins: CoinLabel = null
var _skipped: Label = null
var _say: Callable = Callable()
var confirm_left := 0.0


func setup(p_flow: GameFlow, p_shelf: WarehousePages, say: Callable = Callable()) -> SellStrip:
	flow = p_flow
	shelf = p_shelf
	_say = say
	UiTheme.panel(self, -1, UiTheme.PANEL_HOME_PLAQUE_SMALL)
	custom_minimum_size.x = WIDTH
	var col := UiTheme.vbox(8)
	add_child(col)
	var row1 := HFlowContainer.new()     # 英文长了折一行
	row1.add_theme_constant_override("h_separation", 6)
	col.add_child(row1)
	_picked = UiTheme.make_label("", FONT, UiTheme.INK)
	_picked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(_picked)
	_coins = CoinLabel.make(0, UiTheme.sz(FONT), UiTheme.INK)
	_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(_coins)
	_skipped = UiTheme.make_label("", SMALL_FONT, UiTheme.INK_SOFT)
	_skipped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_skipped)
	all_btn = UiTheme.make_home_button(UiText.t("sell.select_all"), toggle_all, false, Vector2(0, ALL_H), FONT)
	col.add_child(all_btn)
	var row3 := UiTheme.hbox(8)
	col.add_child(row3)
	sell_btn = UiTheme.make_home_button(UiText.t("sell.go"), press_sell, true, Vector2(0, SELL_H), FONT + 2)
	sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(sell_btn)
	cancel_btn = UiTheme.make_home_button(UiText.t("sell.cancel"), func(): cancelled.emit(), false, Vector2(CANCEL_W, SELL_H), FONT)
	row3.add_child(cancel_btn)
	shelf.selection_changed.connect(refresh)
	shelf.filter_changed.connect(refresh)
	visibility_changed.connect(_reset_confirm)
	refresh()
	return self


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


func select_all_button() -> Button:
	return all_btn


func sell_button() -> Button:
	return sell_btn


func cancel_button() -> Button:
	return cancel_btn

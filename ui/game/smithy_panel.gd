## 251：基地「铁匠铺」页（[Smithy]）—— 一张配方一行：产物摆在一块素框的小格里（227），右边一块铭牌写要什么（每样「有几 / 要几」、要多少钱），
## 再右边「打造」（作者待定 3 推荐：点配方 → 看有无 → 按「打造」自动从仓库扣，不用拖）。这一级还不会打的配方灰着、写几级才会。
## 占位：美术设计出样（砧与炉台）后由 UI替换美术换
extends VBoxContainer

signal changed()

const SLOT_MIN := Vector2i(2, 2)
## 产物格子画多大（像素）
const CELL := 40

var flow: GameFlow = null
var font: Font = null
var say: Callable = Callable()
var _head: HeaderTag = null
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
## 配方 id → 那一行的「打造」键
var _buttons: Dictionary = {}
var _tip: HoverTip = null


func setup(p_flow: GameFlow, p_font: Font, p_say: Callable = Callable()) -> void:
	flow = p_flow
	font = p_font
	say = p_say
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_head = HeaderTag.new(UiText.t("smithy.title"))
	_head.mouse_filter = Control.MOUSE_FILTER_PASS
	_head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_head)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = UiTheme.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_tip = HoverTip.new()
	_tip.top_level = true
	add_child(_tip)
	flow.meta.changed.connect(rebuild)
	flow.meta.warehouse.changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	if _list == null:
		return
	UiTheme.clear_children(_list)
	_buttons.clear()
	var lv := Smithy.level(flow.meta)
	_head.text = UiText.t("smithy.title") if lv > 0 else UiText.t("smithy.locked")
	_head.tooltip_text = UiText.t("smithy.intro") if lv > 0 else UiText.t("smithy.locked_tip")
	_scroll.visible = lv > 0
	if lv <= 0:
		return
	var split := Smithy.recipes_for(flow.meta, flow.sorted_smith_recipes())
	for r in (split["ready"] as Array) + (split["locked"] as Array):
		_list.add_child(_row(r as SmithRecipeDef))


func _row(r: SmithRecipeDef) -> Control:
	var row := UiTheme.hbox(10)
	var def := flow.items.get_def(r.output)
	var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
	var grid := GridInventory.new(Vector2i(maxi(SLOT_MIN.x, size.x), maxi(SLOT_MIN.y, size.y)), 0, false)
	if def != null:
		grid.place(ItemInstance.create(def, 0), Vector2i.ZERO, 0)
	var view := InventoryView.new()
	view.label_font = font
	view.show_adjacency = false
	view.cell_px = CELL
	view.inventory = grid
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.item_double_clicked.connect(func(_v: ContainerView, _uid: int): forge(r.id))
	row.add_child(view)
	BoardFrame.wrap(view)     # 227：产物格也带框 + 格线
	_tip.watch(view)
	var plate := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_NAMEPLATE)     # 226：字落在铭牌上
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plate)
	plate.add_child(UiTheme.make_wrapped(line_of(r), UiTheme.FONT_SIZE, UiPalette.for_tone(UiPalette.FG, UiTheme.tone_of(UiTheme.PANEL_NAMEPLATE)), 260))
	var why := Smithy.can_forge(flow.meta, r, flow.items)
	var b := UiTheme.make_home_button(UiText.t("smithy.forge"), func(): forge(r.id))
	b.disabled = why != ""
	b.tooltip_text = why
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	_buttons[r.id] = b
	return row


## 一行铭牌上的字：「短剑　铁矿石 1/2 · 硬木板 0/1 · 40 币」；级数不够的后面写「铁匠铺 N 级」
func line_of(r: SmithRecipeDef) -> String:
	var def := flow.items.get_def(r.output)
	var got := Smithy.have(flow.meta, r)
	var parts: Array[String] = []
	var keys: Array = r.inputs.keys()
	keys.sort()
	for key in keys:
		var d := flow.items.get_def(StringName(String(key)))
		parts.append(UiText.t("smithy.need_item") % [Names.of(d) if d != null else String(key), int(got.get(String(key), 0)), int(r.inputs[key])])
	parts.append(UiText.t("smithy.need_funds") % r.funds)
	var name := Names.pick(r.display_names, r.display_name) if r.display_name != "" else (Names.of(def) if def != null else String(r.output))
	var text := UiText.t("smithy.line") % [name, UiText.t("hud.buff_sep").join(parts)]
	if r.level > Smithy.level(flow.meta):
		text += UiText.t("smithy.line_locked") % r.level
	return text


## 打这一张；返回空串 = 打了，否则是原因（说一句）
func forge(id: StringName) -> String:
	var r := SmithRecipeDef.find(flow.smith_recipes, id)
	var def := flow.items.get_def(r.output) if r != null else null
	var why := flow.forge(id)
	if say.is_valid():
		var name := Names.of(def) if def != null else String(id)
		say.call(UiText.t("smithy.forged") % [name, flow.meta.funds] if why == "" else UiText.t("smithy.cant") % [name, why])
	changed.emit()
	return why


## 测试看：配方 id → 「打造」键
func forge_button(id: StringName) -> Button:
	return _buttons.get(id, null)

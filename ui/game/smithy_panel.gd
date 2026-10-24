## 251：基地「铁匠铺」页（[Smithy]）。补充一 §10.2（作者 14:49）：左列大类（一排平的石键：刀剑 / 斧锤 / 弓 / 法杖 / 盾 / 护甲，[member SmithRecipeDef.group]，
## 选中的按下），右边这一类的配方一格一格平铺（[RecipeCell]：产物在带框的小格里，能打的亮、不能打的压灰，悬浮窗写原因），按面板宽自动折行；
## 点一格 → 下方展开卷轴（[RecipeScroll]：产物名、每样素材有几 / 要几、工钱金币 + 数字、烧亮铁红的「打造」键），点同一格收起、点别的换内容。
## 页面上不写等级（在科技页；级不够只是灰格 + 悬浮窗「铁匠铺要几级」）。打完那格闪一下、卷轴的「有几」刷新，告示卷轴照说「打好了」
extends VBoxContainer

signal changed()

var flow: GameFlow = null
var font: Font = null
var say: Callable = Callable()
var _head: HeaderTag = null
var _funds: CoinLabel = null
var _keys: VBoxContainer = null
var _grid: HFlowContainer = null
var _empty: PanelContainer = null
var _scroll: RecipeScroll = null
## 大类 → 左列那颗键
var _group_keys: Dictionary = {}
## 配方 id → 那一格
var _cells: Dictionary = {}
var _group := ""
## 卷轴上展开的那张（空 = 收着）
var _open: StringName = &""


func setup(p_flow: GameFlow, p_font: Font, p_say: Callable = Callable()) -> void:
	flow = p_flow
	font = p_font
	say = p_say
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := UiTheme.hbox(8)
	add_child(head)
	_head = HeaderTag.new(UiText.t("smithy.title"))
	_head.mouse_filter = Control.MOUSE_FILTER_PASS
	_head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(_head)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var plate := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 10, 4, 10, 4)     # 钱袋读数：纸牌上金币 + 数字
	UiTheme.set_tone(plate, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	plate.tooltip_text = UiText.t("hud.wallet")
	head.add_child(plate)
	_funds = CoinLabel.make(flow.meta.funds, 18)
	plate.add_child(_funds)
	var body := UiTheme.hbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_keys = UiTheme.vbox(6)
	_keys.custom_minimum_size.x = 96
	body.add_child(_keys)
	for g in SmithRecipeDef.GROUPS:
		var key := StoneChip.entry(UiText.t("smithy.group_" + g), show_group.bind(g))
		_keys.add_child(key)
		_group_keys[g] = key
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right)
	var pane := UiTheme.vbox(0)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(pane)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_child(_grid)
	_empty = UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 12, 6, 12, 6)
	UiTheme.set_tone(_empty, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	_empty.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = UiText.t("smithy.group_empty")
	_empty.add_child(l)
	pane.add_child(_empty)
	_scroll = RecipeScroll.make(font, func(): forge(_open))
	add_child(_scroll)
	_group = SmithRecipeDef.GROUPS[0]
	flow.meta.changed.connect(rebuild)
	flow.meta.warehouse.changed.connect(rebuild)
	rebuild()


## 翻到这一类（左列的键）；卷轴收起
func show_group(g: String) -> void:
	if _group != g:
		_open = &""
	_group = g
	rebuild()


func selected_group() -> String:
	return _group


## 点一格：展开这张的卷轴；同一格再点收起
func open_recipe(id: StringName) -> void:
	var r := SmithRecipeDef.find(flow.smith_recipes, id)
	if r != null and r.group != _group:
		_group = r.group
	_open = &"" if _open == id else id
	rebuild()


func opened() -> StringName:
	return _open


func rebuild() -> void:
	if _grid == null:
		return
	var lv := Smithy.level(flow.meta)
	_head.text = UiText.t("smithy.title") if lv > 0 else UiText.t("smithy.locked")
	_head.tooltip_text = UiText.t("smithy.intro") if lv > 0 else UiText.t("smithy.locked_tip")
	_funds.amount = flow.meta.funds
	for g in _group_keys:
		(_group_keys[g] as Button).set_pressed_no_signal(g == _group)
	UiTheme.clear_children(_grid)
	_cells.clear()
	var shown := 0
	var open_recipe_def: SmithRecipeDef = null
	for r in flow.sorted_smith_recipes():
		var rd := r as SmithRecipeDef
		if rd == null or rd.group != _group:
			continue
		var def := flow.items.get_def(rd.output)
		var name := Names.pick(rd.display_names, rd.display_name) if rd.display_name != "" else (Names.of(def) if def != null else String(rd.output))
		var cell := RecipeCell.make(rd.id, def, name, font)
		var why := Smithy.can_forge(flow.meta, rd, flow.items)
		cell.lit = why == ""
		cell.tooltip_text = name + ("\n" + why if why != "" else "")
		cell.selected = rd.id == _open
		cell.clicked.connect(func(c: RecipeCell): open_recipe(c.recipe_id))
		_grid.add_child(cell)
		_cells[rd.id] = cell
		shown += 1
		if rd.id == _open:
			open_recipe_def = rd
	_empty.visible = shown == 0
	if open_recipe_def == null:
		_open = &""
	_scroll.visible = open_recipe_def != null
	if open_recipe_def != null:
		_scroll.show_recipe(open_recipe_def, flow.items, Smithy.have(flow.meta, open_recipe_def), Smithy.can_forge(flow.meta, open_recipe_def, flow.items))


## 打这一张；返回空串 = 打了，否则是原因（说一句）
func forge(id: StringName) -> String:
	var r := SmithRecipeDef.find(flow.smith_recipes, id)
	var def := flow.items.get_def(r.output) if r != null else null
	var why := flow.forge(id)
	if say.is_valid():
		var name := Names.of(def) if def != null else String(id)
		say.call(UiText.t("smithy.forged") % [name, flow.meta.funds] if why == "" else UiText.t("smithy.cant") % [name, why])
	if why == "":
		var cell := _cells.get(id, null) as RecipeCell
		if cell != null:
			cell.flash()
	changed.emit()
	return why


## 测试看：配方 id → 那一格、卷轴、大类键
func cell(id: StringName) -> RecipeCell:
	return _cells.get(id, null)


func recipe_scroll() -> RecipeScroll:
	return _scroll


func group_key(g: String) -> Button:
	return _group_keys.get(g, null)


## 测试看：这张的「打造」键（卷轴展开到这张）
func forge_button(id: StringName) -> Button:
	if _open != id:
		open_recipe(id)
	return _scroll.forge_key if _open == id else null

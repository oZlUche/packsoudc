## 251：基地「铁匠铺」页（[Smithy]）。补充一 §10.2（作者 14:49）：左列大类（刀剑 / 斧锤 / 弓 / 法杖 / 盾 / 护甲，[member SmithRecipeDef.group]，选中的按下），
## 右边这一类的配方一格一格平铺（[RecipeCell]：产物在带框的小格里，能打的亮、不能打的压灰，悬浮窗写原因），按格子区宽自动折行；
## 点一格 → 下方弹出打造界面（[RecipeScroll]：产物名、每样素材有几 / 要几、工钱金币 + 数字、烧红的「打造」键），点同一格收起、点别的换内容。
## 页面上不写等级（在科技页；级不够只是灰格 + 悬浮窗「铁匠铺要几级」）。打完那格闪一下、「有几」刷新，告示卷轴照说「打好了…进了仓库」。
## 补充二 §12（作者 10-25 14:20「铁匠铺里也不需要[仓库]，重来」；14:21「合成界面应该是铁砧配色的」）：整页（右列仓库收起），
## 砖墙底图 `smithy/bg` 按中列「包含」缩放居中（[MarketStage]），`smithy/layout.json` 的矩形摆各块：`keys` 大类木牌（[CatKey]）、`grid` 格子区（素框里铺格）、
## `scroll` 铁砧打造界面（砧顶小尖对准选中格）、`funds` 钱牌（金币 + 数字）、`sign` 招牌上的字。
## 补图（UI替换美术 10-25 15:14）：格子区是深铁框里固定 5 列 × 2 行铺满（[RecipeCell]，不到 10 张补空格），多于 10 张按整行竖着滚
extends VBoxContainer

signal changed()

const LAYOUT := "smithy/layout"
const BG := "smithy/bg"
## 钱牌上金币 + 数字的字号 = 钱牌高的这么多倍
const FUNDS_FONT := 0.62
## 大类木牌之间的空（原尺寸）
const KEY_GAP := 6.0
## 格子区固定几列几行（多出来的行竖着滚）
const COLS := 5
const ROWS := 2
## 298：前后两窗离格子区边、砧面上沿多远（原尺寸）
const COMPARE_GAP := 16.0

var flow: GameFlow = null
var font: Font = null
## 282：铁匠（左上角空墙）
var npc: NpcBadge = null
var _stage: MarketStage = null
var _funds: CoinLabel = null
var _keys: VBoxContainer = null
var _shelf: PanelContainer = null
var _grid: GridContainer = null
var _pane: ScrollContainer = null
var _empty: PanelContainer = null
var _scroll: RecipeScroll = null
## 298：升级类配方点开时并排的两块信息窗（仓库里那把 | 打完那把）
var compare: UpgradeCompare = null
## 大类 → 左列那颗键
var _group_keys: Dictionary = {}
## 配方 id → 那一格
var _cells: Dictionary = {}
var _group := ""
## 打造界面上的那张（空 = 收着）
var _open: StringName = &""
## 格子按哪个缩放 / 多大搭的（变了才重搭）
var _cell_k := 1.0
var _cell_px := Vector2.ZERO


func setup(p_flow: GameFlow, p_font: Font) -> void:
	flow = p_flow
	font = p_font
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage = MarketStage.new(LAYOUT, BG)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(320, 240)
	_stage.resized.connect(_place)
	add_child(_stage)
	_funds = CoinLabel.make(flow.meta.funds, 18)     # 钱牌是浅色木牌：墨字
	_funds.centered = true
	_funds.mouse_filter = Control.MOUSE_FILTER_STOP
	_funds.tooltip_text = UiText.t("hud.wallet")
	_stage.add_child(_funds)
	_keys = UiTheme.vbox(int(KEY_GAP))
	_stage.add_child(_keys)
	for g in SmithRecipeDef.GROUPS:
		var key := CatKey.make(UiText.t("smithy.group_" + g), show_group.bind(g))
		_keys.add_child(key)
		_group_keys[g] = key
	_shelf = RecipeCell.shelf()     # 格子区：素框 + 浅内垫（227 规矩）
	_stage.add_child(_shelf)
	_pane = ScrollContainer.new()
	_pane.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shelf.add_child(_pane)
	_grid = GridContainer.new()
	_grid.columns = COLS
	RecipeCell.space(_grid)
	_pane.add_child(_grid)
	_empty = UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 12, 6, 12, 6)
	UiTheme.set_tone(_empty, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	var l := Label.new()
	l.text = UiText.t("smithy.group_empty")
	_empty.add_child(l)
	_stage.add_child(_empty)     # 这一类还没有配方：一块签压在空格子区正中
	_scroll = RecipeScroll.make(font, func(): forge(_open))
	_stage.add_child(_scroll)     # 后加 = 压在格子区上（砧顶小尖盖住格子区下沿）
	compare = UpgradeCompare.new()
	compare.anchors = func() -> Array: return [cell(_open)]     # 指针在选中那张配方格上才显示，不再盖住格子区（UI设计 复核 11-11）
	compare.resized.connect(_place_compare)
	_pane.resized.connect(_place_compare)
	_stage.add_child(compare)
	npc = NpcBadge.make(NpcDef.BLACKSMITH, flow.meta, flow.items)     # 282
	npc.on_given = _say_given
	_stage.add_child(npc)
	_group = SmithRecipeDef.GROUPS[0]
	flow.meta.changed.connect(rebuild)
	flow.meta.warehouse.changed.connect(rebuild)
	rebuild()


## 282：铁匠给了东西（破晓的信物）
func _say_given(id: StringName) -> void:
	NoticeLayer.post(self, UiText.t("npc.given") % Names.of(flow.items.get_def(id)))


## 翻到这一类（左列的键）；打造界面收起
func show_group(g: String) -> void:
	if _group != g:
		_open = &""
	_group = g
	rebuild()


func selected_group() -> String:
	return _group


## 点一格：弹出这张的打造界面；同一格再点收起
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
	_stage.sign_text = UiText.t("smithy.title")     # 262：铁匠铺默认就有，不再有「未开」招牌
	_stage.tooltip_text = UiText.t("smithy.intro")
	_funds.amount = flow.meta.funds
	_cell_k = _stage.scale_factor()
	var any := {}
	var ready_ := {}
	var mine: Array[SmithRecipeDef] = []
	var whys := {}
	for r in flow.sorted_smith_recipes():
		var rd := r as SmithRecipeDef
		if rd == null:
			continue
		var why := Smithy.can_forge(flow.meta, rd, flow.items)
		any[rd.group] = true
		if why == "":
			ready_[rd.group] = true
		if rd.group == _group:
			mine.append(rd)
			whys[rd.id] = why
	UiTheme.clear_children(_grid)
	_cells.clear()
	var shown := mine.size()
	var slots := maxi(COLS * ROWS, ceili(shown / float(COLS)) * COLS)
	@warning_ignore("integer_division")
	var rows := slots / COLS
	_cell_px = _cell_size(shown)
	var open_recipe_def: SmithRecipeDef = null
	for i in slots:
		var cell_: RecipeCell = null
		if i < shown:
			var rd := mine[i]
			var why: String = whys[rd.id]
			var def := flow.items.get_def(rd.output)
			var name_ := Names.pick(rd.display_names, rd.display_name) if rd.display_name != "" else (Names.of(def) if def != null else String(rd.output))
			cell_ = RecipeCell.make(rd.id, def, name_, _cell_px, _cell_k)
			cell_.lit = why == ""
			var why_t := CoinShort.strip(why)     # 「金币不够」不写字（打开配方卷，工钱那枚金币是红的）
			cell_.tooltip_text = name_ + ("\n" + why_t if why_t != "" else "")
			cell_.selected = rd.id == _open
			cell_.clicked.connect(func(c: RecipeCell): open_recipe(c.recipe_id))
			_cells[rd.id] = cell_
			if rd.id == _open:
				open_recipe_def = rd
		else:
			cell_ = RecipeCell.blank(_cell_px)
		cell_.line_right = i % COLS != COLS - 1
		@warning_ignore("integer_division")
		cell_.line_bottom = i / COLS != rows - 1
		_grid.add_child(cell_)
	# 木牌：正在看的按下；一张配方都没有的类灰着点不了，有配方但一张都打不了的压灰（还能点开看要什么料）
	for g in _group_keys:
		var key := _group_keys[g] as Button
		key.set_pressed_no_signal(g == _group)
		key.disabled = not any.has(g) and g != _group
		if key is CatKey:
			(key as CatKey).dim = not ready_.has(g)
		key.queue_redraw()
	_empty.visible = shown == 0
	if open_recipe_def == null:
		_open = &""
	_scroll.visible = open_recipe_def != null
	if open_recipe_def != null:
		var mat_defs := {}     # 279：材质类格画仓库里会被扣的那件
		var picks := Smithy.material_picks(flow.meta, open_recipe_def)
		for m in picks:
			if picks[m] != null:
				mat_defs[m] = (picks[m] as ItemInstance).def
		_scroll.show_recipe(open_recipe_def, flow.items, Smithy.have(flow.meta, open_recipe_def), Smithy.can_forge(flow.meta, open_recipe_def, flow.items), mat_defs)
	_show_compare(open_recipe_def)
	_aim_pointer.call_deferred()


## 298：升级类配方（[method Anvil.is_upgrade]）点开了 → 两窗；仓库里没有那把 → 左窗按品质 0、压暗。别的配方收起
func _show_compare(recipe: SmithRecipeDef) -> void:
	var pv := Smithy.preview(flow.meta, recipe, flow.items) if recipe != null else {}
	if pv.is_empty():
		compare.clear()
		return
	var before := pv["before"] as ItemInstance
	var missing := before == null
	if missing:
		before = ItemInstance.create(flow.items.get_def(StringName(String(recipe.inputs.keys()[0]))), 0)
	compare.show_pair(before, pv["after"] as ItemInstance, missing)
	_place_compare.call_deferred()     # 格子区这一帧可能还没排好


## 摆在格子区上、选中那格的另一半边（选中格在左半就靠右，反之靠左），下沿贴着砧面上沿往上长；顶不出整页
func _place_compare() -> void:
	if compare == null or _stage == null or _stage.size.x <= 0.0 or not compare.visible or _pane == null:
		return
	var inv := compare.get_parent_control().get_global_transform().affine_inverse()
	var pane := inv * _pane.get_global_rect()
	var gap := COMPARE_GAP * _stage.scale_factor()
	var picked: Control = cell(_open)
	var on_left := picked == null or (inv * picked.get_global_rect().get_center()).x < pane.get_center().x
	var x := pane.end.x - compare.size.x - gap if on_left else pane.position.x + gap
	var y := (inv * _scroll.get_global_rect()).position.y - compare.size.y - gap
	compare.position = Vector2(maxf(0.0, x), maxf(0.0, y)).floor()


## 照底图的摆法放各块（整页大小变了也走这里）；缩放变了格子按新大小重搭
func _place() -> void:
	if _stage == null or _stage.size.x <= 0.0:
		return
	var lay := _stage.layout()
	var k := _stage.scale_factor()
	var fr := _stage.to_local_rect(lay.get("funds", {}))
	_funds.position = fr.position
	_funds.size = fr.size
	_funds.font_size = maxi(12, roundi(fr.size.y * FUNDS_FONT))
	if npc != null and lay.has("npc"):
		npc.fit(_stage.to_local_rect(lay["npc"]))
	var kr := _stage.to_local_rect(lay.get("keys", {}))
	_keys.position = kr.position
	_keys.size = Vector2(kr.size.x, 0)
	CatKey.space(_keys, maxi(2, roundi(KEY_GAP * k)))
	for g in _group_keys:
		var key := _group_keys[g] as Button
		if key is CatKey:
			(key as CatKey).scale_k = k
	var gr := _stage.to_local_rect(lay.get("grid", {}))
	_shelf.position = gr.position
	_shelf.size = gr.size
	_empty.reset_size()
	_empty.position = (gr.get_center() - _empty.size * 0.5).floor()
	var sr := _stage.to_local_rect(lay.get("scroll", {}))
	_scroll.fit(k)
	_scroll.position = sr.position
	_scroll.size = sr.size
	_place_compare()
	if absf(k - _cell_k) > 0.01 or not _cell_size(_cells.size()).is_equal_approx(_cell_px):
		rebuild()
	else:
		_aim_pointer.call_deferred()


## 一格多大：格子区框里面按 5 × 2 平分（多于 10 张时让出竖滚动条的宽）
func _cell_size(shown: int) -> Vector2:
	var edge := RecipeCell.shelf_edge(_shelf)
	var inner := _shelf.size - Vector2.ONE * edge * 2.0
	if shown > COLS * ROWS:
		inner.x -= _pane.get_v_scroll_bar().get_combined_minimum_size().x
	return Vector2(maxf(48.0, floorf(inner.x / COLS)), maxf(48.0, floorf(inner.y / ROWS)))


## 砧顶小尖横向对准选中的那格
func _aim_pointer() -> void:
	var c := _cells.get(_open, null) as RecipeCell
	if c == null or not _scroll.visible or not c.is_inside_tree():
		_scroll.pointer_x = -1.0
		return
	_scroll.pointer_x = c.get_global_rect().get_center().x - _scroll.get_global_rect().position.x


## 打这一张；返回空串 = 打了，否则是原因（说一句）
func forge(id: StringName) -> String:
	var r := SmithRecipeDef.find(flow.smith_recipes, id)
	var def := flow.items.get_def(r.output) if r != null else null
	var why := flow.forge(id)
	var name_ := Names.of(def) if def != null else String(id)
	NoticeLayer.post(self, UiText.t("smithy.forged") % name_ if why == "" else UiText.t("smithy.cant") % [name_, why])
	if why == "":
		var cell_ := _cells.get(id, null) as RecipeCell
		if cell_ != null:
			cell_.flash()
	changed.emit()
	return why


## 测试看：配方 id → 那一格、打造界面、大类键、整页
func cell(id: StringName) -> RecipeCell:
	return _cells.get(id, null)


func recipe_scroll() -> RecipeScroll:
	return _scroll


func group_key(g: String) -> Button:
	return _group_keys.get(g, null)


func stage() -> MarketStage:
	return _stage


func funds_label() -> CoinLabel:
	return _funds


## 测试看：这张的「打造」键（打造界面弹到这张）
func forge_button(id: StringName) -> Button:
	if _open != id:
		open_recipe(id)
	return _scroll.forge_key if _open == id else null

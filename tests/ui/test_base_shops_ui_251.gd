## 251 §六：基地两个新页签 —— 集市 / 铁匠铺各一个（待定 4 推荐），科技点出来才露；货位与产物格带框（227）、字都在牌 / 签 / 键上（226）；
## 集市页买一件进右边仓库，铁匠铺页齐了才能按「打造」
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")


static func _levels(f: GameFlow, market: int, smithy: int) -> void:
	f.meta.tech_levels = {"bargain": 1, "warehouse": 1, "safe_box": 1, "pack": 1, "market": market, "smithy": smithy}
	f.derive_techs()
	f.smith_recipes = SmithRecipeDef.load_all()


static func frame_tabs(t: TestCase, root: Window) -> void:
	t.begin("251 §六：没点出来不露页签；点出来了露「集市」「铁匠铺」（补充二：两页整页，右半边仓库收起）")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	_levels(f, 0, 0)
	var s: Control = W178._screen(f, root)
	t.check(not (s._tab_btns["market"] as Button).visible and not (s._tab_btns["smithy"] as Button).visible, "0 级：两个页签都不露")
	s.queue_free()
	_levels(f, 1, 1)
	s = W178._screen(f, root)
	t.check((s._tab_btns["market"] as Button).visible and (s._tab_btns["smithy"] as Button).visible, "1 级：两个页签都露")
	# UI替换美术（作者 14:49 选乙 平墨图标）：七个页签字左边各一枚图标，一样宽
	var widths := {}
	for key in s._tab_btns:
		var tb := s._tab_btns[key] as Button
		t.check(tb.icon != null and tb.icon_alignment == HORIZONTAL_ALIGNMENT_LEFT, "页签 %s 有图标、在字左边" % key)
		widths[tb.custom_minimum_size.x] = true
	t.eq(widths.size(), 1, "七个页签一样宽")
	t.eq(s._tab_btns.size(), 7, "七个页签")
	t.eq(f.meta.market_stock.size(), 4, "打开基地时补了一次货")
	s.show_tab("market")
	t.check(not s._right.visible, "集市页整页（右半边仓库收起）")
	s.show_tab("smithy")
	t.check(not s._right.visible, "铁匠铺页整页（右半边仓库收起）")
	s.queue_free()
	W178._cleanup()


static func frame_market_page(t: TestCase, root: Window) -> void:
	t.begin("251 补充一 §10.1：集市页 —— 货散放在一张透视大桌上、前后两排（每件一块只有那件大小、带框的小棋盘），台沿下挂金币价签；钱袋读数金币 + 数字；买一件：仓库多一件、价签盖「已售」；字都不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	_levels(f, 3, 0)
	f.meta.funds = 100000
	f.ensure_market()
	var s: Control = W178._screen(f, root)
	s.show_tab("market")
	var p = s.market_panel()
	t.eq(p.views().size(), 8, "3 级：八个货位")
	t.eq(p.views().size(), f.meta.market_stock.size(), "每格一块视图")
	t.check(p.views().all(func(v: InventoryView) -> bool: return BoardFrame.framed(v)), "货位带框（227）")
	var sizes_ok := true
	for i in p.views().size():
		var def := Market.def_at(f.meta, f.items, i)
		sizes_ok = sizes_ok and def != null and (p.views()[i] as InventoryView).inventory.size == def.shape.size_rotated(0)
	t.check(sizes_ok, "每块小棋盘就是那件的大小（不再补成 2×2）")
	p.stage().size = p.stage().design_size()     # 测试屏很小：撑到设计大小再看（大小一变就重摆）
	var spots: Array = p.stage().spots()
	var back := 0
	var front := 0
	for i in p.views().size():
		if float(spots[i].get("scale", 1.0)) < float(spots[back].get("scale", 1.0)):
			back = i
		if float(spots[i].get("scale", 1.0)) > float(spots[front].get("scale", 1.0)):
			front = i
	var bottoms: Array = []
	for v in p.views():
		var fr := (v as Control).get_parent() as Control
		bottoms.append(fr.position.y + fr.size.y)
	bottoms.sort()
	var rows := 1
	for i in range(1, bottoms.size()):
		if bottoms[i] - bottoms[i - 1] > 40.0:
			rows += 1
	t.eq(rows, 2, "八件分前后两排（%s）" % str(bottoms))
	t.check(p.views()[back].cell_px < p.views()[front].cell_px, "后排的格子小、前排大（scale；%s）" % str([back, front, p.views()[back].cell_px, p.views()[front].cell_px, p.stage().size]))
	var foot: Vector2 = p.stage().foot_of(spots[0])
	var fr0 := (p.views()[0] as Control).get_parent() as Control
	t.check(absf(fr0.position.x + fr0.size.x * 0.5 - foot.x) < 1.0 and absf(fr0.position.y + fr0.size.y - foot.y) < 1.0, "货底中点落在 foot 上")
	t.check(p.prices()[0].position.y >= foot.y, "价签平放在货前面")
	var coins_ok := true
	for i in p.prices().size():
		coins_ok = coins_ok and (p.prices()[i] as PriceTag).coin == Market.price_of(f.market(), Market.def_at(f.meta, f.items, i))
	t.check(coins_ok, "价签是金币式（金币 + 数字，不写「币」）")
	t.eq(p.funds_label().amount, 100000, "钱袋读数")
	var act: ItemActions.Action = p._buy_action(0)
	t.eq([act.label, act.coin], [UiText.t("act.buy_coin"), Market.price_of(f.market(), Market.def_at(f.meta, f.items, 0))], "右键「买下」+ 金币价钱")
	var tip := TipButton.make(act, TipButton.FULL)
	t.check(tip.get_children().any(func(c: Node) -> bool: return c is CoinLabel), "右键菜单的按钮上画金币")
	tip.free()
	var n := f.meta.warehouse.item_count()
	var price := Market.price_of(f.market(), Market.def_at(f.meta, f.items, 0))
	t.eq(p.buy(0), "", "买第一格")
	t.eq(f.meta.warehouse.item_count(), n + 1, "仓库多一件")
	t.check(p.prices()[0].sold, "价签盖了已售")
	t.eq(p.funds_label().amount, 100000 - price, "钱袋读数跟着少")
	t.check(p.note() == null, "开着、有货：没有那块签")
	t.eq(Bare.audit(s, "market251"), [] as Array[String], "没有裸字")
	s.say("买不了：钱不够")
	s.show_tab("smithy")
	t.eq(s.notice_layer().lines(), [] as Array[String], "游戏测试 v4.34：换页签，上一页的告示收掉")
	s.queue_free()
	W178._cleanup()
	t.begin("251 补充一 §10.1：没点出集市 —— 只画空棚（不画木台）+ 一块签说去科技页点；页面上不写等级")
	f = W178._flow()
	_levels(f, 0, 0)
	s = W178._screen(f, root)
	p = s.market_panel()
	t.eq(p.views().size(), 0, "没有货位")
	t.check(not p.stage().tables, "空棚")
	t.check(p.note() != null and (p.note().get_child(0) as Label).text == UiText.t("market.locked_tip"), "签：去科技页点出集市")
	t.eq(Bare.audit(p, "market251_locked"), [] as Array[String], "签上的字不裸")
	s.queue_free()
	W178._cleanup()


static func _labels(n: Node, out: Array[String]) -> Array[String]:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


static func frame_smithy_page(t: TestCase, root: Window) -> void:
	t.begin("251 补充一 §10.2：铁匠铺页 —— 左列六个大类（选中的按下），右边这一类的配方一格一格（带框、能打亮 / 不能打灰）；点一格下方展开卷轴（素材有几 / 要几、工钱金币、铁红「打造」）")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	_levels(f, 0, 1)
	f.meta.funds = 1000
	var s: Control = W178._screen(f, root)
	s.show_tab("smithy")
	var p = s.smithy_panel()
	t.eq(p.selected_group(), "blade", "先翻到刀剑")
	t.check(SmithRecipeDef.GROUPS.all(func(g: String) -> bool: return p.group_key(g) != null), "六颗大类键都在（法杖也列着）")
	t.check(p.group_key("blade").button_pressed and not p.group_key("bow").button_pressed, "选中的那颗按下")
	var cell: RecipeCell = p.cell(&"smith_shortsword")
	t.not_null(cell, "短剑那一格在")
	if cell == null:
		s.queue_free()
		return
	t.check(BoardFrame.framed(cell.view), "产物格带框（227）")
	var ls: RecipeCell = p.cell(&"smith_longsword")
	t.check(ls != null and ls.view.inventory.size.x * ls.view.cell_px >= BoardFrame.MIN_SIDE, "游戏测试 v4.39：1×4 的长剑补了一列，框不被裁")
	t.check(not cell.lit and cell.tooltip_text.contains(UiText.t("smithy.missing")), "缺素材：压灰、悬浮窗写原因")
	t.check(not p.recipe_scroll().visible, "没点格子：卷轴收着")
	var b: Button = p.forge_button(&"smith_shortsword")
	t.check(p.recipe_scroll().visible and p.opened() == &"smith_shortsword", "点了：卷轴展开到这张")
	t.check(b.disabled, "缺素材：打造灰着")
	t.check(b.theme_type_variation in [UiTheme.BUTTON_FORGE, UiTheme.BUTTON_ART], "打造键：铁红平键（图到之前）或四态图")
	t.eq(p.recipe_scroll().material_lines(), ["0 / 1", "0 / 2"] as Array[String], "素材：有几 / 要几（硬木板、铁矿石）")
	t.eq(p.recipe_scroll().wage(), 40, "工钱 40（金币 + 数字）")
	for id in [&"iron_ore", &"iron_ore", &"hardwood_plank"]:
		var inst := ItemInstance.create(f.items.get_def(id), f.meta.allocate_uid())
		f.meta.warehouse.try_add(inst, true)
	t.check(p.cell(&"smith_shortsword").lit, "齐了：那格亮了")
	t.eq(p.recipe_scroll().material_lines(), ["1 / 1", "2 / 2"] as Array[String], "卷轴的「有几」跟着刷新")
	b = p.forge_button(&"smith_shortsword")
	t.check(not b.disabled, "齐了：能按")
	t.eq(p.forge(&"smith_shortsword"), "", "打了")
	t.check(f.meta.warehouse.items().any(func(i) -> bool: return (i as ItemInstance).def.id == &"shortsword"), "短剑进了仓库")
	t.eq(f.meta.funds, 960, "扣了 40 币")
	t.eq(p.opened(), &"smith_shortsword", "打完卷轴还开着")
	t.eq(p.recipe_scroll().material_lines(), ["0 / 1", "0 / 2"] as Array[String], "「有几」扣回去了")
	p.open_recipe(&"smith_shortsword")
	t.check(p.opened() == &"" and not p.recipe_scroll().visible, "点同一格：收起")
	p.open_recipe(&"smith_longbow")
	t.eq(p.selected_group(), "bow", "点长弓：翻到弓")
	var bow: RecipeCell = p.cell(&"smith_longbow")
	t.check(bow != null and not bow.lit and bow.tooltip_text.contains(UiText.t("smithy.need_level") % 2), "2 级的长弓：灰着、悬浮窗写要几级")
	p.show_group("staff")
	t.check(p.cell(&"smith_longbow") == null and p.opened() == &"", "翻到法杖：换了一类、卷轴收起")
	t.check(p._empty.visible, "法杖暂空：一块签说还没有")
	p.show_group("blade")
	var texts := _labels(p, [] as Array[String])
	t.check(not texts.any(func(x: String) -> bool: return x.contains("级") or x.to_lower().contains("level")), "页面上不写等级（%s）" % str(texts.slice(0, 4)))
	t.eq(Bare.audit(s, "smithy251"), [] as Array[String], "没有裸字")
	s.queue_free()
	W178._cleanup()

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
	t.begin("251 §六：没点出来不露页签；点出来了露「集市」「铁匠铺」，右半边是仓库")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	_levels(f, 0, 0)
	var s: Control = W178._screen(f, root)
	t.check(not (s._tab_btns["market"] as Button).visible and not (s._tab_btns["smithy"] as Button).visible, "0 级：两个页签都不露")
	s.queue_free()
	_levels(f, 1, 1)
	s = W178._screen(f, root)
	t.check((s._tab_btns["market"] as Button).visible and (s._tab_btns["smithy"] as Button).visible, "1 级：两个页签都露")
	t.eq(f.meta.market_stock.size(), 4, "打开基地时补了一次货")
	s.show_tab("market")
	t.check(s._right.visible, "集市页右半边是仓库")
	s.show_tab("smithy")
	t.check(s._right.visible, "铁匠铺页右半边是仓库")
	s.queue_free()
	W178._cleanup()


static func frame_market_page(t: TestCase, root: Window) -> void:
	t.begin("251 §六：集市页 —— 每格一块视图（在一块框里）+ 一张价签；买一件：仓库多一件、价签盖「已售」；字都不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	_levels(f, 1, 0)
	f.meta.funds = 100000
	var s: Control = W178._screen(f, root)
	s.show_tab("market")
	var p = s.market_panel()
	t.eq(p.views().size(), f.meta.market_stock.size(), "每格一块视图")
	t.check(p.views().all(func(v: InventoryView) -> bool: return BoardFrame.framed(v)), "货位带框（227）")
	var n := f.meta.warehouse.item_count()
	t.eq(p.buy(0), "", "买第一格")
	t.eq(f.meta.warehouse.item_count(), n + 1, "仓库多一件")
	t.check(p.prices()[0].sold, "价签盖了已售")
	t.eq(Bare.audit(s, "market251"), [] as Array[String], "没有裸字")
	s.queue_free()
	W178._cleanup()


static func frame_smithy_page(t: TestCase, root: Window) -> void:
	t.begin("251 §六：铁匠铺页 —— 每张配方一行（产物格带框、铭牌写有几 / 要几）；缺素材「打造」灰着，齐了能按、打出来进仓库")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	_levels(f, 0, 1)
	f.meta.funds = 1000
	var s: Control = W178._screen(f, root)
	s.show_tab("smithy")
	var p = s.smithy_panel()
	var b: Button = p.forge_button(&"smith_shortsword")
	t.not_null(b, "短剑那一行在")
	if b == null:
		s.queue_free()
		return
	t.check(b.disabled, "缺素材：打造灰着")
	for id in [&"iron_ore", &"iron_ore", &"hardwood_plank"]:
		var inst := ItemInstance.create(f.items.get_def(id), f.meta.allocate_uid())
		f.meta.warehouse.try_add(inst, true)
	b = p.forge_button(&"smith_shortsword")
	t.check(not b.disabled, "齐了：能按")
	t.eq(p.forge(&"smith_shortsword"), "", "打了")
	t.check(f.meta.warehouse.items().any(func(i) -> bool: return (i as ItemInstance).def.id == &"shortsword"), "短剑进了仓库")
	t.eq(f.meta.funds, 960, "扣了 40 币")
	var view: Button = p.forge_button(&"smith_longbow")
	t.check(view != null and view.disabled, "2 级的长弓：灰着")
	t.eq(Bare.audit(s, "smithy251"), [] as Array[String], "没有裸字")
	s.queue_free()
	W178._cleanup()

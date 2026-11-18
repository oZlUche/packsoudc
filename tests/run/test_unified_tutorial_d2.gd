## 统一教程 D2（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §10）：切片基地四个页签都开，
## 集市 / 铁匠铺 / 科技走正式版同一套服务、只开清单里的（data/manifests/slice_base.json）；正式版不受影响
extends RefCounted


static func run_tabs(t: TestCase) -> void:
	t.begin("统一教程 D2 · 切片基地：出征、仓库、后勤、书架四个页签都开")
	for key in ["expedition", "warehouse", "logistics", "shelf"]:
		t.check(SliceProfile.keeps_tab(SliceProfile.SLICE, key), "切片有 %s" % key)


static func run_techs_and_recipes(t: TestCase) -> void:
	t.begin("统一教程 D2 · 切片只开两项科技（数值树仓库扩建、机制树行囊）、三张基础配方，配方的料集市都买得到；正式版原样")
	var all := GameFlow.load_techs()
	var slice := SliceBase.techs(all, SliceProfile.SLICE)
	t.eq(slice.map(func(d: TechDef) -> StringName: return d.id), [&"pack", &"warehouse"], "切片两项科技")
	t.check(slice.any(func(d: TechDef) -> bool: return d.tree == TechDef.TREE_STAT) and slice.any(func(d: TechDef) -> bool: return d.tree != TechDef.TREE_STAT), "两棵树各一项")
	t.check(slice.all(func(d: TechDef) -> bool: return d.requires.is_empty()), "都是根节点（不缺前置）")
	t.eq(SliceBase.techs(all, &"").size(), all.size(), "正式版原样")
	var recipes := SliceBase.recipes(SmithRecipeDef.load_all(), SliceProfile.SLICE)
	t.eq(recipes.size(), SliceBase.ids("smith_recipe_ids").size(), "清单里的配方都在")
	var sells := SliceBase.ids("market_item_ids")
	for r in recipes:
		for id in r.inputs:
			t.check(sells.has(StringName(String(id))), "%s 的料 %s 集市卖" % [r.id, id])


static func run_market(t: TestCase) -> void:
	t.begin("统一教程 D2 · 切片集市只卖清单里的货（各固定摊、散货摊都是）；正式版原样")
	var db := ItemDatabase.new()
	db.load_dir()
	var formal := SliceBase.market_rules(Market.load_rules(), &"")
	var slice := SliceBase.market_rules(Market.load_rules(), SliceProfile.SLICE)
	t.check(formal.allowed_ids.is_empty(), "正式版不限")
	var allowed := SliceBase.ids("market_item_ids")
	for id in allowed:
		t.not_null(db.get_def(id), "清单里的 %s 在道具库里" % id)
	var listed := 0
	for st in Market.stalls():
		for id in Market.catalogue(slice, db, st, 3):
			listed += 1
			t.check(allowed.has(id), "%s 摊卖的 %s 在清单里" % [st.id, id])
	t.check(listed > 0, "切片固定摊有货")
	for id in Market.loose_candidates(slice, db):
		t.check(allowed.has(id), "散货摊的 %s 在清单里" % id)
	t.check(Market.loose_candidates(formal, db).size() > Market.loose_candidates(slice, db).size(), "正式版散货摊货更多")


static func run_tutorial_sources(t: TestCase) -> void:
	t.begin("统一教程 D2 · 教学来源清单 = 三段教程固定奖励里的道具")
	var want: Array[StringName] = []
	for c in GameFlow.load_chapters(SliceProfile.SLICE):
		for id in c.tutorial_items:
			if not want.has(id):
				want.append(id)
	var got := SliceBase.ids("tutorial_item_ids")
	Ids.sort(want)
	Ids.sort(got)
	t.eq(got, want, "清单与奖励表一致")


static func run_market_level_one(t: TestCase) -> void:
	t.begin("游戏测试 v6.40 · 切片集市只有 1 级也把清单里的货都摆出来：三张配方的料在固定摊上真买得到")
	var db := ItemDatabase.new()
	db.load_dir()
	var slice := SliceBase.market_rules(Market.load_rules(), SliceProfile.SLICE)
	var on_shelf: Array[StringName] = []
	for st in Market.stalls():
		for id in Market.catalogue(slice, db, st, 1):
			if not on_shelf.has(id):
				on_shelf.append(id)
	for id in SliceBase.ids("market_item_ids"):
		t.check(on_shelf.has(id), "1 级固定摊摆着 %s" % id)
	for r in SliceBase.recipes(SmithRecipeDef.load_all(), SliceProfile.SLICE):
		for id in r.inputs:
			t.check(on_shelf.has(StringName(String(id))), "%s 的料 %s 1 级就买得到" % [r.id, id])
	var formal := Market.load_rules()
	t.check(not Market.catalogue(formal, db, Market.stall(&"goods"), 1).has(&"hardwood_plank"), "正式版 1 级照样按稀有度上限：不摆绿色的硬木板")

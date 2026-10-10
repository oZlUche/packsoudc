## 作者第十一批（报告 087）：稀有度六色、词条侧窗、武器耗耐力、信仰道具休眠保留通用效果、预估 DPS 算开战 buff、
## BOSS 保底金色 + 直接撤离、商店拖着买 / 卖、战斗 buff 图标栏。合成改相邻自动在 test_tutorial2 里验。
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
## 与 Support.paths("087") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_087_run.json"
const META := "user://test_087_meta.json"
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["loadouts", "events"])


static func _kit(c: TestSupport.Content) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == &"standard":
			return l
	return c.loadouts[0] if not c.loadouts.is_empty() else LoadoutDef.new()


static func run_rarity(t: TestCase) -> void:
	t.begin("087 · 稀有度六档：白 / 绿 / 蓝 / 紫 / 金 / 红，名字六个，数据表跟着六档")
	t.eq(ItemPainter.RARITY_COLORS.size(), 6, "六种颜色")
	t.eq(ItemTooltip.RARITY_NAMES.size(), 6, "六个名字")
	var white := ItemPainter.RARITY_COLORS[0]
	var gold := ItemPainter.RARITY_COLORS[4]
	var red := ItemPainter.RARITY_COLORS[5]
	t.check(white.r > 0.7 and white.g > 0.7 and white.b > 0.7, "0 是白")
	t.check(gold.r > 0.7 and gold.g > 0.55 and gold.b < 0.4, "4 是金")
	t.check(red.r > 0.7 and red.g < 0.4 and red.b < 0.4, "5 是红")
	t.eq(ItemTooltip.rarity_name(4), "传说", "4 = 传说（金）")
	t.eq(ItemTooltip.rarity_name(5), "神话", "5 = 神话（红）")
	var d := ItemDef.new()
	d.rarity = 9
	t.eq(ItemPainter.rarity_color(d), red, "超出表长按最后一档")
	var rule: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	t.eq(rule.base_chance.size(), 6, "掉落率表六档")
	t.eq(rule.treasure_rarities(), [4, 5] as Array[int], "珍宝是金与红")
	var econ: EconomyRules = load(ContentPaths.asset_file("economy_rules", "standard"))
	t.eq(econ.shop_rarity_weights.size(), 6, "商店稀有度权重六档")


static func run_glossary(t: TestCase) -> void:
	t.begin("087 · 词条：主文字只写名词、侧边词条写效果；buff 词条按定义生成；武器写耗耐力；DPS 算上开战 buff")
	var c := _content()
	var sigil := ItemInstance.create(c.items.get_def(&"charm_brute"))
	var full := ItemTooltip.describe_full(sigil)
	var text := String(full["text"])
	var terms: Array = full["terms"]
	t.check(text.contains("血怒"), "主文字里有「血怒」")
	t.check(not Glossary.strip_bbcode(text).contains("强攻"), "主文字里不直接写血怒带的轴")
	var names: Array[String] = []
	var blood := ""
	for term in terms:
		names.append(String(term["name"]))
		if String(term["name"]) == "血怒":
			blood = String(term["text"])
	t.check(names.has("血怒"), "词条里有血怒：%s" % str(names))
	t.check(blood.contains("【强攻】1 层") and blood.contains("【加速】1 层") and blood.contains("持续 10.0 秒"),
		"血怒的词条写着每层带一层强攻、一层加速（152）、持续 10 秒：%s" % blood)
	# 107（作者定）：「开战时」「信力」这类直白的词不再弹词条（说明文字仍在表里）
	t.check(not names.has("开战时") and not names.has("信力"), "直白的固定词条不再进侧窗：%s" % str(names))
	t.check(Glossary.term_text("开战时") != "" and not Glossary.term_tip("开战时"), "但说明文字一字不动，只是 tip 关了")
	t.check(text.contains("[u]血怒[/u]"), "主文字里血怒标了下划线（有解释的词）")
	# 匕首：自发、耗耐力、DPS
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	var kf := ItemTooltip.describe_full(knife)
	var ktext := String(kf["text"])
	var kplain := Glossary.strip_bbcode(ktext)
	t.check(kplain.contains("耗耐力 3"), "武器写着每次出手耗耐力：%s" % kplain.replace("\n", " / "))
	t.check(ktext.contains("冷却") and ktext.contains("DPS"), "冷却与 DPS 照旧")
	var knames: Array[String] = []
	for term in kf["terms"]:
		knames.append(String(term["name"]))
	# 107：自发、耗耐力、冷却、近战、武器、金属… 全不弹；匕首因此一个词条都不剩
	t.check(not knames.has("自发") and not knames.has("耗耐力") and not knames.has("冷却"), "匕首的直白词条都不弹了：%s" % str(knames))
	t.check(not ktext.contains("[u]自发[/u]") and not ktext.contains("[u]耗耐力[/u]"), "不弹的词在主文字里也不标色（标了色玩家会去找解释）")
	# 涂毒匕首：中毒是 buff 词条，说明按定义生成
	var pk := ItemInstance.create(c.items.get_def(&"poisoned_knife"))
	var pf := ItemTooltip.describe_full(pk)
	var poison := ""
	for term in pf["terms"]:
		if String(term["name"]) == "中毒":
			poison = String(term["text"])
	t.check(poison.contains("减益") and poison.contains("不限层") and poison.contains("永续"), "中毒的词条按定义：减益、不限层、永续：%s" % poison)
	t.check(Glossary.strip_bbcode(String(pf["text"])).contains("施加中毒"), "apply_status 只写「施加中毒」")
	# Glossary 本身
	t.eq(Glossary.mod_text(StatModifier.make(&"damage", StatModifier.Mode.ADD, 10.0)), "伤害 +10", "加算")
	var pct := StatModifier.make(&"damage", StatModifier.Mode.MULT, 10.0)
	t.eq(Glossary.mod_text(pct), "伤害 +10%", "乘算（133：不再写乘区名）")
	t.eq(Glossary.strip_bbcode("[b]x[/b][color=#fff]y[/color]"), "xy", "剥标签")
	# 107：「开战时」「自发」的 tip 关了，只剩传进来的血怒
	var found := Glossary.terms_in("开战时获得血怒，自发出手", {"血怒": "详"})
	t.eq(found.size(), 1, "只剩血怒一个词条：%s" % str(found))
	t.eq(String(found[0]["name"]), "血怒", "传进来的（buff 词条）照旧")
	var kept := Glossary.terms_in("护甲顶住了直接伤害", {})
	t.eq(kept.size(), 2, "带规则的词照旧弹（护甲、直接伤害）：%s" % str(kept))
	var marked := Glossary.mark("血怒 与 血怒", [{"name": "血怒", "text": ""}])
	t.eq(marked.count("[u]血怒[/u]"), 2, "每处都标")
	# 开战 buff 进预估 DPS：匕首 + 蛮神的护符（信力一阶）
	var board := GridInventory.new(Vector2i(4, 4), 0, false)
	var k := TestSupport.put(board, c.items.get_def(&"knife"))
	var sg := TestSupport.put(board, c.items.get_def(&"charm_brute"))
	t.check(k != null and sg != null, "匕首和护符都放下")
	var plain := BattleCompiler.compile_board(board)
	var tiered := BattleCompiler.compile_board(board, null, [] as Array[StatModifier], [] as Array[AbilityRule], {&"faith:brute": 1})
	t.check(plain.opening_mods().is_empty() and plain.opening_axes().is_empty(), "没过阈值：没有开战 buff")
	t.eq(tiered.opening_axes().size(), 2, "过了一阶：开战血怒带两条轴（152：强攻、加速）")
	t.check(tiered.rough_dps() > plain.rough_dps() * 1.05, "预估 DPS 算上血怒：%.2f > %.2f" % [tiered.rough_dps(), plain.rough_dps()])
	t.check(is_equal_approx(tiered.estimated_dps_of(tiered.item_of(k.uid)), tiered.rough_dps()), "只有匕首出手")



static func run_dormant_faith(t: TestCase) -> void:
	t.begin("087 · 信仰道具休眠时保留通用效果：赐福盾的护甲照给、信力加成与邻接不给；护符（没有 combat）彻底失效；dormant_keeps_combat=false 彻底不参战")
	var c := _content()
	var shield_def := c.items.get_def(&"blessed_shield")
	var bow_def := c.items.get_def(&"blessed_longbow")
	t.check(shield_def.has_faith() and bow_def.has_faith() and shield_def.faith_tag() != bow_def.faith_tag(), "两件不同信仰的赐福之物")
	t.check(FaithState.keeps_combat_when_dormant(shield_def), "盾有战斗定义、默认保留")
	t.check(not FaithState.keeps_combat_when_dormant(c.items.get_def(&"charm_brute")), "蛮神的护符没有 combat：休眠就彻底失效")
	var board := GridInventory.new(Vector2i(10, 8), 0, false)
	var shield := TestSupport.put(board, shield_def)
	var bow := TestSupport.put(board, bow_def)     # 后置入：狩猎之神激活，盾休眠
	if shield == null or bow == null:
		t.check(false, "棋盘上放不下盾和弓")
		return
	t.eq(FaithState.active_tag(board), bow_def.faith_tag(), "激活的是后置入的弓的信仰")
	t.check(FaithState.is_dormant(shield_def, FaithState.active_tag(board)), "盾休眠")
	var spec := BattleCompiler.compile_board(board, null, [] as Array[StatModifier], [] as Array[AbilityRule], {shield_def.faith_tag(): 2, bow_def.faith_tag(): 2})
	var shield_item := spec.item_of(shield.uid)
	t.not_null(shield_item, "休眠的盾仍参战（通用效果）")
	if shield_item != null:
		var armor := StatMath.to_float(shield_item.stats.total_of(BattleStats.BLOCK))
		t.check(is_equal_approx(armor, float(shield_def.combat.base_stats["block"])), "格挡是它自己的基础值 %.0f（信力一阶的 +4 没给）" % armor)
		t.eq(shield_item.rules.size(), shield_def.combat.rules.size(), "只有自己的规则，没有信力加成的规则")
	var bow_item := spec.item_of(bow.uid)
	t.check(bow_item != null and StatMath.to_float(bow_item.stats.total_of(BattleStats.DAMAGE)) > float(bow_def.combat.base_stats["damage"]), "激活的弓吃到了信力加成")
	# 反过来：盾后置入 → 弓休眠，弓照样出手（武器本身的攻击力）
	board.remove(shield.uid)
	t.not_null(TestSupport.put(board, shield), "盾拿起来再放回")
	var spec2 := BattleCompiler.compile_board(board)
	var bow2 := spec2.item_of(bow.uid)
	t.check(bow2 != null and bow2.is_active() and spec2.estimated_dps_of(bow2) > 0.0, "休眠的弓仍出手、有 DPS")
	# 数据说不保留 → 彻底不参战
	var strict := bow_def.duplicate() as ItemDef
	strict.dormant_keeps_combat = false
	var b3 := GridInventory.new(Vector2i(10, 8), 0, false)
	var bow3 := TestSupport.put(b3, strict)
	t.not_null(TestSupport.put(b3, shield_def), "盾后置入")
	if bow3 == null:
		t.check(false, "放不下弓")
		return
	t.is_null(BattleCompiler.compile_board(b3).item_of(bow3.uid), "dormant_keeps_combat=false：休眠就不参战")
	# 107（作者定）：悬浮窗不再写「信仰道具：别的信仰激活时休眠（保留通用效果）」那一行 ——
	# 休眠与否只靠信仰相关行的灰 / 亮区分（那句话留在信仰自己的悬浮窗里）
	t.check(not ItemTooltip.describe(ItemInstance.create(shield_def)).contains("保留通用效果"), "道具悬浮窗不再写休眠说明行")
	var gods := FaithDef.load_all()
	t.check(FaithTooltip.describe(gods.get(&"hunt", null)).contains("休眠"), "休眠的机制说明留在信仰自己的悬浮窗里")


static func run_boss(t: TestCase) -> void:
	t.begin("087 · BOSS：保底一件金色（不看身上有没有）；打倒之后收完战利品直接撤离结算")
	var c := _content()
	var rule: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	t.eq(rule.boss_rarity, 4, "标准规则：BOSS 保底金色")
	var content := {"enemy": "raider", "strength": 0, "items": [{"id": "knife", "at": [0, 0], "rot": 0}]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var normal := DropResolver.roll(content, rule, LootContext.new(), c.items, rng)
	t.check((normal["treasure"] as Array).is_empty(), "普通敌人：珍宝概率 0，没有")
	rng.seed = 7
	var boss := DropResolver.roll(content, rule, LootContext.new(), c.items, rng, true)
	var tr: Array = boss["treasure"]
	t.eq(tr.size(), 1, "BOSS：保底一件")
	if not tr.is_empty():
		var def := c.items.get_def(tr[0])
		t.check(def != null and def.rarity == 4 and not def.is_bag, "是金色（稀有度 4）：%s" % String(tr[0]))
	var none := rule.duplicate() as DropRule
	none.boss_rarity = -1
	rng.seed = 7
	t.check((DropResolver.roll(content, none, LootContext.new(), c.items, rng, true)["treasure"] as Array).is_empty(), "-1 = 不保底")
	var rules: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	t.check(rules.boss_extracts, "标准规则：BOSS 倒下直接撤离")

	# 流程：BOSS 倒下（boss_cleared）→ 战利品屏 → 收起 = 撤离结算
	var f := Support.flow(c, "087")
	var kit := _kit(c)
	var run := f.begin(c.chapter, kit, 3)
	t.not_null(run, "开局")
	if run == null:
		return
	f.pick_spawn(run.map.entry_ids[0])
	t.check(not run.extract_after_boss(), "没打倒 BOSS：撤不了")
	run.boss_cleared = true
	var box := LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(4, 4), c.items)
	run._offer_loot(box)
	f.resume()
	t.eq(f.screen, GameFlow.Screen.LOOT, "先看战利品")
	t.check(f.hide_overlay(), "收起")
	t.check(run.is_over() and run.phase == RunState.Phase.EXTRACTED and run.end_reason == &"boss", "= 直接撤离：局结束、算撤离成功、原因 boss")
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	t.check(f.result != null and f.result.is_extracted(), "结算按撤离算")
	# 存档带着
	var back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and back.boss_cleared, "boss_cleared 跟存档")
	# 规则关掉：收起只是最小化
	var f2 := Support.flow(c, "087")
	var run2 := f2.begin(c.chapter, kit, 3)
	f2.pick_spawn(run2.map.entry_ids[0])
	run2.boss_cleared = true
	run2.node_rules = run2.node_rules.duplicate()
	run2.node_rules.boss_extracts = false
	run2._offer_loot(LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(4, 4), c.items))
	f2.resume()
	t.check(f2.hide_overlay() and f2.screen == GameFlow.Screen.MAP and not run2.is_over(), "boss_extracts=false：收起只是回地图")
	Support.cleanup("087")


static func run_shop_logic(t: TestCase) -> void:
	t.begin("087 · 商店屏的逻辑：栏位是小棋盘、商品只能进自己的容器且钱够、钱不够弹回并提示、双击买、拖进出售区就卖半价")
	var c := _content()
	var f := Support.flow(c, "087")
	var run := f.begin(c.chapter, _kit(c), 3)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var shop_node: MapNode = null
	for id in run.map.node_ids():
		if run.map.get_node(id).type == &"shop":
			shop_node = run.map.get_node(id)
			break
	if shop_node == null:
		t.check(true, "（这个种子没有商店点）")
		Support.cleanup("087")
		return
	run.wallet.earn(1000, &"test")
	run.events.handle(shop_node)
	while f.run.events.pending_event() != null:
		f.choose_event(0)
	var session := run.events.current_shop
	t.not_null(session, "开了店")
	if session == null:
		Support.cleanup("087")
		return
	var screen = load("res://ui/game/shop_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.SHOP
	screen.open({"node": shop_node, "session": session})
	t.eq(screen.shelf_views().size(), session.shelves.size(), "每个栏位一块视图")
	var slot0 := session.item_at(0)
	t.not_null(slot0, "第 0 格有商品")
	if slot0 == null:
		screen.free()
		Support.cleanup("087")
		return
	# 落点过滤
	t.check(screen._allow_drop(slot0, run.board), "钱够：商品能进棋盘")
	t.check(not screen._allow_drop(slot0, session.sell_box), "商品不能进出售区")
	var mine: ItemInstance = run.board.items()[0]
	t.check(not screen._allow_drop(mine, session.shelves[0]), "自己的东西不能放到栏位上")
	t.check(screen._allow_drop(mine, session.sell_box), "自己的东西能进出售区")
	# 审查 A1：没付钱的商品不能拿去合成（会被合成消耗、结不了账 = 白拿）；自己的东西照常能合
	t.check(not bool(screen.drag_layer().craft_filter.call(slot0)), "货架上的商品不许合成")
	screen._dragged_uid = slot0.uid
	screen._dragged_slot = 0
	t.check(not bool(screen.drag_layer().craft_filter.call(slot0)), "拿在手上的商品也不许合成")
	screen._dragged_uid = -1
	screen._dragged_slot = -1
	t.check(bool(screen.drag_layer().craft_filter.call(mine)), "自己的东西许合成")
	# 拖着买：栏位 → 棋盘（模拟拖拽层做的事），放手后结账
	var price0 := int(session.stock[0]["price"])
	var before := run.wallet.balance
	screen._dragged_uid = slot0.uid
	screen._dragged_slot = 0
	session.shelves[0].remove(slot0.uid)
	t.check(run.board.try_add(slot0, true) or run.storage.admit(slot0), "商品进了玩家的容器")
	screen._on_drag_finished(slot0.uid, true)
	t.eq(run.wallet.balance, before - price0, "放手时扣钱")
	t.check(session.sold.has(0), "第 0 格卖掉了")
	t.check(screen.line_text().contains("买下了"), "提示买下了")
	# 钱不够：过滤拦住、提示
	var poor_slot := -1
	for i in session.stock.size():
		if not session.sold.has(i):
			poor_slot = i
			break
	if poor_slot >= 0:
		var inst := session.item_at(poor_slot)
		run.wallet.spend(run.wallet.balance, &"test")
		t.check(not screen._allow_drop(inst, run.board), "钱不够：商品放不进棋盘（弹回栏位）")
		t.check(screen.line_text().contains("金币不足"), "提示金币不足")
		t.check(not screen.quick_buy(inst.uid), "双击也买不了")
		t.check(session.item_at(poor_slot) == inst, "商品还在栏位上")
		run.wallet.earn(1000, &"test")
		# 双击买：进包 / 地上
		var b2 := run.wallet.balance
		t.check(screen.quick_buy(inst.uid), "双击买")
		t.eq(run.wallet.balance, b2 - int(session.stock[poor_slot]["price"]), "扣钱")
		t.check(run.board.has_item(inst.uid) or run.storage.has_item(inst.uid), "东西进了包或地上")
		t.check(session.item_at(poor_slot) == null, "栏位空了")
	# 卖：把自己的东西拖进出售区
	var sell_me := ItemInstance.create(c.items.get_def(&"longsword"))
	run.storage.admit(sell_me)
	run.storage.remove(sell_me.uid)
	session.sell_box.place(sell_me, Vector2i.ZERO, 0)
	var b3 := run.wallet.balance
	screen._on_drag_finished(sell_me.uid, true)
	t.eq(run.wallet.balance, b3 + session.sell_price_of(sell_me.def), "卖了：回定价的一半")
	t.check(not session.sell_box.has_item(sell_me.uid), "出售区清了")
	t.check(screen.line_text().contains("卖掉了"), "提示卖掉了")
	screen.free()
	Support.cleanup("087")


static func frame_buff_chips(t: TestCase, root: Window) -> void:
	t.begin("087 · 战斗面板的 buff 图标：一个字 + 层数、鼠标压上去发 buff_hovered、回放层开悬浮窗写效果")
	var c := _content()
	var panel := CombatantPanel.new()
	panel.label_font = UiPalette.cjk_font()
	panel.display_name = "我"
	root.add_child(panel)
	panel.size = Vector2(320, 190)
	var defs := Glossary.buffs_in_item(c.items.get_def(&"poisoned_knife"))
	t.check(defs.has(&"poison"), "从涂毒匕首收集到中毒")
	panel.buff_defs = defs
	panel.reset({"resources": {"hp": [10, 10]}})
	panel.set_stacks("poison", 3)
	t.eq(panel.icon_of("poison"), "中", "图标是名字的第一个字")
	t.eq(panel.icon_of("nope"), "n", "没有定义的用 id 的第一个字")
	panel._draw()     # 直接画一遍，算出图标的矩形
	var chips: Array = panel._chips
	t.eq(chips.size(), 1, "一个图标")
	if chips.is_empty():
		panel.queue_free()
		return
	var rect: Rect2 = chips[0][0]
	t.eq(panel.chip_at(rect.get_center()), "poison", "压在图标上认得出是谁")
	t.eq(panel.chip_at(Vector2(-5, -5)), "", "别处不算")
	var hovered: Array = []
	panel.buff_hovered.connect(func(id: String, _at: Vector2): hovered.append(id))
	var mm := InputEventMouseMotion.new()
	mm.position = rect.get_center()
	panel._gui_input(mm)
	t.eq(hovered, ["poison"], "发了 buff_hovered")
	# 回放层：悬浮窗写效果
	var view := BattleView.new()
	view.label_font = UiPalette.cjk_font()
	root.add_child(view)
	view.set_buff_defs(defs)
	view._on_buff_hovered("poison", Vector2(10, 10))
	t.check(view._tip.is_showing() and view._tip.text().contains("中毒") and view._tip.text().contains("永续"), "悬浮窗写着中毒的效果")
	view._on_buff_unhovered()
	t.check(not view._tip.is_showing(), "移开就收")
	var spec_defs := Glossary.buffs_in_spec(BattleCompiler.compile_board(LootPacker.board_of([&"poisoned_knife"] as Array[StringName], Vector2i(4, 4), c.items)))
	t.check(spec_defs.has(&"poison"), "从战斗单位也收集得到")
	panel.queue_free()
	view.queue_free()


static func run_death_is_final(t: TestCase) -> void:
	t.begin("087 · 倒下是终局：血到 0 记死，伤药的濒死回血救不回来，只发一次 DIED，回放里不会倒下两次")
	var c := _content()
	var me := BattleCompiler.compile_board(LootPacker.board_of([&"longsword"] as Array[StringName], Vector2i(4, 4), c.items), CombatantBaseline.with_hp(200.0))
	# 对手：一把匕首 + 两瓶伤药（血低于 40% 回 25），血 12 —— 长剑一下就打到 0
	var foe := BattleCompiler.compile_board(LootPacker.board_of([&"knife", &"salve", &"salve"] as Array[StringName], Vector2i(4, 4), c.items), CombatantBaseline.with_hp(12.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var res := BattleSim.run(me, foe, rng, 60.0)
	var died := 0
	var died_at := -1
	var healed_after := 0
	for ev in res.log:
		var e := ev as BattleEvent
		if e.side != 1:
			continue
		if e.name == BattleEvent.DIED:
			died += 1
			died_at = e.time
		elif died_at >= 0 and e.name == BattleEvent.RESOURCE_CHANGED and e.get_name(&"key") == &"hp" and e.get_int(&"delta") > 0:
			healed_after += 1
	t.eq(died, 1, "对手只倒下一次")
	t.eq(healed_after, 0, "倒下之后没有再被治回来")
	t.eq(res.winner, 0, "我赢")
	var final_sides: Array = res.final.get("sides", [])
	if final_sides.size() == 2:
		var hp_pair: Array = (final_sides[1]["resources"] as Dictionary).get("hp", [0, 0])
		t.eq(int(hp_pair[0]), 0, "终局快照里对手血是 0")
	# 直接验运行时：记死之后 is_alive 假、再改血不动
	var rt := CombatantRuntime.from_spec(foe, 1)
	t.check(rt.is_alive(), "活着")
	rt.resources.change(&"hp", -10000, &"test")
	t.check(rt.mark_dead() and not rt.mark_dead(), "mark_dead 第一次真、第二次假")
	t.check(not rt.is_alive() and rt.dead, "死了")


static func run_enemy_identity(t: TestCase) -> void:
	t.begin("087 · 敌人身份决定道具：只从带身份标签的道具里抽，神射手按档位换弓；导入器拦招牌不在身份圈里的")
	var c := _content()
	var pool := c.enemies.pool(c.chapter.enemy_pool)
	var checked := 0
	for eid in TestSupport.enemy_ids():
		var def := c.enemies.enemy(eid)
		if def == null or def.item_tags.is_empty():
			continue
		for strength in 4:
			for seed in 3:
				var rng := RandomNumberGenerator.new()
				rng.seed = seed * 31 + strength
				var built := EnemyPlacer.build_content(def, pool, c.items, strength, rng)
				var content: Dictionary = built["content"]
				var armed := false
				for raw in content.get("items", []):
					var idef := c.items.get_def(StringName(String(raw["id"])))
					if idef == null or idef.is_bag:
						continue
					checked += 1
					t.check(def.allows_item(idef), "%s（%d 档）背的「%s」带身份标签 %s" % [def.display_name, strength, idef.display_name, str(def.item_tags)])
					if idef.tags.has(&"weapon"):
						armed = true
				t.check(armed, "%s（%d 档）有武器" % [def.display_name, strength])
				for sid in def.signature_at(strength):
					var has := false
					for raw in content.get("items", []):
						if StringName(String(raw["id"])) == sid:
							has = true
					t.check(has, "%s（%d 档）带着这一档的招牌「%s」" % [def.display_name, strength, sid])
	t.check(checked > 30, "查了 %d 件" % checked)
	var marks := c.enemies.enemy(&"marksman")
	t.eq(marks.signature_at(0), [&"shortbow"] as Array[StringName], "神射手 0 档：短弓")
	t.eq(marks.signature_at(1), [&"longbow"] as Array[StringName], "1 档：长弓")
	t.eq(marks.signature_at(3), [&"blessed_longbow"] as Array[StringName], "3 档：取 ≤ 档位的最高一档 → 赐福的长弓")
	t.check(not marks.allows_item(c.items.get_def(&"knife")) and marks.allows_item(c.items.get_def(&"arrows")), "神射手不背匕首、背箭矢")
	# 导入器
	var data := ContentExporter.export_enemy(marks)
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.items[id] = c.items.get_def(id)
	var report := ImportReport.new()
	ContentImporter.import_enemy(data, ctx, report)
	t.check(report.ok(), "神射手的数据校验通过：%s" % report.to_text())
	data["signature"] = ["knife"]
	var bad := ImportReport.new()
	ContentImporter.import_enemy(data, ctx, bad)
	t.check(not bad.ok(), "招牌不在身份圈里：拦")
	var back := ContentImporter.import_enemy(ContentExporter.export_enemy(marks), ctx, ImportReport.new())
	t.eq(back.item_tags, marks.item_tags, "item_tags 往返")
	t.eq(back.signature_at(2), marks.signature_at(2), "signature_by_strength 往返")


static func run_bags_move(t: TestCase) -> void:
	t.begin("087 · 包能放到地上（内容物打散跟着进）、放进自由容器（内容物脱落到地上）")
	var c := _content()
	ItemInstance.reset_uid_counter()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	var stash := ItemStash.new(2, 0)
	var box := GridInventory.new(Vector2i(6, 4), 3, false)
	var bag := ItemInstance.create(c.items.get_def(&"bag_leather"))
	board.place(bag, Vector2i(0, 0), 0)
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	board.place(knife, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	var sview := GroundLayer.new()     # 128：一块地
	sview.stash = stash
	sview.position = Vector2(500, 0)
	sview.size = Vector2(400, 300)
	var bview := InventoryView.new()
	bview.inventory = box
	bview.position = Vector2(0, 400)
	bview.size = Vector2(box.size) * InventoryView.CELL
	var drag := DragLayer.new()
	drag.register_view(view)
	drag.register_view(sview)
	drag.register_view(bview)
	drag.stash = stash
	var shed: Array = []
	drag.items_shed.connect(func(items: Array): shed.append(items.size()))
	# 包 → 地上
	view.grab_requested.emit(view, bag.uid, Vector2(10, 10))
	t.check(drag.is_dragging() and board.item_count() == 0, "抓起带东西的包")
	var row_at := sview.position + Vector2(20, 10)
	drag.update_preview(row_at)
	t.check(drag.drop_at(row_at), "放到地上：成")
	t.check(stash.has_item(bag.uid) and stash.has_item(knife.uid), "包和匕首都在地上（打散成两行）")
	t.eq(shed, [1], "发了 items_shed：匕首脱落")
	# 地上 → 棋盘（空包）→ 再放刀 → 包 → 自由容器
	sview.grab_requested.emit(sview, bag.uid, Vector2(10, 10))
	var at := (Vector2(0, 0) + Vector2(0.5, 0.5)) * InventoryView.CELL
	drag.update_preview(at)
	t.check(drag.drop_at(at), "包放回棋盘")
	sview.grab_requested.emit(sview, knife.uid, Vector2(10, 10))
	drag.update_preview(at)
	t.check(drag.drop_at(at), "匕首放回包里")
	view.grab_requested.emit(view, bag.uid, Vector2(10, 10))
	var box_at := bview.position + at
	drag.update_preview(box_at)
	t.check(bview._preview_valid and bview._preview_costly, "预览：能放进自由容器、标着有代价（内容物脱落）")
	t.check(drag.drop_at(box_at), "放进自由容器：成")
	t.check(box.has_item(bag.uid) and stash.has_item(knife.uid), "包在容器里、匕首脱落到了地上")
	t.eq(shed.size(), 2, "又发了一次 items_shed")
	for v in [view, sview, bview]:
		v.free()
	drag.free()


static func run_loot_on_bags(t: TestCase) -> void:
	t.begin("087 · 尸体容器照敌人的棋盘摆：包在原位当背景、道具在包上；包不用探明，上面有没亮的时拖不走；没亮的不画名字")
	var c := _content()
	var content := {"enemy": "raider", "strength": 0, "board": [5, 3],
		"items": [{"id": "bag_leather", "at": [0, 0], "rot": 0}, {"id": "knife", "at": [0, 0], "rot": 0}, {"id": "shortsword", "at": [1, 0], "rot": 1}]}
	var rolled := {"dropped": [&"bag_leather", &"knife", &"shortsword"] as Array[StringName], "treasure": [] as Array[StringName]}
	var corpse := DropResolver.corpse_of(content, rolled, c.items)
	t.check(corpse.requires_bag, "掉了包：容器是棋盘模式")
	t.eq(corpse.item_count(), 3, "三件都在")
	var bag_uid := corpse.bag_at(Vector2i(0, 0))
	t.check(bag_uid != GridInventory.EMPTY_UID, "包在原位")
	t.eq(corpse.contents_of(bag_uid).size(), 2, "两件道具摆在包上")
	var view := LootView.new()
	view.inventory = corpse
	t.check(view.is_revealed(bag_uid), "包一开始就亮着（不用探明）")
	t.check(view.is_locked(bag_uid), "上面有没亮的：包拖不走")
	var hidden: ItemInstance = null
	for inst in corpse.items():
		if (inst as ItemInstance).uid != bag_uid:
			hidden = inst
			break
	t.check(not view._label_visible(hidden), "没亮的不画名字")
	t.check(view._label_visible(corpse.get_item(bag_uid)), "包画名字")
	view.reveal_all()
	t.check(not view.is_locked(bag_uid) and view._label_visible(hidden), "全亮了：包能拖走、名字画出来")
	# 没掉包：老路（自由容器）
	var plain := DropResolver.corpse_of(content, {"dropped": [&"knife"] as Array[StringName], "treasure": [] as Array[StringName]}, c.items)
	t.check(not plain.requires_bag and plain.item_count() == 1, "没掉包：自由容器")
	view.free()


static func run_faith_tooltip(t: TestCase) -> void:
	t.begin("087 · 信仰的悬浮说明：神、说明、信力怎么涨、阈值与现在几阶、这个信仰的道具各阶解锁什么")
	var c := _content()
	var defs := FaithDef.load_all()
	var skill: FaithDef = defs.get(&"skill", null)
	t.not_null(skill, "技巧之神")
	if skill == null:
		return
	var text := FaithTooltip.describe(skill, null, c.items)
	t.check(text.contains("技巧之神") and text.contains("信力怎么涨") and text.contains(skill.deeds_summary()), "写了名字与信力怎么涨")
	t.check(text.contains("阈值：25、80"), "写了阈值")
	t.check(text.contains("技巧之神赐福的盾牌") and text.contains("Lv.1"), "列了这个信仰的道具与各阶")
	t.check(FaithTooltip.describe(null).contains("没有信仰"), "没激活时也有话说")


static func run_rarity_fill_and_tooltips(t: TestCase) -> void:
	t.begin("087 · 稀有度是整格底色（不靠边框）、字色按底色明暗；容器视图自己挂悬浮窗")
	var c := _content()
	var white := c.items.get_def(&"knife")
	var purple := c.items.get_def(&"blessed_shield")
	t.check(ItemPainter.body_color(white).get_luminance() > 0.5, "白色道具底色亮")
	t.check(ItemPainter.label_color(white).get_luminance() < 0.3, "亮底配深字")
	t.check(ItemPainter.label_color(purple).get_luminance() > 0.6, "紫底配浅字")
	var d := ItemPainter.body_color(purple)
	var r := ItemPainter.rarity_color(purple)
	t.check(absf(d.h - r.h) < 0.02, "底色就是稀有度的色相")
	t.check(InventoryView.CELL >= 60.0, "格子放大到 %d" % int(InventoryView.CELL))


static func frame_auto_tooltip(t: TestCase, root: Window) -> void:
	t.begin("087 · 容器视图进树之后自己找 / 造悬浮窗：仓库、结算屏也能停上去看")
	var c := _content()
	var host := Control.new()
	root.add_child(host)
	var inner := VBoxContainer.new()
	host.add_child(inner)
	var box := LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(4, 4), c.items)
	var view := InventoryView.new()
	view.inventory = box
	inner.add_child(view)
	var tip := HoverTip.ensure_for(view)
	t.check(tip != null and tip.get_parent() == host, "最顶层的 Control 祖先下造了一个悬浮窗")
	var view2 := InventoryView.new()
	view2.inventory = box
	inner.add_child(view2)
	var tip2 := HoverTip.ensure_for(view2)
	t.check(tip2 == tip, "第二个视图复用同一个，不再造")
	var tips := 0
	for ch in host.get_children():
		if ch is HoverTip:
			tips += 1
	t.eq(tips, 1, "只有一个悬浮窗")
	# 屏自己造了悬浮窗的：找到它，不另造
	var screen := Control.new()
	root.add_child(screen)
	var own := HoverTip.new()
	screen.add_child(own)
	var view3 := InventoryView.new()
	view3.inventory = box
	screen.add_child(view3)
	t.check(HoverTip.ensure_for(view3) == own, "屏自己的悬浮窗优先")
	host.queue_free()
	screen.queue_free()


static func run_names_and_hunters_and_mana(t: TestCase) -> void:
	t.begin("088 · 多语言名字 Names.of（en 有就用、没有回落 display_name）；输给猎手也扣体力；默认难度没有猎手；power 并进 mana")
	var c := _content()
	var knife := c.items.get_def(&"knife")
	var before := UiText.lang
	UiText.lang = "zh"
	t.eq(Names.of(knife), "匕首", "中文：display_name")
	UiText.lang = "en"
	t.eq(Names.of(knife), "Knife", "英文：display_names.en")
	t.eq(Names.of(knife, "zh"), "匕首", "指定语言")
	var bare := ItemDef.new()
	bare.display_name = "只有中文"
	t.eq(Names.of(bare), "只有中文", "没写英文名回落 display_name")
	t.eq(Names.of(null), "", "null 空串")
	t.check(Names.has(knife, "en") and not Names.has(bare, "en"), "has")
	var faiths := FaithDef.load_all()
	t.eq(Names.of(faiths[&"skill"]), "God of Skill", "信仰也有英文名")
	var marks := c.enemies.enemy(&"marksman")
	t.eq(Names.of(marks), "Marksman", "敌人也有英文名")
	var poisoned := c.items.get_def(&"poisoned_knife")
	var buffs := Glossary.buffs_in_item(poisoned)
	t.eq(Names.of(buffs[&"poison"]), "Poison", "道具里内联的 buff 也有英文名")
	var full := ItemTooltip.describe_full(ItemInstance.create(poisoned))
	var plain_en := Glossary.strip_bbcode(String(full["text"]))
	t.check(plain_en.contains("Poisoned Knife") and plain_en.contains("施加Poison"), "悬浮窗按当前语言写名字：%s" % plain_en.replace("\n", " / "))
	UiText.lang = before
	# 往返
	var back := ContentImporter.import_item(ContentExporter.export_item(knife), ContentImporter.Context.new(), ImportReport.new())
	t.eq(back.display_names, knife.display_names, "display_names 走管线往返")
	# 猎手
	var rules: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	t.eq(rules.loss_cost_of(&"hunter"), 1, "输给猎手扣 1 体力（数据）")
	t.eq(NodeRules.new().loss_cost_of(&"hunter"), 1, "默认表里也有")
	var normal: DifficultyDef = load(ContentPaths.asset_file("difficulties", "normal"))
	var has_hunters := false
	for m in normal.mechanics:
		if String(ContentSchema.registry_name_of(m)) == "hunters":
			has_hunters = true
	t.check(not has_hunters, "普通难度没有猎手机制：猎手要在难度里额外配")
	var diffs := GameFlow.load_difficulties()
	t.check(not diffs.is_empty() and diffs[0].id == &"normal", "难度列表第一个是普通（开局屏默认选它）")
	# mana
	var battery := c.items.get_def(&"battery")
	t.check(battery.combat.base_stats.has("max_mana") and not battery.combat.base_stats.has("max_power"), "电池给 max_mana")
	t.check(c.items.get_def(&"fire_crystal").combat == null, "148：魔晶石不再给魔力")
	t.check(not UiPalette.RESOURCE_COLORS.has("power"), "没有 power 资源的颜色了")


static func run_spyglass_and_codex(t: TestCase) -> void:
	t.begin("088 · 望远镜：序章二开局发的特殊道具 —— 不进背包、图鉴点亮、开节点浮窗（以后每一局都开）、不能生成；基地两个页签：仓库 / 图鉴")
	var c := _content()
	var spy := c.items.get_def(&"spyglass")
	t.check(spy != null and spy.is_keepsake() and spy.tags.has(&"node_tooltips"), "望远镜是特殊道具、带 node_tooltips 标签")
	t.check(not c.items.ids().has(&"spyglass") and c.items.keepsake_ids().has(&"spyglass"), "不在能生成的 id 里、在特殊道具里")
	var econ: EconomyRules = load(ContentPaths.asset_file("economy_rules", "standard"))
	t.check(not ShopSession.candidates(econ, c.items).has(&"spyglass"), "商店不卖")
	var rules: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	t.check(not SearchSession.candidates(rules.search, c.items).has(&"spyglass"), "搜不出来")
	var p2: ChapterDef = load(ContentPaths.asset_file("chapters", "prologue_2"))
	t.check(p2.starting_keepsakes.has(&"spyglass") and not p2.node_tooltips, "序章二靠望远镜开浮窗，不靠章节开关")
	# 局外：拿到 → 存读 → 第一章也开着浮窗
	var f := Support.flow(c, "087")
	f.chapters = [c.chapter, p2] as Array[ChapterDef]
	f.characters = GameFlow.load_characters()
	f.event_defs = c.events
	var run := f.begin_direct(p2, 2)
	t.not_null(run, "开序章二")
	if run == null:
		Support.cleanup("087")
		return
	t.check(f.meta.has_keepsake(&"spyglass"), "开局拿到了望远镜")
	t.check(f.has_ability(&"node_tooltips") and f.tooltips_enabled(), "浮窗开着（靠能力）")
	var notes := f.take_notes()
	t.check(notes.size() == 1 and notes[0].contains("望远镜"), "有一句通知：%s" % str(notes))
	t.check(f.take_notes().is_empty(), "通知取走就没了")
	var board_items := 0
	for inst in run.board.items():
		if (inst as ItemInstance).def.id == &"spyglass":
			board_items += 1
	t.eq(board_items, 0, "不进背包")
	var back := MetaState.from_dict(f.meta.to_dict(), c.items)
	t.check(back != null and back.has_keepsake(&"spyglass"), "跟局外存档")
	f.to_main_menu()
	RunSave.remove(SAVE)
	var run2 := f.begin(c.chapter, _kit(c), 3)
	t.check(run2 != null and f.tooltips_enabled(), "之后开第一章：浮窗也开着（能力是局外的）")
	t.check(f.take_notes().is_empty(), "已经有了不再通知")
	# 没拿过的一张白纸：第一章关着
	var f2 := Support.flow(c, "087")
	f2.begin(c.chapter, _kit(c), 3)
	t.check(not f2.tooltips_enabled(), "没拿过望远镜：第一章浮窗关")
	# 基地页签
	f2.meta.codex["knife"] = 3
	f2.meta.codex["longsword"] = 1
	f2.meta.grant_keepsake(&"spyglass")
	f2.to_main_menu()
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f2
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	screen.open({})
	t.eq(screen.tab(), "warehouse", "默认在仓库页")
	screen.show_tab("codex")
	t.eq(screen.tab(), "codex", "切到图鉴页")
	t.check(screen._pages["codex"].visible and not screen._pages["warehouse"].visible, "只显示图鉴页")
	var tiles: Array = screen.codex_tiles()
	t.eq(tiles.size(), c.items.ids(true).size() + c.items.keepsake_ids().size(), "每件能获得的道具（含 091 锁着的）+ 特殊道具各一格缩略图（089）")
	var lit_n := 0
	var knife_tile: CodexTile = null
	var spy_tile: CodexTile = null
	for tile in tiles:
		if (tile as CodexTile).lit:
			lit_n += 1
		if (tile as CodexTile).def.id == &"knife":
			knife_tile = tile
		if (tile as CodexTile).def.id == &"spyglass":
			spy_tile = tile
	t.eq(lit_n, 3, "点亮的：匕首、长剑、望远镜；其余灰的")
	t.check(knife_tile != null and knife_tile.lit and knife_tile.count == 3, "匕首那格亮着、累计 3")
	t.check(spy_tile != null and spy_tile.lit, "望远镜那格亮着（特殊道具）")
	screen._on_tile_hovered(knife_tile)
	t.check(screen._codex_tip.is_showing() and screen._codex_tip.text().contains("匕首"), "停在亮的格子上：完整说明")
	var dark_tile: CodexTile = null
	for tile in tiles:
		if not (tile as CodexTile).lit:
			dark_tile = tile
			break
	screen._on_tile_hovered(dark_tile)
	t.check(screen._codex_tip.text().contains("未获得"), "停在灰的格子上：只写未获得")
	screen.show_tab("nope")
	t.eq(screen.tab(), "warehouse", "不认识的页签回仓库")
	screen.free()
	Support.cleanup("087")


static func run_loss_cost_bound_to_battle(t: TestCase) -> void:
	t.begin("088 · 战败代价跟战斗绑定：参数写了用参数（0 无代价 / -2 必死 / 大于 1）；没写看节点内容 loss_cost；再没有核心必死、其余按规则表；跟战前准备屏的存档")
	var W := preload("res://tests/run/test_node_events.gd")
	var w = W._world(200, 9, false)     # 弱玩家：必输
	var ev: NodeEvents = w.events
	var battle: MapNode = W._node(w, &"battle")
	t.eq(ev.loss_cost_for(&"battle", {}), w.rules.loss_cost_of(&"battle"), "没写：按规则表")
	t.eq(ev.loss_cost_for(&"core", {}), NodeEvents.LOSS_DEATH, "核心没写：必死")
	t.eq(ev.loss_cost_for(&"battle", {"loss_cost": 3}), 3, "节点内容写了：用内容的")
	t.eq(ev.loss_cost_for(&"core", {"loss_cost": 0}), 0, "核心也能写成无代价")
	t.eq(ev.loss_cost_for(&"battle", {"loss_cost": 3}, 5), 5, "参数写了：参数优先")
	var lost: Array = []
	ev.defeated.connect(func(why: StringName): lost.append(why))
	# 无代价
	var v0: int = w.vitality.current
	ev.fight_content(battle, &"battle", battle.content, null, 0)
	t.eq(w.vitality.current, v0, "写了 0：输了不扣")
	# 大于 1
	ev.fight_content(battle, &"battle", battle.content, null, 3)
	t.eq(w.vitality.current, v0 - 3, "写了 3：扣 3")
	# 节点内容里写
	var content := battle.content.duplicate(true)
	content["loss_cost"] = 2
	ev.fight_content(battle, &"battle", content)
	t.eq(w.vitality.current, v0 - 5, "内容里写 2：扣 2")
	t.check(lost.is_empty(), "还没战败")
	# 必死
	ev.fight_content(battle, &"battle", battle.content, null, NodeEvents.LOSS_DEATH)
	t.eq(lost, [&"fatal_loss"] as Array[StringName], "写了必死：直接战败（原因 fatal_loss）")
	t.eq(w.vitality.current, v0 - 5, "必死不走 spend")
	# 战前准备屏：代价跟着 pending_battle 存
	var w2 = W._world(300, 9, false)
	var ev2: NodeEvents = w2.events
	ev2.pause_before_battle = true
	var b2: MapNode = W._node(w2, &"battle")
	ev2._battle_at(b2, &"battle", b2.content, "node", 4)
	t.eq(int(ev2.pending_battle.get("loss_cost", -99)), 4, "等着开打的一场记着代价")
	var v2: int = w2.vitality.current
	t.check(ev2.start_pending_battle(), "开战")
	t.eq(w2.vitality.current, v2 - 4, "打输扣的是记着的 4")
	# 猎手定义的默认值
	t.eq(HunterDef.new().loss_cost, -1, "猎手默认按规则表")


static func run_save_slots(t: TestCase) -> void:
	t.begin("089 · 三个存档位：新的游戏 = 挑空位开新存档；继续 = 读当前位；读取存档 = 换位；删除；老的单文件搬进第 1 位；满了去读取存档屏")
	var c := _content()
	var root := "user://test_089_slots"
	var slots := SaveSlots.new(root)
	for n in range(1, SaveSlots.COUNT + 1):
		slots.remove(n)
	t.check(not slots.any() and slots.first_empty() == 1, "一开始全空")
	# 老的单文件搬家
	var legacy_run := "user://test_089_legacy_run.json"
	var legacy_meta := "user://test_089_legacy_meta.json"
	var old := MetaState.new()
	old.runs = 7
	MetaSave.write(old, legacy_meta)
	t.check(slots.migrate_legacy(legacy_run, legacy_meta), "搬进第 1 位")
	t.check(slots.exists(1) and not FileAccess.file_exists(legacy_meta), "第 1 位有了、老文件没了")
	t.eq(int(slots.summary(1, c.items)["runs"]), 7, "摘要读得出第几局")
	t.check(not slots.migrate_legacy(legacy_run, legacy_meta), "再搬没东西")
	# 流程
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.loadouts = c.loadouts
	f.event_defs = c.events
	f.settings_path = "user://test_089_settings.json"
	f.player_baseline = CombatantBaseline.with_hp(10000.0)
	f.slots = slots
	f.use_slot(1)
	t.check(f.slot == 1 and f.meta.runs == 7 and f.save_path == slots.run_path(1), "切到第 1 位：路径与局外都是它的")
	t.check(f.profile_exists(), "当前位有存档：主菜单显示「继续」")
	t.check(f.settings.save_slot == 1, "设置记着当前位")
	# 新的游戏：挑空位（第 2 位）
	t.check(f.start_new_game(), "新的游戏")
	t.check(f.slot == 2 and f.meta.runs == 0 and slots.exists(2), "开在第 2 位、一份新的局外、落了地")
	t.check(f.screen == GameFlow.Screen.SETUP or f.run != null, "开了局（开局屏或直接开）")
	t.check(slots.exists(1) and int(slots.summary(1, c.items)["runs"]) == 7, "第 1 位没被动")
	# 读取存档：回第 1 位
	f.to_main_menu()
	t.check(f.load_slot(1), "读第 1 位")
	t.check(f.slot == 1 and f.meta.runs == 7, "回到第 1 位的局外")
	t.check(not f.load_slot(3), "空位读不了")
	# 满了：新的游戏去读取存档屏
	f.to_main_menu()
	t.check(f.new_game_in(3), "第 3 位开新的")
	f.to_main_menu()
	t.check(not slots.any() == false and slots.first_empty() == -1, "三位都满了")
	t.check(not f.start_new_game() and f.screen == GameFlow.Screen.SLOTS and bool(f.last_payload.get("full", false)), "新的游戏 → 读取存档屏、提示满了")
	# 删除
	f.delete_slot(2)
	t.check(not slots.exists(2) and slots.first_empty() == 2, "删了第 2 位")
	f.delete_slot(f.slot)
	t.check(f.meta.runs == 0 and not f.profile_exists(), "删当前位：局外换成空的、菜单不显示继续")
	# 读取存档屏
	var screen = load("res://ui/game/slots_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.SLOTS
	screen.open({"full": true})
	t.check(screen._hint.text.contains("满"), "满了的提示")
	t.check(not screen.delete_slot(1), "第一次点删除只是武装")
	t.eq(screen.armed_delete(), 1, "记着要删第 1 位")
	t.check(screen.delete_slot(1), "第二次删了")
	t.check(not slots.exists(1), "第 1 位空了")
	screen.free()
	for n in range(1, SaveSlots.COUNT + 1):
		slots.remove(n)
	GameSettings.remove("user://test_089_settings.json")

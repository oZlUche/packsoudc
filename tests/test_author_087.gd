## 作者第十一批（报告 087）：稀有度六色、词条侧窗、武器耗耐力、信仰道具休眠保留通用效果、预估 DPS 算开战 buff、
## BOSS 保底金色 + 直接撤离、商店拖着买 / 卖、战斗 buff 图标栏。合成改相邻自动在 test_tutorial2 里验。
extends RefCounted

const NodeScreens := preload("res://tests/test_node_screens.gd")
const SAVE := "user://test_087_run.json"
const META := "user://test_087_meta.json"
const SETTINGS := "user://test_087_settings.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var loadouts: Array[LoadoutDef]
	var events: Dictionary


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.loadouts = GameFlow.load_loadouts()
	c.events = GameFlow.load_events()
	return c


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _flow(c: Content) -> GameFlow:
	_cleanup()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.loadouts = c.loadouts
	f.event_defs = c.events
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	f.player_baseline = CombatantBaseline.with_hp(10000.0)
	return f


static func _kit(c: Content) -> LoadoutDef:
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
	var sigil := ItemInstance.create(c.items.get_def(&"strength_sigil"))
	var full := ItemTooltip.describe_full(sigil)
	var text := String(full["text"])
	var terms: Array = full["terms"]
	t.check(text.contains("血怒"), "主文字里有「血怒」")
	t.check(not Glossary.strip_bbcode(text).contains("+10%"), "主文字里不直接写伤害 +10%")
	var names: Array[String] = []
	var blood := ""
	for term in terms:
		names.append(String(term["name"]))
		if String(term["name"]) == "血怒":
			blood = String(term["text"])
	t.check(names.has("血怒"), "词条里有血怒：%s" % str(names))
	t.check(blood.contains("+10%") and blood.contains("持续 10.0 秒"), "血怒的词条写着增伤 +10%%、持续 10 秒：%s" % blood)
	t.check(names.has("开战时") and names.has("信力"), "固定词条也在（开战时、信力）")
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
	t.check(knames.has("自发") and knames.has("耗耐力"), "匕首的词条：自发、耗耐力：%s" % str(knames))
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
	t.eq(Glossary.mod_text(_mod(&"damage", 10, -1, 0.0)), "伤害 +10", "固定值")
	var pct := _mod(&"damage", 0.0, StatMath.Buff.EMPOWER, 10)
	t.eq(Glossary.mod_text(pct), "增伤 +10%", "乘区")
	t.eq(Glossary.strip_bbcode("[b]x[/b][color=#fff]y[/color]"), "xy", "剥标签")
	var found := Glossary.terms_in("开战时获得血怒，自发出手", {"血怒": "详"})
	t.eq(found.size(), 3, "找到三个词条")
	t.eq(String(found[0]["name"]), "开战时", "按出现顺序")
	var marked := Glossary.mark("血怒 与 血怒", [{"name": "血怒", "text": ""}])
	t.eq(marked.count("[u]血怒[/u]"), 2, "每处都标")
	# 开战 buff 进预估 DPS：匕首 + 力量的符号（信力一阶）
	var board := GridInventory.new(Vector2i(4, 4), 0, false)
	var k := ItemInstance.create(c.items.get_def(&"knife"))
	var sg := ItemInstance.create(c.items.get_def(&"strength_sigil"))
	board.place(k, Vector2i(0, 0), 0)
	board.place(sg, Vector2i(1, 0), 0)
	var plain := BattleCompiler.compile(board)
	var tiered := BattleCompiler.compile(board, null, [] as Array[StatModifier], [] as Array[AbilityRule], {&"faith:violence": 1})
	t.check(plain.opening_mods().is_empty(), "没过阈值：没有开战 buff")
	t.eq(tiered.opening_mods().size(), 1, "过了一阶：一条开战增伤")
	t.check(tiered.rough_dps() > plain.rough_dps() * 1.05, "预估 DPS 算上血怒：%.2f > %.2f" % [tiered.rough_dps(), plain.rough_dps()])
	t.check(is_equal_approx(tiered.estimated_dps_of(tiered.item_of(k.uid)), tiered.rough_dps()), "只有匕首出手")


static func _mod(stat: StringName, flat: float, cat: int, pct: int) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.flat = flat
	m.mult_category = cat
	m.mult_percent = pct
	return m


static func run_dormant_faith(t: TestCase) -> void:
	t.begin("087 · 信仰道具休眠时保留通用效果：赐福盾的护甲照给、信力加成与邻接不给；护符（没有 combat）彻底失效；dormant_keeps_combat=false 彻底不参战")
	var c := _content()
	var shield_def := c.items.get_def(&"blessed_shield")
	var bow_def := c.items.get_def(&"blessed_longbow")
	t.check(shield_def.has_faith() and bow_def.has_faith() and shield_def.faith_tag() != bow_def.faith_tag(), "两件不同信仰的赐福之物")
	t.check(FaithState.keeps_combat_when_dormant(shield_def), "盾有战斗定义、默认保留")
	t.check(not FaithState.keeps_combat_when_dormant(c.items.get_def(&"strength_sigil")), "力量的符号没有 combat：休眠就彻底失效")
	var board := GridInventory.new(Vector2i(6, 4), 0, false)
	var shield := ItemInstance.create(shield_def)
	var bow := ItemInstance.create(bow_def)
	board.try_add(shield, true)
	board.try_add(bow, true)     # 后置入：狩猎之神激活，盾休眠
	t.eq(FaithState.active_tag(board), bow_def.faith_tag(), "激活的是后置入的弓的信仰")
	t.check(FaithState.is_dormant(shield_def, FaithState.active_tag(board)), "盾休眠")
	var spec := BattleCompiler.compile(board, null, [] as Array[StatModifier], [] as Array[AbilityRule], {shield_def.faith_tag(): 2, bow_def.faith_tag(): 2})
	var shield_item := spec.item_of(shield.uid)
	t.not_null(shield_item, "休眠的盾仍参战（通用效果）")
	if shield_item != null:
		var armor := StatMath.to_float(shield_item.stats.total_of(BattleStats.ARMOR))
		t.check(is_equal_approx(armor, float(shield_def.combat.base_stats["armor"])), "护甲是它自己的基础值 %.0f（信力一阶的 +4 没给）" % armor)
		t.eq(shield_item.rules.size(), shield_def.combat.rules.size(), "只有自己的规则，没有信力加成的规则")
	var bow_item := spec.item_of(bow.uid)
	t.check(bow_item != null and StatMath.to_float(bow_item.stats.total_of(BattleStats.DAMAGE)) > float(bow_def.combat.base_stats["damage"]), "激活的弓吃到了信力加成")
	# 反过来：盾后置入 → 弓休眠，弓照样出手（武器本身的攻击力）
	board.remove(shield.uid)
	board.try_add(shield, true)
	var spec2 := BattleCompiler.compile(board)
	var bow2 := spec2.item_of(bow.uid)
	t.check(bow2 != null and bow2.is_active() and spec2.estimated_dps_of(bow2) > 0.0, "休眠的弓仍出手、有 DPS")
	# 数据说不保留 → 彻底不参战
	var strict := bow_def.duplicate() as ItemDef
	strict.dormant_keeps_combat = false
	var b3 := GridInventory.new(Vector2i(6, 4), 0, false)
	var bow3 := ItemInstance.create(strict)
	b3.try_add(bow3, true)
	b3.try_add(ItemInstance.create(shield_def), true)
	t.is_null(BattleCompiler.compile(b3).item_of(bow3.uid), "dormant_keeps_combat=false：休眠就不参战")
	t.check(ItemTooltip.describe(ItemInstance.create(shield_def)).contains("保留通用效果"), "悬浮窗写着休眠时保留通用效果")


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
	var f := _flow(c)
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
	var f2 := _flow(c)
	var run2 := f2.begin(c.chapter, kit, 3)
	f2.pick_spawn(run2.map.entry_ids[0])
	run2.boss_cleared = true
	run2.node_rules = run2.node_rules.duplicate()
	run2.node_rules.boss_extracts = false
	run2._offer_loot(LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(4, 4), c.items))
	f2.resume()
	t.check(f2.hide_overlay() and f2.screen == GameFlow.Screen.MAP and not run2.is_over(), "boss_extracts=false：收起只是回地图")
	_cleanup()


static func run_shop_logic(t: TestCase) -> void:
	t.begin("087 · 商店屏的逻辑：栏位是小棋盘、商品只能进自己的容器且钱够、钱不够弹回并提示、双击买、拖进出售区就卖半价")
	var c := _content()
	var f := _flow(c)
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
		_cleanup()
		return
	run.wallet.earn(1000, &"test")
	run.events.handle(shop_node)
	while f.run.events.pending_event() != null:
		f.choose_event(0)
	var session := run.events.current_shop
	t.not_null(session, "开了店")
	if session == null:
		_cleanup()
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
		_cleanup()
		return
	# 落点过滤
	t.check(screen._allow_drop(slot0, run.board), "钱够：商品能进棋盘")
	t.check(not screen._allow_drop(slot0, session.sell_box), "商品不能进出售区")
	var mine: ItemInstance = run.board.items()[0]
	t.check(not screen._allow_drop(mine, session.shelves[0]), "自己的东西不能放到栏位上")
	t.check(screen._allow_drop(mine, session.sell_box), "自己的东西能进出售区")
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
		# 双击买：进包 / 暂存区
		var b2 := run.wallet.balance
		t.check(screen.quick_buy(inst.uid), "双击买")
		t.eq(run.wallet.balance, b2 - int(session.stock[poor_slot]["price"]), "扣钱")
		t.check(run.board.has_item(inst.uid) or run.storage.has_item(inst.uid), "东西进了包或暂存区")
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
	_cleanup()


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
	var spec_defs := Glossary.buffs_in_spec(BattleCompiler.compile(LootPacker.board_of([&"poisoned_knife"] as Array[StringName], Vector2i(4, 4), c.items)))
	t.check(spec_defs.has(&"poison"), "从战斗单位也收集得到")
	panel.queue_free()
	view.queue_free()

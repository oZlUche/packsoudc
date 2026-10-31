## 作者第十五批（报告 091 第十四节）：待定项拍板 —— 遭遇打赢接着搜、打输不再搜但不扣体力；商店回头再逛、刷新价不重置；
## 后续修改 —— 出发屏读数、基地出售页（一键出售按稀有度档）、背景底色可选；两个编辑器 bug（改 id 每敲一字多一条、语言字典加项默认成数字）；套装编辑器
extends RefCounted

const GAME := "res://ui/game/game.tscn"
## 与 Support.paths("091") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_091_run.json"
const META := "user://test_091_meta.json"
const SETTINGS := "user://test_091_settings.json"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


## 遭遇打输：整场包在事件里 —— 会话收掉、点用过、体力一点不掉、一局也不结束
static func run_encounter_lost(t: TestCase) -> void:
	t.begin("091 · 搜索遭遇打输：不能再搜（会话收掉、点用过），但体力不掉、一局不结束；赢了的那一路见 084 搜索循环")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到带搜索点的种子")
		return
	var f := Support.flow(c, "091", 1.0)
	var run := f.begin(c.chapter, LoadoutDef.new(), int(found["seed"]))     # 空手 + 1 血：肯定输
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(int(found["entry"]))
	# 让这一次搜必遭遇：规则复制一份再改，不碰共享资产
	var rules: NodeRules = run.events.rules.duplicate(true)
	rules.search.encounter_curve.clear()
	rules.search.encounter_curve.append(1.0)
	run.events.rules = rules
	var next := int(found["next"])
	var vit_before := run.vitality.current
	t.check(f.step_to(next), "走上搜索点")
	t.eq(f.screen, GameFlow.Screen.EVENT, "先到事件屏")
	var labels: Array = NodeScreens._labels(f.last_payload.get("def", null))
	t.check(f.choose_event(maxi(labels.find("搜索"), 0)), "选「搜索」")
	var session: SearchSession = run.events.current_search
	t.not_null(session, "会话开着")
	if session == null:
		Support.cleanup("091")
		return
	t.check(not session.active and not session.encounter.is_empty(), "第一次就遭遇")
	t.eq(f.screen, GameFlow.Screen.EVENT, "→「有人来了」")
	t.check(f.choose_event(0), "迎战")
	t.eq(f.screen, GameFlow.Screen.PREBATTLE, "→ 战前准备")
	t.eq(int(run.events.pending_battle.get("loss_cost", -1)), 0, "这一场写了无代价")
	t.check(f.start_battle(), "开战")
	t.eq(f.screen, GameFlow.Screen.BATTLE, "→ 回放")
	t.check(not bool(f.last_payload.get("won", true)), "输了")
	t.check(run.events.current_search == null and not session.active, "输了：会话收掉，不能再搜")
	t.check(run.map.get_node(next).is_visited(), "点用过了")
	t.eq(run.vitality.current, vit_before, "体力一点没掉")
	t.check(not run.is_over(), "一局没结束")
	f.resume()
	NodeScreens._settle(f)
	t.eq(f.screen, GameFlow.Screen.MAP, "收尾回地图")
	Support.cleanup("091")


## 商店回头再逛：刷新次数 / 卖掉的记在节点里，回来价钱接着涨
static func run_shop_revisit(t: TestCase) -> void:
	t.begin("091 · 商店可以回头再逛：离开再回来店重开、刷新次数与刷新价接着算（不重置）")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"shop", kit.items)
	if found.is_empty():
		t.check(true, "（种子里出生点旁没有商店，跳过）")
		return
	var f := Support.flow(c, "091", 10000.0)
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	if run == null:
		t.check(false, "开局")
		return
	var entry := int(found["entry"])
	var shop := int(found["next"])
	f.pick_spawn(entry)
	run.wallet.earn(100000, &"test")
	t.check(f.step_to(shop), "走上商店点")
	var guard := 0
	while f.screen == GameFlow.Screen.EVENT and guard < 5:
		guard += 1
		f.choose_event(0)
	t.eq(f.screen, GameFlow.Screen.SHOP, "→ 商店屏")
	var s1: ShopSession = run.events.current_shop
	t.not_null(s1, "开了店")
	if s1 == null:
		Support.cleanup("091")
		return
	t.check(s1.refresh() and s1.refresh(), "刷了两次")
	t.eq(s1.refreshes, 2, "计了两次")
	var cost_after := s1.refresh_cost()
	var node := run.map.get_node(shop)
	t.eq(int(node.content.get("shop", {}).get("refreshes", -1)), 2, "刷新次数记在节点里")
	s1.leave()
	t.eq(f.screen, GameFlow.Screen.MAP, "离开回地图")
	t.check(node.is_visited(), "点用过了")
	t.check(f.step_to(entry), "退回出生点")
	t.check(f.step_to(shop), "再走上商店点")
	t.eq(f.screen, GameFlow.Screen.SHOP, "店又开了")
	var s2: ShopSession = run.events.current_shop
	t.check(s2 != null and s2 != s1, "是新一个会话")
	if s2 != null:
		t.eq(s2.refreshes, 2, "刷新次数接着算")
		t.eq(s2.refresh_cost(), cost_after, "刷新价不重置")
		s2.leave()
	NodeScreens._settle(f)
	Support.cleanup("091")


## 背景底色：设置里挑一个，调色板 / 底板 / 存盘都跟着
static func frame_bg_theme(t: TestCase, root: Window) -> void:
	t.begin("091 · 背景底色可选：几种底色、默认石墨；设置屏点一个就立刻换底板、存盘读回来还是它")
	t.check(UiPalette.BG_THEMES.size() >= 4, "至少四种底色（%d）" % UiPalette.BG_THEMES.size())
	t.check(UiPalette.has_bg_theme(UiPalette.BG_DEFAULT) and not UiPalette.has_bg_theme("nope"), "认得默认、不认瞎写的")
	var saved_theme := UiPalette.bg_theme
	Support.cleanup("091")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.show_settings()
	t.eq(flow.screen, GameFlow.Screen.SETTINGS, "→ 设置")
	var screen = game.base()
	t.check(screen != null and screen.has_method("set_bg_theme"), "设置屏在")
	if screen == null:
		game.queue_free()
		return
	var pick := ""
	for th in UiPalette.BG_THEMES:
		if String(th["id"]) != UiPalette.BG_DEFAULT:
			pick = String(th["id"])
			break
	var before := UiPalette.bg()
	screen.set_bg_theme(pick)
	t.eq(flow.settings.bg_theme, pick, "设置记住了")
	t.eq(UiPalette.bg_theme, pick, "调色板换了")
	t.check(UiPalette.bg() != before, "底色真的变了")
	t.check(screen._bg_rect != null and screen._bg_rect.color == UiPalette.bg(), "这一屏的底板立刻换色")
	t.check((screen._bg_btns[pick] as Button).button_pressed, "按钮亮着的是选中的那一个")
	var back := GameSettings.load_from(SETTINGS)
	t.eq(back.bg_theme, pick, "存盘读回来还是它")
	# 101 第 5 刀：认不认得这个 id 是界面的事 —— 设置层原样存，调色板兜底成默认那档
	var bad := GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "bg_theme": "nope"})
	t.eq(bad.bg_theme, "nope", "设置层原样存着（它不认识底色的名单）")
	UiPalette.apply(bad)
	t.eq(UiPalette.bg_theme, UiPalette.BG_DEFAULT, "调色板认不出来：回到默认那档")
	t.eq(GameSettings.new().bg_theme, "", "没存过：空串 = 用界面的默认")
	UiPalette.apply(GameSettings.new())
	t.eq(UiPalette.bg_theme, UiPalette.BG_DEFAULT, "空串也回到默认那档")
	screen.set_bg_theme("nope")
	t.eq(flow.settings.bg_theme, pick, "不认的不接")
	screen.set_bg_theme(UiPalette.BG_DEFAULT)
	t.eq(UiPalette.bg_theme, UiPalette.BG_DEFAULT, "换回默认")
	UiPalette.bg_theme = saved_theme
	game.queue_free()
	Support.cleanup("091")


static func _place_any(inv: Variant, def: ItemDef) -> ItemInstance:
	var inst := ItemInstance.create(def)
	for y in inv.size.y:
		for x in inv.size.x:
			if inv.place(inst, Vector2i(x, y)):
				return inst
	return null


## 基地出售页：单件卖、一键按档卖、预览
static func frame_sell_tab(t: TestCase, root: Window) -> void:
	t.begin("091 · 基地「出售」页：按定价的比例进钱；筛选档「白色 / 绿色及以下 / … / 全部」；预览 → 一键出售；双击卖一件")
	var c = NodeScreens._content()
	Support.cleanup("091")
	var f := Support.flow(c, "091", 10000.0)
	var white: ItemDef = null
	var higher: ItemDef = null
	for id in c.items.all_ids():
		var d: ItemDef = c.items.get_def(id)
		if d.is_bag:
			continue
		if d.rarity == 0 and white == null:
			white = d
		elif d.rarity >= 2 and higher == null:
			higher = d
	if white == null or higher == null:
		t.check(false, "道具库里找不到白色 + 蓝色以上各一件")
		return
	var a := _place_any(f.meta.warehouse, white)
	var b := _place_any(f.meta.warehouse, higher)
	t.check(a != null and b != null, "仓库里放了两件")
	if a == null or b == null:
		Support.cleanup("091")
		return
	t.check(f.sell_ratio() > 0.0 and f.sell_ratio() <= 1.0, "出售比例在 (0, 1]（%.2f）" % f.sell_ratio())
	var pw := MetaState.sell_price(white, f.sell_ratio())
	var ph := MetaState.sell_price(higher, f.sell_ratio())
	t.eq(pw, floori(float(ItemValue.of(white)) * f.sell_ratio()), "卖价 = 定价 × 比例，向下取整")
	var pre := f.meta.sell_preview(0, f.sell_ratio())
	t.eq([int(pre["count"]), int(pre["funds"])], [1, pw], "预览「白色」：一件、它的钱")
	t.eq(int(f.meta.sell_preview(-1, f.sell_ratio())["count"]), 2, "预览「全部」：两件")
	t.eq(f.meta.warehouse.item_count(), 2, "预览不动仓库")

	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	screen.show_tab("sell")
	t.eq(screen.tab(), "warehouse", "268：出售页删了，\"sell\" 落仓库页")
	screen.set_sell_mode(true)     # 268 补充二：快速出售 —— 筛选牌筛选 + 出售条全选，勾了再卖
	var sheet: SellStrip = screen.sell_strip()
	var tools: WarehouseTools = screen.warehouse_tools()
	tools.set_filter(&"", 0)
	sheet.toggle_all()
	t.check(sheet.summary_text().contains("1 件"), "筛「白色」全选：已选 1 件（%s）" % sheet.summary_text())
	t.eq(sheet.coin_amount(), pw, "金币写它的卖价")
	sheet.toggle_all()
	tools.set_filter(&"", -1)
	sheet.toggle_all()
	t.check(sheet.summary_text().contains("2 件"), "「全部」全选：已选 2 件（%s）" % sheet.summary_text())
	sheet.toggle_all()
	var funds0 := f.meta.funds
	t.eq(screen.sell(a.uid), pw, "悬浮窗卖一件：得它的钱")
	t.eq(f.meta.funds, funds0 + pw, "钱进了局外账户")
	t.eq(f.meta.warehouse.item_count(), 1, "仓库少一件")
	t.eq(screen.sell(a.uid), -1, "再卖同一件：没有了")
	tools.set_filter(&"", 0)
	sheet.toggle_all()
	t.eq(screen.shelf().selected.size(), 0, "「白色」档已经没东西可勾")
	t.check(sheet.sell_button().disabled, "【出售】压灰")
	tools.set_filter(&"", -1)
	sheet.toggle_all()
	sheet.press_sell()
	var got: Dictionary = sheet.press_sell()
	t.eq([int(got["count"]), int(got["funds"])], [1, ph], "全选「全部」两下【出售】：卖掉剩下那件")
	t.eq(f.meta.funds, funds0 + pw + ph, "钱都进来了")
	t.eq(f.meta.warehouse.item_count(), 0, "仓库空了")
	t.check(MetaSave.exists(META), "卖完就存局外")
	var back := MetaState.from_dict(f.meta.to_dict(), c.items)
	t.eq(back.funds, f.meta.funds, "钱跟存档")
	screen.queue_free()
	Support.cleanup("091")


## 道具编辑器：新建后边敲 id，列表里始终只有一条
static func frame_item_editor_id_typing(t: TestCase, root: Window) -> void:
	t.begin("091 · 道具编辑器：新建道具边敲 id，草稿与列表始终只有它一条（不再每敲一字多一条）")
	var ed = (load("res://ui/editor/content_editor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	var n0: int = ed._ids.size()
	ed._new_item()
	t.check(ed._drafts.has("new_item"), "新建的先叫 new_item")
	for text in ["t", "ti", "tib", "tibia"]:
		ed._on_id_changed(text)
	t.eq(ed._drafts.size(), 1, "草稿只有一份")
	t.check(ed._drafts.has("tibia") and not ed._drafts.has("t") and not ed._drafts.has("new_item"), "键是最后敲出来的那个 id")
	t.eq(ed._ids.size(), n0 + 1, "列表只多了一条（%d → %d）" % [n0, ed._ids.size()])
	t.check(ed._ids.has("tibia") and not ed._ids.has("tib") and not ed._ids.has("t"), "半截名字没留在列表里")
	t.eq(ed._list.item_count, ed._ids.size(), "画出来的和列表一致")
	ed._drafts.clear()
	ed.queue_free()


## PropertyForm：语言字典「+ 加一项」给的是空字串、键是下一个语言码；数值字典照旧给 0
static func frame_property_form_text_dict(t: TestCase, root: Window) -> void:
	t.begin("091 · PropertyForm 字典：给 titles / texts 这类语言字典加一项 → 键是下一个语言码、值是空字串（不是 0.0）；文字用单行框改")
	var def := EventDef.new()
	def.id = &"probe"
	def.titles = {"en": "Hello"}
	var form := PropertyForm.create(def, UiPalette.cjk_font())
	root.add_child(form)
	var box := form._dict_editor(def, "titles", def.titles)
	root.add_child(box)
	var add: Button = null
	var line_edits := 0
	var spin := 0
	for row in box.get_children():
		if row is Button and (row as Button).text == "+ 加一项":
			add = row
		for c in row.get_children():
			if c is SpinBox:
				spin += 1
			elif c is LineEdit:
				line_edits += 1
	t.check(add != null, "有「+ 加一项」")
	t.check(spin == 0 and line_edits >= 2, "文字值用单行框，不是数字框")
	if add != null:
		add.pressed.emit()
	t.eq(def.titles.size(), 2, "多了一项")
	var new_key := ""
	for k in def.titles:
		if k != "en":
			new_key = String(k)
	var expect := ""
	for l in UiText.LANGS:
		if l != "zh" and l != "en":
			expect = String(l)
			break
	if expect == "":
		expect = "lang_1"     # 语言码都写过了就 lang_1
	t.eq(new_key, expect, "键是下一个还没写的语言码，都写了就 lang_1")
	t.check(def.titles[new_key] is String and def.titles[new_key] == "", "值是空字串")
	t.check(not (def.titles[new_key] is float), "不是 0.0")
	# 空字典也认（按键名）
	t.check(PropertyForm._is_text_dict("texts", {}) and PropertyForm._is_text_dict("labels", {}), "titles / texts / labels 按键名认")
	t.check(not PropertyForm._is_text_dict("weights", {"a": 1.0}), "数值字典不算")
	box.queue_free()
	form.queue_free()


## 属性键下拉：属性表加一项从已有属性里挑（也能自定义）；修饰的 stat 字段是下拉
static func frame_stat_key_picker(t: TestCase, root: Window) -> void:
	t.begin("091 · 属性键下拉：base_stats 加一项从已知属性里挑（排除已有的）或自定义；StatModifier.stat / DealDamage.damage_stat 也是下拉 + 自定义")
	var saved := UiText.lang
	UiText.lang = "zh"
	var known := PropertyForm.known_stat_keys()
	t.check(known.has("damage") and known.has("block") and known.has("max_hp") and known.has("haste"), "认得战斗属性常量（%d 个）" % known.size())
	t.check(known.has("max_armor") and known.has("regen_stamina"), "词典里有名字的也在")
	var sorted := known.duplicate()
	sorted.sort()
	t.eq(known, sorted, "升序")
	t.check(PropertyForm.stat_label("damage").begins_with("伤害"), "中文模式显示「伤害 (damage)」（%s）" % PropertyForm.stat_label("damage"))
	PropertyForm.register_stat_keys(["zz_probe_stat"])
	t.check(PropertyForm.known_stat_keys().has("zz_probe_stat"), "编辑器登记的也进列表")

	# 属性表：加一项
	var profile := CombatProfile.new()
	profile.base_stats = {"damage": 5.0}
	var form := PropertyForm.create(profile, UiPalette.cjk_font())
	root.add_child(form)
	var box := form._dict_editor(profile, "base_stats", profile.base_stats)
	root.add_child(box)
	var adder: HBoxContainer = box.get_child(box.get_child_count() - 1)
	var picker: Control = adder.get_child(0)
	var add_btn: Button = adder.get_child(1)
	t.check(picker.has_meta("stat_options") and add_btn.text == "+ 加一项", "最后一行是「下拉 + 加一项」")
	var ob: OptionButton = picker.get_meta("stat_options")
	var custom: LineEdit = picker.get_meta("stat_custom")
	var listed: Array[String] = []
	for i in ob.item_count:
		listed.append(String(ob.get_item_tooltip(i)))
	t.check(not listed.has("damage"), "已有的 damage 不再列出")
	t.check(listed.has("block") and listed.has("max_hp"), "没写的属性都在")
	t.check(ob.get_item_text(ob.item_count - 1) == "自定义…", "最后一项是自定义")
	t.check(not custom.visible, "默认不露输入框")
	var armor_at := listed.find("block")
	ob.select(armor_at)
	ob.item_selected.emit(armor_at)
	add_btn.pressed.emit()
	t.check(profile.base_stats.has("block") and profile.base_stats["block"] is float and profile.base_stats["block"] == 0.0, "挑「格挡」加一项：armor = 0.0")
	# 重建后再加自定义
	box.queue_free()
	box = form._dict_editor(profile, "base_stats", profile.base_stats)
	root.add_child(box)
	adder = box.get_child(box.get_child_count() - 1)
	picker = adder.get_child(0)
	add_btn = adder.get_child(1)
	ob = picker.get_meta("stat_options")
	custom = picker.get_meta("stat_custom")
	ob.select(ob.item_count - 1)
	ob.item_selected.emit(ob.item_count - 1)
	t.check(custom.visible, "选「自定义…」露出输入框")
	custom.text = "my_power"
	add_btn.pressed.emit()
	t.check(profile.base_stats.has("my_power"), "自定义键加进去了")
	t.check(not PropertyForm._is_stat_dict("type_weights", {"battle": 3.0}), "节点类型权重不算属性表")
	t.check(PropertyForm._is_stat_dict("weights", {"damage": 1.0, "block": 2.0}), "键全是已知属性就算")
	box.queue_free()
	form.queue_free()

	# 修饰的 stat：下拉，当前值选中
	var m := StatModifier.new()
	m.stat = &"block"
	var mf := PropertyForm.create(m, UiPalette.cjk_font())
	root.add_child(mf)
	var hits: Array = []     # lambda 里改数组（按引用）；对象变量会被按值捕获
	var walker := func(node: Node, f: Callable) -> void:
		for c in node.get_children():
			if c is Control and (c as Control).has_meta("stat_options"):
				hits.append(c.get_meta("stat_options"))
			f.call(c, f)
	walker.call(mf, walker)
	var found_ob: OptionButton = hits[0] if not hits.is_empty() else null
	t.check(found_ob != null, "stat 字段是下拉")
	if found_ob != null:
		t.eq(String(found_ob.get_item_tooltip(found_ob.get_selected())), "block", "当前值选中")
		var dmg := -1
		for i in found_ob.item_count:
			if String(found_ob.get_item_tooltip(i)) == "damage":
				dmg = i
		found_ob.select(dmg)
		found_ob.item_selected.emit(dmg)
		t.eq(m.stat, &"damage", "换一项写回字段")
	mf.queue_free()
	# 自定义的当前值：下拉停在「自定义…」、输入框露出且是那个字
	var m2 := StatModifier.new()
	m2.stat = &"weird_stat"
	var mf2 := PropertyForm.create(m2, UiPalette.cjk_font())
	root.add_child(mf2)
	hits.clear()
	walker.call(mf2, walker)
	found_ob = hits[0] if not hits.is_empty() else null
	if found_ob != null:
		var picker2: Control = found_ob.get_parent()
		var custom2: LineEdit = picker2.get_meta("stat_custom")
		t.check(found_ob.get_selected() == found_ob.item_count - 1 and custom2.visible and custom2.text == "weird_stat", "不在列表里的值当自定义")
		custom2.text = "weirder"
		custom2.text_changed.emit("weirder")
		t.eq(m2.stat, &"weirder", "改输入框写回字段")
	mf2.queue_free()
	# 可选的属性键（ResourceCost.amount_stat 默认空）：空值停在「不用」，读回仍为空；选 armor 才写成 armor
	var rc := ResourceCost.new()
	t.eq(rc.amount_stat, &"", "amount_stat 默认空")
	var rcf := PropertyForm.create(rc, UiPalette.cjk_font())
	root.add_child(rcf)
	hits.clear()
	walker.call(rcf, walker)
	var opt: OptionButton = hits[0] if not hits.is_empty() else null
	t.check(opt != null, "amount_stat 是下拉")
	if opt != null:
		t.eq(opt.get_selected(), 0, "空值选中第一项")
		t.check(opt.get_item_text(0).begins_with("不用"), "第一项是「不用」（%s）" % opt.get_item_text(0))
		t.eq(PropertyForm._picked_stat(opt.get_parent()), "", "读回仍为空")
		t.eq(rc.amount_stat, &"", "没碰就没写成别的")
		var armor_i := -1
		for i in opt.item_count:
			if String(opt.get_item_tooltip(i)) == "block":
				armor_i = i
		t.check(armor_i > 0, "列表里有格挡")
		opt.select(armor_i)
		opt.item_selected.emit(armor_i)
		t.eq(rc.amount_stat, &"block", "选 armor 写成 armor")
		t.eq(PropertyForm._picked_stat(opt.get_parent()), "block", "读回 armor")
		opt.select(0)
		opt.item_selected.emit(0)
		t.eq(rc.amount_stat, &"", "再选回「不用」写回空")
	rcf.queue_free()
	# 必填的 stat 没有「不用」这一项
	var m3 := StatModifier.new()
	var mf3 := PropertyForm.create(m3, UiPalette.cjk_font())
	root.add_child(mf3)
	hits.clear()
	walker.call(mf3, walker)
	var opt3: OptionButton = hits[0] if not hits.is_empty() else null
	if opt3 != null:
		t.check(not opt3.get_item_text(0).begins_with("不用"), "必填的 stat 不给「不用」")
	mf3.queue_free()
	t.check(PropertyForm._is_stat_field("stat") and PropertyForm._is_stat_field("damage_stat") and not PropertyForm._is_stat_field("status"), "认 stat / *_stat")
	UiText.lang = saved


## 135（作者定）：搜索遭遇打输不扣体力、点不能再搜 —— 文案跟着说清楚；节点规则里不再有 search 的扣体力表项
static func run_search_loss_text_135(t: TestCase) -> void:
	t.begin("135 · 搜索遭遇的文案：输了是「被赶跑」、不扣体力；规则表没有 search 一项；地图日志按原因说")
	var destroyed: EventDef = load("res://data/events/search_destroyed.tres")
	t.eq(destroyed.title, "被赶跑了", "打输那一屏的标题")
	t.check(not destroyed.text.contains("对方留下"), "不再像打赢了：%s" % destroyed.text)
	var tut: EventDef = load("res://data/events/tut_search_2.tres")
	t.check(not tut.text.contains("会扣体力") and tut.text.contains("不扣体力"), "教程不再说搜索遭遇扣体力")
	for path in ["res://data/node_rules/standard.tres", "res://data/node_rules/prologue.tres"]:
		var rules: NodeRules = load(path)
		t.check(not rules.loss_cost.has("search"), "%s：没有 search 的扣体力表项" % path.get_file())
		t.eq(rules.loss_cost_of(&"search"), 0, "%s：loss_cost_of(search) = 0，和实际一致" % path.get_file())
	t.eq(NodeRules.new().loss_cost_of(&"search"), 0, "默认表也没有")
	t.eq(preload("res://ui/game/map_screen.gd").search_end_text(&"encounter"), "被赶跑，这个点不能再搜", "日志：遭遇打输")
	t.eq(preload("res://ui/game/map_screen.gd").search_end_text(&"exhausted"), "搜完了", "日志：搜满")
	t.eq(preload("res://ui/game/map_screen.gd").search_end_text(&"left"), "离开", "日志：自己走")

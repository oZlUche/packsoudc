## 161（作者定）：开局拆成三页（选角色 → 配道具 → 选地图与难度），右下角继续 / 返回；角色卡用方块与爱心读属性差异
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const Support := preload("res://tests/run/flow_support.gd")


static func run_stat_blocks(t: TestCase) -> void:
	t.begin("161 · 属性方块：每块 10 点、最后一块按余数部分填充；体力一点一颗心；块数可改")
	var hp := StatBlocks.new().setup(StatBlocks.HP, 70)
	t.eq(hp.fills().size(), 7, "生命 70 = 7 块")
	t.check(hp.fills().all(func(f: float) -> bool: return f == 1.0), "7 块都满")
	t.check(hp.text_of().contains("70"), "提示写着具体值：%s" % hp.text_of())
	var st := StatBlocks.new().setup(StatBlocks.STAMINA, 55)
	t.eq(st.fills().size(), 6, "耐力 55 = 5 块满 + 1 块")
	t.check(absf(st.fills()[5] - 0.5) < 0.001, "最后一块半满")
	t.eq(st.color(), UiPalette.STAMINA, "耐力是黄的")
	t.eq(hp.color(), UiPalette.HP, "生命是红的")
	var heart := StatBlocks.new().setup(StatBlocks.VITALITY, 7)
	t.eq(heart.fills().size(), 7, "体力 7 = 7 颗心")
	var fine := StatBlocks.new().setup(StatBlocks.HP, 70, 5)
	t.eq(fine.fills().size(), 14, "每块 5 点：14 块")
	t.check(fine.custom_minimum_size.y > StatBlocks.BLOCK * 1.5, "超过一排 %d 块折行" % StatBlocks.PER_ROW)
	var narrow := StatBlocks.new().setup(StatBlocks.HP, 45)
	t.check(narrow.custom_minimum_size.x < hp.custom_minimum_size.x, "45 比 70 短")
	t.eq(hp.custom_minimum_size.x, 7 * StatBlocks.BLOCK, "作者 2026-10-16：方块条连成一根，格子之间不留空（7 块 = 7 个边长）")
	t.eq(heart.custom_minimum_size.x, 7 * StatBlocks.BLOCK + 6 * StatBlocks.GAP, "心照旧隔开")
	for b in [hp, st, heart, fine, narrow]:
		b.free()


static func run_bags_weigh_nothing(t: TestCase) -> void:
	t.begin("161 · 包不算重：三种包与腰带 0 重，只剩包的棋盘负重 0")
	var items := ItemDatabase.new()
	items.load_dir()
	for id in [&"bag_leather", &"bag_long", &"bag_small"]:
		t.eq(ItemWeight.of(items.get_def(id)), 0, "%s 0 重" % id)
	var board := GridInventory.new(Vector2i(9, 6), 1, true)
	board.try_add(ItemInstance.create(items.get_def(&"bag_leather")))
	board.try_add(ItemInstance.create(items.get_def(&"bag_leather")))
	t.eq(ItemWeight.total(board), 0, "布鲁图斯的两个皮革包：负重 0")


static func frame_three_pages(t: TestCase, root: Window) -> void:
	t.begin("161 · 开局三页：选角色（角色卡 + 棋盘预览）→ 配道具（仓库只在这页）→ 选地图与难度（摘要）；返回不丢东西")
	Support.cleanup("setup161")
	var p := Support.paths("setup161")
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	if flow.characters.size() < 2:
		t.check(false, "至少两个角色")
		game.queue_free()
		return
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.eq(setup.page(), 0, "第一页")
	t.check(setup._title.text.contains("选角色"), "标题：%s" % setup._title.text)
	t.eq(setup._back_btn.text, "回主菜单", "第一页的返回 = 回主菜单")
	t.check(not setup._warehouse_view.is_visible_in_tree(), "第一页看不到仓库")

	# 角色卡：255 起面板是一行蜡板方块（生命 / 耐力 / 耐力回复 / 体力），按这个角色的底子写
	var ch: CharacterDef = setup.character()
	var plaques: Array = setup._stat_plaques
	t.eq(plaques.map(func(p: StatPlaque) -> String: return p.caption), ["生命", "耐力", "耐力回复", "体力"], "四块：生命、耐力、耐力回复、体力")
	t.eq((plaques[0] as StatPlaque).value, str(int(ch.baseline().value_of(&"max_hp"))), "生命上限按角色")
	t.eq((plaques[1] as StatPlaque).value, str(int(ch.baseline().value_of(&"max_stamina"))), "耐力上限按角色")
	t.eq((plaques[3] as StatPlaque).value, str(ch.vitality_max), "体力按角色")
	t.check(setup._preview_view != null and setup._preview_view.inventory.size == ch.board_size, "右边是这个角色的棋盘预览")
	t.eq(setup._preview_view.inventory.bags().size(), 0, "255：预览只画形状，不画包")
	t.check(not setup._drag._views.has(setup._preview_view), "预览只看不拖（不在拖拽层上）")
	# 214：角色卡第一行 = 160 的大头像 + 铭牌，图 = 这个角色的肖像（没图是占位剪影）
	var big: PortraitSlot = setup._portrait
	t.check(big != null and big.get_parent().get_parent() == setup._card and big.get_parent().get_index() == 0 and big.get_index() == 0, "角色卡第一行打头是大头像")
	t.check(big != null and big.get_parent().get_child(1) is Nameplate, "铭牌在它右边")
	t.check(big != null and big.custom_minimum_size == Vector2(160, 160), "大头像 160×160")
	t.check(big != null and (big.picture.texture if big.picture != null else null) == Nameplate.character_face(ch.id), "大头像 = 这个角色的肖像")

	# 换角色：卡和预览跟着变
	setup.choose_character(1)
	var ch2: CharacterDef = setup.character()
	t.check(ch2 != ch, "换了角色")
	t.eq(setup._preview_view.inventory.size, ch2.board_size, "预览的棋盘尺寸跟着变")
	t.check(setup._portrait != big and is_instance_valid(setup._portrait) and setup._portrait.get_parent().get_index() == 0, "换角色：大头像跟着重画")
	t.check((setup._portrait.picture.texture if setup._portrait.picture != null else null) == Nameplate.character_face(ch2.id), "换成新角色的肖像")

	# 第二页：仓库在，带一件
	t.check(setup.next_page(), "继续")
	t.eq(setup.page(), 1, "第二页")
	t.check(setup._warehouse_view.is_visible_in_tree(), "第二页看得到仓库")
	t.eq(setup._back_btn.text, "返回", "第二页的返回 = 回上一页")
	var first := flow.meta.warehouse.items()[0] as ItemInstance
	t.check(setup.carry_in(first.uid), "带上一件")

	# 第三页：摘要写着角色与地图；换图不动角色与带上的东西
	t.check(setup.next_page(), "继续")
	t.eq(setup.page(), 2, "第三页")
	t.eq(setup._enter_btn.text, "出发", "最后一页是「出发」")
	t.eq(setup._summary.text, Names.of(ch2), "右上只写角色名（180 补二）")
	setup.choose_chapter(setup.chapter_index)
	t.eq(setup.character(), ch2, "重挑模式：角色不变")
	t.eq(setup.carried().size(), 1, "重挑模式：带上的还在")

	# 返回：不丢
	t.check(setup.escape(), "Esc")
	t.eq(setup.page(), 1, "Esc 回第二页")
	t.eq(setup.carried().size(), 1, "带上的还在")
	setup.prev_page()
	t.eq(setup.page(), 0, "回第一页")
	t.eq(setup.carried().size(), 1, "回第一页也还在")

	# 出发：最后一页的「出发」= depart
	setup.show_page(2)
	t.check(not setup.next_page() and setup._enter_btn.disabled, "182：没挑出生点，「出发」灰着、走不了")
	setup.pick_spawn(setup.preview().entry_ids()[0])
	t.check(setup.next_page(), "出发")
	# 218 补充一（作者定）：第一次按「出发」先在开局屏上叠一层「军团的交代」，「知道了」之后才进图
	var brief = game.overlay()
	t.check(brief != null and brief.screen == GameFlow.Screen.EVENT and brief.is_briefing(), "先弹交代（叠在开局屏上）")
	t.eq(game.base(), setup, "开局屏还在底下")
	t.is_null(flow.run, "局还没开")
	if brief != null and brief.screen == GameFlow.Screen.EVENT:
		t.check(brief.find_children("*", "Button", true, false).all(func(b): return (b as Button).text != "整理背包（B）"), "没有整理背包")
		t.check(brief.choose(0), "知道了")
	t.check(flow.meta.briefing_seen.has(&"briefing_legion"), "记看过")
	t.eq(game.base().screen, GameFlow.Screen.MAP, "进了地图")
	t.is_null(game.overlay(), "交代收掉了")
	t.eq(flow.run.phase, RunState.Phase.ON_MAP, "182：直接站在挑的出生点上")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup("setup161")

## 报告 383（作者 2026-11-22 23:49）：出征三屏 —— 一 选人 / 吃饭 / 选神三条折叠横条（默认折叠、沿用上一局、同一时间只展开一条），
## 二 配道具（多了科技发的随身技能），三 地图、难度、材料倾向；原第四页取消；军需牌删了，局外加成并进角色卡的数字
extends RefCounted

const CS := preload("res://tests/run/test_character_setup.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const C355 := preload("res://tests/meta/test_canteen_355.gd")


static func _game(root: Window):
	Support.cleanup("char")
	var game = load(CS.GAME).instantiate()
	game.save_path = CS.SAVE
	game.meta_path = CS.META
	root.add_child(game)
	var flow: GameFlow = game.flow
	Support.pass_tutorials(flow)
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	return game


static func _free_mode(setup) -> bool:
	for i in setup._chapters.size():
		if setup._chapters[i].id == &"free_mode":
			setup.show_page(2)
			setup.choose_chapter(i)
			setup._sync_preview()
			var entries: Array = setup.preview().entry_ids()
			if not entries.is_empty():
				setup.pick_spawn(int(entries[0]))
			return true
	return false


static func frame_three_screens_and_bars(t: TestCase, root: Window) -> void:
	t.begin("383 · 三屏；第一屏只有角色一条时也是折叠横条，头上写头像和角色名；点开是原来的三栏；没开的食物 / 信仰不出")
	var game = _game(root)
	var flow: GameFlow = game.flow
	flow.new_run()
	var setup = game.base()
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	t.eq(setup._pages.size(), 3, "三页")
	t.eq(setup.last_page(), 2, "第三页是最后一页")
	t.eq(setup._title.text, "出征准备", "第一页标题「出征准备」")
	var ch_bar: FoldBar = setup.bar(setup.BAR_CHARACTER)
	t.check(ch_bar != null and ch_bar.visible and not ch_bar.open, "角色横条在、默认折叠")
	t.check(not setup.bar(setup.BAR_MEAL).visible and not setup.bar(setup.BAR_FAITH).visible, "食堂没开、万神院没到：只有角色一条")
	var head := ch_bar.summary.get_node_or_null(^"HeadText") as Label
	t.check(head != null and head.text == Names.of(setup.character()), "折叠时写角色名（%s）" % [head.text if head != null else ""])
	t.eq(ch_bar.summary.find_children("*", "PortraitSlot", true, false).size(), 1, "和头像")
	t.check(not setup._char_row.is_visible_in_tree(), "三栏收着")
	ch_bar.press()
	t.check(ch_bar.open and setup._char_row.is_visible_in_tree(), "点头展开：角色列表、角色卡、棋盘预览")
	setup.choose_character(1 if setup._characters.size() > 1 else 0)
	t.eq((ch_bar.summary.get_node(^"HeadText") as Label).text, Names.of(setup.character()), "换了角色，头上的名字跟着变")
	ch_bar.press()
	t.check(not ch_bar.open and not setup._char_row.is_visible_in_tree(), "再点收起")
	t.eq(Bare.audit(setup._pages[0], "setup383"), [] as Array[String], "第一屏不裸字")
	t.check(setup.next_page() and setup.page() == 1, "继续到配道具")
	t.check(setup.next_page() and setup.page() == 2, "继续到地图")
	t.eq(setup._enter_btn.text, UiText.t("setup.depart"), "第三页是「出发」")
	game.queue_free()
	Support.cleanup("char")


static func frame_all_bars_fit(t: TestCase, root: Window) -> void:
	t.begin("383 · 三条都在：同一时间只展开一条；展开哪一条都不越出屏、不压右下角的按钮")
	var game = _game(root)
	var flow: GameFlow = game.flow
	C355._open(flow)
	flow.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	flow.new_run()
	var setup = game.base()
	for id in [setup.BAR_CHARACTER, setup.BAR_MEAL, setup.BAR_FAITH]:
		t.check(setup.bar(id).visible and not setup.bar(id).open, "%s：在、折叠" % id)
	t.eq(setup.meal_head_text(), UiText.t("canteen.menu_empty_pot"), "锅空：食物横条写空锅")
	t.eq(setup.faith_head_text(), "无信者", "没选过神：无信者")
	var design_h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1000))
	var room: float = design_h - setup.PAGE_MARGIN - setup.NAV_ROOM - setup._title.get_parent().get_combined_minimum_size().y - setup.PAGE_SEP
	for id in [setup.BAR_CHARACTER, setup.BAR_MEAL, setup.BAR_FAITH]:
		setup.open_bar(id)
		var opened: Array = [setup.BAR_CHARACTER, setup.BAR_MEAL, setup.BAR_FAITH].filter(func(k): return setup.bar(k).open)
		t.eq(opened, [id], "只展开 %s" % id)
		var h: float = (setup._bar_col as Control).get_combined_minimum_size().y
		t.check(h <= room, "%s 展开：放得进页面、不压右下角的按钮（%.0f ≤ %.0f）" % [id, h, room])
	game.queue_free()
	Support.cleanup("char")


static func frame_faith_bar(t: TestCase, root: Window) -> void:
	t.begin("383 · 信仰横条：万神院到了才有；展开是神龛一排（无信者在前、没解锁的？？？？）；选一位头上跟着换、出发就奉祂；下回默认沿用")
	var game = _game(root)
	var flow: GameFlow = game.flow
	flow.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	flow.new_run()
	var setup = game.base()
	var fb: FoldBar = setup.bar(setup.BAR_FAITH)
	t.check(fb.visible and not fb.open, "信仰横条在、折叠")
	t.check(setup.open_bar(setup.BAR_FAITH) and setup.faith_panel() != null, "展开：神龛一排")
	var gods := Pantheon.gods(flow.faith_defs)
	var open_god: StringName = &""
	var locked_god: StringName = &""
	for g in gods:
		if Pantheon.god_open(flow.meta, g) and open_god == &"":
			open_god = g
		elif not Pantheon.god_open(flow.meta, g) and locked_god == &"":
			locked_god = g
	t.check(open_god != &"", "一档有能选的神")
	if locked_god != &"":
		t.check(not setup.choose_god(locked_god), "没解锁的选不了")
	t.check(setup.choose_god(open_god), "选 %s" % open_god)
	t.eq(setup.faith_head_text(), Names.of(flow.faith_defs[open_god]), "头上写这位神")
	var btn := setup.faith_panel().find_child("Choose_" + String(open_god), true, false) as Button
	t.check(btn != null and btn.disabled and btn.text == UiText.t("pantheon.chosen"), "选着的那座写「奉着」")
	t.check(_free_mode(setup), "第三页挑自由模式")
	t.check(Support.depart(setup), "出发")
	t.eq(flow.run.selected_faith if flow.run != null else &"?", open_god, "这一局奉祂")
	t.eq(Pantheon.choice(flow.meta), open_god, "下回默认沿用")
	game.queue_free()
	Support.cleanup("char")


static func frame_card_numbers_and_belt(t: TestCase, root: Window) -> void:
	t.begin("383 · 科技的局外加成并进角色卡数字、悬停看来源；随身技能挪到配道具页；沿用上回的角色")
	var game = _game(root)
	var flow: GameFlow = game.flow
	var buff := load(ContentPaths.asset_file("run_buffs", "tech_sinew_1")) as RunBuffDef
	flow.buff_defs[buff.id] = buff
	flow.meta.tech_buffs.append(buff.id)
	flow.meta.belt_grants = {&"smoke_bomb": 2}
	var last: CharacterDef = flow.characters[flow.characters.size() - 1]
	flow.meta.last_character = last.id
	flow.new_run()
	var setup = game.base()
	t.eq(setup.character(), last, "沿用上回的角色 %s" % last.id)
	var ch: CharacterDef = setup.character()
	var hp0: float = ch.baseline().value_of(&"max_hp")
	var want: String = setup._num(setup.boosted(hp0, &"max_hp", setup.meta_context()))
	t.check(want != setup._num(hp0), "筋骨 +10%%：生命 %s → %s" % [setup._num(hp0), want])
	var plate: StatSealPlate = setup._stat_plate
	t.eq(plate.values()[0], want, "角色卡上的生命是加过的数")
	t.eq(plate.captions()[0], UiText.t("setup.stat_hp"), "项名照旧")
	var tip: String = (plate.cells[0][0] as Control).tooltip_text
	t.check(tip.contains(UiText.t("setup.stat_source") % [setup._num(hp0), "+" + setup._num(float(want) - hp0)]), "悬停写来源（%s）" % tip)
	setup.show_page(1)
	var slots: Array[BeltGrantSlot] = setup.belt_slots()
	t.check(slots.size() == 1 and slots[0].count == 2 and slots[0].icon() != null, "配道具页一枚随身技能圆槽 × 2")
	t.check(slots.size() == 1 and slots[0].is_visible_in_tree(), "看得见")
	game.queue_free()
	Support.cleanup("char")

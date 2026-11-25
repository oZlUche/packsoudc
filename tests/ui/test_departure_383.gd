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
	flow.meta.coach_seen.append("god_pick")     # 第一次选神的翻书和教练层另有用例（test_pantheon_377）
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
	t.eq(setup.meal_head_text(), UiText.t("canteen.empty_chip"), "锅空：食物横条写空锅")
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
	t.check(Pantheon.unlock(flow.meta, &"brute"), "396：先在万神院解锁蛮神的神殿")
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
	t.check(open_god != &"", "解锁了的神能选")
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


static func _two_menus(flow: GameFlow) -> Canteen:
	C355._open(flow)
	var cn := flow.meta.canteen
	for id in [&"mountain_yam", &"fowl_leg", &"sour_wheat", &"sour_wheat"]:
		cn.store.try_add(C355._inst(flow.items, id, flow.meta.allocate_uid()))
	for pair in [[&"mountain_yam", "山薯"], [&"sour_wheat", "酸麦"]]:
		var it := cn.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == pair[0])[0] as ItemInstance
		cn.store.remove(it.uid)
		cn.pot.place(it, Vector2i(0, 0), 0)
		cn.active = -1
		cn.save_menu(String(pair[1]))
		cn.empty_pot()
	return cn


## 一锅「山薯 + 禽腿」的摆法（自由组合用），摆完倒回仓库
static func _free_cells(cn: Canteen) -> Array:
	for id in [&"mountain_yam", &"fowl_leg"]:
		var it := cn.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == id)[0] as ItemInstance
		cn.store.remove(it.uid)
		cn.pot.try_add(it, true)
	var cells := Canteen.layout_of(cn.pot)
	cn.empty_pot()
	return cells


static func _drop_store(cn: Canteen, id: StringName) -> void:
	for inst in cn.store.items():
		if (inst as ItemInstance).def.id == id:
			cn.store.remove((inst as ItemInstance).uid)


static func _setup(root: Window) -> Array:
	var game = _game(root)
	var flow: GameFlow = game.flow
	var cn := _two_menus(flow)
	return [game, flow, cn]


static func frame_meal_bar_states(t: TestCase, root: Window) -> void:
	t.begin("383（作者 11-23）· 食物横条七种：空；上次配方够料自动复用；配方缺料写【食材不足】、不管就不吃、下次为空；自由组合够 / 缺（缺的去掉、小字提醒）；摆了没开饭写「尚未确认」；开过饭只能看")
	var g := _setup(root)
	var game = g[0]
	var flow: GameFlow = g[1]
	var cn: Canteen = g[2]
	t.check(not cn.eat(), "锅空不能开饭")
	t.check(not cn.to_dict().has("fixed") and cn.to_dict().has("last"), "存档不再有固定配方，记上一局")
	var old := {"store": cn.store.to_dict(), "pot": cn.pot.to_dict(), "menus": [], "active": -1, "fixed": 1}
	var back := Canteen.from_dict(old, flow.items)
	t.check(back.last.is_empty() and not back.eaten, "旧档（含 v8.07 的 fixed）：上次没吃、没开饭")
	flow.new_run()
	var setup = game.base()
	t.eq(setup.meal_state(), Canteen.PLAN_EMPTY, "第一次：空")
	t.eq(setup.meal_head_text(), UiText.t("canteen.empty_chip"), "横条写空锅")
	setup.cancel()
	# 上次配方「酸麦」、够料
	cn.last = {"kind": Canteen.LAST_MENU, "name": "酸麦", "cells": (cn.menus[1]["cells"] as Array).duplicate(true)}
	flow.new_run()
	setup = game.base()
	t.eq(setup.meal_state(), Canteen.PLAN_MENU, "上次配方、够料：自动复用")
	t.check(setup.meal_head_text().begins_with("酸麦") and setup.meal_head_text().contains(UiText.t("canteen.recipe_sub")), "写配方名和效果（%s）" % setup.meal_head_text())
	t.eq(cn.pot.item_count(), 0, "进来不动锅")
	setup.cancel()
	# 配方缺料
	_drop_store(cn, &"sour_wheat")
	flow.new_run()
	setup = game.base()
	t.eq(setup.meal_state(), Canteen.PLAN_MENU_SHORT, "上次配方、缺料")
	t.check(setup.meal_head_text().contains(UiText.t("canteen.short_mark")), "写【食材不足】（%s）" % setup.meal_head_text())
	t.check(setup.bar(setup.BAR_MEAL).summary.find_child("Chip_short", true, false) != null, "朱红小牌")
	setup.cancel()
	# 自由组合够料 / 缺料
	var cells := _free_cells(cn)
	cn.last = {"kind": Canteen.LAST_FREE, "name": "", "cells": cells}
	flow.new_run()
	setup = game.base()
	t.eq(setup.meal_state(), Canteen.PLAN_FREE, "上次自由组合、够料")
	t.check(setup.meal_head_text().begins_with(UiText.t("canteen.unnamed")), "写【自由组合】（%s）" % setup.meal_head_text())
	var full := int(setup.meal_effect().get("count", 0))
	setup.cancel()
	_drop_store(cn, &"fowl_leg")
	flow.new_run()
	setup = game.base()
	t.eq(setup.meal_state(), Canteen.PLAN_FREE_SHORT, "上次自由组合、缺料")
	t.check(setup.meal_head_text().contains(UiText.t("canteen.free_short_note")), "一行小字提醒")
	t.check(int(setup.meal_effect().get("count", 0)) == full - 1, "缺的去掉、剩下的照用（%d → %d）" % [full, int(setup.meal_effect().get("count", 0))])
	setup.cancel()
	# 摆了没开饭
	var yam := cn.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"mountain_yam")[0] as ItemInstance
	cn.store.remove(yam.uid)
	cn.pot.place(yam, Vector2i(0, 0), 0)
	flow.new_run()
	setup = game.base()
	t.eq(setup.meal_state(), Canteen.PLAN_UNCONFIRMED, "锅里摆着、没按开饭")
	t.check(setup.meal_head_text().contains(UiText.t("canteen.unconfirmed")), "写「食物尚未确认」")
	setup.open_bar(setup.BAR_MEAL)
	t.check(setup._meal_box.find_child("ConfirmMeal", true, false) != null, "展开有【确认这一锅】")
	t.eq(Bare.audit(setup._meal_box, "meal383"), [] as Array[String], "字不裸")
	setup.confirm_meal()
	t.eq(setup.meal_state(), &"confirmed", "确认了")
	t.check(not setup.meal_head_text().contains(UiText.t("canteen.unconfirmed")), "不再写尚未确认")
	setup.cancel()
	# 开过饭
	t.check(flow.canteen_eat(), "食堂【开饭】")
	flow.new_run()
	setup = game.base()
	t.eq(setup.meal_state(), Canteen.PLAN_EATEN, "开过饭")
	t.check(setup.meal_head_text().contains(UiText.t("canteen.eaten_mark")), "写「已开饭」")
	setup.open_bar(setup.BAR_MEAL)
	t.check(setup.meal_buttons().is_empty() and setup._meal_box.find_child("EatenNote", true, false) != null, "展开只能看、不能换")
	t.eq(setup.choose_menu(0), -1, "换不了")
	setup.cancel()
	game.queue_free()
	Support.cleanup("char")


static func frame_meal_leave_and_eat(t: TestCase, root: Window) -> void:
	t.begin("383（作者 11-23）· 没确认就离开第一屏弹窗（继续离开 = 这局不吃、锅留着）；配方缺料不管 = 不吃、下次为空；自由组合缺料吃剩下的；出发那一刻才吃；应用配方缺料弹「食材不足」")
	# 1. 没确认 → 弹窗 → 继续离开 → 出发不吃、锅留着
	var g := _setup(root)
	var game = g[0]
	var flow: GameFlow = g[1]
	var cn: Canteen = g[2]
	var yam := cn.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"mountain_yam")[0] as ItemInstance
	cn.store.remove(yam.uid)
	cn.pot.place(yam, Vector2i(0, 0), 0)
	flow.new_run()
	var setup = game.base()
	t.check(not setup.next_page() and setup._notice_up(), "离开第一屏：弹「食物还没确认」")
	t.eq(setup.meal_notice.keys.size(), 2, "两颗键：继续离开 / 留下确认")
	setup.meal_notice.key(UiText.t("canteen.leave_stay")).pressed.emit()
	t.check(setup._page == 0 and setup.bar(setup.BAR_MEAL).open, "留下确认：还在第一屏，食物横条展开")
	setup.next_page()
	setup.meal_notice.key(UiText.t("canteen.leave_go")).pressed.emit()
	t.eq(setup._page, 1, "继续离开：到第二屏")
	t.check(_free_mode(setup) and Support.depart(setup), "出发")
	var mod := MealModule.of(flow.run) if flow.run != null else null
	t.check(mod == null or not mod.has_meal(), "这一局没有食物效果")
	t.check(cn.pot.has_item(yam.uid), "锅里的食材原样留着")
	t.check(cn.last.is_empty(), "上一局记成没吃")
	game.queue_free()
	Support.cleanup("char")
	# 2. 配方缺料不管 → 不吃，下次为空
	g = _setup(root)
	game = g[0]
	flow = g[1]
	cn = g[2]
	cn.last = {"kind": Canteen.LAST_MENU, "name": "酸麦", "cells": (cn.menus[1]["cells"] as Array).duplicate(true)}
	_drop_store(cn, &"sour_wheat")
	flow.new_run()
	setup = game.base()
	t.check(_free_mode(setup) and Support.depart(setup), "配方缺料：照样出发")
	mod = MealModule.of(flow.run) if flow.run != null else null
	t.check(mod == null or not mod.has_meal(), "这一局没有食物效果")
	t.eq(cn.plan()["state"], Canteen.PLAN_EMPTY, "下次出征是空的")
	game.queue_free()
	Support.cleanup("char")
	# 3. 自由组合缺料 → 吃剩下的；出发那一刻才从仓库拿
	g = _setup(root)
	game = g[0]
	flow = g[1]
	cn = g[2]
	cn.last = {"kind": Canteen.LAST_FREE, "name": "", "cells": _free_cells(cn)}
	_drop_store(cn, &"fowl_leg")
	var yam_uid := (cn.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"mountain_yam")[0] as ItemInstance).uid
	flow.new_run()
	setup = game.base()
	t.check(cn.store.has_item(yam_uid), "进来、翻页都不拿")
	t.check(_free_mode(setup) and Support.depart(setup), "出发")
	mod = MealModule.of(flow.run) if flow.run != null else null
	t.check(mod != null and mod.has_meal(), "吃到了剩下的那部分")
	t.check(not cn.store.has_item(yam_uid) and cn.pot.item_count() == 0, "出发那一刻吃掉山薯")
	t.check(String(cn.last.get("kind", "")) == Canteen.LAST_FREE and (cn.last["cells"] as Array).size() == 1, "记成自由组合（吃下去的那一锅）")
	game.queue_free()
	Support.cleanup("char")
	# 4. 横条里应用缺料的配方 → 弹「食材不足」，够的照用；食堂页同样弹，没有【固定】键
	g = _setup(root)
	game = g[0]
	flow = g[1]
	cn = g[2]
	_drop_store(cn, &"sour_wheat")
	flow.new_run()
	setup = game.base()
	setup.open_bar(setup.BAR_MEAL)
	t.eq(setup.meal_buttons().size(), 2, "两份配方各一颗【应用】")
	t.eq(setup.choose_menu(1), 1, "应用「酸麦」：缺 1 样")
	t.check(setup._notice_up(), "弹「食材不足」")
	setup.meal_notice.keys[0].pressed.emit()
	t.eq(setup.meal_state(), Canteen.PLAN_MENU_SHORT, "一样都凑不出：横条仍是【食材不足】（测试 v8.17）")
	t.check(setup.meal_head_text().contains(UiText.t("canteen.short_mark")), "头上写【食材不足】（%s）" % setup.meal_head_text())
	t.eq(setup.choose_menu(0), 0, "应用「山薯」：够")
	t.eq(setup.meal_state(), Canteen.PLAN_MENU, "横条照「山薯」")
	setup.cancel()
	var panel = load("res://ui/game/canteen_panel.gd").new()
	var drag := DragLayer.new()
	root.add_child(drag)
	root.add_child(panel)
	panel.setup(flow, drag, ThemeDB.fallback_font)
	t.eq(panel.find_children("Fix", "Button", true, false).size(), 0, "食堂页没有【固定】键")
	t.check(panel.load_menu(1).size() == 1 and panel.short_notice != null, "食堂里应用缺料的配方：照摆、弹「食材不足」")
	panel.short_notice.close()
	panel.load_menu(0)
	t.check(panel.eat() and cn.eaten, "照「山薯」摆好、【开饭】")
	t.check(not drag._views.has(panel.pot_view), "开过饭：锅拖不动")
	panel.free()
	drag.free()
	game.queue_free()
	Support.cleanup("char")

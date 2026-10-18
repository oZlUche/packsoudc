## 196（作者定稿「甲 · 夜晚营地」）：休息点整屏是营地 —— 选项按后果画成造物，锁住换图不藏，歇完不跳屏（篝火熄、冒一行体力），
## 神坛 / 铸炉回来还是营地，两份用完留在营地只剩路标
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const F175 := preload("res://tests/run/test_forge_175.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Camp := preload("res://ui/game/rest_camp_screen.gd")


static func _pieces_of(def: EventDef) -> Array:
	return def.options.map(func(o): return Camp.piece_of(o as EventOption))


static func _index(def: EventDef, piece: StringName) -> int:
	return _pieces_of(def).find(piece)


static func run_mapping(t: TestCase) -> void:
	t.begin("196 · 选项 → 造物看后果；摆位按造物集合挑（教程三档）；事件的 scene 决定用哪一屏；导入器只认空或 rest_camp")
	var c = NodeScreens._content()
	var rest: EventDef = c.events.get(&"rest_default", null)
	t.not_null(rest, "有默认休息事件")
	if rest == null:
		return
	t.eq(rest.scene, EventDef.SCENE_REST_CAMP, "rest_default 演成营地")
	t.eq(_pieces_of(rest), [&"fire", &"tent", &"altar", &"forge", &"sign"], "篝火 / 帐篷 / 祭坛 / 铁炉 / 路标")
	t.eq(Camp.variant_for([&"fire", &"tent", &"altar", &"forge", &"sign"]), &"full", "四件全有：full")
	for id in [&"tut3_rest_1", &"tut3_rest_2"]:
		var tut: EventDef = c.events.get(id, null)
		t.check(tut != null and tut.scene == EventDef.SCENE_REST_CAMP, "%s 也是营地" % id)
		if tut != null:
			t.eq(Camp.variant_for(_pieces_of(tut)), &"tutorial_fire_tent_altar", "%s 落「篝火 + 帐篷 + 祭坛」那一档（加了扎营，待定 3 A）" % id)
	t.eq(Camp.variant_for([&"fire", &"sign"]), &"tutorial_fire", "只有篝火")
	t.eq(Camp.variant_for([&"fire", &"tent", &"sign"]), &"tutorial_fire_tent", "篝火 + 帐篷")
	t.eq(GameDirector.script_for(GameFlow.Screen.EVENT, {"def": rest}), GameDirector.CAMP_SCRIPT, "营地事件 → 营地屏")
	t.eq(GameDirector.script_for(GameFlow.Screen.EVENT, {"camp": rest, "done": true}), GameDirector.CAMP_SCRIPT, "用完的那一屏也是营地")
	var plain := EventDef.new()
	t.eq(GameDirector.script_for(GameFlow.Screen.EVENT, {"def": plain}), String(GameDirector.SCREEN_SCRIPTS[GameFlow.Screen.EVENT]), "别的事件照旧走事件屏")
	t.check(not FileAccess.file_exists("res://ui/game/rest_screen.gd"), "休息区结果屏删了")
	var report := ImportReport.new()
	ContentImporter.import_event({"id": "x", "scene": "camp_typo", "options": [{"label": "走"}]}, ContentImporter.Context.new(), report)
	t.check(not report.ok(), "不认得的场景：导入报错")
	var ok_report := ImportReport.new()
	ContentImporter.import_event({"id": "y", "scene": "rest_camp", "options": [{"label": "走"}]}, ContentImporter.Context.new(), ok_report)
	t.check(ok_report.ok(), "rest_camp 认得")


static func run_rest_stays(t: TestCase) -> void:
	t.begin("196 · 营地里歇：不跳休息区屏、不弹结果页；记下回了几点；还有没用的就重新挂起营地，两份用完留一屏只剩路标")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "camp196")
	var node := F175._rest_next_to_spawn(f, c, kit)
	t.check(node != null and f.step_to(node.id), "走上休息点")
	if node == null:
		Support.cleanup("camp196")
		return
	var def: EventDef = f.run.events.pending_event()
	t.check(def != null and def.scene == EventDef.SCENE_REST_CAMP, "挂起的是营地事件")
	f.run.vitality.spend(f.run.vitality.current - 1, &"test")
	var before := f.run.vitality.current
	var tent := _index(def, &"tent")
	t.check(f.choose_event(tent), "点帐篷")
	var gained := f.run.vitality.current - before
	t.check(gained > 0, "扎营回了体力（%d）" % gained)
	t.eq(f.screen, GameFlow.Screen.EVENT, "还在营地（不跳休息区、不弹结果页）")
	t.eq(int(f.camp_rest.get("restored", -1)), gained, "记下的是一共回的点数（扎营那一份也并进来）")
	t.eq(int(f.camp_rest.get("node", -1)), node.id, "记的是这个点")
	if f.run.active_faith_id() == &"":
		t.check(node.is_visited(), "没信仰：歇完两份都算用完")
		t.check(bool(f.last_payload.get("done", false)) and f.last_payload.get("camp", null) == def, "留一屏营地（done）")
		f.resume()
		t.eq(f.screen, GameFlow.Screen.MAP, "点路标（resume）回地图")
	else:
		t.eq(f.run.events.pending_event(), def, "有信仰：营地重新挂起")
	Support.cleanup("camp196")


static func run_altar_back_to_camp(t: TestCase) -> void:
	t.begin("196 待定 2 A · 从铸炉回来：休息点还有没用的就回营地，不回地图")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "camp196b")
	var node := F175._rest_next_to_spawn(f, c, kit)
	t.check(node != null and f.step_to(node.id), "走上休息点")
	if node == null:
		Support.cleanup("camp196b")
		return
	var def: EventDef = f.run.events.pending_event()
	t.check(f.choose_event(_index(def, &"forge")), "点铁炉")
	t.eq(f.screen, GameFlow.Screen.FORGE, "→ 铸炉屏")
	t.check(f.leave_forge(), "离开铸炉")
	t.eq(f.screen, GameFlow.Screen.EVENT, "回到营地")
	t.eq(f.run.events.pending_event(), def, "营地事件重新挂起")
	Support.cleanup("camp196b")


static func frame_camp_screen(t: TestCase, root: Window) -> void:
	t.begin("196 · 营地屏：没信仰祭坛画用过的图、点不动、悬浮窗写原因；点篝火：体力涨、篝火帐篷都换用过的图、冒一行字；透明处不算点中；路标回地图")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("camp196_ui")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("camp196_ui")["run"])
	game.meta_path = String(Support.paths("camp196_ui")["meta"])
	game.settings_path = String(Support.paths("camp196_ui")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	var node := F175._rest_next_to_spawn(flow, c, kit)
	t.check(node != null and flow.step_to(node.id), "走上休息点")
	var screen = game.overlay()
	if screen == null or not screen.has_method("piece"):
		t.check(false, "叠层是营地屏")
		game.queue_free()
		Support.cleanup("camp196_ui")
		return
	t.eq(screen.variant(), &"full", "四件全摆")
	var altar = screen.piece(&"altar")
	t.check(altar != null, "祭坛照摆（不藏）")
	if flow.run.active_faith_id() == &"" and altar != null:
		t.check(not altar.enabled and altar.texture_name() == "altar_used", "没信仰：画用过的祭坛")
		t.check(not screen.click(&"altar"), "点不动")
		t.eq(altar.medal, "", "没信仰不画徽章")
		screen._on_piece_hovered(true, altar)
		t.check(screen._tip.text().contains("祭坛") and screen._tip.text().contains(altar.why) and altar.why != "", "悬浮窗：名字 + 原因（%s）" % screen._tip.text())
	var fire = screen.piece(&"fire")
	t.check(fire != null and fire.enabled and fire.texture_name() == "fire_lit", "篝火亮着")
	if fire != null:
		t.check(not fire._has_point(Vector2(1, 1)), "图的透明角落：不算点中")
		t.check(fire._has_point(fire.size * Vector2(0.5, 0.75)), "火堆中间：点中")
	flow.run.vitality.spend(flow.run.vitality.current - 1, &"test")
	var before := flow.run.vitality.current
	t.check(screen.click(&"fire"), "点篝火")
	t.check(flow.run.vitality.current > before, "体力涨了")
	t.eq(flow.screen, GameFlow.Screen.EVENT, "没跳休息区屏")
	screen = game.overlay()
	t.check(screen != null and screen.has_method("piece"), "还是营地")
	if screen != null and screen.has_method("piece"):
		t.check(screen.rest_note().begins_with("体力 +%d" % (flow.run.vitality.current - before)), "冒一行：%s" % screen.rest_note())
		t.eq(screen.piece(&"fire").texture_name(), "fire_out", "篝火熄了")
		t.eq(screen.piece(&"tent").texture_name(), "tent_used", "帐篷也换成用过的（同一份歇脚）")
		t.check(not screen.click(&"tent"), "再点帐篷无效")
		t.check(screen.piece(&"sign").enabled, "路标能点")
		var forge = screen.piece(&"forge")
		t.check(forge != null and forge.enabled, "铁炉还能点")
		t.check(screen.click(&"sign"), "点路标")
	t.eq(flow.screen, GameFlow.Screen.MAP, "回地图")
	game.queue_free()
	Support.cleanup("camp196_ui")


static func frame_text_board(t: TestCase, root: Window) -> void:
	t.begin("196 补充一 · 事件有正文才出字板（教程的神坛教献祭）：正文照事件屏替换，× 收起成卷轴、同一个点里记住；rest_default 没字板")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	for case in [[&"tut3_rest_1", true], [&"rest_default", false]]:
		Support.cleanup("camp196_board")
		var game = (load(GAME) as PackedScene).instantiate()
		game.save_path = String(Support.paths("camp196_board")["run"])
		game.meta_path = String(Support.paths("camp196_board")["meta"])
		game.settings_path = String(Support.paths("camp196_board")["settings"])
		root.add_child(game)
		var flow: GameFlow = game.flow
		flow.chapters = [c.chapter] as Array[ChapterDef]
		var node := F175._rest_next_to_spawn(flow, c, kit)
		if node == null:
			t.check(false, "找得到休息点")
			game.queue_free()
			continue
		node.content["event"] = String(case[0])
		t.check(flow.step_to(node.id), "走上休息点（%s）" % case[0])
		var screen = game.overlay()
		t.check(screen != null and screen.has_method("board_shown"), "叠层是营地屏")
		if screen != null and screen.has_method("board_shown"):
			if case[1]:
				t.check(screen.board_shown(), "教程：有字板")
				t.check(screen.board_text().contains("骨骰子") and not screen.board_text().contains("{"), "{item:bone_dice} 换成了名字（%s）" % screen.board_text().left(60))
				screen.fold_board(true)
				t.check(not screen.board_shown() and screen._scroll.visible, "× 收起：只剩卷轴")
				screen._reopen(screen._payload)
				t.check(not screen.board_shown(), "营地重画：还是收着")
				screen.fold_board(false)
				t.check(screen.board_shown(), "点卷轴：展开")
			else:
				t.check(not screen.board_shown() and screen.board_text() == "", "rest_default：没有字板")
		game.queue_free()
	Support.cleanup("camp196_board")

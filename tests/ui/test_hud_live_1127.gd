## 作者 11-27：顶端栏的读数要即时 —— 选牌加了体力上限（【耐行】只加空容器）左上角的心当场多一颗；
## 进点拿到的经验当场灌进经验值条：进点开着叠层（战前、搜索……）时顶端栏这一条抬到叠层上面，不被压暗盖住；鼠标仍归叠层
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "hud_live_1127"


static func frame_readings_follow_model(t: TestCase, root: Window) -> void:
	t.begin("11-27 · 顶栏读数即时：只加空的体力容器心也立刻多；加经验等级格立刻变；金币立刻变")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var host := HudHost.new()
	host.size = Vector2(1200, 700)
	root.add_child(host)
	host.setup(run, null, HudLayout.default_for("map"))
	var vit := host.widget(&"vitality")
	var cur := run.vitality.current
	run.vitality.set_max(run.vitality.maximum + 2, &"level_card", false)
	t.eq(run.vitality.current, cur, "空容器：当前体力没变")
	t.eq(vit.hearts(), Vector2i(run.vitality.maximum, run.vitality.current), "心数立刻跟上上限（没等别的事来刷）")
	t.eq(vit.text(), UiText.t("hud.vitality") % [run.vitality.current, run.vitality.maximum], "提示里的数也跟上")
	run.vitality.set_max(run.vitality.maximum - 1, &"level_card", false)
	t.eq(vit.hearts(), Vector2i(run.vitality.maximum, run.vitality.current), "上限降回去也立刻跟上")
	var lv := LevelModule.of(run)
	if lv != null:
		var lw := host.widget(&"level")
		var need := float(lv.progress().y)
		lv.gain(need / maxf(0.01, lv.mult()) + 1.0, LevelModule.SRC_DEPTH)
		t.eq(lw.text(), str(lv.level()), "加经验升了级：等级格立刻是新等级")
	var wallet := host.widget(&"wallet")
	run.wallet.earn(7)
	t.eq(wallet.text(), "%d" % run.wallet.balance, "金币立刻变")
	host.free()


static func frame_bar_above_overlay(t: TestCase, root: Window) -> void:
	t.begin("11-27 · 进点开着叠层：顶端栏、栏里的读数、经验值条抬到叠层上面；鼠标仍归叠层；回到地图放回去")
	var c := GF._content()
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是搜索点的种子")
		return
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {}
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [ch] as Array[ChapterDef]
	flow.begin(ch, kit, int(found["seed"]), [] as Array[int], null)
	var map = game.base()
	if flow.run.travel.current_id < 0:
		map.pick_spawn(int(found["entry"]))
	Support.skip_opening_pick(map, flow.run)
	var host: HudHost = map._hud_host
	var up := GameDirector.OVERLAY_Z + 1
	for id in [&"hud_bar", &"vitality", &"xp_bar"]:
		var w := host.widget(id)
		if w != null:
			t.eq(w.z_index, 0, "地图上没叠层：%s 不抬" % id)
	t.check(map.step(int(found["next"])), "走进搜索点")
	t.check(game.overlay() != null, "开着叠层")
	for id in [&"hud_bar", &"vitality", &"wallet", &"xp_bar"]:
		var w := host.widget(id)
		if w != null:
			t.eq(w.z_index, up, "叠层开着：%s 抬到叠层上面" % id)
	var below := host.widget(&"status_slate")
	if below != null:
		t.eq(below.z_index, 0, "栏外的读数（状态石板）不抬")
	var vit := host.widget(&"vitality")
	var pos: Vector2 = vit.get_global_rect().get_center()
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)
	var hovered := root.gui_get_hovered_control()
	t.check(hovered != vit and not (hovered != null and vit.is_ancestor_of(hovered)), "鼠标停在心上接到的是叠层，不是顶栏（%s）" % hovered)
	var def: EventDef = flow.last_payload.get("def", null)
	var leave := -1
	if def != null:
		for i in def.options.size():
			if (def.options[i] as EventOption).label == "离开":
				leave = i
	t.check(leave >= 0 and flow.choose_event(leave), "选「离开」回地图")
	GF._settle_overlays(flow)
	t.check(game.overlay() == null, "回到地图（屏 %d，叠层 %s）" % [flow.screen, game.overlay()])
	t.eq(host.widget(&"hud_bar").z_index, 0, "回到地图：放回去")
	game.flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)

## 秒杀绕过模拟，日志为空；开战过场仍须放开回放并显示继续。
extends RefCounted

const Nodes := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "smite_replay"


static func frame_smite_replay(t: TestCase, root: Window) -> void:
	t.begin("蛮神秒杀：普通/精英 × 体力/信力 × 动效开/关，空回放结束后能领取战利品")
	for type in [&"battle", &"elite"]:
		for option in [SmitePerk.VITALITY, SmitePerk.FAITH]:
			for motion in [false, true]:
				_case(t, root, type, option, motion)


static func _case(t: TestCase, root: Window, type: StringName, option: StringName, motion: bool) -> void:
	var label := "%s/%s/motion=%s" % [type, option, motion]
	var c := Nodes._content()
	var kit := Nodes._kit(c)
	var found := Nodes._seed_with(c, type, kit.items)
	t.check(not found.is_empty(), label + "：找到目标节点")
	if found.is_empty():
		return
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {}
	var prefix := PREFIX + "_" + type + "_" + option + ("_on" if motion else "_off")
	var p := Support.paths(prefix)
	Support.cleanup(prefix)
	var game = load("res://ui/game/game.tscn").instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var f: GameFlow = game.flow
	f.chapters = [ch] as Array[ChapterDef]
	f.begin(ch, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	Support.activate(f.run, &"charm_brute")
	f.run.faith_power.add_points(&"brute", 200)
	t.check(f.step_to(int(found["next"])), label + "：到战前准备")
	var pre = game.overlay()
	GameDirector.fades_allowed = motion
	t.check(pre.smite(option), label + "：立即击败")
	var battle = game.overlay()
	t.eq(battle.screen, GameFlow.Screen.BATTLE, "进入回放")
	t.eq(battle.intro_running(), motion, label + "：过场遵守动效开关")
	var ended := []
	battle.view().finished.connect(func(): ended.append(true))
	if motion:
		t.check(battle.view().is_held(), label + "：过场暂停回放")
		battle._end_intro()
	battle.view()._process(0.1)
	t.check(battle._seen_end and battle._next != null, label + "：空回放自动显示继续")
	t.eq(ended.size(), 1, label + "：结束信号只发一次")
	battle.view().hold()
	battle.view().release()
	battle.view()._process(0.1)
	t.eq(ended.size(), 1, label + "：结束后暂停恢复不重复结算")
	battle.proceed()
	t.eq(f.screen, GameFlow.Screen.LOOT, "继续到战利品")
	GameDirector.fades_allowed = false
	game.queue_free()
	Support.cleanup(prefix)

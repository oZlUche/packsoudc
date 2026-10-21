## 166 补充二（作者定）：战斗屏也放静态指引 —— 同一个 CoachOverlay，目标是回放层的控件；
## 这一章第一场战斗淡入后放一次，期间回放停着；看过记在局外；调试台能让下一场再放
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "battle_coach"


static func run_coach_data(t: TestCase) -> void:
	t.begin("166 补充二 · 战斗教程是数据：六步按看屏幕的顺序，目标都在 BattleView.COACH_TARGETS 里、都有字；只有序章一写了")
	var steps := CoachOverlay.load_steps(&"prologue_battle")
	var targets: Array = steps.map(func(s: Dictionary) -> String: return String(s["target"]))
	t.eq(targets, ["timeline", "play_button", "speed_button", "skip_button", "buffs_mine", "next_button"], "六步按顺序")
	t.eq(CoachOverlay.problems(steps, BattleView.COACH_TARGETS), [] as Array[String], "目标都认得、都有字")
	t.check(not CoachOverlay.problems(steps).is_empty(), "拿地图屏的读数部件去对：对不上（两套目标分开认）")
	var bad := CoachOverlay.problems([{"target": "vitality", "text": "x"}], BattleView.COACH_TARGETS)
	t.check(bad.size() == 1 and bad[0].contains("vitality"), "战斗屏没有体力读数：报出来")
	for ch in DirAccess.get_files_at("res://data/chapters"):
		if not ch.ends_with(".tres"):
			continue
		var def := load("res://data/chapters/" + ch) as ChapterDef
		if def == null:
			continue
		if def.id == &"prologue":
			t.eq(def.coach_for(&"battle"), &"prologue_battle", "序章一写了战斗教程")
		elif def.coach_for(&"battle") != &"":
			var s := CoachOverlay.load_steps(def.coach_for(&"battle"))
			t.check(not s.is_empty() and CoachOverlay.problems(s, BattleView.COACH_TARGETS).is_empty(), "%s 的战斗教程 %s 读得到、没问题" % [def.id, def.coach_for(&"battle")])


## 容器的排布是延迟的，同一帧里手动排一遍（从外到里）
static func _lay_out(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_lay_out(c)


static func frame_battle_coach(t: TestCase, root: Window) -> void:
	t.begin("166 补充二 · 写了战斗教程的章：第一场开屏就停住回放、放六步，点完收掉、接着放、记在局外；再开不放；调试台让下一场再放")
	var c := GF._content()
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是战斗点的种子")
		return
	var ch := c.chapter.duplicate() as ChapterDef     # 别改缓存里的那份
	ch.coaches = {"battle": "prologue_battle", "prebattle": "prologue_prebattle"}     # 218 补充一：战前屏的也一并验
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [ch] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(ch, kit, int(found["seed"]), [] as Array[int], null)
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	map.step(int(found["next"]))
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备")
	if pre != null and pre.screen == GameFlow.Screen.PREBATTLE:
		# 218 补充一（217 批三）：第一次进战前屏放三步（对手、天平、自己），四个目标都找得到；走完记在局外
		_lay_out(pre)
		t.check(pre.show_coach(), "战前教程开了")
		var po: CoachOverlay = pre.coach()
		if po != null:
			t.eq(po.get_parent(), pre, "盖在战前屏上")
			t.eq(po.steps.size(), 3, "三步")
			for id in pre.COACH_TARGETS:
				var r: Rect2 = pre.control_rect(id)
				t.check(r.size.x > 0.0 and r.size.y > 0.0, "战前 %s 找得到（%s）" % [id, r])
			for i in 3:
				t.check(po.hole().size.x > 0.0, "战前第 %d 步挖了洞" % (i + 1))
				po.next()
		t.is_null(pre.coach(), "三步点完：收掉")
		t.check(flow.meta.coach_seen.has("prologue_prebattle"), "战前教程记在局外")
		t.check(not CoachOverlay.due(flow, &"prologue_prebattle"), "看过了：下一次不放")
	t.check(pre != null and pre.start_battle(), "战前准备 → 开战")
	var screen = game.overlay()
	if screen == null or screen.screen != GameFlow.Screen.BATTLE:
		t.check(false, "没到回放屏")
		game.queue_free()
		Support.cleanup(PREFIX)
		return
	var view: BattleView = screen.view()
	t.check(view.is_held() and not view.is_playing(), "开屏就停住（教程还没出来，一帧都不偷跑）")
	view._process(1.0)
	t.eq(view.now(), 0.0, "停着：时间不走")
	screen.call("_maybe_coach")     # 屏上是延迟调用，这里直接叫
	var o: CoachOverlay = screen.coach()
	t.not_null(o, "教程开了")
	if o == null:
		game.queue_free()
		Support.cleanup(PREFIX)
		return
	t.eq(o.get_parent(), screen, "盖在回放屏上")
	t.eq(o.steps.size(), 6, "六步")
	_lay_out(screen)
	for id in BattleView.COACH_TARGETS:
		var r := view.control_rect(id)
		t.check(r.size.x > 0.0 and r.size.y > 0.0, "%s 找得到（%s）" % [id, r])
	t.eq(view.control_rect(&"nope"), Rect2(), "不认得的 id：空矩形")
	t.eq(view.control_rect(&"next_button"), screen._next.get_global_rect(), "「跳过并继续」是战斗屏登记的那个按钮")
	t.check(o.hole().size.x > 0.0, "第一步挖了洞（时间轴）")
	for i in o.steps.size() - 1:
		o.next()
		t.check(view.is_held(), "第 %d 步：回放还停着" % (i + 2))
	view._process(1.0)
	t.eq(view.now(), 0.0, "教程期间时间一直没走")
	o.next()
	t.is_null(screen.coach(), "六步点完：收掉")
	t.check(not view.is_held() and view.is_playing(), "回放接着放")
	view._process(0.1)
	t.check(view.now() > 0.0, "时间走起来了（%.2f 秒）" % view.now())
	t.check(flow.meta.coach_seen.has("prologue_battle"), "记在局外")
	t.check(not screen.coach_due(), "看过了：下一场不放")
	ch.coaches = {}
	t.check(not screen.coach_due(), "没写战斗教程的章：不放")
	ch.coaches = {"battle": "prologue_battle"}
	map.replay_battle_coach()
	t.check(not flow.meta.coach_seen.has("prologue_battle") and screen.coach_due(), "调试台「重放战斗教程」：下一场再放")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)


static func frame_hold_release(t: TestCase, root: Window) -> void:
	t.begin("166 补充二 · 回放的停住 / 接着放：停之前在放才接着放；停着时重播也不偷跑；播完了不动")
	var c := GF._content()
	var f := Support.flow(c, PREFIX)
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	var result: BattleResult = null
	if not found.is_empty():
		f.new_run()
		f.begin(c.chapter, kit, int(found["seed"]))
		f.pick_spawn(int(found["entry"]))
		f.step_to(int(found["next"]))
		f.start_battle()
		result = f.last_payload.get("result", null)
	Support.cleanup(PREFIX)
	if result == null:
		t.check(false, "没有一场战斗结果")
		return
	var view := BattleView.new()
	root.add_child(view)
	view.play(result)
	t.check(view.is_playing(), "开播")
	view.hold()
	t.check(not view.is_playing(), "停住")
	view.release()
	t.check(view.is_playing(), "在放时停的：接着放")
	view.toggle_play()
	view.hold()
	view.release()
	t.check(not view.is_playing(), "暂停着停的：还是暂停")
	view.hold()
	view.play(result)
	t.check(not view.is_playing(), "停着时重播：不偷跑")
	view.release()
	t.check(view.is_playing(), "收掉后放")
	view.skip_to_end()
	view.hold()
	view.release()
	t.check(not view.is_playing(), "播完了：不动")
	view.queue_free()

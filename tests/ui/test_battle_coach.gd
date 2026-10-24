## 166 补充二（作者定）：战斗屏也放静态指引 —— 同一个 CoachOverlay，目标是回放层的控件；
## 这一章第一场战斗淡入后放一次，期间回放停着；看过记在局外；调试台能让下一场再放
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "battle_coach"


static func run_coach_data(t: TestCase) -> void:
	t.begin("166 补充二 · 战斗教程是数据：四步按看屏幕的顺序（220 压了步），目标都在 BattleView.COACH_TARGETS 里、都有字；只有序章一写了")
	var steps := CoachOverlay.load_steps(&"prologue_battle")
	var targets: Array = steps.map(func(s: Dictionary) -> String: return String(s["target"]))
	t.eq(targets, ["timeline", "play_button", "buffs_mine", "next_button"], "220：四步按顺序（播放 / 倍速 / 跳过并成一步）")
	t.eq(CoachOverlay.problems(steps, BattleView.COACH_TARGETS), [] as Array[String], "目标都认得、都有字")
	t.check(not CoachOverlay.problems(steps).is_empty(), "拿地图屏的读数部件去对：对不上（两套目标分开认）")
	var bad := CoachOverlay.problems([{"target": "vitality", "text": "x", "texts": {"en": "x"}}], BattleView.COACH_TARGETS)
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
	t.begin("166 补充二 · 写了战斗教程的章：第一场开屏就停住回放、放四步，点完收掉、接着放、记在局外；再开不放；调试台让下一场再放")
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
	var flag: IconButton = pre._start_btn as IconButton if pre != null else null
	t.check(flag != null and flag.has_art() and flag.text == "", "作者 2026-10-21：「开战」是战旗图（字画在图里）")
	if flag != null:
		t.eq(flag.custom_minimum_size, Vector2(216, 134), "战旗 216 × 134")
		t.check(flag._has_point(Vector2(100, 60)) and not flag._has_point(Vector2(4, 4)) and not flag._has_point(Vector2(210, 60)), "可点的是旗面，挂杆两头不算")
		t.check(not flag.disabled and flag.icon == flag._states[""], "能开战：正常那一态")
		flag.disabled = true
		flag.sync_art()
		t.eq(flag.icon, flag._states.get("_disabled", null), "灰着：换灰的那一态")
		flag.disabled = false
		flag.sync_art()
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
	t.eq(o.steps.size(), 4, "220：四步")
	_lay_out(screen)
	for id in BattleView.COACH_TARGETS:
		var r := view.control_rect(id)
		t.check(r.size.x > 0.0 and r.size.y > 0.0, "%s 找得到（%s）" % [id, r])
	t.eq(view.control_rect(&"nope"), Rect2(), "不认得的 id：空矩形")
	t.eq(view.control_rect(&"next_button"), screen._next_slot.get_global_rect(), "教程指的是「继续」那一格（回放中空着）")
	t.is_null(screen._next, "作者 2026-10-21：回放中没有按钮（「跳过并继续」删了）")
	t.check(o.hole().size.x > 0.0, "第一步挖了洞（时间轴）")
	for i in o.steps.size() - 1:
		o.next()
		t.check(view.is_held(), "第 %d 步：回放还停着" % (i + 2))
	view._process(1.0)
	t.eq(view.now(), 0.0, "教程期间时间一直没走")
	o.next()
	t.is_null(screen.coach(), "四步点完：收掉")
	t.check(not view.is_held() and view.is_playing(), "回放接着放")
	view._process(0.1)
	t.check(view.now() > 0.0, "时间走起来了（%.2f 秒）" % view.now())
	t.is_null(screen._next, "还在放：没有「继续」")
	view.seek(view._result.duration_sec() + 1.0)
	var cont: IconButton = screen._next as IconButton
	t.check(cont != null and cont.get_parent() == screen._next_slot and cont.has_art(), "拖时间轴拖到头 = 看完：「继续」战旗落在那一格")
	t.eq(cont.custom_minimum_size if cont != null else Vector2.ZERO, Vector2(216, 134), "作者 19:09：继续是战旗 216 × 134（231：比格子高，上下伸出去）")
	t.check(not screen.medal().visible, "231：拖到头 = 跳过：铜章直接藏起，让位给旗")
	view.seek(view._result.duration_sec() + 1.0)
	t.eq(screen._next_slot.get_children().filter(func(n): return n is IconButton).size(), 1, "再拖到头一次：还是那一面")
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


## 220 §2.1：回放里头一回碰到一种反应 —— 弹字那一刻停住、一步纸条（文字由反应定义拼）指着挨反应那一方的状态行，点了接着放；
## 同一场第二次不停；跳过不停；流程开战时把「这一场头一回的」交给回放屏，局外当场就记下
static func frame_reaction_pause(t: TestCase, root: Window) -> void:
	t.begin("220 · 反应第一次触发：回放停住解释一句，点了接着放；第二次不停；跳过不停；局外当场记")
	var c := GF._content()
	var f := Support.flow(c, PREFIX)
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if not found.is_empty():
		f.new_run()
		f.begin(c.chapter, kit, int(found["seed"]))
		f.pick_spawn(int(found["entry"]))
		f.step_to(int(found["next"]))
		f.start_battle()
		var fresh = f.last_payload.get("new_reactions", null)
		t.check(fresh is Array, "开战的载荷里带「这一场头一回的反应」")
		var res: BattleResult = f.last_payload.get("result", null)
		if fresh is Array and res != null:
			t.eq((fresh as Array).size(), ReactionResolver.reactions_in(res.log).size(), "新档：这一场打出的都是头一回")
			t.check((fresh as Array).all(func(id): return f.meta.reaction_seen(StringName(String(id)))), "局外当场记下（不等回放看完）")
	Support.cleanup(PREFIX)
	f = Support.flow(c, PREFIX)
	var make := func(at_sec: float) -> BattleEvent:
		return BattleEvent.make(BattleEvent.EFFECT_RESOLVED, int(at_sec * StatMath.ONE), 1,
			{"effect": ReactionResolver.EFFECT, "reaction": "poison_bleed", "elements": ["poison", "bleed"]})
	var r := BattleResult.new()
	r.winner = 0
	r.duration = 3 * StatMath.ONE
	r.log.append(BattleEvent.make(BattleEvent.BATTLE_START, 0, -1))
	r.log.append(make.call(1.0))
	r.log.append(make.call(1.0))     # 同一刻又来一次：不能叠第二张纸条
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, int(1.0 * StatMath.ONE), 1, {"amount": 1, "type": "physical"}))
	r.log.append(make.call(2.0))
	var screen = load("res://ui/game/battle_screen.gd").new()
	screen.screen = GameFlow.Screen.BATTLE
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({"result": r, "won": true, "new_reactions": [&"poison_bleed"]})
	var view: BattleView = screen.view()
	_lay_out(screen)
	t.check(view.is_playing() and screen.coach() == null, "开播，没停")
	view._process(0.5)
	t.check(screen.coach() == null, "反应之前不停")
	view._process(0.6)
	var o: CoachOverlay = screen.coach()
	t.not_null(o, "第一次菌血：停下来放一张纸条")
	if o != null:
		t.check(view.is_held() and not view.is_playing(), "回放停住")
		t.eq(o.steps.size(), 1, "一步")
		var text := String(o.step()["text"])
		var def := ReactionResolver.by_id(&"poison_bleed")
		t.eq(text, Encyclopedia.reaction_intro(def), "文字由反应定义拼")
		t.check(text.begins_with("【元素反应】" + Names.of(def) + "：毒碰上血。") and text.ends_with("打出过的都会在百科里点亮。"), "「【元素反应】名字：甲碰上乙。说明　机制一句」（%s）" % text)
		t.check(text.contains("两种不同的元素"), "讲的是机制：两种不同的元素碰上就起反应")
		t.eq(String(o.step()["target"]), "buffs_enemy", "指着挨反应那一方（对手）的状态行")
		t.check(o.hole().size.x > 0.0, "对手的状态行挖得到洞")
		var cur := view._cursor
		view._process(1.0)
		t.eq(view._cursor, cur, "停着：后面的事件不偷跑（同一刻的第二次也没走）")
		o.next()
		t.is_null(screen.coach(), "点一下：收掉")
		t.check(not view.is_held() and view.is_playing(), "接着放")
		view._process(1.5)
		t.is_null(screen.coach(), "同一场第二次菌血：不再停")
	screen.queue_free()
	var skip = load("res://ui/game/battle_screen.gd").new()
	skip.screen = GameFlow.Screen.BATTLE
	skip.flow = f
	skip.font = UiPalette.cjk_font()
	root.add_child(skip)
	skip.open({"result": r, "won": true, "new_reactions": [&"poison_bleed"]})
	skip.view().skip_to_end()
	t.check(skip.coach() == null and not skip.view().is_held(), "跳过：不停、不解释")
	skip.queue_free()
	var seen = load("res://ui/game/battle_screen.gd").new()
	seen.screen = GameFlow.Screen.BATTLE
	seen.flow = f
	seen.font = UiPalette.cjk_font()
	root.add_child(seen)
	seen.open({"result": r, "won": true})
	seen.view()._process(1.5)
	t.check(seen.coach() == null, "见过的反应（载荷里没有）：不停")
	seen.queue_free()
	Support.cleanup(PREFIX)


## 作者 10-24：菌血讲过、后来打出激荡又停一次，试玩者以为同一张教学在重复 —— 元素反应整个存档只讲一次（讲的是机制）
static func frame_reaction_pause_once(t: TestCase, root: Window) -> void:
	t.begin("作者 10-24 · 元素反应的说明整个存档只停一次：同一场两种反应只停第一种；见过任何一种后，新的一种也不停")
	var c := GF._content()
	var f := Support.flow(c, PREFIX)
	var make := func(at_sec: float, id: String, els: Array) -> BattleEvent:
		return BattleEvent.make(BattleEvent.EFFECT_RESOLVED, int(at_sec * StatMath.ONE), 1,
			{"effect": ReactionResolver.EFFECT, "reaction": id, "elements": els})
	var r := BattleResult.new()
	r.winner = 0
	r.duration = 3 * StatMath.ONE
	r.log.append(BattleEvent.make(BattleEvent.BATTLE_START, 0, -1))
	r.log.append(make.call(1.0, "poison_bleed", ["poison", "bleed"]))
	r.log.append(make.call(2.0, "lightning_bleed", ["lightning", "bleed"]))
	var screen = load("res://ui/game/battle_screen.gd").new()
	screen.screen = GameFlow.Screen.BATTLE
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({"result": r, "won": true, "new_reactions": [&"poison_bleed", &"lightning_bleed"]})
	var view: BattleView = screen.view()
	_lay_out(screen)
	view._process(1.1)
	var o: CoachOverlay = screen.coach()
	t.not_null(o, "第一种反应：停下讲一次")
	if o != null:
		o.next()
	view._process(1.5)
	t.is_null(screen.coach(), "同一场第二种反应：不再停")
	screen.queue_free()
	# 流程：存档见过一种反应了 —— 下一场打出别的反应，载荷里不再带「头一回」
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if not found.is_empty():
		f.new_run()
		f.meta.reactions_seen = [&"fire_ice"] as Array[StringName]
		f.begin(c.chapter, kit, int(found["seed"]))
		f.pick_spawn(int(found["entry"]))
		f.step_to(int(found["next"]))
		f.start_battle()
		var fresh = f.last_payload.get("new_reactions", null)
		t.check(fresh is Array and (fresh as Array).is_empty(), "见过一种反应的存档：这一场不再停（%s）" % [fresh])
	Support.cleanup(PREFIX)

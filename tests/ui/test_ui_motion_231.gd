## 231：界面过渡（作者 2026-10-21 19:12）—— UiMotion 六个小动效（关着 = 立即终态、开着 = 终值对）；
## 双剑铜章（事件 → 姿态、分胜负、倍速 ≥ 4 不挥）；战前 → 战斗一镜到底（战前屏垫着、回放演完才起跑、跳过直接终态、继续旗展开前点不着）
extends RefCounted

const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "ui_motion_231"


static func frame_ui_motion(t: TestCase, root: Window) -> void:
	t.begin("231 · UiMotion：开关看测试开关与设置；关着直接终态返回 null；开着先摆起点、走完到终值（展旗裁切走完摘掉材质、展开中点不着）")
	t.check(not UiMotion.enabled(null), "跑测试：关着")
	GameDirector.fades_allowed = true
	var gs := GameSettings.new()
	t.check(UiMotion.enabled(gs) and UiMotion.enabled(null), "测试开关开 + 设置开：动")
	gs.ui_fades = false
	t.check(not UiMotion.enabled(gs), "设置里关了：不动")
	GameDirector.fades_allowed = false

	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 80)
	root.add_child(b)
	b.size = Vector2(120, 80)
	t.is_null(UiMotion.unfurl(b, false), "关着：不造 Tween")
	t.eq(UiMotion.revealed(b), 1.0, "关着：全显")
	t.is_null(b.material, "关着：不挂材质")
	var tw := UiMotion.unfurl(b, true)
	t.not_null(tw, "开着：造 Tween")
	t.eq(UiMotion.revealed(b), 0.0, "起点：一点没显")
	t.check(b.disabled, "展开中点不着")
	t.eq(b.pivot_offset, Vector2(60, 0), "绕旗顶中点摆")
	if tw != null:
		tw.custom_step(UiMotion.UNFURL_SEC * 0.5)
		var mid := UiMotion.revealed(b)
		t.check(mid > 0.0 and mid < 1.0, "走一半：显出一部分（%s）" % mid)
		tw.custom_step(2.0)
	t.eq(UiMotion.revealed(b), 1.0, "走完：全显")
	t.is_null(b.material, "走完：材质摘了（和没动过一样）")
	t.check(not b.disabled and is_zero_approx(b.rotation), "走完：能点、摆正")
	b.disabled = true
	var tw2 := UiMotion.unfurl(b, true)
	tw2.custom_step(2.0)
	t.check(b.disabled, "本来灰着的旗：展开完还灰着")
	b.disabled = false

	var fu := UiMotion.furl(b, true)
	fu.custom_step(1.0)
	t.eq(UiMotion.revealed(b), 0.0, "收旗：收到 0")
	UiMotion.furl(b, false)
	t.eq(UiMotion.revealed(b), 0.0, "收旗关着：直接收起")
	UiMotion.unroll(b, false)
	t.eq(UiMotion.revealed(b), 1.0, "开卷关着：直接全显（材质摘掉）")
	var ur := UiMotion.unroll(b, true)
	t.eq(UiMotion.revealed(b), 0.0, "开卷起点：一点没显")
	ur.custom_step(1.0)
	t.eq(UiMotion.revealed(b), 1.0, "开卷走完：全显")

	var c := Control.new()
	root.add_child(c)
	c.position = Vector2(100, 100)
	c.size = Vector2(50, 50)
	var r := UiMotion.rise(c, true, 12.0)
	t.eq([c.position, c.modulate.a], [Vector2(100, 112), 0.0], "升：从下面 12 px、透明起")
	r.custom_step(1.0)
	t.eq([c.position, c.modulate.a], [Vector2(100, 100), 1.0], "升：回原位、不透明")
	var s := UiMotion.slide(c, true, -24.0)
	t.eq(c.position, Vector2(76, 100), "滑：从左边 24 px 起（方向随正负）")
	s.custom_step(1.0)
	t.eq([c.position, c.modulate.a], [Vector2(100, 100), 1.0], "滑：回原位")
	var p := UiMotion.pop(c, true)
	t.eq([c.scale, c.modulate.a], [Vector2.ONE * 0.96, 0.0], "弹出：0.96、透明起（不弹跳）")
	p.custom_step(1.0)
	t.eq([c.scale, c.modulate.a], [Vector2.ONE, 1.0], "弹出：1、不透明")
	var f := UiMotion.fade(c, true, 1.0, 0.0)
	t.eq(c.modulate.a, 1.0, "淡：从 1 起")
	f.custom_step(1.0)
	t.eq(c.modulate.a, 0.0, "淡：到 0")
	t.is_null(UiMotion.fade(c, false, 0.0, 1.0), "淡关着：不造 Tween")
	t.eq(c.modulate.a, 1.0, "淡关着：直接终值")
	b.queue_free()
	c.queue_free()


static func frame_duel_medal(t: TestCase, root: Window) -> void:
	t.begin("231 · 双剑铜章：三层图都在；出手 → 那把剑朝对面劈一下再回；挨打 → 后仰；分胜负：赢的竖起、输的垂下变灰；分完不再动；倍速 4 不挥")
	t.check(DuelMedal.has_layers(), "盘 / 左剑 / 右剑三张图都在")
	var m := DuelMedal.new()
	root.add_child(m)
	t.eq(m.size, Vector2(132, 132), "132 见方（和战前中缝的铜章一样大）")
	m.strike(0)
	var tw: Tween = m._tweens[0]
	t.not_null(tw, "左方出手：左剑动")
	if tw != null:
		t.check(DuelMedal.WINDUP_DEG > 0.0 and DuelMedal.WINDUP_LIFT.x < 0.0 and DuelMedal.WINDUP_LIFT.y < 0.0, "作者 22:24：先往后上方提起（逆着劈的方向转、往后往上提）")
		t.check(DuelMedal.STRIKE_DEG >= 45.0 and DuelMedal.STRIKE_DEG <= 60.0 and DuelMedal.STRIKE_PUSH.x >= 12.0, "再劈下：45–60°，往对面推得更远")
		t.check(DuelMedal.WINDUP_SEC + DuelMedal.CHOP_SEC + DuelMedal.RECOVER_SEC <= 0.3, "一劈（扬起 + 劈下 + 收回）≤ 0.3 s")
		tw.custom_step(1.0)
	t.check(is_zero_approx(m.pose(0)["deg"]) and m.pose(0)["offset"] == Vector2.ZERO, "劈完回原位")
	m.strike(1)
	tw = m._tweens[1]
	t.not_null(tw, "右方出手：右剑动")
	tw.custom_step(1.0)
	m.hit(1, true)
	tw = m._tweens[1]
	tw.custom_step(DuelMedal.RECOIL_SEC * 0.2)
	t.check(m.pose(1)["deg"] > 0.0, "右剑挨打：往后仰（顺时针，背离对面）")
	t.check(m._spark >= 0.0 or m._spark_seed > 0, "大伤：迸火星")
	tw.custom_step(1.0)
	m.rate = 4.0
	var before: Tween = m._tweens[0]
	m.strike(0)
	t.check(m._tweens[0] == before and is_zero_approx(m.pose(0)["deg"]), "倍速 4：只闪不挥（左剑没新动作）")
	m.rate = 1.0
	m.spread(true)
	for s in 2:
		(m._tweens[s] as Tween).custom_step(1.0)
	t.check(m.is_spread() and is_equal_approx(m.pose(0)["deg"], -DuelMedal.GUARD_DEG) and m.pose(0)["offset"] == DuelMedal.GUARD_OFF, "作者 10-22：拉开 —— 左剑立成守姿、往外让")
	t.check(is_equal_approx(m.pose(1)["deg"], DuelMedal.GUARD_DEG) and m.pose(1)["offset"] == DuelMedal.GUARD_OFF * Vector2(-1, 1), "右剑对称")
	var ends := []
	for s in 2:
		var grip: Vector2 = DuelMedal.GRIP[s]
		var tip: Vector2 = DuelMedal.TIP[s]
		var off: Vector2 = m.pose(s)["offset"]
		var at := grip + off
		ends.append([at, at + (tip - grip).rotated(deg_to_rad(m.pose(s)["deg"]))])
	var left_x := maxf(ends[0][0].x, ends[0][1].x)
	var right_x := minf(ends[1][0].x, ends[1][1].x)
	t.check(right_x - left_x >= 16.0, "守姿里两把剑隔开（不碰）：左剑最右 %.0f、右剑最左 %.0f" % [left_x, right_x])
	m.strike(0)
	(m._tweens[0] as Tween).custom_step(1.0)
	t.check(is_equal_approx(m.pose(0)["deg"], -DuelMedal.GUARD_DEG) and m.pose(0)["offset"] == DuelMedal.GUARD_OFF, "拉开后劈完退回守姿（不回交叉）")
	t.check(DuelMedal.STRIKE_PUSH.x - DuelMedal.GUARD_OFF.x >= 36.0, "出手时冲过去的距离够长")
	t.eq(m.winner(), -2, "还没分")
	m.set_final(0, false)
	t.eq(m.winner(), 0, "左赢")
	t.check(is_equal_approx(m.pose(0)["deg"], -DuelMedal.RAISE_DEG) and m.pose(0)["grey"] == 0.0, "左剑竖起来、不灰")
	t.check(is_equal_approx(m.pose(1)["deg"], -DuelMedal.DROP_DEG) and m.pose(1)["grey"] == 1.0, "右剑垂下去、褪灰")
	m.strike(1)
	m.hit(0)
	t.check(m._tweens[0] == null and m._tweens[1] == null and is_equal_approx(m.pose(0)["deg"], -DuelMedal.RAISE_DEG), "分完了：事件不再让剑动")
	var draw := DuelMedal.new()
	root.add_child(draw)
	var tf := draw.set_final(-1, true)
	t.not_null(tf, "演：造 Tween")
	tf.custom_step(2.0)
	t.check(draw.pose(0)["grey"] == 1.0 and draw.pose(1)["grey"] == 1.0, "平局：两把都垂下、都灰")
	m.queue_free()
	draw.queue_free()


static func frame_battle_intro(t: TestCase, root: Window) -> void:
	t.begin("231 · 开战一镜到底：战前屏垫着演完才放掉；回放演完才起跑；铜章下移到继续那一格；看完分胜负，继续旗展开完才能点；跳过直接终态")
	var c := GF._content()
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是战斗点的种子")
		return
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {}     # 不放教程：只看过场
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
	GameDirector.fades_allowed = true
	flow.begin(ch, kit, int(found["seed"]), [] as Array[int], null)
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	map.step(int(found["next"]))
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备")
	if pre == null or pre.screen != GameFlow.Screen.PREBATTLE:
		_done(game)
		return
	var log_size := -1
	t.check(pre.start_battle(), "开战")
	var screen = game.overlay()
	t.check(screen != null and screen.screen == GameFlow.Screen.BATTLE, "到了回放屏")
	if screen == null or screen.screen != GameFlow.Screen.BATTLE:
		_done(game)
		return
	var result: BattleResult = flow.last_payload.get("result", null)
	log_size = result.log.size() if result != null else -1
	var pre_sz: Vector2 = pre.overlay_frame().get_combined_minimum_size()
	var bat_sz: Vector2 = screen.overlay_frame().get_combined_minimum_size()
	t.eq(bat_sz, pre_sz, "战前与战斗两块铜面板一样大（作者 10-21：尺寸统一，过场里铜框不缩放）：%s / %s" % [pre_sz, bat_sz])
	t.check(screen.intro_running(), "过场在演")
	t.check(is_instance_valid(pre) and pre.is_inside_tree(), "战前屏还垫在底下")
	t.check(pre._lane.medal_hidden, "战前中缝的铜章交出去了（不再画）")
	t.eq(UiMotion.revealed(pre._start_btn), 1.0, "开战旗：收旗刚开始（还没收）")
	var view: BattleView = screen.view()
	t.check(view.is_held() and not view.is_playing(), "过场里回放停着")
	view._process(1.0)
	t.eq(view.now(), 0.0, "过场里时间不走")
	var medal: DuelMedal = screen.medal()
	t.eq(medal.get_parent(), screen, "铜章在飞：挂在屏上，不跟面板一起透明")
	t.eq(medal.global_position, pre._lane.medal_rect().position, "起点 = 战前中缝铜章的位置")
	t.eq(screen.overlay_frame().get_parent().modulate.a, 0.0, "前 0.2 s：本屏的铜框还藏着（战前的铜框是实的，不两块一起半透明）")
	screen._swap_in(pre)
	t.check(not pre.visible and screen.overlay_frame().get_parent().modulate.a == 1.0, "0.2 s：整块换成本屏（战前屏藏掉）")
	screen._end_intro()
	t.check(not screen.intro_running() and view.is_playing(), "演完：回放开始")
	t.eq(medal.get_parent(), screen._next_slot, "铜章落在继续那一格")
	t.check(medal.is_spread(), "落地后两把剑拉开成守姿（作者 10-22）")
	t.check(pre.is_queued_for_deletion(), "垫着的战前屏放掉")
	t.eq(result.log.size() if result != null else -2, log_size, "回放日志一条没变")
	# 一条条放完：分胜负演着，继续旗等着展开
	view._process(result.duration_sec() + 1.0 if result != null else 100.0)
	t.check(screen.verdict_shown() and not view.ended_by_jump, "放完了（不是跳过）")
	var winner := -1 if result.is_draw() else result.winner
	t.eq(medal.winner(), winner, "铜章分了胜负（%d）" % winner)
	var flag: IconButton = screen._next
	t.not_null(flag, "继续旗建好了")
	if flag != null:
		t.check(flag.disabled and UiMotion.revealed(flag) == 0.0, "剑分胜负的时候：旗还卷着、点不着")
		t.eq(flag.icon_id, BattleScreenScript().continue_art(screen._won), "赢用鲜红桂冠旗、输平用褪色那面")
	_done(game)

	t.begin("231 · 跳过：铜章直接摆终态、藏起；继续旗立刻在、能点；动效关着整个过场不演（战前屏直接撤）")
	var r := BattleResult.new()
	r.winner = 1
	r.duration = 3 * StatMath.ONE
	r.log.append(BattleEvent.make(BattleEvent.BATTLE_START, 0, -1))
	r.log.append(BattleEvent.make(BattleEvent.ITEM_FIRED, int(1.0 * StatMath.ONE), 0, {"uid": 1}))
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, int(1.0 * StatMath.ONE), 1, {"amount": 5 * StatMath.ONE, "type": "physical"}))
	r.log.append(BattleEvent.make(BattleEvent.DIED, int(3.0 * StatMath.ONE), 0))
	var f := Support.flow(c, PREFIX)
	GameDirector.fades_allowed = true
	var s = BattleScreenScript().new()
	s.screen = GameFlow.Screen.BATTLE
	s.flow = f
	s.font = UiPalette.cjk_font()
	root.add_child(s)
	s.open({"result": r, "won": false})
	var v: BattleView = s.view()
	var hits := []
	v.event_applied.connect(func(e: BattleEvent): hits.append(e.name))
	v._process(1.5)
	t.eq(hits, [BattleEvent.BATTLE_START, BattleEvent.ITEM_FIRED, BattleEvent.DAMAGE], "一条条放：每条都发给铜章")
	t.not_null(s.medal()._tweens[1], "挨打的右剑在动")
	v.skip_to_end()
	t.eq(hits.size(), 3, "跳过补的那些不发")
	t.check(v.ended_by_jump, "这次是跳过来的")
	t.eq(s.medal().winner(), 1, "铜章直接摆终态（右赢）")
	t.check(not s.medal().visible, "铜章藏起，让位给继续旗")
	t.check(s._next != null and not s._next.disabled and UiMotion.revealed(s._next) == 1.0, "继续旗立刻在、能点")
	s.queue_free()
	GameDirector.fades_allowed = false
	Support.cleanup(PREFIX)


static func BattleScreenScript() -> GDScript:
	return load("res://ui/game/battle_screen.gd")


static func _done(game: Node) -> void:
	GameDirector.fades_allowed = false
	game.flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)

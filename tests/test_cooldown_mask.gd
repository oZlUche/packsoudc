## 103 第 7 条：冷却旋转遮罩 —— 进度是时刻的纯函数；日志带 ready_at；回放画双方棋盘、遮罩跟倍速与跳转。
extends RefCounted

const FX := preload("res://tests/test_effect_system.gd")


static func run_clock(t: TestCase) -> void:
	t.begin("103 · 冷却进度：刚出手 0、就绪 1、中间线性；扇形从 12 点顺时针转没")
	t.eq(CooldownClock.progress(2.0, 4.0, 2.0), 0.0, "刚出手：0")
	t.eq(CooldownClock.progress(2.0, 4.0, 3.0), 0.5, "走一半：0.5")
	t.eq(CooldownClock.progress(2.0, 4.0, 9.0), 1.0, "就绪之后钳在 1")
	t.eq(CooldownClock.progress(2.0, 4.0, 1.0), 0.0, "回退到出手之前钳在 0（跳转回去不会出负数）")
	t.eq(CooldownClock.progress(2.0, 2.0, 2.0), 1.0, "零冷却：直接就绪")
	var prev := -1.0
	var mono := true
	for i in 21:
		var p := CooldownClock.progress(0.0, 2.0, i * 0.1)
		mono = mono and p >= prev
		prev = p
	t.check(mono, "单调不减")
	t.eq(CooldownClock.sector(Vector2.ZERO, 10.0, 1.0).size(), 0, "就绪：没有遮罩")
	var full := CooldownClock.sector(Vector2.ZERO, 10.0, 0.0)
	t.check(full.size() > 3 and full[1].is_equal_approx(full[full.size() - 1]), "刚出手：整圈")
	var half := CooldownClock.sector(Vector2.ZERO, 10.0, 0.5)
	t.check(half[1].is_equal_approx(Vector2(0, 10)) and half[half.size() - 1].is_equal_approx(Vector2(0, -10)), "走一半：遮住的是左半边（6 点顺时针到 12 点）")


static func _weapon(cd: float, stamina: float) -> CombatantSpec:
	var cost := ResourceCost.new()
	cost.amount = stamina
	var s := FX._spec(100.0, [FX._compiled(7, "w", {"damage": 1.0}, [FX._rule(OnSchedule.new(), FX._cooldown(cd), [FX._damage()], [cost])])])
	s.baseline = StatSet.new()
	s.baseline.set_base(BattleStats.MAX_STAMINA, StatMath.from_float(10.0))
	return s


static func run_log(t: TestCase) -> void:
	t.begin("103 · 日志：item_fired 带下一次就绪时刻；耐力不够跳过也发 item_skipped；开战带每件道具的首个就绪时刻")
	var r := BattleSim.run(_weapon(1.5, 6.0), FX._spec(1000.0, []), RandomNumberGenerator.new(), 10.0)
	var fired: Array = []
	var skipped: Array = []
	for e in r.log:
		if e.side != 0:
			continue
		if e.name == BattleEvent.ITEM_FIRED:
			fired.append(e)
		elif e.name == BattleEvent.ITEM_SKIPPED:
			skipped.append(e)
	t.check(not fired.is_empty(), "有出手")
	t.eq((fired[0] as BattleEvent).get_int(&"ready_at") - (fired[0] as BattleEvent).time, StatMath.from_float(1.5), "ready_at = 出手时刻 + 冷却")
	t.check(not skipped.is_empty(), "耐力 10、每下 6、不回耐力：第二下起跳过")
	t.eq((skipped[0] as BattleEvent).get_int(&"ready_at") - (skipped[0] as BattleEvent).time, StatMath.from_float(1.5), "跳过的那次也开了新一轮")
	var cds: Array = r.initial.get("cooldowns", [])
	t.eq(int((cds[0] as Dictionary).get(7, -1)), StatMath.from_float(1.5), "开战：uid 7 第一次 1.5 秒就绪")


static func run_view(t: TestCase) -> void:
	t.begin("103 · 回放：画双方棋盘，遮罩按回放时刻转（倍速、跳转都对）；多条冷却只跟最长的那条")
	var board := GridInventory.new(Vector2i(4, 3))
	var spec := _weapon(2.0, 1.0)
	var view := BattleView.new()
	view.label_font = UiPalette.cjk_font()
	view._ready()
	var r := BattleSim.run(spec, FX._spec(1000.0, []), RandomNumberGenerator.new(), 10.0)
	view.set_board(0, board)
	view.play(r, ["我", "敌"])
	t.check(view.board_view(0).inventory == board and view._board_slots[0].visible, "我方棋盘画出来了")
	t.check(not view._board_slots[1].visible, "没给棋盘的一方不画")
	var o := view.overlay(0)
	t.eq(o.progress_of(7), 0.0, "开战：第一轮刚开始")
	view.seek(1.0)
	t.eq(o.progress_of(7), 0.5, "跳到 1 秒：走了一半（冷却 2 秒）")
	view.seek(3.0)
	t.eq(o.progress_of(7), 0.5, "跳到 3 秒：第二轮（2～4 秒）走了一半")
	view.seek(0.5)
	t.eq(o.progress_of(7), 0.25, "往回跳：照样对（进度是时刻的纯函数）")
	view.seek(0.0)
	view.toggle_play()
	view._speed_idx = 2     # 4×
	view._process(0.25)
	t.eq(o.progress_of(7), 0.5, "4 倍速播 0.25 秒真实时间 = 回放 1 秒：一半")
	view.free()

	var o2 := CooldownOverlay.new()
	o2.reset({3: 4.0})
	o2.note_cycle(3, 1.0, 2.0)
	t.eq(o2.cycles[3], [0.0, 4.0, 4.0], "长周期没走完时，短周期的那条不覆盖")
	o2.now = 4.0
	o2.note_cycle(3, 4.0, 8.0)
	t.eq(o2.cycles[3], [4.0, 8.0, 4.0], "新一轮照常接上")
	o2.now = 0.0    # seek 时事件先于 now 同步
	o2.note_cycle(3, 8.0, 10.0)
	t.eq(o2.cycles[3], [8.0, 10.0, 2.0], "加速后周期变短：上一轮已走完就接上，不看 now")
	o2.free()

## UI替换美术 10-24：开局第 2 页「带入现金」换皮 —— 钉着的便条（浅纸墨字）、顶行「带入现金 / 仓库 N」、
## 步进件一步 10（读数只写带多少）、三枚石签「不带 / 一半 / 全部」一样宽；做了不会变的那颗压灰
extends RefCounted

const CS := preload("res://tests/run/test_character_setup.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _state(setup) -> Array:
	var chips: Array = setup._cash_chips
	return [setup._cash_step.minus.disabled, setup._cash_step.plus.disabled, chips[0].disabled, chips[1].disabled, chips[2].disabled]


static func frame_cash_note(t: TestCase, root: Window) -> void:
	t.begin("UI替换美术 10-24 · 带入现金：便条、步进件、三枚石签；压灰跟着带多少")
	Support.cleanup("char")
	var game = load(CS.GAME).instantiate()
	game.save_path = CS.SAVE
	game.meta_path = CS.META
	root.add_child(game)
	var flow: GameFlow = game.flow
	if flow.characters.is_empty() or flow.chapters.is_empty():
		t.check(false, "没有角色或章节")
		game.queue_free()
		return
	flow.meta.funds = 95
	for gch in flow.chapters:     # 序章不走开局屏：先给上章节许诺的解锁，再挑第一章（同 test_character_setup）
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	var note: PanelContainer = setup.find_child("CashNote", true, false)
	t.not_null(note, "钉着一张便条")
	if note == null:
		game.queue_free()
		Support.cleanup("char")
		return
	t.eq(note.size_flags_horizontal, Control.SIZE_SHRINK_END, "255 补充二：钉在仓库框底部靠右，不拉满整栏")
	t.check(note.get_parent() != null and note.get_parent().get_parent() == setup._warehouse_box, "便条在仓库木框里")
	t.check(setup._cash_step is StoneStepper and setup._cash_chips.size() == 3, "一个步进件、三枚石签")
	t.check(note.find_children("*", "Button", true, false).all(func(b: Button) -> bool: return b.text != "−10" and b.text != "+10"), "没有「−10」「+10」两颗旧键")
	var w0: float = setup._cash_chips[0].custom_minimum_size.x
	t.check(w0 > 0.0 and setup._cash_chips.all(func(c: Button) -> bool: return is_equal_approx(c.custom_minimum_size.x, w0)), "三枚一样宽")

	setup.set_carry_funds(0)
	t.eq(setup._cash_store.text, "仓库 95", "右上写仓库余额")
	t.eq(setup._cash_step.plate.text, "0", "读数只写带多少")
	t.eq(_state(setup), [true, false, true, false, false], "带 0：−、「不带」压灰")
	setup._cash_step.plus.pressed.emit()
	t.eq(setup.carry_funds, 10, "+ 一步 10")
	t.eq(_state(setup), [false, false, false, false, false], "带 10：都能按")
	setup._cash_chips[1].pressed.emit()
	t.eq(setup.carry_funds, 47, "「一半」= 仓库的一半（向下取整）")
	t.eq(_state(setup), [false, false, false, true, false], "正好一半：「一半」压灰")
	setup._cash_chips[2].pressed.emit()
	t.eq(setup.carry_funds, 95, "「全部」")
	t.eq(_state(setup), [false, true, false, false, true], "带满：+、「全部」压灰")
	flow.meta.funds = 0
	setup._refresh_cash()
	t.eq(setup.carry_funds, 0, "仓库没钱了：带的跟着收到 0")
	t.eq(_state(setup), [true, true, true, true, true], "仓库 0：全部压灰（便条照样在）")
	t.check(note.is_inside_tree(), "便条还在")
	game.queue_free()
	Support.cleanup("char")

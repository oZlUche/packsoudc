## UI替换美术 10-24：开局第 2 页「带入现金」换皮 —— 钉着的便条（浅纸墨字）、顶行「带入现金 / 仓库 N」、
## 三枚石签「不带 / 一半 / 全部」一样宽；做了不会变的那颗压灰。作者 10-27：±10 步进件换成拖条（按比例）+ 能键盘输入的数字框
extends RefCounted

const CS := preload("res://tests/run/test_character_setup.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _state(setup) -> Array:
	var chips: Array = setup._cash_chips
	return [chips[0].disabled, chips[1].disabled, chips[2].disabled]


static func frame_cash_note(t: TestCase, root: Window) -> void:
	t.begin("UI替换美术 10-24 · 带入现金：便条、拖条 + 输入框（作者 10-27）、三枚石签；压灰跟着带多少")
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
	t.check(note.get_parent() != null and setup._warehouse_box.is_ancestor_of(note), "便条在仓库那一栏里（整理键右边）")
	t.check(setup._cash_slider is StoneSlider and setup._cash_field is StoneField and setup._cash_chips.size() == 3, "一条拖条、一个输入框、三枚石签")
	t.is_null(note.find_children("*", "StoneStepper", true, false).front() if not note.find_children("*", "StoneStepper", true, false).is_empty() else null, "没有 ±10 步进件了")
	t.check(note.find_children("*", "Button", true, false).all(func(b: Button) -> bool: return b.text != "−10" and b.text != "+10"), "没有「−10」「+10」两颗旧键")
	var w0: float = setup._cash_chips[0].custom_minimum_size.x
	t.check(w0 > 0.0 and setup._cash_chips.all(func(c: Button) -> bool: return is_equal_approx(c.custom_minimum_size.x, w0)), "三枚一样宽")

	setup.set_carry_funds(0)
	t.eq(setup._cash_store.text, "仓库 95", "右上写仓库余额")
	t.eq(setup._cash_field.text, "0", "输入框写带多少")
	t.eq(_state(setup), [true, false, false], "带 0：「不带」压灰")
	# 拖条：按比例
	var sl: StoneSlider = setup._cash_slider
	t.eq(sl.max_value, 95.0, "拖条到头 = 仓库余额")
	sl.value = sl.value_at(sl._track().y)
	t.eq(setup.carry_funds, 95, "拖到最右 = 全部")
	t.eq(setup._cash_field.text, "95", "输入框跟着变")
	sl.value = sl.value_at(lerpf(sl._track().x, sl._track().y, 0.2))
	t.eq(setup.carry_funds, 19, "拖到两成 = 19")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(sl._track().x, sl.size.y * 0.5)
	sl._gui_input(press)
	t.eq(setup.carry_funds, 0, "按在最左 = 不带")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	sl._gui_input(up)
	# 键盘输入
	setup._cash_field.text = "3a0"
	setup._cash_field.text_changed.emit("3a0")
	t.eq(setup.carry_funds, 30, "只认数字：3a0 → 30")
	t.eq(setup._cash_field.text, "30", "非数字的字去掉")
	t.eq(sl.value, 30.0, "拖条跟着走")
	setup._cash_field.text = "500"
	setup._cash_field.text_changed.emit("500")
	t.eq(setup.carry_funds, 95, "超过仓库余额收到余额")
	t.eq(setup._cash_field.text, "95", "框里也改成余额")
	setup._cash_field.text = ""
	setup._cash_field.text_changed.emit("")
	t.eq(setup.carry_funds, 0, "删空 = 0")
	setup._cash_chips[1].pressed.emit()
	t.eq(setup.carry_funds, 47, "「一半」= 仓库的一半（向下取整）")
	t.eq(_state(setup), [false, true, false], "正好一半：「一半」压灰")
	setup._cash_chips[2].pressed.emit()
	t.eq(setup.carry_funds, 95, "「全部」")
	t.eq(_state(setup), [false, false, true], "带满：「全部」压灰")
	flow.meta.funds = 0
	setup._refresh_cash()
	t.eq(setup.carry_funds, 0, "仓库没钱了：带的跟着收到 0")
	t.eq(_state(setup), [true, true, true], "仓库 0：石签全部压灰（便条照样在）")
	t.check(not sl.enabled and not setup._cash_field.editable, "仓库 0：拖条和输入框都关着")
	t.eq(setup._cash_field.text, "0", "仓库 0：框里写 0")
	t.eq(sl._grab_x(), sl._track().x, "仓库 0：把手在最左")
	t.check(note.is_inside_tree(), "便条还在")
	game.queue_free()
	Support.cleanup("char")

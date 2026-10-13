## 160（作者定）：腰带离开背包，只在右下角，格子画成圆；圆里一种随身技能、右下角写几个；双击用，用不了在圆上方飘字
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func run_layout(t: TestCase) -> void:
	t.begin("160 · 默认布局：腰带锚在右下角，不在右上那一列；布局版本升了（旧的回默认）")
	var l := HudLayout.default_for("map")
	var found := {}
	for e in l.entries:
		if e["id"] == &"belt":
			found = e
	t.eq(found.get("anchor", ""), "bottom_right", "腰带在右下角")
	t.eq(found.get("offset", Vector2.ZERO), HudLayout.BELT_OFFSET, "偏移 %s" % HudLayout.BELT_OFFSET)
	t.check(not HudLayout.BAR_RIGHT.has(&"belt"), "顶端栏右槽里没有腰带（166）")
	t.eq(BeltSlots.SLOT, 72.0, "166：圆槽直径 72（更显眼）")
	t.check(HudLayout.VERSION >= 3, "布局版本 %d" % HudLayout.VERSION)


static func frame_slots(t: TestCase, root: Window) -> void:
	t.begin("160 · 圆槽：几格几个圆、按圆心距命中；放进去画在第 i 个圆、写数量；双击用一个；用不了飘字；背包里没有腰带")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var belt := BeltModule.of(s)
	var slots := BeltSlots.new()
	root.add_child(slots)
	slots.bind(belt)
	var n := belt.slot_count()
	t.eq(slots.custom_minimum_size, Vector2(n * BeltSlots.SLOT + (n - 1) * BeltSlots.GAP, BeltSlots.SLOT), "%d 个圆排一行" % n)
	for i in n:
		t.eq(slots.slot_at(slots.slot_center(i)), i, "第 %d 个圆心命中第 %d 格" % [i, i])
	t.eq(slots.slot_at(Vector2(BeltSlots.SLOT + BeltSlots.GAP * 0.5, BeltSlots.SLOT * 0.5)), -1, "两个圆之间的空：不命中")
	t.eq(slots.slot_at(Vector2(2, 2)), -1, "外接方块的角（圆外）：不命中")
	belt.add(&"aid_pack", 2)
	belt.add(&"smoke_bomb", 1)
	t.eq(slots.skill_at(0), &"aid_pack", "第一格是急救包")
	t.eq(slots.skill_at(1), &"smoke_bomb", "第二格是烟雾弹")
	t.eq(slots.skill_at(2), &"", "第三格空")
	t.check(slots._get_tooltip(slots.slot_center(0)).contains("急救包 ×2"), "悬停写名字与个数")
	s.vitality.current = s.vitality.maximum - 1
	t.eq(slots.use_slot(0), "", "用一个急救包")
	t.eq(belt.count_of(&"aid_pack"), 1, "剩一个")
	t.check(slots.use_slot(1) != "", "地图上用不了烟雾弹")
	t.check(slots.flashed().contains("烟雾弹"), "圆上方飘字：%s" % slots.flashed())
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.double_click = true
	mb.position = slots.slot_center(0)
	s.vitality.current = s.vitality.maximum - 1
	slots._gui_input(mb)
	t.eq(belt.count_of(&"aid_pack"), 0, "双击用掉最后一个")
	t.eq(slots.skill_at(0), &"smoke_bomb", "空出来的那格让给后面的")
	slots.queue_free()

	var panel: Control = (load("res://ui/game/inventory_panel.gd") as GDScript).new()
	root.add_child(panel)
	panel.setup(s, UiPalette.cjk_font())
	t.check(not ("belt_view" in panel), "背包里没有腰带")
	panel.queue_free()

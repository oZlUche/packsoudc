## 232（作者 19:23 选 2、6）：背包窗换成一只背包（385 又换成浅石框），腰带 1–6 格换弯皮带（圆心读表，超过 6 格退回直圆槽）
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func frame_satchel(t: TestCase, root: Window) -> void:
	t.begin("385 · 背包窗换石刻：一整块浅石框跟窗一样大、在画布底下；标题行是拖动把手；不凸出窗外；名牌深石板、页签石页签、收起键浅石小格")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var host := Control.new()
	host.size = Vector2(1600, 1000)
	root.add_child(host)
	var win := BagWindow.new()
	host.add_child(win)
	win.setup_bag(run, UiPalette.cjk_font(), func(): pass)
	var w := win.window_size()
	var stone := win.get_node_or_null("Stone") as NinePatchRect
	t.check(stone != null and stone.texture != null, "换上了浅石框")
	if stone != null:
		t.eq(Rect2(stone.position, stone.size), Rect2(Vector2.ZERO, w), "石框跟窗一样大")
		t.check(stone.get_index() < win._canvas.get_index(), "石框在画布底下")
	t.eq(UiTheme.tone_at(win.card), UiTheme.TONE_DARK, "角色卡是深底（白字）")
	t.eq(UiTheme.tone_at(win), UiTheme.TONE_LIGHT, "窗里是浅底（墨字）")
	t.eq(Rect2(win._header.position, win._header.size), Rect2(0, 0, w.x, 52), "拖动把手 = 窗顶标题行")
	t.eq(win.outset, Rect2(), "不凸出窗外")
	var plate_box := win.nameplate.get_theme_stylebox("panel") as StyleBoxTexture
	t.check(plate_box != null and plate_box.texture == UiTheme.art_cached(UiTheme.ART_STONE_SLATE), "名牌底是深石板")
	var tab := win.views.get_child(0) as StoneChip
	t.check(tab != null and (tab.get_theme_stylebox("normal") as StyleBoxTexture).texture == UiTheme.art_cached(UiTheme.ART_STONE_TAB)
		and (tab.get_theme_stylebox("pressed") as StyleBoxTexture).texture == UiTheme.art_cached(UiTheme.ART_STONE_TAB_ON), "页签：浅石 / 选中深石板")
	t.check((win.close_button.get_theme_stylebox("normal") as StyleBoxTexture).texture == UiTheme.art_cached(UiTheme.ART_HUD_WELL), "收起键是浅石小格")
	win.move_to(Vector2(-500, -500))
	t.eq(win.position, Vector2.ZERO, "往左上拖出屏：贴屏边")
	host.free()


static func frame_curved_belt(t: TestCase, root: Window) -> void:
	t.begin("232 · 腰带：1–6 格一整张弯皮带，圆心 = 表里的、半径 36 命中；7 格退回一排直圆槽")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	var belt := BeltModule.of(run) if run != null else null
	if belt == null:
		t.check(false, "这一局有腰带")
		return
	var slots := BeltSlots.new()
	root.add_child(slots)
	slots.bind(belt)
	for n in range(1, 7):
		belt.slots = n
		belt.changed.emit()
		var lay: Dictionary = BeltSlots.belt_layouts().get(str(n), {})
		t.check(slots.curved(), "%d 格：弯皮带" % n)
		t.eq(slots.custom_minimum_size, Vector2(lay["size"][0], lay["size"][1]), "%d 格：大小是图的" % n)
		for i in n:
			var want := Vector2(float(lay["centers"][i][0]), float(lay["centers"][i][1]))
			t.eq(slots.slot_center(i), want, "%d 格第 %d 个圆心" % [n, i])
			t.eq(slots.slot_at(want + Vector2(35, 0)), i, "%d 格第 %d 个：半径 36 内命中" % [n, i])
	belt.slots = 7
	belt.changed.emit()
	t.check(not slots.curved(), "7 格：退回直圆槽")
	t.eq(slots.slot_center(6), Vector2(BeltSlots.SLOT * 0.5 + 6 * (BeltSlots.SLOT + BeltSlots.GAP), BeltSlots.SLOT * 0.5), "7 格一排直的")
	slots.free()

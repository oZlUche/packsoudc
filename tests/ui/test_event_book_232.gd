## 232（作者 19:23 选 1）：事件窗是一本摊开的书 —— 整张图从面板左上往外 (40, 34)；插图在左页 image_rect，右页 text_rect 一列：标题 → 正文 → 选项
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "event_book_232"


static func frame_book(t: TestCase, root: Window) -> void:
	t.begin("232 · 事件窗书皮：图摆位、插图在左页、标题与选项在右页、浅底")
	var c := NodeScreens._content()
	var kit := NodeScreens._kit(c)
	var found := NodeScreens._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是搜索点的种子")
		return
	var f := Support.flow(c, PREFIX)
	f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	t.check(f.step_to(int(found["next"])), "走上搜索点")
	var screen = load("res://ui/game/event_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.EVENT
	root.add_child(screen)
	screen.open(f.last_payload)
	var frame: OverlayFrame = screen.overlay_frame()
	t.check(frame != null and frame.book, "书皮")
	var meta := OverlayFrame.book_meta()
	t.eq(frame.book_back.position, -Vector2(40, 34), "图左上 = 面板左上往外 (40, 34)")
	t.eq(frame.book_back.size, Vector2(1400, 874), "整张图原大")
	t.eq(UiTheme.tone_at(frame), UiTheme.TONE_LIGHT, "浅底")
	var image := frame.find_child("Image", true, false) as Control
	var page := frame.find_child("Page", true, false) as Control
	var ir: Array = meta["image_rect"]
	var tr_: Array = meta["text_rect"]
	t.check(page != null, "有一列正文")
	if image != null and page != null:     # 有插图：插图左页、右页一列
		t.eq(Rect2(image.position, image.size), Rect2(ir[0], ir[1], ir[2], ir[3]), "插图在 image_rect")
		t.eq(page.position, Vector2(tr_[0], tr_[1]), "右页在 text_rect")
		t.check(frame.title_label.get_parent() == page and page.get_child(0) == frame.title_label, "标题在右页最上面")
		var options := page.find_child("Options", false, false)
		t.check(options != null and options.get_child_count() > 0, "选项在右页")
	elif page != null:     # 局内界面布局方案 §9.3：没插图 —— 正文在左页、选项在右页
		t.check(screen.compact(), "没插图：紧凑版式")
		t.eq(page.position, Vector2(ir[0], ir[1]), "标题和正文在左页（image_rect）")
		t.check(frame.title_label.get_parent() == page and page.get_child(0) == frame.title_label, "标题在左页最上面")
		var options := frame.find_child("Options", true, false) as Control
		t.check(options != null and options.get_child_count() > 0 and options.get_parent() != page, "选项单独一列")
		if options != null:
			t.eq(options.position.x, float(tr_[0]), "选项在右页")
	t.check(frame.title() != "", "有标题")
	screen.free()
	Support.cleanup(PREFIX)

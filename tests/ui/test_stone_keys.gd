## 乙 石刻（UI替换美术 kit，作者 18:27 选定）的纸卷键：主键 = `kit/key_primary_*`（左头蜡封，字在 [16, 宽] 里居中）、
## 矮键 = 商店纸卷压到 44 高；主键可带一行小字（神坛「献祭」的预览）。读档屏：读取 / 在此开新档主键、删除矮键、返回普通键
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "stone_keys"


static func frame_primary_short_keys(t: TestCase, root: Window) -> void:
	t.begin("乙 石刻：主键用蜡封纸卷（九宫格左 36、字让开 16）、矮键 44 高字 18、带小字的主键 64 高")
	var p := ScrollKey.primary("献祭", func(): pass) as ScrollKey
	root.add_child(p)
	t.check(p != null and p.art and p.primary_key, "主键是纸卷键")
	var box := p.get_theme_stylebox("normal") as StyleBoxTexture
	t.check(box != null and box.texture == UiTheme.art_cached("kit/key_primary_normal"), "主键用 kit/key_primary")
	if box != null:
		t.eq(box.texture_margin_left, 36.0, "左头蜡封 36 不拉")
		t.eq(box.content_margin_left - box.content_margin_right, 16.0, "字在 [16, 宽] 里居中")
	t.eq(p.get_combined_minimum_size().y, 56.0, "主键高 56")
	t.check(p.get_combined_minimum_size().x >= 132.0, "主键最窄 132")
	var s := ScrollKey.short("回地图", func(): pass) as ScrollKey
	root.add_child(s)
	t.check(s != null and not s.primary_key, "矮键是普通纸卷")
	t.eq(s.get_combined_minimum_size().y, ScrollKey.SHORT_H, "矮键 44 高")
	t.eq(s.get_theme_font_size("font_size"), UiTheme.sz(ScrollKey.SHORT_FONT), "矮键字 18（258：按字号档）")
	var two := ScrollKey.primary("献祭", func(): pass, true) as ScrollKey
	root.add_child(two)
	t.eq(two.get_combined_minimum_size().y, ScrollKey.SUB_H, "带小字的主键 64 高")
	ScrollKey.show_sub(two, "献祭", "3 件 · 信力 +12（Lv.1 → Lv.2）")
	t.eq([two.text, two.sub], ["献祭", "3 件 · 信力 +12（Lv.1 → Lv.2）"], "大字、小字分开")
	t.eq((two.get_theme_stylebox("normal") as StyleBoxTexture).content_margin_bottom, ScrollKey.SUB_LIFT, "有小字：大字往上让")
	var w := UiPalette.cjk_font().get_string_size(two.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ScrollKey.SUB_FONT).x
	t.check(two.get_combined_minimum_size().x >= w + 42.0 + 26.0, "宽容得下小字")
	ScrollKey.show_sub(two, "献祭", "")
	t.eq((two.get_theme_stylebox("normal") as StyleBoxTexture).content_margin_bottom, 0.0, "没小字：大字居中")
	var flat := Button.new()
	ScrollKey.show_sub(flat, "献祭", "用过了")
	t.eq(flat.text, "献祭\n用过了", "平板按钮：小字接成第二行")
	flat.free()
	for b in [p, s, two]:
		b.free()


static func frame_slots_keys(t: TestCase, root: Window) -> void:
	t.begin("乙 石刻：读档屏 —— 在此开新档 / 读取是主键，删除是矮键，返回是普通纸卷")
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX)
	f.settings = GameSettings.new()
	var slots = load("res://ui/game/slots_screen.gd").new()
	slots.flow = f
	slots.font = UiPalette.cjk_font()
	root.add_child(slots)
	slots.open({})
	var by_text := {}
	for k in slots.find_children("*", "Button", true, false):
		if k is ScrollKey:
			by_text[k.text] = k
	t.check(by_text.has(UiText.t("slots.new_here")) and (by_text[UiText.t("slots.new_here")] as ScrollKey).primary_key, "在此开新档 = 主键")
	t.check(by_text.has(UiText.t("slots.back")) and not (by_text[UiText.t("slots.back")] as ScrollKey).primary_key, "返回 = 普通纸卷")
	var plain: Array = slots.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return not b is ScrollKey and b.visible)
	t.eq(plain.size(), 0, "读档屏没有平板按钮了")
	slots.free()
	Support.cleanup(PREFIX)

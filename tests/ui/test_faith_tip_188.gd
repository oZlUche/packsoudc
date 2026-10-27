## 188（作者 2026-10-17 17:29）：「前四张截图的文本都删掉。信仰说明的悬浮窗需要重新排版和设计字体颜色」。
## 背包面板不再写操作提示、地上说明、参战 / 可用格读数、信仰行；信仰窗 = 名字行（Lv）+ 信力行 + 进度条 / 各阶效果 / 信力来源 / 献祭，颜色全走模板
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _power(id: StringName, points: int) -> FaithPower:
	var p := FaithPower.new()
	p.points[String(id)] = points
	return p


static func run_faith_layout(t: TestCase) -> void:
	t.begin("188 · 信仰窗：蛮神 45 点 = Lv.1、45 / 100、分段进度条拿到阈值与信力（补充一）；没到的阶整行灰；不写括号注 / 背景 / 阈值 / 道具清单 / 机制说明")
	var defs := FaithDef.load_all()
	var brute: FaithDef = defs.get(&"brute", null)
	t.not_null(brute, "蛮神")
	if brute == null:
		return
	var full := FaithTooltip.describe_full(brute, _power(&"brute", 45))
	var head := Glossary.strip_bbcode(String(full["head"]))
	t.check(head.contains("蛮神") and head.contains("Lv.1") and head.contains("45 / 100"), "名字行与信力行（%s）" % head)
	var text := Glossary.strip_bbcode(String(full["text"]))
	for word in ["阈值", "暴力与杀戮", "帝国", "这个信仰的道具", "休眠，只保留", "右键信物", "信力怎么涨"]:
		t.check(not text.contains(word), "不写「%s」" % word)
	t.check(full["bar"]["thresholds"] == [30, 100, 200, 400] and int(full["bar"]["points"]) == 45, "进度条：各级阈值与现在的信力（%s）" % str(full["bar"]))
	var sections: Array = full["sections"]
	t.check(sections.size() == 3, "三段：各阶效果、信力来源、献祭（%d）" % sections.size())
	var perks := String(sections[0])
	var lv2_dim := RegEx.create_from_string("\\[color=@dim\\]\\[font_size=\\d+\\]Lv\\.2").search(perks) != null
	var lv1_dim := RegEx.create_from_string("\\[color=@dim\\]\\[font_size=\\d+\\]Lv\\.1").search(perks) != null
	t.check(lv2_dim and not lv1_dim, "Lv.2 整行暗、Lv.1 亮")
	t.check(Glossary.strip_bbcode(String(sections[1])).begins_with("信力来源"), "第二段信力来源")
	t.check(Glossary.strip_bbcode(String(sections[2])).begins_with("献祭"), "第三段献祭")
	t.check(String(full["head"]).contains("[color=@faith]") and String(full["head"]).contains("[color=@faith]45[/color]") and String(full["head"]).contains("[color=@faith]Lv.1[/color]"), "神名、信力数与 Lv 都是信仰色（257）")
	var hex := RegEx.create_from_string("\\[color=#")
	var leaks: Array[String] = []
	for id in defs:
		var f := FaithTooltip.describe_full(defs[id], _power(id, 100000))
		if hex.search(String(f["text"])) != null:
			leaks.append(String(id))
		if (f["bar"]["thresholds"] as Array) != (defs[id] as FaithDef).thresholds:
			leaks.append("%s 进度条的阈值不对" % id)
	t.check(leaks.is_empty(), "没有写死的十六进制色、满阶也给进度条（补充一）：%s" % "，".join(leaks))
	var hunt: FaithDef = defs.get(&"hunt", null)
	if hunt != null and hunt.perks.is_empty():
		t.check(Glossary.strip_bbcode(String(FaithTooltip.describe_full(hunt)["sections"][0])).begins_with("信力来源"), "没有阶效果的狩猎之神：第一段就是信力来源")
	t.check(FaithTooltip.describe_full(null).is_empty(), "没有信仰：不开窗")


static func frame_faith_window(t: TestCase, root: Window) -> void:
	t.begin("188 · 信仰窗：名字行下挂分段进度条（补充一：一段一级、长度按所需信力，满阶也挂）、宽 360、各段之间虚线；换别的窗进度条摘掉")
	var brute: FaithDef = FaithDef.load_all().get(&"brute", null)
	if brute == null:
		t.check(false, "蛮神")
		return
	var tip := HoverTip.new()
	root.add_child(tip)
	tip.show_faith(FaithTooltip.describe_full(brute, _power(&"brute", 45)), Vector2(100, 100))
	var bar = tip.faith_bar()
	t.not_null(bar, "挂了进度条")
	if bar != null:
		var segs: Array[Vector2] = bar.segments(HoverTip.MAX_WIDTH)
		t.eq(segs.size(), 4, "四段")
		if segs.size() == 4:
			var unit := segs[0].y / 30.0
			var ok := absf(segs[1].y - 70.0 * unit) <= 1.0 and absf(segs[2].y - 100.0 * unit) <= 1.0 and absf(segs[3].y - 200.0 * unit) <= 1.0
			t.check(ok, "四段宽度 30:70:100:200（容差 1 px）：%s" % str(segs))
			t.check(segs[1].x > segs[0].x + segs[0].y, "段与段之间有缝")
		t.check(absf(float(bar.fill_of(0)) - 1.0) < 0.001 and absf(float(bar.fill_of(1)) - 15.0 / 70.0) < 0.001 and float(bar.fill_of(2)) == 0.0, "45 点：第一段满、第二段 15/70、后面空")
		t.check(bar.get_index() == tip._panel.head.get_index() + 1, "在名字行下面")
	t.eq(tip._faith_parts.size(), 1 + 2 * 2, "进度条 + 两段（各一条虚线）")
	tip._refit()
	t.eq(tip._panel.body.custom_minimum_size.x, HoverTip.scaled(HoverTip.MAX_WIDTH), "宽 360（258：随字号档），不按内容收窄")
	tip.show_faith(FaithTooltip.describe_full(brute, _power(&"brute", 999)), Vector2(100, 100))
	var full_bar = tip.faith_bar()
	t.check(full_bar != null and float(full_bar.fill_of(3)) == 1.0, "满阶：还挂着、全满")
	tip.show_text("别的", Vector2(100, 100))
	t.check(tip._faith_parts.is_empty() and tip._panel.body.visible, "换别的窗：信仰窗的件都摘了")
	tip.show_faith({}, Vector2(100, 100))
	t.eq(tip.text(), "别的", "没有信仰：不开")
	tip.queue_free()


static func frame_panel_texts(t: TestCase, root: Window) -> void:
	t.begin("188 · 背包面板：找不到操作提示、地上说明、参战 / 可用格读数、停上去看、信仰行；顶出来的回话交给宿主")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var panel: Control = (load("res://ui/game/inventory_panel.gd") as GDScript).new()
	var heard: Array[String] = []
	panel.hint_sink = func(text: String): heard.append(text)
	root.add_child(panel)
	panel.setup(s, UiPalette.cjk_font())
	var texts: Array[String] = []
	for n in panel.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	var joined := "\n".join(texts)
	for word in ["左键拖动", "地上（不限件数）", "参战", "可用格", "停上去看效果", "信仰：", "作战棋盘"]:
		t.check(not joined.contains(word), "没有「%s」" % word)
	panel._on_displaced([], false)
	t.eq(heard.size(), 1, "顶出来的话交给宿主")
	panel.queue_free()

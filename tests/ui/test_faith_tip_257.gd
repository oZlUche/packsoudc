## 257（作者 2026-10-27 11:08 挑甲）：信仰窗四段分立 —— 神赐 / 赐福之物 / 信力来源两列 / 献祭图标下写倍率；
## 信力的数信力色、加成的数数值色、条件里的数不上色；赐福道具窗的加成成了带神名虚线的小节，信物降成脚注
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _power(id: StringName, points: int) -> FaithPower:
	var p := FaithPower.new()
	p.points[String(id)] = points
	return p


static func run_four_sections(t: TestCase) -> void:
	t.begin("257 · 蛮神窗四段：神赐（不含道具名）/ 赐福之物（护符、赐福的道具）/ 信力来源（每行信力色）/ 献祭")
	var c := CS._content()
	var brute: FaithDef = FaithDef.load_all().get(&"brute", null)
	t.not_null(brute, "蛮神")
	if brute == null:
		return
	var full := FaithTooltip.describe_full(brute, _power(&"brute", 45), null, c.items)
	var sections: Array = full["sections"]
	t.eq(sections.size(), 4, "四段")
	if sections.size() != 4:
		return
	var perks := Glossary.strip_bbcode(String(sections[0]))
	t.check(perks.begins_with("神赐"), "第一段神赐")
	t.check(not perks.contains("蛮神的护符") and not perks.contains(FaithTooltip.BLESSED_NAME), "神赐段不含道具名")
	var items := Glossary.strip_bbcode(String(sections[1]))
	t.check(items.begins_with("赐福之物") and items.contains("蛮神的护符") and items.contains(FaithTooltip.BLESSED_NAME), "第二段赐福之物：%s" % items.substr(0, 40))
	t.check(Glossary.strip_bbcode(String(sections[2])).begins_with("信力来源"), "第三段信力来源")
	t.check(Glossary.strip_bbcode(String(sections[3])).begins_with("献祭"), "第四段献祭")
	# 信力来源：每一行的所得都是信力色（表里第二格）
	var rows := RegEx.create_from_string("\\[cell expand=1\\](.*?)\\[/cell\\]").search_all(String(sections[2]))
	var gains := 0
	for m in rows:
		if m.get_string(1).contains("blank.png"):
			continue
		gains += 1
		t.check(m.get_string(1).contains("[color=@faith]"), "信力来源所得信力色：%s" % Glossary.strip_bbcode(m.get_string(1)))
	t.check(gains >= 2, "信力来源至少两行（%d）" % gains)
	# 条件里的数不上色：Lv.1「生命值低于 30%」的 30 不在 val 色里
	t.check(not String(sections[0]).contains("[color=@val]30"), "条件里的 30% 不上色")
	t.check(String(sections[0]).contains("[color=@val]10%[/color]"), "加成的 10% 上数值色")


static func run_bonus_numbers(t: TestCase) -> void:
	t.begin("257 · Glossary.bonus_numbers：加成数数值色、信力数信力色、条件数不染")
	var s := Glossary.bonus_numbers("生命值低于 30% 时，造成伤害提高 10%")
	t.check(not s.contains("[color=@val]30") and s.contains("[color=@val]10%[/color]"), "低于 30%% 不染、提高 10%% 染：%s" % s)
	var f := Glossary.bonus_numbers("伤害 +1，每 50 信力一份")
	t.check(f.contains("[color=@val]+1[/color]") and f.contains("[color=@faith]50[/color]"), "+1 数值色、50 信力色：%s" % f)
	t.check(Glossary.faith_numbers("献祭 ×5").contains("[color=@faith]5[/color]"), "faith_numbers 染信力色")


static func frame_item_faith_divider(t: TestCase, root: Window) -> void:
	t.begin("257 · 赐福长弓窗：神名居中的虚线小节（信力色）+ 两列加成，信物降成脚注一行")
	var c := CS._content()
	var bow := c.items.get_def(&"blessed_longbow")
	if bow == null:
		t.check(false, "缺长弓")
		return
	var saved := ItemTooltip.faith_probe
	ItemTooltip.faith_probe = Callable()
	var full := ItemTooltip.describe_full(ItemInstance.create(bow))
	var tip := HoverTip.new()
	root.add_child(tip)
	tip.show_item(full, Vector2(100, 100))
	var panel = tip._panel
	t.check(panel.faith_dash.visible and Glossary.strip_bbcode(panel.faith_title.text).contains("狩猎之神"), "有神名分隔行：%s" % panel.faith_title.text)
	t.check(String(full["faith_title"]).begins_with("[color=@faith]"), "神名信力色")
	t.check(panel.faith_body.visible and panel.faith_body.get_index() == panel.faith_dash.get_index() + 1, "加成在分隔行下面")
	var body := Glossary.strip_bbcode(String(full["body"]) if full.has("body") else "")
	t.check(not body.contains("右键"), "正文里没有信物行")
	var faith := String(full["faith"])
	t.check(faith.contains("[font_size=%d]" % ItemTooltip.ANCHOR_FOOT_SIZE) and Glossary.strip_bbcode(faith).contains("信物 · 右键奉为主信仰"), "信物脚注一行")
	t.check(not Glossary.strip_bbcode(faith).contains("：右键"), "信物行不再两个冒号")
	tip.show_text("别的", Vector2(100, 100))
	t.check(not panel.faith_dash.visible and not panel.faith_body.visible, "换别的窗：小节藏起")
	tip.queue_free()
	ItemTooltip.faith_probe = saved


static func frame_brute_window_height(t: TestCase, root: Window) -> void:
	t.begin("257 · 蛮神窗（带道具段、满阶）高度 ≤ 屏高 − 顶端栏")
	var c := CS._content()
	var brute: FaithDef = FaithDef.load_all().get(&"brute", null)
	if brute == null:
		t.check(false, "蛮神")
		return
	var limit := float(ProjectSettings.get_setting("display/window/size/viewport_height")) - maxf(HudHost.BAR_HEIGHT, HudHost.HudBarScript.design_height())
	var tip := HoverTip.new()
	root.add_child(tip)
	for pts in [45, 400]:
		tip.show_faith(FaithTooltip.describe_full(brute, _power(&"brute", pts), null, c.items), Vector2(100, 100))
		tip._refit()
		var h: float = tip._panel.get_combined_minimum_size().y
		t.check(h > 200.0 and h <= limit, "%d 信力：窗高 %d ≤ %d" % [pts, int(h), int(limit)])
	tip.queue_free()

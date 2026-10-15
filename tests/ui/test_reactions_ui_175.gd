## 175 第一批的可见性：悬浮窗「可引发」、对阵屏的元素小图标、百科的反应页（没引发过只写两种元素）、
## 局外记账（引发过的反应跟存档）、回放的反应弹字与日志行、buff 词条写印 / 截治疗 / 恢复叠层；
## 补充四：反应效果写「× 反应层数」、词条写按层计时 / 减半时机 / 按类型易伤、回放悬浮窗写「其中 N 层不可解除」
extends RefCounted

const Staff := preload("res://tests/run/test_crystal_148.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_tooltip(t: TestCase) -> void:
	t.begin("175 · 悬浮窗：法杖装着火晶石与雷晶石写「可引发：【过载】」；单独看没有这一行；对阵屏给它标火、雷")
	var db := _db()
	var b := Staff._staff_board(db, &"fire_crystal", &"lightning_crystal")
	var staff: ItemInstance = b["staff"]
	var text := ItemTooltip.describe(staff, b["board"])
	t.check(text.contains("可引发：【过载】"), "棋盘上：可引发过载（%s）" % text)
	t.check(not ItemTooltip.describe(staff).contains("可引发"), "单独看（没装晶石）：不写")
	var els := InventoryView.elements_of_board(b["board"])
	t.eq(els.get(staff.uid, []), [&"fire", &"lightning"] as Array[StringName], "法杖带火、雷（按元素顺序）")
	t.check(not els.has((b["left"] as ItemInstance).uid), "晶石自己不出手，不标")


static func run_encyclopedia(t: TestCase) -> void:
	t.begin("175 · 百科：「反应」一组十页；没引发过只写两种元素，引发过写说明与效果")
	var book := Encyclopedia.build(GameFlow.load_help_pages(), _db())
	var ids: Array[String] = []
	for id in book.ids():
		if id.begins_with("reaction:"):
			ids.append(id)
	t.eq(ids.size(), 10, "十页")
	t.eq(String(book.page("reaction:fire_poison").get("title", "")), "爆燃", "标题是反应名")
	var seen := {}
	book.reaction_lit = func(id: StringName) -> bool: return seen.has(id)
	var dark := book.render("reaction:fire_poison")
	t.check(dark.contains("还没有引发过") and dark.contains("火 + 毒") and not dark.contains("效果："), "没引发过：只写两种元素（%s）" % dark)
	seen[&"fire_poison"] = true
	var lit := book.render("reaction:fire_poison")
	lit = TextTemplate.strip_bbcode(lit)
	t.check(lit.contains("效果：") and lit.contains("造成 3 点火焰伤害（× 反应层数）") and lit.contains("施加灼伤（× 反应层数的一半）"), "引发过：说明与效果，随 N 变的标出来（%s）" % lit)
	t.check(not Names.description_of(ReactionResolver.by_id(&"fire_poison")).contains("3"), "说明里不写 M 的数（170）")
	var toc_has := false
	for cat in book.toc():
		for g in cat["groups"]:
			if String(g["group"]) == "reaction":
				toc_has = true
	t.check(toc_has, "目录里有「反应」一组")


static func run_meta(t: TestCase) -> void:
	t.begin("175 · 局外记账：打完一场记下引发过的反应，跟存档往返")
	var m := MetaState.new()
	t.eq(m.note_reactions([&"fire_poison", &"fire_poison", &"ice_bleed"]), 2, "记下两种（重复的只记一次）")
	t.eq(m.note_reactions([&"fire_poison"]), 0, "已经记过的不再算新")
	var back := MetaState.from_dict(m.to_dict(), _db())
	t.not_null(back, "读得回来")
	if back != null:
		t.check(back.reaction_seen(&"fire_poison") and back.reaction_seen(&"ice_bleed"), "往返后还在")
		t.check(not back.reaction_seen(&"fire_ice"), "没引发过的不亮")


static func run_replay(t: TestCase) -> void:
	t.begin("175 · 回放：反应弹字是反应名、颜色按第一种元素；buff 词条写印 / 截治疗 / 恢复叠层 / 按层计时 / 减半 / 剧毒；保底层写进悬浮窗")
	var e := BattleEvent.make(BattleEvent.EFFECT_RESOLVED, 0, 1, {"effect": ReactionResolver.EFFECT, "reaction": "fire_poison", "elements": ["fire", "poison"]})
	t.eq(BattleView.reaction_label(e), "爆燃", "弹字写反应名")
	t.eq(BattleView.reaction_color(e), UiPalette.damage_color(&"fire"), "颜色按火")
	var panel := CombatantPanel.new()
	panel.size = Vector2(300, 200)
	var l := panel.popup_text("爆燃", Color.RED)
	t.eq(l.text, "爆燃", "面板上飘一行反应名")
	t.check(l.get_theme_constant("outline_size") > 0, "描边")
	panel.free()
	var lib := ContentLibrary.buffs()
	t.check(Glossary.describe_buff(lib[&"scorch"]).contains("火元素的印"), "灼伤：火元素的印")
	var sb := Glossary.describe_buff(lib[&"scorched_blood"])
	t.check(sb.contains("治疗无效") and sb.contains("每层持续 1 秒") and sb.contains("按层计时"), "燃血：治疗无效、按层计时（%s）" % sb)
	var fb := Glossary.describe_buff(lib[&"fungal_blood"])
	t.check(fb.contains("实际回了几点就叠几层中毒") and fb.contains("每次恢复生命少 50%"), "菌血：恢复减半、按到手的量叠中毒（%s）" % fb)
	t.check(Glossary.describe_buff(lib[&"chill"]).contains("武器出手时") and not Glossary.describe_buff(lib[&"chill"]).contains("至多"), "寒冷：出手时生效、不封顶")
	t.check(Glossary.describe_buff(lib[&"numb"]).contains("付耐力时"), "麻痹：付耐力时生效")
	t.check(Glossary.describe_buff(lib[&"bleed"]).contains("每次结算后层数减半"), "流血：结算后减半")
	t.check(Glossary.describe_buff(lib[&"virulent"]).contains("受到的中毒伤害每层 +25%"), "剧毒：只放大毒素伤害（%s）" % Glossary.describe_buff(lib[&"virulent"]))
	# 凝毒的保底：回放悬浮窗写「其中 N 层不可解除」
	var view := BattleView.new()
	var p0 := CombatantPanel.new()
	var p1 := CombatantPanel.new()
	view._panels = [p0, p1]
	p1.buff_defs[&"poison"] = lib[&"poison"]
	view._apply(BattleEvent.make(BattleEvent.STATUS_STACKED, 0, 1, {"buff": "poison", "delta": 3, "stacks": 3, "guard": 3}))
	t.check(view.buff_tip("poison", 1).contains("其中 3 层不可解除"), "保底写进悬浮窗（%s）" % view.buff_tip("poison", 1))
	p0.free()
	p1.free()
	view.free()

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
	t.check(lit.contains("效果：") and lit.contains("造成 3 点火焰伤害（× 反应层数）") and lit.contains("施加 1 层灼伤（× 反应层数的一半）"), "引发过：说明与效果，随 N 变的标出来（%s）" % lit)
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
	# 185：玩家看的只有效果的合计；机制说明（元素印、按层计时、减半）只进 buff_rule_lines 给作者工具
	var plain := func(def: BuffDef, n: int = 0) -> String: return Glossary.strip_bbcode(Glossary.describe_buff(def, n))
	t.check(Glossary.buff_rule_lines(lib[&"scorch"]).has("火元素印"), "灼伤：作者工具写火元素印")
	t.check(not plain.call(lib[&"scorch"]).contains("元素印"), "玩家的窗不写元素印")
	var sb: String = plain.call(lib[&"scorched_blood"], 3)
	t.check(sb.contains("恢复量归零，每秒受到 3 点火焰伤害"), "燃血按作者原话（%s）" % sb)
	t.check(Glossary.buff_rule_lines(lib[&"scorched_blood"]).has("每层持续 1 秒"), "燃血：按层计时只在作者工具里")
	var fb: String = plain.call(lib[&"fungal_blood"], 4)
	t.check(fb.contains("恢复量减半，每次恢复获得等量的中毒"), "菌血按作者原话（%s）" % fb)
	t.check(plain.call(lib[&"chill"], 3).contains("下一次出手的冷却 +30%"), "寒冷 ×3：下一次出手的冷却 +30%")
	t.check(plain.call(lib[&"numb"], 2).contains("下一次付耐力多付 20%"), "麻痹 ×2：下一次付耐力多付 20%")
	t.check(Glossary.buff_rule_lines(lib[&"bleed"]).has("每次生效后层数减半"), "流血：减半写在作者工具里")
	t.check(plain.call(lib[&"virulent"], 2).contains("受到的毒素伤害 +50%"), "剧毒 ×2：只放大毒素伤害（%s）" % plain.call(lib[&"virulent"], 2))
	# 凝毒的保底：185 起不写「其中 N 层不可解除」（内部说明），只写现在的合计
	var view := BattleView.new()
	var p0 := CombatantPanel.new()
	var p1 := CombatantPanel.new()
	view._panels = [p0, p1]
	p1.buff_defs[&"poison"] = lib[&"poison"]
	view._apply(BattleEvent.make(BattleEvent.STATUS_STACKED, 0, 1, {"buff": "poison", "delta": 3, "stacks": 3, "guard": 3}))
	var tip := Glossary.strip_bbcode(view.buff_tip("poison", 1))
	t.check(tip.contains("每秒受到 3 点毒素伤害") and not tip.contains("不可解除"), "回放悬浮窗写合计、不写保底说明（%s）" % tip)
	p0.free()
	p1.free()
	view.free()

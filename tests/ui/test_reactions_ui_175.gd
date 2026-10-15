## 175 第一批的可见性：悬浮窗「可引发」、对阵屏的元素小图标、百科的反应页（没引发过只写两种元素）、
## 局外记账（引发过的反应跟存档）、回放的反应弹字与日志行、buff 词条写印 / 截治疗 / 锁
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
	t.check(lit.contains("效果：") and lit.contains("每层造成 3 点"), "引发过：说明与效果（%s）" % lit)
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
	t.begin("175 · 回放：反应弹字是反应名、颜色按第一种元素；buff 词条写印 / 截治疗 / 锁")
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
	t.check(Glossary.describe_buff(lib[&"scorch"]).contains("火元素的印"), "灼：火元素的印")
	t.check(Glossary.describe_buff(lib[&"scorched_blood"]).contains("治疗无效"), "燃血：治疗无效")
	t.check(Glossary.describe_buff(lib[&"fungal_blood"]).contains("少掉的变成中毒伤害"), "菌血：减半转毒伤")
	t.check(Glossary.describe_buff(lib[&"congeal"]).contains("不能被清除"), "凝毒：中毒不能被清除")

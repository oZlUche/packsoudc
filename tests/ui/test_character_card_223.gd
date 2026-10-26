## 223（作者 2026-10-21 16:07 选蜡板、甲 角色卡）：背包窗右栏的角色卡 —— 身体三行 = effective_baseline、▲▼ 与来源、被动两条、英文无汉字
extends RefCounted

const Buffs := preload("res://tests/run/test_run_buffs.gd")


static func _run(c: TestSupport.Content, buffs: Array[StringName]) -> RunState:
	var run := RunState.start(c.chapter, 41, c.items, c.enemies, c.sets, Buffs._kit(c).items, c.buffs, buffs)
	run.set_character(load("res://data/characters/andreus.tres") as CharacterDef)     # 256：布鲁图斯没有技能了，用安德烈乌斯（求饶 + 偷袭两条）
	return run


static func frame_card(t: TestCase, root: Window) -> void:
	t.begin("223 · 角色卡：身体三行 = effective_baseline（生命 / 耐力取整、耐力回复一位小数），没加成不写 ▲▼；局外筋骨 +10% 生命后 ▲ 与来源；被动两条；英文无汉字")
	var c := Buffs._content()
	var run := _run(c, [] as Array[StringName])
	var card := CharacterCard.new()
	root.add_child(card)
	card.refresh(run)
	var eff := run.effective_baseline()
	t.eq(String(card.row(0)["value"]), str(roundi(float(eff.base_stats.get(BattleStats.MAX_HP, 0.0)))), "生命上限 = 有效基线")
	t.eq(String(card.row(1)["value"]), str(roundi(float(eff.base_stats.get(BattleStats.MAX_STAMINA, BattleStats.default_value(BattleStats.MAX_STAMINA))))), "耐力上限 = 有效基线")
	t.eq(String(card.row(2)["value"]), "%.1f" % float(eff.base_stats.get(BattleStats.REGEN_STAMINA, BattleStats.default_value(BattleStats.REGEN_STAMINA))), "耐力回复一位小数")
	t.eq(String(card.row(2)["label"]), "耐力恢复/秒", "作者 10-25：第三行叫「耐力恢复/秒」")
	t.eq(String(card.row(2)["unit"]), "", "「每秒」并进名字，不再另写小字")
	for i in 3:
		t.eq(float(card.row(i)["delta"]), 0.0, "第 %d 行没加成：不写 ▲▼" % i)
	var skills := run.character.skill_entries()
	t.eq(card.passive_names(), skills.map(func(e): return String(e["name"])), "被动 = 角色的被动（主动藏着不列）")
	t.eq(card.passive_names().size(), 2, "两条")
	t.check(card.tip_text(3).contains(String(skills[0]["text"])), "被动停上去写全文")
	t.eq(card.row_at(Vector2(100, 20)), 0, "第一行在卡上沿 12..42")
	t.eq(card.row_at(Vector2(100, 120)), 3, "第一条被动在 111 起")

	var buffed := _run(c, [&"tech_sinew_1"] as Array[StringName])
	card.refresh(buffed)
	var own := float(buffed.player_baseline.base_stats.get(BattleStats.MAX_HP, 0.0))
	var hp := float(buffed.effective_baseline().base_stats.get(BattleStats.MAX_HP, 0.0))
	t.check(hp > own, "筋骨让生命上限变高（%.0f → %.0f）" % [own, hp])
	t.eq(float(card.row(0)["delta"]), float(roundi(hp) - roundi(own)), "▲N = 有效 − 角色本身")
	t.check(String(card.row(0)["tip"]).contains("筋骨"), "悬浮窗写是谁给的：%s" % String(card.row(0)["tip"]))
	var src := CharacterCard.sources(buffed, BattleStats.MAX_HP)
	t.eq(src.size(), 1, "生命只有一个来源")
	if src.size() == 1:
		t.eq(roundi(float(src[0]["delta"])), roundi(hp - own), "来源的数 = 加出来的数")
	t.eq(float(card.row(1)["delta"]), 0.0, "耐力没变")

	UiText.lang = "en"
	card.refresh(buffed)
	var han := RegEx.create_from_string("[\\x{4e00}-\\x{9fff}]")
	for i in 5:
		var text := card.tip_text(i) + (String(card.row(i).get("label", "")) + String(card.row(i).get("unit", "")) if i < 3 else "")
		t.check(han.search(text) == null, "英文：第 %d 行没有汉字（%s）" % [i, text])
	for i in card.passive_names().size():
		var lines := card.passive_lines(i)
		var whole := String(buffed.character.skill_entries()[i]["text"])
		t.eq(" ".join(lines), whole, "游戏测试 v3.81：英文被动写全文、只在空格处折行（%d 行）" % lines.size())
	t.check(card.size.y >= CharacterCard.SIZE.y and card.size.y <= 400.0, "卡跟着说明长高，仍在背包窗里（%.0f）" % card.size.y)
	var f := UiPalette.cjk_font()
	t.eq(CharacterCard.wrap_lines("Erosion takes 1 less Vitality", f, 13, f.get_string_size("Erosion takes 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 2.0, 6),
		["Erosion takes 1", "less Vitality"] as Array[String], "按词断，不拆 Erosion")
	t.eq(CharacterCard.wrap_lines("一二三四", f, 13, f.get_string_size("一二", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 1.0, 6), ["一二", "三四"] as Array[String], "汉字逐字断")
	t.eq(CharacterCard.wrap_lines("一二三四五六", f, 13, f.get_string_size("一二", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 1.0, 2)[1].right(1), "…", "超行数：末行加省略号")
	UiText.lang = "zh"
	card.queue_free()

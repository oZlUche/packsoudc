## 223（作者 2026-10-21 16:07 选蜡板、甲 角色卡）：背包窗右栏的角色卡 —— 身体三行 = effective_baseline、▲▼ 与来源、被动两条、英文无汉字
extends RefCounted

const Buffs := preload("res://tests/run/test_run_buffs.gd")


static func _run(c: TestSupport.Content, buffs: Array[StringName]) -> RunState:
	var run := RunState.start(c.chapter, 41, c.items, c.enemies, c.sets, Buffs._kit(c).items, c.buffs, buffs)
	run.set_character(load("res://data/characters/andreus.tres") as CharacterDef)     # 256：布鲁图斯没有技能了，用安德烈乌斯（求饶 + 偷袭两条）
	return run


static func frame_card(t: TestCase, root: Window) -> void:
	t.begin("223 / 381 · 角色卡：全属性分生存、攻击、探索三组；数 = 有效值（生命 / 耐力取整、回复一位小数），没加成白字；悬浮窗「说明 + 基础 + 加算 + 百分比」；局外筋骨不算这一局的（不黄）；升级的牌算（黄）；被动两枚小签；英文无汉字")
	var c := Buffs._content()
	var run := _run(c, [] as Array[StringName])
	var card := CharacterCard.new()
	root.add_child(card)
	card.refresh(run)
	var eff := run.effective_baseline()
	t.eq(card.group_labels(), ["生存", "攻击", "探索"] as Array[String], "三组")
	t.eq(String(card.row_of(&"max_hp")["value"]), str(roundi(float(eff.base_stats.get(BattleStats.MAX_HP, 0.0)))), "生命上限 = 有效基线")
	t.eq(String(card.row_of(&"max_stamina")["value"]), str(roundi(float(eff.base_stats.get(BattleStats.MAX_STAMINA, BattleStats.default_value(BattleStats.MAX_STAMINA))))), "耐力上限 = 有效基线")
	t.eq(String(card.row_of(&"regen_stamina")["value"]), "%.1f" % float(eff.base_stats.get(BattleStats.REGEN_STAMINA, BattleStats.default_value(BattleStats.REGEN_STAMINA))), "耐力回复一位小数")
	t.eq(String(card.row_of(&"regen_stamina")["label"]), "耐力恢复/秒", "作者 10-25：叫「耐力恢复/秒」")
	t.eq(String(card.row_of(&"crit_chance")["value"]), "%d%%" % roundi(float(eff.base_stats.get(BattleStats.CRIT_CHANCE, BattleStats.default_value(BattleStats.CRIT_CHANCE))) * 100.0), "暴击率按百分数")
	t.eq(String(card.row_of(&"weapon_damage")["value"]), "+0%", "没加成的武器伤害也列：+0%")
	t.check(card.row_count() >= 10, "属性行都在（%d 行）" % card.row_count())
	for i in card.row_count():
		t.check(not bool(card.row(i)["boosted"]), "开局没拿东西：第 %d 行白字" % i)
	var skills := run.character.skill_entries()
	t.eq(card.passive_names(), skills.map(func(e): return String(e["name"])), "被动 = 角色的被动（主动藏着不列）")
	t.eq(card.passive_names().size(), 2, "两枚小签")
	t.check(card.tip_text(card.row_count()).contains(String(skills[0]["text"])), "小签停上去写全文")
	t.eq(card.row_at(card.passive_rect(0).get_center()), card.row_count(), "停在第一枚小签上")
	t.eq(card.row_at(Vector2(100, float(card.row(0)["top"]) + 5.0)), 0, "停在第一行上")
	t.check(card.tip_text(0).begins_with("生命归零"), "悬浮窗第一行是说明：%s" % card.tip_text(0))

	var buffed := _run(c, [&"tech_sinew_1"] as Array[StringName])
	card.refresh(buffed)
	var own := float(buffed.player_baseline.base_stats.get(BattleStats.MAX_HP, 0.0))
	var hp := float(buffed.effective_baseline().base_stats.get(BattleStats.MAX_HP, 0.0))
	t.check(hp > own, "筋骨让生命上限变高（%.0f → %.0f）" % [own, hp])
	t.eq(String(card.row_of(&"max_hp")["value"]), str(roundi(hp)), "数 = 有效值")
	t.check(not bool(card.row_of(&"max_hp")["boosted"]), "局外科技不是这一局拿的：白字")
	var tip := String(card.row_of(&"max_hp")["tip"])
	t.check(tip.contains("%d[/color]" % roundi(own)) and tip.contains("%"), "第二行写基础与百分比：%s" % tip)
	t.check(tip.contains(CharacterCard.BOOST_COLOR.to_html(false)), "加成黄字")

	var lv := LevelModule.of(buffed)
	if lv != null:
		lv.taken[&"card_hp_flat"] = 1
		card.refresh(buffed)
		t.check(bool(card.row_of(&"max_hp")["boosted"]), "拿了体魄：生命上限黄字")
		t.check(not bool(card.row_of(&"max_stamina")["boosted"]), "耐力没动：白字")

	UiText.lang = "en"
	card.refresh(buffed)
	var han := RegEx.create_from_string("[\\x{4e00}-\\x{9fff}]")
	for i in card.row_count() + card.passive_names().size():
		var text := card.tip_text(i) + (String(card.row(i).get("label", "")) if i < card.row_count() else "")
		t.check(han.search(text) == null, "英文：第 %d 行没有汉字（%s）" % [i, text])
	t.check(card.size.y >= CharacterCard.SIZE.y and card.size.y <= 400.0, "卡放得进背包窗右栏（%.0f）" % card.size.y)
	var f := UiPalette.cjk_font()
	t.eq(CharacterCard.wrap_lines("Erosion takes 1 less Vitality", f, 13, f.get_string_size("Erosion takes 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 2.0, 6),
		["Erosion takes 1", "less Vitality"] as Array[String], "按词断，不拆 Erosion")
	t.eq(CharacterCard.wrap_lines("一二三，四", f, 13, f.get_string_size("一二三", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 1.0, 6), ["一二", "三，四"] as Array[String], "避头：逗号不落行首，带上一个字下来（复测 10-27）")
	t.eq(CharacterCard.wrap_lines("一二三四", f, 13, f.get_string_size("一二", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 1.0, 6), ["一二", "三四"] as Array[String], "汉字逐字断")
	t.eq(CharacterCard.wrap_lines("一二三四五六", f, 13, f.get_string_size("一二", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 1.0, 2)[1].right(1), "…", "超行数：末行加省略号")
	UiText.lang = "zh"
	card.queue_free()

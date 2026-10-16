## 175 补 5.5：效果栏图标 —— 每个 buff、每条轴正负、两个系统格都取得到图；被动条目与缺图回首字；
## 着色（元素状态 / 反应产物用关键词色，其余按组）；保底的中毒 / 流血换彩色成品；图标格 28×28、层数单独取
extends RefCounted


static func run_coverage(t: TestCase) -> void:
	t.begin("175 补 5.5 · 图标齐：内容库每个 buff、十三条轴正负、鏖战与格挡各有一张；被动条目没有")
	EffectIcons.clear_cache()
	var missing: Array = []
	for id in ContentLibrary.buffs():
		if EffectIcons.of(String(id), 1) == null:
			missing.append(id)
	for axis in StatAxes.ORDER:
		for v in [1, -1]:
			if EffectIcons.of(CombatantPanel.AXIS_PREFIX + String(axis), v) == null:
				missing.append("%s %d" % [axis, v])
	for id in [CombatantPanel.OVERTIME_CHIP, CombatantPanel.BLOCK_CHIP]:
		if EffectIcons.of(id, 1) == null:
			missing.append(id)
	t.check(missing.is_empty(), "缺图：%s" % [missing])
	t.eq(EffectIcons.of("passive:0", 3), null, "被动条目永远首字")
	t.eq(EffectIcons.file_of("axis:attack_speed", 2), "axis_attack_speed_pos", "正层取 pos")
	t.eq(EffectIcons.file_of("axis:attack_speed", -2), "axis_attack_speed_neg", "负层取 neg")
	t.eq(EffectIcons.file_of("system:block", 5), "system_block", "系统格")
	var tex := EffectIcons.of("scorch", 1)
	t.eq(tex.get_size() if tex != null else Vector2.ZERO, Vector2(56, 56), "源图 56（按 28 显示）")


static func run_tint(t: TestCase) -> void:
	t.begin("175 补 5.5 · 着色：元素状态与反应产物用补 5.4 的关键词色，其余按组；保底的中毒 / 流血换彩色成品")
	var lib := ContentLibrary.buffs()
	t.eq(EffectIcons.tint_of("scorch", lib.get(&"scorch"), 1), Color("ff8a4c"), "灼伤")
	t.eq(EffectIcons.tint_of("chill", lib.get(&"chill"), 1), Color("8fdcff"), "寒冷")
	t.eq(EffectIcons.tint_of("numb", lib.get(&"numb"), 1), Color("ffe45c"), "麻痹用 shock 色")
	t.eq(EffectIcons.tint_of("poison", lib.get(&"poison"), 1), Color("8fe060"), "中毒")
	t.eq(EffectIcons.tint_of("bleed", lib.get(&"bleed"), 1), Color("ff4f72"), "流血")
	t.eq(EffectIcons.tint_of("scorched_blood", lib.get(&"scorched_blood"), 1), Color("ff8a4c"), "燃血跟灼伤")
	t.eq(EffectIcons.tint_of("virulent", lib.get(&"virulent"), 1), Color("8fe060"), "剧毒跟中毒")
	t.eq(EffectIcons.tint_of("fungal_blood", lib.get(&"fungal_blood"), 1), Color("8fe060"), "菌血跟中毒")
	t.eq(EffectIcons.tint_of("system:overtime", null, 0), CombatantPanel.SYSTEM_COLOR, "系统琥珀")
	t.eq(EffectIcons.tint_of("axis:damage_dealt", null, 1), UiPalette.HP, "减益红")
	t.eq(EffectIcons.tint_of("blood_rage", lib.get(&"blood_rage"), 2), UiPalette.ARMOR, "增益蓝")

	t.check(EffectIcons.of("poison", 3, 2) != EffectIcons.of("poison", 3, 0), "中毒带保底：换整张")
	t.check(EffectIcons.is_guard_art("poison", 3, 2) and EffectIcons.is_guard_art("bleed", 3, 1), "中毒 / 流血有保底成品")
	t.check(not EffectIcons.is_guard_art("poison", 3, 0), "没保底不换")
	t.check(not EffectIcons.is_guard_art("scorch", 3, 2), "别的状态没有保底成品，照旧着色")


static func run_fallback(t: TestCase) -> void:
	t.begin("175 补 5.5 · 缺图回首字：目录指到别处取不到图，格子照旧写「首字 ×层数」；层数单独取")
	var saved := EffectIcons.art_dir
	EffectIcons.art_dir = "res://nowhere/"
	EffectIcons.clear_cache()
	t.eq(EffectIcons.of("poison", 3), null, "取不到 null，不报错")
	EffectIcons.art_dir = saved
	EffectIcons.clear_cache()

	var panel := CombatantPanel.new()
	panel.buff_defs = ContentLibrary.buffs()
	panel.set_stacks("poison", 4)
	panel.set_axis("attack_speed", -3)
	t.eq(panel.chip_count("poison"), "4", "层数")
	t.eq(panel.chip_count("axis:attack_speed"), "3", "轴格画绝对值")
	t.check(panel.icon_texture("poison") != null and panel.icon_texture("axis:attack_speed") != null, "有图")
	t.eq(panel.chip_text("poison"), "中 ×4", "首字退路的字不变")
	panel.free()


static func frame_icon_chips(t: TestCase, root: Window) -> void:
	t.begin("175 补 5.5 · 对阵面板：有图的格子 28×28，被动条目照旧是首字格")
	var panel := CombatantPanel.new()
	panel.label_font = UiPalette.cjk_font()
	root.add_child(panel)
	panel.size = Vector2(360, 200)
	panel.buff_defs = ContentLibrary.buffs()
	panel.passives = [PassiveNote.make(&"faith:x", "信仰：自然之神", 3)]
	panel.reset({"resources": {"hp": [10, 10]}})
	panel.set_stacks("poison", 4)
	panel.guards["poison"] = 1
	panel.set_stacks("scorch", 2)
	panel._draw()     # 直接画一遍，算出图标的矩形
	var sizes := {}
	for c in panel._chips:
		sizes[String(c[1])] = (c[0] as Rect2).size
	t.eq(sizes.get("poison"), Vector2(28, 28), "中毒格 28×28")
	t.eq(sizes.get("scorch"), Vector2(28, 28), "灼伤格 28×28")
	t.check(sizes.has("passive:0") and (sizes["passive:0"] as Vector2).x > 28.0, "被动条目是首字格（%s）" % [sizes.get("passive:0")])
	panel.queue_free()

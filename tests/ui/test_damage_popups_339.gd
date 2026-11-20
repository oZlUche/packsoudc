## 339：战斗飘字 —— 时长跟倍速、停住时一起停、暴击保留类型色、反应两色渐变、细描边
extends RefCounted


static func _tween(l: Label) -> Tween:
	return l.get_meta(&"tween") as Tween


static func frame_durations(t: TestCase, root: Window) -> void:
	t.begin("339 · 飘字时长：1 / 2 / 4 倍速约 0.9 / 0.45 / 0.3 秒；反应名 1.2 / 0.6 / 0.5 秒")
	var panel := CombatantPanel.new()
	root.add_child(panel)
	panel.size = Vector2(300, 200)
	for row in [[1.0, 0.9], [0.5, 0.45], [0.25, 0.3]]:
		var l := panel.popup(12, &"fire", false, false, row[0])
		var tw := _tween(l)
		tw.custom_step(row[1] - 0.02)
		t.check(l.modulate.a > 0.0, "倍速系数 %s：%s 秒前还看得见" % [row[0], row[1]])
		tw.custom_step(0.05)
		t.check(is_zero_approx(l.modulate.a), "倍速系数 %s：%s 秒飘完" % [row[0], row[1]])
	for row in [[1.0, 1.2], [0.5, 0.6], [0.25, 0.5]]:
		var r := panel.popup_text("爆燃", Color.RED, row[0])
		var tw := _tween(r)
		tw.custom_step(row[1] - 0.02)
		t.check(r.modulate.a > 0.0, "反应名 %s：还看得见" % row[0])
		tw.custom_step(0.05)
		t.check(is_zero_approx(r.modulate.a), "反应名 %s：%s 秒飘完" % [row[0], row[1]])
	panel.free()

	var view := BattleView.new()
	t.eq(view._popup_scale(), 1.0, "1 倍速：系数 1")
	view._speed_idx = BattleView.SPEEDS.find(2.0)
	t.eq(view._popup_scale(), 0.5, "2 倍速：系数 0.5（不像抖动那样只在 4 倍才缩）")
	view._speed_idx = BattleView.SPEEDS.find(4.0)
	t.eq(view._popup_scale(), 0.25, "4 倍速：系数 0.25")
	view.free()


static func run_pause(t: TestCase) -> void:
	t.begin("339 · 回放停住：场上的飘字都停在原地，接着放时接着飘；停着时新出的字也停着")
	var panel := CombatantPanel.new()
	panel.size = Vector2(300, 200)
	var a := panel.popup(5, &"physical")
	var b := panel.popup_text("过载", Color.YELLOW)
	panel.pause_popups(true)
	t.check(panel.popups_paused(), "记着停了")
	t.check(not _tween(a).is_running() and not _tween(b).is_running(), "伤害数和反应名都停")
	var c := panel.popup(7, &"fire")
	t.check(not _tween(c).is_running(), "停着时新出的字也停着")
	panel.pause_popups(false)
	t.check(_tween(a).is_running() and _tween(b).is_running() and _tween(c).is_running(), "接着放：都接着飘")
	panel.free()


static func frame_colors(t: TestCase, root: Window) -> void:
	t.begin("339 · 颜色：暴击仍是类型色（不换金）、字大一号描边加倍；冰雷有自己的颜色；治疗绿；都有细描边")
	var panel := CombatantPanel.new()
	root.add_child(panel)
	panel.size = Vector2(300, 200)
	var hit := panel.popup(12, &"fire")
	var crit := panel.popup(12, &"fire", false, true)
	t.eq(crit.label_settings.font_color, UiPalette.damage_color(&"fire"), "火的暴击：火的颜色")
	t.check(crit.label_settings.font_color != UiPalette.CRIT, "不是金色")
	t.check(crit.label_settings.font_size > hit.label_settings.font_size, "暴击字大一号")
	t.eq(hit.label_settings.outline_size, UiTheme.OUTLINE_SIZE, "普通：细描边")
	t.eq(crit.label_settings.outline_size, UiTheme.OUTLINE_SIZE * 2, "暴击：描边两倍")
	t.eq(crit.text, "-12", "暴击：数字那段")
	var mark := crit.get_node_or_null("CritMark") as Label
	t.not_null(mark, "2C：末尾的「!」单独一段")
	if mark != null:
		t.eq(mark.text, "!", "「!」")
		t.eq(mark.label_settings.font_color, UiPalette.CRIT, "「!」染暴击金")
		t.eq(mark.label_settings.outline_size, crit.label_settings.outline_size, "「!」描边同数字")
		t.eq(mark.get_meta(&"exempt_bare_text", ""), "effect", "「!」也带守门标记")
	t.is_null(hit.get_node_or_null("CritMark"), "普通的没有「!」")
	_tween(crit).custom_step(0.06)
	t.check(crit.scale.x > 1.05, "暴击出现时放大一下（%s）" % crit.scale.x)
	_tween(crit).custom_step(0.1)
	t.check(is_equal_approx(crit.scale.x, 1.0), "随后弹回原大")
	t.check(is_equal_approx(hit.scale.x, 1.0), "普通的不放大")
	var heal := panel.popup(4, &"physical", true)
	t.eq(heal.label_settings.font_color, UiPalette.HEAL, "治疗青绿")
	t.check(heal.label_settings.outline_size > 0, "治疗也有描边")
	t.eq(hit.get_meta(&"exempt_bare_text", ""), "effect", "226 守门标记还在")
	var white := UiPalette.style_color("fg", &"dark")
	t.check(UiPalette.damage_color(&"ice") != white and UiPalette.damage_color(&"lightning") != white, "冰、雷和白字分得开")
	t.check(UiPalette.damage_color(&"ice") != UiPalette.damage_color(&"lightning"), "冰、雷彼此分得开")
	panel.free()


static func run_gradient(t: TestCase) -> void:
	t.begin("339 · 反应：反应名与反应打的伤害数用两种元素色渐变；没有反应的伤害不挂；只有一种色退回单色")
	var def := ReactionResolver.by_id(&"fire_ice")
	t.not_null(def, "火冰反应在表里")
	if def == null:
		return
	var react := BattleEvent.make(BattleEvent.EFFECT_RESOLVED, 0, 1, {"effect": ReactionResolver.EFFECT, "reaction": "fire_ice", "elements": ["ice", "fire"]})
	var cs := BattleView.reaction_colors(react)
	t.eq(cs.size(), 2, "两种色")
	t.eq(cs[0], UiPalette.damage_color(def.elements[0]), "第一种按反应表的顺序")
	t.eq(cs[1], UiPalette.damage_color(def.elements[1]), "第二种按反应表的顺序")
	t.eq(BattleView.reaction_color(react), cs[0], "单色退路 = 第一种")
	var dmg := BattleEvent.make(BattleEvent.DAMAGE, 0, 1, {"amount": 9, "type": "fire", "reaction": "fire_ice"})
	t.eq(BattleView.reaction_colors(dmg).size(), 2, "反应打的伤害：从反应 id 查到两种色")
	var panel := CombatantPanel.new()
	panel.size = Vector2(300, 200)
	var l := panel.popup(9, &"fire", false, false, 1.0, cs)
	var m := l.material as ShaderMaterial
	t.not_null(m, "反应打的伤害数：挂渐变")
	if m != null:
		t.eq(m.get_shader_parameter(&"color_a"), cs[0], "左边第一种色")
		t.eq(m.get_shader_parameter(&"color_b"), cs[1], "右边第二种色")
		t.eq(l.label_settings.font_color, Color.WHITE, "字本身白色（由着色器上色）")
	var plain := panel.popup(9, &"fire")
	t.is_null(plain.material, "没有反应的伤害：不挂")
	t.eq(plain.label_settings.font_color, UiPalette.damage_color(&"fire"), "仍是单色")
	var name_label := panel.popup_text("冰火", BattleView.reaction_color(react), 1.0, cs)
	t.not_null(name_label.material, "反应名：挂渐变")
	t.check(name_label.label_settings.outline_size > 0, "反应名描边还在")
	var one := panel.popup_text("冰火", Color.RED, 1.0, [Color.RED])
	t.is_null(one.material, "只有一种色：不挂，退回单色")
	t.eq(one.label_settings.font_color, Color.RED, "单色")
	panel.free()

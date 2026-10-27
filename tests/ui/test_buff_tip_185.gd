## 185（作者 2026-10-17 定稿）：效果悬浮窗 —— 深底窗嵌在浅石板里也是亮字；只写名字行与现在的合计；数值全上 val 色；
## 文字窗按内容收窄；机制说明只给作者工具；血怒 +15% / +15%；菌血、燃血按作者原话；限时的写时间、图标上画计时环（16:24）
extends RefCounted


static func _plain(def: BuffDef, n: int = 0) -> String:
	return Glossary.strip_bbcode(Glossary.describe_buff(def, n))


static func run_effect_totals(t: TestCase) -> void:
	t.begin("185 · 效果只写现在的合计：中毒 ×5、血怒、坚韧 ×2、菌血、燃血；不写每层 / 当前 / 元素印 / 不可叠层")
	var lib := ContentLibrary.buffs()
	var poison: String = _plain(lib[&"poison"], 5)
	t.check(poison.contains("中毒 ×5") and poison.contains("每秒受到 5 点毒素伤害"), "中毒 ×5（%s）" % poison)
	for word in ["每层", "当前", "元素印", "元素的印"]:
		t.check(not poison.contains(word), "中毒不写「%s」" % word)
	var rage: String = _plain(lib[&"blood_rage"])
	t.check(rage.contains("造成的伤害 +15%") and rage.contains("攻速 +15%"), "血怒 +15%% / +15%%（%s）" % rage)
	t.check(not rage.contains("不可叠层") and not rage.contains("×"), "血怒：不写不可叠层、不写 ×N")
	t.check(rage.contains("持续 10 秒"), "限时的写时长（作者 16:24）")
	t.check(_plain(lib[&"hardy_guard"], 2).contains("护甲上限 +30"), "坚韧 ×2：护甲上限 +30")
	t.check(_plain(lib[&"fungal_blood"], 4).contains("恢复量减半，每次恢复获得等量的中毒"), "菌血按作者原话")
	t.check(_plain(lib[&"scorched_blood"], 3).contains("恢复量归零，每秒受到 3 点火焰伤害"), "燃血按作者原话")
	t.check(_plain(lib[&"marked"]).contains("格挡 −3"), "标记：格挡 −3")
	t.check(Glossary.strip_bbcode(Glossary.buff_body(lib[&"poison"])).contains("每秒受到 1 点"), "图鉴 / 子窗按 1 层")
	t.check(Glossary.buff_rule_lines(lib[&"scorched_blood"]).has("每层持续 1 秒"), "作者工具仍看得到按层计时")
	t.check(Glossary.buff_rule_lines(lib[&"poison"]).has("毒元素印"), "作者工具写元素印（查询清单二.2）")


static func run_values_colored(t: TestCase) -> void:
	t.begin("185 · 数值全在 [color=@val] 里：拿掉数值段之后正文里没有裸数字")
	var lib := ContentLibrary.buffs()
	var bare: Array[String] = []
	var re := RegEx.create_from_string("\\[color=@val\\][^\\[]*\\[/color\\]")
	for id in lib:
		var def: BuffDef = lib[id]
		for n in [1, 3]:
			var parts := Glossary.buff_tip_parts(def, n)
			var text := re.sub(String(parts["head"]) + "\n" + String(parts["body"]), "", true)
			if RegEx.create_from_string("\\d").search(Glossary.strip_bbcode(text)) != null:
				bare.append("%s ×%d：%s" % [id, n, Glossary.strip_bbcode(text)])
	t.check(bare.is_empty(), "没有裸数字：%s" % "；".join(bare))
	t.eq(Glossary.val("5"), "[color=@val]5[/color]", "val 就是数值色")
	t.not_null(UiPalette.text_colors()["styles"].get("val", null), "字色模板登记了 val")


static func run_no_rule_lines_for_players(t: TestCase) -> void:
	t.begin("185 · 玩家的窗不写机制说明：层数减半、计时、不可解除、元素印；回放窗写还剩几秒")
	var lib := ContentLibrary.buffs()
	var view := BattleView.new()
	var p0 := CombatantPanel.new()
	var p1 := CombatantPanel.new()
	view._panels = [p0, p1]
	var leaks: Array[String] = []
	for id in lib:
		p0.buff_defs[id] = lib[id]
		p0.set_stacks(String(id), 2)
		var tip := Glossary.strip_bbcode(view.buff_tip(String(id), 0))
		for word in ["层数减半", "计时", "不可解除", "元素印", "不限层", "永续"]:
			if tip.contains(word):
				leaks.append("%s：%s" % [id, word])
	t.check(leaks.is_empty(), "没有内部说明：%s" % "，".join(leaks))
	# 限时（185 补充一）：血怒 10 秒，第 2 秒上身（载荷带到期时刻）、现在第 5 秒 → 还剩 7 秒，环剩七成
	p1.buff_defs[&"blood_rage"] = lib[&"blood_rage"]
	view._apply(BattleEvent.make(BattleEvent.STATUS_STACKED, StatMath.from_float(2.0), 1, {"buff": "blood_rage", "delta": 1, "stacks": 1,
		"expires_at": StatMath.from_float(12.0), "seconds_left": 0}))
	p1.set_now(5.0)
	t.check(absf(p1.time_left("blood_rage") - 7.0) < 0.01, "还剩 7 秒（%.2f）" % p1.time_left("blood_rage"))
	t.check(absf(p1.time_ratio("blood_rage") - 0.7) < 0.01, "计时环剩七成")
	t.check(Glossary.strip_bbcode(view.buff_tip("blood_rage", 1)).contains("还剩 7 秒"), "悬浮窗写还剩几秒")
	# 叠满了只刷新：delta 0 那条把到期时刻往后推，环回满
	view._apply(BattleEvent.make(BattleEvent.STATUS_STACKED, StatMath.from_float(5.0), 1, {"buff": "blood_rage", "delta": 0, "stacks": 1,
		"expires_at": StatMath.from_float(15.0), "seconds_left": 0, "reason": "refresh"}))
	t.check(absf(p1.time_ratio("blood_rage") - 1.0) < 0.01, "再上身：环回满")
	# 老回放存档：没有计时键 = 当永续
	p1.buff_defs[&"marked"] = lib[&"marked"]
	view._apply(BattleEvent.make(BattleEvent.STATUS_STACKED, 0, 1, {"buff": "marked", "delta": 1, "stacks": 1}))
	t.eq(p1.time_left("marked"), -1.0, "老格式：不写时间、不画环")
	# 按层计时（燃血）：写还剩几秒，不画环
	p1.buff_defs[&"scorched_blood"] = lib[&"scorched_blood"]
	view._apply(BattleEvent.make(BattleEvent.STATUS_STACKED, StatMath.from_float(4.0), 1, {"buff": "scorched_blood", "delta": 3, "stacks": 3, "expires_at": -1, "seconds_left": 3}))
	t.check(absf(p1.time_left("scorched_blood") - 2.0) < 0.01, "燃血：还剩 2 秒（%.2f）" % p1.time_left("scorched_blood"))
	t.eq(p1.time_ratio("scorched_blood"), -1.0, "按层计时不画环")
	t.eq(p1.time_left("poison"), -1.0, "永续的没有计时")
	var inst := BuffInstance.create(lib[&"blood_rage"], 1, StatMath.from_float(1.0))
	t.eq(int(inst.timer_payload()["expires_at"]), StatMath.from_float(11.0), "运行时把到期时刻放进载荷")
	p1.set_stacks("blood_rage", 0)
	t.check(not p1.timers.has("blood_rage"), "拿掉了计时也清")
	p0.free()
	p1.free()
	view.free()


static func frame_bright_text_and_width(t: TestCase, root: Window) -> void:
	t.begin("185 · 皮革窗嵌在浅石板里也是亮字；文字窗按内容收窄（220～360），长的到 360")
	var slab := Control.new()
	slab.size = Vector2(1200, 800)
	UiTheme.apply_tone(slab, UiTheme.PANEL_OVERLAY)
	root.add_child(slab)
	var tip := HoverTip.new()
	slab.add_child(tip)
	var lib := ContentLibrary.buffs()
	tip.show_status(Glossary.buff_tip_parts(lib[&"marked"], 0), Vector2(100, 100))
	var ink := UiTheme.text_theme(UiTheme.TONE_LIGHT).get_color("default_color", "RichTextLabel")
	t.check(tip._panel.body.get_theme_color("default_color") != ink, "正文不是墨色")
	t.check(tip._panel.head.visible and tip._panel.sep.visible, "名字行、分隔线")
	tip._refit()
	tip._refit()
	t.check(tip._panel.body.custom_minimum_size.x < HoverTip.MAX_WIDTH and tip._panel.body.custom_minimum_size.x >= HoverTip.MIN_WIDTH,
		"短的收窄（%.0f）" % tip._panel.body.custom_minimum_size.x)
	tip.hide_tip()
	tip.show_text("这是一段很长很长的说明文字，长到一行放不下，要折成好几行才能写完，所以窗要撑到最宽的那一档才对。", Vector2(100, 100))
	tip._refit()
	tip._refit()
	var w := tip._panel.body.custom_minimum_size.x
	t.check(w > HoverTip.scaled(HoverTip.MAX_WIDTH) - 24.0 and w <= HoverTip.scaled(HoverTip.MAX_WIDTH), "长的折行、宽到 360 这一档（258：随字号档；%.0f）" % w)
	slab.queue_free()

## 193（作者 2026-10-18 晚的反馈）：悬浮窗 —— 亮字主题不再把没写默认色的变体取成纯黑（节点浮窗黑字）；
## 钉住先等半秒再起步；源每帧核对（视图藏了 / 道具没了 / 鼠标挪到空格就收）；没正文的道具窗不留空白；献祭一行图标不写名字
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func run_bright_theme(t: TestCase) -> void:
	t.begin("193 §1 · 亮字主题：每一种字色都不是纯黑，富文本小字 / 正文和富文本本身同色；全局主题给变体写了默认字色")
	UiTheme._tone_themes.erase(&"bright")
	var bright := UiTheme.bright_text_theme()
	var black := 0
	for type in bright.get_color_type_list():
		for key in bright.get_color_list(type):
			if bright.get_color(key, type) == Color(0, 0, 0, 1):
				black += 1
	t.eq(black, 0, "亮字主题里没有纯黑")
	for v in [UiTheme.RICH_SMALL, UiTheme.RICH_BODY]:
		if bright.has_color("default_color", v):
			t.eq(bright.get_color("default_color", v), bright.get_color("default_color", "RichTextLabel"), "%s 和富文本同色" % v)
	var base := UiTheme.current()
	t.check(base.has_color("default_color", UiTheme.RICH_SMALL) and base.has_color("default_color", UiTheme.RICH_BODY), "全局主题：富文本两个变体有默认色")
	t.check(base.has_color("font_color", UiTheme.LABEL_HUD) and base.has_color("font_color", UiTheme.LABEL_HUD_LARGE) and base.has_color("font_color", UiTheme.LABEL_HUD_DOUBLE), "全局主题：顶端栏标签三个变体有默认字色")


static func frame_node_tip_color(t: TestCase, root: Window) -> void:
	t.begin("193 §1 · 地图点那种纯文字的浮窗：没上色的字是前景浅色，不是黑")
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.show_text("有人在这里做买卖。", Vector2(200, 200))
	var c := tip._text.get_theme_color("default_color", UiTheme.RICH_SMALL)
	t.check(c.get_luminance() > 0.6, "正文默认色够亮（%s）" % c)
	t.eq(tip._text.get_theme_color("default_color", UiTheme.RICH_SMALL), UiPalette.FG, "就是前景色")
	host.queue_free()


static func run_pin_delay(t: TestCase) -> void:
	t.begin("193 §3.1 · 钉住先等 0.5 秒：0.4 秒没线、0.6 秒线走了约六分之一、1.1 秒钉住")
	t.eq(HoverTip.pin_progress(0.4), 0.0, "0.4 秒：没线")
	t.check(absf(HoverTip.pin_progress(0.6) - 0.1 / HoverTip.PIN_SEC) < 0.001, "0.6 秒：进度 %.2f" % HoverTip.pin_progress(0.6))
	t.eq(HoverTip.pin_progress(HoverTip.PIN_DELAY_SEC + HoverTip.PIN_SEC), 1.0, "走满")


static func frame_pin_delay_window(t: TestCase, root: Window) -> void:
	t.begin("193 §3.1 · 窗上：停在源上 0.4 秒没线、1.1 秒钉住；子窗一样")
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var tip := HoverTip.new()
	host.add_child(tip)
	var far := Vector2(5, 880)
	tip.show_text("地图上的点", Vector2(400, 400))
	tip.tick(0.4, far)
	t.eq(HoverTip.pin_progress(tip._panel.dwell), 0.0, "0.4 秒：还没起步")
	t.check(not tip.is_pinned(), "没钉")
	tip.tick(0.2, far)
	t.check(HoverTip.pin_progress(tip._panel.dwell) > 0.0 and not tip.is_pinned(), "0.6 秒：线在走")
	tip.tick(0.5, far)
	t.check(tip.is_pinned(), "1.1 秒：钉住")
	tip._panel.terms = {"probe": {"name": "探针", "text": "说明"}}
	var child := tip.open_child(tip._panel, "term:probe")
	t.not_null(child, "开了子窗")
	if child != null:
		tip._panel.hover("term:probe")     # 作者 10-27：子窗只认停在开它的词上
		tip.tick(0.55, far)
		t.check(not child.pinned, "子窗 0.55 秒：没钉")
		tip.tick(0.6, far)
		t.check(child.pinned, "子窗 1.15 秒：钉住")
	tip._panel.terms["probe2"] = {"name": "探针二", "text": "说明"}
	var loose := tip.open_child(tip._panel, "term:probe2")
	if loose != null:
		tip._panel.hover("")
		tip.tick(0.016, loose.global_position + loose.size * 0.5)
		t.check(not tip.windows().has(loose), "没钉住的子窗：词上移开（移进子窗也算）当场收")
	host.queue_free()


static func _board_tip(root: Window) -> Dictionary:
	var c := CS._content()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var inst := ItemInstance.create(c.items.get_def(&"poison_arrows"))
	board.place(inst, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	var on := InputEventMouseMotion.new()
	on.position = Vector2(24, 24)
	view.gui_input.emit(on)
	return {"host": host, "board": board, "inst": inst, "view": view, "tip": tip, "src": view.global_position + on.position, "on": on}


static func frame_source_check(t: TestCase, root: Window) -> void:
	t.begin("193 §3.2 · 源每帧核对：钉住的窗在视图藏起来后收；道具被拿走后收；鼠标挪到空格但没有鼠标事件也当场收")
	var f := _board_tip(root)
	var tip: HoverTip = f["tip"]
	var view: InventoryView = f["view"]
	var src: Vector2 = f["src"]
	t.check(tip.is_showing(), "停在道具上：出现")
	tip.tick(HoverTip.PIN_DELAY_SEC + HoverTip.PIN_SEC + 0.01, src)
	t.check(tip.is_pinned(), "钉住了")
	view.visible = false
	tip.tick(0.016, src)
	t.check(not tip.is_showing(), "视图藏了（进点开事件屏）：钉住的也收")
	(f["host"] as Control).queue_free()
	# 道具被拿走
	f = _board_tip(root)
	tip = f["tip"]
	(f["board"] as GridInventory).remove((f["inst"] as ItemInstance).uid)
	tip.tick(0.016, f["src"])
	t.check(not tip.is_showing(), "道具不在了：收")
	(f["host"] as Control).queue_free()
	# 鼠标挪到空格，没有鼠标事件
	f = _board_tip(root)
	tip = f["tip"]
	view = f["view"]
	var empty := view.global_position + Vector2(0.5, 3.5) * InventoryView.CELL     # 窗开在鼠标右下：左下角那格不在窗里
	t.check(not tip._panel.global_rect().has_point(empty) and (f["board"] as GridInventory).cell_uid(Vector2i(0, 3)) == GridInventory.EMPTY_UID, "那一格空着、不在窗里")
	tip.tick(0.05, empty)
	t.check(not tip.is_showing(), "作者 10-27：挪开当场收（不再有宽限）")
	(f["host"] as Control).queue_free()
	# 宿主自己藏了：文字窗也收
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var text_tip := HoverTip.new()
	host.add_child(text_tip)
	text_tip.show_text("地图上的点", Vector2(300, 300))
	host.visible = false
	text_tip.tick(0.016, Vector2(5, 5))
	t.check(not text_tip.is_showing(), "宿主藏了：文字窗收")
	host.queue_free()


static func frame_empty_body(t: TestCase, root: Window) -> void:
	t.begin("193 §3.3 · 没有正文的道具窗（蛮族的项链）：藏掉分隔线与正文，只剩名字 / 虚线 / 价值与重量")
	var c := CS._content()
	var def := c.items.get_def(&"barbarian_necklace")
	t.not_null(def, "有蛮族的项链")
	if def == null:
		return
	var full := ItemTooltip.describe_full(ItemInstance.create(def))
	t.eq(String(full["body"]), "", "正文是空串")
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.show_item(full, Vector2(100, 100))
	t.check(not tip._panel.sep.visible and not tip._panel.body.visible, "分隔线、正文都藏了")
	t.check(tip._panel.foot_row.visible and tip._panel.foot_sep.visible, "虚线与脚注还在")
	t.check(not tip.text().contains("\n\n"), "纯文字不拼空行")
	var arrows := ItemTooltip.describe_full(ItemInstance.create(c.items.get_def(&"poison_arrows")))
	tip.show_item(arrows, Vector2(100, 100))
	t.check(tip._panel.sep.visible and tip._panel.body.visible, "有正文的照旧")
	host.queue_free()


static func run_offer_row(t: TestCase) -> void:
	t.begin("193 §3.4 · 信仰窗献祭：一行图标、不写名字；缺图退回文字（257：图标下一行写 ×N 倍率，信力色）")
	var defs := FaithDef.load_all()
	for id in defs:
		var def: FaithDef = defs[id]
		var sec := FaithTooltip._offer_section(def)
		if sec == "" or not sec.contains("[img"):
			continue
		for r in def.offerings:
			t.check(not sec.contains((r as OfferingRule).short_name()), "%s：不写「%s」" % [id, (r as OfferingRule).short_name()])
		t.eq(sec.count("[cell][center][img"), def.offerings.size(), "%s：一条规矩一组图标" % id)
		for r in def.offerings:
			var mult := "[color=@faith]×%s[/color]" % TextTemplate.num((r as OfferingRule).multiplier)
			t.check(sec.contains("[center]%s[/center]" % mult), "%s：图标下写 %s" % [id, mult])

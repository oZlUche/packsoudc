extends RefCounted

const Buffs := preload("res://tests/run/test_run_buffs.gd")
const Erosion := preload("res://tests/run/test_erosion.gd")


static func frame_status_width(t: TestCase, root: Window) -> void:
	t.begin("顶栏状态槽 · 英文多项科技与限时状态；侵蚀前与推进后；大字、悬停、宽窄切换")
	var lang := UiText.lang
	UiText.lang = "en"
	var old_size := UiTheme.text_size
	UiTheme.set_text_size(&"large")
	UiTheme.refresh()
	UiTheme.install()
	var c := Buffs._content()
	var diff := Erosion._difficulty(3, 4, 1, [])
	var run := RunState.start(c.chapter, 41, c.items, c.enemies, c.sets, Buffs._kit(c).items, c.buffs,
			[&"tech_thorough_search_2", &"tech_endurance_1"] as Array[StringName], null, [], diff)
	var mod := BuffModule.of(run)
	t.check(mod.grant(&"marked") and mod.grant(&"weakened"), "正式状态模块实际授予永久与限时状态")
	var buffs = HudWidgets.create(&"buffs")
	var erosion = HudWidgets.create(&"erosion")
	for w in [buffs, erosion]:
		root.add_child(w)
		w.setup(run, null)
		w.set_in_bar(true)
	var size_before: int = buffs._text.get_theme_font_size("font_size")
	var all_text: String = buffs.text_of()
	buffs.fit_bar_width(175)
	t.eq(buffs.text(), all_text, "保留完整读数的查询")
	t.eq(buffs._text.text, "Effects: 4", "英文大字窄槽显示项数")
	t.check(buffs.tooltip_text.contains("Thorough Search (Tech)") and buffs.tooltip_text.contains("Weakened (5 steps left)"), "悬停有科技完整名和限时作用的剩余步数")
	t.check(buffs.get_combined_minimum_size().x <= 175 and buffs._text.get_theme_font_size("font_size") == size_before, "摘要实际尺寸在预算内，字级不变")
	mod.tick()
	t.check(buffs.tooltip_text.contains("4 steps left"), "状态时限变化后悬停读数刷新")
	buffs.fit_bar_width(1100)
	t.eq(buffs._text.text, buffs.text(), "够宽时完整显示")
	buffs.fit_bar_width(175)
	buffs.set_in_bar(false)
	t.eq(buffs._text.text, buffs.text(), "离开顶栏后解除收纳")
	t.check(buffs.tooltip_text.is_empty() and buffs.mouse_filter == Control.MOUSE_FILTER_IGNORE, "离栏恢复原来的鼠标行为")
	erosion.fit_bar_width(erosion.bar_reserve_width())
	t.check(erosion._text.text.contains("3") and erosion.tooltip_text.contains("starts in 3 steps"), "侵蚀开始前的完整与摘要步数")
	var field := run.travel.erosion
	run.travel.clock.total = field.next_at_action
	field.on_action(run.travel.clock, run.map)
	erosion.fit_bar_width(erosion.bar_reserve_width())
	t.check(erosion._text.text.contains("1") and erosion._text.text.contains("4") and erosion.tooltip_text.contains("next in 4 steps"), "实际推进后摘要保留档数与距下档的步数")
	for w in [buffs, erosion]:
		w.free()
	var host := HudHost.new()
	root.add_child(host)
	host.setup(run, null, HudLayout.default_for("map"))
	var active_buffs := host.widget(&"buffs")
	var active_erosion := host.widget(&"erosion")
	for width in [1600, 1280, 1000]:
		host.size = Vector2(width, 800)
		host.arrange()
		var dial_rect := host.rect_of(&"countdown")
		t.check(dial_rect.has_area(), "中央日晷可见")
		t.check(active_buffs.get_rect().end.x + HudHost.GAP <= dial_rect.position.x
				and active_erosion.get_rect().end.x + HudHost.GAP <= dial_rect.position.x, "%d 宽度：两个状态槽均未侵入日晷" % width)
		t.check(not active_buffs.get_rect().intersects(active_erosion.get_rect()), "%d 宽度：状态与侵蚀不互压" % width)
	host.free()
	run.dispose()
	UiTheme.set_text_size(old_size)
	UiTheme.refresh()
	UiText.lang = lang

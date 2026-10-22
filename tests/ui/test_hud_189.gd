## 189 / 190（作者 2026-10-18 定案：「乙的整体风格，但是倒计时要换成日晷样式」「去掉数字倒计时，而是设计成鼠标移动上去时出现悬浮窗」
## 「日晷记住要刻上去的，而不是额外的部件」）：倒计时 = 半圆日规，栏上没有数字，停上去弹「倒计时」悬浮窗。
## 长槽与铜点在 235 丙款栏皮里退役（栏皮与两头见 test_topbar_235）
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const Support := preload("res://tests/run/flow_support.gd")
const HOST_SIZE := Vector2(1600, 1000)


## 有悬浮窗的屏（组件从 `screen._tip` 取窗）
class FakeScreen:
	extends Control
	var _tip: HoverTip


static func _run() -> RunState:
	var c := CS._content()
	return CS._start(c, CS._character(c, &"marcus"))


## 默认布局，左槽第二行的小字先藏掉（只看第一行与槽身对齐）
static func _host(root: Window, run: RunState, screen: Control = null) -> HudHost:
	var layout := HudLayout.default_for("map")
	for id in [&"encumbrance", &"buffs", &"erosion", &"distances"]:
		layout.entry_of(id)["visible"] = false
	var host := HudHost.new()
	host.size = HOST_SIZE
	root.add_child(host)
	host.setup(run, screen, layout)
	host.arrange()
	return host


static func run_dial(t: TestCase) -> void:
	t.begin("190 · 日规：阶段按剩余（过半 calm、不过半 half、不到四分之一或只剩五步 low）；角度 = 180 − 180 × 用掉的比例；栏上不写数字；小档缩一半；缺图退回文字")
	var run := _run()
	if run == null:
		t.check(false, "开不了局")
		return
	var cdm := CountdownModule.of(run)
	t.check(cdm != null and cdm.has_countdown(), "这一局有倒计时")
	if cdm == null or not cdm.has_countdown():
		return
	var lim := cdm.limit()
	var w = HudWidgets.create(&"countdown")
	w.setup(run, null)
	t.check(w.has_dial(), "日规五张图都在")
	var cases := [[int(round(lim * 77.0 / 90.0)), &"calm"], [int(round(lim * 40.0 / 90.0)), &"half"], [int(round(lim * 15.0 / 90.0)), &"low"], [5, &"low"]]
	for cs in cases:
		run.travel.clock.total = lim - int(cs[0])
		w.refresh()
		t.eq(w.stage(), cs[1], "剩 %d / %d：%s" % [cs[0], lim, cs[1]])
	run.travel.clock.total = lim - int(round(lim * 77.0 / 90.0))
	var want := 180.0 - 180.0 * (1.0 - float(cdm.left()) / float(lim))
	t.check(absf(w.angle() - want) < 0.01, "角度 %.1f°（77/90 ≈ 154°）" % w.angle())
	w.refresh()
	t.check(not w.get("_text").visible and RegEx.create_from_string("\\d").search(w.text()) == null, "栏上不写数字（%s）" % w.text())
	t.check(w.has_content(), "有倒计时：显示")
	w.set_tier(HudWidget.Tier.LARGE)
	t.eq(w.custom_minimum_size, Vector2(104, 52) + w.get_theme_stylebox("panel").get_minimum_size(), "大档 104 × 52（加底的内边距）")
	w.set_tier(HudWidget.Tier.SMALL)
	t.eq(w.custom_minimum_size, Vector2(52, 26) + w.get_theme_stylebox("panel").get_minimum_size(), "小档缩一半")
	w.free()
	# 缺图：退回文字
	var root_dir := UiTheme.asset_root
	UiTheme.asset_root = "res://no/such/dir/"
	UiTheme._art_cache.clear()
	var plain = HudWidgets.create(&"countdown")
	plain.setup(run, null)
	t.check(not plain.has_dial() and plain.text().begins_with("倒计时 %d / %d" % [cdm.left(), lim]), "缺日规图：退回「倒计时 N / M」（%s）" % plain.text())
	plain.free()
	UiTheme.asset_root = root_dir
	UiTheme._art_cache.clear()


static func frame_dial_tip(t: TestCase, root: Window) -> void:
	t.begin("190 · 日规的悬浮窗：「倒计时」/「倒计时还剩 N（共 M）」/「最近的撤离点倒计时剩 K 时关闭」（关了写「已关闭」；193 补充一）；N 随阶段换样式、不写十六进制；开着时走一步字跟着变")
	var run := _run()
	if run == null:
		t.check(false, "开不了局")
		return
	var cdm := CountdownModule.of(run)
	var screen := FakeScreen.new()
	screen.size = HOST_SIZE
	root.add_child(screen)
	screen._tip = HoverTip.new()
	screen.add_child(screen._tip)
	var host := _host(root, run, screen)
	var w = host.widget(&"countdown")
	var lim := cdm.limit()
	run.travel.clock.total = lim - int(round(lim * 40.0 / 90.0))
	w.refresh()
	var closing := cdm.closing_extract_id()
	w.open_tip()
	var tip: HoverTip = screen._tip
	t.check(tip.is_showing(), "停上去：开窗")
	var shown := Glossary.strip_bbcode(tip.text()).replace("\n", " / ")
	t.check(shown.contains("倒计时") and shown.contains("倒计时还剩 %d（共 %d）" % [cdm.left(), lim]), "两行字：%s" % shown)
	var body := String(w.tip_parts()["body"])
	t.check(body.contains("[color=@stamina]%d[/color]" % cdm.left()) and not body.contains("[color=#"), "不过半：数字走 stamina 样式、没有十六进制")
	if closing >= 0:
		var at := PaidExtracts.closes_at(run.map.get_node(closing))
		run.travel.clock.total = lim - (at + 12)
		w.refresh()
		t.check(Glossary.strip_bbcode(tip.text()).contains("最近的撤离点倒计时剩 %d 时关闭" % at), "撤离点倒计时剩 %d 时关闭：%s" % [at, Glossary.strip_bbcode(tip.text()).replace("\n", " / ")])
		run.travel.clock.total = lim - at
		w.refresh()
		t.check(Glossary.strip_bbcode(tip.text()).contains("最近的撤离点已关闭"), "关了：%s" % Glossary.strip_bbcode(tip.text()).replace("\n", " / "))
	else:
		t.check(not w.tip_plain().contains("撤离点"), "没有限时撤离点：只有一行")
	run.travel.clock.total = lim - 3
	w.refresh()
	t.check(Glossary.strip_bbcode(tip.text()).contains("倒计时还剩 3（") and String(w.tip_parts()["body"]).contains("[color=@hp]3[/color]"), "开着时走到倒计时剩 3：字跟着变、数字走 hp 样式")
	w.close_tip()
	host.queue_free()
	screen.queue_free()

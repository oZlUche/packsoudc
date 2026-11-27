## 作者 11-27（确认清单 85 A / 86 OK）：状态与委托合成地图左上一块深石板，两节各自可收起（收起只剩「状态 N」「委托 x / y」）、
## 收起记在设置里；没内容的节不显示、都没有整块不显示；经验值条上缘贴着栏石面下沿，栏里多一行也不往下掉
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const Slate := preload("res://ui/hud/widgets/status_slate_widget.gd")


class FakeFlow:
	extends RefCounted
	var settings := GameSettings.new()
	var saved := 0

	func save_settings() -> void:
		saved += 1


class FakeScreen:
	extends Control
	var flow := FakeFlow.new()
	var _tip: HoverTip = null


static func run_split(t: TestCase) -> void:
	t.begin("11-27 · 状态名字末尾括号里的来源拆到右边")
	t.eq(Array(Slate.split_source("耐久（科技）")), ["耐久", "科技"], "全角括号")
	t.eq(Array(Slate.split_source("Hauling (Tech)")), ["Hauling", "Tech"], "半角括号")
	t.eq(Array(Slate.split_source("迅捷")), ["迅捷", ""], "没括号：右边空")


static func frame_slate(t: TestCase, root: Window) -> void:
	t.begin("11-27 · 左上石板：状态 / 委托两节、各自收起并记进设置、没内容不显示")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	run.meta_buffs.clear()
	var screen := FakeScreen.new()
	root.add_child(screen)
	var host := HudHost.new()
	host.size = Vector2(1600, 900)
	screen.add_child(host)
	host.setup(run, screen, HudLayout.default_for("map"))
	host.arrange()
	var slate = host.widget(&"status_slate")
	t.not_null(slate, "石板造出来了")
	if slate == null:
		screen.free()
		return
	t.check(not slate.visible, "没有状态也没带委托：整块不显示")
	# 状态：一条局外的（名字带「（科技）」），一条局内有时限的
	var tech_id := &""
	var timed_id := &""
	for id_ in run.buff_defs:
		var d: RunBuffDef = run.buff_defs[id_]
		if tech_id == &"" and d.is_meta() and Names.of(d).ends_with("）"):
			tech_id = id_
		if timed_id == &"" and d.is_map() and d.duration_steps > 0:
			timed_id = id_
	t.check(tech_id != &"" and timed_id != &"", "找到一条科技 buff（%s）和一条有时限的地图 buff（%s）" % [tech_id, timed_id])
	run.meta_buffs.append(tech_id)
	BuffModule.of(run).grant(timed_id)     # 发信号：石板自己刷
	t.check(slate.visible, "有状态：石板显示")
	var rows: Array[String] = slate._status.row_texts()
	t.eq(rows.size(), 2, "状态两行")
	var tech_name := Slate.split_source(Names.of(run.buff_defs[tech_id]))
	t.eq(rows[0], "%s|%s" % [tech_name[0], tech_name[1]], "科技那条：名字在左、来源在右")
	t.eq(rows[1], "%s|%s" % [Slate.split_source(Names.of(run.buff_defs[timed_id]))[0], UiText.t("hud.slate_left") % run.buff_defs[timed_id].duration_steps], "有时限的：右边「剩 N 步」")
	t.check(not slate._comm.visible and not slate._dash.visible, "没带委托：委托节和虚线不显示")
	# 委托
	var cm := CommissionModule.of(run)
	cm.tracked = [{"id": "cartographers_verify_vein", "stage": 0, "pick": "", "done": 0}] as Array[Dictionary]
	cm.progressed.emit(&"cartographers_verify_vein", 0, false)
	t.check(slate._comm.visible and slate._dash.visible, "带了委托：委托节和虚线显示")
	t.eq(slate._comm.count_l.text, UiText.t("commission.progress") % [0, 1], "委托标题后面「已办成 / 带了几条」")
	t.eq(slate._comm.row_texts().size(), 1, "委托一行")
	t.check(not slate._status.count_l.visible, "状态节展开时标题后面不写数")
	# 收起状态节
	var flow: FakeFlow = screen.flow
	slate._status.knob.pressed.emit()
	t.check(not flow.settings.status_open and flow.saved == 1, "点圆钮：状态节收起、记进设置并存了")
	t.check(not slate._status.rows.visible and slate._status.count_l.visible, "收起：行藏起来，标题后面写条数")
	t.eq(slate._status.count_l.text, "2", "「状态 2」")
	t.check(slate._comm.rows.visible, "委托节不受影响")
	slate._comm.knob.pressed.emit()
	t.check(not flow.settings.commissions_open, "委托节也收起")
	t.eq(slate.text(), "%s 2\n%s %s" % [UiText.t("hud.slate_status"), UiText.t("hud.slate_commissions"), UiText.t("commission.progress") % [0, 1]], "两节都收起：只剩两行标题")
	t.check(GameSettings.from_dict(flow.settings.to_dict()).status_open == false, "收起存进设置文件读回来还是收着（下一局照旧）")
	# 新的一块（下一局）照设置
	var host2 := HudHost.new()
	host2.size = Vector2(1600, 900)
	screen.add_child(host2)
	host2.setup(run, screen, HudLayout.default_for("map"))
	t.check(not host2.widget(&"status_slate")._status.rows.visible, "重新造：照设置收着")
	slate._status.knob.pressed.emit()
	t.check(flow.settings.status_open and slate._status.rows.visible, "再点：展开")
	screen.free()


static func frame_xp_flush(t: TestCase, root: Window) -> void:
	t.begin("11-27（86 OK）· 经验值条上缘贴着栏石面下沿；栏里多一行（侵蚀）也不往下掉")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var host := HudHost.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	host.setup(run, null, HudLayout.default_for("map"))
	host.arrange()
	var xp := host.widget(HudLayout.XP_BAR)
	var stone := load("res://ui/hud/widgets/hud_bar.gd").design_height() as float
	t.eq(xp.position.y, stone, "经验值条的上缘 = 栏石面高 %d" % int(stone))
	host.free()

## 222（作者 2026-10-21 13:05：「出发前有提示，空手也可以进战斗，就是正常结算（纯挨打）」）：
## 开局屏棋盘上一件会出手的都没有 —— 「出发」上面常显一句接应者的话，不拦；战前屏「开战」不再灰，空手照常打、照常按打输结算
extends RefCounted

const Setup := preload("res://tests/ui/test_setup_180.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "unarmed_222"


static func frame_unarmed(t: TestCase, root: Window) -> void:
	t.begin("222 · 空棋盘：开局屏有提示、放上武器提示消失、照样能出发；战前屏「开战」可点、只提醒一句；空手打一场输掉、扣体力")
	var game = Setup._game(root, PREFIX)
	var flow: GameFlow = game.flow
	var setup = game.base()
	var hint := UiText.t("setup.unarmed")
	setup.show_page(1)
	setup.choose_preset(-1)     # 不带预设：只有角色的初始包
	t.check(setup.unarmed(), "不带预设：棋盘上没有会出手的")
	t.eq(setup.status_text(), hint, "「出发」上面一句提示")
	var armed := -1
	for i in flow.presets().size():
		setup.choose_preset(i)
		if not setup.unarmed():
			armed = i
			break
	t.check(armed >= 0, "有一套预设带着武器")
	t.eq(setup.status_text(), "", "放上武器：提示没了")
	setup.choose_preset(-1)
	setup.show_page(2)
	setup.set_run_seed(7)     # 固定一张图，测试不随种子变
	t.eq(setup.status_text(), hint, "第三页也常显")
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var ids: Array[int] = pv.entry_ids()
	t.check(not ids.is_empty() and setup.pick_spawn(ids[0]), "挑一个入口")
	setup.close_hint()
	t.check(Support.depart(setup), "空手照样出发（不二次确认）")
	var run := flow.run
	t.not_null(run, "开局了")
	if run == null:
		game.queue_free()
		Support.cleanup(PREFIX)
		return
	t.check(run.compile_player().active_items().is_empty(), "这一局真是空手")
	var map = game.base()
	if map.has_method("rules_open") and map.rules_open():
		map.close_rules()
	# 离得最近的战斗点或精英点（路上别的点照常过）
	var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
	var target := -1
	for nid in dist:
		if run.map.get_node(int(nid)).type in [&"battle", &"elite"] and int(nid) != run.travel.current_id and (target < 0 or int(dist[nid]) < int(dist[target])):
			target = int(nid)
	t.check(target >= 0 and Support.walk_to(flow, target, GameFlow.Screen.PREBATTLE), "走到一个战斗点（%d）" % target)
	var before := run.vitality.current
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备")
	if pre != null and pre.screen == GameFlow.Screen.PREBATTLE:
		t.eq(pre.can_start(), "", "空手也能开战")
		t.check(not pre._start_btn.disabled, "「开战」不灰")
		t.eq(pre._why.text, UiText.t("pre.no_attacker"), "只提醒一句")
		# 248：看得见的战斗 / 精英点，战前屏左下角一颗平的「退回」（作者 14:44 选丙「回头脚印」石键，字由代码写）
		var rb: IconButton = pre.retreat_button()
		t.check(rb != null and rb.art_label == UiText.t("pre.retreat") and rb.get_parent().get_index() == 0, "248：左下角有「退回」")
		if rb != null:
			t.check(rb.has_art() and rb.custom_minimum_size == Vector2(112, 40), "248：定稿石键图（112 × 40）")
			t.eq(rb.tooltip_text, UiText.t("pre.retreat_tip"), "248：悬浮说明照旧")
			t.eq(rb.art_label_rect, Rect2(36, 0, 72, 40), "248：字写在 json 的 text_rect 里")
			t.eq(rb.art_label_font_size(), 18, "248：「退回」18 号放得下")
			rb.art_label = "Fall back"
			var fs := rb.art_label_font_size()
			t.check(fs < 18 and UiPalette.cjk_font_bold().get_string_size("Fall back", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= 72.0, "248：英文放不下逐号缩（%d 号）" % fs)
			rb.art_label = UiText.t("pre.retreat")
		t.check(pre.start_battle(), "开战")
		t.check(not bool(flow.last_payload.get("won", true)), "纯挨打：输了")
		var result: BattleResult = flow.last_payload.get("result", null)
		t.check(result != null and not result.is_draw(), "对手照常打到底，不是平局")
		t.eq(int(run.tally["battles_lost"]), 1, "按打输结算：记一场败")
		t.check(run.vitality.current < before or run.events.losses_forgiven > 0 or run.is_over() or not run.events.pending_ransom.is_empty(),
			"扣了体力（%d → %d），或用掉了一次免罚，或等着求饶（256）" % [before, run.vitality.current])
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)

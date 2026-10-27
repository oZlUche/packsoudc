## 184（作者 2026-10-17 15:36 / 15:37）：小兵棋子立在节点正中、可走的路是行进的虚线墨路 + 定长墨环 +「计二步」签、
## 走一步镜头把人带回中央、拖出屏外时屏边有指向他的小棋子；图例「你」= 棋子、「出生」= 182 的小旗
extends RefCounted

const Setup := preload("res://tests/ui/test_setup_180.gd")
const Support := preload("res://tests/run/flow_support.gd")


## 第三页挑第一个入口出发，回地图屏
static func _map(root: Window, prefix: String) -> Node:
	var game = Setup._game(root, prefix)
	var setup = game.base()
	setup.show_page(2)
	setup.preview().size = Vector2(640, 600)
	setup.preview().finish()
	var ids: Array[int] = setup.preview().entry_ids()
	if not ids.is_empty():
		setup.pick_spawn(ids[0])
	Support.depart(setup)
	return game


static func frame_pawn_and_paths(t: TestCase, root: Window) -> void:
	t.begin("184 · 棋子立在节点正中、屏幕定长；可走的边有墨路、终点墨环；花两步的写「计二步」；旧的三角人标撤了")
	var game = _map(root, "pawn184a")
	var flow: GameFlow = game.flow
	var map = game.base()
	t.eq(map.screen, GameFlow.Screen.MAP, "进了地图屏")
	if map.screen != GameFlow.Screen.MAP:
		game.queue_free()
		return
	var view: MapView = map._view
	view.size = Vector2(1400, 900)
	var run: RunState = flow.run
	var here := run.travel.current_id
	t.eq(view.current_id, here, "人在出生点")
	t.not_null(UiTheme.art(UiTheme.ART_MAP_PAWN), "棋子图到位")
	var pawn := view.pawn_at()
	var pos := view.positions()
	t.check(not pawn.is_empty() and (pawn["at"] as Vector2).distance_to(view.to_screen(pos[here])) < 0.01, "棋子脚底对准节点圆心（不是节点底部）")
	var meta := UiTheme.art_meta(UiTheme.ART_MAP_PAWN)
	var r1 := view.pawn_rect(pawn["at"])
	t.check(absf(r1.size.y - MapView.PAWN_H) < 0.01, "显示高 %d 像素" % int(r1.size.y))
	var anchor: Array = meta.get("anchor", [20, 33])
	t.check(absf(r1.position.y + float(anchor[1]) * MapView.PAWN_H / 40.0 - (pawn["at"] as Vector2).y) < 0.01, "锚点 [20,33] 落在节点圆心，身子往上立")
	view.zoom = 0.3
	var small := view.pawn_rect(view.pawn_at()["at"])
	view.zoom = 2.0
	var big := view.pawn_rect(view.pawn_at()["at"])
	t.check(small.size.is_equal_approx(big.size), "缩放 0.3 与 2.0 下棋子一样大（%s / %s）" % [small.size, big.size])
	t.eq(MapView.END_RING_R, 28.0, "终点墨环半径是像素定长")
	view.focus(here)

	var moves := run.travel.available_moves()
	t.eq(view.reachable.keys().size(), moves.size(), "可走的点都标上了")
	t.check(moves.all(func(id: int) -> bool: return view.reachable.has(id) and view.reach_cost.has(id)), "每个可走目标都有花费")
	t.check(not view.has_method("_draw_player_marker"), "三角人标撤了")

	# 花两步的边：写「计二步」
	if not moves.is_empty():
		var target: int = moves[0]
		var e := MapNavigator.edge_for_step(run.map, here, target)
		var was := e.action_cost
		e.action_cost = 2
		map._after_move()
		var want := "计%s步" % MapView._han(int(view.reach_cost[target]))
		t.check(int(view.reach_cost[target]) >= 2 and view.tags_text().has(want), "花两步的写「%s」（%s）" % [want, view.tags_text()])
		e.action_cost = was
		map._after_move()
		t.check(not view.tags_text().any(func(s: String) -> bool: return s.begins_with("计")), "一步的不写")
	t.eq(MapView._han(3), "三", "步数用汉字")

	# 虚线：从节点边缘起到节点边缘止
	var line := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var cut := MapView._trim(line, 20.0, 20.0)
	t.check(cut.size() >= 2 and cut[0].is_equal_approx(Vector2(20, 0)) and cut[cut.size() - 1].is_equal_approx(Vector2(80, 0)), "墨路两头让开节点")

	# 图例：「你」是棋子，「出生」是小旗
	var legend = map.hud().widget(&"legend") if map.hud() != null else null
	if legend != null:
		legend.refresh()
		var names: Array[String] = legend.row_names()
		t.check(not names.is_empty() and names[0] == "你", "图例第一行「你」（%s）" % [names])
	t.not_null(UiTheme.art(UiTheme.ART_LEGEND_FLAG), "出生的小旗到位")
	game.queue_free()
	Support.cleanup("pawn184a")


static func frame_follow_and_offscreen(t: TestCase, root: Window) -> void:
	t.begin("184 · 跟镜头：人在中央三分之一里不动，出去了平移回来、缩放不动；拖出屏外屏边出现小棋子，点它回到自己；换屏淡入关着一步到位")
	var game = _map(root, "pawn184b")
	var flow: GameFlow = game.flow
	var map = game.base()
	if map.screen != GameFlow.Screen.MAP:
		t.check(false, "进了地图屏")
		game.queue_free()
		return
	var view: MapView = map._view
	view.size = Vector2(1400, 900)
	var here: int = flow.run.travel.current_id
	view.zoom = 1.5
	view.focus(here)
	var pan0 := view.pan
	t.check(not view.follow_current(false), "人在正中：不跟")
	t.eq(view.pan, pan0, "pan 没动")
	var safe := view.safe_rect()
	view.pan += Vector2(safe.size.x * 0.4, 0.0)     # 把人推到右边、出了中央三分之一（还在屏上）
	var z := view.zoom
	t.check(view.follow_current(false), "出了中央三分之一：跟")
	t.check(view.pan.distance_to(view.focus_pan(here)) < 0.5, "平移到让人落在中央")
	t.eq(view.zoom, z, "缩放不动")
	t.check(not view.following(), "淡入关着：没有补间，一步到位")

	# 作者 10-27：focus = 人在安全区正中；空格回正、按住锁住；走一步之后镜头不动（不再调 follow_current）
	view.focus(here)
	t.check(view.to_screen(view.positions()[here]).distance_to(view.safe_rect().get_center()) < 0.5, "回正：人在正中央")
	view.pan += Vector2(300.0, 120.0)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	map._unhandled_key_input(key)
	t.check(view.pan.distance_to(view.focus_pan(here)) < 0.5 or view.following(), "空格：回正")
	t.check(view.lock_on_player, "按住空格：锁住")
	var up := InputEventKey.new()
	up.keycode = KEY_SPACE
	map._unhandled_key_input(up)
	t.check(not view.lock_on_player, "松开空格：放开")
	view.stop_follow()
	view.pan = view.focus_pan(here)
	var inset0 := view.content_inset
	view.content_inset = Rect2(0.0, 40.0, 0.0, 400.0)     # 底下读数占得高：人落在安全区下边、屏幕上照样看得见
	view.pan = Vector2(700.0, 700.0) - (view.positions()[here] as Vector2) * view.zoom
	var sp := view.to_screen(view.positions()[here])
	t.check(sp.y > view.safe_rect().end.y and sp.y < view.size.y, "人在安全区下边、屏内")
	t.check(not view.offscreen_rect().has_area(), "人在屏上看得见：不出小棋子（作者 10-21：提示要贴着棋子）")
	view.content_inset = inset0
	view.pan = view.focus_pan(here)
	view.pan += Vector2(safe.size.x * 3.0, safe.size.y * 3.0)     # 拖到屏外
	var off := view.offscreen_rect()
	t.check(off.has_area(), "人出了屏：屏边出现指向他的小棋子")
	t.check(view.safe_rect().grow(1.0).encloses(off), "小棋子在安全区里")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = off.get_center()
	view.animate_moves = false
	view._gui_input(click)
	t.check(view.pan.distance_to(view.focus_pan(here)) < 0.5, "点它：回到自己")
	t.check(not view.offscreen_rect().has_area(), "回来了：小棋子收起（人 %s，可见区 %s，跟着 %s，size %s）" % [view.to_screen(view.positions()[here]), view.visible_rect(), view.following(), view.size])
	# 游戏测试 10-22：上下读数占得太多（安全区让不出一半）时，居中照样让开顶端栏，人不会落在栏底下
	var inset1 := view.content_inset
	view.content_inset = Rect2(0.0, 100.0, 0.0, 400.0)
	view.pan = view.focus_pan(here)
	t.check(view.visible_rect().has_point(view.to_screen(view.positions()[here])), "让不出一半：人照样在顶端栏下面看得见")
	t.check(not view.offscreen_rect().has_area(), "不出小棋子")
	view.content_inset = inset1

	# 跳：开着动画时从旧点弧线跳过去，跳的时候墨路先不画
	var moves := flow.run.travel.available_moves()
	if not moves.is_empty():
		view.animate_moves = true
		var from := here
		view.current_id = moves[0]
		view.hop_from(from)
		t.check(view.hopping(), "开着动画：在跳")
		view._hop["t"] = MapView.HOP_SEC * 0.5
		var mid: Vector2 = view.pawn_at()["at"]
		var a := view.to_screen(view.positions()[from])
		var b := view.to_screen(view.positions()[moves[0]])
		t.check(mid.y < (a.y + b.y) * 0.5 - MapView.HOP_LIFT * 0.9, "半程抬起来（上凸的弧）")
		t.eq(view.tags_text(), [] as Array[String], "跳的时候墨路与签先不画")
		view.finish_hop()
		t.check(not view.hopping() and (view.pawn_at()["at"] as Vector2).distance_to(b) < 0.01, "落在新节点正中")
		view.current_id = from
		view.animate_moves = false
		view.hop_from(moves[0])
		t.check(not view.hopping(), "动画关着：不跳，直接站上去")
	game.queue_free()
	Support.cleanup("pawn184b")


static func run_spawn_art_182(t: TestCase) -> void:
	t.begin("182 定稿美术：第三页入口是小旗三态、提示窗是纸签 + 上沿红蜡封")
	for state in ["_normal", "_hover", "_sel"]:
		t.not_null(UiTheme.art(UiTheme.ART_SPAWN_MARK + state), "小旗%s" % state)
	t.not_null(UiTheme.art(UiTheme.ART_NODE_HINT), "纸签底")
	t.not_null(UiTheme.art(UiTheme.ART_NODE_SEAL), "红蜡封")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_NODE_HINT), UiTheme.TONE_LIGHT, "纸签浅底墨字")
	var box := UiTheme.build().get_stylebox("panel", UiTheme.PANEL_NODE_HINT) as StyleBoxTexture
	t.check(box != null and box.texture == UiTheme.art(UiTheme.ART_NODE_HINT), "提示窗用纸签九宫格")

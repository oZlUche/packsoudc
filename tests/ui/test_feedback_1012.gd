## 2026-10-12 反馈小修：敌人道具写的位置摆不下（旧存档）自己找空位；地图进图缩放按点距定、玩家的缩放全局沿用。
extends RefCounted


static func run_enemy_stale_position(t: TestCase) -> void:
	t.begin("反馈 · 药师战前没短剑：写的位置摆不下（旧存档记着改形状前的位置）就自己找空位，不丢；查数据的 unplaced_items 照样报出来")
	var c := TestSupport.load_content()
	var content := {
		"board": [4, 3],
		"items": [
			{"id": "bag_leather", "at": [0, 0], "rot": 0},
			{"id": "antidote_kit", "at": [0, 0], "rot": 0},
			{"id": "shortsword", "at": [3, 2], "rot": 0},     # 出了棋盘：旧位置
		],
	}
	var board := EnemyKit.board_of(content, c.items)
	var ids := board.items().map(func(i) -> StringName: return (i as ItemInstance).def.id)
	t.check(ids.has(&"shortsword"), "短剑还在敌人棋盘上（%s）" % str(ids))
	t.check(ids.has(&"antidote_kit"), "解毒包也在")
	t.eq(EnemyKit.unplaced_items(content, c.items), [&"shortsword"] as Array[StringName], "查数据：照写的位置摆不下的是短剑")
	var strict := EnemyKit.board_of(content, c.items, false)
	t.check(not strict.items().any(func(i) -> bool: return (i as ItemInstance).def.id == &"shortsword"), "不找空位的版本确实摆不下")


static func run_map_zoom_setting(t: TestCase) -> void:
	t.begin("反馈 · 地图缩放存进设置：默认 0（自动）；存读一致；乱值夹进范围")
	var gs := GameSettings.new()
	t.eq(gs.map_zoom, 0.0, "默认自动")
	gs.map_zoom = 1.3
	t.eq(GameSettings.from_dict(gs.to_dict()).map_zoom, 1.3, "存读一致")
	t.eq(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION}).map_zoom, 0.0, "旧设置文件没这个键：自动")
	t.eq(GameSettings.normalize_zoom(-2.0), 0.0, "负数 = 自动")
	t.eq(GameSettings.normalize_zoom(99.0), 2.5, "太大夹到 2.5")
	t.eq(GameSettings.normalize_zoom(0.01), 0.3, "太小夹到 0.3")


static func frame_map_start_zoom(t: TestCase, root: Window) -> void:
	t.begin("反馈 · 进图缩放：自动按最短边定（相邻点在屏幕上至少隔 5 个节点半径，最多 1.5 倍），人在正中；给了玩家的缩放就用它；视图还没尺寸就等 resized")
	var g := RingMapGenerator.new().generate(RingMapConfig.sample(4), 2)
	var view := MapView.new()
	view.size = Vector2(800, 600)
	root.add_child(view)
	view.graph = g
	var gap := view.shortest_edge()
	t.check(gap > 0.0, "有最短边（%.0f）" % gap)
	view.fit()
	var whole := view.zoom
	var z := view.start_zoom()
	t.check(z >= whole - 0.001, "不比看全图更小（%.2f ≥ %.2f）" % [z, whole])
	t.check(z <= MapView.START_ZOOM_MAX + 0.001, "不超过 1.5（%.2f）" % z)
	t.check(gap * z >= MapView.START_GAP - 0.5 or is_equal_approx(z, MapView.START_ZOOM_MAX), "最短边在屏幕上够宽（%.0f px）" % (gap * z))
	var id: int = g.entry_ids[0]
	view.current_id = id
	view.open_at(0.0)
	t.eq(view.zoom, z, "没定过：用自动缩放")
	var on_screen := view.to_screen(view.positions()[id])
	var c := view.canvas_rect().size * view.zoom
	if c.x > view.size.x and c.y > view.size.y:
		t.check(Rect2(Vector2.ZERO, view.size).has_point(on_screen), "人所在的点在视图里（%s）" % on_screen)
	view.open_at(2.0)
	t.eq(view.zoom, 2.0, "玩家定过：照用")
	var seen: Array = []
	view.zoom_changed.connect(func(v: float): seen.append(v))
	view.zoom_at(Vector2(400, 300), 1.15)
	t.eq(seen.size(), 1, "滚轮缩放发 zoom_changed（游戏屏记进设置）")
	view.queue_free()

	var late := MapView.new()
	root.add_child(late)
	late.graph = g
	late.current_id = id
	late.open_at(1.2)
	late.size = Vector2(800, 600)
	t.eq(late.zoom, 1.2, "进图时还没尺寸：第一次 resized 时才定缩放")
	late.queue_free()


static func run_slab_text_ink(t: TestCase) -> void:
	t.begin("反馈 2026-10-13 · 浅石板上的富文本：亮橙、白色道具名换成够深的墨水版；深石板原样")
	var orange := Color("f0a040")
	var white := Color("e8e8e8")
	var text := "[color=#%s]先看对手[/color][color=#%s]长剑[/color]" % [orange.to_html(false), white.to_html(false)]
	var out := UiPalette.toned(text, UiTheme.tone_of(UiTheme.PANEL_OVERLAY))     # 169：统一入口
	if UiTheme.tone_of(UiTheme.PANEL_OVERLAY) == UiTheme.TONE_LIGHT:
		t.check(not out.contains(orange.to_html(false)) and not out.contains(white.to_html(false)), "浅石板：两种亮色都换掉了（%s）" % out)
		t.check(UiTheme.contrast(UiTheme.ink_color(orange), UiTheme.PAPER) >= UiTheme.MIN_CONTRAST, "橙色换成够深的版本")
		t.eq(UiTheme.ink_color(white), UiTheme.INK, "白色道具名 → 墨色")
	else:
		t.eq(out, text, "深石板：原样")

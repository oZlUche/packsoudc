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


static func frame_spawn_view(t: TestCase, root: Window) -> void:
	t.begin("作者 2026-10-16 · 开局视角：缩到所有出生点都装得下；出生点在图的哪一侧，屏上也偏哪一侧（另一侧多露地图）")
	var g := RingMapGenerator.new().generate(RingMapConfig.sample(4), 2)
	var view := MapView.new()
	view.size = Vector2(800, 600)
	root.add_child(view)
	view.graph = g
	var pos := view.positions()
	var ids: Array = pos.keys()
	var c := view.canvas_rect().size
	# 取画布右下那几个点当出生点
	ids.sort_custom(func(a, b) -> bool: return (pos[a] as Vector2).x + (pos[a] as Vector2).y > (pos[b] as Vector2).x + (pos[b] as Vector2).y)
	var spawns: Array = ids.slice(0, 2)
	view.current_id = -1
	view.open_at(2.5, spawns)
	t.check(view.zoom < 2.5, "从 2.5 缩下来才装得下（%.2f）" % view.zoom)
	view.open_at(1.0, spawns)     # 原比例：出生点那团比屏小，有地方偏
	var screen := Rect2(Vector2.ZERO, view.size)
	var mid := Vector2.ZERO
	for id in spawns:
		var s := view.to_screen(pos[id])
		t.check(screen.has_point(s), "出生点 %d 在屏里（%s）" % [id, s])
		mid += s / spawns.size()
	t.eq(view.zoom, 1.0, "装得下就不改缩放")
	var canvas_mid := Vector2.ZERO
	for id in spawns:
		canvas_mid += (pos[id] as Vector2) / spawns.size()
	if c.x * view.zoom > view.size.x and canvas_mid.x > c.x * 0.6:
		t.check(mid.x > view.size.x * 0.5, "出生点在图右边：屏上也偏右（%.0f）" % mid.x)
	if c.y * view.zoom > view.size.y and canvas_mid.y > c.y * 0.6:
		t.check(mid.y > view.size.y * 0.5, "出生点在图下边：屏上也偏下（%.0f）" % mid.y)
	view.queue_free()


static func frame_tip_leave_fast(t: TestCase, root: Window) -> void:
	t.begin("作者 2026-10-16 · 鼠标移开道具：往悬浮窗外走立刻收（宽限只留给往窗里去的）；停着不动等宽限过完")
	var c := TestSupport.load_content()
	var host := Control.new()
	host.size = Vector2(800, 600)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 3), 1)
	board.place(ItemInstance.create(c.items.get_def(&"knife")), Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2(300, 300)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	var on := InputEventMouseMotion.new()
	on.position = Vector2(4, 4)
	view.gui_input.emit(on)
	t.check(tip.is_showing(), "停在刀上：显示")
	view.mouse_exited.emit()
	var away := view.global_position + Vector2(-30, -30)     # 往左上走：悬浮窗在右下
	tip.tick(0.016, away)
	t.check(tip.is_showing(), "第一拍记下离窗多远")
	tip.tick(0.016, away + Vector2(-20, -20))
	t.check(not tip.is_showing(), "再往外走：不等宽限，立刻收")
	view.gui_input.emit(on)
	view.mouse_exited.emit()
	tip.tick(0.016, away)
	tip.tick(0.016, away)
	t.check(tip.is_showing(), "停着不动：还在宽限里")
	tip.tick(HoverTip.GRACE_SEC, away)
	t.check(not tip.is_showing(), "宽限过完收")
	t.eq(HoverTip.rect_distance(Rect2(0, 0, 10, 10), Vector2(13, 14)), 5.0, "点到矩形的距离")
	host.queue_free()


static func run_window_and_nameplate_art(t: TestCase) -> void:
	t.begin("作者 2026-10-16 · 背包浮窗是一整块深石板（不透明的板身）；名牌是铜牌、本身不透明；图读不出时脚注写字")
	t.check(UiTheme.VARIATIONS.has(UiTheme.PANEL_WINDOW), "浮窗变体登记了")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_WINDOW), UiTheme.tone_of(UiTheme.PANEL_OVERLAY), "和叠层石板同一种深浅")
	var theme := UiTheme.build()
	if UiTheme.has_slab():
		t.check(theme.get_stylebox("panel", UiTheme.PANEL_WINDOW) is SlabStyle, "浮窗：石板（板边 + 板身）")
	# 作者 2026-10-17：名牌改铜质狗牌 —— 铜板本身不透明，单层九宫格、不垫板身；深底亮字；内容从边距里开始（不压左上的穿链孔）
	var plate := theme.get_stylebox("panel", UiTheme.PANEL_NAMEPLATE) as StyleBoxTexture
	t.not_null(plate, "名牌：铜牌单层九宫格")
	if plate != null:
		var img := plate.texture.get_image()
		t.eq(img.get_pixel(img.get_width() / 2, img.get_height() / 2).a, 1.0, "铜牌中间不透明")
		t.eq([plate.content_margin_left, plate.content_margin_top], [22.0, 18.0], "内容从左上角穿链孔外面开始")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_NAMEPLATE), UiTheme.TONE_DARK, "深铜底：名字用亮色字")
	t.eq(UiTheme.tip_icon("no_such_icon", "值 "), "值 ", "没有图：写字")
	t.check(UiTheme.tip_icon("coin", "值 ").begins_with("[img"), "金币图读得出来：用图")


static func frame_tip_pin_on_source(t: TestCase, root: Window) -> void:
	t.begin("作者 2026-10-17 · 钉住看源：悬浮窗出来后鼠标还停在道具 / 关键词 / 别的源上满 0.6 秒就钉，不必先移进窗；钉住后在源上不算离开，源离开窗还留着，离开 0.4 秒才收")
	var c := TestSupport.load_content()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 3), 1)
	board.place(ItemInstance.create(c.items.get_def(&"poison_arrows")), Vector2i(0, 0), 0)
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
	var src := view.global_position + on.position
	t.check(tip.is_showing() and not tip._panel.global_rect().has_point(src), "停在道具上：出现（鼠标不在窗里）")
	tip.tick(0.3, src)
	t.check(not tip.is_pinned() and tip._panel.dwell > 0.0, "停在道具上 0.3 秒：进度在走、还没钉")
	tip.tick(0.31, src)
	t.check(tip.is_pinned(), "停在道具上满 0.6 秒：钉住")
	tip.tick(1.0, src)
	t.check(tip.is_showing(), "钉住后还在道具上：不收")
	var empty := InputEventMouseMotion.new()
	empty.position = Vector2(200, 160)
	view.gui_input.emit(empty)
	var far := Vector2(5, 880)
	tip.tick(0.2, far)
	t.check(tip.is_showing(), "离开道具 0.2 秒：钉住的窗还在")
	tip.tick(0.25, far)
	t.check(not tip.is_showing(), "源和窗都离开 0.4 秒：收")

	# 关键词：停在开子窗的词上也走子窗的钉住进度
	view.gui_input.emit(on)
	tip.tick(0.61, src)
	var terms: Dictionary = tip._panel.terms
	if not terms.is_empty():
		var inside := tip._panel.global_position + tip._panel.size * 0.5
		tip._panel.hover("term:" + String(terms.keys()[0]))
		tip.tick(0.3, inside)
		t.eq(tip.windows().size(), 2, "停在关键词上：开子窗")
		var child: HoverTip.TipWindow = tip.windows()[1]
		tip.tick(0.61, inside)
		t.check(child.pinned, "还停在那个词上满 0.6 秒：子窗钉住（鼠标没进子窗）")
	tip.hide_tip()

	# 别的源（地图点、按钮）：show_text + release
	tip.show_text("地图上的点", Vector2(400, 400))
	tip.release()
	t.check(not tip.is_showing(), "没钉住就离开源：立刻收")
	tip.show_text("地图上的点", Vector2(400, 400))
	tip.tick(0.61, far)
	t.check(tip.is_pinned(), "源上停满：钉住")
	tip.show_text("别的点", Vector2(400, 400))
	t.eq(tip.text(), "地图上的点", "钉住的窗不被别的源换掉")
	tip.release()
	t.check(tip.is_showing(), "钉住后离开源：还在")
	tip.tick(0.45, far)
	t.check(not tip.is_showing(), "离开窗 0.4 秒：收")
	host.queue_free()


static func run_routes_hidden(t: TestCase) -> void:
	t.begin("作者 2026-10-17 · 挑出生点时的路线卡（风险 / 收益）对玩家隐藏：卡片不建，左下角那件跟着藏")
	var consts: Dictionary = (load("res://ui/game/map_screen.gd") as Script).get_script_constant_map()
	t.eq(consts.get("SHOW_ROUTES", true), false, "路线卡关着")


static func run_map_no_backdrop_rings(t: TestCase) -> void:
	t.begin("作者 2026-10-17 · 局内地图不画不是路的同心圆（布局底纹默认关，地图编辑器才开）")
	var view := MapView.new()
	t.check(not view.show_backdrop, "默认不画底纹")
	view.free()

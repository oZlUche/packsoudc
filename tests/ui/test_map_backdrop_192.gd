## 192（191 甲，作者 2026-10-18「实施」）：地图底图钉在画布上 —— 按 json 的 `safe_area` 把底图对准路网画布，之后和路、点一起缩放平移；
## 看全图 = 整张纸刚好装进安全区；拖动时纸的任何一边不越过安全区中心线；开局第三页的预览和局内第一帧是同一张纸、同一大小
extends RefCounted
const Support := preload("res://tests/run/flow_support.gd")

const Setup := preload("res://tests/ui/test_setup_180.gd")
const VIEW_SIZE := Vector2(1600, 1000)


static func _near(a: Rect2, b: Rect2, tol: float = 1.0) -> bool:
	return a.position.distance_to(b.position) <= tol and a.size.distance_to(b.size) <= tol


static func run_skin_geometry(t: TestCase) -> void:
	t.begin("192 · safe_area：写了四个数原样读；一句话 / 缺 = 默认中间 80% × 72%；paper_rect 把安全区放大到盖住画布、中心对齐")
	t.eq(MapSkin.safe_rect(&"ruins"), Rect2(192, 168, 1536, 864), "遗迹：json 的四个数")
	t.eq(MapSkin.logical_size(&"ruins"), Vector2(1920, 1200), "逻辑尺寸按 json 的 size")
	var keep := MapSkin.root
	var dir := "user://test_map_backdrop_192/"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.5, 0.4))
	img.save_png(dir + "t192.png")
	var f := FileAccess.open(dir + "t192.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"size": [1920, 1200], "safe_area": "中间约 80% × 72% 的椭圆"}))
	f.close()
	MapSkin.root = dir
	t.check(_near(MapSkin.safe_rect(&"t192"), Rect2(192, 168, 1536, 864), 0.01), "还是一句话：按默认")
	DirAccess.remove_absolute(dir + "t192.json")
	t.eq(MapSkin.logical_size(&"t192"), Vector2(8, 8), "没 json：按贴图尺寸")
	t.check(_near(MapSkin.safe_rect(&"t192"), Rect2(0.8, 1.12, 6.4, 5.76), 0.001), "没 json：默认比例（%s）" % MapSkin.safe_rect(&"t192"))
	MapSkin.root = keep
	DirAccess.remove_absolute(dir + "t192.png")
	var paper := MapSkin.paper_rect(&"ruins", Rect2(0, 0, 1000, 1000))
	var s := 1000.0 / 864.0
	t.check(_near(paper, Rect2(Vector2(500, 500) - Vector2(960, 600) * s, Vector2(1920, 1200) * s), 0.01), "画布 1000²：s = 1000 / 864，纸 %.0f × %.0f" % [paper.size.x, paper.size.y])
	t.check(paper.get_center().distance_to(Vector2(500, 500)) < 0.01, "纸的中心 = 画布中心")
	t.eq(MapSkin.paper_rect(&"no_such_map", Rect2(0, 0, 1000, 1000)), Rect2(), "没这张图：空矩形")
	t.eq(MapSkin.paper_rect(&"ruins", Rect2()), Rect2(), "画布没面积：空矩形")
	t.eq(RingLayoutBase.canvas_side(4), 2.0 * (4.0 * RingLayoutBase.RING_STEP + RingLayoutBase.MARGIN), "画布边长按环数算")


static func _view(root: Window, skin: StringName = &"ruins") -> MapView:
	var view := MapView.new()
	view.size = VIEW_SIZE
	root.add_child(view)
	view.skin = skin
	view.graph = RingMapGenerator.new().generate(RingMapConfig.sample(4), 2)
	return view


static func frame_view_camera(t: TestCase, root: Window) -> void:
	t.begin("192 · 地图视图：纸随底图 / 图更新；看全图 = 纸刚好装进安全区；滚轮围着鼠标缩放那一点不动；拖到头纸边停在安全区中心线；没底图照旧")
	var view := _view(root)
	view.content_inset = Rect2(40, 100, 60, 120)
	var paper := view.paper()
	t.check(paper.has_area(), "有底图有图：有纸")
	t.check(_near(paper, MapSkin.paper_rect(&"ruins", view.canvas_rect()), 0.01), "纸 = paper_rect(底图, 画布)")
	t.check(paper.encloses(view.canvas_rect()), "纸盖住整张画布")
	view.fit()
	t.check(is_equal_approx(view.zoom, view.zoom_min()), "看全图：缩放 = 下限（%.3f）" % view.zoom)
	var safe := view.safe_rect()
	var on := view.paper_on_screen()
	t.check(safe.grow(1.0).encloses(on), "纸在安全区里（%s ⊂ %s）" % [on, safe])
	t.check(absf(on.size.x - safe.size.x) <= 1.0 or absf(on.size.y - safe.size.y) <= 1.0, "有一边刚好贴满")
	t.check(on.get_center().distance_to(safe.get_center()) <= 1.0, "纸居中")
	view.zoom_at(safe.get_center(), 1.0 / 1.15)
	t.check(is_equal_approx(view.zoom, view.zoom_min()), "再往小缩：停在下限")
	var at := safe.get_center() + Vector2(120, -60)
	var before := view.to_canvas(at)
	view.zoom_at(at, 1.15)
	view.zoom_at(at, 1.15)
	t.check(view.to_canvas(at).distance_to(before) < 0.01, "围着 (%.0f, %.0f) 放大：纸上那一点不动" % [at.x, at.y])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	view._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(5000, 0)
	view._gui_input(drag)
	t.check(absf(view.paper_on_screen().position.x - safe.get_center().x) <= 1.0, "往右拖 5000：纸的左边停在安全区中心 x（%.1f / %.1f）" % [view.paper_on_screen().position.x, safe.get_center().x])
	drag.relative = Vector2(0, 5000)
	view._gui_input(drag)
	t.check(absf(view.paper_on_screen().position.y - safe.get_center().y) <= 1.0, "往下拖 5000：纸的上边停在安全区中心 y")
	drag.relative = Vector2(-20000, -20000)
	view._gui_input(drag)
	t.check(absf(view.paper_on_screen().end.x - safe.get_center().x) <= 1.0 and absf(view.paper_on_screen().end.y - safe.get_center().y) <= 1.0, "往左上拖到头：右边、下边停在中心线")
	press.pressed = false
	view._gui_input(press)
	view.skin = &"cursed_depths"
	t.check(_near(view.paper(), MapSkin.paper_rect(&"cursed_depths", view.canvas_rect()), 0.01), "换底图：纸跟着换")
	view.skin = &""
	t.eq(view.paper(), Rect2(), "没底图：空矩形")
	t.eq(view.zoom_min(), MapView.ZOOM_MIN, "没底图：下限照旧 0.3")
	var c := view.canvas_rect().size
	view.fit()
	t.check(is_equal_approx(view.zoom, clampf(minf(view.safe_rect().size.x / c.x, view.safe_rect().size.y / c.y), MapView.ZOOM_MIN, 1.0)), "没底图：看全图照旧按画布")
	view.skin = &"ruins"
	view.graph = RingMapGenerator.new().generate(RingMapConfig.sample(6), 3)
	t.check(_near(view.paper(), MapSkin.paper_rect(&"ruins", view.canvas_rect()), 0.01), "换图：纸跟着画布变")
	view.size = VIEW_SIZE * 1.5
	t.check(view.zoom >= view.zoom_min() - 0.0001, "窗口变大：缩放不低于新的下限")
	view.queue_free()


static func frame_preview_matches_reveal(t: TestCase, root: Window) -> void:
	t.begin("192 §5 · 第三页预览上的纸 = 入局第一帧地图上的纸（同一大小、同一位置，含 182 的微放大）—— 转场不跳")
	var was := GameDirector.fades_allowed
	GameDirector.fades_allowed = true
	var game = Setup._game(root, "map192")
	game.flow.settings.ui_fades = true
	var setup = game.base()
	setup.show_page(2)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	t.check(pv.paper_on_screen().has_area(), "预览有纸")
	var ids: Array[int] = pv.entry_ids()
	if not ids.is_empty():
		setup.pick_spawn(ids[0])
	pv.finish()
	setup.close_hint()
	var zoom_p := pv.ring_gap() / RingLayoutBase.RING_STEP
	var want_paper := MapSkin.paper_rect(pv.skin, Rect2(Vector2.ZERO, Vector2.ONE * RingLayoutBase.canvas_side(pv.levels)))
	t.check(absf(pv.paper_on_screen().size.x - want_paper.size.x * zoom_p * pv.view_zoom) < 0.01, "纸的大小 = 画布里的纸 × 圈距 ÷ 环距 × 微放大")
	var from: Rect2 = pv.get_global_transform() * pv.paper_on_screen()
	t.check(Support.depart(setup), "出发")
	var map = game.base()
	var view: MapView = map._view
	t.check(map.revealing(), "在转场")
	var to: Rect2 = view.get_global_transform() * view.paper_on_screen()
	t.check(_near(from, to), "第一帧的纸和预览上的纸重合（%s / %s）" % [from, to])
	GameDirector.fades_allowed = was
	game.queue_free()

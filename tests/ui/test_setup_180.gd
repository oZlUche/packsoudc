## 180（作者 2026-10-17 09:05）：开局第二页减文案；第三页 左 地图 / 规模两级列表 | 中 晕开的地图预览 | 右 摘要 + 当前难度（加减、红字挑战）；
## 序章不进列表；种子玩家看不见（调试台可指定下一局）；上次的图 / 规模 / 难度记在局外旗标里
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const Support := preload("res://tests/run/flow_support.gd")


static func _game(root: Window, prefix: String, unlock_all: bool = true) -> Node:
	Support.cleanup(prefix)
	var p := Support.paths(prefix)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	if unlock_all:
		for d in flow.difficulties:
			if d.requires_unlock != &"":
				flow.meta.grant_unlock(d.requires_unlock)
	flow.new_run()
	return game


static func _texts(n: Node) -> Array[String]:
	var out: Array[String] = []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	for c in n.find_children("*", "Button", true, false):
		out.append((c as Button).text)
	for c in n.find_children("*", "RichTextLabel", true, false):
		out.append((c as RichTextLabel).get_parsed_text())
	return out


static func frame_kit_page_text(t: TestCase, root: Window) -> void:
	t.begin("180 · 第二页减文案：仓库标题只写页数、没有「往左边的包里拖……」；棋盘标题「行囊　名字　N × M 格」；读数只有负重与带入预算两行")
	var game = _game(root, "setup180a")
	var setup = game.base()
	setup.show_page(1)
	var texts := _texts(setup._pages[1])
	t.check(not texts.any(func(s: String) -> bool: return s.contains("往左边") or s.contains("撤离了回来")), "没有那句说明")
	t.check(texts.any(func(s: String) -> bool: return s.begins_with("仓库　") and s.ends_with("页") and not s.contains("件")), "仓库标题只写页数")
	var ch: CharacterDef = setup.character()
	t.check(texts.has("行囊　%s　　%d × %d 格" % [Names.of(ch), ch.board_size.x, ch.board_size.y]), "棋盘标题")
	t.check(not texts.any(func(s: String) -> bool: return s.contains("已带") or s.contains("带上")), "没有「已带」「带上」")
	var readout: String = setup._readout.get_parsed_text()
	t.check(readout.contains("负重") and readout.contains("带入预算") and readout.get_slice_count("\n") == 2, "两行：%s" % readout)
	game.queue_free()
	Support.cleanup("setup180a")


static func frame_map_page(t: TestCase, root: Window) -> void:
	t.begin("180 · 第三页：序章不进地图列表；选中的图下面展开规模（「小型」+ 右边小字「4~5 环　36 步」）；没有种子框、没有「默认（章节配置）」；预览按真生成的环数画圈、半径按规模")
	var game = _game(root, "setup180b")
	var flow: GameFlow = game.flow
	var setup = game.base()
	t.check(setup.map_chapters().all(func(c: ChapterDef) -> bool: return c.hidden_by_unlock == &""), "列表里没有教程章")
	t.check(not setup.map_chapters().is_empty(), "至少有一张图")
	for tut in flow.tutorial_chapters():
		t.check(not setup.map_chapters().has(tut), "教程章 %s 永远不列（只出现一次）" % tut.id)
	setup.show_page(2)
	var c: ChapterDef = setup.chapter()
	t.eq(Names.of(c), "魔法废墟", "图的名字")
	t.eq(c.map_skin, &"ruins", "魔法废墟铺遗迹的底图")
	var opts: Array = setup.scale_options()
	t.eq(opts, [&"small", &"medium", &"large"] as Array, "三档规模展开在下面")
	t.eq(setup.scale_id, &"small", "默认第一档")
	var sb: Button = setup._scale_btns[&"small"]
	t.eq(sb.text, "小型", "名字不带括号")
	var note := sb.get_child(0) as Label
	t.check(note != null and note.text == "4~5 环　36 步", "右边小字（%s）" % (note.text if note != null else "?"))
	t.check(not (setup._scale_btns[&"large"] as Button).text.contains("占位"), "大型去掉「（占位）」")
	var texts := _texts(setup._pages[2])
	t.check(not texts.any(func(s: String) -> bool: return s.contains("种子") or s.contains("默认（章节配置）") or s.contains("自由模式")), "没有种子、默认项、自由模式")
	t.eq(setup._pages[2].find_children("*", "SpinBox", true, false).size(), 0, "没有种子框")

	var pv: MapPreview = setup.preview()
	t.not_null(pv, "中间是预览")
	pv.finish()
	t.eq(pv.skin, c.map_skin, "预览铺这张图的底")
	t.eq(pv.levels, setup.ring_levels(c, &"small"), "圈数 = 真生成的环数")
	t.check(pv.levels >= 4 and pv.levels <= 5, "小型 4~5 环（%d）" % pv.levels)
	t.check(is_equal_approx(pv.radius_frac, MapPreview.RADIUS_BY_SCALE[&"small"]), "小型半径 0.55")
	t.check((pv.material as ShaderMaterial).shader.resource_path.ends_with("ink_reveal.gdshader"), "墨化开的着色器")
	var g := c.map_source.resolve(setup.run_seed, &"small")
	t.eq(RingMapLayout.ring_count_of(g), pv.levels, "同一个种子再生成一遍，环数一样（确定性）")
	setup.choose_scale(&"large")
	pv.finish()
	t.check(pv.levels >= 9 and is_equal_approx(pv.radius_frac, MapPreview.RADIUS_BY_SCALE[&"large"]), "大型：圈多、几乎铺满（%d 环）" % pv.levels)
	t.check(pv.ring_width() < MapPreview.RING_WIDTH_MAX, "大型圈细")
	t.check(setup._summary.get_parsed_text().contains("地图　魔法废墟 · 大型"), "摘要：%s" % setup._summary.get_parsed_text())
	game.queue_free()
	Support.cleanup("setup180b")


static func frame_difficulty_and_memory(t: TestCase, root: Window) -> void:
	t.begin("180 · 当前难度：大字数字、加减钳在已解锁的档里、红字逐级列挑战；出发记下图 / 规模 / 难度，下次默认；调试台的下局种子只管一局")
	var game = _game(root, "setup180c")
	var flow: GameFlow = game.flow
	var setup = game.base()
	setup.show_page(2)
	var ladder := flow.available_difficulties()
	t.check(ladder.size() >= 2, "解锁后至少两档")
	t.eq(setup._difficulty_num.text, "0", "首局默认 0")
	t.eq(setup._difficulty_num.get_theme_font_size("font_size"), 72, "数字 72 号")
	t.check(setup._minus_btn.disabled and not setup._plus_btn.disabled, "0 档：减灰、加亮")
	t.eq(setup._challenge.text, "", "0 档红字留白")
	setup.step_difficulty(-1)
	t.eq(setup.difficulty_index, 0, "减不下去")
	for i in ladder.size() + 2:
		setup.step_difficulty(1)
	t.eq(setup.difficulty(), ladder[ladder.size() - 1], "加到最高的已解锁档就停")
	t.check(setup._plus_btn.disabled, "到顶：加灰")
	t.eq(setup._challenge.get_theme_color("font_color"), UiPalette.HP, "红字")
	for i in range(1, ladder.size()):
		if ladder[i].challenge != "":
			t.check(setup._challenge.text.contains(ladder[i].challenge), "列出第 %d 级的挑战" % ladder[i].level)
	t.eq(ladder[1].display_name, "进阶一", "进阶去掉「（占位）」")
	setup.choose_scale(&"medium")
	flow.next_run_seed = 4242
	setup.show_page(1)
	setup.show_page(2)
	t.eq(setup.run_seed, 4242, "调试台指定了下一局种子：进第三页用它")
	var went: bool = setup.depart()
	t.check(went, "出发")
	if went:
		t.eq(flow.run.run_seed, 4242, "这一局用的是它")
	t.eq(flow.next_run_seed, -1, "只管一局")
	t.eq(flow.meta.flag(&"last_map"), setup.chapter().order + 1, "记下图")
	t.eq(flow.meta.flag(&"last_scale"), 2, "记下规模（中型 = 第二档）")
	t.eq(flow.meta.flag(&"last_difficulty"), ladder[ladder.size() - 1].level, "记下难度")
	flow.to_main_menu()
	flow.new_run()
	var again = game.base()
	t.eq(again.scale_id, &"medium", "下次默认上次的规模")
	t.eq(again.difficulty(), ladder[ladder.size() - 1], "下次默认上次的难度")
	again.show_page(2)
	game.queue_free()
	Support.cleanup("setup180c")


static func frame_reveal_into_run(t: TestCase, root: Window) -> void:
	t.begin("180 §4 · 入局转场：第一帧的圈和预览上的圈重合（缩放 = 圈距 ÷ 环距、画布中心在预览圆心）；纸化开、节点一环一环长出来、读数最后出来；点一下直接到头；换屏淡入关着就不转场")
	var was := GameDirector.fades_allowed
	GameDirector.fades_allowed = true
	var game = _game(root, "setup180d")
	var flow: GameFlow = game.flow
	flow.settings.ui_fades = true
	var setup = game.base()
	setup.show_page(2)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)     # 第一帧里容器还没排版
	pv.finish()
	var want: Dictionary = setup.reveal_payload()
	t.check(not want.is_empty(), "第三页开着：有转场的几何")
	if want.is_empty():
		GameDirector.fades_allowed = was
		game.queue_free()
		return
	t.check(is_equal_approx(float(want["ring_gap"]), pv.ring_gap()) and int(want["levels"]) == pv.levels, "圈距、环数取预览的")
	t.check(setup.depart(), "出发")
	t.eq(flow.map_reveal, {}, "交出去就清")
	var map = game.base()
	t.eq(map.screen, GameFlow.Screen.MAP, "→ 地图屏")
	t.eq(map.modulate.a, 1.0, "不叠换屏淡入")
	t.check(map.revealing(), "在转场")
	var view: MapView = map._view
	t.check(is_equal_approx(view.zoom, float(want["ring_gap"]) / RingLayoutBase.RING_STEP), "缩放 = 圈距 ÷ 环距（%.3f）" % view.zoom)
	var c_local: Vector2 = view.get_global_transform().affine_inverse() * (want["center"] as Vector2)
	t.check(view.to_screen(view.canvas_rect().get_center()).distance_to(c_local) < 0.5, "画布中心落在预览圆心")
	t.check(absf(RingLayoutBase.RING_STEP * view.zoom - pv.ring_gap()) < 0.01, "第一环和预览第一圈一样大")
	t.not_null(map.reveal_paper(), "盖着一张纸")
	var mat := map.reveal_paper().material as ShaderMaterial
	t.check(mat.get_shader_parameter(&"invert") == true and is_equal_approx(float(mat.get_shader_parameter(&"radius")), float(want["radius"])), "纸从预览的半径化开")
	t.eq(view.node_front, 0.0, "节点还没长出来")
	t.eq(view.deco_alpha, 0.0, "装饰还没浮现")
	t.check(map._floating.all(func(c: Control) -> bool: return c.modulate.a == 0.0), "读数还藏着")
	t.is_null(map._rules, "规则卡等转场完")
	var to: Dictionary = map.reveal_target()
	map.apply_reveal(0.6)
	t.check(view.zoom > minf(float(want["ring_gap"]) / RingLayoutBase.RING_STEP, float(to["zoom"])) - 0.001 and view.zoom < maxf(float(want["ring_gap"]) / RingLayoutBase.RING_STEP, float(to["zoom"])) + 0.001, "半程：缩放在起止之间")
	t.check(view.node_front > 0.0 and view.node_front < float(view.level_count() + 1), "节点一环一环长（%.2f）" % view.node_front)
	var grow: Dictionary = view._grow_map()
	var origin := view.reveal_origin_ring()
	var rings: Dictionary = (view._layout as RingLayoutBase).levels_of(view.graph)
	var near := -1.0
	var far_ := 2.0
	for id in grow:
		var k := absi(int(rings[id]) - origin)
		if k == 0:
			near = maxf(near, float(grow[id]))
		if k == view.level_count() - 1:
			far_ = minf(far_, float(grow[id]))
	t.check(near > far_, "离出生环近的先长（%.2f > %.2f）" % [near, far_])
	map.apply_reveal(1.0)
	t.check(float(mat.get_shader_parameter(&"radius")) > Vector2(root.size).length(), "纸已经化出屏外")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	map._input(ev)
	t.check(not map.revealing(), "点一下：直接到头")
	t.is_null(map.reveal_paper(), "纸撤了")
	t.check(is_equal_approx(view.zoom, float(to["zoom"])) and view.pan.distance_to(to["pan"]) < 0.5, "视角落到平时进图的那样")
	t.eq(view.node_front, INF, "节点画全")
	t.eq(view.deco_alpha, 1.0, "装饰画全")
	t.check(map._floating.all(func(c: Control) -> bool: return c.modulate.a == 1.0), "读数出来了")
	t.eq(map.rules_open(), flow.rules_card_pending() or map._rules != null, "转场完才轮到规则卡")
	game.queue_free()
	Support.cleanup("setup180d")

	# 换屏淡入关着：直接进图
	var g2 = _game(root, "setup180e")
	g2.flow.settings.ui_fades = false
	var s2 = g2.base()
	s2.show_page(2)
	s2.preview().finish()
	s2.depart()
	t.check(not g2.base().revealing(), "淡入关着：不转场")
	t.eq(g2.base()._view.node_front, INF, "一步到位")
	g2.queue_free()
	Support.cleanup("setup180e")
	GameDirector.fades_allowed = was


static func run_map_deco(t: TestCase) -> void:
	t.begin("180 §4 · 地图装饰层 `<底图>_deco.png`：美术没交 = null；交了地图屏铺在底图上")
	t.is_null(MapSkin.deco(&"ruins") if not FileAccess.file_exists(MapSkin.root + "ruins_deco.png") else null, "遗迹的装饰层还没交")
	t.is_null(MapSkin.deco(&""), "没底图就没装饰")
	var keep := MapSkin.root
	var dir := "user://test_map_deco_180/"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.4, 0.3))
	img.save_png(dir + "t180.png")
	img.fill(Color(0, 0, 0, 0))
	img.save_png(dir + "t180_deco.png")
	MapSkin.root = dir
	t.not_null(MapSkin.deco(&"t180"), "交了就读得到")
	var v := MapView.new()
	v.skin = &"t180"
	t.not_null(v._deco_tex, "地图屏铺上")
	v.free()
	MapSkin.root = keep
	for f in ["t180.png", "t180_deco.png"]:
		DirAccess.remove_absolute(dir + f)

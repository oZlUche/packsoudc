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
	t.eq(setup._summary.text, Names.of(setup.character()), "180 补二：右上只写角色名")
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
	t.eq(setup._difficulty_num.text, "〇", "首局默认 0 级，写「〇」（180 补二：罗马数字）")
	t.eq(setup._difficulty_num.get_theme_font_size("font_size"), 72, "数字 72 号")
	t.eq(setup._counter.theme_type_variation, UiTheme.PANEL_FLIP_COUNTER, "翻页计数器牌面")
	t.eq(setup._difficulty_num.get_theme_color("font_color"), Color.WHITE, "白字")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_FLIP_COUNTER), UiTheme.TONE_DARK, "黑底")
	t.check(setup._minus_btn.disabled and not setup._plus_btn.disabled, "0 档：减灰、加亮")
	t.eq(setup._challenge.text(), "", "0 档纸上全空（补四）")
	t.check(not setup.difficulty_open() and setup._diff_plate.visible and setup._counter.modulate.a == 0.0, "补四：〇级整块收起，只剩「开启挑战」")
	t.check(not setup._diff_plate.disabled and setup._diff_plate.text == "开启挑战", "按钮能点，写「开启挑战」（补四定乙）")
	t.check(setup._diff_plate.size.y >= DifficultyBlock.FACE_SIZE.y and setup._diff_plate.alignment == HORIZONTAL_ALIGNMENT_CENTER, "收起时按钮更高、字居中")
	var block: DifficultyBlock = setup._diff_block
	t.check(block.scroll.top_rod.visible and block.scroll.bottom_rod.visible and block.scroll.paper_alpha == 0.0, "按钮背后两根卷好的卷轴（就是羊皮纸那对），中间不露纸")
	var face := block.face_rect()
	t.check(block.rods_y < face.position.y and block.rods_y + block.scroll.get_combined_minimum_size().y > face.end.y, "卷轴上下各露出一截")
	setup.step_difficulty(-1)
	t.eq(setup.difficulty_index, 0, "减不下去")
	for i in ladder.size() + 2:
		setup.step_difficulty(1)
	block.finish()     # 展开过渡直接到头
	t.eq(setup.difficulty(), ladder[ladder.size() - 1], "加到最高的已解锁档就停")
	t.eq(setup._difficulty_num.text, TextTemplate.roman(ladder[ladder.size() - 1].level), "罗马数字（%s）" % setup._difficulty_num.text)
	t.check(setup._plus_btn.disabled, "到顶：加灰")
	t.check(setup.difficulty_open() and setup._counter.modulate.a == 1.0, "≥ Ⅰ：展开")
	t.check(not setup._diff_plate.visible, "展开后「开启挑战」收走")
	for i in range(1, ladder.size()):
		if ladder[i].challenge != "":
			t.check(setup._challenge.text().contains(ladder[i].challenge), "列出第 %d 级的挑战" % ladder[i].level)
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


static func frame_supplement_two(t: TestCase, root: Window) -> void:
	t.begin("180 补二（作者 10:09）：仓库框按自己的内容定大小、留滚动条位、放不下就滚，不和棋盘对齐；第三页右上只写角色名、没有「出发摘要」；「返回」大两号仍比「出发」小")
	var game = _game(root, "setup180f")
	var setup = game.base()
	setup.show_page(1)
	var scroll: ScrollContainer = setup.warehouse_scroll()
	t.not_null(scroll, "仓库在滚动区里")
	var want: Vector2 = setup._warehouse_pages.get_combined_minimum_size()
	t.eq(scroll.custom_minimum_size.x, want.x + setup.SCROLL_GUTTER, "宽 = 页签 + 格子 + 滚动条位")
	t.eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "只竖着滚")
	t.check(scroll.custom_minimum_size.y <= want.y, "高不超过格子")
	t.check(setup._warehouse_box is PanelContainer and (setup._warehouse_box as PanelContainer).theme_type_variation == UiTheme.PANEL_GROOVE, "仓库自己一块板")
	t.check(setup._warehouse_box.get_parent() != setup._board_host.get_parent(), "和棋盘不在同一块板里")
	t.eq(setup._warehouse_box.size_flags_vertical, Control.SIZE_SHRINK_BEGIN, "按内容高、顶边对齐")
	# 一屏放不下：这一页只剩 300 高 → 滚动区夹在剩下的高里
	setup.fit_warehouse_to(300.0)
	t.check(scroll.custom_minimum_size.y < want.y, "放不下就滚（%.0f < %.0f）" % [scroll.custom_minimum_size.y, want.y])
	setup.show_page(2)
	var texts := _texts(setup._pages[2])
	t.check(not texts.any(func(s: String) -> bool: return s.contains("出发摘要") or s.contains("负重") or s.begins_with("地图　")), "没有「出发摘要」和其余各行")
	t.eq(setup._summary.text, Names.of(setup.character()), "只写角色名")
	t.eq(setup._back_btn.get_theme_font_size("font_size"), UiPalette.button_font_size(setup.BACK_FONT, UiPalette.Tier.MINOR), "「返回」大两号")
	t.check(setup._back_btn.get_theme_font_size("font_size") < setup._enter_btn.get_theme_font_size("font_size"), "仍比「出发」小")
	t.eq(setup.difficulty_numeral(0), "〇", "0 级「〇」")
	t.eq(setup.difficulty_numeral(3), "Ⅲ", "3 级「Ⅲ」")
	game.queue_free()
	Support.cleanup("setup180f")


static func frame_supplement_three_four(t: TestCase, root: Window) -> void:
	t.begin("180 补三 / 补四 / 补五（作者 11:22 / 11:32 / 11:38 / 11:49）：翻页有方向；〇级收成「开启挑战」，点开：卷轴并拢下移、按钮换成铜牌 / 计数器 / 加减，再拉开放出 Ⅰ 级一行；收起反过来；过渡中点一下到终态；到头的加减真灰")
	var game = _game(root, "setup180g")
	var flow: GameFlow = game.flow
	flow.settings.ui_fades = true
	var setup = game.base()
	setup.show_page(2)
	var block: DifficultyBlock = setup._diff_block
	var counter: FlipCounter = setup._flipper
	counter.size = Vector2(120, 100)
	var closed_y := block.rods_y
	# 点「开启挑战」：拨到 Ⅰ、展开
	setup._diff_plate.pressed.emit()
	t.eq(setup.difficulty_index, 1, "点按钮 → Ⅰ")
	t.check(setup.difficulty_open() and block.transitioning(), "开始展开过渡")
	block._tween.custom_step(DifficultyBlock.MOVE_SEC * 0.5)
	t.check(block.rods_y > closed_y and block.rods_y < block.open_rods_y(), "第一段：两根卷轴一起往下移（%.1f）" % block.rods_y)
	t.check(setup._diff_plate.modulate.a < 1.0 and setup._counter.modulate.a > 0.0 and block.title.modulate.a > 0.0, "按钮面淡出，铜牌 / 计数器淡入")
	t.eq(counter.last_dir, 0, "还没翻页")
	block._tween.custom_step(DifficultyBlock.MOVE_SEC * 0.5 + 0.01)
	t.check(absf(block.rods_y - block.open_rods_y()) < 0.5, "卷轴到了纸的位置")
	t.eq(counter.last_dir, 1, "第二段：〇 → Ⅰ 从下往上翻")
	t.check(counter.flipping(), "正在翻")
	t.eq(setup._challenge.rows().size(), 1, "纸上一行（〇级没有行）")
	t.check(setup._challenge.shown_h < setup._challenge.paper_height(), "两根卷轴正在拉开")
	block._tween.custom_step(DifficultyBlock.SPREAD_SEC)
	t.check(not block.transitioning(), "过渡完了")
	t.check(absf(setup._challenge.shown_h - setup._challenge.paper_height()) < 0.5, "拉开到一行的高")
	t.check(not setup._diff_plate.visible and block.title.modulate.a == 1.0 and setup._counter.modulate.a == 1.0, "展开态：铜牌、计数器、加减")
	t.eq(setup._minus_btn.theme_type_variation, UiTheme.BUTTON_STEP, "加减用专门的灰态")
	t.check(not setup._minus_btn.disabled, "Ⅰ 级：减可按（回〇级收起）")
	# 收起：先翻回〇、卷轴合拢，再上移回按钮背后
	setup.step_difficulty(-1)
	t.eq(counter.last_dir, -1, "按减：从上往下翻")
	t.check(not setup.difficulty_open() and block.transitioning(), "开始收起过渡")
	block._tween.custom_step(DifficultyBlock.SPREAD_SEC * 0.5)
	t.check(setup._challenge.shown_h < setup._challenge.paper_height() and absf(block.rods_y - block.open_rods_y()) < 0.5, "先合拢，卷轴还在纸的位置")
	# 过渡中点一下：直接到终态
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	block._on_shield_input(click)
	t.check(not block.transitioning() and setup._diff_plate.visible and setup._counter.modulate.a == 0.0, "过渡中点一下：直接收好")
	t.check(absf(block.rods_y - closed_y) < 0.5 and setup._challenge.rows().is_empty(), "卷轴回到按钮背后，纸空")
	t.eq(setup._difficulty_num.text, "〇", "计数器〇")
	# 到头的灰态和平常不一样
	var off: StyleBoxFlat = setup._plus_btn.get_theme_stylebox("disabled") as StyleBoxFlat
	var on: StyleBoxFlat = setup._plus_btn.get_theme_stylebox("normal") as StyleBoxFlat
	t.check(off != null and on != null and off.bg_color != on.bg_color, "灰态的底不同于平常（压到板色）")
	t.check(setup._plus_btn.get_theme_color("font_disabled_color").a <= 0.51, "灰态字暗一半")
	game.queue_free()
	Support.cleanup("setup180g")

	# 只解锁了普通：铜牌压灰、悬停提示
	var g2 = _game(root, "setup180h", false)
	var s2 = g2.base()
	s2.show_page(2)
	t.check(s2._diff_plate.disabled and s2._diff_plate.tooltip_text == "通关一次后开放", "一个难度都没解锁：铜牌压灰，提示通关一次后开放")
	g2.queue_free()
	Support.cleanup("setup180h")


static func frame_challenge_scroll(t: TestCase, root: Window) -> void:
	t.begin("180 补三 / 补五 · 羊皮纸：每级一行从下到上、新行在最上、数字列固定宽（点对齐）；底卷轴常在，纸长超上限时收束、默认看最新、滚轮滚、加一级回到顶")
	var sc := ChallengeScroll.new(308)
	root.add_child(sc)
	var lines: Array = [[1, "体力上限少一点"], [2, "侵蚀更重，包里的东西会受损，越往深处越严重"], [3, "猎手循着脚步追来"]]
	sc.set_lines(lines.slice(0, 1), false)
	sc.set_lines(lines.slice(0, 2), false)
	t.eq(int(sc.rows()[0]["level"]), 2, "新的一级在最上")
	t.eq(int(sc.rows()[-1]["level"]), 1, "最低级在最下")
	var nums: Array = sc.rows().map(func(r: Dictionary) -> Label: return (r["box"] as Control).find_child("Num", true, false))
	t.check(nums.all(func(l: Label) -> bool: return l.custom_minimum_size.x == ChallengeScroll.NUM_W and l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT), "数字一列固定宽、右对齐 → 点在一条竖线上")
	t.eq((nums[0] as Label).text, "Ⅱ", "罗马数字")
	t.check(sc.bottom_rod.visible and not sc.capped(), "补五：没超长也有底卷轴（纸由两根卷轴夹着）")
	var one := sc.content_height()
	sc.max_paper = one - 1.0
	sc.set_lines(lines, false)
	t.check(sc.capped() and sc.bottom_rod.visible, "超长：底卷轴收束")
	t.eq(sc.shown_h, sc.max_paper, "纸停在上限")
	t.eq(sc.bottom_rod.position.y, sc.top_rod.custom_minimum_size.y + sc.max_paper, "底卷轴贴着纸下沿")
	t.eq(sc.scroll_y, 0.0, "默认看最新的几级")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	sc._on_paper_input(ev)
	t.check(sc.scroll_y > 0.0, "滚轮往下：看更早的级")
	for i in 10:
		sc._on_paper_input(ev)
	t.eq(sc.scroll_y, sc.max_scroll(), "到底不再动")
	sc.set_lines(lines.slice(0, 2), false)
	sc.set_lines(lines, false)
	t.eq(sc.scroll_y, 0.0, "加一级：回到顶")
	sc.set_lines(lines.slice(0, 2), true)
	t.eq(sc.rows().size(), 2, "减一级：最上那行收回")
	sc.free()

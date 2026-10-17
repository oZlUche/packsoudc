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

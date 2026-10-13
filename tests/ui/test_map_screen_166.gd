## 166（作者定）：地图屏 —— 图标按钮（缺图退回文字、快捷键与角标）、左下图例（只列这张图上有的类型）、
## 进点自动存档、序章静态教程（挖洞、点一下下一步、放过一次不再放、步骤数据校验）
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "map166"


static func run_icon_button(t: TestCase) -> void:
	t.begin("166 · 图标按钮：缺图写字；悬浮窗是「名字（快捷键）」+ 一句说明；角标 -1 不画")
	var hits := [0]
	var b := IconButton.make("no_such_icon", "背包", "背包", "整理棋盘", func(): hits[0] += 1, "B")
	t.check(not b.has_art(), "没有图")
	t.eq(b.text, "背包", "缺图：按钮上写字")
	t.eq(b.tooltip_text, "背包（B）\n整理棋盘", "悬浮窗：名字（快捷键）+ 说明")
	t.eq(b.hotkey, "B", "右上角快捷键")
	t.eq(b.badge, -1, "默认没有角标")
	t.eq(b.custom_minimum_size, Vector2(IconButton.SIZE, IconButton.SIZE), "方的，%s" % IconButton.SIZE)
	t.eq(b.theme_type_variation, UiTheme.BUTTON_ICON, "底走图标按钮变体")
	b.pressed.emit()
	t.eq(hits[0], 1, "按下调回调")
	var plain := IconButton.make("no_such_icon", "放大镜", "放大镜", "", Callable())
	t.eq(plain.tooltip_text, "放大镜", "没快捷键、没说明：只写名字")
	b.free()
	plain.free()


static func run_legend(t: TestCase) -> void:
	t.begin("166 · 左下图例：只列这张图上有的节点类型，按样式表的顺序，每一种都有短名")
	var c := CS._content()
	var run := CS._start(c, null)
	if run == null:
		t.check(false, "开不了局")
		return
	var legend := HudWidgets.create(&"legend")
	legend.setup(run, null)
	var types: Array = legend.call("types")
	var have := {}
	for id in run.map.node_ids():
		have[NodeEvents.effective_type(run.map.get_node(id))] = true
	t.check(not types.is_empty(), "有东西：%s" % legend.text())
	var last := -1
	for ty in types:
		t.check(have.has(ty), "%s 图上有" % ty)
		t.check(MapNodeStyle.name_of(ty) != "", "%s 有短名「%s」" % [ty, MapNodeStyle.name_of(ty)])
		var at := MapNodeStyle.STYLES.keys().find(ty)
		t.check(at > last, "%s 按样式表的顺序" % ty)
		last = at
	for ty in have:
		if MapNodeStyle.NAMES.has(ty):
			t.check(types.has(ty), "图上有的 %s 列进去了" % ty)
	t.eq(legend.title(), "图例", "部件标题")
	# 作者 2026-10-13：图例深色半透明底、白字、有内边距，往右上挪一点
	var box := legend.theme.get_stylebox("panel", UiTheme.PANEL_HUD) as StyleBoxFlat
	t.check(box != null and box.bg_color.get_luminance() < 0.2 and box.bg_color.a > 0.5, "深色底（%s）" % (box.bg_color if box != null else null))
	t.check(box != null and box.content_margin_left >= 8 and box.content_margin_top >= 4, "有内边距，图标和字不压边框")
	t.eq(legend.theme.get_color("font_color", UiTheme.LABEL_HUD), Color.WHITE, "白字")
	t.check(HudLayout.CORNER_OFFSET.x > 8 and HudLayout.CORNER_OFFSET.y < -8, "左下角离边远一点（往右上挪）")
	legend.free()


static func run_autosave(t: TestCase) -> void:
	t.begin("166 · 进点自动存档：走上一个点、这个点的事还没给玩家看就存；看完回到地图再存一次；读档站在新点上")
	var c := GF._content()
	var f := Support.flow(c, PREFIX)
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是战斗点的种子")
		return
	f.new_run()
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	t.check(f.pick_spawn(int(found["entry"])), "挑出生点")
	RunSave.remove(f.save_path)
	t.check(not f.has_save(), "先清掉存档")
	t.check(f.step_to(int(found["next"])), "走上战斗点")
	t.eq(f.screen, GameFlow.Screen.PREBATTLE, "停在战前准备屏")
	t.check(f.has_save(), "没按任何存档：已经存了")
	var saved := RunSave.read(c.items, c.enemies, c.sets, f.save_path)
	t.check(saved != null and saved.travel.current_id == int(found["next"]), "存档里人在新点上")
	t.check(f.start_battle(), "开战")
	RunSave.remove(f.save_path)
	f.resume()
	if run.pending_loot != null:
		f.take_all_loot()
	t.eq(f.screen, GameFlow.Screen.MAP, "看完回地图")
	t.check(f.has_save(), "回到地图又存了一次")
	var back := RunSave.read(c.items, c.enemies, c.sets, f.save_path)
	t.check(back != null and back.map.get_node(int(found["next"])).is_visited(), "这一次存的是打完的样子")
	Support.cleanup(PREFIX)


static func run_coach_data(t: TestCase) -> void:
	t.begin("166 · 教程步骤是数据：序章地图那份四步（体力、货币、背包、放大镜），目标都是登记过的读数部件；坏的报出来")
	var steps := CoachOverlay.load_steps(&"prologue_map")
	var targets: Array = steps.map(func(s: Dictionary) -> String: return String(s["target"]))
	t.eq(targets, ["vitality", "wallet", "bag_button", "reopen_button"], "四步按顺序")
	t.eq(CoachOverlay.problems(steps), [] as Array[String], "没有问题")
	var bad := CoachOverlay.problems([{"target": "nope", "text": "x"}, {"target": "wallet"}])
	t.check(bad.size() == 2 and bad[0].contains("nope") and bad[1].contains("没写说明"), "坏目标、没写字都报：%s" % "；".join(bad))
	t.eq(CoachOverlay.load_steps(&"no_such_coach"), [], "没有这份：空")
	# 每一章写了教程的，那份都在、都没问题
	var c := TestSupport.load_content("free_mode", [])
	for ch in DirAccess.get_files_at("res://data/chapters"):
		if not ch.ends_with(".tres"):
			continue
		var def := load("res://data/chapters/" + ch) as ChapterDef
		if def != null and def.coach != &"":
			var s := CoachOverlay.load_steps(def.coach)
			t.check(not s.is_empty() and CoachOverlay.problems(s).is_empty(), "%s 的教程 %s 读得到、没问题" % [def.id, def.coach])
	t.not_null(c, "内容读得到")


static func frame_coach_overlay(t: TestCase, root: Window) -> void:
	t.begin("166 · 教程遮罩：目标外扩 8 挖洞；箭头从洞外指向洞；点一下下一步；最后一下收掉、发完成")
	var o := CoachOverlay.new()
	var target := Rect2(100, 60, 40, 40)
	o.target_rect = func(id: StringName) -> Rect2: return target if id == &"wallet" else Rect2()
	root.add_child(o)
	o.set_anchors_preset(Control.PRESET_TOP_LEFT)
	o.size = Vector2(1200, 700)
	var done := [0]
	o.finished.connect(func(): done[0] += 1)
	o.start([{"target": "wallet", "text": "货币"}, {"target": "nope", "text": "找不到的目标"}])
	t.eq(o.index, 0, "第一步")
	t.eq(o.hole(), target.grow(CoachOverlay.HOLE_PAD), "洞 = 目标外扩 %s" % CoachOverlay.HOLE_PAD)
	var ends := o.arrow_ends()
	t.check(ends.size() == 2 and ends[0].y > o.hole().end.y and ends[1].y > ends[0].y, "目标在上半屏：箭头在洞下面、朝上指")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	o._gui_input(click)
	t.eq(o.index, 1, "点一下：下一步")
	t.eq(o.hole(), Rect2(), "找不到目标：不挖洞")
	t.eq(o.arrow_ends(), [] as Array[Vector2], "也不画箭头")
	t.eq(done[0], 0, "还没完")
	o._gui_input(click)
	t.eq(done[0], 1, "最后一下：发完成")
	t.check(o.is_queued_for_deletion(), "收掉")


static func frame_prologue_coach(t: TestCase, root: Window) -> void:
	t.begin("166 · 序章开场：规则卡收起、地图露出来时放教程；放完记在局外，再开地图不放；调试台能重放")
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	var prologue: ChapterDef = null
	for ch in flow.chapters:
		if ch.id == &"prologue":
			prologue = ch
	t.not_null(prologue, "有序章一")
	if prologue == null:
		game.queue_free()
		return
	t.eq(prologue.coach, &"prologue_map", "序章一写了教程")
	flow.begin_direct(prologue)
	var map = game.base()
	if flow.screen != GameFlow.Screen.MAP:
		map.call("_maybe_coach")
		t.is_null(map.coach(), "开场事件压着（屏 %s）：先不放" % flow.screen)
		Support.settle(flow)
	if map.get("_rules") != null:
		map.call("_maybe_coach")
		t.is_null(map.coach(), "规则卡压着：先不放")
		map.close_rules()
	map.call("_maybe_coach")     # 屏上是延迟调用，这里直接叫
	var o: CoachOverlay = map.coach()
	t.not_null(o, "地图露出来：教程开了（屏 %s）" % flow.screen)
	if o != null:
		t.eq(o.index, 0, "第一步")
		t.check(o.hole().size.x > 0.0, "第一步挖了洞（体力在栏里）")
		for i in o.steps.size():
			t.check(o.hole().size.x > 0.0, "第 %d 步的目标找得到" % (i + 1))
			o.next()
		t.is_null(map.coach(), "四步点完：收掉")
	t.check(flow.meta.coach_seen.has("prologue_map"), "记在局外")
	map.call("_maybe_coach")
	t.is_null(map.coach(), "放过了：不再自己放")
	t.check(map.show_coach(true), "调试台「重放教程」照样能放")
	t.not_null(map.coach(), "重放开了")
	game.queue_free()
	Support.cleanup(PREFIX)


static func frame_prebattle_no_slip(t: TestCase, root: Window) -> void:
	t.begin("166 补充一 · 主动技能藏着：安德烈乌斯到了战前准备屏也没有「溜走」，脱身的记账照旧")
	var c := CS._content()
	var andreus := CS._character(c, &"andreus")
	var kit := GF._loadout(TestSupport.load_content("free_mode", ["loadouts"]), &"standard")
	var found := GF._seed_with(TestSupport.load_content("free_mode", ["loadouts"]), &"battle", kit.items)
	if andreus == null or found.is_empty():
		t.check(false, "没有安德烈乌斯 / 找不到种子")
		return
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(c.chapter, kit, int(found["seed"]), [] as Array[int], andreus)
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	map.step(int(found["next"]))
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备屏")
	t.not_null(flow.slip_skill(), "脱身还在角色身上（记账照旧）")
	if pre != null:
		t.eq(pre.get("_slip_btn") == null, RunSkills.ACTIVE_HIDDEN, "「溜走」按钮%s" % ["没建" if RunSkills.ACTIVE_HIDDEN else "在"])
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)


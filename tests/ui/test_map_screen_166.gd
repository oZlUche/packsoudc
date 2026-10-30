## 166（作者定）：地图屏 —— 图标按钮（缺图退回文字、快捷键与角标）、左下图例（只列这张图上有的类型）、
## 进点自动存档、序章静态教程（挖洞、点一下下一步、放过一次不再放、步骤数据校验）
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "map166"
const PrebattleScript := preload("res://ui/game/prebattle_screen.gd")


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
		have[MapNodeStyle.key_of(run.map.get_node(id))] = true     # 267：材料节点按种类
	t.check(not types.is_empty(), "有东西：%s" % legend.text())
	var last := -1
	for ty in types:
		t.check(have.has(ty), "%s 图上有" % ty)
		t.check(MapNodeStyle.name_of(ty) != "", "%s 有短名「%s」" % [ty, MapNodeStyle.name_of(ty)])
		if MapNodeStyle.KINDS.has(ty):     # 267：材料节点紧跟在「搜索」后面
			t.check(last <= MapNodeStyle.STYLES.keys().find(&"search"), "%s 跟在搜索后面" % ty)
			continue
		var at := MapNodeStyle.STYLES.keys().find(ty)
		t.check(at > last, "%s 按样式表的顺序" % ty)
		last = at
	for ty in have:
		if MapNodeStyle.NAMES.has(ty) or MapNodeStyle.KINDS.has(ty):
			t.check(types.has(ty), "图上有的 %s 列进去了" % ty)
	t.eq(legend.title(), "图例", "部件标题")
	# 作者 2026-10-13：图例白字、有内边距；232：底是双尾旗九宫格（深底），最窄 158
	var box := legend.theme.get_stylebox("panel", UiTheme.PANEL_HUD) as StyleBoxTexture
	t.check(box != null and box.texture != null, "双尾旗底")
	t.check(box != null and box.content_margin_left >= 8 and box.content_margin_top >= 4, "有内边距，图标和字不压边框")
	t.check(legend.custom_minimum_size.x >= 158.0, "最窄 158")
	t.check(box != null and box.content_margin_right >= box.content_margin_left, "右边内边距不小于左边（复测 v4.78：最宽那行贴右边金线）")
	t.eq(legend.get_meta(&"tone", &""), UiTheme.TONE_DARK, "深底（白字）")
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
	t.eq(targets, ["vitality", "wallet", "bag_end", "reopen_button"], "四步按顺序（235：背包指栏的右头）")
	t.eq(CoachOverlay.problems(steps), [] as Array[String], "没有问题")
	var bad := CoachOverlay.problems([{"target": "nope", "text": "x", "texts": {"en": "x"}}, {"target": "wallet", "texts": {"en": "x"}}])
	t.check(bad.size() == 2 and bad[0].contains("nope") and bad[1].contains("没写说明"), "坏目标、没写字都报：%s" % "；".join(bad))
	var no_en := CoachOverlay.problems([{"target": "wallet", "text": "x"}])
	t.check(no_en.size() == 1 and no_en[0].contains("texts.en"), "221 F3：没写英文也报：%s" % "；".join(no_en))
	var step := {"target": "wallet", "text": "货币", "texts": {"en": "Coins"}}
	UiText.lang = "en"
	var en := CoachOverlay.text_of(step)
	UiText.lang = "zh"
	t.eq([en, CoachOverlay.text_of(step), CoachOverlay.text_of({"text": "只有中文"})], ["Coins", "货币", "只有中文"], "221 F3：按语言取，没写英文回落中文")
	t.eq(CoachOverlay.load_steps(&"no_such_coach"), [], "没有这份：空")
	# 218：自由模式那份三步（日晷、背包按钮、腰带）；负重读数默认藏着，所以指背包按钮
	var free := CoachOverlay.load_steps(&"free_mode_map")
	t.eq(free.map(func(s: Dictionary) -> String: return String(s["target"])), ["countdown", "bag_end", "belt"], "218：自由模式三步按顺序（235：背包指栏的右头）")
	t.eq(CoachOverlay.problems(free), [] as Array[String], "218：没有问题")
	t.check(free.all(func(s: Dictionary) -> bool: return TextLint.scan({"text": String(s["text"])}).is_empty()), "218：不写数字")
	t.eq((load(ContentPaths.asset_file("chapters", "free_mode")) as ChapterDef).coach_for(&"map"), &"free_mode_map", "218：自由模式配了这份")
	t.eq((load(ContentPaths.asset_file("chapters", "clockwork_hourglass")) as ChapterDef).coaches, {}, "218 补充一：机关沙漏不配教程（作者）")
	# 218 补充一（217 批三）：序章一的背包窗四步（220 压了步）、战前屏三步，目标各认各的屏
	var bag := CoachOverlay.load_steps(&"prologue_bag")
	t.eq(bag.map(func(s: Dictionary) -> String: return String(s["target"])), ["board", "board", "board", "strip_stamina"], "220：背包窗棋盘三步、三枚签并成一步")
	t.eq(CoachOverlay.problems(bag, BagWindow.COACH_TARGETS), [] as Array[String], "背包窗的目标都认得")
	var pre := CoachOverlay.load_steps(&"prologue_prebattle")
	t.eq(pre.map(func(s: Dictionary) -> String: return String(s["target"])), ["enemy_board", "stats", "my_board"], "战前屏三步")
	t.eq(CoachOverlay.problems(pre, PrebattleScript.COACH_TARGETS), [] as Array[String], "战前屏的目标都认得")
	for some in [free, bag, pre]:
		t.check((some as Array).all(func(s: Dictionary) -> bool: return TextLint.scan({"text": String(s["text"])}).is_empty()), "不写数字")
	var p1 := load(ContentPaths.asset_file("chapters", "prologue")) as ChapterDef
	t.eq(p1.coaches, {"map": "prologue_map", "battle": "prologue_battle", "bag": "prologue_bag", "prebattle": "prologue_prebattle"}, "序章一四份教程收在一个字典里")
	# 旧 json 的 coach / coach_battle 导入时收进字典
	var old_ch := ContentImporter.import_chapter({"id": "x", "coach": "a", "coach_battle": "b", "map_source": {"mode": "PRESET", "preset_path": "res://data/maps/prologue.json"}}, ContentImporter.Context.new(), ImportReport.new())
	t.eq(old_ch.coaches, {"map": "a", "battle": "b"}, "旧字段 coach / coach_battle → coaches")
	var bad_kind := ImportReport.new()
	ContentImporter.import_chapter({"id": "x", "coaches": {"nope": "a"}}, ContentImporter.Context.new(), bad_kind)
	t.check(bad_kind.to_text().contains("nope"), "认不得的屏报出来")
	# 每一章写了教程的，那份都在、都没问题
	var c := TestSupport.load_content("free_mode", [])
	for ch in DirAccess.get_files_at("res://data/chapters"):
		if not ch.ends_with(".tres"):
			continue
		var def := load("res://data/chapters/" + ch) as ChapterDef
		if def != null and def.coach_for(&"map") != &"":
			var s := CoachOverlay.load_steps(def.coach_for(&"map"))
			t.check(not s.is_empty() and CoachOverlay.problems(s).is_empty(), "%s 的教程 %s 读得到、没问题" % [def.id, def.coach_for(&"map")])
		for kind in (def.coaches.keys() if def != null else []):
			t.check(ChapterDef.COACH_KINDS.has(StringName(String(kind))) and not CoachOverlay.load_steps(StringName(String(def.coaches[kind]))).is_empty(), "%s 的 %s 教程读得到" % [def.id, kind])
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
	t.eq(prologue.coach_for(&"map"), &"prologue_map", "序章一写了教程")
	flow.begin_direct(prologue)
	var map = game.base()
	if flow.screen != GameFlow.Screen.MAP:
		map.call("_maybe_coach")
		t.is_null(map.coach(), "开场事件压着（屏 %s）：先不放" % flow.screen)
		Support.settle(flow)
	t.check(map.tutorial_ask_open(), "240：开场事件选完先问要不要教程")
	map.call("_maybe_coach")
	t.is_null(map.coach(), "240：卡开着，教程先不放")
	map.accept_tutorial()     # 240：【需要】
	t.is_null(map.get("_rules"), "220：序章一没有规则卡，不弹")
	map.toggle_pause()
	var pause_labels: Array = map._pause.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	t.check(not pause_labels.has("本图规则") and pause_labels.has("百科"), "220：序章的暂停菜单没有「本图规则」（%s）" % [pause_labels])
	map.toggle_pause()
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
	for i in map.coach().steps.size():
		map.coach().next()
	# 218 补充一（217 批三）：第一次开背包窗放背包窗教程 —— 四步，棋盘与三枚签都挖得到洞；走完记在局外，再开不放
	t.check(CoachOverlay.due(flow, &"prologue_bag"), "背包窗教程还没看过")
	map.toggle_bag()
	var win: BagWindow = null
	for ch in map._bag.get_children():
		if ch is BagWindow:
			win = ch
	t.not_null(win, "开了背包窗")
	if win != null:
		_lay_out(win)     # 屏上等一帧再放；这里手动排一遍
		t.check(win.show_coach(flow, map._bag), "背包窗教程开了")
		var bo: CoachOverlay = win.coach
		if bo != null:
			t.eq(bo.get_parent(), map._bag, "铺在压暗那一层上")
			t.eq(bo.steps.size(), 4, "220：四步")
			for id in BagWindow.COACH_TARGETS:
				var r := win.control_rect(id)
				t.check(r.size.x > 0.0 and r.size.y > 0.0, "背包窗 %s 找得到（%s）" % [id, r])
			t.check(win.control_rect(&"strip_stamina").position.y > win.control_rect(&"board").end.y, "签在棋盘下面（%s / %s）" % [win.control_rect(&"strip_stamina"), win.control_rect(&"board")])
			for i in 4:
				t.check(bo.hole().size.x > 0.0, "背包窗第 %d 步挖了洞" % (i + 1))
				bo.next()
		t.is_null(win.coach, "四步点完：收掉")
		t.check(flow.meta.coach_seen.has("prologue_bag"), "背包窗教程记在局外")
	map.toggle_bag()
	t.check(not CoachOverlay.due(flow, &"prologue_bag"), "看过了：再开不放")
	map.replay_coach(&"bag")
	t.check(CoachOverlay.due(flow, &"prologue_bag"), "调试台「重放背包教程」：下一次开窗再放")
	game.queue_free()
	Support.cleanup(PREFIX)


static func frame_prebattle_no_slip(t: TestCase, root: Window) -> void:
	t.begin("166 补充一 · 安德烈乌斯到了战前准备屏没有「溜走」（256：脱身删了，战前屏只有偷袭）")
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
	t.is_null(flow.slip_skill(), "256：脱身删了")
	if pre != null:
		t.is_null(pre.get("_slip_btn"), "「溜走」按钮没建")
		t.not_null(pre.ambush_button(), "偷袭键在")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)


## 容器的排布是延迟的，同一帧里手动排一遍（从外到里）
static func _lay_out(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_lay_out(c)

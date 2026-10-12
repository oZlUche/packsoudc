## 157：各屏构成第一批 —— 叠层共用石板框（有图九宫格、没图平面）、悬浮窗底、光标、淡入开关；战前对阵式（名牌、读数不写件数、天平）；
## 回放时间轴（刻度、拖动 = seek）与三种反馈（跳转时抑制）、收尾战报；战败结算保险箱放大居中；事件选项代价图标与结果页收获行
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const FIXTURES := "res://tests/fixtures/ui/"
const NOWHERE := "res://tests/fixtures/no_such_ui/"


static func run_theme_art(t: TestCase) -> void:
	t.begin("157 · 石板框与悬浮窗底：assets/ui 有图是九宫格（边距与标题条高读 json），没图是原来的平面底；美术交付的那张框已经放进来")
	var saved := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	var flat := UiTheme.build()
	t.check(flat.get_stylebox("panel", UiTheme.PANEL_OVERLAY) is StyleBoxFlat, "没图：石板框是平面底")
	t.check(flat.get_stylebox("panel", UiTheme.PANEL_TOOLTIP) is StyleBoxFlat, "没图：悬浮窗底是平面底")
	t.eq(UiTheme.frame_title_height(), 0, "没图：标题条按字高")
	UiTheme.asset_root = FIXTURES
	var art := UiTheme.build()
	var box := art.get_stylebox("panel", UiTheme.PANEL_OVERLAY) as StyleBoxTexture
	t.check(box != null and box.texture != null, "测试图：石板框是九宫格")
	if box != null:
		t.eq([box.texture_margin_left, box.texture_margin_top, box.texture_margin_right, box.texture_margin_bottom], [1.0, 1.0, 1.0, 1.0], "边距按 json")
		t.eq(box.content_margin_top, 0.0, "顶边内边距 0：标题条自己占住图顶那一条")
	t.eq(UiTheme.frame_title_height(), 30, "标题条高按 json")
	t.check(art.get_stylebox("panel", UiTheme.PANEL_TOOLTIP) is StyleBoxFlat, "测试目录里没有纸：悬浮窗底照旧")
	UiTheme.asset_root = saved
	var real := UiTheme.build().get_stylebox("panel", UiTheme.PANEL_OVERLAY) as StyleBoxTexture
	t.check(real != null and is_equal_approx(real.texture_margin_top, 44.0), "assets/ui 里美术交付的石板框：九宫格、上边距 44")
	t.eq(UiTheme.frame_title_height(), 36, "标题条 36")
	t.check(UiTheme.build().get_stylebox("panel", UiTheme.PANEL_TOOLTIP) is StyleBoxTexture, "assets/ui 里美术交付的纸：悬浮窗底是九宫格")
	for skin in UiCursor.SKINS:
		for name in ["cursor_arrow", "cursor_drag", "cursor_can_drop", "cursor_forbidden"]:
			t.not_null(UiTheme.art("cursors/%s/%s" % [skin, name]), "光标图 %s/%s 在" % [skin, name])
		t.eq(UiCursor.apply(String(skin)), 4, "%s：四种光标都换上了美术的图" % skin)
	t.eq(UiCursor.apply("没有这套"), 4, "认不出的材质按默认（秘银）")
	t.eq(UiCursor.DEFAULT_SKIN, "mithril", "默认秘银")
	UiTheme.asset_root = NOWHERE
	t.eq(UiCursor.apply(), 0, "没图：全还原成系统光标")
	UiTheme.asset_root = saved
	UiCursor.apply()

	t.begin("157 · 换屏淡入：设置项默认开、存取往返；测试与截图工具关掉")
	t.check(GameSettings.new().ui_fades, "默认开")
	var gs := GameSettings.new()
	gs.ui_fades = false
	t.check(not GameSettings.from_dict(gs.to_dict()).ui_fades, "关了存读还是关")
	t.check(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION}).ui_fades, "旧设置文件没这个键：开")
	t.check(not GameDirector.fades_allowed, "跑测试时淡入关着（时序和以前一样）")

	t.begin("157 补 · 光标材质：设置项默认秘银、存取往返、空串回默认；设置屏三个按钮，点了存盘、按下的跟着变")
	t.eq(GameSettings.new().cursor_skin, "mithril", "默认秘银")
	gs.cursor_skin = "leather"
	t.eq(GameSettings.from_dict(gs.to_dict()).cursor_skin, "leather", "存读还是皮革")
	t.eq(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION}).cursor_skin, "mithril", "旧设置文件没这个键：秘银")
	t.eq(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "cursor_skin": ""}).cursor_skin, "mithril", "空串：秘银")


static func run_cost_icons(t: TestCase) -> void:
	t.begin("157 · 事件选项的代价图标：只画会花掉什么（体力、花钱、交出道具、耗行动点、要信仰），得钱不算；有图用图、没图画字符")
	var opt := EventOption.new()
	var gain := ChangeMoney.new()
	gain.amount = 20
	opt.outcomes = [gain, GiveItem.new()] as Array[EventOutcome]
	t.eq(EventCostIcons.kinds_of(opt), [] as Array[String], "得钱、给东西：没有代价")
	var pay := ChangeMoney.new()
	pay.amount = -15
	opt.outcomes = [PassTime.new(), pay, SpendVitality.new(), LoseItem.new(), SpendVitality.new()] as Array[EventOutcome]
	opt.requires = [FaithActive.new()] as Array[EventCondition]
	var kinds := EventCostIcons.kinds_of(opt)
	t.eq(kinds, ["vitality", "money", "item", "time", "faith"] as Array[String], "五种，按表的顺序、不重复")
	t.eq(EventCostIcons.describe(kinds), "代价：耗体力、花钱、交出道具、耗行动点、要信仰", "悬浮提示")
	var strip := EventCostIcons.strip(kinds)
	t.check(strip != null and strip.get_width() == 5 * EventCostIcons.SIZE + 4 * EventCostIcons.GAP and strip.get_height() == EventCostIcons.SIZE, "拼成一条 16 像素高的图")
	t.eq(EventCostIcons.glyph_slots(kinds), [] as Array[int], "美术交付的五张图都在：不用画字符")
	var b := Button.new()
	t.eq(EventCostIcons.attach(b, opt), 5, "挂到按钮上")
	t.check(b.icon != null and b.tooltip_text.begins_with("代价："), "按钮的图标与提示")
	var saved := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	t.eq(EventCostIcons.glyph_slots(kinds), [0, 1, 2, 3, 4] as Array[int], "没图：五格都画字符")
	UiTheme.asset_root = saved
	b.free()

	t.begin("157 · 天平：强弱比取对数再 atan，限 ±25°；哪边强哪边沉，一边是 0 斜满")
	t.eq(BalanceSeam.tilt_of(100.0, 100.0), 0.0, "一样强：平")
	t.check(BalanceSeam.tilt_of(100.0, 300.0) > 0.0, "自己强：自己这边（右）沉")
	t.check(BalanceSeam.tilt_of(300.0, 100.0) < 0.0, "对手强：对手那边（左）沉")
	t.eq(BalanceSeam.tilt_of(100.0, 0.0), -BalanceSeam.MAX_TILT, "自己空棋盘：往对手那边沉到底")
	t.eq(BalanceSeam.tilt_of(1.0, 1e9), BalanceSeam.MAX_TILT, "差得再多也只斜 25°")


static func frame_prebattle_and_replay(t: TestCase, root: Window) -> void:
	t.begin("157 · 战前对阵式与回放：叠层是石板框（标题在标题条）、读数不写几件、两边名牌（没图不画肖像）、清空棋盘天平往对手沉；回放的时间轴刻度、拖动 = seek、跳转不出反馈、战报")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("s157")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("s157")["run"])
	game.meta_path = String(Support.paths("s157")["meta"])
	game.settings_path = String(Support.paths("s157")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	var found: Dictionary = NodeScreens._seed_with(c, &"battle", kit.items)
	var run := flow.begin(c.chapter, kit, int(found.get("seed", 1)))
	flow.pick_spawn(int(found.get("entry", run.map.entry_ids[0])))
	t.check(found.has("next") and flow.step_to(int(found["next"])), "走上战斗点")
	t.eq(flow.screen, GameFlow.Screen.PREBATTLE, "→ 战前准备")
	var pre = game.overlay()
	if pre == null or not pre.has_method("seam"):
		t.check(false, "叠层不是战前准备屏")
		game.queue_free()
		Support.cleanup("s157")
		return
	t.eq(pre.find_children("*", "OverlayFrame", true, false).size(), 1, "一块石板框")
	t.check(pre.overlay_frame().title().begins_with("战前准备"), "标题在标题条上：%s" % pre.overlay_frame().title())
	t.check(pre.enemy_line().begins_with("生命") and pre.enemy_line().contains("DPS") and not pre.enemy_line().contains("件"), "读数只有生命与 DPS：%s" % pre.enemy_line())
	var plates: Array = pre.find_children("*", "Nameplate", true, false)
	t.eq(plates.size(), 2, "两块名牌")
	for p in plates:
		t.check((p as Nameplate).portrait == null and (p as Nameplate).portrait_slot != null and (p as Nameplate).portrait_slot.is_inside_tree(),
			"没肖像图：肖像位照样在、先放占位（%s）" % (p as Nameplate).name_label.text)
	var before: float = pre.seam().tilt
	var moved: Array[int] = []
	for inst in run.board.items():
		moved.append((inst as ItemInstance).uid)
	for uid in moved:
		InventoryService.transfer_auto(run.board, uid, run.storage)
	t.eq(pre.seam().tilt, -BalanceSeam.MAX_TILT, "清空棋盘：天平往对手那边沉到底")
	t.check(before > -BalanceSeam.MAX_TILT, "清空之前没沉到底（%.2f）" % before)
	for uid in moved:
		InventoryService.transfer_auto(run.storage, uid, run.board)
	t.check(pre.start_battle(), "放回去、开战")
	t.eq(flow.screen, GameFlow.Screen.BATTLE, "→ 回放")
	var screen = game.overlay()
	t.eq(screen.find_children("*", "OverlayFrame", true, false).size(), 1, "回放也是一块石板框")
	t.check(screen.overlay_frame().title().begins_with("战斗"), "标题在标题条上")
	var view: BattleView = screen._view
	var result: BattleResult = flow.last_payload.get("result", null)
	t.eq(view.find_children("*", "Nameplate", true, false).size(), 2, "回放面板顶上也是两块名牌")
	var damage := 0
	var deaths := 0
	for e in result.log:
		var ev := e as BattleEvent
		if ev.name == BattleEvent.DAMAGE and ev.get_int(&"amount") != 0:
			damage += 1
		elif ev.name == BattleEvent.DIED:
			deaths += 1
	t.eq(view.timeline().ticks.size(), damage + deaths, "刻度 = 伤害 %d + 倒下 %d" % [damage, deaths])
	t.check(damage > 0, "打了几下")
	var counts := func() -> Array:
		return [view.panel(0).shakes + view.panel(1).shakes, view.panel(0).pops + view.panel(1).pops,
			view.overlay(0).flashes + view.overlay(1).flashes]
	var c0: Array = counts.call()
	var mid := result.duration_sec() * 0.5
	view.timeline().scrub_started.emit()
	view.timeline().seek_requested.emit(mid)
	t.check(absf(view.now() - mid) < 0.001 and view.timeline().cursor == view.now(), "拖到一半：回放时刻与游标都在那儿")
	var hp_drag: Array = view.panel(1)._resources.get("hp", [])
	view.seek(mid)
	t.eq(view.panel(1)._resources.get("hp", []), hp_drag, "和直接 seek 到那一刻的面板一样")
	t.eq(counts.call(), c0, "跳转补上的事件：抖动、弹出、出手高亮都没有")
	view.timeline().scrub_ended.emit()
	view.skip_to_end()
	t.eq(counts.call(), c0, "跳过也不出反馈")
	var dealt := [0, 0]
	for e in result.log:
		var ev := e as BattleEvent
		if ev.name == BattleEvent.DAMAGE and ev.get_int(&"amount") > 0:
			dealt[1 - ev.side] += StatMath.to_int(ev.get_int(&"amount"))
	var report := view.report()
	t.check(report.contains("我造成 %d、承受 %d" % [dealt[0], dealt[1]]) and report.contains("秒"), "战报：%s" % report)
	t.check(screen.verdict_shown(), "胜负写上了")
	view.seek(result.duration_sec() + 1.0)
	t.eq(screen._title.text.count("——"), 1, "拖到头再「看完」一次，胜负不重复写")
	# 拿真实的一下：正常播放时三种反馈会出
	var cs: Array = counts.call()
	view.play(result, ["我", "敌"])
	view._process(result.duration_sec() + 1.0)
	var ce: Array = counts.call()
	t.check(ce[0] > cs[0] and ce[2] > cs[2], "正常放：挨打抖了、出手亮了（%s → %s）" % [cs, ce])
	game.queue_free()
	Support.cleanup("s157")


static func frame_other_overlays(t: TestCase, root: Window) -> void:
	t.begin("157 · 别的叠层也是同一块石板框：休息、容器、保险箱、商店、神坛、百科 —— 各一块，标题在标题条上")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "s157b")
	f.begin(c.chapter, kit, 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	var cases := [
		["rest", {"restored": 1}, "休息区"],
		["container", {"container": GridInventory.new(Vector2i(3, 3), 0, false)}, "战利品"],
		["shop", {}, "商店"],
		["encyclopedia", {}, "百科"],
		["altar", {}, "神坛"],
	]
	if SafeModule.of(f.run) != null:
		cases.append(["safe", {}, "保险箱"])
	for row in cases:
		var screen = load("res://ui/game/%s_screen.gd" % row[0]).new()
		screen.flow = f
		screen.font = UiPalette.cjk_font()
		root.add_child(screen)
		screen.open(row[1])
		var frames: Array = screen.find_children("*", "OverlayFrame", true, false)
		t.eq(frames.size(), 1, "%s：一块石板框" % row[0])
		if not frames.is_empty():
			t.check((frames[0] as OverlayFrame).title().begins_with(String(row[2])), "%s：标题「%s」" % [row[0], (frames[0] as OverlayFrame).title()])
		screen.queue_free()
	Support.cleanup("s157b")


static func frame_result_defeat(t: TestCase, root: Window) -> void:
	t.begin("157 · 战败结算：有保险箱件 → 保险箱居中、格子 60；没有 → 只有一句，没有那一格")
	var c = NodeScreens._content()
	var f := Support.flow(c, "s157c")
	var gun: ItemDef = c.items.get_def(StringName(String(c.items.ids()[0])))
	for with_safe in [true, false]:
		var r := RunResult.new()
		r.outcome = &"defeated"
		r.reason = &"vitality_depleted"
		if with_safe:
			var inst := ItemInstance.create(gun)
			r.safe_items = [inst] as Array[ItemInstance]
			r.safe_layout = [{"def": gun, "origin": Vector2i.ZERO, "rotation": 0}] as Array[Dictionary]
		var screen = load("res://ui/game/result_screen.gd").new()
		screen.flow = f
		screen.font = UiPalette.cjk_font()
		root.add_child(screen)
		screen.open({"result": r})
		var sv: InventoryView = screen.safe_view()
		if with_safe:
			t.check(sv != null and is_equal_approx(sv.cell_px, 60.0), "保险箱那一格按 60 画")
			t.check(sv != null and sv.size_flags_horizontal == Control.SIZE_SHRINK_CENTER and (sv.get_parent().get_parent() as HBoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER, "居中")
		else:
			t.check(sv == null, "空保险箱：没有那一格")
		screen.queue_free()
	Support.cleanup("s157c")


static func frame_event_harvest(t: TestCase, root: Window) -> void:
	t.begin("157 · 事件结果页的收获行：给了两件 → 收获行两件、地上两件、背包自动打开；双击一件进棋盘 → 收获行一件、地上一件；从收获行拿起来能拖（背后是地上）")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "s157d")
	var run := f.begin(c.chapter, kit, 1)
	f.pick_spawn(run.map.entry_ids[0])
	for inst in run.storage.items():
		run.storage.remove((inst as ItemInstance).uid)
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			run.board.remove((inst as ItemInstance).uid)     # 包里腾出地方
	var small: ItemDef = null
	for id in c.items.ids():
		var def: ItemDef = c.items.get_def(StringName(String(id)))
		if def.shape.size_rotated(0) == Vector2i.ONE and not def.is_bag and def.belt_use == null and run.board.can_admit(def):
			small = def
			break
	var detail := {"items": [String(small.id), String(small.id)]}
	run.events.event_resolved.emit(null, &"测试", detail)
	t.eq(run.storage.item_count(), 2, "两件落在地上")
	t.eq((detail.get("item_uids", []) as Array).size(), 2, "地上那两件的 uid 记回了 detail")
	var screen = load("res://ui/game/event_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({"detail": detail, "outcome": "测试"})
	var row: HarvestRow = screen.harvest_row()
	t.check(row != null and row.shown().size() == 2, "收获行两件")
	t.check(screen.bag_open(), "背包自动打开了")
	var rich: Array = screen.find_children("*", "RichTextLabel", true, false)
	var said := ""
	for r in rich:
		said += (r as RichTextLabel).text
	t.check(not said.contains("得到："), "文字里不再写道具名")
	var uid: int = row.shown()[0]
	row.item_double_clicked.emit(row, uid)
	row = screen.harvest_row()
	t.eq(row.shown().size(), 1, "双击一件：收获行剩一件")
	t.check(run.board.get_item(uid) != null and run.storage.item_count() == 1, "那件进了棋盘，地上剩一件")
	var other: int = row.shown()[0]
	screen._drag._on_grab_requested(row, other, Vector2.ZERO)
	t.check(screen._drag.is_dragging() and run.storage.get_item(other) == null, "从收获行拿起来了（离开了地上）")
	t.eq(UiCursor.shape, Input.CURSOR_DRAG, "拿着：光标是「拖动」")
	screen._drag.cancel()
	t.check(run.storage.get_item(other) != null and row.shown().size() == 1, "放回：回到地上、还在收获行")
	t.eq(UiCursor.shape, Input.CURSOR_ARROW, "放下：光标还原")
	screen.queue_free()
	Support.cleanup("s157d")


static func frame_cursor_setting(t: TestCase, root: Window) -> void:
	t.begin("157 补 · 设置屏的光标材质：秘银 / 铁 / 皮革三个按钮，默认按下秘银；点铁 → 设置存上、按下的换成铁；坏值按默认")
	var c = NodeScreens._content()
	var f := Support.flow(c, "s157e")
	f.settings = GameSettings.new()
	var screen = load("res://ui/game/settings_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({})
	t.eq(screen._cursor_btns.keys(), ["mithril", "iron", "leather"], "三个按钮")
	t.check((screen._cursor_btns["mithril"] as Button).button_pressed and not (screen._cursor_btns["iron"] as Button).button_pressed, "默认按下秘银")
	screen.set_cursor_skin("iron")
	t.eq(f.settings.cursor_skin, "iron", "设置改成铁")
	t.eq(GameSettings.load_from(String(Support.paths("s157e")["settings"])).cursor_skin, "iron", "存盘了")
	t.check((screen._cursor_btns["iron"] as Button).button_pressed and not (screen._cursor_btns["mithril"] as Button).button_pressed, "按下的换成铁")
	screen.set_cursor_skin("没有这套")
	t.eq(f.settings.cursor_skin, "iron", "认不出的不改")
	UiCursor.apply()
	screen.queue_free()
	Support.cleanup("s157e")


static func run_tones(t: TestCase) -> void:
	t.begin("157 补 · 深浅字色：每块底都标了深浅（变体查表、美术图看 json），浅底挂墨色字主题、深底不挂；写死的亮色在浅底上压成够深的墨水版")
	for v in UiTheme.VARIATIONS:
		if UiTheme.current().get_type_variation_base(v) == &"PanelContainer":
			t.check(UiTheme.PANEL_TONES.has(v), "面板变体 %s 标了深浅" % v)
	var dir := DirAccess.open("res://assets/ui/")
	for f in dir.get_files():
		var art_name := f.get_basename()
		if f.ends_with(".png") and UiTheme.PANEL_ART.values().has(art_name):
			var tone := String(UiTheme.art_meta(art_name).get("tone", ""))
			t.check(tone == "dark" or tone == "light", "底图 %s 的 json 写了 tone（%s）" % [art_name, tone])
	t.eq(UiTheme.tone_of(UiTheme.PANEL_TOOLTIP), UiTheme.TONE_LIGHT, "悬浮窗底用美术的亮纸：浅")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_OVERLAY), UiTheme.TONE_DARK, "石板框：深")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_DARK), UiTheme.TONE_DARK, "平面底：深")
	t.check(UiTheme.current().get_stylebox("panel", UiTheme.PANEL_TOOLTIP) is StyleBoxTexture, "assets/ui 里有纸：悬浮窗底是九宫格")
	var saved := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	t.eq(UiTheme.tone_of(UiTheme.PANEL_TOOLTIP), UiTheme.TONE_DARK, "没纸：悬浮窗底照旧是深底")
	UiTheme.asset_root = saved
	t.eq(UiTheme.text_theme(UiTheme.TONE_DARK), null, "深底不挂字色主题（用全局的浅色字）")
	var light := UiTheme.text_theme(UiTheme.TONE_LIGHT)
	t.eq(light.get_color("font_color", "Label"), UiTheme.INK, "浅底：标签墨色")
	t.eq(light.get_color("font_color", UiTheme.LABEL_DIM), UiTheme.INK_SOFT, "浅底：暗色字是褐墨")
	t.eq(light.get_color("default_color", "RichTextLabel"), UiTheme.INK, "浅底：富文本墨色")
	t.check(UiTheme.contrast(UiTheme.INK_WARN, UiTheme.PAPER) >= UiTheme.MIN_CONTRAST, "警示色在纸上够清楚")
	var colors := [UiPalette.FG, UiPalette.DIM, UiPalette.HP, UiPalette.HEAL, UiPalette.STAMINA, UiPalette.GRANT, UiPalette.FAITH,
		UiPalette.RECEIVE, UiPalette.ARMOR, UiPalette.MANA, UiPalette.CRIT, Glossary.TERM_COLOR]
	colors.append_array(ItemPainter.RARITY_COLORS)
	for c in colors:
		t.check(UiTheme.contrast(UiTheme.ink_color(c), UiTheme.PAPER) >= UiTheme.MIN_CONTRAST, "#%s 压成墨水版后在纸上对比够" % (c as Color).to_html(false))
	t.eq(UiTheme.ink_color(UiPalette.FG), UiTheme.INK, "前景灰白 → 墨")
	t.eq(UiTheme.ink_color(UiPalette.DIM), UiTheme.INK_SOFT, "暗灰 → 褐墨")
	var src := "[color=#%s]生命[/color] 与 [color=%s]词条[/color]" % [UiPalette.HP.to_html(false), Glossary.TERM_COLOR.to_html(false)]
	var inked := UiTheme.ink_bbcode(src, UiTheme.TONE_LIGHT)
	t.check(not inked.contains(UiPalette.HP.to_html(false)) and inked.contains("[color=#%s]" % UiTheme.ink_color(UiPalette.HP).to_html(false)), "浅底：生命的红换成压暗的红")
	t.check(inked.contains("[color=#%s]词条" % UiTheme.ink_color(Glossary.TERM_COLOR).to_html(false)), "不带 # 的颜色也认")
	t.eq(UiTheme.ink_bbcode(src, UiTheme.TONE_DARK), src, "深底原样")


static func frame_tone_tooltip(t: TestCase, root: Window) -> void:
	t.begin("157 补 · 悬浮窗用纸：浅底墨字 —— 主面板与词条小窗都挂墨色字主题，正文里的颜色换成墨水版；石板框是深底不挂")
	var tip := HoverTip.new()
	root.add_child(tip)
	var src := "[color=#%s]生命 10[/color]\n普通字" % UiPalette.HP.to_html(false)
	tip.show_text(src, Vector2(40, 40), null, [{"name": "灼烧", "text": "每秒掉血"}])
	t.eq(tip.tone(), UiTheme.TONE_LIGHT, "悬浮窗是浅底")
	t.check(tip.text().contains(UiTheme.ink_color(UiPalette.HP).to_html(false)) and not tip.text().contains(UiPalette.HP.to_html(false)), "正文的红换成墨水版")
	var rich := _first_rich(tip)
	t.check(rich != null and rich.get_theme_color("default_color", rich.theme_type_variation) == UiTheme.INK, "正文默认字色是墨")
	var cards := 0
	for c in tip.find_children("*", "PanelContainer", true, false):
		if (c as Control).theme_type_variation == UiTheme.PANEL_TOOLTIP:
			t.eq((c as Control).theme, UiTheme.text_theme(UiTheme.TONE_LIGHT), "纸底挂了墨色字主题")
			cards += 1
	t.eq(cards, 2, "主面板 + 一张词条小窗")
	var frame := OverlayFrame.new()
	root.add_child(frame)
	frame.set_title("标题")
	t.eq(frame.theme, null, "石板框深底：不挂字色主题")
	t.check(frame.title_label.get_theme_color("font_color", UiTheme.LABEL_OVERLAY_TITLE).get_luminance() > 0.5, "石板框标题浅色字")
	frame.free()
	tip.free()


static func _first_rich(n: Node) -> RichTextLabel:
	for c in n.find_children("*", "RichTextLabel", true, false):
		return c as RichTextLabel
	return null


static func run_stone(t: TestCase) -> void:
	t.begin("157 补 · 石板样式：整屏底铺 bg_stone（平铺、底色设置给它染色）；PanelDark / PanelLine / PanelHud 换成石板九宫格，内边距照旧；没图照旧纯色")
	var th := UiTheme.build()
	for pair in [[UiTheme.PANEL_DARK, UiTheme.PANEL_MARGIN], [UiTheme.PANEL_LINE, UiTheme.PANEL_LINE_MARGIN], [UiTheme.PANEL_HUD, UiTheme.HUD_MARGIN]]:
		var box := th.get_stylebox("panel", pair[0]) as StyleBoxTexture
		t.check(box != null and box.texture != null, "%s 是石板九宫格" % pair[0])
		if box != null:
			t.eq(box.content_margin_left, float(pair[1]), "%s 内边距照旧 %d（换皮不改排版）" % [pair[0], pair[1]])
		t.eq(UiTheme.tone_of(pair[0]), UiTheme.TONE_DARK, "%s 深底" % pair[0])
	t.eq(String(UiTheme.art_meta(UiTheme.ART_BG).get("tone", "")), "dark", "整屏底的 json 写了深")
	t.check(bool(UiTheme.art_meta(UiTheme.ART_BG).get("tile", false)), "整屏底平铺")
	var rect := ColorRect.new()
	var tile := UiTheme.dress_backdrop(rect)
	t.check(tile != null and tile.stretch_mode == TextureRect.STRETCH_TILE and tile.mouse_filter == Control.MOUSE_FILTER_IGNORE, "纯色底上铺了一层平铺的石板，不挡鼠标")
	var saved_bg := UiPalette.bg_theme
	UiPalette.bg_theme = UiPalette.BG_DEFAULT
	t.check(UiTheme.backdrop_tint().is_equal_approx(Color.WHITE), "默认底色：石板原色")
	UiPalette.bg_theme = "moss"
	UiTheme.tint_backdrop(rect)
	t.check(not tile.self_modulate.is_equal_approx(Color.WHITE) and tile.self_modulate.g > tile.self_modulate.r, "换成苔绿：石板染绿一点")
	UiPalette.bg_theme = saved_bg
	rect.free()
	var saved := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	var flat := UiTheme.build()
	t.check(flat.get_stylebox("panel", UiTheme.PANEL_DARK) is StyleBoxFlat and flat.get_stylebox("panel", UiTheme.PANEL_HUD) is StyleBoxFlat, "没图：平面底")
	var plain := ColorRect.new()
	t.eq(UiTheme.dress_backdrop(plain), null, "没图：整屏底照旧纯色")
	plain.free()
	UiTheme.asset_root = saved


static func frame_nameplate_slots(t: TestCase, root: Window) -> void:
	t.begin("157 补充二 · 名牌：石碑底（PanelNameplate）、肖像位永远在（没图放占位剪影、框照画）、右边徽记位先画框；有图填进框里")
	var plate := Nameplate.new().setup("游兵", "0 档")
	root.add_child(plate)
	t.eq(plate.theme_type_variation, UiTheme.PANEL_NAMEPLATE, "名牌底是 PanelNameplate")
	t.check(plate.get_theme_stylebox("panel") is StyleBoxTexture, "美术的名牌石碑：九宫格")
	t.eq(plate.portrait, null, "没肖像图：portrait 空")
	t.check(plate.portrait_slot != null and plate.portrait_slot.custom_minimum_size == Vector2(64, 64), "肖像位 64×64 在")
	t.check(plate.portrait_slot.placeholder != null, "放的是美术的占位剪影")
	t.check(plate.portrait_slot.frame != null and is_equal_approx(plate.portrait_slot.frame.offset_left, -4.0), "框画在肖像位外扩 4 px")
	t.check(plate.badge_slot != null and plate.badge_slot.custom_minimum_size == Vector2(32, 32) and plate.badge_slot.frame != null, "徽记位 32×32、先画框")
	t.check(plate.badge_slot.picture == null and plate.badge_slot.placeholder == null, "徽记位里空着")
	t.check(plate.get_combined_minimum_size().y >= 64.0, "名牌高至少放得下肖像位")
	var face := ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGBA8))
	plate.setup("游兵", "0 档", face)
	t.check(plate.portrait != null and plate.portrait.texture == face and plate.portrait_slot.placeholder == null, "有图：图填进肖像位，不放占位")
	var saved := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	var bare := PortraitSlot.new(64)
	t.check(bare.frame == null and bare.placeholder == null and bare.picture == null, "没框图、没剪影图：框和剪影自己画")
	bare.free()
	UiTheme.asset_root = saved
	plate.free()

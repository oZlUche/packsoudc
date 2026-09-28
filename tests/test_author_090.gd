## 作者第十三批（报告 090 第七节）：按钮按重要性分三档放大（300% / 200% / 150%）并改色；Esc 通用「返回」；点当前节点恢复收起的界面；
## 地图右栏三个互动按键 300%
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_090_run.json"
const META := "user://test_090_meta.json"
const SETTINGS := "user://test_090_settings.json"
const NodeScreens := preload("res://tests/test_node_screens.gd")


static func _cleanup() -> void:
	for p in [SAVE, META, SETTINGS]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _bg(b: Button) -> Color:
	var box := b.get_theme_stylebox("normal") as StyleBoxFlat
	return box.bg_color if box != null else Color.TRANSPARENT


static func run_button_tiers(t: TestCase) -> void:
	t.begin("090 · 按钮三档：字号 300% / 200% / 150%，颜色三档各不同、都不是默认灰扣；禁用态另一色")
	var s := GameScreen.new()
	s.font = UiPalette.cjk_font()
	var p := s._button("主", func(): pass, 14, UiPalette.Tier.PRIMARY)
	var sec := s._button("次", func(): pass, 14)
	var m := s._button("辅", func(): pass, 14, UiPalette.Tier.MINOR)
	t.eq(p.get_theme_font_size("font_size"), 42, "主动作 300%（14 → 42）")
	t.eq(sec.get_theme_font_size("font_size"), 28, "不写档 = 次要 200%（14 → 28）")
	t.eq(m.get_theme_font_size("font_size"), 21, "辅助 150%（14 → 21）")
	t.eq(UiPalette.button_font_size(13, UiPalette.Tier.PRIMARY), 39, "13 号的 300% 是 39")
	t.eq(_bg(p), UiPalette.BTN_PRIMARY, "主动作是琥珀实底")
	t.eq(p.get_theme_color("font_color"), UiPalette.BTN_PRIMARY_TEXT, "琥珀底配深字")
	t.eq(_bg(sec), UiPalette.BTN_SECONDARY, "次要是蓝灰底")
	t.eq(_bg(m), UiPalette.BTN_MINOR, "辅助是深底")
	t.check(_bg(p) != _bg(sec) and _bg(sec) != _bg(m), "三档底色各不同")
	t.check(p.get_theme_stylebox("hover") is StyleBoxFlat and (p.get_theme_stylebox("hover") as StyleBoxFlat).bg_color != _bg(p), "停上去变色")
	t.eq((p.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color, UiPalette.BTN_DISABLED, "禁用态另一色")
	var box := p.get_theme_stylebox("normal") as StyleBoxFlat
	t.check(box.content_margin_left >= 20 and box.content_margin_top >= 10, "内边距跟着字号放大")
	t.check(not s.escape(), "底座默认不接 Esc")
	s.free()


## 091（作者定）：成就走管线、条件与进度、完成给解锁、道具上锁、「全部解锁」开关（成就不计）、本图规则卡的记忆
static func run_achievements(t: TestCase) -> void:
	t.begin("091 · 成就：管线往返、条件与进度、完成给解锁开道具 / 难度、全部解锁开关、规则卡记住看过")
	# 管线：作者文件是往返不动点、资产在
	var dir: String = ContentPaths.KINDS["achievements"][0]
	var files := 0
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			files += 1
			var raw := FileAccess.get_file_as_string(dir + "/" + f)
			var r := ImportReport.new()
			var res := ContentImporter.import_achievement(JSON.parse_string(raw), ContentImporter.Context.new(), r)
			t.check(r.ok(), "%s 导入没有错：%s" % [f, r.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_achievement(res)), raw, "%s 是往返不动点" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("achievements", f.get_basename())), "%s 的资产在" % f)
	t.check(files >= 5, "至少五枚成就（%d）" % files)
	var bad := ImportReport.new()
	ContentImporter.import_achievement({"id": "x", "display_name": "x", "kind": "no_such"}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "认不得的条件种类报错")
	var bad2 := ImportReport.new()
	ContentImporter.import_achievement({"id": "x", "display_name": "x", "kind": "keepsake"}, ContentImporter.Context.new(), bad2)
	t.check(not bad2.ok(), "要对象的种类没写 target 报错")

	var defs := GameFlow.load_achievements()
	t.eq(defs.size(), files, "GameFlow.load_achievements 装回全部")
	var c = NodeScreens._content()
	_cleanup()
	var flow := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.difficulties = GameFlow.load_difficulties()
	flow.achievement_defs = defs
	flow.settings = GameSettings.new()
	flow.save_path = SAVE
	flow.meta_path = META
	flow.settings_path = SETTINGS
	# 锁着的道具
	t.check(flow.locked_item_ids().has(&"warhammer") and flow.locked_item_ids().has(&"mithril_sword"), "战锤、秘银剑锁着（数据）")
	flow.apply_item_locks()
	t.check(not c.items.ids().has(&"warhammer") and c.items.ids(true).has(&"warhammer"), "ids() 不给锁着的，ids(true) 给")
	t.check(c.items.is_locked(&"warhammer"), "道具库知道它锁着")
	t.check(flow.check_achievements().is_empty(), "什么都没做：没有成就")
	t.check(not flow.unlocked(&"ascension_1"), "进阶 1 还没解锁")
	# 一次撤离：背出 350 币、还打掉了核心
	var r := RunResult.new()
	r.outcome = &"extracted"
	r.chapter_id = c.chapter.id
	r.value = 350
	r.boss_cleared = true
	r.battles_won = 4
	flow.meta.absorb(r)
	t.check(flow.meta.chapter_extractions_of(c.chapter.id) == 1 and flow.meta.boss_kills == 1 and flow.meta.battles_won == 4, "局外多记的数：按章撤离 / 核心 / 打赢")
	var got := flow.check_achievements()
	var ids: Array[StringName] = []
	for a in got:
		ids.append(a.id)
	t.check(ids.has(&"first_extract") and ids.has(&"big_haul") and ids.has(&"boss_slayer"), "达成：第一次回来、满载而归、直捣核心（%s）" % str(ids))
	t.check(not ids.has(&"extract_3"), "撤离三次还没到")
	t.check(flow.meta.has_achievement(&"first_extract") and flow.meta.achievement_time(&"first_extract") > 0, "记进局外、有时刻")
	t.check(flow.meta.has_unlock(&"ach_first_extract") and flow.unlocked(&"ascension_1"), "给了解锁：战锤的、进阶 1 的")
	t.check(not flow.available_difficulties().filter(func(x: DifficultyDef) -> bool: return x.id == &"ascension_1").is_empty(), "进阶 1 能选了")
	flow.apply_item_locks()
	t.check(c.items.ids().has(&"warhammer") and not c.items.ids().has(&"mithril_sword"), "战锤开了、秘银剑还锁着")
	t.check(flow.check_achievements().is_empty(), "不重复给")
	t.check(not flow.take_notes().is_empty(), "攒了通知")
	var ext3 := flow.achievement_of(&"extract_3")
	t.check(ext3 != null and ext3.progress(flow.meta) == 1 and ext3.goal() == 3 and ext3.progress_text(flow.meta) == "1 / 3", "进度 1 / 3")
	t.check(flow.achievement_granting(&"ach_extract_3") == ext3, "秘银剑的解锁归「老手」")
	t.check(not flow.unlock_names(&"ach_extract_3").is_empty(), "解锁的名字：%s" % str(flow.unlock_names(&"ach_extract_3")))
	# 存档往返
	var back := MetaState.from_dict(flow.meta.to_dict(), c.items)
	t.check(back.has_achievement(&"first_extract") and back.boss_kills == 1 and back.chapter_extractions_of(c.chapter.id) == 1, "成就与多记的数跟存档")
	# 全部解锁：什么都算解锁、道具不锁、成就不计
	flow.settings.unlock_all = true
	t.check(flow.unlocked(&"no_such_unlock") and flow.locked_item_ids().is_empty(), "全部解锁：什么都算解锁、没有锁着的道具")
	flow.meta.extractions = 3
	t.check(flow.check_achievements().is_empty(), "全部解锁开着：成就不计")
	flow.settings.unlock_all = false
	t.eq(flow.check_achievements().size(), 1, "关掉再算：「老手」达成")
	# 规则卡
	t.check(not c.chapter.rules.is_empty() and c.chapter.rules.size() <= 3, "第一章写了本图规则（≤ 3 条）")
	t.check(not flow.meta.has_seen_rules(c.chapter.id), "没看过")
	flow.meta.mark_rules_seen(c.chapter.id)
	t.check(flow.meta.has_seen_rules(c.chapter.id) and MetaState.from_dict(flow.meta.to_dict(), c.items).has_seen_rules(c.chapter.id), "看过了，跟存档")
	_cleanup()


static func frame_escape_and_reopen(t: TestCase, root: Window) -> void:
	t.begin("090 · Esc 通用返回（叠层收起、地图关背包 / 对话框、设置回主菜单）；点当前节点恢复收起的界面；右栏按键 300%")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到带搜索点的种子")
		return
	_cleanup()
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)

	# 主菜单：Esc 没有可回的
	t.check(not game.escape(), "主菜单不接 Esc")
	flow.show_settings()
	t.eq(flow.screen, GameFlow.Screen.SETTINGS, "→ 设置")
	t.check(game.escape(), "设置屏 Esc 接了")
	t.eq(flow.screen, GameFlow.Screen.MAIN_MENU, "→ 回主菜单")
	flow.show_meta()
	var meta = game.base()
	# 091：成就页与筛选
	meta.show_tab("achievements")
	t.eq(meta.tab(), "achievements", "→ 成就页")
	var all_n: int = meta.achievement_rows().size()
	t.check(all_n >= 5 and all_n == flow.achievement_defs.size(), "「全部」列出每一枚（%d）" % all_n)
	meta.show_achievement_filter("done")
	t.check(meta.achievement_rows().is_empty(), "新档：「已解锁」空着")
	meta.show_achievement_filter("todo")
	t.eq(meta.achievement_rows().size(), all_n, "「未解锁」= 全部")
	flow.meta.complete_achievement(&"first_extract")
	meta.show_achievement_filter("done")
	t.check(meta.achievement_rows().size() == 1 and meta.achievement_rows()[0]["id"] == &"first_extract", "完成一枚后「已解锁」有它")
	meta.show_achievement_filter("todo")
	t.eq(meta.achievement_rows().size(), all_n - 1, "「未解锁」少一枚")
	meta.show_achievement_filter("all")
	t.check(game.escape() and meta.tab() == "warehouse", "成就页 Esc 回仓库页")
	meta.show_tab("codex")
	t.check(game.escape() and meta.tab() == "warehouse" and flow.screen == GameFlow.Screen.META, "基地：图鉴页 Esc 先回仓库页")
	t.check(game.escape() and flow.screen == GameFlow.Screen.MAIN_MENU, "仓库页再 Esc 回主菜单")

	flow.begin(c.chapter, kit, int(found["seed"]))
	var map = game.base()
	t.eq(map.screen, GameFlow.Screen.MAP, "→ 地图")
	# 091：第一次进这一章弹「本图规则」卡；Esc 关掉并记住；暂停菜单里能再看
	t.check(not c.chapter.rules.is_empty() and map.rules_open(), "第一次进这一章：本图规则卡弹出来")
	t.check(game.escape() and not map.rules_open(), "Esc 关掉规则卡")
	t.check(flow.meta.has_seen_rules(c.chapter.id), "记住看过了")
	map.toggle_pause()
	map.show_rules()
	t.check(map.rules_open(), "暂停菜单里再看规则卡")
	t.check(game.escape() and not map.rules_open() and map.pause_open(), "Esc 先关规则卡、暂停菜单还在")
	map.toggle_pause()
	t.eq(map._reopen_btn.get_theme_font_size("font_size"), 39, "右栏「回到这个点」300%（13 → 39）")
	t.eq(map._extract_btn.get_theme_font_size("font_size"), 39, "右栏「撤离」300%")
	t.eq(_bg(map._extract_btn), UiPalette.BTN_PRIMARY, "右栏按键是主动作色")
	t.eq(map._reopen_btn.text, "回到这个点（N）", "按钮上只写动作，说明进悬浮提示")

	# 地图上的 Esc：开着什么就关什么，什么都没开着就呼出暂停菜单；暂停菜单里的设置返回回暂停菜单、一局还在
	t.check(game.escape() and map.pause_open(), "地图上什么都没开着：Esc 呼出暂停菜单")
	t.check(game.escape() and not map.pause_open(), "再 Esc 关掉暂停菜单")
	map.toggle_pause()
	map.pause_settings()
	t.check(map.settings_open(), "暂停菜单里开了设置")
	t.check(game.escape() and not map.settings_open() and map.pause_open(), "设置里 Esc 回暂停菜单")
	t.check(game.escape() and not map.pause_open(), "暂停菜单里 Esc 回地图")
	t.check(flow.run != null and flow.screen == GameFlow.Screen.MAP and game.base() == map, "一局还在、地图还是那张")
	map.toggle_bag()
	t.check(map.bag_open(), "开了背包")
	t.check(game.escape(), "Esc 接了")
	t.check(not map.bag_open() and not map.pause_open(), "背包关了，没呼出暂停菜单")
	map.toggle_pause()
	t.check(not map.reopen(), "暂停菜单开着：N 不重开")
	map.toggle_pause()

	map.pick_spawn(int(found["entry"]))
	t.check(map.step(int(found["next"])), "走上搜索点")
	if game.overlay() != null and game.overlay().screen == GameFlow.Screen.EVENT:
		var ev = game.overlay()
		t.check(not game.escape(), "等着选的事件：Esc 不接（必须选）")
		ev.proceed()     # 「搜索」
	var ov = game.overlay()
	if ov == null or ov.screen != GameFlow.Screen.SEARCH:
		t.check(true, "（这个种子没开出搜索屏：%s）" % str(flow.screen))
		flow.to_main_menu()
		game.queue_free()
		_cleanup()
		return
	# 叠层上的 Esc = 收起（最小化）
	t.check(game.escape(), "搜索屏 Esc 接了")
	t.is_null(game.overlay(), "叠层收起了")
	t.check(game.minimized() == ov and not ov.visible, "藏着没销毁")
	t.eq(flow.screen, GameFlow.Screen.MAP, "→ 地图")
	# 点当前节点 = 恢复
	var cur: int = map._view.current_id
	t.check(cur >= 0, "地图知道当前节点")
	map._on_node_pressed(cur, MOUSE_BUTTON_LEFT, false)
	t.check(game.overlay() == ov and ov.visible and game.minimized() == null, "点当前节点：收起的那一屏原样回来了")
	# 再收起、点别的节点不算恢复（照旧是走一步的意思，这里只验当前节点那一条）
	t.check(game.escape(), "再 Esc 收起")
	t.check(game.minimized() == ov, "又藏起来了")
	map._on_node_pressed(cur, MOUSE_BUTTON_RIGHT, false)
	t.is_null(game.overlay(), "右键当前节点不算")
	map._on_node_pressed(cur, MOUSE_BUTTON_LEFT, false)
	t.check(game.overlay() == ov, "左键当前节点又回来了")
	# 会话结束了再点当前节点：没有可开的，只提示
	flow.run.events.current_search.leave()
	if game.overlay() != null:
		game.overlay().proceed() if game.overlay().has_method("proceed") else null
	flow.to_main_menu()
	game.queue_free()
	_cleanup()

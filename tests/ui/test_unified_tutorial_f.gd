## 统一教程 F（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §8.2、§12.1）：
## 局内暂停菜单也有「跳过剩余教程」（同一张确认页，多一句这一局的东西不带出来；确认 = 这一局悄悄结束、补奖励、回基地）；
## 切片老档不锁出战，「上回出征」上多一个「体验统一教程」，点了直接开最早一段没通的教程
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const PREFIX := "unified_f"


static func frame_pause_skip(t: TestCase, root: Window) -> void:
	t.begin("统一教程 F · 局内暂停菜单「跳过剩余教程」：先确认（列奖励、写明这一局的东西不带出来），取消不动；确认后不记场次、补齐奖励、回基地")
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load("res://ui/game/game.tscn").instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.settings.ui_fades = false
	flow.meta.set_flag(GameFlow.TUTORIAL_ASKED)
	var first := flow.tutorial_gate()
	t.not_null(first, "有教程")
	if first == null:
		game.queue_free()
		return
	t.not_null(flow.begin_direct(first), "开了第一段")
	var map = game.base()
	var runs := flow.meta.runs
	var funds := flow.meta.funds
	t.check(map.can_skip_tutorial(), "教程局里能跳")
	map.toggle_pause()
	t.check(map.pause_open(), "暂停菜单开着")
	map.show_skip_tutorial()
	t.check(map.skip_tutorial_open(), "先弹确认页")
	var page: Control = map.find_child("SkipTutorial", true, false)
	t.not_null(page.find_child("TutorialReward", true, false) if page != null else null, "列出要补的奖励")
	var texts: Array = page.find_children("*", "RichTextLabel", true, false).map(func(l: RichTextLabel) -> String: return l.get_parsed_text()) if page != null else []
	t.check(texts.any(func(x: String) -> bool: return x.contains(TextTemplate.plain(UiText.t("skip_tut.in_run"), {}))), "写明这一局的东西不带出来")
	t.check(map.escape() and not map.skip_tutorial_open(), "Esc：接着学")
	t.check(flow.in_run() and flow.tutorial_gate() == first and flow.meta.funds == funds, "取消什么也不动")
	map.show_skip_tutorial()
	map.confirm_skip_tutorial()
	t.check(flow.tutorials_done(), "三段都通了")
	t.eq(flow.meta.funds, funds + 450, "补了三段的 450")
	t.eq(flow.meta.runs, runs, "不记场次")
	t.is_null(flow.run, "这一局没了")
	t.eq(flow.screen, GameFlow.Screen.META, "回基地")
	game.queue_free()
	Support.cleanup(PREFIX)


static func frame_legacy_try(t: TestCase, root: Window) -> void:
	t.begin("统一教程 F · 切片老档：不锁出战，「上回出征」上有「体验统一教程」，点了开第一段；正式版、新切片档没有这个键")
	var f := W178._flow()
	f.profile = SliceProfile.SLICE
	f.chapters = GameFlow.load_chapters(SliceProfile.SLICE)
	f.loadouts = GameFlow.load_loadouts()
	f.meta.runs = 1
	f._open_legacy_slice()
	t.is_null(f.tutorial_gate(), "老档不锁")
	t.not_null(f.legacy_tutorial(), "但第一段还能体验")
	var s: Control = W178._screen(f, root)
	var board: ExpeditionBoard = s.expedition_board()
	t.check(board.last_plate != null and board.try_btn != null, "上回出征上有「体验统一教程」")
	s.queue_free()
	t.check(f.try_tutorial(), "点了：开局")
	t.check(f.run != null and f.run.chapter.id == f.legacy_tutorial().id, "开的是第一段")
	W178._cleanup()
	for prof in [&"", SliceProfile.SLICE]:
		var g := W178._flow()
		g.profile = prof
		g.chapters = GameFlow.load_chapters(prof)
		g.loadouts = GameFlow.load_loadouts()
		t.is_null(g.legacy_tutorial(), "%s 新档：没有体验键（教程本来就锁着）" % prof)
		t.eq(g.try_tutorial(), false, "%s 新档：不做事" % prof)
		W178._cleanup()

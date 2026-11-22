## 统一教程 D 批（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §8）：基地出征页 ——
## 教程没全通时摆「下一段 · 教程 n/3」木牌和「跳过剩余教程」；跳过先弹确认页（列出补的金币和道具），取消什么也不动，确认后留在基地
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")


static func _flow(p_profile: StringName = &"") -> GameFlow:
	var f := W178._flow()
	f.profile = p_profile
	f.chapters = GameFlow.load_chapters(p_profile)
	f.loadouts = GameFlow.load_loadouts()
	return f


static func frame_expedition_card(t: TestCase, root: Window) -> void:
	t.begin("统一教程 D · 出征页：教程木牌写下一段与「教程 1/2」；跳过先确认，取消不动，确认补奖励、留在基地、木牌换回「上回出征」")
	for p in [&"", SliceProfile.SLICE]:
		var f := _flow(p)
		var s: Control = W178._screen(f, root)
		var board: ExpeditionBoard = s.expedition_board()
		t.check(board.tutorial_plate != null and board.last_plate == null, "%s：教程木牌顶替上回出征" % p)
		var texts: Array = board.tutorial_plate.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		t.check(texts.has(UiText.t("meta.tutorial_step") % [1, 2]), "%s：写着第一段（%s）" % [p, texts])
		board.skip_btn.pressed.emit()
		t.check(s.skip_tutorial_open(), "%s：点跳过先弹确认页" % p)
		t.not_null(s.find_child("TutorialReward", true, false), "%s：确认页列出要补的奖励" % p)
		s.close_skip_tutorial()
		t.check(not s.skip_tutorial_open() and f.tutorial_gate() != null and f.meta.funds == 0, "%s：取消什么也不动" % p)
		board.skip_btn.pressed.emit()
		s.confirm_skip_tutorial()
		t.check(f.tutorials_done() and f.meta.funds == 250, "%s：确认：两段都通了，补了 250" % p)
		t.eq(f.screen, GameFlow.Screen.META, "%s：留在基地" % p)
		t.is_null(f.run, "%s：没开局" % p)
		s.queue_free()
		var again: Control = W178._screen(f, root)
		t.check(again.expedition_board().tutorial_plate == null and again.expedition_board().last_plate != null, "%s：再进基地：换回上回出征" % p)
		t.eq(f.skip_remaining_tutorials(), false, "%s：全通了再跳：不做事" % p)
		again.queue_free()
		W178._cleanup()


static func frame_second_step(t: TestCase, root: Window) -> void:
	t.begin("统一教程 D · 第一段通了：木牌写「教程 2/2」，跳过只补剩下的 150")
	var f := _flow()
	f.meta.grant_unlock(&"prologue_done")
	TutorialRewards.mark(f.meta, &"prologue", TutorialRewards.COMPLETED)
	var s: Control = W178._screen(f, root)
	var board: ExpeditionBoard = s.expedition_board()
	var texts: Array = board.tutorial_plate.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.check(texts.has(UiText.t("meta.tutorial_step") % [2, 2]), "写着第二段")
	t.check(texts.has(Names.of(f.chapter_of(&"prologue_2"))), "写着第二段的图名")
	t.eq(int(f.skip_preview()["funds"]), 150, "跳过补 150")
	s.queue_free()
	W178._cleanup()


static func frame_skip_after_first_run(t: TestCase, root: Window) -> void:
	t.begin("游戏测试 v6.38 · 打完第一段、结算后直接回基地点跳过：照样跳（打完的那一局不算在局里）；跳过后出征页和碑当场换新")
	var c := TestSupport.load_content("prologue", ["characters", "events", "faiths", "loadouts", "meta_rules"])
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new(c.meta_rules))
	f.meta_rules = c.meta_rules
	f.chapters = GameFlow.load_chapters()
	f.characters = c.characters
	f.event_defs = c.events
	f.loadouts = c.loadouts
	f.tech_defs = GameFlow.load_techs()
	f.save_path = "user://test_unified_d_run.json"
	f.meta_path = W178.META
	f.settings_path = W178.SETTINGS
	f.new_run()
	t.check(f.run != null and f.choose_event(0), "开了第一段、过了开场")
	if f.run == null:
		return
	f.run.travel.start_at(f.run.map.goal_ids[0])
	t.check(f.extract(), "撤离")
	f.finish_result()
	t.eq(f.screen, GameFlow.Screen.META, "回基地")
	t.check(f.run != null and not f.in_run(), "打完的那一局还留着，但不算在局里")
	var funds := f.meta.funds
	var s: Control = W178._screen(f, root)
	t.eq(s.expedition_board().tutorial_plate.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == UiText.t("meta.tutorial_step") % [2, 2]).size(), 1, "木牌写着第二段")
	s.show_skip_tutorial()
	s.confirm_skip_tutorial()
	t.check(f.tutorials_done(), "跳过成了：两段都通了")
	t.eq(f.meta.funds, funds + 150, "补了剩下一段的 150")
	t.check(s.expedition_board().tutorial_plate == null and s.expedition_board().last_plate != null, "出征页当场换回上回出征")
	t.check(s.expedition_board().skip_btn == null, "跳过键没了")
	s.queue_free()
	if FileAccess.file_exists(f.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f.save_path))
	W178._cleanup()

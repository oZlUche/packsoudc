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
	t.begin("统一教程 D · 出征页：教程木牌写下一段与「教程 1/3」；跳过先确认，取消不动，确认补奖励、留在基地、木牌换回「上回出征」")
	for p in [&"", SliceProfile.SLICE]:
		var f := _flow(p)
		var s: Control = W178._screen(f, root)
		var board: ExpeditionBoard = s.expedition_board()
		t.check(board.tutorial_plate != null and board.last_plate == null, "%s：教程木牌顶替上回出征" % p)
		var texts: Array = board.tutorial_plate.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		t.check(texts.has(UiText.t("meta.tutorial_step") % [1, 3]), "%s：写着第一段（%s）" % [p, texts])
		board.skip_btn.pressed.emit()
		t.check(s.skip_tutorial_open(), "%s：点跳过先弹确认页" % p)
		t.not_null(s.find_child("TutorialReward", true, false), "%s：确认页列出要补的奖励" % p)
		s.close_skip_tutorial()
		t.check(not s.skip_tutorial_open() and f.tutorial_gate() != null and f.meta.funds == 0, "%s：取消什么也不动" % p)
		board.skip_btn.pressed.emit()
		s.confirm_skip_tutorial()
		t.check(f.tutorials_done() and f.meta.funds == 450, "%s：确认：三段都通了，补了 450" % p)
		t.eq(f.screen, GameFlow.Screen.META, "%s：留在基地" % p)
		t.is_null(f.run, "%s：没开局" % p)
		s.queue_free()
		var again: Control = W178._screen(f, root)
		t.check(again.expedition_board().tutorial_plate == null and again.expedition_board().last_plate != null, "%s：再进基地：换回上回出征" % p)
		t.eq(f.skip_remaining_tutorials(), false, "%s：全通了再跳：不做事" % p)
		again.queue_free()
		W178._cleanup()


static func frame_second_step(t: TestCase, root: Window) -> void:
	t.begin("统一教程 D · 第一段通了：木牌写「教程 2/3」，跳过只补剩下的 350")
	var f := _flow()
	f.meta.grant_unlock(&"prologue_done")
	TutorialRewards.mark(f.meta, &"prologue", TutorialRewards.COMPLETED)
	var s: Control = W178._screen(f, root)
	var board: ExpeditionBoard = s.expedition_board()
	var texts: Array = board.tutorial_plate.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.check(texts.has(UiText.t("meta.tutorial_step") % [2, 3]), "写着第二段")
	t.check(texts.has(Names.of(f.chapter_of(&"prologue_2"))), "写着第二段的图名")
	t.eq(int(f.skip_preview()["funds"]), 350, "跳过补 350")
	s.queue_free()
	W178._cleanup()

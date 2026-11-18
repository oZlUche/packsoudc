## 统一教程 A 批（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §2 / §8 / §12.1）：
## 切片也走三段教程；出战只开最早没通的一段；跳过 / 「继续」都回基地；玩过切片的老档不被锁
extends RefCounted

const SAVE := "user://test_unified_a_run.json"
const META := "user://test_unified_a_meta.json"


static func _flow(p_profile: StringName) -> GameFlow:
	var c := TestSupport.load_content()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.profile = p_profile
	f.chapters = GameFlow.load_chapters(p_profile)
	f.characters = GameFlow.load_characters()
	f.event_defs = c.events
	f.save_path = SAVE
	f.meta_path = META
	return f


static func _cleanup() -> void:
	for p in [SAVE, META]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func _ids(list: Array[ChapterDef]) -> Array:
	return list.map(func(c: ChapterDef) -> StringName: return c.id)


static func run_slice_gate(t: TestCase) -> void:
	t.begin("统一教程 A · 切片新档：只开第一段；切片地图要三段通了或跳过才开；跳过后补齐解锁、常规图开")
	var f := _flow(SliceProfile.SLICE)
	var ruins := f.chapter_of(&"slice_ruins")
	t.not_null(ruins, "切片有自己的地图")
	t.eq(_ids(f.available_chapters()), [&"prologue"], "新档出战只列第一段")
	t.check(f.new_run_target() != null and f.new_run_target().id == &"prologue", "出战开第一段")
	t.check(not f.tutorial_allows(ruins), "切片地图锁着")
	t.check(f.start_refusal(ruins, [], null) != "", "直接开切片地图也被拦")
	f.meta.grant_unlock(&"prologue_done")
	t.eq(_ids(f.available_chapters()), [&"prologue_2"], "第一段通了：只列第二段")
	f.skip_prologue()
	t.check(f.tutorials_done() and f.tutorial_gate() == null, "跳过：三段都算通了")
	t.eq(_ids(f.available_chapters()), [&"slice_ruins"], "切片地图开了")
	t.check(f.tutorial_allows(ruins) and f.start_refusal(ruins, [], null) == "", "能出切片地图")


static func run_legacy_slice(t: TestCase) -> void:
	t.begin("统一教程 A · 玩过切片的老档：不锁常规出战，不发教程奖励；正式版老档不受影响")
	var f := _flow(SliceProfile.SLICE)
	f.meta.runs = 2
	f._open_legacy_slice()
	var ruins := f.chapter_of(&"slice_ruins")
	t.check(f.tutorial_gate() == null and f.tutorial_allows(ruins), "老切片档：切片地图照旧能出")
	t.check(f.available_chapters().has(ruins), "列得出切片地图")
	t.eq(f.meta.warehouse.item_count(), 0, "不发教程物品")
	t.eq(f.meta.funds, 0, "不发教程金币")
	var fresh := _flow(SliceProfile.SLICE)
	fresh._open_legacy_slice()
	t.check(fresh.tutorial_gate() != null, "没出过远征的切片档照常走教程")
	var formal := _flow(&"")
	formal.meta.runs = 5
	formal._open_legacy_slice()
	t.check(formal.tutorial_gate() != null and formal.meta.flag(GameFlow.SLICE_LEGACY) == 0, "正式版老档不碰")


static func run_back_to_base(t: TestCase) -> void:
	t.begin("统一教程 A · 没有局内存档时「继续」进基地、不开下一段；开场跳过也回基地")
	var f := _flow(&"")
	f.meta.grant_unlock(&"prologue_done")
	t.check(not f.continue_run(), "「继续」不直接开第二段")
	f.show_meta()
	t.eq(f.screen, GameFlow.Screen.META, "在基地")
	t.is_null(f.run, "没开局")
	var g := _flow(&"")
	g.decline_tutorial()
	t.eq(g.screen, GameFlow.Screen.META, "跳过全部教程：回基地")
	t.check(g.tutorials_done(), "跳过后三段都算通了")
	_cleanup()

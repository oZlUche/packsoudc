## 313（试玩切片 S1 第二批）：切片档案开关 —— 默认是正式版；切片只列切片章节、存档位和设置另放（不碰正式版的存档）、基地只留出征和仓库
extends RefCounted

const META := "user://test_313_meta.json"
const SETTINGS := "user://test_313_settings.json"


static func run_switch(t: TestCase) -> void:
	t.begin("313 · 档案开关：不带特性、不带命令行就是正式版；切片的存档位、设置、页签")
	SliceProfile.forced = null
	t.eq(SliceProfile.current(), &"", "测试里不带 slice：正式版")
	SliceProfile.forced = SliceProfile.SLICE
	t.eq(SliceProfile.current(), &"slice", "强制成切片")
	SliceProfile.forced = null
	t.eq(SliceProfile.slots_root(&""), SaveSlots.DEFAULT_ROOT, "正式版存档位照旧")
	t.eq(SliceProfile.slots_root(&"slice"), "user://slice/slots", "切片存档位另放")
	t.eq(SliceProfile.settings_path(&"", GameSettings.DEFAULT_PATH), GameSettings.DEFAULT_PATH, "正式版设置照旧")
	t.eq(SliceProfile.settings_path(&"slice", GameSettings.DEFAULT_PATH), "user://slice/settings.json", "切片设置另放")
	t.eq(SliceProfile.settings_path(&"slice", SETTINGS), SETTINGS, "测试改过的路径不动")
	t.check(SliceProfile.keeps_tab(&"", "logistics") and SliceProfile.keeps_tab(&"", "shelf"), "正式版四个页签都在")
	t.check(SliceProfile.keeps_tab(&"slice", "expedition") and SliceProfile.keeps_tab(&"slice", "warehouse"), "切片留出征、仓库")
	t.check(not SliceProfile.keeps_tab(&"slice", "logistics") and not SliceProfile.keeps_tab(&"slice", "shelf"), "切片没有后勤、书架")


static func run_saves(t: TestCase) -> void:
	t.begin("313 · 切片的存档位和正式版的不重叠：每一位的局内、局外文件都在 user://slice/ 底下")
	var formal := SaveSlots.new()
	var slice := SaveSlots.new(SliceProfile.slots_root(&"slice"))
	for n in range(1, SaveSlots.COUNT + 1):
		t.check(slice.run_path(n).begins_with("user://slice/") and slice.meta_path(n).begins_with("user://slice/"), "第 %d 位在切片目录里" % n)
		t.check(slice.run_path(n) != formal.run_path(n) and slice.meta_path(n) != formal.meta_path(n), "第 %d 位和正式版不是同一个文件" % n)


static func run_chapters(t: TestCase) -> void:
	t.begin("313 · 两档的章节表不相交：正式版没有切片章节，切片只有切片章节")
	var formal := GameFlow.load_chapters()
	var slice := GameFlow.load_chapters(&"slice")
	t.check(not slice.is_empty(), "切片有章节")
	t.check(slice.all(func(c: ChapterDef) -> bool: return c.profile == &"slice"), "切片表里都是切片章节")
	t.check(formal.all(func(c: ChapterDef) -> bool: return c.profile == &""), "正式版表里没有切片章节")


static func _flow(p_profile: StringName) -> GameFlow:
	var db := ItemDatabase.new()
	db.load_dir()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	f.profile = p_profile
	return f


static func _tabs(f: GameFlow, root: Window) -> Array:
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	var keys: Array = screen._tab_btns.keys()
	var tab: String = screen.tab()
	root.remove_child(screen)
	screen.free()
	return [keys, tab]


static func frame_base_tabs(t: TestCase, root: Window) -> void:
	t.begin("313 · 切片的基地只有出征和仓库两个页签，默认在出征页；正式版照旧四个")
	var formal := _tabs(_flow(&""), root)
	t.eq(formal[0], ["expedition", "warehouse", "logistics", "shelf"], "正式版四个页签")
	var slice := _tabs(_flow(&"slice"), root)
	t.eq(slice[0], ["expedition", "warehouse"], "切片两个页签")
	t.eq(slice[1], "expedition", "默认在出征页")
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)

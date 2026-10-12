## 158：类缓存由游戏自己写（扫脚本头，不起编辑器）、缺素材才后台导入。
## `tools/test.sh` 先 `--import`，所以跑测试时 `.godot/global_script_class_cache.cfg` 是编辑器刚写的 —— 拿它逐条对照
extends RefCounted

const ClassCache := preload("res://tools/class_cache.gd")
const ImportCheck := preload("res://tools/import_check.gd")
const TMP := "user://test_158/"


static func run(t: TestCase) -> void:
	t.begin("158 · 扫脚本头写出的类缓存和编辑器写的那份逐条相同（class、base、path、is_tool、is_abstract、icon、language），写出来逐字节一样")
	var t0 := Time.get_ticks_msec()
	var mine := ClassCache.scan()
	var ms := Time.get_ticks_msec() - t0
	t.check(ms < 3000, "扫全项目 %d ms（不起编辑器）" % ms)
	var editor := ClassCache.read()
	t.check(editor.size() > 100, "编辑器那份在（%d 条）" % editor.size())
	t.eq(mine.size(), editor.size(), "条数一样")
	var bad: Array[String] = []
	for e in mine:
		var k := String(e["class"])
		if not editor.has(k) or str(editor[k]) != str(e):
			bad.append(k)
	t.eq(bad, [] as Array[String], "逐条相同")
	DirAccess.make_dir_recursive_absolute(TMP)
	t.eq(ClassCache.write(mine, TMP + "cache.cfg"), OK, "写得出")
	t.eq(FileAccess.get_file_as_string(TMP + "cache.cfg"), FileAccess.get_file_as_string(ClassCache.CACHE_PATH), "和编辑器写的逐字节一样")
	t.eq(ClassCache.write(mine, TMP + "nested/.godot/cache.cfg"), OK, "目录不在先建")

	t.begin("158 · 文件头的几种写法：class_name 与 extends 同一行、@tool / @abstract / @icon、路径式 extends（找父脚本的类名）、没写 extends 是 RefCounted")
	DirAccess.make_dir_recursive_absolute(TMP + "src")
	_put(TMP + "src/a.gd", "## 说明\n@tool\nclass_name TmpA extends Node2D\n\nvar x := 1\n")
	_put(TMP + "src/b.gd", "@abstract\n@icon(\"res://icon.svg\")\nclass_name TmpB\nextends \"%s\"\n" % (TMP + "src/a.gd"))
	_put(TMP + "src/c.gd", "class_name TmpC\n")
	_put(TMP + "src/d.gd", "extends \"%s\"\n" % (TMP + "src/a.gd"))
	_put(TMP + "src/e.gd", "class_name TmpE\nextends \"%s\"\n" % (TMP + "src/d.gd"))
	_put(TMP + "src/f.gd", "extends Node\n@export var later := 1\nclass_name NotHead\n")
	var got := {}
	for e in ClassCache.scan(TMP + "src"):
		got[String(e["class"])] = e
	t.eq(got.keys().size(), 4, "四个有 class_name（成员后面的不算文件头）")
	t.check(got.has("TmpA") and got["TmpA"]["base"] == &"Node2D" and got["TmpA"]["is_tool"], "同一行：类名与基类；@tool")
	t.check(got.has("TmpB") and got["TmpB"]["base"] == &"TmpA" and got["TmpB"]["is_abstract"] and got["TmpB"]["icon"] == "res://icon.svg", "路径式 extends → 父脚本的类名；@abstract、@icon")
	t.check(got.has("TmpC") and got["TmpC"]["base"] == &"RefCounted", "没写 extends：RefCounted")
	t.check(got.has("TmpE") and got["TmpE"]["base"] == &"TmpA", "父脚本没类名：接着往上找到有类名的那份")

	t.begin("158 · 有没有没导入的素材：.import 的目标都在 = 导过；目标没了、或新图旁边连 .import 都没有 = 没导")
	t.eq(ImportCheck.missing(), [] as Array[String], "测试前导过：一个不缺")
	var src := "res://assets/ui/frame_stone.png.import"
	t.check(ImportCheck.imported(src), "石板框导过")
	DirAccess.make_dir_recursive_absolute(TMP + "assets")
	var text := FileAccess.get_file_as_string(src)
	_put(TMP + "assets/x.png.import", text.replace(".ctex\"", "_gone.ctex\""))
	t.check(not ImportCheck.imported(TMP + "assets/x.png.import"), "目标不在：没导")
	_put(TMP + "assets/new.png", "")
	t.eq(ImportCheck.missing(TMP + "assets"), [TMP + "assets/new.png", TMP + "assets/x.png"] as Array[String], "两件都算没导")


static func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

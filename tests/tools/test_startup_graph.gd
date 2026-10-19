## 176：启动图。GDScript 没有预编译，主场景引用到的每个全局类在第一帧之前都要从源码编译一遍，
## 所以「启动时碰得到哪些脚本」得守住：
## - 启动屏 `ui/boot.tscn` 一个全局类都不引用（第一帧马上出来，正式游戏在后台线程载）；
## - 正式游戏（`game.tscn` + 自动加载 DevNav、Audio）碰不到编辑器、启动器、导入器 / 导出器 / 表格工具。
## 扫法：从起点出发，脚本里出现的全局类名（去掉字符串与注释）、`preload` / `extends` 的路径、场景与资源里的脚本路径，一路跟下去。
## 运行时 `load()` 的路径不算 —— 那不在启动时编译
extends RefCounted

const ClassCache := preload("res://tools/class_cache.gd")
const DevNavScript := preload("res://ui/dev_nav.gd")
const BOOT := "res://ui/boot.tscn"
const GAME := "res://ui/game/game.tscn"
const DEV_NAV := "res://ui/dev_nav.gd"
const AUDIO := "res://ui/audio.gd"     # 204：第二个自动加载
## 游戏启动时不该编译到的开发工具（编辑器整目录另按路径认）
const FORBIDDEN := [
	"res://core/authoring/content_importer.gd",
	"res://core/authoring/content_exporter.gd",
	"res://core/authoring/authoring_context.gd",
	"res://core/authoring/content_check.gd",
	"res://core/authoring/techs_table.gd",
	"res://core/authoring/xlsx_reader.gd",
	"res://core/authoring/text_lint.gd",
	"res://core/authoring/power_estimate.gd",
	"res://core/authoring/import_report.gd",
	"res://ui/launcher.gd",
]

static var _classes: Dictionary = {}
static var _token_re: RegEx = null
static var _path_re: RegEx = null
static var _scene_re: RegEx = null


## class_name → 脚本路径
static func classes() -> Dictionary:
	if _classes.is_empty():
		for e in ClassCache.scan():
			_classes[String(e["class"])] = String(e["path"])
	return _classes


## 一个脚本 / 场景 / 资源静态引用到的文件
static func deps_of(path: String) -> Array[String]:
	if _token_re == null:
		_token_re = RegEx.create_from_string("(\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'|#[^\\n]*)|\\b([A-Z][A-Za-z0-9_]*)\\b")
		_path_re = RegEx.create_from_string("(?:preload\\(\\s*|^extends\\s+)\"(res://[^\"]+)\"")
		_scene_re = RegEx.create_from_string("path=\"(res://[^\"]+\\.(?:gd|tscn|tres))\"")
	var out: Array[String] = []
	var src := FileAccess.get_file_as_string(path)
	if path.ends_with(".tscn") or path.ends_with(".tres"):
		for m in _scene_re.search_all(src):
			out.append(m.get_string(1))
		return out
	for line in src.split("\n"):
		var m := _path_re.search(line.strip_edges())
		if m != null:
			out.append(m.get_string(1))
	var seen := {}
	for m in _token_re.search_all(src):
		var name := m.get_string(2)
		if name != "" and not seen.has(name) and classes().has(name):
			seen[name] = true
			out.append(classes()[name])
	return out


## 从这些起点静态碰得到的文件：路径 → 谁引用的它（起点是 ""）
static func reachable(starts: Array) -> Dictionary:
	var parent := {}
	var stack: Array = []
	for s in starts:
		stack.append([String(s), ""])
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var p: String = top[0]
		if parent.has(p) or not FileAccess.file_exists(p):
			continue
		parent[p] = top[1]
		for d in deps_of(p):
			if not parent.has(d):
				stack.append([d, p])
	return parent


## 引用链（给失败信息看）：a ← b ← c
static func chain(parent: Dictionary, p: String) -> String:
	var out: Array[String] = []
	var q := p
	while q != "" and out.size() < 8:
		out.append(q.trim_prefix("res://"))
		q = parent.get(q, "")
	return " ← ".join(out)


static func _is_editor(p: String) -> bool:
	return p.begins_with("res://ui/editor/") or (p.begins_with("res://ui/") and p.get_base_dir().ends_with("_editor"))


static func run_boot_isolated(t: TestCase) -> void:
	t.begin("176 · 启动屏一个全局类都不引用：从 boot.tscn 只碰得到它自己的脚本")
	var r := reachable([BOOT])
	var files: Array = r.keys()
	files.sort()
	t.eq(files, ["res://ui/boot.gd", BOOT], "启动屏的图（%s）" % [files])
	t.eq(ProjectSettings.get_setting("application/run/main_scene"), BOOT, "主场景是启动屏")


static func run_game_graph(t: TestCase) -> void:
	t.begin("176 · 正式游戏的启动图（game.tscn + DevNav + Audio）碰不到编辑器、启动器、导入器与导出器")
	var r := reachable([GAME, DEV_NAV, AUDIO])
	t.check(r.has("res://ui/game/game_director.gd") and r.has("res://core/inventory/item_database.gd") and r.has("res://core/authoring/content_library.gd"), "扫得到游戏自己（%d 个文件）" % r.size())
	var bad: Array[String] = []
	for p in r:
		if FORBIDDEN.has(p) or _is_editor(String(p)):
			bad.append(chain(r, p))
	t.check(bad.is_empty(), "不该碰到的：\n%s" % "\n".join(bad))
	# 扫法本身认得出引用：编辑器那头确实碰得到导入器
	var ed := reachable(["res://ui/buff_editor/buff_editor.gd"])
	t.check(ed.has("res://core/authoring/content_importer.gd") and ed.has("res://core/authoring/authoring_context.gd"), "编辑器碰得到导入器（扫法没漏）")


static func run_boot_loads(t: TestCase) -> void:
	t.begin("176 · 启动屏在后台线程载入 game.tscn，载好了拿得到场景、进度到头")
	var boot: Control = load("res://ui/boot.gd").new()
	boot.auto_switch = false
	boot.start()
	t.check(not boot.failed, "发得出后台载入请求")
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	var waited := 0
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and waited < 120000:
		OS.delay_msec(20)
		waited += 20
		status = boot.poll()
	t.eq(status, ResourceLoader.THREAD_LOAD_LOADED, "载好了")
	t.check(boot.scene != null and boot.scene.resource_path == GAME, "拿到的是 game.tscn")
	t.eq(boot.progress, 1.0, "进度到头")
	boot.free()


static func run_export_and_devnav(t: TestCase) -> void:
	t.begin("176 → 200 · 导出预设的脚本是二进制令牌（压缩）；玩家版 / 开发版两个预设；DevNav 和调试台同一把门（DevGate）")
	var cfg := ConfigFile.new()
	t.eq(cfg.load("res://export_presets.cfg"), OK, "有导出预设")
	var n := 0
	for s in cfg.get_sections():
		if s.begins_with("preset.") and s.count(".") == 1:
			n += 1
			t.eq(int(cfg.get_value(s, "script_export_mode", -1)), 2, "%s（%s）脚本导出 = 二进制令牌（压缩）" % [s, cfg.get_value(s, "name", "")])
	t.check(n > 0, "至少一个预设")
	t.check(DevNavScript.keep_in(), "命令行跑（开发包）：留")
	DevGate.force_player = true
	t.check(not DevNavScript.keep_in(), "玩家包：撤掉（和调试台同一把门）")
	DevGate.force_player = false
	# 200：两个预设 —— 玩家版不带 dev、不打包测试；开发版带 dev
	var by_name := {}
	for s in cfg.get_sections():
		if s.begins_with("preset.") and s.count(".") == 1:
			by_name[String(cfg.get_value(s, "name", ""))] = s
	t.check(by_name.has("玩家版") and by_name.has("开发版"), "有「玩家版」「开发版」两个预设（%s）" % [by_name.keys()])
	if by_name.has("玩家版") and by_name.has("开发版"):
		var player: String = by_name["玩家版"]
		var dev: String = by_name["开发版"]
		t.check(not String(cfg.get_value(player, "custom_features", "")).contains("dev"), "玩家版不带 dev 特性")
		t.check(String(cfg.get_value(dev, "custom_features", "")).split(",", false).has("dev"), "开发版带 dev 特性")
		for s in [player, dev]:
			var ex := String(cfg.get_value(s, "exclude_filter", ""))
			t.check(ex.contains("tests/*") and not ex.contains("tools/"), "%s 不打包 tests/，tools/ 留着（DevNav preload 了里面的脚本）" % cfg.get_value(s, "name"))
		t.eq(int(cfg.get_value(player + ".options", "debug/export_console_wrapper", -1)), 0, "玩家版不出控制台包装器")
		t.check(bool(cfg.get_value(player, "runnable", false)) and not bool(cfg.get_value(dev, "runnable", true)), "「运行导出」用玩家版")

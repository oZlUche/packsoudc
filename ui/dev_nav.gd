## 开发期导航：任何场景里都能回启动选择器。
##
## 做成 autoload 而不是让每个场景自己加一个按钮 —— 后者的问题是
## **F6 直接跑某个场景时也得能回去**，而那时没有人替它装这个按钮；
## 漏装的场景表现为「进去就出不来，只能关掉重开」。
##
## 它是开发期的东西。真正的场景流（进关、战斗、结算）是 M6 的事，
## 那时这一层要么退化成调试入口，要么直接删掉。
extends CanvasLayer

const LAUNCHER := "res://ui/launcher.tscn"
## 返回键。不用 Esc：拖拽中的取消是 Esc，编辑器里输入框也可能吃掉它，
## 而「手一滑回到主界面」在编辑器里意味着草稿全没。
const BACK_KEY := KEY_F1

## 有未保存内容时，第一下只是提醒，这段时间内再按一下才真的走
const CONFIRM_WINDOW := 4.0

var _button: Button
var _armed: bool = false
var _armed_left: float = 0.0
## 上一帧的当前场景。用它判断「场景换了没」—— SceneTree 没有现成的信号，
## 而 tree_changed 每加一个节点就响一次，编辑器那种反射表单会把它打爆
var _seen: Node = null
## 094：全局类缓存过期时顶上那条红字（有就说明为什么一片灰 / 一片空白）
var _cache_banner: Label = null
## 扫哪些目录找 class_name
const CLASS_DIRS := ["res://core", "res://ui", "res://tools", "res://tests"]
## 115：重开时带上的用户参数 —— 有它说明已经自救过一次，缓存还缺就别再循环
const REBUILT_FLAG := "cache-rebuilt"
## 「有未保存的改动」的字色（和 UiPalette.STAMINA 同色；115：这个脚本不许引用任何全局类，缓存坏着它也得解析得了）
const WARN_COLOR := Color("f0ad4e")
## 158：类缓存自己写（不起编辑器）、缺素材才后台导入（不挡游戏）。两个脚本都没有 class_name，缓存坏着也拿得到
const ClassCache := preload("res://tools/class_cache.gd")
const ImportCheck := preload("res://tools/import_check.gd")
## 158：后台导新素材的进程（-1 = 没在导）；导完不重开，只撤掉右上角那行小字
var _asset_import_pid: int = -1
var _asset_note: Label = null
## 115：重建时的全屏遮罩
var _rebuild_cover: Control = null


func _ready() -> void:
	layer = 128  # 盖在一切之上
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_class_cache()

	_button = Button.new()
	_button.add_theme_font_override("font", _cjk_font())
	_button.add_theme_font_size_override("font_size", 12)
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.offset_top = 6
	_button.offset_right = -6
	_button.focus_mode = Control.FOCUS_NONE  # 不抢输入框的焦点
	_button.pressed.connect(_request_back)
	add_child(_button)
	_relabel()


func _process(delta: float) -> void:
	if _asset_import_pid > 0 and not OS.is_process_running(_asset_import_pid):
		_asset_import_pid = -1     # 158：新素材导完了，下次启动生效
		if _asset_note != null:
			_asset_note.queue_free()
			_asset_note = null
	var current := get_tree().current_scene
	if current != _seen:
		_seen = current
		_armed = false
		_relabel()
	if _armed:
		_armed_left -= delta
		if _armed_left <= 0.0:
			_armed = false
			_relabel()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == BACK_KEY:
		_request_back()
		get_viewport().set_input_as_handled()


## 场景可以实现 `has_unsaved_changes() -> bool` 来要一次确认。
##
## 用鸭子类型而不是让场景继承什么东西：这一层是开发期脚手架，
## 不该为了一个提示，在正经场景的类型里留下痕迹。
func _request_back() -> void:
	if _is_launcher():
		return
	if not _armed and _dirty():
		_armed = true
		_armed_left = CONFIRM_WINDOW
		_relabel()
		return
	_armed = false
	if get_tree().change_scene_to_file(LAUNCHER) != OK:
		push_error("DevNav: 回不去启动选择器")


## 094：全局类缓存里缺的类（脚本里写了 class_name、缓存里没有）。缺了就是「拉了新脚本没重新导入」——
## 依赖它们的脚本会整体解析失败，表现为灰屏 / 编辑器空白。这里只用内建类型，不碰任何全局类，缓存坏了它也得活着
static func stale_classes() -> Array[String]:
	var known := {}
	for entry in ProjectSettings.get_global_class_list():
		known[String((entry as Dictionary).get("class", ""))] = true
	var missing: Array[String] = []
	var regex := RegEx.new()
	regex.compile("^\\s*class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for root in CLASS_DIRS:
		_scan_dir(root, regex, known, missing)
	missing.sort()
	return missing


static func _scan_dir(path: String, regex: RegEx, known: Dictionary, missing: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = false
	for sub in dir.get_directories():
		_scan_dir(path.path_join(sub), regex, known, missing)
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var fa := FileAccess.open(path.path_join(f), FileAccess.READ)
		if fa == null:
			continue
		var lines := 0
		while not fa.eof_reached() and lines < 40:
			var m := regex.search(fa.get_line())
			lines += 1
			if m != null:
				var cname := m.get_string(1)
				if not known.has(cname) and not missing.has(cname):
					missing.append(cname)
				break


## 115 / 158：后台导入的参数（[code]--headless --path <根> --import[/code]，导完就退）；158 起只在有没导入的素材时用
static func import_args(root: String) -> PackedStringArray:
	return PackedStringArray(["--headless", "--path", root, "--import"])


## 115：导完后重开一份游戏的参数：原来的用户参数照带（`--` 之后），末尾加 [constant REBUILT_FLAG]
static func relaunch_args(root: String, user_args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray(["--path", root, "--"])
	for a in user_args:
		if a != REBUILT_FLAG:
			out.append(a)
	out.append(REBUILT_FLAG)
	return out


## 115：这一份是不是自救重开的（用户参数里有 [constant REBUILT_FLAG]）
static func already_rebuilt(user_args: PackedStringArray) -> bool:
	return user_args.has(REBUILT_FLAG)


func _check_class_cache() -> void:
	if OS.has_feature("template"):
		return     # 导出包里的缓存永远是对的
	if Engine.is_editor_hint():
		return     # 102 B1：编辑器本身打开项目时自己就重建了缓存。115：注意不能拿 OS.has_feature("editor") 当门 ——
		# 用编辑器版的 Godot（作者的 Godot_console.exe）直接跑游戏时它也是 true，那样这条自检就永远不跑了
	var missing := stale_classes()
	if missing.is_empty():
		_check_assets()
		return
	# 158（原 115）：缓存过期就自己修 —— 进程内重写缓存（不到一秒，不起编辑器）、立刻重开；重开过一次还缺就别循环，回落到红字
	if already_rebuilt(OS.get_cmdline_user_args()) or not rewrite_cache():
		_show_stale_banner(missing)


## 158：扫脚本头重写全局类缓存，盖上「已重写」，下一帧带原参数重开。写不了返回 false（调用方回落到红字）
func rewrite_cache() -> bool:
	if ClassCache.write(ClassCache.scan()) != OK:
		push_error("DevNav: 写不了全局类缓存")
		return false
	_show_rebuild_cover("脚本缓存过期，已重写，正在重新打开……")
	_finish_rebuild.call_deferred()
	return true


## 158：有没导入的素材（别人加了图）→ 后台导入，不盖板、不重开；这一次游戏里那几张图走占位，下次启动生效
func _check_assets() -> void:
	var todo := ImportCheck.missing()
	if todo.is_empty():
		return
	var root := ProjectSettings.globalize_path("res://")
	var pid := OS.create_process(OS.get_executable_path(), import_args(root))
	if pid <= 0:
		return
	_asset_import_pid = pid
	_asset_note = Label.new()
	_asset_note.text = "新素材导入中……下次启动生效"
	_asset_note.add_theme_font_override("font", _cjk_font())
	_asset_note.add_theme_font_size_override("font_size", 12)
	_asset_note.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	_asset_note.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_asset_note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_asset_note.offset_top = 34
	_asset_note.offset_right = -8
	_asset_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_asset_note)


func importing_assets() -> bool:
	return _asset_import_pid > 0


func rebuilding() -> bool:
	return _rebuild_cover != null


## 115 / 158：缓存修好了：带着原参数重开一份，自己退出
func _finish_rebuild() -> void:
	var root := ProjectSettings.globalize_path("res://")
	if OS.create_process(OS.get_executable_path(), relaunch_args(root, OS.get_cmdline_user_args())) <= 0:
		push_error("DevNav: 重建完了但重开不了，请手动重新启动")
		if _rebuild_cover != null:
			_rebuild_cover.queue_free()
			_rebuild_cover = null
		_show_stale_banner(stale_classes())
		return
	get_tree().quit()


func _show_rebuild_cover(text: String) -> void:
	var cover := ColorRect.new()
	cover.color = Color(0.06, 0.07, 0.09, 1.0)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	label.add_theme_font_override("font", _cjk_font())
	cover.add_child(label)
	add_child(cover)
	_rebuild_cover = cover


## 回落：缺的类写成一条红字（重建过还缺、或起不来导入进程）
func _show_stale_banner(missing: Array[String]) -> void:
	var names := ", ".join(missing.slice(0, 8)) + ("　等 %d 个" % missing.size() if missing.size() > 8 else "")
	var text := "全局类缓存过期：缺 %s —— 界面会灰屏 / 空白。自动重写没修好：在编辑器里打开一次项目（编辑器自己会重建），或跑一次 tools/test.sh（会先 --import）" % names
	push_error("DevNav: " + text)
	_cache_banner = Label.new()
	_cache_banner.text = text
	_cache_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cache_banner.add_theme_font_size_override("font_size", 16)
	_cache_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.12, 0.12, 0.95)
	style.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", style)
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 36
	box.offset_left = 12
	box.offset_right = -12
	box.add_child(_cache_banner)
	add_child(box)


## 中文字体（同 UiPalette.cjk_font，抄一份：见 [constant WARN_COLOR] 的说明）
static func _cjk_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"])
	return f


func _dirty() -> bool:
	var current := get_tree().current_scene
	return current != null and current.has_method("has_unsaved_changes") \
		and current.call("has_unsaved_changes")


func _is_launcher() -> bool:
	var current := get_tree().current_scene
	return current == null or current.scene_file_path == LAUNCHER


func _relabel() -> void:
	if _button == null:
		return
	_button.visible = not _is_launcher()
	if _armed:
		_button.text = "有未保存的改动 · 再按一次 F1 离开"
		_button.add_theme_color_override("font_color", WARN_COLOR)
	else:
		_button.text = "← 主界面　F1"
		_button.remove_theme_color_override("font_color")

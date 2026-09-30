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


func _ready() -> void:
	layer = 128  # 盖在一切之上
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_class_cache()

	_button = Button.new()
	_button.add_theme_font_override("font", UiPalette.cjk_font())
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


func _check_class_cache() -> void:
	if OS.has_feature("template"):
		return     # 导出包里的缓存永远是对的
	var missing := stale_classes()
	if missing.is_empty():
		return
	var text := "全局类缓存过期：缺 %s —— 界面会灰屏 / 空白。修法：Godot 菜单「项目 → 重新加载当前项目」，或跑 tools/run_game（会先 --import）。缓存文件已进仓库，拉最新的 .godot/global_script_class_cache.cfg 也行" % ", ".join(missing)
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
		_button.add_theme_color_override("font_color", UiPalette.STAMINA)
	else:
		_button.text = "← 主界面　F1"
		_button.remove_theme_color_override("font_color")

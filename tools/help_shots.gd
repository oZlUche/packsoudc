## 377：信仰帮助页的截图，中英各一套 —— 界面改了重跑一遍，不手工截。图写到 `assets/help/shots/<语言>/<名字>.png`
## （[member HelpPageDef.shots] 引用的名字），宽 [constant WIDTH]。要真渲染，不能 --headless：
##
##     xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --script res://tools/help_shots.gd
##
## 截两张：`pantheon_pick` 开局第一屏展开的信仰横条（383；一档信赖：三位神开着，三位写？？？？）；`altar_camp` 奉蛮神的一局里休息点的营地（有神坛）。
## 存档写在 `user://help_shots/`，不碰玩家的存档位。
extends SceneTree

const GAME := "res://ui/game/game.tscn"
const OUT := "res://assets/help/shots/"
const WIDTH := 680
const LANGS := ["zh", "en"]
const SETTLE := 30

var _game: Node = null
var _flow: GameFlow = null
var _lang := 0
var _st := 0
var _wait := 0
var _f := 0
var _failed := false


func _initialize() -> void:
	GameDirector.fades_allowed = false
	_boot()


func _boot() -> void:
	var dir := "user://help_shots/%s/" % LANGS[_lang]
	DirAccess.make_dir_recursive_absolute(dir)
	for f in ["run.json", "meta.json", "settings.json"]:
		DirAccess.remove_absolute(dir + f)
	UiText.lang = LANGS[_lang]
	_game = (load(GAME) as PackedScene).instantiate()
	_game.save_path = dir + "run.json"
	_game.meta_path = dir + "meta.json"
	_game.settings_path = dir + "settings.json"
	root.add_child(_game)
	current_scene = _game
	_st = 0
	_f = 0


func L(s: String) -> void:
	print("HELP_SHOTS [%s] %s" % [LANGS[_lang], s])


## 截 [param rect]（画布坐标；空 = 整屏），缩到 [constant WIDTH] 宽存盘
func _shot(name: String, rect: Rect2 = Rect2()) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		L("取不到视口图像")
		_failed = true
		return
	if rect.has_area():
		var r := Rect2i(root.get_final_transform() * rect).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(r)
	img.resize(WIDTH, int(round(WIDTH * float(img.get_height()) / img.get_width())), Image.INTERPOLATE_LANCZOS)
	var dir := ProjectSettings.globalize_path(OUT + LANGS[_lang])
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.png" % [dir, name]
	if img.save_png(path) != OK:
		L("存不下 %s" % path)
		_failed = true
		return
	L("已存 %s（%dx%d）" % [path, img.get_width(), img.get_height()])


## 新档：教程都算过了、导览和到来通知看过，万神院在营地（一档信赖）
func _prepare() -> void:
	var m := _flow.meta
	_flow.settings.language = LANGS[_lang]
	UiText.lang = LANGS[_lang]
	m.set_flag(GameFlow.TUTORIAL_ASKED)
	_flow.skip_prologue()
	for id in ["base_tour", "god_pick", "level_pick"]:
		if not m.coach_seen.has(id):
			m.coach_seen.append(id)
	m.commissions.arrived[String(Pantheon.FACTION)] = 3
	m.set_flag(StringName("arrival_seen_" + String(Pantheon.FACTION)))
	_flow.save_meta()
	_flow.show_meta()


func _process(_delta: float) -> bool:
	_f += 1
	if _wait > 0:
		_wait -= 1
		return false
	if _f > 6000:
		L("超时，停在第 %d 步" % _st)
		_failed = true
		return _done()
	match _st:
		0:
			if _f < 20:
				return false
			var nav := root.get_node_or_null("DevNav")     # 开发期的「← 主界面 F1」不进截图
			if nav != null and "visible" in nav:
				nav.visible = false
			_flow = _game.flow
			_prepare()
			_wait = SETTLE
			_st = 1
		1:
			var base = _game.base()
			if base == null or not base.has_method("expedition_board"):
				return false
			_flow.new_run()     # 383：选神是开局第一屏的信仰横条
			_wait = SETTLE
			_st = 2
		2:
			var setup = _game.base()
			if setup == null or not setup.has_method("open_bar"):
				return false
			setup.open_bar(&"faith")
			_wait = SETTLE
			_st = 3
		3:
			var setup = _game.base()
			var frame: Control = setup.bar(&"faith")
			_shot("pantheon_pick", frame.get_global_rect().grow(8) if frame != null else Rect2())
			setup.cancel()
			_flow.choose_god(&"brute")
			var ch := _flow.chapter_of(&"free_mode")
			var chars := _flow.characters_for(ch)
			var run := _flow.begin(ch, _flow.default_loadout(), 7, [] as Array[int], chars[0] if not chars.is_empty() else null)
			if run == null:
				L("开不了局")
				_failed = true
				return _done()
			var entry := run.map.entry_ids[0]
			_flow.pick_spawn(entry)
			var rest: MapNode = null
			for nid in run.map.neighbors(entry):
				var node := run.map.get_node(nid)
				if node.type in [&"battle", &"event", &"search"]:
					node.type = &"rest"
					for key in node.content.keys():
						node.content.erase(key)
					node.content["event"] = "rest_default"
					rest = node
					break
			if rest == null or not _flow.step_to(rest.id):
				L("走不到休息点")
				_failed = true
				return _done()
			L("奉的是 %s（选的 %s）" % [String(run.active_faith_id()), String(run.selected_faith)])
			_wait = SETTLE * 2
			_st = 4
		4:
			_shot("altar_camp")
			return _next_lang()
	return false


func _next_lang() -> bool:
	_game.queue_free()
	_game = null
	_lang += 1
	if _lang >= LANGS.size():
		return _done()
	_boot()
	return false


func _done() -> bool:
	quit(1 if _failed else 0)
	return true

extends SceneTree
## 在旧版（v6.71 工作区）上留一份局内存档：新档拒教程 → 直接开自由模式 → 走一步 → 存局 → 回主菜单。参数 <outdir> [seed]
var seed_ := 41
var _game: Node
var _flow
var _f := 0
var _st := 0
var _wait := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1: seed_ = int(a[1])
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 6000: print("MAKE 超时 st %d" % _st); quit(1); return true
	if _wait > 0: _wait -= 1; return false
	var scr: int = _flow.screen
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open(): b.decline_tutorial(); _wait = 30; _st = 2
			elif _f > 240: _flow.decline_tutorial(); _wait = 30; _st = 2
		2:
			if scr != GameFlow.Screen.META: return false
			_flow.begin_direct(_flow.chapter_of(&"free_mode"), seed_); _wait = 30; _st = 3
		3:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			print("MAKE 旧版进图：局内存档版本 %d；局外存档版本 %d；当前点 %d" % [RunState.SAVE_VERSION, MetaState.SAVE_VERSION, _flow.run.travel.current_id])
			print("MAKE 存局 %s" % str(_flow.save()))
			_flow.to_main_menu(); _wait = 30; _st = 4
		4:
			print("MAKE 回主菜单；有局内存档 %s" % str(_flow.has_save()))
			quit(0); return true
	return false

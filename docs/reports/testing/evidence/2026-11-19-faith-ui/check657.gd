extends SceneTree
## v6.57 读 v6.56 的旧档：局外档委托应全空、其它字段不变；接着打完存着的那一局，结算后再存再读。
## 参数：<目录>（含 make657 写的 meta_before.json；截图也放这里）
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("C657 " + s)


func shot(n: String) -> void:
	var img := root.get_texture().get_image()
	if img != null: img.save_png("%s/%s.png" % [_out, n])


func _norm(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for k in a:
		if k == "commissions": continue
		if not b.has(k): out.append("少了 %s" % k)
		elif JSON.stringify(a[k], "", true) != JSON.stringify(b[k], "", true): out.append("变了 %s" % k)
	for k in b:
		if not a.has(k) and k != "commissions": out.append("多了 %s" % k)
	return out


func _book(m: MetaState) -> String:
	var c := m.commissions
	return "is_empty %s；rep %s；entries %s；mutex %s；receipts %d；clues %d；taken %s" % [str(c.is_empty()), str(c.rep), str(c.entries), str(c.mutex), c.receipts.size(), c.clues.size(), str(c.taken())]


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 5000:
		L("超时 st %d" % _st); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	match _st:
		0:
			if _f < 60: return false
			shot("menu")
			L("主菜单：有局 %s；局外档 %s" % [str(_flow.has_save()), _flow.meta_path])
			_flow.continue_game(); _wait = 40; _st = 1
		1:
			if _flow.screen != GameFlow.Screen.MAP:
				if _f > 1500: L("没进地图，屏 %s" % GameFlow.Screen.keys()[_flow.screen]); quit(1); return true
				return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			var before = JSON.parse_string(FileAccess.get_file_as_string(_out + "/meta_before.json"))
			L("旧档读进来：委托簿 %s" % _book(_flow.meta))
			var now := _norm(_flow.meta.to_dict()) as Dictionary
			L("和旧档比（除 commissions）：%s" % str(_diff(before, now)))
			L("局内：章 %s，背包件数 %d" % [String(_flow.run.chapter.id), _flow.run.board.items().size()])
			shot("old_run_map")
			L("撤离 %s" % str(_flow.run.force_extract()))
			_flow._flush(); _wait = 60; _st = 2
		2:
			L("结算后屏 %s" % GameFlow.Screen.keys()[_flow.screen])
			shot("result")
			var d = JSON.parse_string(FileAccess.get_file_as_string(_flow.meta_path))
			L("局外档：version %s；commissions %s" % [str(d.get("version")), JSON.stringify(d.get("commissions"))])
			var m := MetaSave.read(_flow.items, _flow.meta_path, _flow.meta_rules)
			L("重读：%s" % (_book(m) if m != null else "读不出"))
			_flow.to_main_menu(); _wait = 30; _st = 3
		3:
			_flow.continue_game(); _wait = 60; _st = 4
		4:
			L("进基地屏 %s；委托簿 %s" % [GameFlow.Screen.keys()[_flow.screen], _book(_flow.meta)])
			shot("base")
			quit(0); return true
	return false

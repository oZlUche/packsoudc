## 一局级套件共用的帮助函数（102 第 A-4 / A-5 条）：造一个带独立存档路径的 [GameFlow]、走到某个点、
## 把当前这一屏看完、找保险箱点。
##
## 文件名不以 `test_` 开头 —— `run_tests.gd` 扫的是套件，这里是套件的工具。
## 以前这些函数在每个 `test_author_*.gd` 里各写一份，搬用例的时候就得连着抄；收到这里之后搬用例只搬用例。
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


## 一组互不打扰的存档路径（同一个前缀同一组）
static func paths(prefix: String) -> Dictionary:
	return {"run": "user://test_%s_run.json" % prefix, "meta": "user://test_%s_meta.json" % prefix,
		"settings": "user://test_%s_settings.json" % prefix}


## 一个用这组路径的 [GameFlow]
static func flow(c, prefix: String, hp: float = 10000.0) -> GameFlow:
	var f: GameFlow = NodeScreens._flow(c, hp)
	var p := paths(prefix)
	f.save_path = String(p["run"])
	f.meta_path = String(p["meta"])
	f.settings_path = String(p["settings"])
	return f


## 删掉这组路径下的文件
static func cleanup(prefix: String) -> void:
	var p := paths(prefix)
	RunSave.remove(String(p["run"]))
	MetaSave.remove(String(p["meta"]))
	GameSettings.remove(String(p["settings"]))


## 把一件信仰道具放上棋盘（激活那个信仰）；放不下就到地上并返回 null
static func activate(run: RunState, item_id: StringName) -> ItemInstance:
	var def := run.items.get_def(item_id)
	if def == null:
		return null
	var inst := ItemInstance.create(def)
	if run.board.try_add(inst, true):
		return inst
	run.storage.admit(inst)
	return null


## 图上的保险箱点（没有 null）
static func safe_node(run: RunState) -> MapNode:
	for id in run.map.node_ids():
		if run.map.get_node(id).type == &"safe":
			return run.map.get_node(id)
	return null


## 从当前点走到某个点（沿最短路），每一步把叠层看完；到不了 / 一局结束返回 false
static func walk_to(f: GameFlow, target: int, stop_at_screen: int = -1) -> bool:
	var run := f.run
	var guard := 0
	while run.travel.current_id != target and guard < 40 and not run.is_over():
		guard += 1
		var dist := MapNavigator.distance_map(run.map, target)
		var best := -1
		for n in run.travel.available_moves():
			if dist.has(n) and (best < 0 or int(dist[n]) < int(dist[best])):
				best = n
		if best < 0 or not f.step_to(best):
			return false
		if run.travel.current_id == target and stop_at_screen >= 0:
			var g := 0
			while GameFlow.is_overlay(f.screen) and f.screen != stop_at_screen and g < 20:
				g += 1
				settle_one(f)
			return true
		NodeScreens._settle(f)
	return run.travel.current_id == target


## 只把当前这一屏看完（不像 NodeScreens._settle 那样一路看到地图 —— 撤离点的事件选第 0 项就是「撤离」）
static func settle_one(f: GameFlow) -> void:
	match f.screen:
		GameFlow.Screen.PREBATTLE:
			f.start_battle()
		GameFlow.Screen.LOOT:
			f.take_all_loot()
		GameFlow.Screen.SEARCH:
			f.run.events.current_search.leave()
		GameFlow.Screen.SHOP:
			f.run.events.current_shop.leave()
		GameFlow.Screen.EVENT:
			if f.run.events.pending_event() != null:
				f.choose_event(0)
			else:
				f.resume()
		_:
			f.resume()

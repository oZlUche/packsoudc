extends SceneTree
## 在 v6.71（存档 v5，三档声望）上做旧档：新游戏 → 拒教程 → 测试辅助写进度 → 存档。参数：<快照输出目录>
## 进度：后勤（legion）声望 3、灰灯 6、考据所（society）9；《两条回路》办成过一次但声望记 0（看「办成过至少 10」）；
## 金币 1234；科技 仓库扩建 2 级、法杖工艺 1 级；铁匠铺 2 级；仓库放几件东西。把存档 to_dict 写到 <目录>/meta_before.json
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


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 5000:
		print("OLD 超时 st %d" % _st); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open(): b.decline_tutorial()
			elif _f > 240: _flow.decline_tutorial()
			else: return false
			_wait = 30; _st = 2
		2:
			if _flow.screen != GameFlow.Screen.META: return false
			var m := _flow.meta
			var book = m.commissions
			book.rep = {"legion": 0, "greylamp": 6, "society": 9}
			book.entries = {"legion_two_routes": {"state": "done", "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}}
			m.funds = 1234
			m.tech_levels[&"warehouse"] = 2
			m.tech_levels[&"staffcraft"] = 1
			m.facility_levels[Smithy.ID] = 2
			for id in ["copper_ore", "seasoned_timber", "knife"]:
				var it := ItemInstance.create(_flow.items.get_def(StringName(id)), 0)
				it.uid = m.allocate_uid()
				m.warehouse.try_add(it)
			print("OLD 存档版本 %s；写进度后存档 %s" % [str(MetaState.SAVE_VERSION), str(_flow.save_meta())])
			_wait = 20; _st = 3
		3:
			var d = JSON.parse_string(FileAccess.get_file_as_string(_flow.meta_path))
			print("OLD 落盘：version %s；commissions %s；funds %s；tech %s；仓库 %d 件" % [str(d.get("version")), JSON.stringify(d.get("commissions", {})), str(d.get("funds")), str(d.get("tech_levels")), _flow.meta.warehouse.item_count()])
			var fa := FileAccess.open(_out + "/meta_before.json", FileAccess.WRITE)
			fa.store_string(JSON.stringify(d, "\t", true)); fa.close()
			quit(0); return true
	return false

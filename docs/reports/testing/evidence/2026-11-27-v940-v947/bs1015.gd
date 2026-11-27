extends SceneTree
## 测试 v9.42（PR #1015）无头：真道具换包 —— 皮包里放三件，换成小包 / 长包 / 草药袋，看哪些原位留下、哪些掉
const G := preload("res://tests/run/test_god_cards_388.gd")


func _cells(it: ItemInstance) -> String:
	return str(it.origin)


func _try(new_bag: StringName, contents: Array) -> void:
	var run := G._start(7, &"brute")
	for it in run.board.items().duplicate(): run.board.remove(it.uid)
	var old := TestSupport.put(run.board, run.items.get_def(&"bag_leather"))
	var inside := []
	for id in contents:
		var bu := old.uid
		var brd := run.board
		var it := TestSupport.put_where(run.board, run.items.get_def(StringName(id)), func(i: ItemInstance) -> bool:
			for c in i.cells():
				if brd.bag_at(i.origin + c) != bu: return false
			return true)
		if it != null: inside.append(it)
	var nb := ItemInstance.create(run.items.get_def(new_bag))
	var plan := run.board.replace_bag_plan(old.uid, nb, {}, old.origin, 0)
	var before := inside.map(func(i): return "%s@%s" % [String(i.def.id), str(i.origin)])
	var res := run.board.replace_bag(old.uid, nb, {}, old.origin, 0)
	var kept := []
	var moved := 0
	for i in inside:
		if run.board.has_item(i.uid):
			kept.append("%s@%s" % [String(i.def.id), str(i.origin)])
	var shed: Array = res.get("shed", [])
	print("BS1015 皮包 %s → %s：包里 %s；预案 留 %d 掉 %d；换了 %s；留在原位 %s；掉出 %s；新包在 %s" % [
		str(old.def.shape.cells_rotated(0).size()), String(new_bag), str(before),
		(plan.get("kept", []) as Array).size(), (plan.get("fallen", []) as Array).size(),
		str(res.get("ok")), str(kept), str(shed.map(func(i): return String(i.def.id))), str(run.board.has_item(nb.uid))])
	for i in inside:
		if run.board.has_item(i.uid) and not (before.has("%s@%s" % [String(i.def.id), str(i.origin)])): moved += 1
	if moved > 0: print("BS1015 BAD 留下的有挪位置的 %d 件" % moved)
	run.dispose()


func _init() -> void:
	for b in [&"bag_small", &"bag_long", &"herb_pouch", &"war_pack", &"bag_leather"]:
		var d := ItemDatabase.new(); d.load_dir()
		var bd := d.get_def(b)
		print("BS1015 %s 形状 %d 格，收 %s" % [String(b), bd.shape.cells_rotated(0).size(), str(bd.bag_accept_tags)])
	_try(&"bag_small", ["bandage", "knife", "herb"])
	_try(&"bag_long", ["bandage", "knife", "herb"])
	_try(&"herb_pouch", ["bandage", "knife", "herb"])
	_try(&"war_pack", ["bandage", "knife", "herb"])
	print("BS1015 完")
	quit(0)

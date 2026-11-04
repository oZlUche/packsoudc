## 277 第 2 条：开局屏「照上回带」—— 仓库里还在的上回那几件摆回棋盘，现金填上回的数（不超过仓库余额）；出发时记下这回带的
extends RefCounted

const CS := preload("res://tests/run/test_character_setup.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_repeat_last(t: TestCase, root: Window) -> void:
	t.begin("277 · 照上回带：摆回仓库里还在的、跳过没了的、现金照上回（收到仓库余额）")
	Support.cleanup("char")
	var game = load(CS.GAME).instantiate()
	game.save_path = CS.SAVE
	game.meta_path = CS.META
	root.add_child(game)
	var flow: GameFlow = game.flow
	if flow.characters.is_empty() or flow.chapters.is_empty():
		t.check(false, "没有角色或章节")
		game.queue_free()
		return
	flow.meta.funds = 30
	var ration := flow.items.get_def(&"ration")
	var inst := ItemInstance.create(ration)
	t.check(flow.meta.warehouse.try_add(inst), "仓库里一份口粮")
	flow.meta.last_carry = [{"id": "ration", "origin": [0, 0], "rot": 0}, {"id": "no_such_item", "origin": [1, 0], "rot": 0}]
	flow.meta.last_carry_funds = 50
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	t.check(setup._repeat_btn != null and not setup._repeat_btn.disabled, "有上回的记录：键亮着")
	t.eq(setup.repeat_last(), 1, "摆上了一件（没了的那件跳过）")
	t.check(setup.board.has_item(inst.uid) and not flow.meta.warehouse.has_item(inst.uid), "口粮从仓库到了棋盘")
	t.eq(setup.carry_funds, 30, "现金照上回 50，收到仓库余额 30")
	setup._record_carry()
	t.eq(flow.meta.last_carry.size(), 1, "出发时记下这回带的")
	t.eq(String(flow.meta.last_carry[0]["id"]), "ration", "记的是口粮")
	t.eq(flow.meta.last_carry_funds, 30, "现金也记下")
	var back := MetaState.from_dict(flow.meta.to_dict(), flow.items)
	t.check(back != null and back.last_carry == flow.meta.last_carry and back.last_carry_funds == 30, "存档往返不丢")
	game.queue_free()
	Support.cleanup("char")

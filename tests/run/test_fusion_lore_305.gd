## 305（合成与锻造改造 A，方案 §6）：拼接 / 拖合不吃锁定件、随身之物；自己合成才记下配方，进过背包或自己造出才认识道具；
## 知识随这一局存、局终并进局外（死了也记得），老档按图鉴与手上的东西补「认识」、不反推配方；
## 悬浮窗「可拼为 / 由…合成 / 可升为」只列知道的，拖合提示与确认窗不认识成品就打问号；点锤先开确认窗，取消什么都不记；
## 寂灭已在本局地上时献祭条件不成立
extends RefCounted

const InvPanel := preload("res://ui/game/inventory_panel.gd")


static func _put(board: GridInventory, items: ItemDatabase, id: StringName, at: Vector2i) -> ItemInstance:
	var inst := ItemInstance.create(items.get_def(id), 0)
	return inst if board.place(inst, at, 0) else null


static func _run() -> RunState:
	var c := TestSupport.load_content()
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	s.meta = MetaState.new()
	CraftingModule.of(s).recipes = RecipeDef.load_all()
	s.board = GridInventory.new(Vector2i(6, 4), 1, false)
	return s


## 开局自带的棋盘（接着「摆上去就认识」那根线）+ 一个包
static func _bagged() -> RunState:
	var c := TestSupport.load_content("free_mode", ["buffs"])
	var s := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs, [] as Array[StringName], null,
		[{"id": "war_pack", "origin": [0, 0], "rot": 0}])
	s.meta = MetaState.new()
	CraftingModule.of(s).recipes = RecipeDef.load_all()
	return s


static func run_locked(t: TestCase) -> void:
	t.begin("305 · 锁定的、随身之物：贴着不出锤、点锤不合、拖上去不合")
	var s := _run()
	var crafting := CraftingModule.of(s)
	var k1 := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var k2 := _put(s.board, s.items, &"knife", Vector2i(1, 0))
	t.eq(crafting.fusion_pairs().size(), 1, "没锁：一对")
	k2.set_locked(true)
	t.eq(crafting.fusion_pairs().size(), 0, "锁了一把：不出锤")
	t.check(not bool(crafting.fuse(k1.uid, k2.uid)["ok"]), "点锤：不合")
	t.check(s.board.has_item(k2.uid), "锁着的还在")
	k2.set_locked(false)
	k2.state[ItemInstance.PINNED_KEY] = true
	t.eq(crafting.fusion_pairs().size(), 0, "随身之物：不出锤")
	k2.state.erase(ItemInstance.PINNED_KEY)
	var knife := _put(s.board, s.items, &"knife", Vector2i(4, 0))
	var vial := ItemInstance.create(s.items.get_def(&"poison_vial"), 0)
	knife.set_locked(true)
	t.check(not bool(crafting.craft(vial, knife.uid)["ok"]), "拖合压在锁着的刀上：不合")
	knife.set_locked(false)
	vial.set_locked(true)
	t.check(not bool(crafting.craft(vial, knife.uid)["ok"]), "手上那件锁着：不合")
	vial.set_locked(false)
	t.check(bool(crafting.craft(vial, knife.uid)["ok"]), "都没锁：合了")


static func run_learn(t: TestCase) -> void:
	t.begin("305 · 合成成功才记配方、认识成品；预览不记；摆进背包就认识")
	var s := _run()
	var crafting := CraftingModule.of(s)
	var knife := s.items.get_def(&"knife")
	var stone := s.items.get_def(&"whetstone")
	t.eq(crafting.known_level(knife, stone, true), 0, "开局：不知道刀 + 磨刀石出什么")
	var k := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var w := _put(s.board, s.items, &"whetstone", Vector2i(0, 2))
	var pv := crafting.fuse_preview(k.uid, w.uid)
	t.check(not pv.is_empty() and int(pv["known"]) == 0, "预览：成品不认识")
	t.check(not s.knows_recipe(&"fuse_quenched_dagger"), "预览不记配方")
	t.check(_bagged().has_met(&"knife") == false, "没摆过的刀：不认识")
	var d := crafting.fuse(k.uid, w.uid)
	t.check(bool(d["ok"]) and d["recipe"] == "fuse_quenched_dagger", "合了，回执带配方 id")
	t.check(s.knows_recipe(&"fuse_quenched_dagger"), "记下配方")
	t.check(s.has_met(&"quenched_dagger"), "认识成品")
	t.eq(crafting.known_level(knife, stone, true), 2, "再看：知道")
	t.check(not s.knows_recipe(&"fuse_twin_blades"), "别的配方照旧不知道")
	var s2 := _bagged()
	t.not_null(_put(s2.board, s2.items, &"twin_blades", Vector2i(0, 0)), "双刀摆进这一局自己的背包")
	t.check(s2.has_met(&"twin_blades"), "摆进背包：认识")
	t.eq(CraftingModule.of(s2).known_level(knife, knife, true), 1, "没合过、但双刀进过背包：认识成品")


static func run_save(t: TestCase) -> void:
	t.begin("305 · 知识随这一局存读；局终并进局外（战败也算）；局外存读往返；老档补认识、不反推配方")
	var s := _run()
	var crafting := CraftingModule.of(s)
	var k1 := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var k2 := _put(s.board, s.items, &"knife", Vector2i(1, 0))
	crafting.fuse(k1.uid, k2.uid)
	var back := Lore.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))["lore"])
	t.check(back.knows_recipe(&"fuse_twin_blades") and back.has_met(&"twin_blades"), "这一局的存档里有")
	var meta := MetaState.new()
	var r := RunResult.new()
	r.outcome = &"defeated"
	r.lore = s.lore
	meta.absorb(r)
	t.check(meta.lore.knows_recipe(&"fuse_twin_blades"), "战败了也并进局外")
	meta.absorb(r)
	t.eq(meta.lore.recipes.size(), 1, "并两次不重复")
	var d: Dictionary = JSON.parse_string(JSON.stringify(meta.to_dict()))
	var m2 := MetaState.from_dict(d, s.items)
	t.check(m2.lore.knows_recipe(&"fuse_twin_blades") and m2.lore.has_met(&"twin_blades"), "局外存读往返")
	d.erase("seen_item_ids")
	d.erase("discovered_fusion_recipes")
	d["codex"] = {"bloodletter": 2, "knife": 0}
	var old := MetaState.from_dict(d, s.items)
	t.check(old.lore.has_met(&"bloodletter"), "老档：图鉴点亮的认识")
	t.check(not old.lore.has_met(&"knife"), "图鉴 0 件的不算")
	t.check(old.lore.recipes.is_empty(), "老档不反推配方")


static func run_tooltip(t: TestCase) -> void:
	t.begin("305 · 悬浮窗只列知道的配方：可拼为 / 由…合成 / 可升为；不接探针 = 都知道")
	var s := _run()
	var knife := s.items.get_def(&"knife")
	var saved_r := ItemTooltip.recipe_probe
	var saved_i := ItemTooltip.item_probe
	ItemTooltip.recipe_probe = s.knows_recipe
	ItemTooltip.item_probe = s.has_met
	t.eq(ItemTooltip.fusions_line(knife), "", "没合成过：刀的悬浮窗不列可拼为")
	t.eq(ItemTooltip.made_from_line(s.items.get_def(&"quenched_dagger")), "", "成品那边也不写")
	t.eq(ItemTooltip.upgrades_line(s.items.get_def(&"bonefang_dagger")), "", "没锤过：不列可升为")
	s.lore.learn_recipe(&"fuse_quenched_dagger")
	var line := ItemTooltip.fusions_line(knife)
	t.check(line.contains("fuse_quenched_dagger") and not line.contains("fuse_twin_blades"), "只列合成过的那张（%s）" % line)
	t.check(ItemTooltip.made_from_line(s.items.get_def(&"quenched_dagger")).contains("[url=item:whetstone]"), "成品：由 刀 与 磨刀石 合成")
	ItemTooltip.recipe_probe = Callable()
	ItemTooltip.item_probe = Callable()
	t.check(ItemTooltip.fusions_line(knife).contains("fuse_twin_blades"), "不接探针：都列")
	ItemTooltip.recipe_probe = saved_r
	ItemTooltip.item_probe = saved_i


static func run_jimie_ground(t: TestCase) -> void:
	t.begin("305 · 寂灭已在本局地上：献祭条件不成立、执行也不献（304 第 8 条）")
	var c := TestSupport.load_content("free_mode", ["buffs"])
	var layout := [{"id": "war_pack", "origin": [0, 0], "rot": 0}, {"id": "magic_staff", "origin": [0, 0], "rot": 0, "state": {ItemInstance.RUNS_KEY: 50}}]
	var at := [[1, 0], [2, 0], [3, 0], [1, 1]]
	var els: Array = JimiePath.CORES.keys()
	for i in 4:
		layout.append({"id": String(JimiePath.CORES[els[i]]), "origin": at[i], "rot": 0})
	var run := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs, [] as Array[StringName], null, layout)
	run.meta = MetaState.new()
	var ctx := EventContext.new()
	ctx.board = run.board
	ctx.storage = run.storage
	ctx.meta = run.meta
	ctx.items = run.items
	ctx.hooks = run.hooks
	t.check(JimieReady.new().check(ctx), "基线：哪儿都没有寂灭，可以献")
	run.storage.admit(ItemInstance.create(run.items.get_def(JimiePath.RED)))
	t.check(not JimieReady.new().check(ctx), "地上有一把：不行")
	JimieSacrifice.new().apply(ctx)
	t.eq(run.board.items().filter(func(i: ItemInstance) -> bool: return i.def.id == JimiePath.RED).size(), 0, "执行端也不献第二把")


static func frame_confirm(t: TestCase, root: Window) -> void:
	t.begin("305 · 点锤先开确认窗：不认识成品写问号、写消耗；取消什么都不动不记；按合成才合并记下")
	var s := _run()
	var panel: Control = InvPanel.new()
	panel.setup(s, null)
	root.add_child(panel)
	var k1 := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var k2 := _put(s.board, s.items, &"knife", Vector2i(1, 0))
	k2.state[ItemInstance.QUALITY_KEY] = 1
	t.check(bool(panel.call("ask_fuse", k1.uid, k2.uid)), "开了确认窗")
	var tip: HoverTip = panel.get("tip")
	t.check(tip.is_pinned(), "钉住")
	var text := tip.text()
	t.check(text.contains(UiText.t("fuse.unknown")) and not text.contains(Names.of(s.items.get_def(&"twin_blades"))), "成品打问号、不写名字（%s）" % text)
	t.check(text.contains(UiText.t("fuse.quality")), "写出品质会丢")
	var buttons := tip.action_buttons()
	t.eq(buttons.size(), 2, "合成 / 取消两颗")
	if buttons.size() == 2:
		buttons[1].chosen.emit(buttons[1].action)
		t.check(s.board.has_item(k1.uid) and s.board.has_item(k2.uid), "取消：两把还在")
		t.check(not s.knows_recipe(&"fuse_twin_blades"), "取消：不记配方")
		panel.call("ask_fuse", k1.uid, k2.uid)
		var again := tip.action_buttons()
		again[0].chosen.emit(again[0].action)
		t.check(not s.board.has_item(k1.uid) and not s.board.has_item(k2.uid), "合成：两把没了")
		t.check(s.knows_recipe(&"fuse_twin_blades"), "合成：记下配方")
	panel.queue_free()

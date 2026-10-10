## 147（作者定，四项待定按推荐）：腰带 —— 随身消耗品槽，默认 3 格、可扩；只收【随身】，随身道具不上棋盘。
## 烟雾弹（战前准备屏：这一场不打，同「脱身」）、急救包（地图上：体力 +1，满了不能用）。存档往返、老档没有腰带读出空腰带
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _new(c: TestSupport.Content, id: StringName) -> ItemInstance:
	return ItemInstance.create(c.items.get_def(id))


static func _start_with(c: TestSupport.Content, kit: Array[StringName]) -> RunState:
	for seed in range(1, 60):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func run_belt_container(t: TestCase) -> void:
	t.begin("147 · 腰带：默认 3 格、只收随身；棋盘不收随身、地上照收；满了不收；加格扩列、缩只缩空格；开局带的随身落进腰带")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var belt := BeltModule.of(s)
	t.not_null(belt, "默认装了腰带模块")
	if belt == null:
		return
	t.eq(belt.belt.size, Vector2i(belt.slots, 1), "1 × %d" % belt.slots)
	var smoke := _new(c, &"smoke_bomb")
	t.check(smoke.def.is_belt() and smoke.def.belt_use != null, "烟雾弹是随身道具")
	t.check(not s.board.accepts(smoke.def), "作战棋盘不收随身道具")
	t.check(not s.board.find_first_fit(smoke.def)["found"], "棋盘上找不到位置")
	t.check(s.storage.accepts(smoke.def), "地上照收")
	t.check(not belt.belt.accepts(c.items.get_def(&"knife")), "腰带不收小刀")
	for i in belt.slots:
		t.check(belt.belt.try_add(_new(c, &"aid_pack")), "第 %d 格放得下" % (i + 1))
	t.check(not belt.belt.try_add(_new(c, &"smoke_bomb")), "满了不收")
	belt.slots += 1
	belt.sync_slots()
	t.eq(belt.belt.size.x, belt.slots, "加一格：扩到 %d 列" % belt.slots)
	t.check(belt.belt.try_add(smoke), "扩出来的那格放得下")
	belt.slots -= 2
	belt.sync_slots()
	t.eq(belt.belt.size.x, belt.slots + 2, "满着：缩不了（东西不丢）")
	t.eq(belt.belt.item_count(), belt.slots + 2, "一件没丢")
	var ctx := RunContext.new()
	var bonus := BeltSlotsBonus.new()
	bonus.amount = 2
	bonus.modify(ctx)
	t.eq(ctx.belt_slots_bonus, 2, "BeltSlotsBonus 往上下文里加格数")

	var s2 := _start_with(c, [&"smoke_bomb", &"aid_pack"] as Array[StringName])
	var b2 := BeltModule.of(s2)
	var in_belt: Array = []
	for inst in b2.belt.items():
		in_belt.append(String((inst as ItemInstance).def.id))
	in_belt.sort()
	t.eq(in_belt, ["aid_pack", "smoke_bomb"], "开局带的随身道具进了腰带")
	for inst in s2.storage.items():
		t.check(not (inst as ItemInstance).def.is_belt(), "地上没有随身道具")


static func run_belt_use(t: TestCase) -> void:
	t.begin("147 · 用：急救包地图上 +1、满了不能用、开战前用不了；烟雾弹只在开战前、核心点用不了、普通战这一场不打（同脱身）；用掉就从腰带拿走")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var belt := BeltModule.of(s)
	var aid := _new(c, &"aid_pack")
	var smoke := _new(c, &"smoke_bomb")
	belt.belt.try_add(aid)
	belt.belt.try_add(smoke)
	var mend := aid.def.belt_use.effects[0] as MendVitality
	t.not_null(mend, "急救包的效果是回体力")
	s.vitality.current = s.vitality.maximum
	t.eq(s.hooks.belt_use(aid.uid), "体力是满的", "满的不让用")
	t.check(belt.belt.has_item(aid.uid), "没用掉")
	s.vitality.current = s.vitality.maximum - 2
	var used: Array = []
	belt.used.connect(func(id: StringName): used.append(id))
	t.eq(s.hooks.belt_use(aid.uid), "", "地图上用了")
	t.eq(s.vitality.current, s.vitality.maximum - 2 + mend.amount, "体力 +%d" % mend.amount)
	t.check(not belt.belt.has_item(aid.uid), "用掉了")
	t.eq(used, [&"aid_pack"], "发了 used")

	t.eq(s.hooks.belt_use(smoke.uid), "只能在开战前用", "烟雾弹：地图上用不了")
	var node := CS._battle_node(s)
	s.events.pending_battle = {"node": node.id, "type": "core", "content": node.content, "kind": "node"}
	t.eq(s.hooks.belt_use(smoke.uid), "核心的战斗躲不开", "核心点用不了")
	var aid2 := _new(c, &"aid_pack")
	belt.belt.try_add(aid2)
	s.vitality.current = 1
	s.events.pending_battle = {"node": node.id, "type": "battle", "content": node.content, "kind": "node"}
	t.eq(s.hooks.belt_use(aid2.uid), "开战前用不了", "急救包开战前用不了")
	var v0 := s.vitality.current
	var m0 := s.wallet.balance
	t.eq(s.hooks.belt_use(smoke.uid), "", "普通战：烟雾弹用了")
	t.check(s.events.pending_battle.is_empty(), "等着开打的一场没了")
	t.check(node.is_visited(), "点算用过")
	t.eq(s.vitality.current, v0, "体力不变")
	t.eq(s.wallet.balance, m0, "没进账")
	t.check(s.pending_loot == null, "没有战利品")
	t.check(not belt.belt.has_item(smoke.uid), "烟雾弹用掉了")


static func run_belt_save(t: TestCase) -> void:
	t.begin("147 · 存档：腰带与里面的东西往返；老档没有腰带那一节 = 空腰带；棋盘读档后照样不收随身；撤离把腰带里的一起带出")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var belt := BeltModule.of(s)
	belt.belt.try_add(_new(c, &"smoke_bomb"))
	var d := s.to_dict()
	var back := RunState.from_dict(d, c.chapter, c.items, c.enemies, c.sets)
	t.not_null(back, "读得回来")
	if back == null:
		return
	var b2 := BeltModule.of(back)
	t.eq(b2.belt.item_count(), 1, "腰带里那件还在")
	t.check(not b2.belt.accepts(c.items.get_def(&"knife")), "读回来的腰带照样只收随身")
	t.check(not back.board.accepts(c.items.get_def(&"smoke_bomb")), "读回来的棋盘照样不收随身")
	var old := d.duplicate(true)
	(old["modules"] as Dictionary).erase("belt")
	var back2 := RunState.from_dict(old, c.chapter, c.items, c.enemies, c.sets)
	t.eq(BeltModule.of(back2).belt.item_count(), 0, "老档：空腰带")
	t.eq(BeltModule.of(back2).belt.size.x, BeltModule.of(back2).slots, "老档：默认格数")
	# 撤离：腰带里的一起带出
	s.phase = RunState.Phase.EXTRACTED
	var r := RunResult.settle(s)
	var ids: Array = []
	for inst in r.carried:
		ids.append((inst as ItemInstance).def.id)
	t.check(ids.has(&"smoke_bomb"), "撤离带出腰带里的烟雾弹")


static func run_belt_import(t: TestCase) -> void:
	t.begin("147 · 导入：能随身用的要带【随身】、不能有战斗、只占 1 格；导出往返一致")
	var bad := ImportReport.new()
	ContentImporter.import_item({"id": "x", "display_name": "x", "shape": ["11"], "tags": ["tool"], "combat": {"base_stats": {"damage": 1}},
		"belt_use": {"when": "MAP", "effects": [{"type": "mend_vitality"}]}}, ContentImporter.Context.new(), bad)
	var text := bad.to_text()
	t.check(text.contains("随身道具只占 1 格") and text.contains("要带「belt」标签") and text.contains("不上棋盘"), "三条都报：" + text.strip_edges().left(120))
	var good := ImportReport.new()
	var data := {"id": "y", "display_name": "y", "shape": ["1"], "tags": ["belt"], "belt_use": {"when": "PREBATTLE", "effects": [{"type": "smoke_escape"}]}}
	var def := ContentImporter.import_item(data, ContentImporter.Context.new(), good)
	t.check(good.ok() and def != null and def.belt_use.when == BeltUse.When.PREBATTLE, "合规的导得进来")
	var again := ContentImporter.import_item(ContentExporter.export_item(def), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_item(again)), ContentExporter.to_json(ContentExporter.export_item(def)), "导出 → 导入 → 再导出不变")
	t.check(def.has_effect(), "随身道具算有效果（编辑器分组）")

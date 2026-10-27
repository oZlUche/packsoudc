## 175 第三批（作者定）：铸炉节点 —— 三槽【时机】【效果】【数值】任意道具都能进，按材质 / 用途 / 稀有度查表铸成 1×1 的铸牌；
## 铸牌不进图鉴、不掉落、能带出；拖到武器上附魔（永存、后来者覆盖），所有附魔都视为铸牌附魔（`state.enchant` 覆盖 `ItemDef.enchant`）；
## 前缀命名（耐久前缀 + 附魔前缀 + 定义名）；存档里查不到的附魔被对账摘掉并报告
extends RefCounted

## 176：带整个库的导入上下文（不写 class_name，按路径取）
const AuthoringContext := preload("res://core/authoring/authoring_context.gd")

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _inst(db: ItemDatabase, id: StringName) -> ItemInstance:
	return ItemInstance.create(db.get_def(id))


static func run_tables(t: TestCase) -> void:
	t.begin("175 · 铸炉映射表：三张都导进来了、每列有 default；按材质 / 用途找行，查不到落 default；内容种类排在构件之后、道具之前")
	Forge.reset()
	for slot in ForgeTable.SLOTS:
		var tb := Forge.table(slot)
		t.not_null(tb, "%s 表" % slot)
		if tb != null:
			for col in ["material", "purpose", "rarity"]:
				t.not_null(ForgeTable.find(tb.get(col), ForgeTable.DEFAULT), "%s.%s 有 default" % [slot, col])
	var db := _db()
	var timing := Forge.table(&"timing")
	t.eq(timing.by_material(db.get_def(&"knife")).key, &"metal", "匕首（金属）落到金属行")
	t.eq(timing.by_material(db.get_def(&"forge_token")).key, ForgeTable.DEFAULT, "没有材质标签：default")
	t.eq(timing.by_purpose(db.get_def(&"knife")).key, &"weapon", "匕首（武器）落到武器行")
	t.eq(timing.by_rarity(9).key, ForgeTable.DEFAULT, "稀有度超出：default")
	t.check(ContentPaths.ORDER.find("forge") > ContentPaths.ORDER.find("rule_parts") and ContentPaths.ORDER.find("forge") < ContentPaths.ORDER.find("items"), "导入顺序：构件 → 铸炉 → 道具")
	var report := ImportReport.new()
	ContentImporter.import_forge_table({"id": "timing", "material": [{"key": "metal", "trigger": "@on_item_fired"}], "purpose": [], "rarity": []}, AuthoringContext.context(), report)
	t.check(report.to_text().contains("default"), "缺 default 行：导入器报错")


static func run_forge_and_rule(t: TestCase) -> void:
	t.begin("175 · 铸：时机金属（出手时）+ 效果骨（流血、嗜血的）+ 数值；拼成一条规则（扳机、节奏、效果、给谁、数值），前缀与那一句")
	var db := _db()
	var ench := Forge.forge(db.get_def(&"knife"), db.get_def(&"antler"), db.get_def(&"knife"))
	t.eq(String(ench.get("trigger", "")), "metal", "时机：金属行")
	t.eq(String(ench.get("direction", "")), "weapon", "方向：武器行")
	t.eq(String(ench.get("effect", "")), "bone", "效果：骨行")
	t.eq(ench.get("from", []), ["knife", "antler", "knife"], "记下三件")
	var v := Forge.table(&"value")
	var expect := maxi(1, roundi(Forge.table(&"effect").by_material(db.get_def(&"antler")).base * v.by_rarity(db.get_def(&"knife").rarity).size * v.by_material(db.get_def(&"knife")).mult * v.by_purpose(db.get_def(&"knife")).mult))
	t.eq(int(ench.get("magnitude", 0)), expect, "数值 = 基数 × 几档 × 材质系数 × 用途系数")
	var rule := Forge.rule_of(ench)
	t.not_null(rule, "拼得出规则")
	if rule != null:
		t.check(rule.trigger is OnItemFired, "出手时")
		t.check(rule.effects[0] is ApplyStatus and (rule.effects[0] as ApplyStatus).buff.id == &"bleed", "施加流血")
		t.eq((rule.effects[0] as ApplyStatus).stacks, expect, "层数 = 数值")
		t.check(rule.costs.is_empty(), "没有消耗")
	t.eq(Forge.prefix(ench), "嗜血的", "前缀：嗜血的")
	t.eq(Forge.prefix(ench, "en"), "Bloodthirsty ", "英文前缀")
	t.check(Forge.sentence(ench).contains("流血"), "那一句写流血（%s）" % Forge.sentence(ench))
	t.check(Forge.sentence(ench).contains("出手时") and not Forge.sentence(ench).contains("其他"), "「出手时」是这把武器自己出手，不是其他道具（%s）" % Forge.sentence(ench))

	var fire := Forge.forge(db.get_def(&"knife"), db.get_def(&"ice_crystal"), db.get_def(&"knife"))
	t.eq(String(fire.get("element", "")), "ice", "冰晶石进效果槽：按它的元素")
	t.eq(Forge.prefix(fire), "霜冻的", "前缀按元素：霜冻的")
	var r2 := Forge.rule_of(fire)
	t.check(r2 != null and r2.effects[0] is DealDamage and (r2.effects[0] as DealDamage).damage_type == &"ice", "打冰伤（补充五：寒冷另由施加来）")

	var beat := {"trigger": "stone", "direction": "default", "rate": 4, "effect": "metal", "target": "default", "tier": 0, "magnitude": 2}
	var r3 := Forge.rule_of(beat)
	t.check(r3 != null and r3.cadence is CooldownCadence, "按节拍 + 每次都触发：换成冷却（不会自己点燃自己）")
	var shield := Forge.forge(db.get_def(&"knife"), db.get_def(&"antler"), db.get_def(&"knife"))
	shield["target"] = "shield"
	var r4 := Forge.rule_of(shield)
	t.check(r4 != null and r4.effects[0] is RemoveStatus, "195：用途是盾 → 守式（骨：清掉自己身上的流血）")
	t.eq(int(r4.effects[0].get("target")), CombatEffect.Target.SELF, "用途是盾：给自己")
	var top := ench.duplicate()
	top["tier"] = 4
	t.eq(Forge.rule_of(top).effects.size(), 3, "195：效果槽稀有度 4 = 基础 + 升阶 + 附带（追加，不换掉）")
	t.eq(Forge.problem({"trigger": "nope", "effect": "bone"}), "时机表里没有「nope」", "表里查不到：坏了")


static func run_token(t: TestCase) -> void:
	t.begin("175 · 铸牌：1×1、重量 1、价值固定 3（补充二）；不进 ids()、不进图鉴；能留进局外；名字「铸牌 · 前缀」、悬浮窗写那一句")
	var db := _db()
	var a := _inst(db, &"knife")
	var b := _inst(db, &"antler")
	var c := _inst(db, &"cleaver")
	var tok := Forge.make_token(db, a, b, c)
	t.not_null(tok, "铸得出来")
	if tok == null:
		return
	t.eq(tok.def.cell_count(), 1, "1×1")
	t.eq(ItemWeight.of(tok.def), 1, "重量 1")
	t.eq(ItemValue.of_instance(tok), Forge.TOKEN_VALUE, "价值固定 3")
	t.check(Forge.TOKEN_VALUE < ItemValue.of_instance(a) + ItemValue.of_instance(b) + ItemValue.of_instance(c), "比三件之和低：铸了就亏")
	t.check(not db.ids(true).has(&"forge_token"), "不进 ids（搜索、掉落、商店、图鉴都从这里拿）")
	t.check(MetaState.keeps(tok.def), "能留进局外（带出、存仓库）")
	var m := MetaState.new()
	var got := {"lit": 0}
	m._record_codex(tok, got)
	t.check(not m.codex.has("forge_token"), "不记图鉴")
	t.eq(Names.of_item(tok), "铸牌 · 嗜血的", "名字")
	var text := Glossary.strip_bbcode(ItemTooltip.describe(tok))
	t.check(text.contains("流血") and text.contains("拖到一件武器上"), "悬浮窗写那一句与用法（%s）" % text)
	var back := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(tok.to_dict())), db)
	t.eq(Forge.prefix(Forge.enchant_of(back)), "嗜血的", "存档往返：附魔还在")


static func run_enchant(t: TestCase) -> void:
	t.begin("175 · 附魔：铸牌拖到武器上 → 武器写入、铸牌消失；再来一枚覆盖；非武器不收；编译只挂一条（以宿主身份跑）；打起来对手流血")
	var db := _db()
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(5, 3), 1, false)
	var knife := _inst(db, &"knife")
	g.place(knife, Vector2i(0, 0), 0)
	var hide := _inst(db, &"beast_hide")
	g.try_add(hide)
	var stash := GridInventory.new(Vector2i(3, 3), 2, false)
	var tok := Forge.make_token(db, _inst(db, &"knife"), _inst(db, &"antler"), _inst(db, &"knife"))
	stash.try_add(tok)
	t.check(not InventoryService.enchant(tok, stash, g, hide.uid), "压在非武器上：不收")
	t.check(stash.has_item(tok.uid), "铸牌还在")
	t.check(InventoryService.enchant(tok, stash, g, knife.uid), "压在匕首上：附魔")
	t.check(not stash.has_item(tok.uid), "铸牌消失")
	t.eq(Names.of_item(knife), "嗜血的" + Names.of(knife.def), "匕首叫嗜血的匕首")
	var spec := BattleCompiler.compile_board(g)
	var item := spec.item_of(knife.uid)
	var n := 0
	for a in item.attached:
		if StringName(String(a["origin"])) == Forge.ORIGIN:
			n += 1
	t.eq(n, 1, "挂一条附魔规则")
	t.check(Glossary.strip_bbcode(ItemTooltip.describe(knife, g)).contains("【附魔】") or ItemTooltip.describe(knife, g).contains("附魔"), "悬浮窗有附魔行")

	var tok2 := Forge.make_token(db, _inst(db, &"knife"), _inst(db, &"leather_armor"), _inst(db, &"knife"))
	t.check(InventoryService.enchant(tok2, null, g, knife.uid), "再附一枚")
	t.eq(Forge.prefix(Forge.enchant_of(knife)), "坚壁的", "后来者覆盖：坚壁的")
	t.eq(BattleCompiler.compile_board(g).item_of(knife.uid).attached.filter(func(a): return StringName(String(a["origin"])) == Forge.ORIGIN).size(), 1, "仍只挂一条")
	t.check(DragLayer.enchant_hint(tok, knife).begins_with("附魔：嗜血的"), "拖拽提示：附魔：嗜血的匕首（%s）" % DragLayer.enchant_hint(tok, knife))

	# 打起来：嗜血的匕首出手时给对手上流血
	knife.state[Forge.KEY] = Forge.forge(db.get_def(&"knife"), db.get_def(&"antler"), db.get_def(&"knife"))
	var me := BattleCompiler.compile_board(g, CombatantBaseline.with_hp(4000.0))
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(4000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var res := BattleSim.run(me, BattleCompiler.compile(null, foe_in), rng, 15.0)     # 时机稀有度 0 是 6 秒一次
	var bled := false
	for ev in res.log:
		var e := ev as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and String(e.payload.get("buff", "")) == "bleed":
			bled = true
	t.check(bled, "对手被上了流血")


static func run_preset_and_naming(t: TestCase) -> void:
	t.begin("175 · 预置附魔（ItemDef.enchant）：实例的覆盖它；命名 = 耐久前缀 + 附魔前缀 + 定义名")
	var db := _db()
	var def := db.get_def(&"knife").duplicate(true) as ItemDef
	def.id = &"probe_enchanted_knife"
	var e := EnchantDef.new()
	e.trigger = &"metal"
	e.effect = &"bone"
	e.magnitude = 2
	def.enchant = e
	var inst := ItemInstance.create(def)
	t.eq(Forge.prefix(Forge.enchant_of(inst)), "嗜血的", "预置的生效")
	inst.state[Forge.KEY] = {"trigger": "metal", "effect": "leather", "magnitude": 3}
	t.eq(Forge.prefix(Forge.enchant_of(inst)), "束缚的", "实例的覆盖预置的（195：皮革攻式）")
	inst.state[Forge.KEY] = {"trigger": "metal", "effect": "leather", "target": "shield", "magnitude": 3}
	t.eq(Forge.prefix(Forge.enchant_of(inst)), "坚壁的", "195：效果槽放盾 = 守式前缀")
	var crystal := _inst(db, &"fire_crystal")
	crystal.state[Forge.KEY] = {"trigger": "metal", "effect": "bone", "magnitude": 1}
	t.eq(Names.of_item(crystal), "完美的嗜血的火焰魔晶石", "耐久前缀 + 附魔前缀 + 名字")


static func run_reconcile(t: TestCase) -> void:
	t.begin("175 · 存档对账：附魔里的行查不到了 → 摘掉、报告一行；好的留着")
	var db := _db()
	var bad := {"uid": 7, "def": "knife", "rot": 0, "origin": [0, 0], "seq": 0, "state": {"enchant": {"trigger": "gone", "effect": "bone"}}}
	var good := {"uid": 8, "def": "knife", "rot": 0, "origin": [0, 0], "seq": 0, "state": {"enchant": {"trigger": "metal", "effect": "bone", "magnitude": 1}}}
	var report := SaveReport.new()
	SaveReconcile.item(bad, db, report, "board")
	SaveReconcile.item(good, db, report, "board")
	t.check(not (bad["state"] as Dictionary).has("enchant"), "坏的摘掉")
	t.check((good["state"] as Dictionary).has("enchant"), "好的留着")
	t.eq(report.unenchanted.size(), 1, "报告一行")
	t.check(report.summary().contains("附魔"), "给玩家的一句提到附魔（%s）" % report.summary())
	t.eq(SaveReport.from_dict(report.to_dict()).unenchanted.size(), 1, "报告往返")


static func run_node(t: TestCase) -> void:
	t.begin("175 补充二 · 铸炉在休息点里：没有独立的铸炉点；休息点开得了铸炉、没铸走开不算用过、铸了就熄（休息点灰不灰不受它管）；老存档的铸炉点按休息点读")
	t.check(not MapNodeTypes.has(&"forge"), "类型表里没有 forge 了")
	t.check(not MapGridText.SYMBOL_TYPES.has("F"), "地图文字里没有 F")
	t.check(not NodeTooltip.DEFAULTS.has("forge"), "浮窗没有铸炉点")
	t.check(String(NodeTooltip.DEFAULTS.get("rest", "")).contains("铸炉"), "休息点的浮窗提到铸炉")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var forges := 0
	for seed in range(1, 9):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items)
		if s == null:
			continue
		for id in s.map.node_ids():
			if s.map.get_node(id).type == &"forge":
				forges += 1
	t.eq(forges, 0, "八张图都不再撒铸炉点")

	var f := Support.flow(c, "forge175")
	var node := _rest_next_to_spawn(f, c, kit)
	t.check(node != null and f.step_to(node.id), "走上休息点")
	t.check(f.open_forge(node), "休息点开得了铸炉")
	t.eq(f.screen, GameFlow.Screen.FORGE, "→ 铸炉屏")
	t.check(f.leave_forge(), "不铸就走")
	t.check(not NodeEvents.forge_used(node), "没铸：不算用过")
	var picks: Array = []
	for id in [&"knife", &"antler", &"cleaver"]:
		var inst := _inst(c.items, id)
		f.run.storage.admit(inst)
		picks.append(inst)
	var tok := f.forge_token(node, picks[0], picks[1], picks[2], [f.run.storage, f.run.storage, f.run.storage])
	t.not_null(tok, "铸成一枚")
	for p in picks:
		t.check(not f.run.storage.has_item((p as ItemInstance).uid), "%s 被消耗" % (p as ItemInstance).def.id)
	t.check(NodeEvents.forge_used(node), "铸炉熄了")
	t.check(not node.is_visited(), "铸了不等于歇过：休息、神坛两份没用，点不灰")
	t.eq(f.forge_token(node, picks[0], picks[1], picks[2], [null, null, null]), null, "熄了不能再铸")
	t.check(not f.open_forge(node), "熄了开不了")
	var other := _first_of(f.run.map, &"battle")
	t.check(other == null or not f.open_forge(other), "不是休息点开不了")
	Support.cleanup("forge175")

	# 老存档：一局档里的铸炉点（含随机点揭开成铸炉的）按休息点读，节点内容原样
	var d := {"map": {"nodes": [{"id": 3, "type": "forge", "content": {"used_forge": true}}, {"id": 4, "type": "random", "content": {"resolved_type": "forge"}},
		{"id": 5, "type": "battle", "content": {}}]}}
	var report := SaveReport.new()
	SaveReconcile.run(d, _db(), report)
	var nodes: Array = d["map"]["nodes"]
	t.eq([String(nodes[0]["type"]), String(nodes[1]["content"]["resolved_type"]), String(nodes[2]["type"])], ["rest", "rest", "battle"], "铸炉点 → 休息点，别的不动")
	t.check(bool(nodes[0]["content"]["used_forge"]), "铸过的照样算铸过")
	t.eq(report.retyped.size(), 2, "对账记了两笔")
	t.check(report.is_empty(), "不用告诉玩家")
	t.eq(SaveReport.from_dict(report.to_dict()).retyped.size(), 2, "报告往返")


static func _first_of(map: MapGraph, type: StringName) -> MapNode:
	for id in map.node_ids():
		if map.get_node(id).type == type:
			return map.get_node(id)
	return null


## 出生点旁边一个休息点（种子里找得到就用，找不到把旁边一个点改成休息点）
static func _rest_next_to_spawn(f: GameFlow, c, kit: LoadoutDef) -> MapNode:
	var found: Dictionary = NodeScreens._seed_with(c, &"rest", kit.items)
	var seed := int(found.get("seed", 1))
	var run := f.begin(c.chapter, kit, seed)
	if run == null:
		return null
	var entry := int(found.get("entry", run.map.entry_ids[0]))
	f.pick_spawn(entry)
	if found.has("next"):
		return run.map.get_node(int(found["next"]))
	for nid in run.map.neighbors(entry):
		var node := run.map.get_node(nid)
		if node.type in [&"battle", &"event", &"search"]:
			node.type = &"rest"
			for key in node.content.keys():
				node.content.erase(key)
			return node
	return null


static func frame_forge_screen(t: TestCase, root: Window) -> void:
	t.begin("175 · 铸炉屏：三槽一槽一件、铸牌不能进槽；预览写将要铸出的那一枚；铸 → 三件消失、出牌槽一枚、铸炉熄；返回时铸牌回背包")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("forge_ui")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("forge_ui")["run"])
	game.meta_path = String(Support.paths("forge_ui")["meta"])
	game.settings_path = String(Support.paths("forge_ui")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	var node := _rest_next_to_spawn(flow, c, kit)
	t.check(node != null and flow.step_to(node.id) and flow.open_forge(node), "走上休息点、开铸炉")
	var screen = game.overlay()
	t.check(screen != null and screen.has_method("put_in"), "叠层是铸炉屏")
	if screen == null or not screen.has_method("put_in"):
		game.queue_free()
		Support.cleanup("forge_ui")
		return
	var uids: Array[int] = []
	for id in [&"knife", &"antler", &"cleaver", &"cleaver"]:
		var inst := _inst(c.items, id)
		flow.run.storage.admit(inst)
		uids.append(inst.uid)
	t.check(screen.preview_text().contains("还差"), "空槽：还差几个（%s）" % screen.preview_text())
	# 196 §5（美术定稿）：整屏炉台近景，槽 / 出牌槽 / 背包按 layout.json 摆，跟底图同一个 cover 变换
	t.eq(screen.backdrop_state(), "lit", "没铸过：炉火亮着")
	t.eq(screen.forge_btn_state(), "idle", "没放满：「铸牌」键是暗的那张")
	var lay: Dictionary = screen.layout()
	var s: float = screen.size.x / 1920.0     # 按宽铺满、竖直居中
	var off: Vector2 = (screen.size - Vector2(1920, 1200) * s) * 0.5
	var r0: Dictionary = lay["slots"][0]
	t.check(screen.spot_rect("slot0").position.is_equal_approx(off + Vector2(r0["x"], r0["y"]) * s), "时机槽按 layout 摆（%s）" % screen.spot_rect("slot0"))
	var fits := true
	for i in 3:
		var v: InventoryView = screen.slot_view(i)
		fits = fits and Rect2(Vector2.ZERO, screen.spot_rect("slot%d" % i).size).grow(0.5).encloses(v.get_rect())
	t.check(fits, "4 × 4 的格子在槽口里")
	# 作者 2026-10-27：「铸」从左上风箱把手挪到台面右端的铜盾「铸牌」键 —— 168 × 156、原点在中心、摆在底图 (1140, 606)；只认盾牌本身，外圈的光不算可点
	var key: Rect2 = screen.spot_rect("forge_btn")
	t.check(key.get_center().is_equal_approx(off + Vector2(1140, 606) * s) and key.size.is_equal_approx(Vector2(168, 156) * s), "「铸牌」键在台面右端（%s）" % key)
	var btn: TextureButton = screen._forge_btn
	var mask := btn.texture_click_mask
	t.check(mask != null and mask.get_bitv(Vector2i(84, 78)) and not mask.get_bitv(Vector2i(1, 1)), "「铸牌」键只认盾牌：中心能点、角上的光不算")
	t.eq(btn.name, "铸牌", "键名「铸牌」")
	var bag: Rect2 = screen.spot_rect("bag")
	t.check(Rect2(Vector2.ZERO, screen.size).encloses(bag) and bag.size.x > 0.0, "背包摆在工作台皮垫上、不出屏（%s）" % bag)
	var baked := true
	for n in screen.find_children("*", "Label", true, false):
		baked = baked and not ((n as Label).text in ["【时机】", "【效果】", "【数值】", "出牌", "铸炉"])
	t.check(baked, "画在底图里的标签代码不再写")
	t.check(screen.put_in(0, uids[0]) and screen.put_in(1, uids[1]), "放进时机、效果")
	t.check(not screen.put_in(1, uids[3]), "一槽一件")
	t.check(screen.forge() == null, "差一槽不能铸")
	t.check(screen.put_in(2, uids[2]), "放进数值")
	t.check(screen.preview_text().contains("将铸出：铸牌 · 嗜血的"), "预览（%s）" % screen.preview_text())
	t.eq(screen.forge_btn_state(), "ready", "三槽满：「铸牌」键发亮、能按")
	var tok: ItemInstance = screen.forge()
	t.not_null(tok, "铸成")
	t.eq(screen.output().item_count(), 1, "出牌槽一枚")
	for i in 3:
		t.eq(screen.slot(i).item_count(), 0, "槽 %d 空了" % i)
	t.check(NodeEvents.forge_used(node), "铸炉熄了")
	t.eq(screen.backdrop_state(), "cold", "铸过：换冷炉底")
	t.eq(screen.forge_btn_state(), "off", "铸过：「铸牌」键灰掉")
	t.check(screen.to_map(), "返回")
	t.check(flow.screen != GameFlow.Screen.FORGE, "离开了铸炉屏")
	t.check(tok != null and flow.run.holder_of(tok.uid) != null, "铸牌回了背包（棋盘或地上）")
	game.queue_free()
	Support.cleanup("forge_ui")

## 108（作者定）：武器附加效果的统一接口 —— 邻居的增益规则（毒箭挨着弓）与日神附魔都走编译器的 `_attach`：
## 规则挂到宿主身上、只听宿主出手、以宿主身份结算、记下来源给悬浮窗写「← 毒箭」。
extends RefCounted


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 一块不要求包的格子：弓横着放在第一行（143：长弓是两头弯回的弓臂，横过来第一行 4 格是弓身、第二行只有两头），
## [param arrows] 个毒箭摆在弓身正下方第二行的空处（增益格朝上，正好压在弓上）
static func _bow_board(db: ItemDatabase, arrows: int) -> Dictionary:
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(6, 4), 1, false)
	var bow := ItemInstance.create(db.get_def(&"longbow"))
	var rot := 0
	for r in 4:
		var cells := bow.def.cells_rotated(r)
		var top := 0
		for c in cells:
			if c.y == 0:
				top += 1
		if _width(cells) == 4 and top == 4:
			rot = r
			break
	g.place(bow, Vector2i.ZERO, rot)
	var under: Array[int] = []
	for x in 4:
		if not bow.def.cells_rotated(rot).has(Vector2i(x, 1)):
			under.append(x)
	var placed: Array[ItemInstance] = []
	for i in arrows:
		var a := ItemInstance.create(db.get_def(&"poison_arrows"))
		g.place(a, Vector2i(under[i], 1), 0)
		placed.append(a)
	return {"board": g, "bow": bow, "arrows": placed}


static func _width(cells: Array[Vector2i]) -> int:
	var w := 0
	for c in cells:
		w = maxi(w, c.x + 1)
	return w


static func run_neighbor_attach(t: TestCase) -> void:
	t.begin("108 · 毒箭贴着弓：弓身上多一条附加规则，只听弓出手、记着来源；不挨着 / 挨着近战就没有")
	var db := _items()
	t.not_null(db.get_def(&"poison_arrows"), "有毒箭")
	var one := _bow_board(db, 1)
	var spec := BattleCompiler.compile_board(one["board"])
	var bow := spec.item_of((one["bow"] as ItemInstance).uid)
	t.eq(bow.attached.size(), 1, "弓挂了一条")
	var idx := int(bow.attached[0]["rule_index"])
	t.eq(bow.attached[0]["origin"], &"poison_arrows", "来源是毒箭")
	var rule := bow.rules[idx]
	t.check(rule.trigger is OnItemFired, "触发器是出手时")
	t.eq((rule.trigger as OnItemFired).source_uids, [bow.source_uid] as Array[int], "绑成只听弓自己")
	t.check((rule.trigger as OnItemFired).include_self, "自己出手算")
	t.check(rule.effects[0] is ApplyStatus and (rule.effects[0] as ApplyStatus).buff.id == &"poison", "效果是施加中毒")
	var arrow_item := spec.item_of((one["arrows"][0] as ItemInstance).uid)
	t.check(arrow_item == null or arrow_item.attached.is_empty(), "毒箭自己身上不挂")
	var linked := bow.linked_uids
	t.check(linked.has((one["arrows"][0] as ItemInstance).uid), "顺带连结（和 grant_mods 一样）")

	var two := _bow_board(db, 2)
	var bow2 := BattleCompiler.compile_board(two["board"]).item_of((two["bow"] as ItemInstance).uid)
	t.eq(bow2.attached.size(), 2, "两件毒箭 → 挂两条（每个邻居各一份）")

	var none := _bow_board(db, 0)
	var lone := ItemInstance.create(db.get_def(&"poison_arrows"))
	(none["board"] as GridInventory).place(lone, Vector2i(5, 3), 0)
	var bow0 := BattleCompiler.compile_board(none["board"]).item_of((none["bow"] as ItemInstance).uid)
	t.eq(bow0.attached.size(), 0, "不挨着就没有")

	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(3, 3), 1, false)
	var knife := ItemInstance.create(db.get_def(&"knife"))
	g.place(knife, Vector2i.ZERO, 0)
	g.place(ItemInstance.create(db.get_def(&"poison_arrows")), Vector2i(0, 1), 0)
	t.eq(BattleCompiler.compile_board(g).item_of(knife.uid).attached.size(), 0, "挨着近战武器不生效（只给远程）")


static func run_attach_in_battle(t: TestCase) -> void:
	t.begin("108 · 打起来：弓每次出手对手 +1 层中毒；拿掉毒箭就没有")
	var db := _items()
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(400.0)
	var foe := BattleCompiler.compile(null, foe_in)
	for arrows in [1, 0]:
		var b := _bow_board(db, arrows)
		var me := BattleCompiler.compile_board(b["board"], CombatantBaseline.with_hp(400.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var res := BattleSim.run(me, foe, rng, 10.0)
		var fired := 0
		var poisoned := 0
		for ev in res.log:
			var e := ev as BattleEvent
			if e.name == BattleEvent.ITEM_FIRED and e.side == 0 and int(e.payload.get("uid", -1)) == (b["bow"] as ItemInstance).uid:
				fired += 1
			if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and String(e.payload.get("buff", "")) == "poison":
				poisoned += int(e.payload.get("delta", 0))
		if arrows == 1:
			t.check(fired > 0, "弓出手了 %d 次" % fired)
			t.eq(poisoned, fired, "每次出手一层中毒（%d 层）" % poisoned)
		else:
			t.eq(poisoned, 0, "没有毒箭：对手不中毒")


static func run_faith_origin(t: TestCase) -> void:
	t.begin("108 · 日神附魔走同一个入口：挂法不变，来源记成 faith:sun；悬浮窗写神名")
	var db := _items()
	var one := _bow_board(db, 0)
	var inp := CompileInput.new()
	var scope := ScopedMod.new()
	scope.tags = [&"weapon"] as Array[StringName]
	scope.rules = [EnchantWeaponsPerk.new().rule()] as Array[AbilityRule]
	scope.origin = FaithTags.tag_of(&"sun")
	inp.scoped.append(scope)
	var bow := BattleCompiler.compile(one["board"], inp).item_of((one["bow"] as ItemInstance).uid)
	t.eq(bow.attached.size(), 1, "挂了一条附火")
	t.eq(bow.attached[0]["origin"], &"faith:sun", "来源是日神")
	t.check(bow.rules[int(bow.attached[0]["rule_index"])].effects[0] is FireEnchant, "就是附火规则")
	t.check(ItemTooltip.origin_name(&"faith:sun") != "faith:sun" and ItemTooltip.origin_name(&"faith:sun") != "", "神名：%s" % ItemTooltip.origin_name(&"faith:sun"))
	var no_origin := ScopedMod.new()
	no_origin.rules = scope.rules
	var inp2 := CompileInput.new()
	inp2.scoped.append(no_origin)
	var bow2 := BattleCompiler.compile(one["board"], inp2).item_of((one["bow"] as ItemInstance).uid)
	t.eq([bow2.rules.size(), bow2.attached.size()], [bow.rules.size(), 0], "没填来源照样挂，只是不记")


static func run_tooltips(t: TestCase) -> void:
	t.begin("108 · 悬浮窗：弓写「附加：… ← 毒箭」、中毒进侧窗；毒箭自己写给邻居附加什么")
	var db := _items()
	var saved := ItemTooltip.faith_probe
	ItemTooltip.faith_probe = Callable()
	var one := _bow_board(db, 1)
	var full := ItemTooltip.describe_full(one["bow"], one["board"])
	var text := String(full["text"])
	t.check(text.contains("附加：") and text.contains("← 毒箭"), "弓：附加行带来源")
	t.check(text.contains("中毒"), "附加行写了中毒")
	var names: Array = []
	for term in full["terms"]:
		names.append(String((term as Dictionary)["name"]))
	t.check(names.has("中毒"), "中毒进了弓的侧窗：%s" % str(names))
	var alone := String(ItemTooltip.describe_full(ItemInstance.create(db.get_def(&"longbow")))["text"])
	t.check(not alone.contains("附加："), "不在棋盘上（单独编）没有附加行")
	var arrows := ItemTooltip.describe_full(ItemInstance.create(db.get_def(&"poison_arrows")))
	t.check(String(arrows["text"]).contains("增益槽") and String(arrows["text"]).contains("附加："), "毒箭：增益槽写附加")
	var anames: Array = []
	for term in arrows["terms"]:
		anames.append(String((term as Dictionary)["name"]))
	t.check(anames.has("中毒"), "毒箭的侧窗也解释中毒")
	ItemTooltip.faith_probe = saved


static func _import(data: Dictionary) -> ImportReport:
	var r := ImportReport.new()
	ContentImporter.import_item(data, ContentImporter.Context.new(), r)
	return r


static func _has_error(r: ImportReport, needle: String) -> bool:
	for e in r.errors:
		if String(e["message"]).contains(needle):
			return true
	return false


static func run_import_checks(t: TestCase) -> void:
	t.begin("108 · 附加规则的导入校验：只许出手时、不许消耗、不许直接毒伤；乘区 FIRE 旧名报错（109）")
	var base := {"id": "x", "shape": ["1"], "adjacency": {"grant_cells": [[0, -1]]}}
	var ok := base.duplicate(true)
	ok["adjacency"]["grant_rules"] = [{"trigger": {"type": "on_item_fired"}, "cadence": {"type": "always"},
		"effects": [{"type": "deal_damage", "damage_type": "fire", "amount": 2.0}]}]
	t.check(_import(ok).ok(), "出手时附带火焰伤害：合法")
	var when := base.duplicate(true)
	when["adjacency"]["grant_rules"] = [{"trigger": {"type": "on_battle_start"}, "cadence": {"type": "always"}, "effects": [{"type": "deal_damage"}]}]
	t.check(_has_error(_import(when), "宿主出手"), "开战时 → error")
	var cost := base.duplicate(true)
	cost["adjacency"]["grant_rules"] = [{"trigger": {"type": "on_item_fired"}, "cadence": {"type": "always"},
		"costs": [{"type": "resource", "amount": 2.0}], "effects": [{"type": "deal_damage"}]}]
	t.check(_has_error(_import(cost), "消耗"), "有消耗 → error")
	var poison := base.duplicate(true)
	poison["adjacency"]["grant_rules"] = [{"trigger": {"type": "on_item_fired"}, "cadence": {"type": "always"},
		"effects": [{"type": "deal_damage", "damage_type": "poison", "amount": 2.0}]}]
	t.check(_has_error(_import(poison), "毒与流血没有直接伤害形态"), "直接毒伤 → error（107 那条同样管附加规则）")
	# 133：乘区整个取消（109 的 FIRE → ELEMENT 改名随之作废）：旧写法只提醒、按乘算读
	var fire_cat := {"id": "y", "shape": ["1"], "is_bag": true}
	fire_cat["bag_mods"] = [{"stat": "damage", "mult_category": "ELEMENT", "mult_percent": 10}]
	var good := _import(fire_cat)
	t.check(good.ok() and good.to_text().contains("乘区已取消"), "旧的乘区写法：提醒、照读 %s" % good.to_text())


static func run_enchant_fires_once_per_hit(t: TestCase) -> void:
	t.begin("108 · 附加规则不算宿主再出手一次：日神附火每击一次（之前会自己触发自己，连锁到截断）")
	var db := _items()
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(4, 4), 1, false)
	var sword := ItemInstance.create(db.get_def(&"longsword"))
	g.place(sword, Vector2i.ZERO, 0)
	var inp := CompileInput.new()
	var scope := ScopedMod.new()
	scope.tags = [&"weapon"] as Array[StringName]
	scope.rules = [EnchantWeaponsPerk.new().rule()] as Array[AbilityRule]
	inp.scoped.append(scope)
	var me := BattleCompiler.compile(g, inp)
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(4000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var res := BattleSim.run(me, BattleCompiler.compile(null, foe_in), rng, 5.0)
	var fired := 0
	var fire_hits := 0
	var overflow := 0
	for ev in res.log:
		var e := ev as BattleEvent
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0:
			fired += 1
		elif e.name == BattleEvent.DAMAGE and e.side == 1 and String(e.payload.get("type", "")) == "fire":
			fire_hits += 1
		elif e.name == BattleEvent.DISPATCH_OVERFLOW:
			overflow += 1
	t.check(fired > 0, "长剑出手 %d 次" % fired)
	t.eq(fire_hits, fired, "每击附火一次")
	t.eq(overflow, 0, "没有连锁截断")


static func run_compile_without_board(t: TestCase) -> void:
	t.begin("140 B-12 · 没有棋盘也照算后续步骤：基线 + 负的基线修饰 → 生命夹到 0，不是原样返回基线")
	var base := CombatantBaseline.with_hp(20.0)
	var inp := CompileInput.of(base)
	inp.baseline_mods = [StatModifier.make(&"max_hp", StatModifier.Mode.ADD, -50.0)] as Array[StatModifier]
	var spec := BattleCompiler.compile(null, inp)
	t.not_null(spec, "空棋盘编得出来")
	t.eq(spec.max_hp_int() if spec != null else -1, 0, "生命 20 − 50 夹到 0")
	var plain := BattleCompiler.compile(null, CompileInput.of(base))
	t.eq(plain.max_hp_int(), 20, "没有修饰：就是基线的 20")

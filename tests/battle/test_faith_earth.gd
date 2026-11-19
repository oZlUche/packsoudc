## 信仰重构 C（交接方案 §6.4）：大地之神「空间承托」—— 大件（≥ 5 格，一阶起 ≥ 4 格）每有一件不同的有效道具贴边一层，最多 2 层；
## 角接触不算、同一邻居多条边只算一次、包与不参战的不算；攻击型减耐力、防御型加格挡 / 护甲；三阶开战按件给护甲；与放置先后无关。
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")


static func _big(id: String, tags: Array, rows: Array = ["111", "11."]) -> ItemDef:
	var d := Comp._weapon(id, rows, 10.0, 1.0, tags)
	if tags.has("shield"):
		d.combat.base_stats = {"block": 10.0}
	return d


static func _small(id: String) -> ItemDef:
	return Comp._weapon(id, ["1"], 1.0, 1.0, ["weapon", "melee"])


static func run_layers(t: TestCase) -> void:
	t.begin("信仰重构 C · 承托：正交贴边一层、角接触不算、同一邻居只算一次、最多 2 层、包和不参战的不算、按 uid 可复现")
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	var big := ItemInstance.create(_big("t_big", ["weapon", "melee"]))     # 5 格：(1,1)(2,1)(3,1)(1,2)(2,2)
	b.place(big, Vector2i(1, 1), 0)
	var corner := ItemInstance.create(_small("t_corner"))
	b.place(corner, Vector2i(0, 0), 0)     # 只碰角
	t.eq(EarthSupport.layers(b, &"").get(big.uid, 0), 0, "角接触不算")
	var long := ItemInstance.create(Comp._weapon("t_long", ["11"], 1.0, 1.0, ["weapon", "melee"]))
	b.place(long, Vector2i(1, 0), 0)     # 贴着上边两条边
	t.eq(EarthSupport.layers(b, &""), {big.uid: 1}, "同一个邻居两条边：一层")
	var right := ItemInstance.create(_small("t_right"))
	b.place(right, Vector2i(4, 1), 0)
	var under := ItemInstance.create(_small("t_under"))
	b.place(under, Vector2i(1, 3), 0)
	t.eq(EarthSupport.layers(b, &""), {big.uid: 2}, "三件贴边：封顶 2 层")
	right.set_benched(true)
	under.set_benched(true)
	t.eq(EarthSupport.layers(b, &""), {big.uid: 1}, "标了不参战的不算")
	var four := GridInventory.new(Vector2i(6, 6), 1, false)
	var mid := ItemInstance.create(Comp._weapon("t_mid", ["11", "11"], 10.0, 1.0, ["weapon", "melee"]))
	four.place(mid, Vector2i(0, 0), 0)
	four.place(ItemInstance.create(_small("t_n")), Vector2i(2, 0), 0)
	t.check(EarthSupport.layers(four, &"", 5).is_empty(), "4 格的中件：基础不算大件")
	t.eq(EarthSupport.layers(four, &"", 4), {mid.uid: 1}, "一阶起 4 格也算")
	# 换个放置顺序，结果一样
	var b2 := GridInventory.new(Vector2i(8, 6), 1, false)
	var u := ItemInstance.create(_small("t_under"))
	b2.place(u, Vector2i(1, 3), 0)
	var big2 := ItemInstance.create(_big("t_big", ["weapon", "melee"]))
	b2.place(big2, Vector2i(1, 1), 0)
	t.eq(EarthSupport.layers(b2, &"").get(big2.uid, 0), 1, "先放邻居再放大件：一样一层")


static func run_effects(t: TestCase) -> void:
	t.begin("信仰重构 C · 承托：武器减耐力消耗、盾加格挡；开战写战记；三阶按件给护甲（封顶）")
	var perk := EarthSupportPerk.new()
	var sword := _big("t_big", ["weapon", "melee"])
	var mods := perk.mods_for(sword, 2)
	t.check(mods.size() == 1 and mods[0].stat == BattleStats.STAMINA_COST and is_equal_approx(mods[0].amount, -8.0), "武器 2 层：耐力消耗 −8%")
	var shield := _big("t_shield", ["shield"])
	var smods := perk.mods_for(shield, 1)
	t.check(smods.size() == 1 and smods[0].stat == BattleStats.BLOCK and is_equal_approx(smods[0].amount, 4.0), "盾 1 层：格挡 +4%")
	t.check(perk.mods_for(Comp._item("t_food", ["1"], ["food"]), 2).is_empty(), "不是武器也不是盾 / 防具：不领")
	# 编译：按 uid 的修饰进了那一件
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	var big := ItemInstance.create(sword)
	b.place(big, Vector2i(1, 1), 0)
	b.place(ItemInstance.create(_small("t_n")), Vector2i(4, 1), 0)
	var input := CompileInput.of(CombatantBaseline.with_hp(100.0))
	perk.compile_into(input, b, null)
	t.eq(input.item_mods.keys(), [big.uid], "只给受承托的那件")
	var spec := BattleCompiler.compile(b, input)
	var plain := BattleCompiler.compile(b, CompileInput.of(CombatantBaseline.with_hp(100.0)))
	t.check(spec.stats_of(big.uid).percent_factor(BattleStats.STAMINA_COST) < plain.stats_of(big.uid).percent_factor(BattleStats.STAMINA_COST), "编译后这件的耐力消耗系数变小了")
	var res := BattleSim.run(spec, FX._spec(5000.0, []), RandomNumberGenerator.new(), 1.0)
	var said := false
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("key", "")) == "earth_support" and int(e.payload.get("count", 0)) == 1:
			said = true
	t.check(said, "开战写一句：1 件受承托")
	# 三阶护甲
	var eff := EarthSupport.new()
	eff.supported = 9
	eff.armor_percent = 2
	eff.armor_cap = 10
	var rule := AbilityRule.new()
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BATTLE_START] as Array[StringName]
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	rule.effects.append(eff)
	var me := FX._spec(1000.0, [])
	me.set_rules = [rule] as Array[AbilityRule]
	var r3 := BattleSim.run(me, FX._spec(5000.0, []), RandomNumberGenerator.new(), 0.5)
	var armor := 0
	for raw in r3.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.payload.get("key", "")) == "armor":
			armor = int(e.payload.get("max", 0))
	t.eq(armor, StatMath.from_float(100.0), "9 件 × 2% 封顶 10%：1000 生命给 100 护甲")

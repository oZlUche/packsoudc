## 279 补充二：品质 —— 砧上用了比配方要求高的材料，这一件记几档品质（上限 2）；编译时伤害 / 格挡 / 护甲 ×(1 + 0.1 × 品质)、
## 句子里的个数每档 +1、自带的百分比每档 +5 点，耐力价不动、定义不碰；悬浮窗写最终值、名字旁菱形；存档往返
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const T251 := preload("res://tests/meta/test_smithy_251.gd")


static func _db() -> ItemDatabase:
	return T110._db()


static func _compiled(db: ItemDatabase, id: StringName, q: int) -> CompiledItem:
	var board := GridInventory.new(Vector2i(4, 4), 0, false)
	var inst := ItemInstance.create(db.get_def(id), 0)
	inst.set_quality(q)
	board.place(inst, Vector2i.ZERO, 0)
	return BattleCompiler.compile_board(board).item_of(inst.uid)


static func _fx(item: CompiledItem, rule: int, effect: int) -> CombatEffect:
	return (item.rules[rule] as AbilityRule).effects[effect]


static func run_state(t: TestCase) -> void:
	t.begin("279 补充二 · 品质记在这一件上：0 不写键，上限 2，存档往返还是整数")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var inst := ItemInstance.create(db.get_def(&"broadsword"), 0)
	t.eq(inst.quality(), 0, "新的一件 0 档")
	inst.set_quality(5)
	t.eq(inst.quality(), 2, "上限 2")
	var back := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(inst.to_dict())), db)
	t.check(back != null and back.quality() == 2 and typeof(back.state[ItemInstance.QUALITY_KEY]) == TYPE_INT, "存档往返：还是整数 2")
	inst.set_quality(0)
	t.check(not inst.state.has(ItemInstance.QUALITY_KEY), "0 档不写键")


static func run_compile(t: TestCase) -> void:
	t.begin("279 补充二 · 编译：伤害 ×1.1 每档（向下取整），写死的点数 +1 每档，暴击 +5 点每档；层数每档 +1（281 照加：每下触发的和一次性的都加）；耐力价不动，定义不碰")
	var db := _db()
	var a := _compiled(db, &"steel_broadsword", 0)
	var b := _compiled(db, &"steel_broadsword", 2)
	t.check(is_equal_approx(StatMath.to_float(b.stats.total_of(BattleStats.DAMAGE)), 13.2), "钢阔剑伤害 11 → 13.2")
	t.eq((_fx(a, 0, 1) as DealDamage).amount, 5.0, "0 档：其中 5 点真实伤害")
	t.eq((_fx(b, 0, 1) as DealDamage).amount, 7.0, "2 档：其中 7 点")
	t.eq((_fx(b, 1, 0) as PrimeNextHit).amount, 4.0, "下一下加伤 2 → 4")
	var cost_a: Variant = ((a.rules[0] as AbilityRule).costs[0] as Resource).get("amount")
	var cost_b: Variant = ((b.rules[0] as AbilityRule).costs[0] as Resource).get("amount")
	t.eq(cost_b, cost_a, "耐力价不动")
	var def_rule := BattleCompiler.profile_of(db.get_def(&"steel_broadsword"), false).rules[0] as AbilityRule
	t.eq((def_rule.effects[1] as DealDamage).amount, 5.0, "定义里还是 5")
	var axe := _compiled(db, &"bone_battle_axe", 1)
	t.eq((_fx(axe, 0, 1) as ApplyStatus).stacks, 3, "兽骨战斧每下流血 2 → 3（281 照加）")
	t.eq((_fx(axe, 1, 0) as DealDamage).amount, 5.0, "流血够层追加 4 → 5")
	var club := _compiled(db, &"club", 2)
	t.eq((_fx(club, 0, 1) as ShiftAxis).delta, -3, "棍棒每下减速 1 → 3 层（281 照加）")
	var fang := _compiled(db, &"bonefang_dagger", 2)
	t.check(is_equal_approx(StatMath.to_float(fang.stats.total_of(BattleStats.CRIT_CHANCE)), 0.25), "骨牙匕首暴击 15% → 25%")
	var bleed := _fx(fang, 0, 1) as ApplyStatus
	var plain := _fx(_compiled(db, &"bonefang_dagger", 0), 0, 1) as ApplyStatus
	t.check(bleed != plain and bleed.stacks == plain.stacks + 2 and bleed.buff == plain.buff, "规则件拷了一份，每下流血 +2 层，还是同一个 buff")
	var maul := _compiled(db, &"meteor_maul", 2)
	var maul0 := _compiled(db, &"meteor_maul", 0)
	var once := _fx(maul, 1, 0) as ShiftAxis
	var once0 := _fx(maul0, 1, 0) as ShiftAxis
	t.check(absi(once.delta) == absi(once0.delta) + 2 and signi(once.delta) == signi(once0.delta), "陨铁大锤开战那一下的轴层数 +2（一次性的照加）")


static func run_forge(t: TestCase) -> void:
	t.begin("279 补充二 · 铁匠铺：材料比要求高几档，产物就几档；和吃掉的那把取较高，不累加")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var r := SmithRecipeDef.find(SmithRecipeDef.load_all(), &"anvil_bone_broadsword")
	var m := T251._meta(1)
	m.funds = 1000
	T110._add(m, db, &"broadsword")
	T110._add(m, db, &"beast_claw")     # 骨、蓝：比要求的绿高一档
	var out := Smithy.forge(m, r, db)
	t.check(out != null and out.quality() == 1, "兽爪顶上：1 档")
	var old := T110._add(m, db, &"broadsword")
	old.set_quality(2)
	T110._add(m, db, &"antler")     # 骨、绿：正好
	var out2 := Smithy.forge(m, r, db)
	t.check(out2 != null and out2.quality() == 2, "吃掉的那把是 2 档：取较高")


static func run_tooltip(t: TestCase) -> void:
	t.begin("279 补充二 · 悬浮窗：名字旁一档一个菱形；句子与自带属性写算完的数")
	var db := _db()
	var inst := ItemInstance.create(db.get_def(&"steel_broadsword"), 0)
	var raw0 := ItemTooltip.describe(inst)
	var plain := Glossary.strip_bbcode(raw0)
	t.check(plain.contains("其中 5 点真实伤害") and not raw0.contains(ItemTooltip.QUALITY_BADGE), "0 档：5 点、没有金菱")
	inst.set_quality(2)
	var raw2 := ItemTooltip.describe(inst)
	var text := Glossary.strip_bbcode(raw2)
	t.eq(raw2.count(ItemTooltip.QUALITY_BADGE), 2, "2 档：名字后两枚金菱")
	t.check(text.contains("其中 7 点真实伤害"), "2 档：其中 7 点（%s）" % text.replace("\n", " | "))
	var fang := ItemInstance.create(db.get_def(&"bonefang_dagger"), 0)
	fang.set_quality(1)
	t.check(Glossary.strip_bbcode(ItemTooltip.describe(fang)).contains("暴击率 20%"), "骨牙匕首 1 档：暴击率 20%")


static func run_tooltip_numbers(t: TestCase) -> void:
	t.begin("279 测试 v5.14 · 按武器伤害打的那一下也写算完的数（刽子手巨斧的斩杀句）")
	var db := _db()
	var text := Glossary.strip_bbcode(ItemTooltip.describe(ItemInstance.create(db.get_def(&"executioner_axe"), 0)))
	var m := RegEx.create_from_string("29%，造成 ([0-9.]+) 点物理伤害").search(text)
	t.check(m != null and float(m.get_string(1)) > 0.0, "斩杀句写了点数（%s）" % text.replace("\n", " | "))


static func run_tooltip_crossbow_text(t: TestCase) -> void:
	t.begin("279 测试 v5.15 · 钢弩：出手时那句单独写「造成 5 点真实伤害」；可升为同一产物只写一遍")
	var db := _db()
	var text := Glossary.strip_bbcode(ItemTooltip.describe(ItemInstance.create(db.get_def(&"steel_crossbow"), 0)))
	t.check(text.contains("造成 5 点真实伤害") and not text.contains("其中 5 点"), "单独一段的真实伤害有主句（%s）" % text.replace("\n", " | "))
	t.check(text.contains("可升为") and not text.contains("重弩 / 重弩"), "可升为不重复")
	var sword := Glossary.strip_bbcode(ItemTooltip.describe(ItemInstance.create(db.get_def(&"steel_broadsword"), 0)))
	t.check(sword.contains("其中") and sword.contains("点真实伤害"), "跟在主伤害后面的仍写「其中 N 点真实伤害」")

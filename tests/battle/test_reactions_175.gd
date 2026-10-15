## 175 第一批：元素印与反应表 —— 施加印即盖印（补充五：伤害不再顺手盖印）；反应不连锁；导入器的校验。
## 175 补充一 / 三（作者伪代码，更正为 min）：取层数最多的异色印、N = min(已有, 新来)、两边各扣 N、新印余量照常叠且不再反应。
## 补充二：反应效果里的数字可写成随 N 变（per_stack / stacks: n / seconds: n + max）。
## 补充四（作者定稿）：五种印都可叠、不封顶、永续，按自己的规矩结算 / 衰减（灼伤与中毒每秒层数点、流血真实伤害跳后减半、
## 寒冷拉长武器冷却后减半、麻痹加耐力消耗后减半）；十对反应各一例 N = 1 与 N = 3；保底（凝毒 / 冻疮）；剧毒；激荡溢出；M 都从 json 读
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")
const S := preload("res://tests/battle/test_status_synergy.gd")


static func _b(id: String) -> BuffDef:
	return ContentLibrary.buffs().get(StringName(id), null)


static func _hit(type: StringName, amount: float) -> DealDamage:
	return S._flat(amount, type)


static func _apply(id: String, stacks: int = 1) -> ApplyStatus:
	return S._apply(_b(id), stacks)


static func _heal_opp(amount: float) -> ChangeResource:
	var e := ChangeResource.new()
	e.target = CombatEffect.Target.OPPONENT
	e.resource_key = BattleStats.RES_HP
	e.amount = amount
	return e


static func _cleanse(id: String) -> RemoveStatus:
	var e := RemoveStatus.new()
	e.target = CombatEffect.Target.OPPONENT
	e.buff_id = StringName(id)
	e.stacks = 0
	return e


static func _cleanse_all() -> RemoveStatus:
	var e := RemoveStatus.new()
	e.target = CombatEffect.Target.OPPONENT
	e.all_debuffs = true
	return e


## 开战那一刻依次跑 [param effects]（打对手）的一场；[param side1_stats] 是对手那件的属性
static func _run(effects: Array, side1_stats: Dictionary = {}) -> BattleContext:
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [S._opener(effects)])]),
		H._spec(100.0, [H._compiled(2, "b", side1_stats, [])]))
	S._start(ctx)
	return ctx


static func _reactions(ctx: BattleContext) -> Array[StringName]:
	return ReactionResolver.reactions_in(ctx.log)


## 开战后直接在对手身上挂 [param pn] 层 [param present]，再由自己给对手施加 [param inn] 层 [param incoming]（引发反应）
static func _react(present: String, pn: int, incoming: String, inn: int, side1_stats: Dictionary = {}) -> BattleContext:
	var ctx := _run([], side1_stats)
	ctx.sides[1].apply_buff(_b(present), pn, ctx.now)
	_apply(incoming, inn).apply(_rc(ctx))
	return ctx


static func _rc(ctx: BattleContext) -> RuleContext:
	return RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))


static func _axis(ctx: BattleContext, side: int, axis: StringName) -> int:
	return ctx.sides[side].axis_stacks(axis)


static func run_marks(t: TestCase) -> void:
	t.begin("175 补充四 / 五 · 五种印：都可叠、不封顶、永续；灼伤 / 中毒每秒层数点、流血真实伤害跳后减半；印只从施加来，伤害不盖印")
	t.check(not ("mark" in DamageTypes.get_def(DamageTypes.FIRE)), "补充五：伤害类型没有「盖印」这一项了")
	var names := {"scorch": "灼伤", "chill": "寒冷", "numb": "麻痹", "poison": "中毒", "bleed": "流血"}
	var elements := {"scorch": &"fire", "chill": &"ice", "numb": &"lightning", "poison": &"poison", "bleed": &"bleed"}
	for id in names:
		var b := _b(id)
		t.not_null(b, "有印 %s" % id)
		if b != null:
			t.check(b.is_stackable() and b.is_permanent() and b.element == elements[id], "%s 可叠、永续、是%s印" % [id, elements[id]])
			t.eq(b.display_name, String(names[id]), "%s 的名字" % id)
	t.eq(_b("virulent").element, &"", "剧毒不再是印（补 4.2 第 8 条）")
	t.check(DamageTypes.get_def(DamageTypes.BLEED).pure, "流血是真实伤害")
	t.eq(DamageTypes.family_of(DamageTypes.BLEED), DamageTypes.PHYSICAL, "补充五：流血是真实 · 物理（family = physical）")
	t.eq(DamageTypes.nature(DamageTypes.BLEED, "zh"), "真实 · 物理", "词条的「真实 · 物理」从数据来")
	t.check(DamageTypes.describe(DamageTypes.BLEED, "zh").begins_with("真实 · 物理。"), "流血的说明以「真实 · 物理」开头")
	for id in [DamageTypes.PHYSICAL, DamageTypes.FIRE, DamageTypes.ICE, DamageTypes.LIGHTNING, DamageTypes.POISON, DamageTypes.REFLECT, DamageTypes.DRAIN]:
		t.check(not DamageTypes.get_def(id).pure and DamageTypes.family_of(id) == id, "%s：不是真实伤害，大类是自己" % id)

	var ctx := _run([_hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.ICE, 1.0), _hit(DamageTypes.LIGHTNING, 1.0)])
	t.check(ctx.sides[1].buffs.is_empty(), "补充五：火、冰、雷伤害只是伤害，身上没有印")
	t.check(_reactions(ctx).is_empty(), "不施加就不反应")
	t.eq(S._hp(ctx, 1), 97, "伤害照打")
	ctx = _run([_apply("scorch")])
	t.eq([ctx.sides[1].stacks_of(&"scorch"), S._hp(ctx, 1)], [1, 100], "补充五：只施加灼伤不打伤害 —— 一层灼伤、不掉血")
	t.check(_reactions(ctx).is_empty(), "一种元素不反应")
	var many: Array = []
	for i in 12:
		many.append(_apply("scorch"))
	ctx = _run(many)
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 12, "十二次施加：十二层灼伤，不封顶（均无叠层上限）")
	t.check(_reactions(ctx).is_empty(), "同元素不反应")
	ctx = _run([_apply("poison", 2), _apply("poison", 3)])
	t.eq(ctx.sides[1].stacks_of(&"poison"), 5, "中毒再碰就是加层")

	# 灼伤：每秒层数点火伤，不衰减；自己跳的火伤不再盖灼伤；火焰照常吃护甲（待定 补 4.7 A）
	ctx = _run([_apply("scorch", 3)])
	H._advance_to(ctx, 1.05)
	t.eq(S._hp(ctx, 1), 97, "灼伤三层：一秒 3 点火伤")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 3, "跳完还是三层（不衰减、自己跳的火伤不盖印）")
	H._advance_to(ctx, 2.05)
	t.eq(S._hp(ctx, 1), 94, "第二秒再 3 点")
	ctx = _run([_apply("scorch", 3)], {"max_armor": 2})
	H._advance_to(ctx, 1.05)
	t.eq([S._hp(ctx, 1), StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_ARMOR))], [99, 0], "灼伤吃护甲：先扣 2 护甲，1 点见血")
	# 中毒：每秒层数点，不衰减
	ctx = _run([_apply("poison", 5)])
	H._advance_to(ctx, 1.05)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"poison")], [95, 5], "中毒五层：一秒 5 点，层数不变")
	# 流血：每秒层数点真实伤害，跳后减半（向下取整，待定 补 4.6 A）
	ctx = _run([_apply("bleed", 5)], {"max_armor": 30})
	H._advance_to(ctx, 1.05)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"bleed")], [95, 2], "流血五层：跳 5 点，剩 5 / 2 = 2 层")
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_ARMOR)), 30, "真实伤害不碰护甲")
	H._advance_to(ctx, 2.05)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"bleed")], [93, 1], "再跳 2 点，剩一层")
	H._advance_to(ctx, 3.05)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"bleed")], [92, 0], "最后一点，一层减半就没了")


static func run_slow(t: TestCase) -> void:
	t.begin("175 补充四 · 寒冷：武器出手时这一次的冷却 × (1 + 层数 × 每层%)，之后减半；麻痹：付耐力时消耗同样加成，之后减半")
	t.eq(_b("chill").decay_halve_on, BuffDef.HALVE_WEAPON_FIRED, "寒冷按武器出手减半")
	t.eq(_b("numb").decay_halve_on, BuffDef.HALVE_STAMINA_PAID, "麻痹按付耐力减半")
	var m_chill := _b("chill").per_stack_percent
	var m_numb := _b("numb").per_stack_percent
	t.check(m_chill > 0.0 and m_numb > 0.0, "每层百分比写在 json 里")
	# 寒冷四层：一秒冷却的武器第一下出手后，下一下排在 1 × (1 + 4M) 之后；寒冷剩两层；再出手 × (1 + 2M)，剩一层
	var weapon := H._rule(OnSchedule.new(), H._cooldown(1.0), [DealDamage.new()])
	var w := H._compiled(1, "w", {"damage": 1}, [weapon])
	w.tags = [&"weapon"] as Array[StringName]
	var ctx := H._battle(H._spec(100.0, [w]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	ctx.sides[0].apply_buff(_b("chill"), 4, ctx.now)
	H._advance_to(ctx, 1.0)
	var first := 1.0 + 1.0 * (1.0 + 4 * m_chill / 100.0)
	t.eq(_ready_at(ctx), StatMath.from_float(first), "第一下：冷却 × (1 + 4M)")
	t.eq(ctx.sides[0].stacks_of(&"chill"), 2, "出手后寒冷减半：剩两层")
	H._advance_to(ctx, first)
	t.eq(_ready_at(ctx), StatMath.from_float(first + 1.0 + 2 * m_chill / 100.0), "第二下：冷却 × (1 + 2M)")
	t.eq(ctx.sides[0].stacks_of(&"chill"), 1, "再减半：一层")
	# 不是武器的道具不吃寒冷，寒冷也不减半
	var trinket := H._compiled(1, "t", {"damage": 1}, [H._rule(OnSchedule.new(), H._cooldown(1.0), [DealDamage.new()])])
	ctx = H._battle(H._spec(100.0, [trinket]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	ctx.sides[0].apply_buff(_b("chill"), 4, ctx.now)
	H._advance_to(ctx, 1.0)
	t.eq([_ready_at(ctx), ctx.sides[0].stacks_of(&"chill")], [StatMath.from_float(2.0), 4], "非武器：冷却不变、寒冷不减")

	# 麻痹四层：付 10 耐力 → 付 10 × (1 + 4M)，剩两层；再付 10 × (1 + 2M)，剩一层
	ctx = H._battle(H._spec(100.0, [H._compiled(1, "a", {"max_stamina": 100}, [])]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	var me := ctx.sides[0]
	me.apply_buff(_b("numb"), 4, ctx.now)
	var cost := ResourceCost.new()
	cost.resource_key = BattleStats.RES_STAMINA
	cost.amount = 10.0
	var rc := _rc(ctx)
	var before := me.resources.current(BattleStats.RES_STAMINA)
	cost.pay(rc)
	t.eq(before - me.resources.current(BattleStats.RES_STAMINA), StatMath.from_float(10.0 * (1.0 + 4 * m_numb / 100.0)), "第一次：耐力消耗 × (1 + 4M)")
	t.eq(me.stacks_of(&"numb"), 2, "付完减半：剩两层")
	before = me.resources.current(BattleStats.RES_STAMINA)
	cost.pay(rc)
	t.eq(before - me.resources.current(BattleStats.RES_STAMINA), StatMath.from_float(10.0 * (1.0 + 2 * m_numb / 100.0)), "第二次：× (1 + 2M)")
	t.eq(me.stacks_of(&"numb"), 1, "再减半：一层")
	var mana := ResourceCost.new()
	mana.resource_key = &"mana"
	mana.amount = 1.0
	mana.pay(rc)
	t.eq(me.stacks_of(&"numb"), 1, "付的不是耐力：麻痹不减")


## 最近一次出手事件里的下一次就绪时刻
static func _ready_at(ctx: BattleContext) -> int:
	var at := -1
	for e in ctx.log:
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0:
			at = e.get_int(&"ready_at")
	return at


static func run_pure(t: TestCase) -> void:
	t.begin("175 补充四 · 真实伤害（流血）：跳过护甲、受伤前改写、格挡、「受到伤害」轴，原值落血")
	var before := DamageTypes.get_def(DamageTypes.BLEED)
	t.check(before.pure and not before.armor_absorbable and not before.provokes, "流血：真实、不吃护甲、不招致反应")
	var halve := ModifyDamage.new()
	halve.percent = -50
	var tr := OnBeforeDamage.new()
	tr.direction = DamageTrigger.Direction.TAKEN
	var vest := H._compiled(2, "vest", {"max_armor": 30, "block": 4}, [H._rule(tr, Always.new(), [halve])])
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [])]), H._spec(100.0, [vest]))
	S._start(ctx)
	var foe := ctx.sides[1]
	foe.shift_axis(StatAxes.DAMAGE_TAKEN, 10)     # 易伤 10 层
	DamageResolver.deal(ctx, foe, StatMath.from_float(10.0), DamageTypes.BLEED, 0, 1, true)
	t.eq(S._hp(ctx, 1), 90, "流血 10 点：护甲、受伤前减半、格挡、易伤都不动它")
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_ARMOR)), 30, "护甲没扣")
	var hp0 := S._hp(ctx, 1)
	DamageResolver.deal(ctx, foe, StatMath.from_float(40.0), DamageTypes.POISON, 0, 1, true)
	t.check(S._hp(ctx, 1) != hp0 - 40, "对照：同样是不吃护甲的中毒，照常被减半 / 格挡 / 易伤改动")


static func run_fire(t: TestCase) -> void:
	t.begin("175 补充四 · 火系反应：爆燃 N × M 火伤再叠 N / 2 层灼伤、淬裂扣 N × M 护甲无伤害、过载 N 层加速、燃血 N 层（每秒 N 点、N 秒）")
	var m_burst := _m("fire_poison", 0)
	var m_shatter := _m("fire_ice", 0)
	# 爆燃
	var ctx := _react("poison", 1, "scorch", 1)
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "引发爆燃")
	t.eq(S._hp(ctx, 1), 100 - roundi(m_burst), "N = 1：一下 M 点火伤")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 0, "N = 1：N / 2 = 0，不重叠灼伤（待定 补 4.2 A）")
	ctx = _react("poison", 3, "scorch", 3)
	t.eq(S._hp(ctx, 1), 100 - roundi(3 * m_burst), "N = 3：3M 火伤")
	t.eq([ctx.sides[1].stacks_of(&"scorch"), ctx.sides[1].stacks_of(&"poison")], [1, 0], "N = 3：重叠 3 / 2 = 1 层灼伤，中毒吃光")
	ctx = _run([_apply("poison", 3), _hit(DamageTypes.FIRE, 1.0), _apply("scorch")])
	t.eq([ctx.sides[1].stacks_of(&"poison"), S._hp(ctx, 1)], [2, 100 - 1 - roundi(m_burst)], "一下火伤 + 一层灼伤打三层中毒：N = min(3, 1) = 1，中毒剩两层")
	ctx = _run([_apply("poison", 3), _hit(DamageTypes.FIRE, 1.0)])
	t.check(_reactions(ctx).is_empty() and ctx.sides[1].stacks_of(&"poison") == 3, "补充五：只打火伤不施加灼伤，不引发爆燃")

	# 淬裂
	ctx = _react("chill", 1, "scorch", 1, {"max_armor": 30})
	t.eq(_reactions(ctx), [&"fire_ice"] as Array[StringName], "引发淬裂")
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_ARMOR)), 30 + roundi(m_shatter), "N = 1：护甲扣 M")
	t.eq(S._hp(ctx, 1), 100, "没有固定伤害")
	ctx = _react("chill", 3, "scorch", 3, {"max_armor": 30})
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_ARMOR)), 30 + roundi(3 * m_shatter), "N = 3：护甲扣 3M")

	# 过载
	ctx = _react("numb", 1, "scorch", 1)
	t.eq(_reactions(ctx), [&"fire_lightning"] as Array[StringName], "引发过载")
	t.eq(_axis(ctx, 0, StatAxes.ATTACK_SPEED), 1, "N = 1：自己一层加速")
	ctx = _react("numb", 3, "scorch", 3)
	t.eq(_axis(ctx, 0, StatAxes.ATTACK_SPEED), 3, "N = 3：三层加速")
	H._advance_to(ctx, 10.0)
	t.eq(_axis(ctx, 0, StatAxes.ATTACK_SPEED), 3, "轴层永续")
	_apply("numb", 2).apply(_rc(ctx))
	_apply("scorch", 2).apply(_rc(ctx))
	t.eq(_axis(ctx, 0, StatAxes.ATTACK_SPEED), 5, "可叠加：再过载 N = 2 → 五层")

	# 燃血
	ctx = _react("bleed", 1, "scorch", 1)
	t.eq(_reactions(ctx), [&"fire_bleed"] as Array[StringName], "引发燃血")
	t.eq([ctx.sides[1].stacks_of(&"scorched_blood"), ctx.sides[1].stacks_of(&"bleed")], [1, 0], "N = 1：一层燃血，流血吃光")
	H._advance_to(ctx, 1.05)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"scorched_blood")], [99, 0], "N = 1：一秒一点，一秒后消失")
	ctx = _react("bleed", 3, "scorch", 3)
	_hit(DamageTypes.PHYSICAL, 30.0).apply(_rc(ctx))
	_heal_opp(20.0).apply(_rc(ctx))
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"scorched_blood")], [70, 3], "N = 3：三层燃血，治疗为零")
	H._advance_to(ctx, 1.05)
	t.eq(S._hp(ctx, 1), 67, "每秒 3 点火伤")
	H._advance_to(ctx, 2.05)
	t.eq(S._hp(ctx, 1), 64, "第二秒还是 3 点")
	H._advance_to(ctx, 3.05)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"scorched_blood")], [61, 0], "第三秒 3 点后消失")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 0, "燃血跳的火伤不盖灼伤")
	ctx = _react("bleed", 3, "scorch", 3)
	ctx.sides[1].apply_buff(_b("bleed"), 2, ctx.now)
	_apply("scorch", 2).apply(_rc(ctx))
	var sb := ctx.sides[1].find_buff(&"scorched_blood")
	t.check(sb != null and sb.stacks == 5 and sb.seconds_left == 5, "再反应 N = 2：五层、还剩五秒（延长）")


## 反应 [param id] 第 [param i] 个效果随 N 变的系数（json 里的 M）
static func _m(id: String, i: int) -> float:
	var def := ReactionResolver.by_id(StringName(id))
	for raw in def.scaling:
		if int((raw as Dictionary)["effect"]) == i:
			return float((raw as Dictionary).get("x", 0.0))
	return 0.0


static func run_ice(t: TestCase) -> void:
	t.begin("175 补充四 · 冰系反应：超导 N 层易伤、凝毒给中毒 N 层保底、冻疮给流血 N 层保底")
	# 超导
	var ctx := _react("chill", 1, "numb", 1)
	t.eq(_reactions(ctx), [&"ice_lightning"] as Array[StringName], "引发超导")
	t.eq(_axis(ctx, 1, StatAxes.DAMAGE_TAKEN), 1, "N = 1：对手一层易伤")
	ctx = _react("chill", 3, "numb", 3)
	t.eq(_axis(ctx, 1, StatAxes.DAMAGE_TAKEN), 3, "N = 3：三层易伤，永续")

	# 凝毒：N 层中毒不可解除、不被消耗
	ctx = _react("poison", 1, "chill", 1)
	t.eq(_reactions(ctx), [&"ice_poison"] as Array[StringName], "引发凝毒")
	var p := ctx.sides[1].find_buff(&"poison")
	t.check(p != null and p.stacks == 1 and p.guard == 1, "N = 1：中毒被吃到 0 后补回一层锁死的（待定 补 4.5 A）")
	ctx = _react("poison", 5, "chill", 3)
	p = ctx.sides[1].find_buff(&"poison")
	t.check(p != null and p.stacks == 3 and p.guard == 3, "N = 3：五层中毒扣三剩二，保底三 → 补到三层")
	# 保底 3 的中毒 5 层：解毒后剩 3；被爆燃吃 N = 5 时算 N = 5、但剩 3
	ctx = _run([])
	var foe := ctx.sides[1]
	foe.apply_buff(_b("poison"), 5, ctx.now)
	foe.find_buff(&"poison").guard = 3
	_cleanse("poison").apply(_rc(ctx))
	t.eq(foe.stacks_of(&"poison"), 3, "解毒剂：清到保底三层为止")
	_cleanse_all().apply(_rc(ctx))
	t.eq(foe.stacks_of(&"poison"), 3, "清除全部减益也一样")
	foe.apply_buff(_b("poison"), 2, ctx.now)
	_apply("scorch", 5).apply(_rc(ctx))
	t.eq(S._hp(ctx, 1), 100 - roundi(5 * _m("fire_poison", 0)), "爆燃按 N = 5 算（保底的层也算数）")
	t.eq(foe.stacks_of(&"poison"), 3, "但中毒还剩三层（不会真正减少）")
	var hp0 := S._hp(ctx, 1)
	H._advance_to(ctx, 1.05)
	t.eq(S._hp(ctx, 1), hp0 - 3 - 2, "锁死的中毒照常每秒跳（3）+ 爆燃叠的两层灼伤（2）")

	# 冻疮：N 层流血不可解除、减半不低于保底
	ctx = _react("bleed", 1, "chill", 1)
	t.eq(_reactions(ctx), [&"ice_bleed"] as Array[StringName], "引发冻疮")
	var bl := ctx.sides[1].find_buff(&"bleed")
	t.check(bl != null and bl.stacks == 1 and bl.guard == 1, "N = 1：一层锁死的流血")
	H._advance_to(ctx, 2.05)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"bleed")], [98, 1], "一层流血减半也不掉：每秒 1 点一直跳")
	ctx = _react("bleed", 3, "chill", 3)
	bl = ctx.sides[1].find_buff(&"bleed")
	t.check(bl != null and bl.stacks == 3 and bl.guard == 3, "N = 3：三层锁死的流血")
	ctx = _run([])
	foe = ctx.sides[1]
	foe.apply_buff(_b("bleed"), 3, ctx.now)
	foe.find_buff(&"bleed").guard = 2
	H._advance_to(ctx, 1.05)
	t.eq([S._hp(ctx, 1), foe.stacks_of(&"bleed")], [97, 2], "保底 2 的流血 3 层：跳 3，3 / 2 = 1 < 2 → 重置为 2")
	H._advance_to(ctx, 2.05)
	t.eq([S._hp(ctx, 1), foe.stacks_of(&"bleed")], [95, 2], "之后每秒 2 点，不再衰减")


static func run_lightning(t: TestCase) -> void:
	t.begin("175 补充四 · 雷系与毒血：电解 N 层剧毒（只放大毒素伤害）、激荡 N 层暴击率（满了溢出到暴击伤害）、菌血 N 层（恢复减半、按到手的量叠中毒）")
	# 电解
	var ctx := _react("poison", 1, "numb", 1)
	t.eq(_reactions(ctx), [&"lightning_poison"] as Array[StringName], "引发电解")
	t.eq([ctx.sides[1].stacks_of(&"virulent"), ctx.sides[1].stacks_of(&"poison")], [1, 0], "N = 1：一层剧毒")
	ctx = _react("poison", 3, "numb", 3)
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 3, "N = 3：三层剧毒")
	var m_vir := float(_b("virulent").damage_taken_by_type.get("poison", 0.0))
	t.check(m_vir > 0.0, "剧毒每层的百分比写在 json 里")
	ctx = _run([])
	var foe := ctx.sides[1]
	foe.apply_buff(_b("virulent"), 2, ctx.now)
	foe.apply_buff(_b("poison"), 4, ctx.now)
	H._advance_to(ctx, 1.05)
	t.eq(S._hp(ctx, 1), 100 - roundi(4 * (1.0 + 2 * m_vir / 100.0)), "剧毒两层：中毒跳伤 × (1 + 2M)")
	ctx = _run([])
	ctx.sides[1].apply_buff(_b("virulent"), 2, ctx.now)
	_hit(DamageTypes.FIRE, 10.0).apply(_rc(ctx))
	t.eq(S._hp(ctx, 1), 90, "火伤不放大")
	t.check(_reactions(ctx).is_empty(), "剧毒不是印，火打上去不反应")

	# 激荡：90% 暴击的武器 + 15 层 → 10 层暴击率 + 5 层暴击伤害
	var w := H._compiled(1, "w", {"damage": 10, "crit_chance": 0.9}, [])
	w.tags = [&"weapon"] as Array[StringName]
	ctx = H._battle(H._spec(100.0, [w]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	ctx.sides[1].apply_buff(_b("bleed"), 15, ctx.now)
	_apply("numb", 15).apply(_rc(ctx))
	t.eq(_reactions(ctx), [&"lightning_bleed"] as Array[StringName], "引发激荡")
	t.eq([_axis(ctx, 0, StatAxes.CRIT_CHANCE), _axis(ctx, 0, StatAxes.CRIT_DAMAGE)], [10, 5], "暴击率加到满（十层），溢出五层转暴击伤害")
	ctx = _react("bleed", 1, "numb", 1)
	t.eq([_axis(ctx, 0, StatAxes.CRIT_CHANCE), _axis(ctx, 0, StatAxes.CRIT_DAMAGE)], [1, 0], "N = 1：一层暴击率")
	ctx = _react("bleed", 3, "numb", 3)
	t.eq(_axis(ctx, 0, StatAxes.CRIT_CHANCE), 3, "N = 3：三层暴击率")

	# 菌血
	ctx = _run([_hit(DamageTypes.PHYSICAL, 20.0)])
	ctx.sides[1].apply_buff(_b("poison"), 1, ctx.now)
	_apply("bleed", 1).apply(_rc(ctx))
	t.eq(_reactions(ctx), [&"poison_bleed"] as Array[StringName], "引发菌血")
	t.eq([ctx.sides[1].stacks_of(&"fungal_blood"), ctx.sides[1].stacks_of(&"bleed")], [1, 0], "N = 1：一层菌血，新来的流血不叠")
	_heal_opp(10.0).apply(_rc(ctx))
	t.eq(S._hp(ctx, 1), 85, "回 10 只到手 5")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 5, "按到手的 5 点叠 5 层中毒（待定 补 4.4 A）")
	H._advance_to(ctx, 1.05)
	t.eq(ctx.sides[1].stacks_of(&"fungal_blood"), 0, "一秒后菌血消失")
	ctx = _react("poison", 3, "bleed", 3)
	var fb := ctx.sides[1].find_buff(&"fungal_blood")
	t.check(fb != null and fb.stacks == 3 and fb.seconds_left == 3, "N = 3：三层菌血、持续三秒")


static func run_rules(t: TestCase) -> void:
	t.begin("175 补充一 / 三 · 伪代码：取层数最多的异色印（并列按火冰雷毒血）、同色的不算；N = min；两边各扣 N、新印余量叠上不再反应；反应不连锁")
	# 三色同在（直接挂上去，不经反应）：来雷 → 取层数最多的寒（5）→ 超导，灼与流血不动
	var ctx := _run([])
	var foe := ctx.sides[1]
	foe.apply_buff(_b("scorch"), 2, ctx.now)
	foe.apply_buff(_b("chill"), 5, ctx.now)
	foe.apply_buff(_b("bleed"), 3, ctx.now)
	var rc := RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_apply("numb").apply(rc)
	t.eq(_reactions(ctx), [&"ice_lightning"] as Array[StringName], "取层数最多的寒 → 超导")
	t.eq([foe.stacks_of(&"chill"), foe.stacks_of(&"scorch"), foe.stacks_of(&"bleed"), foe.stacks_of(&"numb")], [4, 2, 3, 0], "寒扣 N = 1 剩四、灼和流血不动、麻扣光")
	# 并列：灼 3、流血 3，来毒 → 按顺序取火 → 爆燃 N = 3
	ctx = _run([])
	foe = ctx.sides[1]
	foe.apply_buff(_b("scorch"), 3, ctx.now)
	foe.apply_buff(_b("bleed"), 3, ctx.now)
	rc = RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_apply("poison").apply(rc)
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "并列取火（火冰雷毒血的顺序）")
	t.eq(S._hp(ctx, 1), 97, "N = min(3, 1) = 1：1 × 3 = 3")
	t.eq(foe.stacks_of(&"bleed"), 3, "流血不动")
	# 同色不算：灼 3 + 中毒 1，来火 → 异色只有中毒 → 爆燃 N = 1；原来的灼留着、再加反应盖的一层
	ctx = _run([])
	foe = ctx.sides[1]
	foe.apply_buff(_b("scorch"), 3, ctx.now)
	foe.apply_buff(_b("poison"), 1, ctx.now)
	rc = RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_apply("scorch").apply(rc)
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "同色的灼不算，和中毒反应")
	t.eq(foe.stacks_of(&"scorch"), 3, "灼伤 3 留着（N = 1 的爆燃不重叠灼伤）")
	# 电解（补 4 A）：先麻后毒 → N = min(1, 2) = 1 层剧毒，中毒余一层叠上
	ctx = _run([_apply("numb"), _apply("poison", 2)])
	t.eq([ctx.sides[1].stacks_of(&"virulent"), ctx.sides[1].stacks_of(&"poison"), ctx.sides[1].stacks_of(&"numb")], [1, 1, 0], "先麻后毒：一层剧毒、中毒余一层、麻扣光")
	# 补 3.3：寒 1、麻 3，来五层灼 → 和麻反应（过载）N = 3，灼余两层叠上，寒原地不动，不再和灼炸
	ctx = _run([])
	foe = ctx.sides[1]
	foe.apply_buff(_b("chill"), 1, ctx.now)
	foe.apply_buff(_b("numb"), 3, ctx.now)
	rc = RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_apply("scorch", 5).apply(rc)
	t.eq(_reactions(ctx), [&"fire_lightning"] as Array[StringName], "只结算一次：过载")
	t.eq([foe.stacks_of(&"numb"), foe.stacks_of(&"scorch"), foe.stacks_of(&"chill")], [0, 2, 1], "麻扣光、灼余两层、寒不动")
	# 反应不连锁：爆燃里的火伤与灼都在反应结算内
	ctx = _run([_apply("poison", 2), _apply("bleed")])
	t.eq(_reactions(ctx), [&"poison_bleed"] as Array[StringName], "毒 + 血 = 菌血")
	ctx = _run([_apply("poison", 1), _apply("scorch"), _apply("scorch")])
	t.eq(_reactions(ctx).size(), 1, "爆燃之后对手只剩灼，再施加一次灼伤只是加深")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 1, "N = 1 的爆燃不叠灼伤，再施加一层")
	# 出生晚于事件：施加 buff 的那一刻已经排在队里的出手事件，它的规则听不见
	var rt := RuleRuntime.new()
	rt.born = 5
	var e := BattleEvent.make(BattleEvent.ITEM_FIRED, 0, 0, {})
	e.seq = 4
	t.check(rt.born > e.seq, "规则出生（5）晚于事件（4）：派发跳过")
	t.eq(BattleEvent.make(BattleEvent.ITEM_FIRED, 0, 0, {}).seq, BattleEvent.NO_SEQ, "手搓的事件谁都听得见")


## 补充二：一份试验用的火冰反应 —— 物理伤 N × 2、流血 N 层（封顶 5）、偏斜持续 N 秒（封顶 10）；补充四：灼伤 N / 2 层
static func _scaled_def(report: ImportReport) -> ReactionDef:
	return ContentImporter.import_reaction({"id": "fire_ice", "display_name": "试", "elements": ["fire", "ice"], "effects": [
		{"type": "deal_damage", "damage_type": "physical", "amount": {"per_stack": 2.0}, "damage_stat": ""},
		{"type": "apply_status", "buff": "bleed", "stacks": {"stacks": "n", "max": 5.0}},
		{"type": "apply_status", "buff": "deflect", "duration_sec": {"seconds": "n", "max": 10.0}},
		{"type": "apply_status", "buff": "poison", "stacks": {"stacks": "n/2"}},
	]}, ContentLibrary.context(), report)


static func run_scaling(t: TestCase) -> void:
	t.begin("175 补充二 / 四 · 反应里的数字随 N 变：per_stack（N × X）、stacks: n（= N，可封顶）、stacks: n/2（向下取整，0 不跑）、seconds: n + max（这次施加的状态持续 N 秒）；导入器拦错写法；导出写回内联")
	var r := ImportReport.new()
	var def := _scaled_def(r)
	t.check(r.ok(), "四种写法导得进（%s）" % r.to_text())
	t.eq(def.scaling.size(), 4, "记了四行")
	var dumped := ContentExporter.dump(def)
	t.eq(dumped["effects"][0]["amount"], {"per_stack": 2.0}, "导出写回内联：per_stack")
	t.eq(dumped["effects"][1]["stacks"], {"stacks": "n", "max": 5.0}, "导出写回内联：stacks n")
	t.eq(dumped["effects"][2]["duration_sec"], {"seconds": "n", "max": 10.0}, "导出写回内联：seconds n")
	t.eq(dumped["effects"][3]["stacks"], {"stacks": "n/2"}, "导出写回内联：stacks n/2")
	t.check(not dumped.has("scaling"), "json 里不出现 scaling")
	var again := ImportReport.new()
	var def2 := ContentImporter.import_reaction(JSON.parse_string(ContentExporter.to_json(dumped)), ContentLibrary.context(), again)
	t.check(again.ok() and def2.scaling == def.scaling, "往返一致")
	t.eq((def.effects[0] as DealDamage).amount, 1.0, "原效果里留的是占位数，不被结算改动")
	for n in [1, 5, 10]:
		ReactionResolver.reset()
		ReactionResolver.all()     # 先读进数据，再用试验的那份盖掉火冰
		ReactionResolver.register(def)
		var ctx := _run([])
		var foe := ctx.sides[1]
		foe.apply_buff(_b("chill"), n, ctx.now)
		var rc := RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
		_apply("scorch", n).apply(rc)
		t.eq(_reactions(ctx), [&"fire_ice"] as Array[StringName], "N = %d：引发" % n)
		t.eq(S._hp(ctx, 1), 100 - 2 * n, "N = %d：物理 N × 2" % n)
		t.eq(foe.stacks_of(&"bleed"), mini(n, 5), "N = %d：流血 N 层，封顶 5" % n)
		var sb := foe.find_buff(&"deflect")
		t.check(sb != null and sb.expires_at == ctx.now + StatMath.from_float(float(mini(n, 10))), "N = %d：偏斜持续 %d 秒" % [n, mini(n, 10)])
		t.eq(foe.stacks_of(&"poison"), n / 2, "N = %d：中毒 N / 2 层（为 0 不叠）" % n)
	ReactionResolver.reset()
	t.eq(_b("deflect").duration_sec, 4.0, "内容库里的偏斜时长没被改")
	var cases := [
		[{"type": "apply_status", "buff": "deflect", "duration_sec": {"seconds": "n"}}, "max"],
		[{"type": "apply_status", "buff": "bleed", "duration_sec": {"seconds": "n", "max": 3.0}}, "永续"],
		[{"type": "deal_damage", "damage_stat": "", "nope": {"per_stack": 1.0}}, "nope"],
		[{"type": "deal_damage", "damage_stat": "", "amount": {"per_stack": "x"}}, "per_stack"],
	]
	for c in cases:
		var rr := ImportReport.new()
		ContentImporter.import_reaction({"id": "fire_ice", "display_name": "x", "elements": ["fire", "ice"], "effects": [c[0]]}, ContentLibrary.context(), rr)
		t.check(not rr.ok() and rr.to_text().contains(String(c[1])), "拦下：%s（%s）" % [c[1], rr.to_text()])


static func run_import(t: TestCase) -> void:
	t.begin("175 · 导入器：反应得两种不同的元素、id 按元素顺序拼、得有效果")
	var ok := {"id": "fire_poison", "display_name": "爆燃", "elements": ["fire", "poison"],
		"effects": [{"type": "apply_status", "buff": "scorch"}]}
	var r := ImportReport.new()
	ContentImporter.import_reaction(ok, ContentLibrary.context(), r)
	t.check(r.ok(), "正常的能导（%s）" % r.to_text())
	var cases := [
		[{"id": "fire_fire", "display_name": "x", "elements": ["fire", "fire"], "effects": ok["effects"]}, "得不同"],
		[{"id": "fire_wind", "display_name": "x", "elements": ["fire", "wind"], "effects": ok["effects"]}, "不认识的元素"],
		[{"id": "poison_fire", "display_name": "x", "elements": ["poison", "fire"], "effects": ok["effects"]}, "fire_poison"],
		[{"id": "fire_poison", "display_name": "x", "elements": ["fire", "poison"], "effects": []}, "得有效果"],
	]
	for c in cases:
		var rr := ImportReport.new()
		ContentImporter.import_reaction(c[0], ContentLibrary.context(), rr)
		t.check(not rr.ok() and rr.to_text().contains(String(c[1])), "拦下：%s（%s）" % [c[1], rr.to_text()])


static func run_heal(t: TestCase) -> void:
	t.begin("175 · 治疗入口：燃血期间每秒回血也停（补充四：N = 5 的燃血持续 5 秒，每秒 5 点火伤）")
	var regen := H._compiled(2, "b", {"regen_hp": 2}, [])
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [S._opener([_hit(DamageTypes.PHYSICAL, 30.0), _apply("bleed", 5), _apply("scorch", 5)])])]),
		H._spec(100.0, [regen]))
	S._start(ctx)
	t.eq(S._hp(ctx, 1), 70, "开场 30 点")
	H._advance_to(ctx, 4.0)
	ctx.sides[1].settle_regen(ctx.now)
	t.eq(S._hp(ctx, 1), 50, "燃血期间不回血：四秒只掉了 4 × 5")
	H._advance_to(ctx, 7.0)
	ctx.sides[1].settle_regen(ctx.now)
	t.eq(S._hp(ctx, 1), 49, "第五秒再 5 点后燃血消失，只补之后那 2 秒（不把燃血那段补回来）")

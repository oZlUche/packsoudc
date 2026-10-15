## 175 第一批：元素印与反应表 —— 命中盖印、施加中毒 / 流血即盖印、物理不盖、到期消失；十对反应各一例；
## 同元素加深不反应；凝毒期间清不掉中毒、寒印到期恢复；菌血治疗减半转毒伤；燃血治疗为零；反应不连锁；导入器的校验
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


static func _cleanse_poison() -> RemoveStatus:
	var e := RemoveStatus.new()
	e.target = CombatEffect.Target.OPPONENT
	e.buff_id = &"poison"
	e.stacks = 0
	return e


## 开战那一刻依次跑 [param effects]（打对手）的一场；[param side1_stats] 是对手那件的属性
static func _run(effects: Array, side1_stats: Dictionary = {}) -> BattleContext:
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [S._opener(effects)])]),
		H._spec(100.0, [H._compiled(2, "b", side1_stats, [])]))
	S._start(ctx)
	return ctx


static func _reactions(ctx: BattleContext) -> Array[StringName]:
	return ReactionResolver.reactions_in(ctx.log)


static func run_marks(t: TestCase) -> void:
	t.begin("175 · 印：火 / 冰 / 雷命中盖灼 / 寒 / 麻，施加中毒 / 流血就是盖印，物理不盖，几秒后消失，同元素只加深")
	t.eq(DamageTypes.get_def(DamageTypes.FIRE).mark, &"scorch", "火焰盖灼")
	t.eq(DamageTypes.get_def(DamageTypes.ICE).mark, &"chill", "冰霜盖寒")
	t.eq(DamageTypes.get_def(DamageTypes.LIGHTNING).mark, &"numb", "闪电盖麻")
	t.eq(DamageTypes.get_def(DamageTypes.PHYSICAL).mark, &"", "物理不盖")
	t.eq(DamageTypes.get_def(DamageTypes.POISON).mark, &"", "中毒伤害不盖（毒印是状态本身，否则每跳一次多一层）")
	for id in ["scorch", "chill", "numb"]:
		var b := _b(id)
		t.not_null(b, "有印 %s" % id)
		if b != null:
			t.check(not b.is_stackable() and not b.is_permanent() and b.is_debuff, "%s 不可叠、会过期、是减益（085：可叠层永续，所以印是不可叠的）" % id)
	t.eq(_b("poison").element, &"poison", "中毒是毒印")
	t.eq(_b("virulent").element, &"poison", "剧毒也是毒印")
	t.eq(_b("bleed").element, &"bleed", "流血是血印")

	var ctx := _run([_hit(DamageTypes.FIRE, 1.0)])
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 1, "火伤之后身上有灼")
	t.check(_reactions(ctx).is_empty(), "一种元素不反应")
	H._advance_to(ctx, 4.1)
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 0, "四秒后灼消失")

	ctx = _run([_hit(DamageTypes.PHYSICAL, 1.0)])
	t.check(ctx.sides[1].buffs.is_empty(), "物理不盖印")

	ctx = _run([_hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.FIRE, 1.0)])
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 1, "同元素再碰：灼还是一层（刷新时长）")
	t.check(_reactions(ctx).is_empty(), "同元素不反应")
	ctx = _run([_apply("poison", 2), _apply("poison", 3)])
	t.eq(ctx.sides[1].stacks_of(&"poison"), 5, "中毒再碰就是加层")
	t.check(_reactions(ctx).is_empty(), "毒碰毒不反应")


static func run_table(t: TestCase) -> void:
	t.begin("175 · 反应表：十对、名字定稿、id 按元素顺序拼")
	var names := {"fire_poison": "爆燃", "fire_ice": "淬裂", "fire_lightning": "过载", "fire_bleed": "燃血", "ice_lightning": "超导",
		"ice_poison": "凝毒", "ice_bleed": "冻疮", "lightning_poison": "电解", "lightning_bleed": "激荡", "poison_bleed": "菌血"}
	var all := ReactionResolver.all()
	t.eq(all.size(), 10, "十对反应")
	for def in all:
		t.eq(def.display_name, String(names.get(String(def.id), "?")), "%s 的名字" % def.id)
	t.eq(String(all[0].id), "fire_ice", "按元素顺序排：火冰在前")
	t.eq(ReactionResolver.find(&"poison", &"fire").display_name, "爆燃", "不分先后")
	t.eq(ReactionResolver.pair_key(&"bleed", &"ice"), "ice_bleed", "键按元素顺序")
	t.eq(ReactionResolver.pair_key(&"fire", &"fire"), "", "同元素没有键")


static func run_fire(t: TestCase) -> void:
	t.begin("175 · 火系反应：爆燃按层数火伤再盖灼、淬裂护甲清零、过载下一下翻倍、燃血治疗无效")
	# 爆燃：三层中毒 + 一下火 1 → 3 × 3 = 9 火伤，中毒清空，再盖灼
	var ctx := _run([_apply("poison", 3), _hit(DamageTypes.FIRE, 1.0)])
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "引发爆燃")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "中毒被吃掉")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 1, "再盖上灼")
	t.eq(S._hp(ctx, 1), 90, "火 1 + 爆燃 3 层 × 3 = 9")
	# 反过来：先有灼、再施加中毒 —— 一样是爆燃，施加的那几层也算
	ctx = _run([_hit(DamageTypes.FIRE, 1.0), _apply("poison", 2)])
	t.eq(_reactions(ctx), [&"fire_poison"] as Array[StringName], "先灼后毒也是爆燃")
	t.eq(S._hp(ctx, 1), 93, "火 1 + 2 层 × 3 = 6")

	# 淬裂：先寒、再火 → 护甲清零 + 8 点
	ctx = _run([_hit(DamageTypes.ICE, 1.0), _hit(DamageTypes.FIRE, 5.0)], {"max_armor": 30})
	t.eq(_reactions(ctx), [&"fire_ice"] as Array[StringName], "引发淬裂")
	t.eq(ctx.sides[1].resources.current(BattleStats.RES_ARMOR), 0, "护甲清零")
	t.eq(S._hp(ctx, 1), 92, "前两下被护甲吃掉，淬裂的 8 点见血")
	t.eq(ctx.sides[1].stacks_of(&"chill") + ctx.sides[1].stacks_of(&"scorch"), 0, "两印都消耗（火这一下的灼不盖）")

	# 过载：火 → 雷 → 自己下一下翻倍，用掉就没
	ctx = _run([_hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.LIGHTNING, 1.0), _hit(DamageTypes.PHYSICAL, 10.0), _hit(DamageTypes.PHYSICAL, 10.0)])
	t.eq(_reactions(ctx), [&"fire_lightning"] as Array[StringName], "引发过载")
	t.eq(S._hp(ctx, 1), 100 - 1 - 1 - 20 - 10, "过载后第一下 20，第二下照常 10")
	t.eq(ctx.sides[0].stacks_of(&"overload"), 0, "过载用掉了")

	# 燃血：流血 → 火 → 治疗无效 + 6 点火伤；反应里的这下火伤不盖灼（反应不连锁）
	ctx = _run([_apply("bleed", 2), _hit(DamageTypes.FIRE, 1.0), _heal_opp(20.0)])
	t.eq(_reactions(ctx), [&"fire_bleed"] as Array[StringName], "引发燃血")
	t.eq(ctx.sides[1].stacks_of(&"bleed"), 0, "流血被吃掉")
	t.eq(ctx.sides[1].stacks_of(&"scorched_blood"), 1, "对手燃血")
	t.eq(S._hp(ctx, 1), 93, "火 1 + 燃血 6；之后的治疗 20 为零")
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 0, "反应里的火伤不盖灼（本次结算内不盖新印）")
	H._advance_to(ctx, 5.1)
	t.eq(ctx.sides[1].stacks_of(&"scorched_blood"), 0, "几秒后燃血消失")


static func run_ice(t: TestCase) -> void:
	t.begin("175 · 冰系反应：超导易伤、凝毒锁毒到寒印消失、冻疮减速")
	# 超导：寒 → 雷 → 受到的最终伤害 +20%
	var ctx := _run([_hit(DamageTypes.ICE, 1.0), _hit(DamageTypes.LIGHTNING, 1.0), _hit(DamageTypes.PHYSICAL, 10.0)])
	t.eq(_reactions(ctx), [&"ice_lightning"] as Array[StringName], "引发超导")
	t.eq(S._hp(ctx, 1), 100 - 1 - 1 - 12, "超导后 10 打成 12")

	# 凝毒：中毒 → 冰 → 中毒清不掉；寒印留着（这一对不吃印）；寒印到期后能清
	ctx = _run([_apply("poison", 2), _hit(DamageTypes.ICE, 1.0), _cleanse_poison()])
	t.eq(_reactions(ctx), [&"ice_poison"] as Array[StringName], "引发凝毒")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 2, "解毒对中毒无效")
	t.eq(ctx.sides[1].stacks_of(&"chill"), 1, "寒印留着（凝毒不吃印）")
	t.eq(ctx.sides[1].stacks_of(&"congeal"), 1, "挂着凝毒")
	t.check(ctx.sides[1].is_locked(&"poison"), "中毒被锁住")
	H._advance_to(ctx, 4.1)
	t.eq(ctx.sides[1].stacks_of(&"chill"), 0, "寒印到期")
	t.eq(ctx.sides[1].stacks_of(&"congeal"), 0, "凝毒跟着寒印一起掉")
	t.check(not ctx.sides[1].is_locked(&"poison"), "锁解开")
	t.check(ctx.sides[1].stacks_of(&"poison") >= 2, "中毒一直没衰减")
	var rc := RuleContext.create(ctx, ctx.sides[0], RuleRuntime.create(null, 1, null, 0))
	_cleanse_poison().apply(rc)
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "寒印消失后能清掉了")

	# 冻疮：流血 → 冰 → 出手间隔拉长（减速十层）
	ctx = _run([_apply("bleed"), _hit(DamageTypes.ICE, 1.0)])
	t.eq(_reactions(ctx), [&"ice_bleed"] as Array[StringName], "引发冻疮")
	t.eq(ctx.sides[1].axis_total(StatAxes.ATTACK_SPEED), -10, "对手减速十层")


static func run_lightning(t: TestCase) -> void:
	t.begin("175 · 雷系与毒血：电解升剧毒、激荡下一次攻击必暴击、菌血治疗减半转毒伤")
	# 电解：三层中毒 → 雷 → 三层剧毒，麻不留
	var ctx := _run([_apply("poison", 3), _hit(DamageTypes.LIGHTNING, 1.0)])
	t.eq(_reactions(ctx), [&"lightning_poison"] as Array[StringName], "引发电解")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "中毒没了")
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 3, "换成三层剧毒")
	t.eq(ctx.sides[1].stacks_of(&"numb"), 0, "麻被吃掉")

	# 激荡：流血 → 雷 → 下一次武器出手必暴击（这一下自己排在队里的出手事件不算「下一次」）
	var weapon := H._rule(OnSchedule.new(), H._cooldown(1.0), [DealDamage.new()])
	var w := H._compiled(1, "w", {"damage": 10}, [S._opener([_apply("bleed"), _hit(DamageTypes.LIGHTNING, 1.0)]), weapon])
	w.tags = [&"weapon"] as Array[StringName]
	ctx = H._battle(H._spec(100.0, [w]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	t.eq(_reactions(ctx), [&"lightning_bleed"] as Array[StringName], "引发激荡")
	t.eq(ctx.sides[0].stacks_of(&"surge"), 1, "自己挂着激荡")
	H._advance_to(ctx, 1.05)
	var crits := 0
	for e in ctx.log:
		if e.name == BattleEvent.DAMAGE and e.get_int(&"amount") > 0 and e.get_bool(&"crit"):
			crits += 1
	t.eq(crits, 1, "下一次攻击暴击了")
	t.eq(ctx.sides[0].stacks_of(&"surge"), 0, "激荡用掉了")
	H._advance_to(ctx, 2.05)
	crits = 0
	for e in ctx.log:
		if e.name == BattleEvent.DAMAGE and e.get_int(&"amount") > 0 and e.get_bool(&"crit"):
			crits += 1
	t.eq(crits, 1, "再下一次不再必暴（默认暴击率 0）")

	# 菌血：先打掉 20，中毒 → 流血 → 治疗 10 只回 5，另 5 变成中毒伤害
	ctx = _run([_hit(DamageTypes.PHYSICAL, 20.0), _apply("poison"), _apply("bleed"), _heal_opp(10.0)])
	t.eq(_reactions(ctx), [&"poison_bleed"] as Array[StringName], "引发菌血")
	t.eq(ctx.sides[1].stacks_of(&"poison") + ctx.sides[1].stacks_of(&"bleed"), 0, "两印都消耗")
	t.eq(S._hp(ctx, 1), 80, "80 + 5 − 5 = 80")
	var poison_hit := 0
	for e in ctx.log:
		if e.name == BattleEvent.DAMAGE and e.get_name(&"type") == DamageTypes.POISON:
			poison_hit += StatMath.to_int(e.get_int(&"amount"))
	t.eq(poison_hit, 5, "截走的 5 点变成中毒伤害")


static func run_rules(t: TestCase) -> void:
	t.begin("175 · 反应不连锁、命中带来的印没吃掉就补盖、出生晚于事件的规则不听它")
	# 凝毒：冰命中带来的寒没被吃掉 → 补盖上（锁靠它）
	var ctx := _run([_apply("poison"), _hit(DamageTypes.ICE, 1.0)])
	t.eq(ctx.sides[1].stacks_of(&"chill"), 1, "寒补盖上了")
	# 电解只吃雷：施加的中毒（来者）留着去升阶
	ctx = _run([_hit(DamageTypes.LIGHTNING, 1.0), _apply("poison", 2)])
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 2, "先麻后毒：电解把这两层中毒升阶")
	# 爆燃里的火伤与灼都在反应结算内：不再引发别的反应（对手身上的流血还在）
	ctx = _run([_apply("poison", 2), _apply("bleed")])
	t.eq(_reactions(ctx), [&"poison_bleed"] as Array[StringName], "毒 + 血 = 菌血")
	ctx = _run([_apply("poison", 1), _hit(DamageTypes.FIRE, 1.0), _hit(DamageTypes.FIRE, 1.0)])
	t.eq(_reactions(ctx).size(), 1, "爆燃之后对手只剩灼，再一下火只是加深")
	t.eq(ReactionResolver.reactions_in(ctx.log).size(), 1, "一场只记一次爆燃")
	# 出生晚于事件：施加 buff 的那一刻已经排在队里的出手事件，它的规则听不见
	var rt := RuleRuntime.new()
	rt.born = 5
	var e := BattleEvent.make(BattleEvent.ITEM_FIRED, 0, 0, {})
	e.seq = 4
	t.check(rt.born > e.seq, "规则出生（5）晚于事件（4）：派发跳过")
	t.eq(BattleEvent.make(BattleEvent.ITEM_FIRED, 0, 0, {}).seq, BattleEvent.NO_SEQ, "手搓的事件谁都听得见")


static func run_import(t: TestCase) -> void:
	t.begin("175 · 导入器：反应得两种不同的元素、id 按元素顺序拼、吃印只能写 both / none / 其中一种、得有效果")
	var ok := {"id": "fire_poison", "display_name": "爆燃", "elements": ["fire", "poison"],
		"effects": [{"type": "apply_status", "buff": "scorch"}]}
	var r := ImportReport.new()
	ContentImporter.import_reaction(ok, ContentLibrary.context(), r)
	t.check(r.ok(), "正常的能导（%s）" % r.to_text())
	var cases := [
		[{"id": "fire_fire", "display_name": "x", "elements": ["fire", "fire"], "effects": ok["effects"]}, "得不同"],
		[{"id": "fire_wind", "display_name": "x", "elements": ["fire", "wind"], "effects": ok["effects"]}, "不认识的元素"],
		[{"id": "poison_fire", "display_name": "x", "elements": ["poison", "fire"], "effects": ok["effects"]}, "fire_poison"],
		[{"id": "fire_poison", "display_name": "x", "elements": ["fire", "poison"], "consume": "ice", "effects": ok["effects"]}, "吃印"],
		[{"id": "fire_poison", "display_name": "x", "elements": ["fire", "poison"], "effects": []}, "得有效果"],
	]
	for c in cases:
		var rr := ImportReport.new()
		ContentImporter.import_reaction(c[0], ContentLibrary.context(), rr)
		t.check(not rr.ok() and rr.to_text().contains(String(c[1])), "拦下：%s（%s）" % [c[1], rr.to_text()])


static func run_heal(t: TestCase) -> void:
	t.begin("175 · 治疗入口：燃血期间每秒回血也停、反转成的治疗也被截")
	var regen := H._compiled(2, "b", {"regen_hp": 2}, [])
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [S._opener([_hit(DamageTypes.PHYSICAL, 30.0), _apply("bleed"), _hit(DamageTypes.FIRE, 1.0)])])]),
		H._spec(100.0, [regen]))
	S._start(ctx)
	var hp0 := S._hp(ctx, 1)
	H._advance_to(ctx, 4.0)
	ctx.sides[1].settle_regen(ctx.now)
	t.eq(S._hp(ctx, 1), hp0, "燃血期间不回血")
	H._advance_to(ctx, 7.0)
	ctx.sides[1].settle_regen(ctx.now)
	t.eq(S._hp(ctx, 1), hp0 + 4, "燃血 5 秒到期后只补到期之后那 2 秒（不把燃血那段补回来）")

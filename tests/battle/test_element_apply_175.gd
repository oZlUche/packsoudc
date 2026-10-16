## 175 补充五（作者定）：【造成伤害】和【施加元素】是两件事 —— 伤害不再顺手盖印，印只从施加来；
## 道具的 `applies` 简写（造成伤害后施加，编译走 108 的 _attach、来源 `applies`、没打中不施加）；
## 晶石两条供给规则；法杖轮读每格施加对应元素；铸炉元素行按阶加层；日神附火每下施加一层灼伤（补 5.1 A）；
## 道具带哪种元素只看施加；流血 family = physical、pure 只在流血上；悬浮窗伤害与施加分两句
extends RefCounted

## 176：带整个库的导入上下文（不写 class_name，按路径取）
const AuthoringContext := preload("res://core/authoring/authoring_context.gd")

const H := preload("res://tests/battle/test_effect_system.gd")
const S := preload("res://tests/battle/test_status_synergy.gd")
const Staff := preload("res://tests/run/test_crystal_148.gd")
const Cycle := preload("res://tests/battle/test_staff_cycle_175.gd")


static func _b(id: String) -> BuffDef:
	return ContentLibrary.buffs().get(StringName(id), null)


static func _ea(id: String, stacks: int = 1) -> ElementApply:
	var a := ElementApply.new()
	a.buff = _b(id)
	a.stacks = stacks
	return a


## 一件编好的道具：[param rules] 是它自己的规则，再挂上 applies 简写那一条（和编译器一样走 _attach）
static func _with_applies(uid: int, rules: Array, applies: Array) -> CompiledItem:
	var item := H._compiled(uid, "x", {}, rules)
	BattleCompiler._attach(item, ElementApply.rule_of(applies), ElementApply.ORIGIN)
	return item


static func run_rule_shape(t: TestCase) -> void:
	t.begin("175 补充五 · applies 简写：编译成 on_damage DEALT 只认自己、只认打中 → 给对手施加 buff × stacks；经 _attach 挂上、来源 applies")
	var r := ElementApply.rule_of([_ea("scorch", 2)])
	t.not_null(r, "拼得出规则")
	if r == null:
		return
	var trig := r.trigger as OnDamage
	t.check(trig != null and trig.direction == DamageTrigger.Direction.DEALT and trig.own_only and trig.landed_only, "on_damage DEALT own_only landed_only")
	t.check(r.cadence is Always, "每下都施加")
	t.eq(r.effects.size(), 1, "一项一个施加")
	var app := r.effects[0] as ApplyStatus
	t.check(app != null and app.buff.id == &"scorch" and app.stacks == 2 and app.target == CombatEffect.Target.OPPONENT, "给对手两层灼伤")
	t.eq(ElementApply.rule_of([]), null, "空的不拼")

	# 导入：json 写 applies，编译挂上，来源记 applies
	var data := {"id": "probe_applies", "display_name": "试", "shape": ["1"], "tags": ["weapon"],
		"combat": {"base_stats": {"damage": 3}, "rules": [{"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0},
			"effects": [{"type": "deal_damage", "damage_type": "fire"}]}]},
		"applies": [{"buff": "scorch", "stacks": 1}]}
	var rep := ImportReport.new()
	var def := ContentImporter.import_item(data, AuthoringContext.context(), rep)
	t.check(rep.ok(), "applies 能导（%s）" % rep.to_text())
	if def == null:
		return
	t.eq(def.applies.size(), 1, "导进一项")
	t.check(def.applies[0].buff != null and def.applies[0].buff.id == &"scorch" and def.applies[0].stacks == 1, "灼伤一层")
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(3, 3), 1, false)
	var inst := ItemInstance.create(def)
	g.place(inst, Vector2i.ZERO, 0)
	var spec := BattleCompiler.compile_board(g)
	var item := spec.item_of(inst.uid)
	t.eq(item.rules.size(), 2, "自己的一条 + 挂上的一条")
	t.eq(item.attached.size(), 1, "记了一条附加")
	if item.attached.size() == 1:
		t.eq(StringName(String(item.attached[0]["origin"])), ElementApply.ORIGIN, "来源 = applies")
		t.check(item.rules[int(item.attached[0]["rule_index"])].trigger is OnDamage, "挂上的是 on_damage 那条")
	t.eq(ReactionResolver.elements_of_item(item), [&"fire"] as Array[StringName], "它带火（因为施加灼伤）")
	var text := Glossary.strip_bbcode(ItemTooltip.describe(inst, g))
	t.check(text.contains("点火焰伤害，并施加 1 层灼伤") and not text.contains("打中后"), "补 5.4：一句两段「造成 X 点火焰伤害，并施加 1 层灼伤」（%s）" % text)
	t.check(not text.contains("附加：") and not text.contains("火焰攻击"), "不写成「附加 ← …」，也不合成「火焰攻击」")
	var body := String(ItemTooltip.describe_full(inst, g)["body"])
	t.check(body.contains("[color=@fire]火焰伤害[/color]"), "「火焰伤害」整段用伤害类型色、不是关键词（%s）" % body)
	t.check(body.contains("[url=term:scorch][color=@scorch][u]灼伤[/u][/color][/url]"), "「灼伤」是关键词、用状态色（%s）" % body)
	var lone := ItemDef.new()
	lone.id = &"probe_applies_only"
	lone.applies = [_ea("chill", 2)] as Array[ElementApply]
	var item2 := H._compiled(9, "y", {}, [])
	BattleCompiler._attach(item2, ElementApply.rule_of(lone.applies), ElementApply.ORIGIN)
	t.eq(ItemTooltip.applies_line(item2.rules[0]), "打中后施加 [b]2[/b] 层寒冷", "没有武器句：单写「打中后施加 2 层寒冷」")


static func run_elements_of_item(t: TestCase) -> void:
	t.begin("175 补充五 · 道具带哪种元素只看施加：只打火伤的为空，只施加灼伤的 = 火，转成的状态也算")
	var fire_only := H._compiled(1, "f", {}, [H._rule(OnBattleStart.new(), Always.new(), [S._flat(3.0, DamageTypes.FIRE)])])
	t.eq(ReactionResolver.elements_of_item(fire_only), [] as Array[StringName], "只打火伤：不带元素")
	var conv := ConvertDamageType.new()
	conv.to = DamageTypes.LIGHTNING
	t.eq(ReactionResolver.elements_of_rules([H._rule(OnBattleStart.new(), Always.new(), [conv])]), [] as Array[StringName], "把伤害改成闪电：也不带元素")
	var scorch_only := H._compiled(2, "s", {}, [H._rule(OnBattleStart.new(), Always.new(), [S._apply(_b("scorch"))])])
	t.eq(ReactionResolver.elements_of_item(scorch_only), [&"fire"] as Array[StringName], "只施加灼伤：火")
	var cs := ConvertStatus.new()
	cs.to = _b("numb")
	t.eq(ReactionResolver.elements_of_rules([H._rule(OnBattleStart.new(), Always.new(), [cs])]), [&"lightning"] as Array[StringName], "转成麻痹：雷")
	var ench := H._compiled(3, "e", {}, [EnchantWeaponsPerk.new().rule()])
	t.eq(ReactionResolver.elements_of_item(ench), [&"fire"] as Array[StringName], "日神附火：带火（补 5.1 A，因为施加灼伤）")


static func run_in_battle(t: TestCase) -> void:
	t.begin("175 补充五 · 打起来：伤害不盖印；applies 打中一下施加一层；被取消的一下不施加；别的道具打中不算")
	# 只打火伤
	var ctx := H._battle(H._spec(100.0, [H._compiled(1, "a", {}, [S._opener([S._flat(3.0, DamageTypes.FIRE)])])]),
		H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"scorch")], [97, 0], "火伤 3：掉血、不盖灼伤")
	# applies：打中两下，两层（每下一层）
	var hits := S._opener([S._flat(3.0, DamageTypes.FIRE), S._flat(3.0, DamageTypes.PHYSICAL)])
	ctx = H._battle(H._spec(100.0, [_with_applies(1, [hits], [_ea("scorch")])]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 2, "打中两下（不管伤害类型）：两层灼伤")
	# 一次叠多层
	ctx = H._battle(H._spec(100.0, [_with_applies(1, [S._opener([S._flat(3.0)])], [_ea("chill", 3)])]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"chill"), 3, "stacks = 3：一下三层寒冷")
	# 被取消的一下不施加
	var tr := OnBeforeDamage.new()
	tr.direction = DamageTrigger.Direction.TAKEN
	var md := ModifyDamage.new()
	md.cancel = true
	var wall := H._compiled(2, "wall", {}, [H._rule(tr, Always.new(), [md])])
	ctx = H._battle(H._spec(100.0, [_with_applies(1, [S._opener([S._flat(3.0)])], [_ea("scorch")])]), H._spec(100.0, [wall]))
	S._start(ctx)
	t.eq([S._hp(ctx, 1), ctx.sides[1].stacks_of(&"scorch")], [100, 0], "被整个取消：不掉血、不施加")
	# 别的道具打中不算（own_only）
	var other := H._compiled(3, "other", {}, [S._opener([S._flat(3.0)])])
	ctx = H._battle(H._spec(100.0, [_with_applies(1, [], [_ea("scorch")]), other]), H._spec(100.0, [H._compiled(2, "b", {}, [])]))
	S._start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 0, "同一边别的道具打中：不施加")


static func run_crystals(t: TestCase) -> void:
	t.begin("175 补充五 · 晶石两条供给规则：原来的换型 + 造成伤害后施加对应元素一层（火 → 灼伤、冰 → 寒冷、雷 → 麻痹）")
	var db := Cycle._db()
	for pair in [[&"fire_crystal", &"fire", &"scorch"], [&"ice_crystal", &"ice", &"chill"], [&"lightning_crystal", &"lightning", &"numb"]]:
		var def := db.get_def(pair[0])
		var rules := def.adjacency.feed_rules
		t.eq(rules.size(), 2, "%s：两条" % pair[0])
		if rules.size() != 2:
			continue
		t.eq(BattleCompiler.convert_to(rules[0]), pair[1], "%s 第一条：换成 %s" % [pair[0], pair[1]])
		var trig := rules[1].trigger as OnDamage
		t.check(trig != null and trig.direction == DamageTrigger.Direction.DEALT and trig.own_only and trig.landed_only, "%s 第二条：这件打中后" % pair[0])
		t.eq(BattleCompiler.applies_of(rules[1]), {"buff": pair[2], "stacks": 1}, "%s 第二条：施加一层 %s" % [pair[0], pair[2]])
		t.eq(BattleCompiler.applies_of(rules[0]), {}, "换型那条不算施加")


static func run_staff_cycle(t: TestCase) -> void:
	t.begin("175 补充五 · 法杖轮读：装载表每格带 applies，那一下按格里的晶石施加；木棍只打伤害；晶石的施加规则不常驻挂在法杖上")
	var db := Cycle._db()
	var b := Staff._staff_board(db, &"fire_crystal", &"ice_crystal")     # 左火、右冰
	var uid: int = b["staff"].uid
	var spec := Cycle._compile(b["board"], uid)
	var item := spec.item_of(uid)
	t.eq(item.loaded.size(), 2, "轮读表两颗")
	if item.loaded.size() == 2:
		t.eq(item.loaded[0]["applies"], {"buff": &"chill", "stacks": 1}, "第一颗（右冰）：施加寒冷")
		t.eq(item.loaded[1]["applies"], {"buff": &"scorch", "stacks": 1}, "第二颗（左火）：施加灼伤")
	for r in item.rules:
		t.check(BattleCompiler.applies_of(r).is_empty(), "法杖身上没有常驻的施加规则（否则每下都两种元素一起上）")
	t.eq(ReactionResolver.elements_of_item(item), [&"fire", &"ice"] as Array[StringName], "法杖带火、冰（来自装载表的施加）")

	# 打一下冰：对手一层寒冷，不带灼伤；再一下火：寒冷 × 灼伤 → 淬裂
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(4000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var res := BattleSim.run(spec, BattleCompiler.compile(null, foe_in), rng, 5.0)
	var applied: Array[String] = []
	for ev in res.log:
		var e := ev as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and applied.size() < 1:
			applied.append(String(e.payload.get("buff", "")))
	t.eq(applied, ["chill"] as Array[String], "第一下（冰）施加的是寒冷")
	t.check(ReactionResolver.reactions_in(res.log).has(&"fire_ice"), "冰 → 火：淬裂")

	var alone := Staff._staff_board(db, &"", &"")
	var a_spec := Cycle._compile(alone["board"], alone["staff"].uid)
	var a_res := BattleSim.run(a_spec, BattleCompiler.compile(null, foe_in), rng, 5.0)
	var any := false
	for ev in a_res.log:
		if (ev as BattleEvent).name == BattleEvent.STATUS_STACKED:
			any = true
	t.check(not any, "木棍：只打伤害、不施加")
	t.eq(ReactionResolver.elements_of_item(a_spec.item_of(alone["staff"].uid)), [] as Array[StringName], "木棍不带元素")

	var text := Glossary.strip_bbcode(ItemTooltip.describe(b["staff"], b["board"]))
	var ice_at := text.find("点冰霜伤害，并施加 1 层寒冷")
	t.check(ice_at >= 0 and text.find("点火焰伤害，并施加 1 层灼伤") > ice_at, "补 5.4：每颗一句两段（作者 2026-10-16：每颗一行，顺时针）（%s）" % text)


static func run_forge_and_enchant(t: TestCase) -> void:
	t.begin("175 补充五 · 铸炉元素行：火伤之外另加施加，一阶 1 层、每高一阶多 1 层（补 5.2 A）；日神附火每下施加一层灼伤（补 5.1 A）")
	var db := Cycle._db()
	var ench := Forge.forge(db.get_def(&"knife"), db.get_def(&"fire_crystal"), db.get_def(&"knife"))
	t.eq(String(ench.get("element", "")), "fire", "火晶石：火")
	var tiers := {}
	for rarity in [0, 2, 4]:
		var e := ench.duplicate()
		e["tier"] = rarity
		var r := Forge.rule_of(e)
		var app: ApplyStatus = null
		for eff in r.effects:
			if eff is ApplyStatus:
				app = eff
		t.check(r.effects[0] is DealDamage and (r.effects[0] as DealDamage).damage_type == DamageTypes.FIRE, "稀有度 %d：照打火伤" % rarity)
		t.check(app != null and app.buff.id == &"scorch", "稀有度 %d：另施加灼伤" % rarity)
		if app != null:
			tiers[rarity] = app.stacks
	t.eq(tiers, {0: 1, 2: 2, 4: 3}, "一阶 1 层、二阶 2 层、三阶 3 层")
	var ice := Forge.forge(db.get_def(&"knife"), db.get_def(&"ice_crystal"), db.get_def(&"knife"))
	var ri := Forge.rule_of(ice)
	t.check((ri.effects[ri.effects.size() - 1] as ApplyStatus).buff.id == &"chill", "冰晶石：施加寒冷")
	t.check(Forge.sentence(ench).contains("灼伤"), "附魔那一句写施加灼伤（%s）" % Forge.sentence(ench))
	var bone := Forge.forge(db.get_def(&"knife"), db.get_def(&"antler"), db.get_def(&"knife"))
	for eff in Forge.rule_of(bone).effects:
		t.check(not (eff is ApplyStatus) or (eff as ApplyStatus).buff.id == &"bleed", "没有元素行的（骨）不另加")

	var perk := EnchantWeaponsPerk.new()
	var pr := perk.rule()
	t.check(pr.effects[0] is FireEnchant, "附火：火焰伤害")
	t.check(pr.effects.size() == 2 and (pr.effects[1] as ApplyStatus).buff.id == &"scorch" and (pr.effects[1] as ApplyStatus).stacks == 1, "再施加一层灼伤")
	perk.applies_stacks = 0
	t.eq(perk.rule().effects.size(), 1, "层数写 0：只打火伤")


static func run_family_and_pure(t: TestCase) -> void:
	t.begin("175 补充五 · 流血 = 真实 · 物理（family = physical）；pure 只许流血（导入器：别的类型写 pure 报错）")
	var bleed := DamageTypes.get_def(DamageTypes.BLEED)
	t.check(bleed.pure and bleed.family == DamageTypes.PHYSICAL, "流血：真实、大类物理")
	var ok := ImportReport.new()
	ContentImporter.import_damage_type({"id": "bleed", "display_name": "流血", "pure": true, "family": "physical"}, AuthoringContext.context(), ok)
	t.check(ok.ok(), "流血写 pure：合法（%s）" % ok.to_text())
	var bad := ImportReport.new()
	ContentImporter.import_damage_type({"id": "fire", "display_name": "火焰", "pure": true}, AuthoringContext.context(), bad)
	t.check(not bad.ok() and bad.to_text().contains("只有流血是真实伤害"), "火焰写 pure：报错（%s）" % bad.to_text())
	var fam := ImportReport.new()
	ContentImporter.import_damage_type({"id": "x", "display_name": "x", "family": "nope"}, AuthoringContext.context(), fam)
	t.check(not fam.ok(), "认不得的大类：报错")

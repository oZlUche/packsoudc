## 130（作者定）：流派倾向道具 —— 三个新构件（某状态被施加时 / 转化状态 / 状态条件）、status_applied 事件、
## 放血刀吃对手的层、锯齿箭与毒匠手套只给对应武器挂规则、苦艮根只减毒伤、导入器拦自转与自环
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _start(ctx: BattleContext) -> void:
	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()


static func _hp(ctx: BattleContext, side: int) -> int:
	return StatMath.to_int(ctx.sides[side].resources.current(BattleStats.RES_HP))


static func _buff(id: String, max_stacks: int = 0, system: bool = false) -> BuffDef:
	var b := BuffDef.new()
	b.id = StringName(id)
	b.display_name = id
	b.stackable = max_stacks != 1     # 137：没有上限了，只剩可叠 / 不可叠
	b.system = system
	return b


static func _apply(def: BuffDef, stacks: int = 1, target: int = CombatEffect.Target.OPPONENT, per_stack: bool = false) -> ApplyStatus:
	var e := ApplyStatus.new()
	e.buff = def
	e.stacks = stacks
	e.target = target
	e.per_stack = per_stack
	return e


static func _opener(effects: Array, costs: Array = []) -> AbilityRule:
	return H._rule(OnBattleStart.new(), Always.new(), effects, costs)


static func _listen(buff_id: String, effects: Array, costs: Array = [], by_self: bool = true) -> AbilityRule:
	var tr := OnStatusApplied.new()
	tr.buff_id = StringName(buff_id)
	tr.by_self = by_self
	return H._rule(tr, Always.new(), effects, costs)


static func _ctx(side0: Array, side1: Array = []) -> BattleContext:
	return H._battle(H._spec(100.0, [H._compiled(1, "a", {}, side0)]), H._spec(100.0, [H._compiled(2, "b", {}, side1)]))


static func _flat(amount: float, type: StringName = DamageTypes.PHYSICAL) -> DealDamage:
	var e := DealDamage.new()
	e.damage_stat = &""
	e.amount = amount
	e.damage_type = type
	return e


static func run_trigger(t: TestCase) -> void:
	t.begin("130 · 某状态被施加时：只认本方施加、施加几层就读到几层、叠满后刷新不触发")
	var x := _buff("x")
	var mark := _buff("mark")

	var ctx := _ctx([_opener([_apply(x)]), _listen("x", [_apply(mark, 1, CombatEffect.Target.SELF)])])
	_start(ctx)
	t.eq(ctx.sides[0].stacks_of(&"mark"), 1, "给对手施加一层 → 触发一次")

	ctx = _ctx([_opener([_apply(x, 3)]), _listen("x", [_apply(mark, 1, CombatEffect.Target.SELF, true)])])
	_start(ctx)
	t.eq(ctx.sides[0].stacks_of(&"mark"), 3, "per_stack 读到这次施加的层数（3）")

	ctx = _ctx([_listen("x", [_apply(mark, 1, CombatEffect.Target.SELF)])], [_opener([_apply(x, 1, CombatEffect.Target.SELF)])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"x"), 1, "对手自己挂上了")
	t.eq(ctx.sides[0].stacks_of(&"mark"), 0, "对手自己施加的不算（by_self 默认）")

	ctx = _ctx([_listen("x", [_apply(mark, 1, CombatEffect.Target.SELF)], [], false)], [_opener([_apply(x, 1, CombatEffect.Target.SELF)])])
	_start(ctx)
	t.eq(ctx.sides[0].stacks_of(&"mark"), 1, "by_self 关掉：谁施加的都算")

	var capped := _buff("capped", 1)
	ctx = _ctx([_opener([_apply(capped), _apply(capped)]), _listen("capped", [_apply(mark, 1, CombatEffect.Target.SELF)])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"capped"), 1, "上限一层")
	t.eq(ctx.sides[0].stacks_of(&"mark"), 1, "第二次只是刷新时长：不触发")

	var tr := OnStatusApplied.new()
	t.eq(tr.subscribed_events(), [BattleEvent.STATUS_APPLIED] as Array[StringName], "只订阅 status_applied")
	t.check(not BattleEvent.is_view_event(BattleEvent.STATUS_APPLIED), "不进回放（同一刻已有 status_stacked）")


static func run_convert(t: TestCase) -> void:
	t.begin("130 · 转化状态：全部换掉、比例四舍五入且至少 1、可保留原状态、系统 buff 不转")
	var poison := _buff("poison")
	var vir := _buff("virulent")

	var cv := ConvertStatus.new()
	cv.from = &"poison"
	cv.to = vir
	var ctx := _ctx([_opener([_apply(poison, 3), cv])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "中毒归零")
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 3, "剧毒等量 3 层")

	var half := ConvertStatus.new()
	half.from = &"poison"
	half.to = vir
	half.ratio = 1.5
	ctx = _ctx([_opener([_apply(poison, 3), half])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 5, "3 × 1.5 = 4.5 → 四舍五入 5")

	var tiny := ConvertStatus.new()
	tiny.from = &"poison"
	tiny.to = vir
	tiny.ratio = 0.1
	tiny.keep_from = true
	ctx = _ctx([_opener([_apply(poison, 3), tiny])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 1, "换算不足 1 层也给 1 层")
	t.eq(ctx.sides[1].stacks_of(&"poison"), 3, "keep_from：原状态不动")

	var sys := _buff("decay_like", 0, true)
	var cv2 := ConvertStatus.new()
	cv2.from = &"decay_like"
	cv2.to = vir
	ctx = _ctx([_opener([_apply(sys, 2), cv2])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"decay_like"), 2, "系统 buff 不转")
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 0, "也就没有剧毒")

	# 转化出来的那部分也算「施加」：听剧毒施加的能接上
	var mark := _buff("mark")
	ctx = _ctx([_opener([_apply(poison, 2), cv]), _listen("virulent", [_apply(mark, 1, CombatEffect.Target.SELF, true)])])
	_start(ctx)
	t.eq(ctx.sides[0].stacks_of(&"mark"), 2, "转化出的 2 层剧毒发了 status_applied")


static func run_condition(t: TestCase) -> void:
	t.begin("130 · 状态条件：够层才放行、不扣层")
	var bleed := _buff("bleed")
	var mark := _buff("mark")
	var ok := StatusCondition.new()
	ok.buff_id = &"bleed"
	var ctx := _ctx([_opener([_apply(bleed)]), _listen("bleed", [_apply(mark, 1, CombatEffect.Target.SELF)], [ok])])
	_start(ctx)
	t.eq(ctx.sides[0].stacks_of(&"mark"), 1, "对手流血 ≥ 1：放行")
	t.eq(ctx.sides[1].stacks_of(&"bleed"), 1, "不扣层")

	var two := StatusCondition.new()
	two.buff_id = &"bleed"
	two.stacks = 2
	ctx = _ctx([_opener([_apply(bleed)]), _listen("bleed", [_apply(mark, 1, CombatEffect.Target.SELF)], [two])])
	_start(ctx)
	t.eq(ctx.sides[0].stacks_of(&"mark"), 0, "要两层只有一层：不放行")


static func run_items(t: TestCase) -> void:
	t.begin("130 · 十件道具：放血刀吃六层打一刀、蝰蛇毒腺转剧毒、创口盐对流血目标加伤、苦艮根只减毒伤")
	var db := _items()
	for id in ["bloodlust_bracer", "bloodhound_sigil", "bloodletter", "serrated_arrows", "wound_salt",
			"viper_gland", "envenomed_gauntlet", "blight_censer", "bitter_root", "festering_blade"]:
		t.not_null(db.get_def(StringName(id)), "有 %s" % id)
	var bleed_buff := ((db.get_def(&"scimitar").combat.rules[0] as AbilityRule).effects[1] as ApplyStatus).buff
	var poison_buff := ((db.get_def(&"poisoned_knife").combat.rules[0] as AbilityRule).effects[1] as ApplyStatus).buff

	# 放血刀第二条（132 起按目标层数 ×3）：对手攒够六层流血 → 每层 3 点、打完清掉流血
	var burst := db.get_def(&"bloodletter").combat.rules[1] as AbilityRule
	var ctx := _ctx([_opener([_apply(bleed_buff, 5)]), burst])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"bleed"), 5, "五层：不触发")
	t.eq(_hp(ctx, 1), 100, "没挨刀")
	ctx = _ctx([_opener([_apply(bleed_buff, 6)]), burst])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"bleed"), 0, "六层全扣")
	t.eq(_hp(ctx, 1), 82, "放血一刀 6 × 3 = 18 点")

	# 蝰蛇毒腺：自己施加的中毒立刻变剧毒；剧毒每层每秒 5 点
	var gland := db.get_def(&"viper_gland").combat.rules[0] as AbilityRule
	ctx = _ctx([_opener([_apply(poison_buff, 2)]), gland])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"poison"), 0, "中毒没了")
	t.eq(ctx.sides[1].stacks_of(&"virulent"), 2, "换成两层剧毒")
	H._advance_to(ctx, 1.05)
	t.eq(_hp(ctx, 1), 90, "一秒后掉 2 × 5 = 10")
	ctx = _ctx([gland], [_opener([_apply(poison_buff, 2, CombatEffect.Target.SELF)])])
	_start(ctx)
	t.eq(ctx.sides[1].stacks_of(&"poison"), 2, "对手自己带的中毒不转")

	# 创口盐：对手流血时物理 +20%
	var salt := db.get_def(&"wound_salt").combat.rules[0] as AbilityRule
	ctx = _ctx([_opener([_flat(10.0)]), salt])
	_start(ctx)
	t.eq(_hp(ctx, 1), 90, "没流血：照常 10")
	var hit := H._rule(OnStatusApplied.new(), Always.new(), [_flat(10.0)])
	(hit.trigger as OnStatusApplied).buff_id = &"bleed"
	ctx = _ctx([_opener([_apply(bleed_buff)]), hit, salt])
	_start(ctx)
	t.eq(_hp(ctx, 1), 88, "流血时 10 × 1.2 = 12")
	t.eq(ctx.sides[1].stacks_of(&"bleed"), 1, "不扣流血")

	# 苦艮根：只减受到的毒伤
	var root := db.get_def(&"bitter_root").combat.rules[0] as AbilityRule
	ctx = _ctx([_opener([_flat(10.0, &"poison"), _flat(10.0)])], [root])
	_start(ctx)
	t.eq(_hp(ctx, 1), 85, "毒伤 10 减半为 5，物理 10 不变")

	# 175：溃烂之刃的桥（流血被施加时附一层中毒）收进反应【菌血】—— 刀只剩出手时盖血印那一条
	t.eq(db.get_def(&"festering_blade").combat.rules.size(), 1, "溃烂之刃只剩一条规则（桥收进菌血）")

	# 嗜血护腕：对手被施加流血 → 自己加速 1 层（标准轴，不封顶；原来是一层嗜血 buff）
	var bracer := db.get_def(&"bloodlust_bracer").combat.rules[0] as AbilityRule
	var many: Array = []
	for i in 8:
		many.append(_apply(bleed_buff))
	ctx = _ctx([_opener(many), bracer])
	_start(ctx)
	t.eq(ctx.sides[0].axis_stacks(&"attack_speed"), 8, "八次施加，加速八层")
	t.eq(ctx.sides[0].stacks_of(&"bloodlust"), 0, "不再挂嗜血 buff")


## 一块不要求包的格子：锯齿箭挨着长弓，毒匠手套同时挨着小刀与长弓，另一枚锯齿箭只挨着小刀（压着的是近战）。
## 具体落点由棋盘自己找，不写死坐标
static func run_attach(t: TestCase) -> void:
	t.begin("130 · 锯齿箭只给远程、毒匠手套只给近战（108 的附加路径）")
	var db := _items()
	ItemInstance.reset_uid_counter()
	# 位置自己找（形状随时会改）：只要求谁的增益格盖到谁
	var g := GridInventory.new(Vector2i(10, 10), 1, false)
	var bow := TestSupport.put(g, db.get_def(&"longbow"))
	t.not_null(bow, "长弓放下")
	if bow == null:
		return
	var arrows := TestSupport.put_granting(g, db.get_def(&"serrated_arrows"), [bow])
	t.not_null(arrows, "锯齿箭挨着弓")
	if arrows == null:
		return
	var glove := TestSupport.put_granting(g, db.get_def(&"envenomed_gauntlet"), [bow])
	t.not_null(glove, "手套挨着弓")
	if glove == null:
		return
	var knife := TestSupport.put_where(g, db.get_def(&"knife"), func(inst: ItemInstance) -> bool:
		return TestSupport.grants_to(glove, inst) and not TestSupport.touches(inst, bow) and not TestSupport.touches(inst, arrows))
	t.not_null(knife, "小刀也挨着手套，但不碰弓和锯齿箭")
	if knife == null:
		return
	var arrows2 := TestSupport.put_where(g, db.get_def(&"serrated_arrows"), func(inst: ItemInstance) -> bool:
		return TestSupport.grants_to(inst, knife) and not TestSupport.touches(inst, bow))
	t.not_null(arrows2, "另一枚锯齿箭只挨着小刀")
	if arrows2 == null:
		return

	var spec := BattleCompiler.compile_board(g)
	var bow_c := spec.item_of(bow.uid)
	var knife_c := spec.item_of(knife.uid)
	var bow_from: Array = bow_c.attached.map(func(a): return a["origin"])
	var knife_from: Array = knife_c.attached.map(func(a): return a["origin"])
	t.eq(bow_from, [&"serrated_arrows"], "弓只挂了锯齿箭的（手套不给远程）")
	t.eq(knife_from, [&"envenomed_gauntlet"], "小刀只挂了手套的（锯齿箭不给近战）")
	var bow_rule := bow_c.rules[int(bow_c.attached[0]["rule_index"])]
	t.check((bow_rule.effects[0] as ApplyStatus).buff.id == &"bleed", "弓每箭附流血")
	var knife_rule := knife_c.rules[int(knife_c.attached[0]["rule_index"])]
	t.check((knife_rule.effects[0] as ApplyStatus).buff.id == &"poison", "小刀每刀附中毒")


static func run_validation(t: TestCase) -> void:
	t.begin("130 · 导入器：转化不许转成自己、「施加时」不许再施加同一个状态；新构件登记在册")
	for kind_type in [[&"trigger", &"on_status_applied"], [&"cost", &"status_condition"], [&"effect", &"convert_status"]]:
		t.check(EffectRegistry.has_type(kind_type[0], kind_type[1]), "登记了 %s" % kind_type[1])
		t.check(FieldText.TYPE_LABELS.has(String(kind_type[1])), "%s 有中文标签" % kind_type[1])
	var poison := {"id": "poison", "display_name": "中毒"}
	var self_convert := {"id": "t_conv", "shape": ["1"], "combat": {"rules": [{
		"trigger": {"type": "on_battle_start"}, "cadence": {"type": "always"},
		"effects": [{"type": "convert_status", "from": "poison", "to": poison}]}]}}
	var r1 := ImportReport.new()
	ContentImporter.import_item(self_convert, ContentImporter.Context.new(), r1)
	t.check(not r1.ok() and r1.to_text().contains("to 不能是 from"), "自转拦下（%s）" % r1.to_text())

	var loop := {"id": "t_loop", "shape": ["1"], "combat": {"rules": [{
		"trigger": {"type": "on_status_applied", "buff_id": "poison"}, "cadence": {"type": "always"},
		"effects": [{"type": "apply_status", "buff": poison}]}]}}
	var r2 := ImportReport.new()
	ContentImporter.import_item(loop, ContentImporter.Context.new(), r2)
	t.check(not r2.ok() and r2.to_text().contains("自己点燃自己"), "自环拦下（%s）" % r2.to_text())

	for id in ["viper_gland", "festering_blade", "bloodletter", "wound_salt"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/items/%s.json" % id))
		var r := ImportReport.new()
		ContentImporter.import_item(data, ContentImporter.Context.new(), r)
		t.check(r.ok(), "%s 导入无错（%s）" % [id, r.to_text()])

	t.check(Glossary.TERMS.has("施加时") and not Glossary.term_tip("施加时"), "术语「施加时」在册、不弹")
	var buffs := Glossary.buffs_in_item(_items().get_def(&"viper_gland"))
	t.check(buffs.has(&"virulent"), "蝰蛇毒腺的侧窗认得剧毒")
	var apo := load(ContentPaths.asset_file("enemies", "apothecary")) as EnemyDef
	t.check(apo.schools.has(&"poison"), "药师的流派里有毒")

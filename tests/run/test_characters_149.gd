## 149（作者定，五项待定按推荐）：角色差异落在棋盘（7 / 8 / 9 × 6）与初始面板（各占一轴，开局钱按角色）；
## 筋骨 / 耐久 / 扛重 / 行囊四条科技改百分比（先乘后加，乘算相加不相乘）；不屈改成「败仗少扣一点」；角色被动不许和科技撞同一种效果
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")

## 满级的四条科技
const MAX_TECHS: Array[StringName] = [&"tech_sinew_3", &"tech_endurance_3", &"tech_hauling_3", &"tech_pack_3"]

## 写死的对照表（数值来自三份角色 JSON 与 docs/techs.xlsx；改了数就改这里）：
## id → [棋盘, 生命, 耐力, 耐力回复, 体力, 负重, 开局钱, 满级生命, 满级体力, 满级负重, 满级开局钱]
const TABLE := {
	&"andreus": [Vector2i(9, 6), 45.0, 45.0, 4.0, 3, 64, 120, 58.5, 5, 96, 240],     # 256：体力 3、耐力 45、9 × 6、负重 64
	&"marcus": [Vector2i(8, 6), 55.0, 65.0, 5.0, 5, 48, 100, 71.5, 8, 72, 200],
	&"brutus": [Vector2i(9, 6), 70.0, 55.0, 3.0, 7, 56, 80, 91.0, 11, 84, 160],
}


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["characters", "hunter_defs", "buffs"])


static func _start(c: TestSupport.Content, ch: CharacterDef, techs: Array[StringName] = [] as Array[StringName]) -> RunState:
	for seed in range(1, 60):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs, techs, ch)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func _stat(s: RunState, key: StringName) -> float:
	return float(s.effective_baseline().base_stats.get(key, 0.0))


static func run_boards_and_panels(t: TestCase) -> void:
	t.begin("149 · 三个人：棋盘 8 / 9 × 6（256 起安德烈乌斯也是 9 × 6）；面板各占一轴；开局钱按角色；没写开局钱的角色用经济规则的全局数")
	var c := _content()
	for id in TABLE:
		var row: Array = TABLE[id]
		var ch := CS._character(c, id)
		t.not_null(ch, "%s 在" % id)
		if ch == null:
			continue
		var s := _start(c, ch)
		if s == null:
			t.check(false, "%s 开不了局" % id)
			continue
		t.eq(s.board.size, row[0], "%s：棋盘 %s" % [id, row[0]])
		t.eq(_stat(s, &"max_hp"), row[1], "%s：生命 %s" % [id, row[1]])
		t.eq(_stat(s, &"max_stamina"), row[2], "%s：耐力 %s" % [id, row[2]])
		t.eq(_stat(s, &"regen_stamina"), row[3], "%s：耐力回复 %s" % [id, row[3]])
		t.eq(s.vitality.maximum, int(row[4]) + c.chapter.vitality_bonus, "%s：体力 %d（+ 章节 %d）" % [id, row[4], c.chapter.vitality_bonus])
		t.eq(s.carry_capacity(), row[5], "%s：负重 %d" % [id, row[5]])
		t.eq(s.wallet.balance, 0, "%s：不带钱入局就是 0（2026-10-22 起钱全由玩家自己带）" % id)
		t.check(s.buff_context().stat_bonus.is_empty(), "%s：没有技能往基线上加数（操练不再是 +1 耐力回复）" % id)
	# 2026-10-22（作者定）：角色的 `starting_funds` 不再发钱 —— 开局的钱只看玩家带了多少
	var plain := CS._character(c, &"marcus").duplicate(true) as CharacterDef
	plain.starting_funds = -1
	var sp := _start(c, plain)
	t.eq(sp.wallet.balance, 0, "没写开局钱、也没带钱：0")
	# 开局屏的初始包在最窄的棋盘上也摆得下
	var narrow := GridInventory.new(TABLE[&"marcus"][0], RunState.BOARD_ID, true)
	RunState.give_kit(narrow, CS._character(c, &"marcus").starting_bags, c.items, null)
	t.eq(narrow.item_count(), CS._character(c, &"marcus").starting_bags.size(), "8 × 6 上初始包都摆得下")


static func run_percent_techs(t: TestCase) -> void:
	t.begin("149 · 科技改百分比：满级时三个人的生命 / 体力 / 负重 / 开局钱按各自的基数放大，差距比零级大；四舍五入；乘算相加不相乘；神坛加算在乘之后")
	var c := _content()
	for id in MAX_TECHS:
		t.check(c.buffs.has(id), "%s 在" % id)
	var zero := {}
	var full := {}
	for id in TABLE:
		var row: Array = TABLE[id]
		var ch := CS._character(c, id)
		var s := _start(c, ch, MAX_TECHS)
		if s == null:
			t.check(false, "%s 开不了局" % id)
			continue
		t.eq(_stat(s, &"max_hp"), row[7], "%s 满级：生命 %s" % [id, row[7]])
		t.eq(s.vitality.maximum, int(row[8]) + c.chapter.vitality_bonus, "%s 满级：体力 %d" % [id, row[8]])
		t.eq(s.carry_capacity(), row[9], "%s 满级：负重 %d" % [id, row[9]])
		# 2026-10-22（作者定）：钱全由玩家自己带 —— 科技不再放大开局钱（表里 row[10] 那列退役）
		t.eq(s.wallet.balance, 0, "%s 满级：开局钱仍是 0（玩家带多少就是多少）" % id)
		t.eq(_stat(s, &"max_stamina"), row[2], "%s 满级：耐力不动" % id)
		zero[id] = [row[1], row[4], row[5]]
		full[id] = [row[7], row[8], row[9]]
	for i in 3:
		var z: Array = []
		var f: Array = []
		for id in TABLE:
			z.append(float(zero[id][i]))
			f.append(float(full[id][i]))
		t.check(f.max() - f.min() > z.max() - z.min(), "第 %d 项：满级的差（%s）大于零级的差（%s）" % [i, f.max() - f.min(), z.max() - z.min()])

	t.eq(RunContext.scaled(5, 20, 0), 6, "5 × 1.2 = 6")
	t.eq(RunContext.scaled(7, 60, 0), 11, "7 × 1.6 = 11.2 → 11")
	t.eq(RunContext.scaled(40, 15, 0), 46, "40 × 1.15 = 46（整数算，不落成 45）")
	t.eq(RunContext.scaled(40, 15, 3), 49, "先乘后加")
	# 乘算相加不相乘：+10% 与 +20% = +30%，不是 1.1 × 1.2
	var ctx := RunContext.new()
	for amount in [10.0, 20.0]:
		var sb := StatBonus.new()
		sb.mode = StatBonus.Mode.MULT
		sb.amount = amount
		sb.modify(ctx)
	t.eq(float(ctx.stat_mult[&"max_hp"]), 30.0, "两条乘算相加：+30%")
	var vb := VitalityMaxBonus.new()
	vb.amount = 0
	vb.percent = 20
	vb.modify(ctx)
	vb.modify(ctx)
	t.eq(ctx.vitality_max_of(5), 7, "体力两条 +20%：5 × 1.4 = 7")
	t.check(StatBonus.new().describe().contains("+0") and sb_desc_mult().contains("%"), "说明：加算写数，乘算写百分号")
	# 神坛的加算在乘之后
	var brutus := CS._character(c, &"brutus")
	var s2 := _start(c, brutus, [&"tech_sinew_3"] as Array[StringName])
	var altar := AltarModule.of(s2)
	if altar != null:
		altar.stat_bonus["max_hp"] = 5.0
		t.eq(_stat(s2, &"max_hp"), 70.0 * 1.3 + 5.0, "神坛 +5 在 ×1.3 之后：96")
	# 战斗面板的「基础属性加成」一格写出了乘算
	var mult_shown := false
	for n in BattlePassives.of(s2):
		if (n as PassiveNote).id == &"base_bonus":
			for m in (n as PassiveNote).mods:
				if (m as StatModifier).mode == StatModifier.Mode.MULT and (m as StatModifier).stat == &"max_hp":
					mult_shown = true
	t.check(mult_shown, "基础属性加成里有生命 +30%")


static func sb_desc_mult() -> String:
	var sb := StatBonus.new()
	sb.mode = StatBonus.Mode.MULT
	sb.amount = 10.0
	return sb.describe()


static func run_undaunted_and_rule(t: TestCase) -> void:
	t.begin("149 · 不屈 = 败仗少扣一点（最少扣一）；安德烈乌斯独占免罚败仗；导入器拦角色被动和科技撞同一种效果；操练是战斗规则")
	var c := _content()
	var undaunted: RunBuffDef = c.buffs.get(&"tech_undaunted_1", null)
	t.not_null(undaunted, "不屈在")
	if undaunted == null:
		return
	t.check(undaunted.effects[0] is LossDiscount, "不屈的效果是 loss_discount")
	var marcus := CS._character(c, &"marcus")
	var s := _start(c, marcus, [&"tech_undaunted_1"] as Array[StringName])
	var discount := s.buff_context().loss_discount
	t.check(discount >= 1, "上下文里少扣 %d" % discount)
	s.hooks.register(&"player_spec", func() -> CombatantSpec: return BattleCompiler.compile_board(null))
	var node := CS._battle_node(s)
	var cost := s.node_rules.loss_cost_of(&"battle")
	var v0 := s.vitality.current
	t.check(not s.events.fight_content(node, &"battle", node.content), "没打赢")
	t.eq(s.vitality.current, v0 - maxi(1, cost - discount), "败仗扣 %d − %d（最少一）" % [cost, discount])
	var plain := _start(c, marcus)
	plain.hooks.register(&"player_spec", func() -> CombatantSpec: return BattleCompiler.compile_board(null))
	var v1 := plain.vitality.current
	plain.events.fight_content(CS._battle_node(plain), &"battle", node.content)
	t.eq(plain.vitality.current, v1 - cost, "没点不屈：照扣 %d" % cost)

	# 撞车检查：角色被动用了科技用的效果（筋骨 = stat_bonus）→ 报错；现在的三个角色导得进来
	var ctx := ContentImporter.Context.new()
	for id in c.buffs:
		ctx.register_run_buff(c.buffs[id])
	var bad := ImportReport.new()
	ContentImporter.import_character({"id": "x", "starting_bags": ["bag_leather"], "skills": [
		{"type": "passive", "id": "p", "display_name": "p", "passive": [{"type": "stat_bonus", "stat": "max_hp", "amount": 5.0}]}]}, ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("tech_sinew"), "撞了筋骨：报错并指出科技 —— " + bad.to_text().strip_edges().left(100))
	var old := ImportReport.new()
	ContentImporter.import_character({"id": "y", "starting_bags": ["bag_leather"], "skills": [
		{"type": "passive", "id": "p", "display_name": "p", "passive": [{"type": "free_losses"}]}]}, ctx, old)
	t.check(old.ok(), "免罚败仗不再撞科技（不屈换成了少扣）")
	for ch in c.characters:
		var data := ContentExporter.export_character(ch)
		var r := ImportReport.new()
		ContentImporter.import_character(data, ctx, r)
		t.check(r.ok(), "%s 导得进来：%s" % [ch.id, r.to_text().strip_edges().left(100)])
	var neg := ImportReport.new()
	ContentImporter.import_character({"id": "z", "starting_bags": ["bag_leather"], "starting_funds": -5}, ContentImporter.Context.new(), neg)
	t.check(not neg.ok(), "开局钱 −5 报错")

	# 操练：耐力掉到两成以下时回一段（一场一次）；说明里的数从规则来
	var drill: RunSkill = null
	for sk in marcus.skills:
		if (sk as RunSkill).id == &"drill":
			drill = sk
	t.not_null(drill, "马库斯有操练")
	if drill == null:
		return
	t.eq(drill.passive.size(), 0, "不再是一局被动")
	t.eq(drill.rules.size(), 1, "一条战斗规则")
	t.check(marcus.combat_rules().has(drill.rules[0]), "编进玩家的战斗规则")
	var text := Names.description_of(drill)
	var amount := int((drill.rules[0].effects[0] as ChangeResource).amount)
	t.check(not text.contains("{") and text.contains(str(amount)), "说明渲染了数（%s）：%s" % [amount, text])

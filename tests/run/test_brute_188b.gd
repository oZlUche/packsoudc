## 188 补充一（作者 2026-10-18 10:30）：信仰窗一级一行、没到的级灰；蛮神说明改写，X 随信力（每 50 信力一阶）；
## 二级献祭生命上限二选一（信力 / 造成伤害 + 急速）；三级耗体力或信力立即击败非首领敌人；献祭写「大型道具」
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const CELL := "\\[cell\\](.*?)\\[/cell\\]\\[cell expand=1\\](.*?)\\[/cell\\]"


static func _power(points: int) -> FaithPower:
	var p := FaithPower.new()
	p.points["brute"] = points
	return p


## 各级那一行：[{lv: 文字, text: 文字, raw: BBCode}]
static func _rows(def: FaithDef, points: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sec := String(FaithTooltip.describe_full(def, _power(points))["sections"][0])
	for m in RegEx.create_from_string(CELL).search_all(sec):
		out.append({"lv": Glossary.strip_bbcode(m.get_string(1)).replace("　", "").strip_edges(), "text": Glossary.strip_bbcode(m.get_string(2)), "raw": m.get_string(2)})
	return out


static func run_perk_lines(t: TestCase) -> void:
	t.begin("188 补充一 · 蛮神信仰窗：一级一行；45 信力 Lv.1 行有赐福武器 / 30% / 10%，Lv.2～4 灰，Lv.4 按 400 写 10 秒；400 → 50%、360 → 45%")
	var brute: FaithDef = FaithDef.load_all().get(&"brute", null)
	t.not_null(brute, "蛮神")
	if brute == null:
		return
	var rows := _rows(brute, 45)
	t.eq(rows.size(), 4, "四行（Lv.1～Lv.4 各一行）")
	if rows.size() != 4:
		return
	var lv1 := String(rows[0]["text"])
	t.check(String(rows[0]["lv"]) == "Lv.1" and lv1.contains("可以在祭坛赐福武器") and lv1.contains("生命值低于 30% 时，造成伤害提高 10%") and lv1.contains("；"), "Lv.1 一行两句：%s" % lv1)
	t.check(not String(rows[0]["raw"]).begins_with("[color=@dim]"), "Lv.1 到了：不灰")
	for i in range(1, 4):
		t.check(String(rows[i]["raw"]).begins_with("[color=@dim]"), "Lv.%d 没到：整行灰" % (i + 1))
	t.check(String(rows[1]["text"]).contains("可以在祭坛献祭生命上限换取能力"), "Lv.2：%s" % rows[1]["text"])
	t.check(String(rows[2]["text"]).contains("可消耗 1 体力或 30 信力立即击败非首领敌人"), "Lv.3：%s" % rows[2]["text"])
	t.check(String(rows[3]["text"]).contains("在战斗中，首次生命值归零时会持续战斗 10 秒"), "Lv.4 按到那一级的 400 信力写：%s" % rows[3]["text"])
	var at400 := _rows(brute, 400)
	t.check(at400.size() == 4 and String(at400[0]["text"]).contains("造成伤害提高 50%"), "400 信力：50%")
	t.check(at400.size() == 4 and not String(at400[3]["raw"]).begins_with("[color=@dim]"), "400 信力：Lv.4 亮")
	var at360 := _rows(brute, 360)
	t.check(at360.size() == 4 and String(at360[0]["text"]).contains("造成伤害提高 45%"), "赐福花 40 降到 360：360 / 50 取整 = 7，7 × 5 + 10 = 45%")
	var low: LowHpEmpowerPerk = null
	var und: UndyingPerk = null
	for p in brute.perks:
		if p is LowHpEmpowerPerk:
			low = p
		if p is UndyingPerk:
			und = p
	t.check(low != null and low.percent_at(100000) == 50, "增伤封顶 50%")
	t.check(und != null and und.seconds_at(100000) == 20.0, "持续战斗封顶 20 秒")


static func run_low_hp_threshold(t: TestCase) -> void:
	t.begin("188 补充一 · 低血增伤是门槛式：生命 29% 时造成伤害 +10%，31% 时不加")
	var rng := RandomNumberGenerator.new()
	var b := BattleCompiler.compile_board(null, CombatantBaseline.with_hp(100.0))
	for case in [[29, true], [31, false]]:
		var me := CombatantRuntime.from_spec(b, 0)
		var ctx := BattleContext.create(me, CombatantRuntime.from_spec(b, 1), rng)
		var mx := me.resources.maximum(BattleStats.RES_HP)
		me.resources.change(BattleStats.RES_HP, mx * int(case[0]) / 100 - me.resources.current(BattleStats.RES_HP), BattleEvent.REASON_DAMAGE)
		var packet := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx.sides[1], 0, 0)
		ctx._damage_stack.append(packet)
		var fx := LowHpEmpower.new()
		fx.hp_percent = 30
		fx.percent = 10
		fx.apply(RuleContext.create(ctx, me, RuleRuntime.create(null, 0, null, 0)))
		t.eq(packet.percent, StatMath.from_percent(10) if bool(case[1]) else 0, "生命 %d%%：%s" % [case[0], "+10%" if case[1] else "不加"])


static func run_sacrifice_and_smite(t: TestCase) -> void:
	t.begin("188 补充一 · 神坛二级：换信力 +20 / 换能力（每件道具造成伤害、急速 MULT +5，再做一次 +10）；三级：普通战斗也有两个按钮，不够的灰着写原因、点了花对的那样（体力 1 灰；信力 29 灰只在构件上验）")
	var c = NodeScreens._content()
	var kit = NodeScreens._kit(c)
	var found: Dictionary = NodeScreens._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := Support.flow(c, "188b")
	f.faith_defs = FaithDef.load_all()
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	Support.activate(run, &"charm_brute")
	run.faith_power.add_points(&"brute", 100)
	var altar := AltarModule.of(run)
	var hp_perk := altar.perk(&"altar_sacrifice_hp") as AltarSacrificeHpPerk
	t.not_null(hp_perk, "Lv.2 有献祭生命上限")
	if hp_perk == null:
		Support.cleanup("188b")
		return
	t.eq(hp_perk.altar_options(), [AltarSacrificeHpPerk.FAITH, AltarSacrificeHpPerk.BUFF] as Array[StringName], "两个选项")
	t.check(hp_perk.altar_option_label(AltarSacrificeHpPerk.FAITH).contains("+20 信力") and hp_perk.altar_option_label(AltarSacrificeHpPerk.BUFF).contains("造成伤害 +5%、急速 +5%"), "选项写清楚换什么")
	var p0 := run.faith_power.points_of(&"brute")
	hp_perk.altar_apply(run, null, AltarSacrificeHpPerk.FAITH)
	t.eq(run.faith_power.points_of(&"brute"), p0 + 20, "换信力 +20")
	var cin := CompileInput.new()
	hp_perk.compile_into(cin, run.board, run)
	t.check(cin.mods.is_empty(), "只换了信力：没有加成")
	for n in [1, 2]:
		hp_perk.altar_apply(run, null, AltarSacrificeHpPerk.BUFF)
		cin = CompileInput.new()
		hp_perk.compile_into(cin, run.board, run)
		var got := {}
		for m in cin.mods:
			var sm := m as StatModifier
			if sm.mode == StatModifier.Mode.MULT:
				got[sm.stat] = sm.amount
		t.check(float(got.get(BattleStats.DAMAGE, 0.0)) == 5.0 * n and float(got.get(BattleStats.HASTE, 0.0)) == 5.0 * n, "换了 %d 次能力：造成伤害、急速各 MULT +%d" % [n, 5 * n])
	t.check(hp_perk.battle_note(run).contains("+10%"), "常驻格写合计：%s" % hp_perk.battle_note(run))
	# 三级：立即击败
	run.faith_power.add_points(&"brute", 200)
	var smite := altar.perk(&"smite")
	t.check(f.step_to(int(found["next"])) and f.screen == GameFlow.Screen.PREBATTLE, "走上普通战斗点 → 战前准备")
	var acts: Array[Dictionary] = smite.prebattle_actions(run, &"battle") if smite != null else [] as Array[Dictionary]
	t.eq(acts.size(), 2, "普通战斗：两个按钮")
	t.check(smite != null and smite.prebattle_actions(run, &"core").is_empty(), "首领点：没有")
	# 信力不够那一档：到了 3 级信力至少 200，屏上碰不到（花信力会掉级），只在构件上验
	var keep := run.faith_power.points_of(&"brute")
	run.faith_power.spend_points(&"brute", keep - 29)
	acts = smite.prebattle_actions(run, &"battle")
	t.check(acts.size() == 2 and String(acts[0]["why"]) == "" and String(acts[1]["why"]).contains("信力不够"), "信力 29：信力那个灰、写原因（%s）" % acts[1]["why"])
	run.faith_power.add_points(&"brute", keep - 29)
	var vit_keep := run.vitality.current
	run.vitality.current = 1
	var screen = load("res://ui/game/prebattle_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	Engine.get_main_loop().root.add_child(screen)
	screen.open(f.last_payload)
	var btns := {}
	for n in screen.find_children("*", "Button", true, false):
		if (n as Button).has_meta("perk_option"):
			btns[(n as Button).get_meta("perk_option")] = n
	var vb: Button = btns.get(SmitePerk.VITALITY, null)
	var fb: Button = btns.get(SmitePerk.FAITH, null)
	t.check(btns.size() == 2 and vb != null and fb != null, "屏上两个按钮")
	if vb != null and fb != null:
		t.check(vb.disabled and vb.tooltip_text.contains("体力不够"), "体力 1：体力那个灰，停上去写原因")
		t.check(not fb.disabled and fb.text.contains("30 信力"), "信力那个能点：%s" % fb.text)
	screen.queue_free()
	t.check(not f.smite(SmitePerk.VITALITY), "体力不够：点不动")
	var before := run.faith_power.points_of(&"brute")
	t.check(f.smite(SmitePerk.FAITH), "耗信力立即击败")
	t.eq(run.faith_power.points_of(&"brute"), before - 30, "信力 −30")
	t.eq(run.vitality.current, 1, "体力没动")
	t.check(run.events.pending_battle.is_empty() and f.screen != GameFlow.Screen.PREBATTLE, "这一场算打过了")
	run.vitality.current = vit_keep
	Support.cleanup("188b")


static func run_offering_words(t: TestCase) -> void:
	t.begin("188 补充一 · 献祭：「占 9 格以上」改叫「大型道具」；没有图标时退回文字（有「骨制品」）；有图时排一行图标（193 起 32 像素）")
	var defs := FaithDef.load_all()
	var leaks: Array[String] = []
	for id in defs:
		var text := Glossary.strip_bbcode(FaithTooltip.describe(defs[id], _power(0)))
		for word in ["9 格", "体积及以上", "体积正好"]:
			if text.contains(word):
				leaks.append("%s：%s" % [id, word])
	t.check(leaks.is_empty(), "不写格数：%s" % "，".join(leaks))
	var brute: FaithDef = defs.get(&"brute", null)
	if brute == null:
		t.check(false, "蛮神")
		return
	var sections: Array = FaithTooltip.describe_full(brute)["sections"]
	var offer := String(sections[sections.size() - 1])
	var all_art := true
	for r in brute.offerings:
		if FaithTooltip.icon_paths(r).is_empty():
			all_art = false
	if all_art:
		t.check(offer.contains("[img=%d]res://assets/ui/tags/beast_part.png" % FaithTooltip.ICON_SIZE), "图标都在：排一行图标")
		t.check(not Glossary.strip_bbcode(offer).contains("大型道具"), "193 §3：图标都在就不写名字")
	else:
		t.check(Glossary.strip_bbcode(offer).contains("兽材") and not offer.contains("[img="), "还没有图标：文字（250：兽材还没有图标）")
		t.check(Glossary.strip_bbcode(offer).contains("大型道具"), "蛮神的大块东西写「大型道具」")
	t.eq(ItemVolume.size_label(3), "大型道具", "体积第三档 = 大型道具")

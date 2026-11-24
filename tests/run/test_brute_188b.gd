## 188 补充一（作者 2026-10-18 10:30）：信仰窗一级一行、没到的级灰；蛮神说明改写，X 随信力（每 50 信力一阶）；
## 二级献祭生命上限二选一（信力 / 造成伤害 + 急速）；三级耗体力或祈愿立即击败非首领敌人；献祭写「大型道具」
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const CELL := "\\[cell\\](.*?)\\[/cell\\]\\[cell expand=1\\](.*?)\\[/cell\\]"


static func _power(points: int) -> FaithPower:
	var p := FaithPower.new()
	p.points["brute"] = points
	return p


## 各级那一组：[{lv: 文字, text: 各条用换行连起来, raw: 第一条的 BBCode}]；257 起一条一行，阶号只在头一行
static func _rows(def: FaithDef, points: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sec := String(FaithTooltip.describe_full(def, _power(points))["sections"][0])
	for m in RegEx.create_from_string(CELL).search_all(sec):
		var lv := Glossary.strip_bbcode(m.get_string(1)).replace("　", "").strip_edges()
		var text := Glossary.strip_bbcode(m.get_string(2)).strip_edges()
		if lv != "":
			out.append({"lv": lv, "text": text, "raw": m.get_string(2)})
		elif text != "" and not out.is_empty():
			out[-1]["text"] = String(out[-1]["text"]) + "\n" + text
	return out


static func run_perk_lines(t: TestCase) -> void:
	t.begin("188 补充一 · 蛮神信仰窗（388 起：怒气 + 一阶赐福 + 二阶献祭；穿透、低血、不屈、立即击败改成了质变牌）：一级一行；45 信力 Lv.0、Lv.1 亮，Lv.2 灰")
	var brute: FaithDef = FaithDef.load_all().get(&"brute", null)
	t.not_null(brute, "蛮神")
	if brute == null:
		return
	var rows := _rows(brute, 45)
	t.eq(rows.size(), 3, "三组（基础 + Lv.1、Lv.2）")
	if rows.size() != 3:
		return
	t.check(String(rows[0]["lv"]) == "Lv.0" and String(rows[0]["text"]).contains("怒气"), "基础：怒气（%s）" % rows[0]["text"])
	var lv1 := String(rows[1]["text"])
	t.check(lv1.contains("可以在祭坛赐福武器") and not lv1.contains("穿透护甲"), "Lv.1 只有赐福（穿甲改成了【破甲】牌）：%s" % lv1)
	t.check(not String(rows[1]["raw"]).begins_with("[color=@dim]"), "Lv.1 到了：不灰")
	t.check(String(rows[2]["raw"]).begins_with("[color=@dim]"), "Lv.2 没到：整行灰")
	t.check(String(rows[2]["text"]).contains("可以在祭坛献祭生命上限换取能力"), "Lv.2：%s" % rows[2]["text"])
	for r in rows:
		t.check(not String(r["text"]).contains("体力立即击败") and not String(r["text"]).contains("持续战斗"), "没有旧的三阶那两句：%s" % r["lv"])


static func run_sacrifice_and_smite(t: TestCase) -> void:
	t.begin("188 补充一 · 神坛二级：换信力 +20 / 换能力（每件道具造成伤害、急速 MULT +5，再做一次 +10）；388 起立即击败按【神罚】牌给次数：没拿没按钮，用完灰着，点了记次数、不花体力")
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
	run.faith_power.add_points(&"brute", 120)     # 372：第二道门槛 117
	var altar := AltarModule.of(run)
	var hp_perk := altar.perk(&"altar_sacrifice_hp") as AltarSacrificeHpPerk
	t.not_null(hp_perk, "Lv.2 有献祭生命上限")
	if hp_perk == null:
		Support.cleanup("188b")
		return
	t.eq(hp_perk.altar_options(), [AltarSacrificeHpPerk.FAITH, AltarSacrificeHpPerk.BUFF] as Array[StringName], "两个选项")
	t.check(hp_perk.altar_option_label(AltarSacrificeHpPerk.FAITH).contains("经验值 +20") and hp_perk.altar_option_label(AltarSacrificeHpPerk.BUFF).contains("造成伤害 +5%、急速 +5%"), "选项写清楚换什么")
	var p0 := run.faith_power.points_of(&"brute")
	hp_perk.altar_apply(run, null, AltarSacrificeHpPerk.FAITH)
	t.eq(run.faith_power.points_of(&"brute"), p0 + 20, "换经验值 +20")
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
	# 388：立即击败改成质变牌【神罚】：一局几次，不花体力
	var smite := altar.perk(&"smite") as SmitePerk
	t.check(f.step_to(int(found["next"])) and f.screen == GameFlow.Screen.PREBATTLE, "走上普通战斗点 → 战前准备")
	t.check(smite != null and smite.prebattle_actions(run, &"battle").is_empty(), "没拿【神罚】：没有按钮")
	LevelModule.of(run).taken["god_brute_smite"] = 1
	var acts: Array[Dictionary] = smite.prebattle_actions(run, &"battle")
	t.check(acts.size() == 1 and String(acts[0]["why"]) == "", "拿了【神罚】：一个按钮，能点")
	t.check(smite.prebattle_actions(run, &"core").is_empty(), "首领点：没有")
	LevelModule.of(run).god_state[SmitePerk.USED_KEY] = 2
	acts = smite.prebattle_actions(run, &"battle")
	t.check(acts.size() == 1 and String(acts[0]["why"]) != "", "两次用完：灰着写原因（%s）" % (acts[0]["why"] if not acts.is_empty() else ""))
	t.check(not f.smite(SmitePerk.USES), "次数不够：点不动")
	LevelModule.of(run).god_state[SmitePerk.USED_KEY] = 1
	var vit := run.vitality.current
	t.check(f.smite(SmitePerk.USES), "还剩一次：点了就击败")
	t.eq(run.vitality.current, vit, "不花体力")
	t.eq(int(LevelModule.of(run).god_state[SmitePerk.USED_KEY]), 2, "用掉的次数记上")
	Support.cleanup("188b")


static func run_offering_words(t: TestCase) -> void:
	t.begin("188 补充一 · 献祭：「占 9 格以上」改叫「大型道具」；没有图标时退回文字（有「骨制品」）；有图时排一行图标（193 起 32 像素）")
	var defs := FaithDef.load_all()
	var leaks: Array[String] = []
	for id in defs:
		var text := Glossary.strip_bbcode(String(FaithTooltip.describe_full(defs[id], _power(0)).get("text", "")))
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

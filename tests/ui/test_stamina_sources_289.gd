## 289（作者 2026-11-07 15:04：「在耐力说明的悬浮窗里列出耐力消耗的来源」）：耐力签的悬浮窗下面两段 —— 消耗来源（一件一行、大到小）、
## 回复来源（基线 + 带回复的道具）；数和总数同一套算（[method StaminaEstimate.breakdown]）
extends RefCounted

const C148 := preload("res://tests/run/test_crystal_148.gd")


static func _board(db: ItemDatabase, ids: Array) -> Dictionary:
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(8, 6), 1, true)
	g.try_add(ItemInstance.create(db.get_def(&"bag_leather")), true)
	g.try_add(ItemInstance.create(db.get_def(&"bag_leather")), true)
	var made := {}
	for id in ids:
		var inst := ItemInstance.create(db.get_def(StringName(id)))
		if g.try_add(inst, true):
			made[id] = inst
	return {"board": g, "made": made}


static func run_breakdown(t: TestCase) -> void:
	t.begin("289 · 拆账：消耗一件一行、加起来 = 总数，大到小；回复 = 基线 + 口粮，加起来 = 总回复；装着晶石的法杖不列")
	var db := C148._db()
	var b := _board(db, ["knife", "knife", "ration"])
	var spec := BattleCompiler.compile_board(b["board"])
	var e := StaminaEstimate.breakdown(spec)
	var costs: Array = e["costs"]
	var sum := 0.0
	for r in costs:
		sum += float(r["per_sec"])
	t.eq(costs.size(), 2, "两把刀：两行（同名不合并）")
	t.check(absf(sum - float(e["cost"])) < 0.0001 and absf(float(e["cost"]) - float(StaminaEstimate.of(spec)["cost"])) < 0.0001, "消耗行之和 = 总数 = of()（%.2f）" % sum)
	var sorted := true
	for i in range(1, costs.size()):
		sorted = sorted and float(costs[i - 1]["per_sec"]) >= float(costs[i]["per_sec"])
	t.check(sorted, "大到小")
	var regens: Array = e["regen_rows"]
	var ration_regen := float(db.get_def(&"ration").combat.base_stats.get("regen_stamina", 0))
	t.check(regens.size() == 2 and int(regens[0]["uid"]) == 0 and StringName(regens[1]["def_id"]) == &"ration", "回复：基线一行、口粮一行")
	t.check(absf(float(regens[1]["per_sec"]) - ration_regen) < 0.0001, "口粮那行 = 它的回复（%.1f）" % ration_regen)
	t.check(absf(float(regens[0]["per_sec"]) + float(regens[1]["per_sec"]) - float(e["regen"])) < 0.0001, "基线 = 总回复 − 口粮")
	var staff := BattleCompiler.compile_board(C148._staff_board(db, &"fire_crystal", &"")["board"])
	t.eq((StaminaEstimate.breakdown(staff)["costs"] as Array).size(), 0, "装着晶石的法杖：不列")
	var empty_staff := BattleCompiler.compile_board(C148._staff_board(db, &"", &"")["board"])
	t.eq((StaminaEstimate.breakdown(empty_staff)["costs"] as Array).size(), 1, "空杖：列一行")


static func run_tip_text(t: TestCase) -> void:
	t.begin("289 · 悬浮窗：头两行照旧，下面「消耗来源」「回复来源」两段；没有消耗写一行；超过 8 件合成「其余 N 件」")
	var db := C148._db()
	var b := _board(db, ["knife", "ration"])
	var text := TextTemplate.strip_bbcode(StaminaEstimate.describe(BattleCompiler.compile_board(b["board"])))
	var knife_name := Names.of(db.get_def(&"knife"))
	t.check(text.contains("每秒平均消耗") and text.contains("耐力上限"), "头两行照旧")
	t.check(text.contains(UiText.t("stamina.costs_head")) and text.contains(UiText.t("stamina.regen_head")), "两段标题")
	t.check(text.contains(knife_name + "　") and text.contains(UiText.t("stamina.baseline") + "　"), "刀一行、基线一行（%s）" % text)
	t.check(text.contains(Names.of(db.get_def(&"ration")) + "　+"), "口粮带加号")
	t.check(text.find(UiText.t("stamina.costs_head")) < text.find(knife_name) and text.find(knife_name) < text.find(UiText.t("stamina.regen_head")), "刀在消耗段")
	var none := TextTemplate.strip_bbcode(StaminaEstimate.describe(BattleCompiler.compile_board(_board(db, ["ration"])["board"])))
	t.check(none.contains(UiText.t("stamina.no_cost")), "没有消耗：写「没有消耗」")
	var many := _board(db, ["knife", "knife", "knife", "knife", "knife", "knife", "knife", "knife", "knife", "knife"])
	var spec := BattleCompiler.compile_board(many["board"])
	var n := (StaminaEstimate.breakdown(spec)["costs"] as Array).size()
	var long := TextTemplate.strip_bbcode(StaminaEstimate.describe(spec))
	if n > StaminaEstimate.MAX_COST_ROWS:
		var rest := n - StaminaEstimate.MAX_COST_ROWS + 1
		t.check(long.contains("其余 %d 件" % rest), "%d 件：7 行 + 「其余 %d 件」" % [n, rest])
		t.eq(long.count(knife_name + "　"), StaminaEstimate.MAX_COST_ROWS - 1, "单列 7 行")
	else:
		t.check(false, "摆得下九件以上刀（%d）" % n)

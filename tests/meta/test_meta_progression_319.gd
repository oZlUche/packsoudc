## 319：局外成长改革 B 批 —— 两棵树（数值 / 机制）、见识点数、按总分阶梯发点、v4 → v5 迁移、战利分扣本金
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const Grid := preload("res://tests/meta/test_meta_grid.gd")
const META := "user://test_319_meta.json"


static func _result(score_: int, extracted: bool = false, run_id: String = "") -> RunResult:
	var r := RunResult.new()
	r.outcome = &"extracted" if extracted else &"defeated"
	r.run_id = run_id
	r.safe_net = score_     # 保险箱里的成功失败都算；普通难度、没别的项：总分 = 这一项
	return r


static func run_ladder(t: TestCase) -> void:
	t.begin("319 · 见识阶梯 1000 / 2000 / 5000：达到即领、每档一点；边界 0、999、1000、1999、2000、4999、5000、超高分；还差几分")
	var rules := ScoreRules.load_rules()
	t.eq(rules.insight_ladder, [1000, 2000, 5000] as Array[int], "score.json 里的三档")
	t.eq(rules.version, 2, "计分规则第 2 版（扣本金）")
	var want := {0: 0, 999: 0, 1000: 1, 1999: 1, 2000: 2, 4999: 2, 5000: 3, 99999: 3}
	for s in want:
		t.eq(rules.insight_for(s), want[s], "%d 分 → %d 点" % [s, want[s]])
	t.eq(rules.insight_gap(2340), 2660, "2340 分：还差 2660 到 5000")
	t.eq(rules.insight_gap(0), 1000, "0 分：还差 1000")
	t.eq(rules.insight_gap(5000), 0, "满档：0")


static func run_absorb_grants(t: TestCase) -> void:
	t.begin("319 · 结算发见识：成功、失败同一张表；余额 / 累计跟存档；同一局（run_id）再结算什么也不动；试玩切片不发")
	var db := T110._db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	var lost := _result(2340, false, "run-a")
	var got := m.absorb(lost)
	t.eq(int(got["insight"]), 2, "战败 2340 分：2 点")
	t.eq(lost.insight, 2, "记在这一局的结算里")
	t.eq(m.insight, 2, "余额 2")
	t.eq(int(m.history[0]["insight"]), 2, "历史行记见识")
	t.eq(int(m.history[0]["score_v"]), 2, "历史行记计分版本")
	var runs0 := m.runs
	var again := m.absorb(_result(2340, false, "run-a"))
	t.check(bool(again.get("duplicate", false)), "同一局再结算：标重复")
	t.eq(m.insight, 2, "不重复发")
	t.eq(m.runs, runs0, "局数也不加")
	var win := _result(5200, true, "run-b")
	m.absorb(win)
	t.eq(m.insight, 5, "撤离 5200 分：再 3 点")
	t.eq(m.insight_earned, 5, "累计得到 5")
	var low := _result(999, true, "run-c")
	m.absorb(low)
	t.eq(m.insight, 5, "999 分：0 点")
	var slice := _result(5000, true, "run-d")
	m.absorb(slice, 0, false)
	t.eq(m.insight, 5, "试玩切片：不发")
	t.eq(slice.insight, 0, "切片那一局记 0")
	t.check(m.spend_insight(2), "花 2 点")
	t.check(not m.spend_insight(99), "不够：花不了")
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.eq([back.insight, back.insight_earned, back.insight_spent], [3, 5, 2], "余额 / 得到 / 花掉跟存档")
	t.check(back.settled_runs.has("run-a") and back.settled_runs.has("run-d"), "结算过的局跟存档")
	t.check(bool(back.absorb(_result(100, false, "run-b")).get("duplicate", false)), "读档后同一局照样认得出")
	var many := MetaState.new()
	for i in MetaState.SETTLED_MAX + 5:
		many.absorb(_result(0, false, "r%d" % i))
	t.eq(many.settled_runs.size(), MetaState.SETTLED_MAX, "结算记录有上限，旧的先删")


static func run_mechanism_costs(t: TestCase) -> void:
	t.begin("319 · 机制树只花见识：钱再多没见识升不了；见识够就升、不扣钱；数值树照旧花钱不花见识")
	var defs := GameFlow.load_techs()
	var m := MetaState.new(GameFlow.load_meta_rules())
	var scouting := TechService.find(defs, &"scouting")
	var search := TechService.find(defs, &"thorough_search")
	m.funds = 100000
	t.check(not TechService.ready(m, search), "钱够、没见识：细搜不能点")
	m.insight = 1
	t.check(TechService.upgrade(m, search), "1 点见识：细搜 1 级")
	t.eq([m.funds, m.insight, m.insight_spent], [100000, 0, 1], "钱不动，见识花掉")
	m.insight = 1
	t.check(not TechService.ready(m, scouting), "侦察要 2 点：1 点不够")
	m.insight = 2
	t.check(TechService.upgrade(m, scouting), "2 点：侦察点亮")
	var endurance := TechService.find(defs, &"endurance")
	m.insight = 0
	t.check(TechService.upgrade(m, endurance), "数值树：只要钱")
	t.eq(m.funds, 100000 - endurance.tiers[0].funds, "扣了钱")
	for def in defs:
		for tier in def.tiers:
			if def.is_mechanism():
				t.check(tier.insight > 0 and tier.funds == 0 and tier.items.is_empty(), "%s：只花见识" % def.id)
			else:
				t.eq(tier.insight, 0, "%s：不花见识" % def.id)


static func run_import_cross_tree(t: TestCase) -> void:
	t.begin("319 · 导入：前置跨树、机制树花钱、数值树花见识都报错")
	var ctx := ContentImporter.Context.new()
	var r := ImportReport.new()
	var a := ContentImporter.import_tech({"id": "t319_a", "display_name": "A", "tree": "mechanism", "effect": {"type": "tech_safe_size"},
		"tiers": [{"insight": 1}]}, ctx, r)
	ContentImporter.import_tech({"id": "t319_b", "display_name": "B", "requires": ["t319_a"], "effect": {"type": "tech_safe_size"},
		"tiers": [{"funds": 10}]}, ctx, r)
	ContentImporter.validate_techs(ctx, r)
	t.not_null(a, "机制树节点导得进来")
	t.check(r.to_text().contains("另一棵树"), "跨树前置报错：%s" % r.to_text())
	var r2 := ImportReport.new()
	ContentImporter.import_tech({"id": "t319_c", "display_name": "C", "tree": "mechanism", "effect": {"type": "tech_safe_size"},
		"tiers": [{"funds": 5, "insight": 1}]}, ContentImporter.Context.new(), r2)
	t.check(r2.to_text().contains("只花见识"), "机制树花钱报错")
	var r3 := ImportReport.new()
	ContentImporter.import_tech({"id": "t319_d", "display_name": "D", "effect": {"type": "tech_safe_size"},
		"tiers": [{"funds": 5, "insight": 1}]}, ContentImporter.Context.new(), r3)
	t.check(r3.to_text().contains("不花见识"), "数值树花见识报错")


static func run_migrate_v4(t: TestCase) -> void:
	t.begin("319 · 老档 v4 → v5：幸运删掉、按旧成本退钱退材料；讨价 2 级并成 1 级、退第二级；机制树没交完的材料退回；数值树不动；再读一次不重复退；先备份")
	var text := FileAccess.get_file_as_string("res://tests/fixtures/meta_v4.json")
	var raw: Dictionary = JSON.parse_string(text)
	t.eq(int(raw["version"]), 4, "样本是 v4")
	var up := MetaMigrations.upgrade(raw)
	t.eq(int(up["version"]), MetaState.SAVE_VERSION, "升到当前版本")
	t.check(not (up["tech_levels"] as Dictionary).has("luck"), "幸运没了")
	t.eq(int(up["tech_levels"]["bargain"]), 1, "讨价 2 → 1")
	t.eq(int(up["tech_levels"]["market"]), 2, "高级货物照旧")
	t.eq(int(up["tech_levels"]["warehouse"]), 2, "数值树照旧")
	t.eq(int(up["funds"]), 100 + 400 + 800 + 1300 + 1000, "退钱：幸运三级 2500 + 讨价第二级 1000")
	t.eq(up["migration_refund"]["items"], {"hardwood_plank": 2, "rivet_box": 2, "silver_ingot": 1, "crystal_shards": 2}, "退材料：幸运 3 级的、讨价 2 级的、法杖工艺没交完的")
	t.check(not (up["tech_deposits"] as Dictionary).has("staffcraft"), "机制树的上交记录清掉")
	t.eq(int(up["tech_deposits"]["warehouse"]["steel_ingot"]), 1, "数值树的上交记录不动")
	t.eq((up["migration_log"] as Array).size(), 1, "迁移记一条")
	t.eq(int(raw["tech_levels"]["luck"]), 3, "不改入参")
	var db := T110._db()
	var m := MetaSave.from_text(text, db, GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.not_null(m, "v4 的档读得回来")
	if m == null:
		return
	var counts := {}
	for inst in m.warehouse.items():
		counts[String((inst as ItemInstance).def.id)] = int(counts.get(String((inst as ItemInstance).def.id), 0)) + 1
	for id in ["hardwood_plank", "rivet_box", "silver_ingot", "crystal_shards"]:
		t.check(int(counts.get(id, 0)) >= (2 if id != "silver_ingot" else 1), "%s 进了仓库" % id)
	t.check(not m.tech_buffs.has(&"tech_luck_3"), "没有幸运 buff")
	t.eq(m.tech_buffs.has(&"tech_bargain_1"), true, "讨价 1 级的 buff")
	t.check(not m.to_dict().has("migration_refund"), "存回去不再带退款单：再读不重复退")
	var again := MetaState.from_dict(MetaMigrations.upgrade(m.to_dict()), db, GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.eq(again.funds, m.funds, "读第二遍：钱不变")
	t.eq(again.warehouse.item_count(), m.warehouse.item_count(), "读第二遍：件数不变")
	# 迁移前备份
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META + ".v4.bak"))
	var read := MetaSave.read(db, META, GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.not_null(read, "从文件读")
	t.check(FileAccess.file_exists(META + ".v4.bak"), "迁移前留了 .v4.bak")
	t.eq(FileAccess.get_file_as_string(META + ".v4.bak"), text, "备份是原样")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META + ".v4.bak"))
	MetaSave.remove(META)


static func run_basis_score(t: TestCase) -> void:
	t.begin("319 · 战利分扣本金：带进来的原样带出不得分（账面价值照旧）；捡到的得分；合成成品接着本金；回局外去掉本金")
	var c = Grid._content()
	var s: RunState = Grid._extracted(c, 23, Grid._kit(c))
	var carried := 0
	for inst in s.board.items():
		var item := inst as ItemInstance
		if not item.is_pinned():
			t.check(item.has_basis(), "%s 带进来的记了本金" % item.def.id)
			carried += 1
	t.check(carried > 0, "带进了 %d 件" % carried)
	var r := RunResult.settle(s)
	t.check(r.value > 0, "背出去的账面价值 %d" % r.value)
	t.eq(r.loot_net, 0, "原样带出：战利分 0")
	t.eq(int(r.score_parts["loot"]), 0, "总分里的战利 0")
	var s2: RunState = Grid._extracted(c, 24, Grid._kit(c))
	var found := ItemInstance.create(c.items.get_def(&"knife"))
	t.check(s2.board.try_add(found, true), "捡到一把刀放上棋盘")
	var r2 := RunResult.settle(s2)
	t.eq(r2.loot_net, ItemValue.of_in(found, s2.board), "捡到的那把按全价算")
	var a := ItemInstance.create(c.items.get_def(&"knife"))
	a.set_basis(10)
	var b := ItemInstance.create(c.items.get_def(&"knife"))
	var out := ItemInstance.create(c.items.get_def(&"longsword"))
	CraftingModule.carry_basis(out, [a, b])
	t.eq(out.basis(), 10, "成品接着两件的本金（只有一件有）")
	var plain := ItemInstance.create(c.items.get_def(&"longsword"))
	CraftingModule.carry_basis(plain, [b, ItemInstance.create(c.items.get_def(&"knife"))])
	t.check(not plain.has_basis(), "两件都是捡的：成品没本金")
	var m := MetaState.new(GameFlow.load_meta_rules())
	m.absorb(r)
	for inst in m.board.items() if m.board != null else []:
		t.check(not (inst as ItemInstance).has_basis(), "回局外的 %s 没本金" % (inst as ItemInstance).def.id)


static func run_result_panel(t: TestCase) -> void:
	t.begin("319 · 结算屏见识小纸：领了几点、三档打勾、还差几分（满档写已完成）、余额")
	var rules := ScoreRules.load_rules()
	var r := _result(2340)
	r.score = 2340
	r.insight = 2
	var box := ResultScreenScript.insight_panel(r, rules, 7)
	var texts: Array[String] = []
	for l in box.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	t.eq(texts[0], UiText.t("result.insight_gain") % 2, "头一行：见识 +2")
	t.check(texts[1].ends_with("✓") and texts[2].ends_with("✓") and not texts[3].ends_with("✓"), "1000、2000 打勾，5000 没有：%s" % [texts])
	t.eq(texts[4], UiText.t("result.insight_gap") % 2660, "还差 2660")
	t.eq(texts[5], UiText.t("result.insight_balance") % 7, "余额 7")
	box.free()
	r.score = 6000
	var full := ResultScreenScript.insight_panel(r, rules, 7)
	var last: Array[String] = []
	for l in full.find_children("*", "Label", true, false):
		last.append((l as Label).text)
	t.eq(last[4], UiText.t("result.insight_all"), "满档：已完成所有档位")
	full.free()


const ResultScreenScript := preload("res://ui/game/result_screen.gd")


static func frame_tech_tabs(t: TestCase, root: Window) -> void:
	t.begin("319 · 科技页两枚页签：数值成长 / 机制成长（带见识余额）；换页签树只画那一棵；选另一棵树的节点自动换页签；机制节点的账目行写见识、说明怎么得")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	m.insight = 4
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), m)
	f.meta_path = META
	f.settings_path = "user://test_319_settings.json"
	f.tech_defs = GameFlow.load_techs()
	f.buff_defs = RunBuffs.load_all()
	var panel = load("res://ui/game/tech_panel.gd").new()
	root.add_child(panel)
	panel.setup(f, UiPalette.cjk_font())
	t.eq(panel.current_tree(), TechDef.TREE_STAT, "先看数值树")
	t.not_null(panel.tree().node_button(&"warehouse"), "树上有仓库")
	t.is_null(panel.tree().node_button(&"pack"), "没有行囊（在另一棵）")
	t.check(String(panel.tree_tab(TechDef.TREE_MECHANISM).text).contains(UiText.t("tech.insight_have") % 4), "机制成长页签带余额：%s" % panel.tree_tab(TechDef.TREE_MECHANISM).text)
	panel.tree_tab(TechDef.TREE_MECHANISM).pressed.emit()
	t.eq(panel.current_tree(), TechDef.TREE_MECHANISM, "按页签换到机制树")
	t.not_null(panel.tree().node_button(&"pack"), "树上有行囊")
	t.is_null(panel.tree().node_button(&"warehouse"), "没有仓库")
	t.check(panel.select(&"scouting"), "选侦察")
	var cost := String(panel.panel_texts()["cost"])
	t.check(cost.contains(UiText.t("tech.insight")) and cost.contains(UiText.t("tech.insight_how")), "账目行写见识、写怎么得：%s" % cost)
	t.check(String(panel.panel_texts()["effect"]).contains(UiText.t("tech.next_run")), "局外 buff：写下一次出征起生效")
	t.check(panel.select(&"sinew"), "选筋骨")
	t.eq(panel.current_tree(), TechDef.TREE_STAT, "选数值树的节点：自动换回数值树")
	t.check(panel.select(&"thorough_search"), "选细搜")
	panel.upgrade(&"thorough_search")
	t.eq(m.insight, 3, "点亮细搜花 1 点")
	t.check(String(panel.tree_tab(TechDef.TREE_MECHANISM).text).contains(UiText.t("tech.insight_have") % 3), "页签上的余额跟着变")
	panel.queue_free()
	MetaSave.remove(META)
	GameSettings.remove("user://test_319_settings.json")

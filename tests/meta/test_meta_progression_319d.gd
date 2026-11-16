## 319 D 批：追踪一项科技（还差的材料 + 哪种材料节点出、还差几点见识；存档往返）、局内计数（额外奖励 / 换货进对局记录）、见识校准台冒烟
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const ResultScreenScript := preload("res://ui/game/result_screen.gd")


static func run_target_shortfall(t: TestCase) -> void:
	t.begin("319 D · 追踪：数值树写还差的材料（仓库里有的扣掉）和哪种材料节点出；机制树写还差几点见识；满级不写")
	var db := T110._db()
	var defs := GameFlow.load_techs()
	var m := T110._meta()
	var undaunted := TechService.find(defs, &"undaunted")
	var short := TechTarget.shortfall(m, undaunted)
	t.eq(short["items"], {"hardwood_plank": 2, "steel_ingot": 2}, "两样材料都还差 2")
	T110._add(m, db, &"steel_ingot")
	t.eq(TechTarget.shortfall(m, undaunted)["items"], {"hardwood_plank": 2, "steel_ingot": 1}, "仓库里有一件：钢锭还差 1")
	var kinds := TechTarget.search_kinds(GameFlow.load_chapters())
	t.check(kinds.has("remains"), "各章材料节点合起来有遗骸：%s" % [kinds.keys()])
	t.eq(TechTarget.sources_of(db.get_def(&"steel_ingot"), kinds), [NodeText.label_of(&"search_remains")] as Array[String], "工艺材料：遗骸出")
	m.tracked_tech = &"undaunted"
	var line := TechTarget.line(m, defs, db, kinds)
	t.check(line.begins_with(UiText.t("tech.target_head") % Names.of(undaunted)) and line.contains(NodeText.label_of(&"search_remains")), "一行：目标 + 还差 + 来源：%s" % line)
	m.tracked_tech = &"scouting"
	m.insight = 1
	t.check(TechTarget.line(m, defs, db, kinds).contains(UiText.t("tech.target_insight") % 1), "侦察要 2 点、有 1：还差 1 点见识")
	m.insight = 5
	t.check(TechTarget.line(m, defs, db, kinds).ends_with(UiText.t("tech.target_ready_insight")), "见识够了")
	m.tech_levels["scouting"] = TechService.find(defs, &"scouting").max_level()
	t.eq(TechTarget.line(m, defs, db, kinds), "", "满级不写")
	m.tracked_tech = &""
	t.eq(TechTarget.line(m, defs, db, kinds), "", "没追踪不写")


static func run_target_save_and_panel(t: TestCase) -> void:
	t.begin("319 D · 追踪存档往返；结算小纸最后一行写目标（没追踪不写）")
	var db := T110._db()
	var m := T110._meta()
	m.tracked_tech = &"undaunted"
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.eq(back.tracked_tech, &"undaunted", "读回来还在追踪")
	t.eq(MetaState.from_dict(T110._meta().to_dict(), db, GameFlow.load_meta_rules()).tracked_tech, &"", "没追踪的档读回来是空")
	var r := RunResult.new()
	r.score = 1200
	r.insight = 1
	var box := ResultScreenScript.insight_panel(r, ScoreRules.load_rules(), 3, "目标：X")
	t.not_null(box.find_child("Target", true, false), "有目标那一行")
	box.free()
	var bare := ResultScreenScript.insight_panel(r, ScoreRules.load_rules(), 3)
	t.is_null(bare.find_child("Target", true, false), "没追踪：不写")
	bare.free()


static func frame_track_key(t: TestCase, root: Window) -> void:
	t.begin("319 D · 科技页【追踪】：按了记下、再按取消；满级不摆")
	ItemInstance.reset_uid_counter()
	var m := T110._meta()
	var f := GameFlow.new(T110._db(), EnemyDatabase.new(), SetDatabase.new(), m)
	f.meta_path = "user://test_319d_meta.json"
	f.settings_path = "user://test_319d_settings.json"
	f.tech_defs = GameFlow.load_techs()
	f.buff_defs = RunBuffs.load_all()
	var panel = load("res://ui/game/tech_panel.gd").new()
	root.add_child(panel)
	panel.setup(f, UiPalette.cjk_font())
	t.check(panel.select(&"undaunted"), "选一项")
	t.not_null(panel.track_button(), "有【追踪】")
	t.eq(String(panel.track_button().text), UiText.t("tech.track"), "写追踪")
	panel.track_button().pressed.emit()
	t.eq(m.tracked_tech, &"undaunted", "记下了")
	t.eq(String(panel.track_button().text), UiText.t("tech.untrack"), "换成取消追踪")
	panel.track_button().pressed.emit()
	t.eq(m.tracked_tech, &"", "再按取消")
	m.tech_levels["undaunted"] = TechService.find(f.tech_defs, &"undaunted").max_level()
	panel.select(&"undaunted")
	m.changed.emit()
	t.is_null(panel.track_button(), "满级：不摆")
	panel.queue_free()
	MetaSave.remove(f.meta_path)
	GameSettings.remove(f.settings_path)


static func run_counters_to_record(t: TestCase) -> void:
	t.begin("319 D · 对局记录：额外奖励件数、换货次数与花费从计数来，存档只在有的时候写")
	var r := RunResult.new()
	t.check(not r.to_dict().has("bounty") and not r.to_dict().has("shop_refreshes"), "没有就不写")
	r.bounty = 1
	r.shop_refreshes = 1
	r.shop_refresh_coins = 40
	var d := r.to_dict()
	t.eq([d.get("bounty"), d.get("shop_refreshes"), d.get("shop_refresh_coins")], [1, 1, 40], "有就写")


static func run_bench_smoke(t: TestCase) -> void:
	t.begin("319 D · 见识校准台：一局出生即撤、一局认真探索都走得完；同种子两遍一样；汇总表有这两组")
	var ctx := InsightBench.content()
	var rows: Array = []
	for st in ["rush", "explore"]:
		var row := InsightBench.play(ctx, {"seed": 1, "strategy": st, "difficulty": "normal", "techs": []})
		t.check(["extracted", "defeated", "stuck"].has(String(row.get("outcome", ""))), "%s 走完了：%s" % [st, row.get("outcome", "?")])
		rows.append(row)
	var again := InsightBench.play(ctx, {"seed": 1, "strategy": "rush", "difficulty": "normal", "techs": []})
	t.eq([again["score"], again["steps"]], [rows[0]["score"], rows[0]["steps"]], "同种子同分同步数")
	var md := InsightBench.markdown(InsightBench.summarize(rows), [])
	t.check(md.contains("| rush |") and md.contains("| explore |"), "汇总表两组都在")

## 269（作者 2026-10-31 11:50 定 A）：总分 = （战利 + 战绩 + 探索）× 难度系数，向下取整；战败也有分；局外累计一局只加一次；最佳一局按分
extends RefCounted

const Records := preload("res://tests/ui/test_run_records_261.gd")


## 作者截图那局：走过 14、击败 8（其中精英 1）、打输 2、搜索 5、战败、普通难度、什么也没带出
static func _screenshot_run() -> RunResult:
	var r := RunResult.new()
	r.outcome = &"defeated"
	r.reason = &"vitality_depleted"
	r.visited = 14
	r.steps = 32
	r.battles_won = 9
	r.elite_won = 1
	r.battles_lost = 2
	r.searches = 5
	return r


static func run_rules(t: TestCase) -> void:
	t.begin("269 · 计分规矩从 score.json 来：击败 10 / 40 / 200，探索 2 / 5 / 5 / 25，难度每档 0.25，撤离不另加，战利算分")
	var rules := ScoreRules.load_rules()
	t.eq([rules.kill_points("normal"), rules.kill_points("elite"), rules.kill_points("boss")], [10, 40, 200], "击败普通 / 精英 / 首领")
	t.eq([rules.explore_points("visited"), rules.explore_points("search"), rules.explore_points("craft"), rules.explore_points("lit")], [2, 5, 5, 25], "走过 / 搜索 / 合成 / 图鉴新点亮")
	t.eq(rules.difficulty_step, 0.25, "难度每档 +0.25")
	t.eq(rules.extract_bonus, 0, "撤离不另加")
	t.check(rules.loot_counts, "带出价值算分")
	t.eq([rules.mult(0), rules.mult(3)], [1.0, 1.75], "普通 ×1、进阶三 ×1.75")


static func run_screenshot_run(t: TestCase) -> void:
	t.begin("269 · 作者截图那局（战败、走过 14、击败 8 + 精英 1、搜索 5、普通难度）= 173，不再是 0")
	var r := _screenshot_run()
	r.compute_score()
	t.eq(r.score, 173, "总分 173")
	t.eq(r.score_parts, {"loot": 0, "battle": 120, "explore": 53, "mult": 1}, "战利 0 · 战绩 8×10 + 40 · 探索 14×2 + 5×5")
	var rows := LedgerView.rows_for(r, 0)
	var total: Dictionary = rows[rows.size() - 1]
	t.eq(LedgerView.text_at(total), "173", "账单总分行写 173")
	t.eq(String(total["parts"]), UiText.t("ledger.score_parts") % [0, 120, 53], "下面小字：战利 0 · 战绩 120 · 探索 53（普通难度不写难度）")
	t.eq(rows.size(), 12, "十一行 + 总分，行数不变")
	r.safe_value = 30
	r.value = 999     # 战败：棋盘上的不算
	r.compute_score()
	t.eq(r.score, 203, "战败只算保险箱的价值：173 + 30")


static func run_extract_and_difficulty(t: TestCase) -> void:
	t.begin("269 · 撤离 = 带出价值 + 保险箱 + 战绩 + 探索；图鉴新点亮一件 25；进阶三 ×1.75 向下取整，账单小字写难度")
	var r := _screenshot_run()
	r.outcome = &"extracted"
	r.reason = &"extract"
	r.value = 400
	r.safe_value = 50
	r.crafts = 2
	r.boss_won = 1
	r.battles_won = 10
	r.compute_score(3)
	t.eq(r.score_parts["loot"], 450, "战利 = 400 + 50")
	t.eq(r.score_parts["battle"], 8 * 10 + 40 + 200, "战绩：普通 8 + 精英 1 + 首领 1")
	t.eq(r.score_parts["explore"], 14 * 2 + 5 * 5 + 2 * 5 + 3 * 25, "探索：走过 + 搜索 + 合成 + 新点亮 3")
	t.eq(r.score, 450 + 320 + 138, "普通难度不乘")
	r.difficulty_level = 3
	r.compute_score(3)
	t.eq(r.score, floori((450 + 320 + 138) * 1.75), "进阶三 ×1.75 向下取整（%d）" % r.score)
	t.check(LedgerView.score_parts_text(r).ends_with(UiText.t("ledger.score_mult") % "1.75"), "小字末尾「 · 难度 ×1.75」（%s）" % LedgerView.score_parts_text(r))
	r.difficulty_level = 1
	r.compute_score(3)
	t.check(LedgerView.score_parts_text(r).ends_with(UiText.t("ledger.score_mult") % "1.25"), "进阶一 ×1.25（%s）" % LedgerView.score_parts_text(r))


static func run_meta_score(t: TestCase) -> void:
	t.begin("269 · 局外累计：撤离 / 战败各加一次（含图鉴新点亮那笔），历史行记分；最佳一局按分挑；老的 best_run 没分按价值比")
	var db := ItemDatabase.new()
	db.load_dir()
	var m := MetaState.new(GameFlow.load_meta_rules())
	var lost := _screenshot_run()
	var got := m.absorb(lost)
	t.eq(m.score, 173, "战败一局：+173（不是 0）")
	t.eq(int(got["score"]), 173, "absorb 返回这局的分")
	t.eq(int(m.history[0]["score"]), 173, "历史行记分")
	t.eq(int(m.best_run.get("score", -1)), 173, "最佳一局：战败的也能是最佳（按分）")
	var win := RunResult.new()
	win.outcome = &"extracted"
	win.reason = &"extract"
	win.value = 100
	var knife := ItemInstance.create(db.get_def(&"knife"))
	win.carried.append(knife)
	got = m.absorb(win)
	t.eq(int(got["lit"]), 1, "带出一把刀：图鉴新点亮 1")
	t.eq(win.score, 100 + 25, "撤离：价值 100 + 新点亮 1 × 25")
	t.eq(m.score, 173 + win.score, "累计只加一次（价值不再另加）")
	t.eq(int(m.best_run["score"]), 173, "100 多分的撤离没超过 173：最佳一局不换")
	t.eq(m.best_value, 100, "best_value 仍按价值（成就「满载而归」不动）")
	m.best_run = {"value": 500, "outcome": "extracted"}     # 269 前的存档：best_run 没记分
	var big := RunResult.new()
	big.outcome = &"extracted"
	big.value = 300
	m.absorb(big)
	t.eq(int(m.best_run["value"]), 500, "老 best_run 没分：按价值 500 比，300 分的新局不顶掉")
	var bigger := RunResult.new()
	bigger.outcome = &"extracted"
	bigger.value = 600
	m.absorb(bigger)
	t.eq(int(m.best_run.get("score", -1)), 600, "超过了才换成新局（带分）")
	var back := MetaState.from_dict(m.to_dict(), db)
	t.eq(back.score, m.score, "累计分跟存档")
	t.eq(int(back.history[0]["score"]), 600, "历史行的分跟存档")


static func frame_records_score(t: TestCase, root: Window) -> void:
	t.begin("269 · 对局记录：列表加「分」一栏、详情一行「总分 N（战利 · 战绩 · 探索）」；269 前的老行写「—」")
	var f := Records._flow()
	f.meta.history.append({"outcome": "extracted", "reason": "extract", "run_no": 1, "value": 80, "steps": 9, "chapter": "free_mode", "pinned": false})
	f.meta.runs = 1
	f.meta.absorb(_screenshot_run())
	var screen = Records._screen(f, root)
	screen.open_shelf("records")
	var win: RunRecordsWindow = screen.records_window()
	t.eq(win.row_count(), 2, "两行")
	t.eq(String(win.row_columns(0)[5]), UiText.t("records.col_score") % "173", "新局：分一栏写 173")
	t.eq(String(win.row_columns(1)[5]), UiText.t("records.col_score") % UiText.t("records.no_score"), "老行：「—」")
	win.show_detail(0)
	t.check(win.detail_text().contains(UiText.t("records.detail_score") + " " + UiText.t("records.detail_score_v") % [173, 0, 120, 53]), "详情写总分与三项（%s）" % win.detail_text())
	win.show_detail(1)
	t.check(win.detail_text().contains(UiText.t("records.detail_score") + " " + UiText.t("records.no_score")), "老行详情：「—」")
	screen.queue_free()
	Records._cleanup()

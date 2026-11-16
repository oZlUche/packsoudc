## 319 D 批：见识阶梯校准台（[InsightBench]）。同一批种子 × 玩法 × 难度 × 科技（无 / 满机制树）整局走，出一张汇总表和逐局 CSV。只出表，不改数。
##
##     godot --headless --path . --script res://tools/insight_bench.gd -- [--seeds=20] [--seed=1] [--strategies=rush,tier1,explore,explore_all]
##         [--difficulties=normal,ascension_4,ascension_10] [--techs=none,full] [--chapter=free_mode] [--character=andreus]
##         [--preset=preset_offense] [--scale=] [--out=报告.md] [--csv=逐局.csv]
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var seeds := int(opts.get("seeds", "20"))
	var first := int(opts.get("seed", "1"))
	var strategies := String(opts.get("strategies", ",".join(InsightBench.STRATEGIES))).split(",")
	var diffs := String(opts.get("difficulties", "normal,ascension_4,ascension_10")).split(",")
	var tech_sets := String(opts.get("techs", "none,full")).split(",")
	var base := {"chapter": String(opts.get("chapter", "free_mode")), "character": String(opts.get("character", "andreus")),
		"preset": String(opts.get("preset", "preset_offense")), "scale": String(opts.get("scale", ""))}
	var ctx := InsightBench.content()
	var rows: Array = []
	var started := Time.get_ticks_msec()
	for d in diffs:
		for tk in tech_sets:
			for st in strategies:
				for i in seeds:
					var cfg := base.duplicate()
					cfg.merge({"seed": first + i, "strategy": st, "difficulty": d, "techs": InsightBench.FULL_MECH if tk == "full" else []})
					var t0 := Time.get_ticks_msec()
					var row := InsightBench.play(ctx, cfg)
					rows.append(row)
					print("IB %s %s %s 种子 %d：%s 分 %s 步 %s，%.1f 秒" % [d, tk, st, first + i, row.get("outcome", "?"), row.get("score", "?"), row.get("steps", "?"),
						(Time.get_ticks_msec() - t0) / 1000.0])
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	var header: Array[String] = [
		"日期 %s；章节 `%s`，角色 `%s`，预设 `%s`，规模 `%s`；种子 %d～%d（每格 %d 局，玩法、难度、科技之间配对）；共 %d 局，用 %.0f 秒。" % [
			Time.get_date_string_from_system(), base["chapter"], base["character"], base["preset"], base["scale"] if base["scale"] != "" else "默认",
			first, first + seeds - 1, seeds, rows.size(), secs],
		"见识阶梯 %s（`score.json`）。「新档」= 带出的不同道具都算图鉴新点亮；「老玩家」= 图鉴不加分。" % str(ScoreRules.load_rules().insight_ladder),
	]
	var md := InsightBench.markdown(InsightBench.summarize(rows), header)
	var out := String(opts.get("out", ""))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		if not write_text(out, md):
			return
		print("写好了 " + out)
	else:
		print(md)
	var csv := String(opts.get("csv", ""))
	if csv != "":
		var cols := ["seed", "strategy", "difficulty", "techs", "outcome", "steps", "actions", "score", "score_veteran", "lit", "insight",
			"insight_veteran", "battles", "elites", "bosses", "searches", "bounty", "refresh_used"]
		var lines: Array[String] = [",".join(PackedStringArray(cols))]
		for row in rows:
			lines.append(",".join(PackedStringArray(cols.map(func(c: String) -> String: return str((row as Dictionary).get(c, ""))))))
		DirAccess.make_dir_recursive_absolute(csv.get_base_dir())
		if not write_text(csv, "\n".join(lines) + "\n"):
			return
		print("写好了 " + csv)
	finish(0)

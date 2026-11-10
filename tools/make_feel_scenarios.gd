## 平衡检测方案（2026-11-10）§8.3：造人工验证用的短场景（[FeelScenarios]），存输入包、预期事实和问题清单；
## 每一场再写一份回放存档进 `user://battle_logs`，作者从启动选择器的「战斗回放」里就能看。
##
##     godot --headless --path . --script res://tools/make_feel_scenarios.gd -- [输出目录=user://diagnostics/feel] [--no-replays]
##
## 输出目录里：每个场景一份 `<代号>.diag.tres`、`scenarios.json`（预期事实）、`questions.md`（先自由回答再看诊断）。
## 退出码：0 全部找到；2 有场景没找到（照样写出找到的）；1 写不了
extends CliTool

const DEFAULT_DIR := "user://diagnostics/feel"
## 给人看的顺序：成对的两场（换对手、换一件）错开放
const ORDER: Array[String] = ["crush_win", "counter_a", "swap_a", "clear_loss", "close_call", "counter_b", "stamina_short", "swap_b", "aftermath"]


func run() -> void:
	var split := split_args(OS.get_cmdline_user_args())
	var pos: Array[String] = split["pos"]
	var opts: Dictionary = split["opts"]
	var dir: String = pos[0] if pos.size() > 0 else DEFAULT_DIR
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		print("建不了 " + dir)
		finish(1)
		return
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var ctx := {"items": items, "enemies": enemies, "sets": sets}
	var all := FeelScenarios.build(ctx)
	all.append(FeelScenarios.aftermath(ctx, dir.path_join("_run")))
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return ORDER.find(String(a["id"])) < ORDER.find(String(b["id"])))
	var rows: Array = []
	var missing := 0
	for i in all.size():
		var sc: Dictionary = all[i]
		var row := {}
		for k in sc:
			if not (sc[k] is Object) and k != "specs" and k != "content":
				row[k] = sc[k]
		if not bool(sc["found"]):
			missing += 1
			print("没找到：%s（%s）" % [sc["id"], sc.get("why", "")])
			rows.append(row)
			continue
		var pack: BattleDiagPack = sc["pack"]
		pack.meta["scenario"] = sc["id"]
		row["code"] = "S%d" % (rows.filter(func(x: Dictionary) -> bool: return x.has("code")).size() + 1)     # 给人看的代号：不带场景名，免得暗示答案
		var path := BattleDiagnostics.write(pack, String(row["code"]), dir, 1 << 20)     # 文件名也用代号
		row["pack_file"] = path.get_file()
		if not opts.has("no-replays"):
			row["replay"] = _replay(sc, String(row["code"]), i, items)
		rows.append(row)
		var f: Dictionary = sc["facts"]
		print("%-14s %s，%.1f 秒，余血 %s / %s → %s" % [sc["id"], f["outcome"], float(f["duration"]), _pct(f["hp_end"][0]), _pct(f["hp_end"][1]), path])
	BattleTraceWriter.flush()
	var doc := ExperimentManifest.stamp({"made": Time.get_datetime_string_from_system(true) + "Z", "limit": FeelScenarios.LIMIT, "scenarios": rows},
		ExperimentManifest.SYNTHETIC)
	var ok := store_text(dir.path_join("scenarios.json"), JSON.stringify(doc, "  ", true) + "\n") and store_text(dir.path_join("questions.md"), FeelScenarios.questions(rows))
	if not ok:
		print("写不了 scenarios.json / questions.md")
		finish(1)
		return
	print("写入 %s（%d 个场景，%d 个没找到）" % [dir, rows.size(), missing])
	finish(2 if missing > 0 else 0)


## 用包里的输入再打一遍、带上追踪，写一份回放存档。返回文件主干（没写返回空）
func _replay(sc: Dictionary, code: String, i: int, items: ItemDatabase) -> String:
	var pack: BattleDiagPack = sc["pack"]
	var specs: Array = sc.get("specs", pack.specs())
	var rng := RandomNumberGenerator.new()
	rng.seed = pack.rng_seed
	rng.state = pack.rng_state
	var trace := BattleTrace.new()
	var result := BattleSim.run(specs[0], specs[1], rng, pack.time_limit, pack.overtime, trace)
	var boards: Array = []
	for s in specs:
		var spec := s as CombatantSpec
		boards.append(spec.board.to_dict() if spec.board != null else {})
	var info := {"chapter": "feel:%s" % code, "node": i, "enemy": String(sc.get("enemy", "")), "rng_seed": pack.rng_seed,
		"time_limit": pack.time_limit, "names": [CombatantSpec.item_names(specs[0], items), CombatantSpec.item_names(specs[1], items)], "boards": boards}
	return BattleTraceWriter.write(trace, result, ExperimentManifest.stamp(info, ExperimentManifest.SYNTHETIC)).get_file()


static func _pct(v: Variant) -> String:
	return "—" if v == null else "%.0f%%" % (float(v) * 100.0)

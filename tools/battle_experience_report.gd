## 平衡检测方案（2026-11-10）§8.2：一场战斗的体验诊断报告。读诊断包重跑，配上同一个战斗标识的观看记录，写五节（[BattleExperience]）。
##
##     godot --headless --path . --script res://tools/battle_experience_report.gd -- <包.diag.tres> [--viewing=<.viewing.json>]
##         [--viewing-dir=user://diagnostics/viewing] [--seeds=40] [--no-factors] [--out=<报告.md>] [--json=<报告.json>]
##
## 观看记录没给就按包里的战斗标识去目录里找；找不到就在未知项里写明。退出码：0 写出了；1 用法或读写错误；3 包读不出来
extends CliTool


func run() -> void:
	var split := split_args(OS.get_cmdline_user_args())
	var pos: Array[String] = split["pos"]
	var opts: Dictionary = split["opts"]
	if pos.is_empty():
		print("用法：battle_experience_report.gd -- <包.diag.tres> [--viewing=…] [--seeds=40] [--no-factors] [--out=…] [--json=…]")
		finish(1)
		return
	var pack := BattleDiagnostics.load_pack(pos[0])
	if pack == null or not pack.problems().is_empty():
		print("读不出诊断包：%s %s" % [pos[0], str(pack.problems()) if pack != null else ""])
		finish(3)
		return
	var battle_id := String(pack.meta.get("battle_id", ""))
	var viewing := _viewing(opts, battle_id)
	var result := pack.rerun()
	var same: Variant = null
	if not pack.expected.is_empty():
		same = BattleDiagPack.compare(pack.expected, BattleDiagPack.summary(result)).is_empty()
	var specs := pack.specs()
	var factors: Array = []
	if not opts.has("no-factors"):
		factors = BattleExperience.factor_rows(specs[0], specs[1], pack.time_limit, pack.overtime, pack.rng_seed, int(opts.get("seeds", BattleFactor.SEEDS)))
	var r := BattleExperience.analyze(result, specs, pack.time_limit, viewing, factors, same)
	if r["battle_id"] == "":
		r["battle_id"] = battle_id
	var md := BattleExperience.markdown(r)
	print(md)
	for key in ["out", "json"]:
		if not opts.has(key):
			continue
		if not write_text(String(opts[key]), md if key == "out" else JSON.stringify(r, "  ", true) + "\n"):
			return
	finish(0)


## 按参数读观看记录；没给就在目录里找文件名带这个战斗标识的最新一份
func _viewing(opts: Dictionary, battle_id: String) -> Dictionary:
	var path := String(opts.get("viewing", ""))
	if path == "" and battle_id != "":
		var dir := String(opts.get("viewing-dir", BattleDiagnostics.VIEWING))
		var tag := BattleDiagnostics._safe(battle_id)
		for f in BattleDiagnostics.list(dir, BattleDiagnostics.VIEWING_EXT):
			if f.contains(tag):
				path = dir.path_join(f)
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

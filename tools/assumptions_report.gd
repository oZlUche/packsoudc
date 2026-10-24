## 系数假设实测表（245）：读真实对局量出来的 `assumptions.jsonl`（[AssumptionStats]），按系数列「现在的值 / 实测中位数 / 四分位 / 场数」，另给一张按段位的小表。
##
##     godot --headless --path . --script res://tools/assumptions_report.gd -- [jsonl=user://calibration/assumptions.jsonl] [输出=docs/reports/balance/<日期>-assumptions.md]
##
## 别人导出的数据包解开后，几份 jsonl 首尾接起来就能一起读。只打印，不写回 power_weights.json
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else AssumptionStats.PATH
	var date := Time.get_date_string_from_system()
	var out_path: String = args[1] if args.size() > 1 else "%s/%s-assumptions.md" % [BalanceMatrix.OUT_DIR, date]
	var rows := AssumptionStats.read_rows(path)
	if rows.is_empty():
		print("没有数据（%s）：先在游戏里打几场，或把导出的 calibration/assumptions.jsonl 路径传进来" % path)
		finish(1)
		return
	var versions := {}
	for r in rows:
		versions[String(r.get("version", ""))] = true
	var header: Array[String] = [
		"日期 %s" % date,
		"数据 `%s`（%d 场，版本 %s）" % [path, rows.size(), ", ".join(PackedStringArray(versions.keys()))],
		"现在的值读 `%s`" % PowerWeights.PATH,
	]
	var md := AssumptionStats.markdown(rows, PowerWeights.load_from(), "系数假设实测 %s" % date, header)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		print("写不了 " + out_path)
		finish(1)
		return
	f.store_string(md)
	f.close()
	print(md)
	print("写入 %s" % out_path)
	finish(0)

## 平衡检测方案（2026-11-10）§4.2：校准数据审计（[DataAudit]）。只读输入，写 `audit.json` 和 `audit.md`。
##
##     godot --headless --path . --script res://tools/audit_balance_data.gd -- [目录=user://calibration] [输出目录=同输入目录]
##         [--build=<构建>] [--chapter=<章节>] [--character=<角色>] [--source=<来源>] [--allow-mixed] [--strict]
##
## 目录里找 snapshots.jsonl / runs.jsonl / assumptions.jsonl（导出包解开后的 calibration 目录也一样）。
## 退出码：0 通过（警告写在报告里）；1 用法或读写错误；2 加了 --strict 且有严重问题（坏行、未知格式、同标识不同内容、版本混合且没加 --allow-mixed）。
## 工具自己崩了也是 2，这时不会写出 audit.json —— 看有没有这个文件就分得开
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := {}
	var paths: Array[String] = []
	for a in args:
		if a == "--allow-mixed":
			opts["allow_mixed"] = true
		elif a == "--strict":
			opts["strict"] = true
		elif a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			if not ["build", "chapter", "character", "source"].has(kv[0]):
				printerr("不认识的参数：", a)
				finish(DataAudit.EXIT_USAGE)
				return
			opts[kv[0]] = kv[1]
		elif a.begins_with("--"):
			printerr("不认识的参数：", a)
			finish(DataAudit.EXIT_USAGE)
			return
		else:
			paths.append(a)
	var dir: String = paths[0] if paths.size() > 0 else CalibrationRecorder.DIR
	var out_dir: String = paths[1] if paths.size() > 1 else dir
	if not DirAccess.dir_exists_absolute(dir):
		printerr("没有这个目录：", dir)
		finish(DataAudit.EXIT_USAGE)
		return
	var items := ItemDatabase.new()
	items.load_dir()
	var result := DataAudit.run(dir, opts, items)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var md := DataAudit.markdown(result)
	if not _write(out_dir.path_join("audit.json"), JSON.stringify(result, "  ", true)) or not _write(out_dir.path_join("audit.md"), md):
		finish(DataAudit.EXIT_USAGE)
		return
	print(md)
	finish(int(result["exit_code"]))


func _write(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("写不了：", path)
		return false
	f.store_string(text)
	f.close()
	return true

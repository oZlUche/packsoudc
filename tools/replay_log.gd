## 把一场战斗的内部日志（`.jsonl`，117）按 `.txt` 的格式打到标准输出 —— 给 AI 线程在没有窗口的环境里读日志用。
##
##     godot --headless --path . --script res://tools/replay_log.gd -- <file.jsonl> [--summary]
##     godot --headless --path . --script res://tools/replay_log.gd -- --latest [--summary]
##
## `--summary` 只打双方总伤害、每件道具出手 / 跳过次数、暴击率、buff 总层数。
## `--latest` 读 user://battle_logs 里最新的一场。文件不存在或一行都读不出来退出码 1
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var summary := args.has("--summary")
	var path := ""
	for a in args:
		if not String(a).begins_with("--"):
			path = String(a)
	if args.has("--latest"):
		var all := BattleArchive.stems()
		if all.is_empty():
			printerr("user://battle_logs 里没有日志")
			finish(1)
			return
		path = BattleArchive.DIR.path_join(all[-1] + BattleArchive.TRACE_EXT)
	if path == "" or not FileAccess.file_exists(path):
		printerr("用法：--script res://tools/replay_log.gd -- <file.jsonl | --latest> [--summary]（找不到「%s」）" % path)
		finish(1)
		return
	var parsed := BattleTrace.parse_jsonl(FileAccess.get_file_as_string(path))
	var entries: Array = parsed["entries"]
	if entries.is_empty() and (parsed["header"] as Dictionary).is_empty():
		printerr("「%s」里一行都读不出来" % path)
		finish(1)
		return
	var lines := BattleTrace.summarize(parsed["header"], entries) if summary else BattleTrace.format_lines(parsed["header"], entries)
	for line in lines:
		print(line)
	if int(parsed["bad"]) > 0:
		printerr("（跳过了 %d 行坏行）" % int(parsed["bad"]))
	finish(0)

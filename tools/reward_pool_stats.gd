## 主题奖励池抽样统计（事件方案 2026-11-11 §8.4）：池 × 章节 × 深度 × 难度，理论概率与固定种子实抽对照。
##
##     godot --headless --path . --script res://tools/reward_pool_stats.gd -- [--n=10000] [--out=路径.md]
##
## 有空格（没有合格候选）或偏离理论概率的行就退出 1
extends CliTool

const CHAPTERS := ["free_mode", "clockwork_hourglass"]


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var n := int(opts.get("n", "10000"))
	var items := ItemDatabase.new()
	items.load_dir()
	var rows := RewardPoolStats.table(RewardPool.load_all(), items, CHAPTERS, n)
	var md := RewardPoolStats.markdown(rows, n)
	var out := String(opts.get("out", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			print("写不了 %s" % out)
			finish(1)
			return
		f.store_string(md)
		f.close()
		print("写好了 %s（%d 格）" % [out, rows.size()])
	else:
		print(md)
	var bad := RewardPoolStats.problems(rows)
	for line in bad:
		print("!! " + line)
	finish(1 if not bad.is_empty() else 0)

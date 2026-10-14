## 173 §3.4：本机存档检查（只读）—— 对 `user://slots/*` 的每一位跑一遍读档 + 内容对账，打印修复报告，**不写任何文件**。
## 合并前跑一下就知道这次更新会不会动到自己的档。`bash tools/check_saves.sh`（或 `-- <目录>` 换一个根目录）
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var root := String(args[0]) if not args.is_empty() else SaveSlots.DEFAULT_ROOT
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var rules := GameFlow.load_meta_rules()
	var techs := GameFlow.load_techs()
	var slots := SaveSlots.new(root)
	var bad := 0
	print("内容版本：%s　根目录：%s" % [ContentPaths.content_stamp(), root])
	for n in range(1, SaveSlots.COUNT + 1):
		if not slots.exists(n):
			continue
		for which in ["meta", "run"]:
			var path := slots.meta_path(n) if which == "meta" else slots.run_path(n)
			if not AtomicFile.exists(path):
				continue
			var report := SaveReport.new()
			var ok: bool
			if which == "meta":
				ok = MetaSave.read(items, path, rules, techs, report) != null
			else:
				ok = RunSave.read(items, enemies, null, path, report) != null
			var line := "第 %d 位 %s：" % [n, which]
			if not ok:
				bad += 1
				line += "读不回来" + ("（作废，可捞回 %d 件）" % report.salvage.size() if which == "run" else "（会备份后从零开始）")
			elif report.is_empty():
				line += "原样读回"
			else:
				line += report.summary()
			if report.stamp_saved != "" and report.stamp_saved != report.stamp_now:
				line += "　（存于内容版本 %s）" % report.stamp_saved
			print(line)
			for row in report.refunded + report.rehomed + report.replaced + report.dropped:
				print("    ", JSON.stringify(row))
	finish(1 if bad > 0 else 0)

## 173 §3.3：重生成内容快照 `tests/fixtures/content_snapshot.json`。先跑一遍检查：有没交代的改动就不写、列出来、退出码 1 ——
## 补完 [IdAliases] 的表再跑。`bash tools/snapshot_content.sh`
extends CliTool


func run() -> void:
	var now := ContentSnapshot.capture()
	var old := ContentSnapshot.load_frozen()
	var issues := ContentSnapshot.problems(old, now) if not old.is_empty() else ([] as Array[String])
	if not issues.is_empty():
		for line in issues:
			print("✗ " + line)
		print("快照没更新：先补表")
		finish(1)
		return
	var f := FileAccess.open(ContentSnapshot.PATH, FileAccess.WRITE)
	if f == null:
		print("写不了 %s" % ContentSnapshot.PATH)
		finish(1)
		return
	f.store_string(ContentSnapshot.to_text(now))
	f.close()
	print("快照已更新：%d 件道具" % (now["items"] as Dictionary).size())
	finish(0)

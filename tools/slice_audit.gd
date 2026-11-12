## 试玩切片清单核对（报告 313）：清单和章节、地图、配方、敌人、事件对不对得上，再按种子整局走，见过的道具都得在清单里。
##
##     godot --headless --path . --script res://tools/slice_audit.gd -- [--manifest=slice_ruins] [--seeds=20]
##
## 没问题退出码 0；有问题逐条打出来，退出码 1
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var id := String(opts.get("manifest", "slice_ruins"))
	var m := SliceAudit.load_manifest(id)
	if m.is_empty():
		printerr("读不出清单 %s/%s.json" % [SliceAudit.DIR, id])
		finish(1)
		return
	var r := SliceAudit.run_all(m, int(opts.get("seeds", "20")))
	print("见过的道具：%s" % ", ".join(r["seen"]))
	for line in r["problems"]:
		print("✗ " + String(line))
	print("清单 %s：%d 条问题" % [id, (r["problems"] as Array).size()])
	finish(0 if (r["problems"] as Array).is_empty() else 1)

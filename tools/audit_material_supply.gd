## 材料供给审计（303 第 2 步，材料方案 2026-11-11 §6.1）：每张铁匠铺配方每一格顶得上的道具、来源与可达性。
##
##     godot --headless --path . --script res://tools/audit_material_supply.gd -- [--out=路径.md] [--json=路径.json]
##
## 有 no_item / no_source 的格就退出 1
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var result := MaterialSupplyAudit.audit(items, enemies)
	var md := MaterialSupplyAudit.markdown(result, items)
	var out := String(opts.get("out", ""))
	if out != "":
		_write(out, md)
	else:
		print(md)
	var js := String(opts.get("json", ""))
	if js != "":
		_write(js, JSON.stringify(result["slots"], "  "))
	var c := MaterialSupplyAudit.counts(result)
	print("格：%s" % c)
	finish(1 if int(c[MaterialSupplyAudit.NO_ITEM]) + int(c[MaterialSupplyAudit.NO_SOURCE]) > 0 else 0)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("写不了 %s" % path)
		return
	f.store_string(text)
	f.close()
	print("写好了 %s" % path)

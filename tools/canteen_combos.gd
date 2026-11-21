## 355：灰灯食堂强力搭配记录（只读，[CanteenAudit]）—— 每加一种食材重跑一次，结果抄进落地报告。
##
##     godot --headless --path . --script res://tools/canteen_combos.gd -- <输出.md>
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://canteen_combos.md"
	var items := ItemDatabase.new()
	items.load_dir()
	var chars: Array = ContentPaths.load_typed(ContentPaths.CHARACTERS, CharacterDef)
	var text := CanteenAudit.report(items, chars)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print(text)
	finish()

## 试玩切片对打表（报告 312）：切片地图上每一场仗 × 四种玩家配置，各打 N 个种子。只打印，不改数
##
##     godot --headless --path . --script res://tools/slice_bench.gd -- [--seeds=20] [--map=res://data/maps/slice_ruins.json] [--out=路径.md]
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var ch := ContentPaths.load_asset("characters", "andreus") as CharacterDef
	var md := SliceBench.markdown(String(opts.get("map", "res://data/maps/slice_ruins.json")), ch, items, enemies, int(opts.get("seeds", "20")))
	var out := String(opts.get("out", ""))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		if not write_text(out, md):
			return
		print("写好了 " + out)
	else:
		print(md)
	finish(0)

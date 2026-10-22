## 流派木桩（242 §8.1 ①）：五路流派 × 段位，每路每段三个种子，写成木桩文件给 bench_matrix / bench_hunters 吃。
##
##     godot --headless --path . --script res://tools/build_archetypes.gd -- [池=standard_ruins] [难度=ascension_3（取它的段位表）] [输出=res://data/authoring/calibration/archetypes.json]
##
## 不占 dummies.json（那是真实木桩的位置，作者打十局后 build_dummies 生成）
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var pool_id: String = args[0] if args.size() > 0 else "standard_ruins"
	var difficulty_id: String = args[1] if args.size() > 1 else "ascension_3"
	var out_path: String = args[2] if args.size() > 2 else ArchetypeBuilder.DEFAULT_PATH
	var items := ItemDatabase.new()
	items.load_dir()
	var pool := ContentPaths.load_asset("enemy_pools", pool_id) as EnemyPool
	if pool == null:
		print("没有敌人池 %s" % pool_id)
		finish(1)
		return
	var brackets := BalanceMatrix.brackets_of(difficulty_id)
	var character := ContentPaths.load_asset("characters", String(ArchetypeBuilder.CHARACTER)) as CharacterDef
	var dummies := ArchetypeBuilder.build(pool, items, brackets, character)
	if DummyBuilder.save(dummies, out_path) != OK:
		print("写不了 " + out_path)
		finish(1)
		return
	print("段位表（难度 %s）：%s" % [difficulty_id, str(brackets)])
	for key in dummies:
		var d: Dictionary = dummies[key]
		var left: Array = d["left"]
		print("%-12s 档 %d　%d 件　生命 %.0f　DPS %.1f%s" % [key, int(d["tier"]), (d["picked"] as Array).size(), float(d["hp"]), float(d["dps"]),
			("　放不下：" + ", ".join(left)) if not left.is_empty() else ""])
	print("写入 %s（%d 份）" % [out_path, dummies.size()])
	finish(0)

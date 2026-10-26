## 流派木桩（242 §8.1 ①）：五路流派 × 段位，每路每段三个种子（另有兵刃与它的三个变体，[method ArchetypeBuilder.build_variants]），写成木桩文件给 bench_matrix / bench_hunters 吃。
##
##     godot --headless --path . --script res://tools/build_archetypes.gd -- [池=standard_ruins] [难度=ascension_3（取它的段位表）] [输出=res://data/authoring/calibration/archetypes.json] [--variants]
##
## `--variants`：只重造兵刃四路，输出文件里的五路原样留着（道具库改过之后，五路要和旧表逐格对得上时用）
##
## 不占 dummies.json（那是真实木桩的位置，作者打十局后 build_dummies 生成）
extends CliTool


func run() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var only_variants := args.has("--variants")
	args.erase("--variants")
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
	var sun := ContentPaths.load_asset("faiths", String(ArchetypeBuilder.SUN)) as FaithDef
	var variants := ArchetypeBuilder.build_variants(pool, items, brackets, character, sun)     # 兵刃 + 三个变体
	var dummies := {}
	if only_variants:
		var text := _splice(out_path, variants)
		var f := FileAccess.open(out_path, FileAccess.WRITE) if text != "" else null
		if f == null:
			print("写不了 " + out_path)
			finish(1)
			return
		f.store_string(text)
		f.close()
		dummies = variants
	else:
		dummies = ArchetypeBuilder.build(pool, items, brackets, character)
		dummies.merge(variants)
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


## 五路那一段原文照留（读回来再写会把整数写成 0.0），旧的兵刃四路（总在文件末尾）剪掉，新的接在后面
static func _splice(path: String, variants: Dictionary) -> String:
	var old := DummyBuilder.load_file(path)
	if old.is_empty():
		return ""
	var text := FileAccess.get_file_as_string(path).strip_edges()
	var keep := text.trim_suffix("}").strip_edges(false, true)
	for key in old:
		if String((old[key] as Dictionary).get("group", "")) != "":
			keep = text.substr(0, text.find("\n  \"%s\": " % key)).trim_suffix(",")
			break
	var extra := JSON.stringify(variants, "  ", false).strip_edges()
	return keep + ",\n" + extra.substr(2) + "\n"

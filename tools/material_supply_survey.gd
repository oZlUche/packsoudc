## 材料供给复测（报告 303，材料与难度方案 §7.2 M1 / M2）：两张图各开 N 局，每个搜索点按正式会话搜满，数配方材质格的材料。
##
##     godot --headless --path . --script res://tools/material_supply_survey.gd -- [--n=100] [--out=路径.md]
##
## 变体：没有三件新材料（对照）、M1 现状、M2 材料节点里材料份额 ×1.25 / ×1.5（上限 1）。只打印，不改数
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var n := int(opts.get("n", "100"))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var seeds: Array = []
	for i in n:
		seeds.append(i + 1)
	var slot_list := MaterialSupplySurvey.slots(SmithRecipeDef.load_all())
	var variants := {
		"无新材料": {"hide": MaterialSupplySurvey.NEW_MATERIALS},
		"M1 现状": {},
		"M2 材料份额 ×1.25": {"kind_share": 1.25},
		"M2 材料份额 ×1.5": {"kind_share": 1.5},
	}
	var names: Array = variants.keys()
	var md := "# 材料供给复测（地图机会层）\n\n每章种子 1..%d；每个生成时就是搜索点的点都按正式会话搜满、不遭遇（遭遇照样掷随机数）。是供给上限，不是玩家真拿得到的量；宝箱、掉落、商店、事件不在内。\n\n" % n
	var started := Time.get_ticks_msec()
	for ch_id in MaterialSupplySurvey.CHAPTERS:
		var ch := ContentPaths.load_asset("chapters", String(ch_id)) as ChapterDef
		var runs := {}
		for v in names:
			runs[v] = MaterialSupplySurvey.survey(ch, items, enemies, seeds, slot_list, variants[v])
		md += MaterialSupplySurvey.markdown(String(ch_id), runs, names) + "\n"
	md += "共用 %.0f 秒。\n" % ((Time.get_ticks_msec() - started) / 1000.0)
	var out := String(opts.get("out", ""))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		if not write_text(out, md):
			return
		print("写好了 " + out)
	else:
		print(md)
	finish(0)

## 342 B3：材料倾向的配对试验（[MaterialBiasTrial]）：两章各开 N 张图，每个方向比较无倾向、×1.25、×1.5。
##
##     godot --headless --path . --script res://tools/material_bias_trial.gd -- [--n=60] [--out=路径.md]
##
## 只打印，不改数
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var n := int(opts.get("n", "60"))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var seeds: Array = []
	for i in n:
		seeds.append(i + 1)
	var md := "# 材料倾向配对试验\n\n每章种子 1..%d；每个生成时就是搜索点的点都按正式会话搜满、不遭遇。是供给上限，不是玩家真拿得到的量。\n\n" % n
	var started := Time.get_ticks_msec()
	for ch_id in MaterialBiasTrial.CHAPTERS:
		var ch := ContentPaths.load_asset("chapters", String(ch_id)) as ChapterDef
		md += MaterialBiasTrial.markdown(String(ch_id), MaterialBiasTrial.trial(ch, items, enemies, seeds)) + "\n"
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

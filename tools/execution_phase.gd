## 难度候选 D4（报告 303）：处决武器按对手的生命阶段看（[ExecutionPhase]）。只出表，不改数。
##
##     godot --headless --path . --script res://tools/execution_phase.gd -- [--fights=50] [--seed=1] [--pool=standard_ruins] [--out=路径.md]
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var pool_id := String(opts.get("pool", "standard_ruins"))
	var fights := int(opts.get("fights", "50"))
	var seed_ := int(opts.get("seed", "1"))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var rules := ContentPaths.load_asset("node_rules", "standard") as NodeRules
	var ctx := {"pool": ContentPaths.load_asset("enemy_pools", pool_id) as EnemyPool, "enemies": enemies, "items": items,
		"fights": fights, "seed": seed_, "time_limit": rules.battle_time_limit, "overtime": rules.overtime}
	var started := Time.get_ticks_msec()
	var rows := ExecutionPhase.run(ctx)
	var dps := ExecutionPhase.dummy_dps(items)
	var header: Array[String] = ["日期 %s；`%s` 单独一件，玩家基础 %s（生命打不死）；敌人池 `%s` 每种敌人每档 %d 场，种子 %d；共用 %.0f 秒。" % [
		Time.get_date_string_from_system(), ExecutionPhase.WEAPON, JSON.stringify(ExecutionPhase.BASELINE), pool_id, fights, seed_,
		(Time.get_ticks_msec() - started) / 1000.0]]
	var md := ExecutionPhase.markdown(rows, dps, header)
	var out := String(opts.get("out", ""))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		if not write_text(out, md):
			return
		print("写好了 " + out)
	else:
		print(md)
	finish(0)

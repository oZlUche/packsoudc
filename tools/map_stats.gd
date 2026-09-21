## 批量跑环形生成器，看成功率与重试次数的分布。
##
##     godot --headless --path . --script res://tools/map_stats.gd -- [种子数=64] [环数...=4 5 6]
##
## 重试次数一高，说明配置与校验在打架 —— 该改配置，不是调高上限。
## `failure_tally` 汇总会指出是哪条规则在咬。
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 64
	var rings: Array[int] = []
	for i in range(1, args.size()):
		rings.append(int(args[i]))
	if rings.is_empty():
		rings = [4, 5, 6] as Array[int]

	print("环数 | 成功 | 平均尝试 | 最多 | 有高危区 | 失败规则（累计）")
	for ring_count in rings:
		var cfg := RingMapConfig.sample(ring_count)
		var made := 0
		var total := 0
		var worst := 0
		var zoned := 0
		var tally := {}
		for s in seeds:
			var gen := RingMapGenerator.new()
			var g := gen.generate(cfg, s)
			total += gen.attempts_used
			worst = maxi(worst, gen.attempts_used)
			for rule in gen.failure_tally:
				tally[rule] = int(tally.get(rule, 0)) + int(gen.failure_tally[rule])
			if g != null:
				made += 1
				if not g.zones.is_empty():
					zoned += 1
		print("%4d | %d/%d | %8.2f | %4d | %8d | %s"
			% [ring_count, made, seeds, float(total) / float(seeds), worst, zoned, str(tally)])
	finish(0)

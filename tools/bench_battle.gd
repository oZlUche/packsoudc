## 批量战斗基准。做数值平衡时要跑成千上万场，这里量的是单场成本。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/bench_battle.gd
extends SceneTree

const BATTLES := 2000


func _initialize() -> void:
	var a := _build(80.0, 9.0, 0.7, 3)
	var b := _build(80.0, 7.0, 0.5, 4)

	# 预热，避开首次脚本编译
	for i in 50:
		var warm := RandomNumberGenerator.new()
		warm.seed = i
		BattleSim.run(a, b, warm)

	var started := Time.get_ticks_usec()
	var total_events := 0
	for i in BATTLES:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		total_events += BattleSim.run(a, b, rng).log.size()
	var elapsed := Time.get_ticks_usec() - started

	print("%d 场：%.1f ms，单场 %.3f ms，平均 %.1f 条事件" % [
		BATTLES, elapsed / 1000.0, elapsed / 1000.0 / BATTLES,
		float(total_events) / BATTLES,
	])
	quit(0)


func _build(hp: float, dmg: float, cd: float, rule_count: int) -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.max_hp = StatMath.from_float(hp)
	for i in rule_count:
		var it := CompiledItem.new()
		it.source_uid = i + 1
		it.def_id = StringName("w%d" % i)
		it.stats = StatSet.new()
		it.stats.set_base(BattleStats.DAMAGE, StatMath.from_float(dmg))
		it.stats.set_base(BattleStats.HASTE, StatMath.ONE)

		var rule := AbilityRule.new()
		rule.trigger = OnSchedule.new()
		var cad := CooldownCadence.new()
		cad.seconds = cd + i * 0.13
		rule.cadence = cad
		rule.effects = [DealDamage.new()] as Array[Effect]
		it.rules = [rule] as Array[AbilityRule]
		spec.add(it)
	return spec

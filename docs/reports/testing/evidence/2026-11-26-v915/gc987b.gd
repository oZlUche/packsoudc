extends SceneTree
## 测试 v9.15 补充：收式在不断连击时每 10 秒按清零结算一次（自配连击机制，不耗耐力）
const T := preload("res://tests/battle/test_faith_skill.gd")
func _pure(br: BattleResult) -> Array:
	var out := []
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and bool(e.payload.get("pure", false)): out.append("%.1fs %d" % [StatMath.to_float(e.time), e.get_int(&"raw") / 10000])
	return out
func _init() -> void:
	for secs in [40.0]:
		var rng := RandomNumberGenerator.new(); rng.seed = 1
		var a := BattleSim.run(T._me({"clumsy_pct": 50.0}), T._dummy(), rng, secs)
		rng.seed = 1
		var b := BattleSim.run(T._me({"clumsy_pct": 50.0, "finish_sec": 10.0}), T._dummy(), rng, secs)
		print("GC987B 不断连击 40 秒：只有大巧若拙 真实伤害 %d 下；加收式 %d 下 %s；最高连击 %d / %d" % [_pure(a).size(), _pure(b).size(), str(_pure(b)), int(T._combo(a)[0]), int(T._combo(b)[0])])
	quit(0)

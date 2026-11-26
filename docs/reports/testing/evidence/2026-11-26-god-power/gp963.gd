extends SceneTree
## 神牌贡献对照（报告 396 第四节建议 4）：四位神 × 普通 / 稀有 / 传说装备，加无信者传说一组。
## 每局从 1 级升到 30 级（随机挑牌或偏神牌），在 6 / 12 / 18 / 24 / 30 级各打几场真敌人。
## 同一场打三遍：A 全开；B 去掉这位神（不奉神、拿掉神牌）；C 只拿掉神牌（核心留着）。
## 贡献 = 1 - B / A（每秒造成的伤害；每秒挡下或回复的伤害）
const G := preload("res://tests/run/test_god_cards_388.gd")
const CHECKS: Array[int] = [6, 12, 18, 24, 30]
const TIER_AT := {6: 0, 12: 1, 18: 2, 24: 3, 30: 3}
var RUNS := 8
var FIGHTS := 3
var POLICY := "random"
var GROUPS: Array = [[&"brute", 0], [&"brute", 2], [&"brute", 4], [&"sun", 0], [&"sun", 2], [&"sun", 4],
	[&"nature", 0], [&"nature", 2], [&"nature", 4], [&"skill", 0], [&"skill", 2], [&"skill", 4], [&"", 4]]
var LOO := true
var DBG := 0

var pool: EnemyPool
var enemies: EnemyDatabase
var limit := 30.0
var overtime: OvertimeRules = null
var gear := {}     # "weapon_2" → [ids]

func _gear(items: ItemDatabase) -> void:
	for id in items.all_ids():
		var d := items.get_def(id)
		if d.is_blessed() or d.is_anchor(): continue
		for t in [&"weapon", &"armor", &"shield"]:
			if d.tags.has(t):
				gear.get_or_add("%s_%d" % [t, d.rarity], []).append(id)

func _kit(run: RunState, rar: int, rng: RandomNumberGenerator) -> Array:
	var placed := []
	for bag in [&"war_pack", &"bag_leather", &"bag_leather"]:
		if TestSupport.put(run.board, run.items.get_def(bag)) == null: print("GP963 放不下包 ", bag)
	var plan := [["weapon", rar, 2], ["armor", clampi(rar, 1, 3), 1], ["shield", clampi(rar, 1, 3), 1]]
	for p in plan:
		var ids: Array = gear.get("%s_%d" % [p[0], p[1]], []).duplicate()
		var got := 0
		var tries := 0
		while got < int(p[2]) and tries < 40 and not ids.is_empty():
			tries += 1
			var id: StringName = ids[rng.randi() % ids.size()]
			if TestSupport.put(run.board, run.items.get_def(id)) != null:
				placed.append(String(id)); got += 1; ids.erase(id)
	return placed

func _is_god(lv: LevelModule, cid: String) -> bool:
	return String(lv.rules().card(StringName(cid)).get("kind", "")) == "god"

func _level_to(lv: LevelModule, target: int, rng: RandomNumberGenerator) -> void:
	var guard := 0
	while lv.level() < target and guard < 200:
		guard += 1
		lv.gain(5.0, LevelModule.SRC_EVENT, "test")
	guard = 0
	while lv.pending() > 0 and guard < 100:
		guard += 1
		var cards := lv.offer()
		if cards.is_empty(): break
		var i := rng.randi() % cards.size()
		if POLICY == "god":
			var gi := []
			for j in cards.size():
				if _is_god(lv, String(cards[j])): gi.append(j)
			if not gi.is_empty(): i = gi[rng.randi() % gi.size()]
		lv.pick(i)

## mode: "A" 全开；"B" 去掉这位神；"C" 只拿掉神牌；"-<cid>" 只拿掉这一张
func _spec(run: RunState, mode: String) -> CombatantSpec:
	var lv := LevelModule.of(run)
	var keep_taken := lv.taken.duplicate()
	var keep_faith := run.selected_faith
	if mode == "B" or mode == "C":
		for k in keep_taken.keys():
			if _is_god(lv, String(k)): lv.taken.erase(k)
	elif mode.begins_with("-"):
		lv.taken.erase(mode.substr(1))
	if mode == "B":
		run.selected_faith = &""
	var spec := run.compile_player()
	lv.taken = keep_taken
	run.selected_faith = keep_faith
	return spec

func _enemy(run: RunState, strength: int, rng: RandomNumberGenerator) -> CombatantSpec:
	var node := MapNode.new(); node.id = 0; node.type = &"battle"
	for _t in 20:
		var entry := EnemyPlacer.pick(pool, enemies, node, strength, rng)
		if entry == null: continue
		var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, run.items, strength, rng).get("content", {})
		var e := EnemyKit.spec_of(content, enemies, pool, run.items)
		if e != null: return e
	return null

## [dealt, mitigated, seconds, won]
func _fight(me: CombatantSpec, foe: CombatantSpec, seed_: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var res := BattleSim.run(me, foe, rng, limit, overtime)
	var dealt := 0.0; var mit := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE:
			if DBG > 0: DBG -= 1; print("GP963 DBG side %d %s" % [e.side, str(e.payload)])
			var applied := float(e.get_int(&"amount"))
			if e.side == 1:
				dealt += StatMath.to_float(int(applied + float(e.get_int(&"absorbed"))))
			elif e.side == 0:
				mit += maxf(0.0, StatMath.to_float(int(float(e.get_int(&"raw")) - applied)))
		elif e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.get_name(&"key")) == "hp":
			var why := String(e.get_name(&"reason"))
			if (why == "heal" or why == "regen") and e.get_int(&"delta") > 0:
				mit += StatMath.to_float(e.get_int(&"delta"))
	return [dealt, mit, maxf(0.5, res.duration_sec()), res.winner == 0, res]

func _share(a: float, b: float) -> float:
	return 0.0 if a <= 0.0001 else 1.0 - b / a

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for s in args:
		if s.begins_with("runs="): RUNS = int(s.substr(5))
		elif s.begins_with("fights="): FIGHTS = int(s.substr(7))
		elif s.begins_with("policy="): POLICY = s.substr(7)
		elif s.begins_with("groups="):
			GROUPS = []
			for g in s.substr(7).split(","):
				var p := g.split(":")
				GROUPS.append([StringName(p[0] if p[0] != "none" else ""), int(p[1])])
		elif s == "noloo": LOO = false
		elif s.begins_with("dbg="): DBG = int(s.substr(4))
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var rules := ContentPaths.load_asset("node_rules", "standard") as NodeRules
	if rules != null:
		limit = rules.battle_time_limit; overtime = rules.overtime
	var t0 := Time.get_ticks_msec()
	print("GP963 策略 %s；每组 %d 局；每个检查点 %d 场；时限 %.0f 秒" % [POLICY, RUNS, FIGHTS, limit])
	for grp in GROUPS:
		var god: StringName = grp[0]; var rar: int = grp[1]
		for r in RUNS:
			var seed_ := hash("%s:%d:%d:%s" % [god, rar, r, POLICY]) & 0x7fffffff
			var run := G._start(seed_ % 100000 + 1, god)
			if run == null: continue
			var lv := LevelModule.of(run)
			var rng := RandomNumberGenerator.new(); rng.seed = seed_
			if run.vitality != null: pass
			if gear.is_empty(): _gear(run.items)
			var kit := _kit(run, rar, rng)
			var tot := {"A": [0.0, 0.0, 0.0], "B": [0.0, 0.0, 0.0], "C": [0.0, 0.0, 0.0]}
			var wins := 0; var n := 0
			for L in CHECKS:
				_level_to(lv, L, rng)
				var row := {"A": [0.0, 0.0, 0.0], "B": [0.0, 0.0, 0.0], "C": [0.0, 0.0, 0.0]}
				var loo_specs := {}
				var gcards := []
				for k in lv.taken.keys():
					if _is_god(lv, String(k)): gcards.append(String(k))
				var loo := {}
				for f in FIGHTS:
					var foe := _enemy(run, int(TIER_AT[L]), rng)
					if foe == null: continue
					var fs := rng.randi()
					var a := _fight(_spec(run, "A"), foe, fs)
					var b := _fight(_spec(run, "B"), foe, fs) if god != &"" else a
					var c := _fight(_spec(run, "C"), foe, fs) if god != &"" else a
					for pair in [["A", a], ["B", b], ["C", c]]:
						for i in 3:
							row[pair[0]][i] += float(pair[1][i]); tot[pair[0]][i] += float(pair[1][i])
					wins += 1 if a[3] else 0; n += 1
					if LOO and L == 30 and god != &"":
						for cid in gcards:
							var x := _fight(_spec(run, "-" + cid), foe, fs)
							var acc: Array = loo.get_or_add(cid, [0.0, 0.0, 0.0])
							for i in 3: acc[i] += float(x[i])
					lv._on_battle(null, a[4], false)
				var dA: float = row["A"][0] / row["A"][2]; var mA: float = row["A"][1] / row["A"][2]
				var dB: float = row["B"][0] / row["B"][2]; var mB: float = row["B"][1] / row["B"][2]
				var dC: float = row["C"][0] / row["C"][2]; var mC: float = row["C"][1] / row["C"][2]
				print("GP963 CP|%s|%d|%d|L%d|dps %.1f/%.1f/%.1f|mit %.1f/%.1f/%.1f|god_d %.3f|god_m %.3f|card_d %.3f|card_m %.3f|gcards %d" % [
					god, rar, r, L, dA, dB, dC, mA, mB, mC, _share(dA, dB), _share(mA, mB), _share(dA, dC), _share(mA, mC), gcards.size()])
				if not loo.is_empty():
					var parts := []
					for cid in loo:
						var acc: Array = loo[cid]
						parts.append("%s=%.3f/%.3f" % [cid, _share(dA, acc[0] / acc[2]), _share(mA, acc[1] / acc[2])])
					print("GP963 LOO|%s|%d|%d|%s" % [god, rar, r, ";".join(parts)])
			var DA: Array = tot["A"]; var DB: Array = tot["B"]; var DC: Array = tot["C"]
			print("GP963 RUN|%s|%d|%d|kit %s|wins %d/%d|dps %.1f|mit %.1f|god_d %.3f|god_m %.3f|card_d %.3f|card_m %.3f" % [
				god, rar, r, ",".join(kit), wins, n, DA[0] / DA[2], DA[1] / DA[2],
				_share(DA[0] / DA[2], DB[0] / DB[2]), _share(DA[1] / DA[2], DB[1] / DB[2]),
				_share(DA[0] / DA[2], DC[0] / DC[2]), _share(DA[1] / DA[2], DC[1] / DC[2])])
			run.dispose()
	print("GP963 完 %.0f 秒" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)

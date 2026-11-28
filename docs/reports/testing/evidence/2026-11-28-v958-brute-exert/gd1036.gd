extends SceneTree
## v9.58 蛮神【竭力】对照（由 gd1128 改，只多一套 brute_exert：开局质变先拿竭力，其余同 brute 少最后一张升级）。
## 原 gd1128 说明：神明成型后对道具的依赖（架构设计 11-28 请求，只测不改）。
## 30 级、按成型流派挑满质变牌和基础牌（真走 LevelModule 的选牌，每次把摆出来的牌换成清单里下一张能拿的），
## 背包四档：空包（只一把制式短剑）、普通、稀有、传说（两把武器 + 护甲 + 盾 + 三个包，同报告 2026-11-26 神明强度对照的放法）；
## 同一批敌人：标准遗迹地图上真放出来的普通（强度 2–3 档）、精英（2–3 档）、首领，A0 与 A8 各一批。
## 每格：几套背包种子 × 每类敌人几个。记胜率、用时、赢时剩余生命。参数：kits=4 foes=15 maps=24 builds=a,b
const G := preload("res://tests/run/test_god_cards_388.gd")
var KITS := 4
var FOES := 15
var MAPS := 24
var ONLY: Array = []
var gear := {}
var enemies: EnemyDatabase
var pool: EnemyPool
var limit := 30.0
var overtime: OvertimeRules = null

const GENERAL := ["card_weapon_damage", "card_weapon_haste", "card_hp_pct", "card_crit_chance", "card_crit_damage", "card_hp_flat",
	"card_regen", "card_stamina_pct", "card_weapon_cost", "card_stamina_flat"]

## 名字 → [神, 质变牌顺序, 基础牌顺序（可重复）]
func _builds() -> Dictionary:
	return {
		"sun_blaze": [&"sun", ["god_sun_blaze", "god_sun_sunbath", "god_sun_shift", "god_sun_blaze_up", "god_sun_sunbath_up", "god_sun_shift_up"],
			_rep("god_sun_noon", 6) + _rep("god_sun_faster", 3) + ["god_sun_dawnlight", "god_sun_dusklight"] + _rep("god_sun_fullmoon", 3)],
		"sun_eternal": [&"sun", ["god_sun_blaze", "god_sun_eternal_day", "god_sun_eternal_day_up"],
			_rep("god_sun_longday", 5) + _rep("god_sun_noon", 8) + ["god_sun_dawnlight"]],
		"brute": [&"brute", ["god_brute_break", "god_brute_burn", "god_brute_blood", "god_brute_break_up", "god_brute_burn_up", "god_brute_blood_up"],
			_rep("god_brute_damage", 5) + _rep("god_brute_haste", 5) + _rep("god_brute_irate", 3) + ["god_brute_persist", "god_brute_linger", "god_brute_laurel"]
			+ _rep("god_brute_regen", 2) + _rep("god_brute_lifesteal", 2)],
		"brute_exert": [&"brute", ["god_brute_exert", "god_brute_break", "god_brute_burn", "god_brute_blood", "god_brute_break_up", "god_brute_burn_up"],
			_rep("god_brute_damage", 5) + _rep("god_brute_haste", 5) + _rep("god_brute_irate", 3) + ["god_brute_persist", "god_brute_linger", "god_brute_laurel"]
			+ _rep("god_brute_regen", 2) + _rep("god_brute_lifesteal", 2)],
		"skill": [&"skill", ["god_skill_press", "god_skill_gap", "god_skill_zanshin", "god_skill_press_up", "god_skill_gap_up", "god_skill_zanshin_up"],
			_rep("god_skill_see", 4) + _rep("god_skill_stream", 4) + _rep("god_skill_ready", 2) + _rep("god_skill_steady", 2)
			+ ["god_skill_breath", "god_skill_vigor", "god_skill_finish"] + _rep("god_skill_cloud", 2) + _rep("god_skill_poise", 2) + _rep("god_skill_parry", 2)],
		"nature": [&"nature", ["god_nature_decay", "god_nature_reap", "god_nature_cycle", "god_nature_decay_up", "god_nature_reap_up", "god_nature_cycle_up"],
			_rep("god_nature_poison", 6) + _rep("god_nature_rejuv", 6) + ["god_nature_survive"] + _rep("god_nature_food", 2) + _rep("god_nature_herb", 2)],
		"earth": [&"earth", ["god_earth_rock", "god_earth_sky", "god_earth_pillar", "god_earth_rock_up", "god_earth_sky_up", "god_earth_pillar_up"],
			_rep("god_earth_vital", 4) + _rep("god_earth_strive", 4) + _rep("god_earth_grounded", 3) + ["god_earth_thick", "god_earth_quake", "god_earth_ram",
			"god_earth_heavy", "god_earth_jade", "god_earth_ranges", "god_earth_pillar_sky"]],
		"none": [&"", [], []],
	}


func _rep(id: String, n: int) -> Array:
	var a := []
	for i in n: a.append(id)
	return a


func _gear(items: ItemDatabase) -> void:
	for id in items.all_ids():
		var d := items.get_def(id)
		if d.is_blessed() or d.is_anchor(): continue
		for t in [&"weapon", &"armor", &"shield"]:
			if d.tags.has(t):
				gear.get_or_add("%s_%d" % [t, d.rarity], []).append(id)


## tier：-1 = 空包（只一把制式短剑）；0 / 2 / 4 = 普通 / 稀有 / 传说
func _kit(run: RunState, tier: int, rng: RandomNumberGenerator) -> Array:
	var placed := []
	if tier < 0:
		if TestSupport.put(run.board, run.items.get_def(&"shortsword")) != null: placed.append("shortsword")
		return placed
	for bag in [&"war_pack", &"bag_leather", &"bag_leather"]:
		TestSupport.put(run.board, run.items.get_def(bag))
	var plan := [["weapon", tier, 2], ["armor", clampi(tier, 1, 3), 1], ["shield", clampi(tier, 1, 3), 1]]
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


## 升到 30 级；每次摆出来的牌换成清单里下一张能拿的（质变位按质变清单，普通位按基础牌清单，都拿完了按通用牌）
func _level_up(run: RunState, quals: Array, bases: Array) -> void:
	var lv := LevelModule.of(run)
	var q := quals.duplicate()
	var b := bases.duplicate()
	var guard := 0
	while guard < 400:
		guard += 1
		if lv.pending() <= 0:
			if lv.level() >= 30: break
			lv.gain(5.0, LevelModule.SRC_EVENT, "test")
			continue
		var cards := lv.offer()
		if cards.is_empty(): break
		if lv.seed_offer() or EarthHeavenPerk.select_offer(lv):
			lv.pick(0); continue
		var want := ""
		if lv.offer_qual:
			for c in q:
				if lv.eligible(StringName(c)): want = c; break
			if want != "": q.erase(want)
		else:
			for c in b:
				if lv.eligible(StringName(c)): want = c; break
			if want != "": b.erase(want)
			else:
				for c in GENERAL:
					if lv.eligible(StringName(c)): want = c; break
		if want != "":
			lv.offer_ids[0] = want
		lv.pick(0)


func _foes(diff: String, items: ItemDatabase, sets: SetDatabase) -> Dictionary:
	var ch := BalanceExperiment.chapter_for_pool("standard_ruins")
	var pop := BalanceExperiment.real_nodes({"chapter": ch, "maps": MAPS, "seed": 1128, "items": items, "enemies": enemies, "sets": sets,
		"difficulty": ContentPaths.load_asset("difficulties", diff)})
	var out := {"normal": [], "elite": [], "boss": []}
	for p in pop:
		var t := String(p["type"])
		var k := "boss" if t == "core" else ("elite" if t == "elite" else ("normal" if t == "battle" else ""))
		if k == "" or (k != "boss" and int(p["strength"]) < 2): continue
		if (out[k] as Array).size() >= FOES: continue
		var spec := EnemyKit.spec_of(p["content"], enemies, pool, items)
		if spec != null: (out[k] as Array).append([spec, String(p["enemy"])])
	return out


func _init() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("kits="): KITS = int(s.substr(5))
		elif s.begins_with("foes="): FOES = int(s.substr(5))
		elif s.begins_with("maps="): MAPS = int(s.substr(5))
		elif s.begins_with("builds="): ONLY = Array(s.substr(7).split(","))
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var rules := ContentPaths.load_asset("node_rules", "standard") as NodeRules
	if rules != null:
		limit = rules.battle_time_limit; overtime = rules.overtime
	var items := ItemDatabase.new(); items.load_dir()
	var sets := SetDatabase.new(); sets.load_dir()
	var t0 := Time.get_ticks_msec()
	var foes := {}
	for d in ["normal", "ascension_8"]:
		foes[d] = _foes(d, items, sets)
		print("GD1036 敌人 %s：%s" % [d, ", ".join((foes[d] as Dictionary).keys().map(func(k): return "%s %d 个（%s）" % [k, foes[d][k].size(), ",".join(foes[d][k].map(func(e): return e[1]))]))])
	var builds := _builds()
	for name_ in builds:
		if not ONLY.is_empty() and not ONLY.has(name_): continue
		var bd: Array = builds[name_]
		for tier in [-1, 0, 2, 4]:
			for k in KITS:
				var seed_ := hash("%s:%d:%d" % [name_, tier, k]) & 0x7fffffff
				var run := G._start(seed_ % 100000 + 1, bd[0])
				if run == null: continue
				if gear.is_empty(): _gear(run.items)
				var rng := RandomNumberGenerator.new(); rng.seed = seed_
				var kit := _kit(run, tier, rng)
				_level_up(run, bd[1], bd[2])
				var lv := LevelModule.of(run)
				var gq := []
				var gb := {}
				for t in lv.taken:
					var row := lv.rules().card(StringName(String(t)))
					if String(row.get("god", "")) == "": gb["通用"] = int(gb.get("通用", 0)) + int(lv.taken[t])
					elif lv.rules().is_qual(StringName(String(t))): gq.append(String(t).trim_prefix("god_"))
					else: gb[String(t).trim_prefix("god_")] = int(lv.taken[t])
				var me := run.compile_player()
				print("GD1036 SET|%s|%d|%d|等级 %d|质变 %s|基础 %s|背包 %s" % [name_, tier, k, lv.level(), ",".join(gq), str(gb), ",".join(kit)])
				for d in foes:
					for kind in foes[d]:
						var arr: Array = foes[d][kind]
						for i in arr.size():
							var frng := RandomNumberGenerator.new(); frng.seed = hash("%d:%s:%d" % [k, kind, i])
							var res := BattleSim.run(me, arr[i][0], frng, limit, overtime)
							var m := BattleMetrics.of(res, limit, [me, arr[i][0]])
							var hp: Array = m["hp_end"]
							print("GD1036 F|%s|%d|%d|%s|%s|%d|%s|%.2f|%s" % [name_, tier, k, d, kind, i, "W" if res.winner == 0 else "L", float(m["duration"]),
								str(hp[0]) if hp[0] != null else "-"])
				run.dispose()
	print("GD1036 完 %.0f 秒" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)

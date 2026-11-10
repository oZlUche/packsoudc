## 平衡检测方案（2026-11-10）§8.3：最小人工验证的短场景。每个场景 = 我方一张棋盘 × 池里一个真敌人 × 一个种子，
## 从候选里按顺序找第一个满足条件的（大胜、明显败、险胜、耐力见底、被针对与它的对照、换一件以后变好），
## 存下输入（诊断包）和预期事实（[BattleExperience] 量出来的）。找不到就记「没找到」，不放宽条件。
##
## 预期事实只是诊断量出来的事实，不是「正确答案」：给人看的时候先让人自由回答，再拿出来对。
class_name FeelScenarios
extends RefCounted

const LIMIT := 30.0
const SEED_TRIES := 60
const FACTOR_SEEDS := 40

## [id, 说明, 池, 我方候选 [[道具…], 生命], 敌人候选 [[id, 档]], 条件]
static func catalog() -> Array:
	return [
		["crush_win", "大胜：赢，余血八成以上，六秒内", "standard_ruins",
			[[["longsword", "shortsword", "salve"], 120.0], [["battle_axe", "shortsword"], 120.0]], [["raider", 0], ["ragpicker", 0], ["smuggler", 0]],
			func(m: Dictionary) -> bool: return m["outcome"] == BattleMetrics.WIN and float(m["hp_end"][0]) >= 0.8 and float(m["duration"]) <= 6.0],
		["clear_loss", "明显败：输，对方余血七成以上", "standard_ruins",
			[[["knife"], 60.0], [["club"], 60.0]], [["brute", 2], ["berserker", 1], ["butcher", 1]],
			func(m: Dictionary) -> bool: return m["outcome"] == BattleMetrics.LOSS and m["hp_end"][1] != null and float(m["hp_end"][1]) >= 0.7],
		["close_call", "险胜：赢，余血一成半以下", "standard_ruins",
			[[["longsword", "shortsword"], 100.0], [["shortsword", "knife", "salve"], 100.0], [["battle_axe"], 100.0]],
			[["raider", 1], ["tracker", 1], ["marksman", 1], ["butcher", 1]],
			func(m: Dictionary) -> bool: return m["outcome"] == BattleMetrics.WIN and float(m["hp_end"][0]) > 0.0 and float(m["hp_end"][0]) <= 0.15],
		["stamina_short", "耐力见底：我方耐力在前半场打空，场次超过五秒", "standard_ruins",
			[[["battle_axe", "warhammer", "longsword", "shortsword"], 250.0], [["greatsword", "warhammer", "battle_axe"], 250.0]],
			[["shield_wall", 1], ["warden", 2], ["shield_wall", 2], ["warden", 1]],
			func(m: Dictionary) -> bool: return m["stamina_empty_at"][0] != null and float(m["stamina_empty_at"][0]) <= float(m["duration"]) / 2.0 and float(m["duration"]) > 5.0],
		["counter_a", "被针对：毒与流血的配装打免疫毒与流血的机关，输，对方一层毒、血都没上", "clockwork",
			[[["poisoned_knife", "bloodletter"], 100.0]],
			[["steam_turret", 1], ["clockwork_sentry", 1], ["gear_golem", 1], ["pendulum_warden", 1], ["steam_turret", 2], ["clockwork_sentry", 2], ["gear_golem", 2]],
			func(m: Dictionary) -> bool: return m["outcome"] == BattleMetrics.LOSS and not (m["statuses_taken"][1] as Dictionary).has("poison") \
				and not (m["statuses_taken"][1] as Dictionary).has("bleed")],
		["counter_b", "对照：同一份配装打不免疫的敌人，赢", "clockwork",
			[[["poisoned_knife", "bloodletter"], 100.0]], [["tinker_apprentice", 1], ["tinker_apprentice", 2], ["clock_keeper", 1]],
			func(m: Dictionary) -> bool: return m["outcome"] == BattleMetrics.WIN],
		["swap_a", "换装前：两把剑，差一点输（对方余血四成以下）", "standard_ruins",
			[[["longsword", "shortsword"], 100.0]], [["berserker", 1], ["butcher", 1], ["tracker", 1], ["marksman", 1], ["raider", 1]],
			func(m: Dictionary) -> bool: return m["outcome"] == BattleMetrics.LOSS and m["hp_end"][1] != null and float(m["hp_end"][1]) <= 0.4],
	]


## 换装后：swap_a 找到的那一场，把短剑换成这一件，别的都不动（同一个敌人、同一个种子）
const SWAP_OUT := &"shortsword"
const SWAP_IN: Array[StringName] = [&"tower_shield", &"round_shield", &"leather_armor", &"plate_cuirass", &"salve", &"battle_axe", &"greatsword"]


## 造全部场景。返回 [{id, note, found, pack, facts, …}]；[param ctx] 要 items、enemies
static func build(ctx: Dictionary) -> Array:
	var out: Array = []
	var swap_hit: Dictionary = {}
	for row in catalog():
		var hit := _search(row, ctx)
		out.append(hit)
		if row[0] == "swap_a" and bool(hit["found"]):
			swap_hit = hit
	out.append(_swap_b(swap_hit, ctx))
	return out


static func _search(row: Array, ctx: Dictionary) -> Dictionary:
	var items: ItemDatabase = ctx["items"]
	var enemies: EnemyDatabase = ctx["enemies"]
	var pool := ContentPaths.load_asset("enemy_pools", String(row[2])) as EnemyPool
	var base := {"id": row[0], "note": row[1], "pool": row[2], "found": false}
	if pool == null:
		base["why"] = "没有敌人池 %s" % row[2]
		return base
	var pred: Callable = row[5]
	for mine in row[3]:
		for foe_row in row[4]:
			var def := enemies.enemy(StringName(foe_row[0]))
			if def == null:
				continue
			for k in SEED_TRIES:
				var s := hash("%s:%s:%d" % [row[0], foe_row[0], k])
				var me := player(mine[0], float(mine[1]), items)
				var erng := RandomNumberGenerator.new()
				erng.seed = s
				var content: Dictionary = EnemyPlacer.build_content(def, pool, items, int(foe_row[1]), erng).get("content", {})
				var foe := EnemyKit.spec_of(content, enemies, pool, items)
				if me == null or foe == null:
					continue
				var hit := _try(me, foe, s, pred)
				if hit.is_empty():
					continue
				hit.merge(base)
				hit["found"] = true
				hit["mine"] = mine[0]
				hit["hp"] = mine[1]
				hit["enemy"] = foe_row[0]
				hit["tier"] = foe_row[1]
				hit["content"] = content
				hit["foe_spec"] = foe
				return hit
	base["why"] = "候选里没有满足条件的"
	return base


## 打一场，满足条件就返回 {seed, pack, facts}
static func _try(me: CombatantSpec, foe: CombatantSpec, s: int, pred: Callable) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var pack := BattleDiagPack.capture(me, foe, rng, LIMIT, null, {"source": ExperimentManifest.SYNTHETIC})
	var result := BattleSim.run(me, foe, rng, LIMIT, null)
	var facts := facts_of(result, [me, foe])
	if not bool(pred.call(facts)):
		return {}
	pack.expected = BattleDiagPack.summary(result)
	return {"seed": s, "pack": pack, "facts": facts, "specs": [me, foe]}


## 预期事实：结果、时长、余血、双方伤害主要来源、决定性窗口、耐力见底、上过的状态
static func facts_of(result: BattleResult, specs: Array) -> Dictionary:
	var a := BattleExperience.analyze(result, specs, LIMIT)
	var c: Dictionary = a["cause"]
	return {"outcome": a["outcome"], "duration": a["duration"], "hp_end": a["hp_end"], "top_damage": c["top_damage"],
		"decisive_window": c["decisive_window"], "stamina_empty_at": c["stamina_empty_at"], "statuses_taken": c["statuses_taken"],
		"fires": a["rhythm"]["fires"], "first_interaction": a["rhythm"]["first_interaction"]}


static func player(ids: Array, hp: float, items: ItemDatabase) -> CombatantSpec:
	var typed: Array[StringName] = []
	for i in ids:
		if items.get_def(StringName(i)) == null:
			return null
		typed.append(StringName(i))
	return BattleCompiler.compile_board(LootPacker.board_of(typed, Vector2i(5, 5), items), CombatantBaseline.with_hp(hp))


## 换装后：swap_a 那一场把 [constant SWAP_OUT] 换成 [constant SWAP_IN] 里第一件能让同一个种子赢下来的；
## 另配对 [constant FACTOR_SEEDS] 个种子看换前换后的胜率差，连带变化（[method BattleFactor.collateral]）一起记
static func _swap_b(a: Dictionary, ctx: Dictionary) -> Dictionary:
	var base := {"id": "swap_b", "note": "换装后：同一个敌人、同一个种子，只把短剑换一件", "found": false}
	if a.is_empty():
		base["why"] = "swap_a 没找到"
		return base
	var items: ItemDatabase = ctx["items"]
	var before := player(a["mine"], float(a["hp"]), items)
	var pred := func(m: Dictionary) -> bool: return m["outcome"] == BattleMetrics.WIN
	for cand in SWAP_IN:
		var ids: Array = (a["mine"] as Array).duplicate()
		ids[ids.find(String(SWAP_OUT))] = String(cand)
		var me := player(ids, float(a["hp"]), items)
		if me == null:
			continue
		var hit := _try(me, a["foe_spec"], int(a["seed"]), pred)
		if hit.is_empty():
			continue
		hit.merge(base)
		hit["found"] = true
		hit["mine"] = ids
		hit["hp"] = a["hp"]
		hit["enemy"] = a["enemy"]
		hit["tier"] = a["tier"]
		hit["pool"] = a["pool"]
		hit["content"] = a["content"]
		hit["swap"] = {"out": String(SWAP_OUT), "in": String(cand)}
		hit["collateral"] = BattleFactor.collateral(before, me, [SWAP_OUT, cand] as Array[StringName])
		var p := BattleFactor.paired(me, before, a["foe_spec"], BattleFactor.seeds_from(int(a["seed"]), FACTOR_SEEDS), LIMIT)
		hit["paired"] = {"n": p["n"], "win_after": p["win_a"], "win_before": p["win_b"], "win_diff": p["win_diff"], "hp_diff": p["hp_diff"]}
		return hit
	base["why"] = "换哪一件同一个种子都没赢"
	return base


## 战后有明显得失：正式开一局（free_mode，标准开局装备），打图上第一个带敌人的战斗点，输了按节点规则扣体力；诊断开着抓包，战前战后各记一份体力 / 钱 / 件数 / 步数。
## [param dir] 是这一份包临时落的目录
static func aftermath(ctx: Dictionary, dir: String) -> Dictionary:
	var base := {"id": "aftermath", "note": "战后得失：正式一局（标准开局装备）里打一场，看体力、钱、件数怎么变", "pool": "standard_ruins", "found": false}
	var chapter := ContentPaths.load_asset("chapters", "free_mode") as ChapterDef
	if chapter == null:
		base["why"] = "没有 free_mode"
		return base
	var kit_def := ContentPaths.load_asset("loadouts", "standard") as LoadoutDef
	var kit: Array[StringName] = kit_def.items if kit_def != null else [] as Array[StringName]
	for seed_ in range(1, 40):
		var s := RunState.start(chapter, seed_, ctx["items"], ctx["enemies"], ctx.get("sets", null), kit)
		if s == null:
			continue
		s.pick_spawn(s.map.entry_ids[0])
		var node: MapNode = null
		for id in s.map.node_ids():
			var n := s.map.get_node(id)
			if n.type == &"battle" and EnemyKit.has_enemy(n.content):
				node = n
				break
		if node == null:
			continue
		var was: Variant = BattleDiagnostics.enabled
		var was_dir := BattleDiagnostics.target_dir
		for old in BattleDiagnostics.list(dir):
			DirAccess.remove_absolute(dir.path_join(old))
		BattleDiagnostics.enabled = true
		BattleDiagnostics.target_dir = dir
		s.events.trace_info = {"run_id": s.run_id, "chapter": "free_mode"}
		var before := s.events.state_brief()
		var won := s.events.fight_content(node, &"battle", node.content)
		var after := s.events.state_brief()
		BattleDiagnostics.enabled = was
		BattleDiagnostics.target_dir = was_dir
		s.events.trace_info = {}
		var files := BattleDiagnostics.list(dir)
		if files.is_empty():
			continue
		var pack := BattleDiagnostics.load_pack(dir.path_join(files[files.size() - 1]))
		if pack == null:
			continue
		var delta := {}
		var changed := false
		for k in before:
			delta[k] = (float(after[k]) - float(before[k]) as Variant) if before[k] != null and after[k] != null else null
			changed = changed or (delta[k] != null and float(delta[k]) != 0.0)
		if not changed:
			continue     # 免罚败仗、等求饶、没掉钱：这一场看不出得失，换下一个种子
		var specs := pack.specs()
		var facts := facts_of(pack.rerun(), specs)
		facts["run_before"] = before
		facts["run_after"] = after
		facts["run_delta"] = delta
		facts["ransom_pending"] = not s.events.pending_ransom.is_empty()
		base.merge({"found": true, "seed": pack.rng_seed, "pack": pack, "facts": facts, "won": won, "enemy": String(node.content.get("enemy", "")),
			"tier": int(node.content.get("strength", 0)), "run_seed": seed_, "node_id": node.id}, true)
		return base
	base["why"] = "开不出带敌人、打完看得出得失的战斗点"
	return base


## 问题清单：每个场景同样四问，先自由回答再看诊断；不在问题里暗示答案
static func questions(rows: Array) -> String:
	var lines: Array[String] = ["# 人工验证：战斗胜负感", "",
		"每一场看完回放（启动选择器 → 战斗回放，名字以 `feel:` 开头）先回答下面四问，再打开 `scenarios.json` 对照诊断量出来的事实。",
		"记下回答人（作者 / 玩家）、看过几场、以前对这类配装熟不熟。有两组是成对的（同一份配装换了对手、同一个对手换了一件），同一人连着看，后看的会受先看的影响：按下表的顺序看，成对的已经错开。",
		"样本小，只用来找具体的理解障碍，不说明总体满意度。", "",
		"## 四问", "",
		"1. 你认为刚才为什么赢 / 输？",
		"2. 哪个准备选择有帮助？下一次会改什么？",
		"3. 这场之后你具体得到了 / 失去了什么？影响下一步吗？",
		"4. 原因有多清楚（1～5）、结果有多要紧（1～5）？各说一句为什么。", "",
		"## 场景", "",
		"| 顺序 | 代号 | 回放 | 回答人 | 1 | 2 | 3 | 4 |",
		"|---:|---|---|---|---|---|---|---|"]
	var order := 0
	for r in rows:
		var row := r as Dictionary
		if not bool(row.get("found", false)):
			continue
		order += 1
		lines.append("| %d | %s | %s |  |  |  |  |  |" % [order, row["code"], String(row.get("replay", "—"))])
	lines.append("")
	lines.append("代号对应的场景说明和预期事实在 `scenarios.json`；**答完再看**。")
	return "\n".join(lines) + "\n"

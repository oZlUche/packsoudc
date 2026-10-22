## 流派木桩（242 §3.1 / §8.1 ①）：没有真实快照时先拿这个扫表 —— 流派 × 段位，每段的「平均玩家」按同段敌人一样富来配。
##
## 五路 = 道具库现有的三个战斗流派标签（burst / rapid / bleed）+ 两种防御偏向（盾 shield / 防具 armor）。
## 段位 k 对池的第 k 档：件数在那一档的 item_count 里掷、稀有度上限取那一档（和敌人组装同一条 [method EnemyPlacer.choose_items]，
## 流派就是这一路的标签，保底武器照样补）。摆法 = 开局棋盘（默认角色的尺寸与开局包，后两段多一个包），
## 包先摆、武器先摆、道具大的先摆，逐件找第一个放得下的位置（贪心，和开局发 kit 同一条 [method GridInventory.try_add]）；放不下的记在 `left`。
## 每路每段换 [constant SEEDS] 个种子各配一份，免得一块棋盘的偶然性。输出和 [DummyBuilder] 同一个格式（073），
## 每份多记流派、段号、种子；键是 `流派/段号/种子`。真实木桩（作者打十局后）到了就换掉它。
class_name ArchetypeBuilder
extends RefCounted

const DEFAULT_PATH := "res://data/authoring/calibration/archetypes.json"
const ARCHETYPES: Array[StringName] = [&"burst", &"rapid", &"bleed", &"shield", &"armor"]
const SEEDS := 3
## 后两段多背的那个包
const EXTRA_BAG := &"bag_leather"
## 开局棋盘按这个角色（8 × 6、皮包 + 小包）
## 拼大件用的长条包（1 × 4）
const STRIP_BAG := &"bag_long"
const CHARACTER := &"marcus"


## 全部木桩：{`流派/段号/种子` → 木桩}。[param brackets] 是段位表（第 k 段从第几步开始）
static func build(pool: EnemyPool, items: ItemDatabase, brackets: Array[int], character: CharacterDef,
		seeds: int = SEEDS, archetypes: Array[StringName] = ARCHETYPES) -> Dictionary:
	var out := {}
	for a in archetypes:
		for k in brackets.size():
			var hi := (brackets[k + 1] - 1) if k + 1 < brackets.size() else -1
			for s in seeds:
				var dummy := one(a, k, s, pool, items, character, k >= brackets.size() - 2)
				dummy["steps"] = [brackets[k], hi]
				out[key_of(a, k, s)] = dummy
	return out


static func key_of(archetype: StringName, bracket: int, seed: int) -> String:
	return "%s/%d/%d" % [archetype, bracket, seed]


## 一份：流派 [param archetype]、第 [param bracket] 段（对池的同号档）、第 [param seed] 个种子
static func one(archetype: StringName, bracket: int, seed: int, pool: EnemyPool, items: ItemDatabase,
		character: CharacterDef, extra_bag: bool) -> Dictionary:
	var strength := pool.clamp_strength(bracket)
	var tier := pool.tier_of(strength)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(archetype), bracket, seed, "archetype"])
	var count := rng.randi_range(tier.item_count.x, tier.item_count.y) if tier != null else 3
	var rule := pool.loadout if pool.loadout != null else EnemyLoadout.new()
	var who := EnemyDef.new()
	who.id = StringName("archetype_%s" % archetype)
	who.schools = [archetype] as Array[StringName]
	var cap := EnemyPlacer.rarity_cap_of(rule, tier)
	var picks := EnemyPlacer.choose_items(who, rule, items, count, rng, cap, strength)
	_arm(picks, archetype, rule.weapon_tag, items, cap, rng)
	picks.sort_custom(func(a: StringName, b: StringName) -> bool:     # 武器先摆（别让一件大甲占了包、刀反而没地方），再大的先摆
		var wa := items.get_def(a).tags.has(rule.weapon_tag)
		if wa != items.get_def(b).tags.has(rule.weapon_tag):
			return wa
		var ca := items.get_def(a).cell_count()
		var cb := items.get_def(b).cell_count()
		return ca > cb if ca != cb else String(a) < String(b))
	var bags: Array[StringName] = character.starting_bags.duplicate() if character != null else [EXTRA_BAG] as Array[StringName]
	if extra_bag:
		bags.append(EXTRA_BAG)
	var size := character.board_size if character != null else RunState.BOARD_SIZE
	var board := GridInventory.new(size, RunState.BOARD_ID, true)
	var left: Array[String] = []
	var spare := BagPool.standard().candidates(items, cap)
	spare.sort_custom(func(a: BagPoolEntry, b: BagPoolEntry) -> bool:
		var ca := items.get_def(a.bag).cell_count()
		var cb := items.get_def(b.bag).cell_count()
		return ca < cb if ca != cb else String(a.bag) < String(b.bag))
	board.begin_batch()
	for id in bags:
		board.try_add(ItemInstance.create(items.get_def(id), 0), true)
	for id in picks:
		var def := items.get_def(id)
		if board.try_add(ItemInstance.create(def, 0), true):
			continue
		var fitted := false
		for e in spare:
			var bag := items.get_def(e.bag)
			if EnemyPlacer.bag_fits(bag, def) and board.try_add(ItemInstance.create(bag, 0), true):
				bags.append(e.bag)
				fitted = board.try_add(ItemInstance.create(def, 0), true)
				break
		if not fitted:
			fitted = _strip_cover(board, def, items, bags)
		if not fitted:
			left.append(String(id))
	board.end_batch()
	var baseline := character.baseline() if character != null else CombatantBaseline.default_baseline()
	var stats := {}
	for key in baseline.base_stats:
		stats[String(key)] = float(baseline.base_stats[key])
	var dummy := {
		"archetype": String(archetype), "bracket": bracket, "seed": seed, "tier": strength, "samples": 1,
		"board_size": [size.x, size.y], "requires_bag": true, "layout": RunState.layout_of(board), "baseline": stats,
		"bags": bags.map(func(id: StringName) -> String: return String(id)),
		"picked": picks.map(func(id: StringName) -> String: return String(id)), "left": left,
	}
	var m := DummyBuilder.metrics(dummy, items)
	dummy["hp"] = float(m["hp"])
	dummy["dps"] = float(m["dps"])
	return dummy


## 流派池里一件武器都没有（盾、防具两路）：把最后一件非流派道具换成一件武器（同稀有度上限，随机）；全是流派道具就加一件
static func _arm(picks: Array[StringName], archetype: StringName, weapon_tag: StringName, items: ItemDatabase, cap: int, rng: RandomNumberGenerator) -> void:
	if weapon_tag == &"" or picks.any(func(id: StringName) -> bool: return items.get_def(id).tags.has(weapon_tag)):
		return
	var weapons: Array[StringName] = []
	for id in items.ids():
		var d := items.get_def(id)
		if d != null and not d.is_bag and d.tags.has(weapon_tag) and (cap < 0 or d.rarity <= cap):
			weapons.append(id)
	if weapons.is_empty():
		return
	Ids.sort(weapons)
	var w := weapons[rng.randi_range(0, weapons.size() - 1)]
	for i in range(picks.size() - 1, -1, -1):
		if not items.get_def(picks[i]).tags.has(archetype):
			picks[i] = w
			return
	picks.append(w)


## 外框长边等于长条包长度的一件：在棋盘上找一块空着的外框，用 [constant STRIP_BAG] 一条条铺满，再把这件摆上去。
## 摆不上就把刚铺的包收回、换下一块地方。成了返回 true，铺的包记进 [param bags]
static func _strip_cover(board: GridInventory, def: ItemDef, items: ItemDatabase, bags: Array[StringName]) -> bool:
	var strip := items.get_def(STRIP_BAG)
	if strip == null:
		return false
	var length := maxi(strip.shape.size_rotated(0).x, strip.shape.size_rotated(0).y)
	var strip_rot := 0 if strip.shape.size_rotated(0).x == length else 1     # 横放的那个朝向
	for rot in [0, 1]:
		var box := def.shape.size_rotated(rot)
		var across := box.x == length     # 横条一行行往下铺；否则竖条一列列往右铺
		if not across and box.y != length:
			continue
		var n := box.y if across else box.x
		for y in board.size.y - box.y + 1:
			for x in board.size.x - box.x + 1:
				var origin := Vector2i(x, y)
				var laid: Array[ItemInstance] = []
				for i in n:
					var b := ItemInstance.create(strip, 0)
					var at := origin + (Vector2i(0, i) if across else Vector2i(i, 0))
					if not board.place(b, at, strip_rot if across else 1 - strip_rot):
						break
					laid.append(b)
				if laid.size() == n and board.place(ItemInstance.create(def, 0), origin, rot):
					for i in n:
						bags.append(STRIP_BAG)
					return true
				for b in laid:
					board.remove(b.uid)
	return false

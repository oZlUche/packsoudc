class_name JimiePath
extends RefCounted
## 281 寂灭的路（二）：开局背包里有全黑法杖（[method ItemInstance.is_black_staff]）、这张图配了元素（[constant TRIALS]，作者 11:17 定 B：按章节配表），
## 且那一种元素之核哪儿都没有（[UniqueItems]）—— 图上恰好一个事件点换成试炼：最高档的一场，敌人只受这一种元素的伤害
## （其余类型、真实伤害都减 100%，[member CombatantSpec.only_damage_type]），输了不掉体力（`loss_cost` 0），打过就用掉。
## 打赢了给那一种元素之核（1×1、独一、不能卖）

const EVENT := &"event_jimie_trial"
## 点内容里的键：只受哪种伤害、打赢给什么
const ONLY_KEY := "element_only"
const REWARD_KEY := "jimie_reward"

## 章节 → 元素。冰、毒留给以后两章
const TRIALS := {&"free_mode": &"fire", &"clockwork_hourglass": &"lightning"}
const CORES := {&"fire": &"jimie_core_fire", &"ice": &"jimie_core_ice", &"lightning": &"jimie_core_lightning", &"poison": &"jimie_core_poison"}

## （三）神坛献祭换来的红武，与这一局的结束原因（结算屏第二页看它放黑洞）
const RED := &"jimie"
const REASON := &"jimie"
## 献祭之后接着弹的那段话（【魔法之神的残余意识】，正文给作者写）
const GOD_EVENT := &"event_jimie_god"


static func element_of(chapter: ChapterDef) -> StringName:
	return TRIALS.get(chapter.id, &"") if chapter != null else &""


static func has_black_staff(run: RunState) -> bool:
	return run != null and run.board != null and run.board.items().any(func(i: ItemInstance) -> bool: return i.is_black_staff())


## 开局（[GameFlow] 新开一局、局外状态接上之后）：够条件就挑一个事件点换成试炼。返回点 id，没换返回 -1
static func plant(run: RunState) -> int:
	if run == null or run.map == null or run.pool == null or run.items == null:
		return -1
	var element := element_of(run.chapter)
	if element == &"" or not has_black_staff(run):
		return -1
	var core: StringName = CORES[element]
	if UniqueItems.owned(core, run.meta, run, run.items):
		return -1
	var ids: Array[int] = []
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if n.type == &"event" and not run.map.entry_ids.has(id):
			ids.append(id)
	if ids.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("jimie:%d" % run.run_seed)
	var node := run.map.get_node(ids[rng.randi_range(0, ids.size() - 1)])
	var built := _enemy(node, run, rng)
	if built.is_empty():
		return -1
	for key in ["event_group", "outcome"]:
		node.content.erase(key)
	for key in built:
		node.content[key] = built[key]
	EnemyKit.stamp_hp(node.content, run.enemy_hp_mult())     # 320 A1
	node.content["event"] = String(EVENT)
	node.content["loss_cost"] = 0
	node.content[ONLY_KEY] = String(element)
	node.content[REWARD_KEY] = String(core)
	return node.id


## 最高档的一个对手（按精英点挑人）
static func _enemy(node: MapNode, run: RunState, rng: RandomNumberGenerator) -> Dictionary:
	var tiers := run.pool.strengths()
	if tiers.is_empty():
		return {}
	var top: int = tiers[tiers.size() - 1]
	var view := MapNode.from_dict(node.to_dict())
	view.type = &"elite"
	var entry := EnemyPlacer.pick(run.pool, run.enemies, view, top, rng)
	if entry == null:
		return {}
	var built := EnemyPlacer.build_content(run.enemies.enemy(entry.enemy), run.pool, run.items, top, rng, run.carry_rule, run.bag_pool)
	return built.get("content", {})


## 打赢了（[RunHooks] 的 red_drop）：试炼的点放进尸体。已经有了（别处拿到过）就不给
static func reward(content: Dictionary, run: RunState, rolled: Dictionary) -> bool:
	var core := StringName(String(content.get(REWARD_KEY, "")))
	if core == &"" or run == null or run.items == null:
		return false
	if not UniqueItems.can_give(run.items.get_def(core), run.meta, run, run.items):
		return false
	var dropped: Array = rolled.get("dropped", [])
	if not dropped.has(core):
		dropped.append(core)
	rolled["dropped"] = dropped
	return true


## （三）献祭备齐了：背包里有全黑法杖与四颗元素之核，寂灭不在背包也不在局外（仓库、待置入的棋盘…）
static func sacrifice_ready(board: ItemContainer, meta: MetaState) -> bool:
	if board == null or _black_staff(board) == null:
		return false
	for el in CORES:
		if _first(board, CORES[el]) == null:
			return false
	return _first(board, RED) == null and not UniqueItems.owned(RED, meta)


## （三）献祭：法杖与四颗核消失，寂灭摆在法杖原来的位置（同形状；摆不下就找空位，再不行放地上）。没备齐返回 false
static func sacrifice(board: ItemContainer, storage: ItemContainer, items: ItemDatabase) -> bool:
	var grid := board as GridInventory
	var staff := _black_staff(board)
	var def := items.get_def(RED) if items != null else null
	if grid == null or staff == null or def == null:
		return false
	var cores: Array[ItemInstance] = []
	for el in CORES:
		var c := _first(board, CORES[el])
		if c == null:
			return false
		cores.append(c)
	var at := staff.origin
	var rot := staff.rotation
	grid.remove(staff.uid)
	for c in cores:
		grid.remove(c.uid)
	var red := ItemInstance.create(def)
	if grid.place(red, at, rot):
		return true
	if grid.try_add(red, true):
		return true
	return storage != null and storage.admit(red)


static func _black_staff(board: ItemContainer) -> ItemInstance:
	for v in board.items():
		var i := v as ItemInstance
		if i != null and i.is_black_staff():
			return i
	return null


static func _first(board: ItemContainer, id: StringName) -> ItemInstance:
	for v in board.items():
		var i := v as ItemInstance
		if i != null and i.def.id == id:
			return i
	return null

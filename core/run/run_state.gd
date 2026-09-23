## 一局游戏的全部状态（架构文档 7 节，M5）：地图、旅程、体力、钱、棋盘、暂存区、节点事件、随机流。
##
## M4 结束时这些东西各自都能跑，只差一个装它们的壳 —— 这就是那个壳。它做三件事：
## 1. **开局**（[method start]）：从一章生成地图、放敌人、标付费撤离点、造棋盘与暂存区、把节点事件接到旅程上；
## 2. **接线**：打赢的战利品、搜到的东西、买到的东西、事件给的东西，都落到「待拾取」或暂存区；战败、撤离改阶段；
## 3. **存档**（[method to_dict] / [method from_dict]）：所有逻辑类都有 to_dict，这里只是把它们装进一个带版本号的字典。
##
## 纯 [RefCounted]，不是 autoload：核心逻辑层没有全局状态（1 节）。M6 的 GameDirector 持有它、给界面看。
## 内容库（道具、敌人、套装）由持有方给，存档里只写 id。
class_name RunState
extends RefCounted

## 存档从第一天就写版本号（7.2）
const SAVE_VERSION := 1
## 作战棋盘的尺寸（3.2：棋盘 + 包体）。占位，等角色系统
const BOARD_SIZE := Vector2i(8, 6)
const BOARD_ID := 1
const STORAGE_ID := 2

enum Phase { PICK_SPAWN, ON_MAP, DEFEATED, EXTRACTED }

signal phase_changed(phase: int, reason: StringName)
## 有东西等着拾取（尸体容器 / 搜索收获）。拿走或丢掉之前不会再来第二份
signal loot_pending(container: GridInventory)
signal loot_cleared()
## 走出一个发生过事的点，暂存区里的东西留在了那里（3.4 / 058）
signal storage_dropped(node_id: int, items: Array)

var run_seed: int = 0
var chapter: ChapterDef = null
var items: ItemDatabase = null
var enemies: EnemyDatabase = null
var sets: SetDatabase = null

var map: MapGraph = null
var travel: MapTravel = null
var vitality: Vitality = null
var wallet: Wallet = null
## 作战棋盘：requires_bag，只有包里的东西参战（3.2）
var board: GridInventory = null
## 暂存区：一个列表，保留但不参战（3.4）
var storage: ItemStash = null
var rng: RunRNG = null
var events: NodeEvents = null
var tracker: SetTracker = null
## 玩家自带的基线属性（4.2）。角色系统落地前用默认的；沙盒、测试可以换
var player_baseline: CombatantBaseline = null

var pool: EnemyPool = null
var drop_rule: DropRule = null
var node_rules: NodeRules = null
var economy: EconomyRules = null

var phase: int = Phase.PICK_SPAWN
var end_reason: StringName = &""
## 等着拾取的容器（尸体 / 搜索收获）；null = 没有
var pending_loot: GridInventory = null
## 这一局的计数（给结算看）：打赢 / 打输几场。跟着存档走
var tally: Dictionary = {"battles_won": 0, "battles_lost": 0}


#region 开局
## 从一章开一局。生成不出图返回 null。[param kit] 是开局带的道具 id（包放棋盘，其余先放包里、放不下进暂存区）——
## 「选初始背包」的界面是 M6 的事，这里只收一个清单
static func start(
	p_chapter: ChapterDef, p_seed: int, p_items: ItemDatabase, p_enemies: EnemyDatabase,
	p_sets: SetDatabase = null, kit: Array[StringName] = [] as Array[StringName]
) -> RunState:
	if p_chapter == null or p_chapter.map_source == null:
		return null
	var s := RunState.new()
	s.run_seed = p_seed
	s.chapter = p_chapter
	s.items = p_items
	s.enemies = p_enemies
	s.sets = p_sets
	s._resolve_rules()
	s.map = p_chapter.map_source.resolve(p_seed)
	if s.map == null:
		return null
	ItemInstance.reset_uid_counter()
	if s.pool != null:
		EnemyPlacer.fill(s.map, s.pool, p_enemies, p_items, p_chapter.difficulty, s.scale_id())
	PaidExtracts.mark(s.map, s.economy)
	s.rng = RunRNG.new(p_seed)
	s.vitality = Vitality.new()
	s.wallet = Wallet.new(s.economy.starting_balance if s.economy != null else 0)
	s.board = GridInventory.new(BOARD_SIZE, BOARD_ID, true)
	s.storage = ItemStash.new(STORAGE_ID, 0)
	s._bind_tracker()
	s._give_kit(kit)
	s.travel = MapTravel.new(s.map, ActionClock.new())
	s.travel.vitality = s.vitality
	s._wire_events()
	s.phase = Phase.PICK_SPAWN
	return s


## 站到出生点上开局。返回 false = 不是出生点，或不在挑出生点阶段
func pick_spawn(id: int) -> bool:
	if phase != Phase.PICK_SPAWN or map == null or not map.entry_ids.has(id):
		return false
	travel.start_at(id)
	_set_phase(Phase.ON_MAP, &"spawn")
	return true


## 走一步。开着的商店 / 搜索先关掉（随时可以离开）；走出发生过事的点，暂存区连东西一起清空（3.4）；不在图上走不了
func step_to(id: int) -> bool:
	if phase != Phase.ON_MAP:
		return false
	if not travel.available_moves().has(id):
		return travel.step_to(id)     # 让旅程自己拒绝、发 refused；走不成就不该清东西
	close_sessions()
	_drop_storage_if_leaving()
	return travel.step_to(id)


## 走出现在这个点会不会清暂存区：这个点上发生过事（打了、搜了、开了店、休息了、出了事件），而且暂存区里有东西
func will_clear_storage() -> bool:
	return events != null and travel != null and travel.current_id >= 0 \
		and events.last_handled_id == travel.current_id and storage.item_count() > 0


func _drop_storage_if_leaving() -> void:
	if events == null or travel == null:
		return
	if will_clear_storage():
		var dropped: Array = storage.items().duplicate()
		storage.clear()
		storage_dropped.emit(travel.current_id, dropped)
	# 离开了就不再算「发生过事的点」：回头再路过一次不会又清一遍
	if events.last_handled_id == travel.current_id:
		events.last_handled_id = -1


## 离开正在搜的点 / 正在逛的店
func close_sessions() -> void:
	if events == null:
		return
	if events.current_search != null:
		events.current_search.leave()
	if events.current_shop != null:
		events.current_shop.leave()


func current_node() -> MapNode:
	return map.get_node(travel.current_id) if map != null and travel != null and travel.current_id >= 0 else null


## 在撤离点上撤离：付费的先付钱（付不起 false）。撤离结算（背出去的东西算价值、进 meta）是 M6 的事
func try_extract() -> bool:
	var node := current_node()
	if phase != Phase.ON_MAP or node == null or NodeEvents.effective_type(node) != &"extract":
		return false
	if not events.pay_extract_fee(node):
		return false
	close_sessions()
	_set_phase(Phase.EXTRACTED, &"extract")
	return true


func is_over() -> bool:
	return phase == Phase.DEFEATED or phase == Phase.EXTRACTED
#endregion


#region 背包与战利品
## 开战那一刻编译玩家（4.2 是纯函数；套装的战斗侧效果从 tracker 取）
func compile_player() -> CombatantSpec:
	var mods: Array[StatModifier] = tracker.combat_mods() if tracker != null else [] as Array[StatModifier]
	var rules: Array[AbilityRule] = tracker.combat_rules() if tracker != null else [] as Array[AbilityRule]
	return BattleCompiler.compile(board, player_baseline, mods, rules)


## 从待拾取的容器里拿一件进暂存区
func take_loot(uid: int) -> bool:
	if pending_loot == null:
		return false
	var ok := InventoryService.transfer_auto(pending_loot, uid, storage)
	if pending_loot.item_count() == 0:
		discard_loot()
	return ok


## 全拿走，返回拿了几件
func take_all_loot() -> int:
	if pending_loot == null:
		return 0
	var n := InventoryService.transfer_all(pending_loot, storage)
	discard_loot()
	return n


## 剩下的不要了
func discard_loot() -> void:
	if pending_loot == null:
		return
	pending_loot = null
	loot_cleared.emit()


## 暂存区 → 棋盘（自动找位）
func equip(uid: int) -> bool:
	return InventoryService.transfer_auto(storage, uid, board)


## 棋盘 → 暂存区
func unequip(uid: int) -> bool:
	return InventoryService.transfer_auto(board, uid, storage)


func _offer_loot(container: GridInventory) -> void:
	if container == null or container.item_count() == 0:
		return
	if pending_loot != null:
		# 上一份还没处理就来了新的（沙盒里一步接一步）：并进去，一件都不丢
		InventoryService.transfer_all(pending_loot, container)
	pending_loot = container
	loot_pending.emit(container)


func _give_kit(kit: Array[StringName]) -> void:
	if items == null:
		return
	var bags: Array[ItemDef] = []
	var rest: Array[ItemDef] = []
	for id in kit:
		var d := items.get_def(id)
		if d == null:
			continue
		if d.is_bag:
			bags.append(d)
		else:
			rest.append(d)
	board.begin_batch()
	for d in bags:
		board.try_add(ItemInstance.create(d, 0), true)
	for d in rest:
		var inst := ItemInstance.create(d, 0)
		if not board.try_add(inst, true):
			storage.admit(inst)
	board.end_batch()
#endregion


#region 接线
func _resolve_rules() -> void:
	if enemies != null and chapter.enemy_pool != &"":
		pool = enemies.pool(chapter.enemy_pool)
	drop_rule = _rule_asset("drop_rules", chapter.drop_rule) as DropRule
	node_rules = _rule_asset("node_rules", chapter.node_rules) as NodeRules
	economy = _rule_asset("economy_rules", chapter.economy_rules) as EconomyRules


static func _rule_asset(kind: String, id: StringName) -> Resource:
	if id == &"":
		return null
	var path := ContentPaths.asset_file(kind, String(id))
	return load(path) if ResourceLoader.exists(path) else null


## 这一章的规模 id（有规模模板的生成器才有）
func scale_id() -> StringName:
	var cfg: Resource = chapter.map_source.generator_config if chapter != null and chapter.map_source != null else null
	if cfg == null or not cfg.has_method("scale"):
		return &""
	var p = cfg.call("scale")
	return p.id if p != null else &""


func _bind_tracker() -> void:
	if sets == null:
		return
	tracker = SetTracker.create(sets)
	tracker.bind(board)


func _wire_events() -> void:
	events = NodeEvents.new(map)
	events.vitality = vitality
	events.rules = node_rules
	events.pool = pool
	events.enemies = enemies
	events.items = items
	events.drop_rule = drop_rule
	events.wallet = wallet
	events.economy = economy
	events.difficulty = chapter.difficulty
	events.scale_id = scale_id()
	events.player_spec = compile_player
	events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool):
		var key := "battles_won" if won else "battles_lost"
		tally[key] = int(tally.get(key, 0)) + 1)
	events.loot_ready.connect(func(_n: MapNode, corpse: GridInventory): _offer_loot(corpse))
	events.search_closed.connect(func(_n: MapNode, haul: GridInventory, _why: StringName): _offer_loot(haul))
	events.shop_opened.connect(func(_n: MapNode, session: ShopSession):
		if session != null:
			session.bought.connect(func(def: ItemDef, _price: int): storage.admit(ItemInstance.create(def, 0))))
	events.event_resolved.connect(func(_n: MapNode, _outcome: StringName, detail: Dictionary):
		for id in detail.get("items", []):
			var d := items.get_def(StringName(String(id)))
			if d != null:
				storage.admit(ItemInstance.create(d, 0)))
	events.defeated.connect(func(why: StringName): _set_phase(Phase.DEFEATED, why))
	events.bind(travel)


func _set_phase(p: int, reason: StringName) -> void:
	if phase == p:
		return
	phase = p
	end_reason = reason if is_over() else &""
	phase_changed.emit(phase, reason)
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"seed": run_seed,
		"chapter": String(chapter.id),
		"phase": phase,
		"end_reason": String(end_reason),
		"map": map.to_dict(),
		"travel": travel.to_dict(),
		"vitality": vitality.to_dict(),
		"wallet": wallet.to_dict(),
		"board": board.to_dict(),
		"storage": storage.to_dict(),
		"rng": rng.to_dict(),
		"events": {"searches_closed": events.searches_closed, "last_handled": events.last_handled_id},
		"pending_loot": pending_loot.to_dict() if pending_loot != null else null,
		"tally": tally.duplicate(),
	}


## 读回来。章节、内容库由调用方给（[RunSave] 按 id 取章节）。开着的商店 / 搜索会话不存：
## 存档那一刻视为离开了那个点（随时可以离开，5.4）
static func from_dict(
	d: Dictionary, p_chapter: ChapterDef, p_items: ItemDatabase, p_enemies: EnemyDatabase, p_sets: SetDatabase = null
) -> RunState:
	if int(d.get("version", -1)) != SAVE_VERSION or p_chapter == null:
		return null
	var s := RunState.new()
	s.run_seed = int(d.get("seed", 0))
	s.chapter = p_chapter
	s.items = p_items
	s.enemies = p_enemies
	s.sets = p_sets
	s._resolve_rules()
	s.map = MapGraph.from_dict(d.get("map", {}))
	s.travel = MapTravel.from_dict(d.get("travel", {}), s.map)
	s.vitality = Vitality.from_dict(d.get("vitality", {}))
	s.wallet = Wallet.from_dict(d.get("wallet", {}))
	s.board = GridInventory.from_dict(d.get("board", {}), p_items)
	s.storage = ItemStash.from_dict(d.get("storage", {}), p_items)
	s.rng = RunRNG.from_dict(d.get("rng", {}))
	s.travel.vitality = s.vitality
	s._bind_tracker()
	s._wire_events()
	s.events.searches_closed = int((d.get("events", {}) as Dictionary).get("searches_closed", 0))
	s.events.last_handled_id = int((d.get("events", {}) as Dictionary).get("last_handled", -1))
	for key in d.get("tally", {}):
		s.tally[String(key)] = int((d["tally"] as Dictionary)[key])
	var loot = d.get("pending_loot", null)
	if loot is Dictionary:
		s.pending_loot = GridInventory.from_dict(loot, p_items)
	s.phase = int(d.get("phase", Phase.PICK_SPAWN))
	s.end_reason = StringName(String(d.get("end_reason", "")))
	return s
#endregion

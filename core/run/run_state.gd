## 一局游戏的全部状态（架构文档 7 节，M5）：地图、旅程、体力、钱、棋盘、地上、节点事件、随机流。
##
## M4 结束时这些东西各自都能跑，只差一个装它们的壳 —— 这就是那个壳。它做三件事：
## 1. **开局**（[method start]）：从一章生成地图、放敌人、标付费撤离点、造棋盘与地上、把节点事件接到旅程上；
## 2. **接线**：打赢的战利品、搜到的东西、买到的东西、事件给的东西，都落到「待拾取」或地上；战败、撤离改阶段；
## 3. **存档**（[method to_dict] / [method from_dict]）：所有逻辑类都有 to_dict，这里只是把它们装进一个带版本号的字典。
##
## 纯 [RefCounted]，不是 autoload：核心逻辑层没有全局状态（1 节）。M6 的 GameDirector 持有它、给界面看。
## 内容库（道具、敌人、套装）由持有方给，存档里只写 id。
class_name RunState
extends RefCounted

## 存档从第一天就写版本号（7.2）
const SAVE_VERSION := 4
## 作战棋盘的尺寸（3.2：棋盘 + 包体）。占位，等角色系统
const BOARD_SIZE := Vector2i(8, 6)
const BOARD_ID := 1
const STORAGE_ID := 2
## 092：新加 class_name 的脚本用 preload 引用，作者拉了没重新 --import 也能跑
const SafePlacerScript := preload("res://core/run/safe_placer.gd")

enum Phase { PICK_SPAWN, ON_MAP, DEFEATED, EXTRACTED }

signal phase_changed(phase: int, reason: StringName)
## 有东西等着拾取（尸体容器 / 搜索收获）。拿走或丢掉之前不会再来第二份
signal loot_pending(container: GridInventory)
signal loot_cleared()
## 140 R-23：猎手、侵蚀、技能、信力的信号不再转发 —— 界面直接接模块（`hunters.sensed / changed / player_expelled`、
## `travel.erosion.warned / advanced / applied / total_reached`、`skills.changed`、`faith_power.changed`）
## 129：负重级数变了（0 = 轻装）。HUD 与地图屏听
signal encumbrance_changed(level: int)

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
## 地上：一个列表，保留但不参战（3.4）
var storage: ItemStash = null
## 092（作者定）：保险箱 —— 放进去的道具视为已带出，战败也带得出；大小按局外规则（初始 3×3）
## 092（作者定）：保险箱关上了 —— 里面的送回基地、不能再改；[param count] 是几件
var rng: RunRNG = null
var events: NodeEvents = null
## 101 第 3 刀：别人（节点事件、事件的条件与后果）要调一局的能力都经这张带类型的表。
## 骨架自己的那几条在 [method _wire_events] 里接，模块与机制在自己的 `install` 里接
var hooks: RunHooks = RunHooks.new()
var tracker: SetTracker = null
## 玩家自带的基线属性（4.2）。开局给了角色就是角色的；没给用持有方的 / 默认的
var player_baseline: CombatantBaseline = null
## 这一局的角色 id（067）；跟着存档，读档后持有方按它找回基线。空 = 没按角色开（老路、测试）
var character_id: StringName = &""
## 这一局选的地图规模（085：随机一局可选）；空 = 章节配置里默认的。跟着存档
var map_scale: StringName = &""
## 角色定义（开局给；读档由持有方按 id 找回）。技能编进 buff_context
var character: CharacterDef = null
## 这一局的进阶难度（069）：id 跟着存档，定义由持有方按 id 找回；null = 普通
var difficulty_id: StringName = &""
var difficulty: DifficultyDef = null
## 机制在一局上留的记号（`mechanic_tags[&"erosion"] = true`……），机制装的时候写，别处只读
var mechanic_tags: Dictionary = {}
## 101 第 0 刀：这一局装了哪些模块（id → [RunModule]）。**本类不认识任何具体模块** —— 加一种玩法不用改这里。
## 取一个用 [method module]（各模块通常还给一个带类型的 `of(run)`）
var modules: Dictionary = {}
## 开局时外面给模块的运行时输入（**不进存档**）：id → 字典。模块在 install 里读自己那份（[method module_input]）。
## 来源是局外规则、角色、开局屏（比如保险箱多大来自 [member MetaRules.safe_size]）；本类不解释里面的内容
var module_inputs: Dictionary = {}
## 读档拿到的各模块状态，等 install 时分发给它们
var modules_saved: Dictionary = {}
## 101：要离开当前这个点了（走一步 / 被事件挪走，**在真正动之前**发）。模块订阅它做「走开就……」的事 ——
## 保险箱关上、留在这个点的东西留下。参数是正要离开的点
signal leaving(node_id: int)
## 101：花掉了行动点（走一步、被事件挪走、原地耗时，**这一步该发生的事都发生完之后**发）。
## 模块订阅它做「走完一步才算的」事 —— 倒计时看看归零没有、赐福掷一次。
## [param reason] 是花在什么上：&"step" 自己走一步、&"relocate" 被事件挪走、&"wait" 原地耗时
signal stepped(node_id: int, reason: StringName)
## 101：到了一个点（头一回踩上、或者回到走过的点，**在这个点的事发生之前**发）。
## 模块订阅它做「到了就……」的事 —— 留在这个点的东西回到地上、相邻的道具合成。
## [param first_time] = 头一回踩上这个点
signal arrived(node_id: int, first_time: bool)
## 猎手（069 / 071）：难度清单里的猎手机制装进来的系统；null = 这一局没有猎手。定义表由持有方给，存档里的状态读档时先放这儿等机制装
var hunters: HunterSystem = null
var hunter_defs: Dictionary = {}
## 信仰定义（8-4）：持有方给，名字与说明用；激活规则只看棋盘上的标签（[FaithState]）
var faith_defs: Dictionary = {}
## 局内技能的账（082）：定义在角色上，这里记次数、冷却、旗子；没角色也有一份空的
var skills: RunSkills = null
## 读档回来的技能账，等持有方按 id 找回角色（[method set_character]）再接上
var skills_saved: Dictionary = {}
## 信力（082）：每个信仰一个池子，只有激活的信仰收点；行为与阈值在信仰文件里
var faith_power: FaithPower = null
## 104：对过账的道具实例（uid → true）：一件道具头一回出现在棋盘 / 地上 / 保险箱里发一次 `item_acquired`。只增不减，跟着存档
var owned_uids: Dictionary = {}
## 104：这一局获得过 / 置入过棋盘的道具种类（定义 id → true），给载荷的 first_in_run。跟着存档
var acquired_ids: Dictionary = {}
var placed_ids: Dictionary = {}
var hunters_saved: Dictionary = {}
## 侵蚀场的存档状态，读档时先放这儿等机制装（075）
var erosion_saved: Dictionary = {}

var pool: EnemyPool = null
var drop_rule: DropRule = null
## 126：敌人携带规则（章节引用；空 = 敌人不带非战斗道具）
var carry_rule: CarryRule = null
## 209：这一章的包池（[member ChapterDef.bag_pool]）；null = 不掷包
var bag_pool: BagPool = null
var node_rules: NodeRules = null
var economy: EconomyRules = null
## 129：负重规则（章节引用；空 = 这一章不算负重）
var encumbrance: EncumbranceRules = null
var _encumbrance_level: int = 0

var phase: int = Phase.PICK_SPAWN
var end_reason: StringName = &""
## 087：核心点的 BOSS 打倒了（作者定：收完战利品直接撤离结算，[method extract_after_boss]）。跟存档
var boss_cleared: bool = false
## 等着拾取的容器（尸体 / 搜索收获）；null = 没有
var pending_loot: GridInventory = null
## 173：读档时的修复报告（[RunSave.from_text] 给的；模块安置放不回原位的道具也记在这里）。null = 不记
var repair: SaveReport = null
## 159：搜索收获箱里哪件算「亮过」（uid → bool）—— 走开时开着的搜索只落亮过的，没亮的算没搜到（下次回来再搜还能亮）。
## [GameFlow] 接上它的 `seen_loot`；没接（纯核心）= 都算亮过
var loot_seen: Callable = Callable()
## 这一局的计数（给结算看）：打赢 / 打输几场；224 加其中精英 / 首领、翻过几个搜索点（同一个点只算一次）、合成几次。跟着存档走（旧档缺的键 = 0）
var tally: Dictionary = {"battles_won": 0, "battles_lost": 0, "elite_won": 0, "boss_won": 0, "searches": 0, "crafts": 0}
## 224：翻过的搜索点（点 id → true）—— tally.searches 同一个点只算一次。跟着存档走
var searched_nodes: Dictionary = {}
## buff（059）：定义表由持有方给（id → RunBuffDef，存档只写 id）；局外的在开局那一刻定下来跟着存档；
## 一局里的每条 {"id", "left"}（left = 还能走几步，-1 = 整局）
var buff_defs: Dictionary = {}
var meta_buffs: Array[StringName] = []
## 091：局外状态的引用（不存档；持有方 [GameFlow] 接上）—— 事件的条件 / 后果看、立局外旗标要用
var meta: MetaState = null:
	set(v):
		meta = v
		if events != null:
			events.meta = v
## 事件层（063）：定义表由持有方给（id → EventDef，存档只写 id）。空表 = 每个点踩上去直接发生
var event_defs: Dictionary = {}:
	set(v):
		event_defs = v
		if events != null:
			events.event_defs = v


#region 开局
## 从一章开一局。生成不出图返回 null。[param kit] 是开局带的道具 id（包放棋盘，其余先放包里、放不下到地上）。
## [param p_character] 给了就按角色来（棋盘尺寸、体力上限、基线、初始包）；[param p_layout] 是开局屏摆好的棋盘
## （[method layout_of] 的产物：哪件、放哪、什么朝向），先按它摆，再发 kit
## [param p_carry_funds]：这一局开局带多少钱（2026-10-22 作者定：玩家自己从仓库带，不带就是 0）
static func start(
	p_chapter: ChapterDef, p_seed: int, p_items: ItemDatabase, p_enemies: EnemyDatabase,
	p_sets: SetDatabase = null, kit: Array[StringName] = [] as Array[StringName],
	p_buff_defs: Dictionary = {}, p_meta_buffs: Array[StringName] = [] as Array[StringName],
	p_character: CharacterDef = null, p_layout: Array = [], p_difficulty: DifficultyDef = null, p_hunter_defs: Dictionary = {},
	p_scale: StringName = &"", p_module_inputs: Dictionary = {}, p_carry_funds: int = 0
) -> RunState:
	if p_chapter == null or p_chapter.map_source == null:
		return null
	var s := RunState.new()
	s.run_seed = p_seed
	s.chapter = p_chapter
	s.items = p_items
	s.enemies = p_enemies
	s.sets = p_sets
	s.map_scale = p_scale
	s.module_inputs = p_module_inputs.duplicate(true)
	s._resolve_rules()
	s.map = p_chapter.map_source.resolve(p_seed, p_scale)
	if s.map == null:
		return null
	ItemInstance.reset_uid_counter()
	SafePlacerScript.mark(s.map, p_chapter.safes)     # 092：先换点，再放敌人（换掉的点不该带敌人）
	if s.pool != null:
		EnemyPlacer.fill(s.map, s.pool, p_enemies, p_items, p_chapter.difficulty, s.scale_id(), s.carry_rule, s.bag_pool)
	EnemyPlacer.arrange_map(s.map, p_items)     # 165：预设图里没写位置的敌人道具（与相邻组）在这里摆一次、记进内容
	PaidExtracts.mark(s.map, s.economy)
	EventPlacer.fill(s.map, s.node_rules)
	ChestPlacer.roll(s.map, s.node_rules.chest if s.node_rules != null else null, p_chapter.chest_skin)     # 154：宝箱的稀有度与皮肤生成时就定
	s.rng = RunRNG.new(p_seed)
	# 局外 buff 在开局那一刻定下来：体力上限、开局钱按它们改（一局里的规则见 buff_context）
	s.buff_defs = p_buff_defs
	for id in p_meta_buffs:
		var def: RunBuffDef = p_buff_defs.get(id, null)
		if def != null and def.is_meta():
			s.meta_buffs.append(id)
	if p_difficulty != null:
		s.difficulty = p_difficulty
		s.difficulty_id = p_difficulty.id
	s.hunter_defs = p_hunter_defs
	var vitality_max := Vitality.PLACEHOLDER_MAX
	var board_size := BOARD_SIZE
	var full_kit := kit.duplicate()
	if p_character != null:
		s.set_character(p_character)
		vitality_max = p_character.vitality_max
		board_size = p_character.board_size
		if p_layout.is_empty():
			full_kit = p_character.starting_bags + kit
	full_kit.append_array(p_chapter.starting_items)     # 章节发的（序章二：一把匕首）
	var ctx := s.buff_context()     # 角色定了再算：技能的被动（体力上限、开局钱）也在里面（082）
	# 149：体力上限、开局钱按角色的基数乘科技的百分比再加加算；章节的体力加成在最后加
	s.vitality = Vitality.new(ctx.vitality_max_of(vitality_max) + p_chapter.vitality_bonus)
	# 2026-10-22（作者定）：开局的钱**全由玩家自己从仓库带**（[param p_carry_funds]），不再凭空发。
	# 原来那条水源（`EconomyRules.starting_balance` / `CharacterDef.starting_funds` / `starting_funds_bonus`）256 删了
	s.wallet = Wallet.new(maxi(0, p_carry_funds))
	s.board = GridInventory.new(board_size, BOARD_ID, true)
	if p_character != null:
		p_character.shape_board(s.board, p_items)     # 255：缺格与随身之物在开局屏的摆盘之前（它们不进 layout_of）
	s.storage = ItemStash.new(STORAGE_ID, 0)
	s._bind_tracker()
	place_layout(s.board, p_layout, p_items, s.storage)
	give_kit(s.board, full_kit, p_items, s.storage)
	s.travel = MapTravel.new(s.map, ActionClock.new())
	s._wire_events()
	s.install_modules()     # 模块要接的东西（旅程、节点事件）都造好了才装
	s._seed_owned()     # 104：带进来的不算「获得」
	# 084：章节说了「默认已经站在出生点上」（序章只有一个出生点，没什么可挑的）就直接站上去
	if p_chapter.auto_spawn and not s.map.entry_ids.is_empty():
		s.pick_spawn(s.map.entry_ids[0])
	return s


## 站到出生点上开局。返回 false = 不是出生点，或不在挑出生点阶段
func pick_spawn(id: int) -> bool:
	if phase != Phase.PICK_SPAWN or map == null or not map.entry_ids.has(id):
		return false
	map.demote_entries(id)     # 182：没挑的入口变普通搜索点、路线只留这一条
	travel.start_at(id)
	_set_phase(Phase.ON_MAP, &"spawn")
	return true


## 走一步。开着的商店 / 搜索先关掉（随时可以离开）；没拿的战利品、地上的东西都留在这个点上（3.4 / 084：离开就是清的时机）；
## 等着开打的一场没打不能走；不在图上走不了
func step_to(id: int) -> bool:
	if phase != Phase.ON_MAP or not events.pending_battle.is_empty() or not events.pending_ransom.is_empty():
		return false
	if not travel.available_moves().has(id):
		return travel.step_to(id)     # 让旅程自己拒绝、发 refused；走不成就不该清东西
	var was_visited := _leave_current(id)
	# 134：猎手的回合在进点之前（旅程的闸门 _arrival_gate 里）：够得着就先上猎手的事件屏、这个点的事挂起
	var ok := travel.step_to(id)
	if ok:
		_after_move(was_visited, &"step")
	return ok


## 要离开现在这个点了（走一步 / 被事件挪走同一条路）：对账、关会话、丢待拾取、忘掉「发生过事的点」、发 [signal leaving]。
## 顺序不能动：leaving 必须在 _forget_handled 之后、真正动身之前。返回目的地 [param to_id] 走过没有
func _leave_current(to_id: int) -> bool:
	reconcile_owned()     # 104：地上留下之前对账，这个点上拿到的都算获得
	_abandon_sessions()
	_forget_handled()
	leaving.emit(travel.current_id)     # 101：走开了 —— 模块自己接（保险箱关上、地上留在这个点）
	return map.has_node(to_id) and map.get_node(to_id).is_visited()


## 动完了（走到了 / 挪到了）：回到走过的点再发一次「到了」，技能走一步，发 [signal stepped]
func _after_move(was_visited: bool, reason: StringName) -> void:
	if was_visited and not travel.is_holding():
		_arrived_again(travel.current_id)
	skills.on_step()     # 冷却与躲避在猎手的回合之后减：躲 3 步就是 3 个猎手回合够不着（082）
	stepped.emit(travel.current_id, reason)     # 101：走完一步 —— 模块自己接（赐福、倒计时归零 = 行动失败）


## 回到走过的点（头一回踩的在 _on_arrive 里已经发过）
func _arrived_again(id: int) -> void:
	arrived.emit(id, false)
	# 作者 2026-10-12：上回选了「先回地图」的点：回来同一个事件再弹（门禁不能借走开跳过）
	if events != null and map.has_node(id) and bool(map.get_node(id).content.get("revisit_event", false)):
		map.get_node(id).content.erase("revisit_event")
		events.handle(map.get_node(id))
		return
	# 091（作者定）：商店可以回头再逛 —— 回到走过的商店点就把店再开起来；货架 / 刷新次数 / 卖掉的都记在节点内容里，刷新价不重置
	if events != null and map.has_node(id) and NodeEvents.effective_type(map.get_node(id)) == &"shop":
		events.reopen_shop(map.get_node(id))


## 134：旅程的进点闸门 —— 人已经挪到点上、步数花了、惩罚结算了，这个点的事发生之前：先过猎手的回合（出现、移动、感知、开打）。
## 有猎手够得着（开打前的事件屏排上了）就挂起这次进点，等那一场了结后 [method resume_arrival] 接着进；输给驱逐档的取消（视为没进）
func _arrival_gate(_intent: MoveIntent, _first_visit: bool) -> bool:
	if hunters == null:
		return false
	hunters.on_player_step()
	return events != null and int(events.pending.get("hunter", -1)) >= 0


## 134：有挂起的进点吗（猎手在进点之前追上了，这个点的事还没发生）
func has_pending_arrival() -> bool:
	return travel != null and travel.is_holding()


## 134：猎手那一场了结了（赢了、逃掉了、输了但是击退档）：接着进挂起的那个点 —— 这个点的事现在发生。
## 还有等着选的事件 / 等着开打的一场时不接（先处理那些）。返回接没接
func resume_arrival() -> bool:
	if not has_pending_arrival() or is_over() or phase != Phase.ON_MAP:
		return false
	if events != null and (not events.pending.is_empty() or not events.pending_battle.is_empty() or not events.pending_ransom.is_empty()):
		return false
	var first := bool(travel.held.get("first", false))
	if not travel.finish_arrival():
		return false
	if not first:
		_arrived_again(travel.current_id)
	return true


## 事件把人挪走（8-3 的传送后果）：不走边，但离开发生过事的点照样清地上、猎手照样得一个回合 —— 和走一步一样的壳，只是意图不同
func relocate(intent: MoveIntent) -> bool:
	if phase != Phase.ON_MAP or intent == null:
		return false
	var was_visited := _leave_current(intent.to_id)     # 101：事件把人挪走也算走开
	var ok := travel.apply(intent)     # 134：猎手的回合在闸门里，先于落地那个点的事
	if ok:
		_after_move(was_visited, &"relocate")
	return ok


## 玩家空下来了（叠层看完、会话关了）问一声猎手够不够得着；够得着就开打前的事件屏已经排上。
## 134：没有猎手要打、又有挂起的进点（猎手那一场了结了）就接着进那个点。返回有没有事发生
func poke_hunters() -> bool:
	if hunters != null and hunters.check_engagement():
		return true
	return resume_arrival()


## 按 id 取一个敌人池资产（猎手可以指定自己的池）
func pool_by_id(id: StringName) -> EnemyPool:
	return _rule_asset("enemy_pools", id) as EnemyPool


## 走出现在这个点会不会把地上留下（087：留在这个点、回来能拿；不再是「清掉」）。
## 规则与状态都在 [NodeStorageModule] 里；没装那个模块 = 走开什么也不留
func will_clear_storage() -> bool:
	var ns := NodeStorageModule.of(self)
	return ns != null and ns.will_drop()


## 离开了就不再算「发生过事的点」：回头再路过一次不会又清一遍
func _forget_handled() -> void:
	if events != null and travel != null and events.last_handled_id == travel.current_id:
		events.last_handled_id = -1


## 头一回踩上一个点：先发「到了」（按点暂存的东西回到地上），再结等着的合成（产物放不下就到地上），
## 再让那个点的事发生 —— 顺序不能反，不然合成的产物没地方去、事件给的东西看不见
func _on_arrive(node: MapNode) -> void:
	if node != null:
		arrived.emit(node.id, true)     # 按点暂存先还回来，再合成（模块按清单顺序接线）—— 顺序不能反
	events.handle(node)


## 084：没拿完的战利品（尸体 / 搜索收获）留在这个点上 —— 收起战利品屏不算丢。
## 159（作者定）：走了也不丢 —— 倒到这个点的地上（和地上原来的东西一样跟着点走，回来再拿）；包先倒空、再放空包。
## [param skip] 里的 uid 不落（走开时开着的搜索里没亮过的：算没搜到）
func _drop_pending_loot(skip: Dictionary = {}) -> void:
	if pending_loot == null:
		return
	var loot := pending_loot
	var bags: Array[ItemInstance] = []
	for it in loot.items().duplicate():
		var inst := it as ItemInstance
		if inst.def != null and inst.def.is_bag:
			bags.append(inst)
			continue
		loot.remove(inst.uid)
		if not skip.has(inst.uid):
			storage.admit(inst)
	for bag in bags:
		loot.remove(bag.uid)
		if not skip.has(bag.uid):
			storage.admit(bag)
	pending_loot = null
	loot_cleared.emit()


## 走开、撤离、失败都先做这两件：开着的会话关掉、没拿的战利品落到地上（159：原来是丢掉）
func _abandon_sessions() -> void:
	var unseen := _unseen_search_haul()     # 关会话之前记：关的时候收获箱整箱交出去、都记成见过
	close_sessions()
	_drop_pending_loot(unseen)


## 作者 2026-10-16（关搜索屏时左边的道具直接掉到地上；离开点不该再弹提醒）：搜索收获箱 [param haul] 里亮过的倒到这个点的地上
## （包最后放，同 [method _drop_pending_loot]）；没亮过的留在箱里 —— 还开着的会话下次再搜接着揭示，会话收了就算没搜到。
## 没接 [member loot_seen] = 都算亮过。返回倒了几件
func drop_seen_haul(haul: GridInventory) -> int:
	if haul == null or storage == null:
		return 0
	var bags: Array[ItemInstance] = []
	var n := 0
	for it in haul.items().duplicate():
		var inst := it as ItemInstance
		if loot_seen.is_valid() and not bool(loot_seen.call(inst.uid)):
			continue
		if inst.def != null and inst.def.is_bag:
			bags.append(inst)
			continue
		haul.remove(inst.uid)
		storage.admit(inst)
		n += 1
	for bag in bags:
		haul.remove(bag.uid)
		storage.admit(bag)
		n += 1
	return n


## 159：开着的搜索收获箱里还没亮过的 uid（没接 [member loot_seen] = 都算亮过）
func _unseen_search_haul() -> Dictionary:
	var out := {}
	var session: SearchSession = events.current_search if events != null else null
	if session == null or not session.active or not loot_seen.is_valid():
		return out
	for it in session.haul_box.items():
		var uid := (it as ItemInstance).uid
		if not bool(loot_seen.call(uid)):
			out[uid] = true
	return out


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
	var cd := CountdownModule.of(self)
	if cd != null and cd.extract_closed(node):
		return false     # 092：倒计时过半关掉的撤离点
	if not events.pay_extract_fee(node):
		return false
	_abandon_sessions()
	_set_phase(Phase.EXTRACTED, &"extract")
	return true


## 087（作者定）：BOSS 倒下之后直接撤离结算 —— 不看站在哪、不付费。没打倒 BOSS / 已经结束返回 false
func extract_after_boss() -> bool:
	if not boss_cleared or is_over():
		return false
	_abandon_sessions()
	_set_phase(Phase.EXTRACTED, &"boss")
	return true


## **只给演示与测试用**（101 第 6 刀；原来是 `tools/demo_fill.gd` 的前身在导演里直接写 `phase` 与 `end_reason`）：
## 不看站在哪、不付费、不结算撤离点，直接把这一局记成撤离成功。正式游戏走 [method try_extract] / [method extract_after_boss]。
## 已经结束返回 false
func force_extract() -> bool:
	if is_over():
		return false
	_abandon_sessions()
	_set_phase(Phase.EXTRACTED, &"extract")
	return true


## 行动失败（101）：这一局当场结束 —— 开着的会话关掉、没拿的战利品丢掉、排着的事清掉，阶段进战败。
## 模块用它（倒计时归零就是这么失败的）；[param reason] 进结算与战绩。返回这次有没有真的失败
func fail(reason: StringName) -> bool:
	if is_over():
		return false
	_abandon_sessions()
	if events != null:
		events.pending_battle = {}
		events.pending = {}
		events.pending_ransom = {}
	_set_phase(Phase.DEFEATED, reason)
	return true


func is_over() -> bool:
	return phase == Phase.DEFEATED or phase == Phase.EXTRACTED
#endregion


#region buff
## 现在激活的 buff 定义：局外的 + 一局里的
func active_buff_defs() -> Array:
	var out: Array = []
	for id in meta_buffs:
		var def: RunBuffDef = buff_defs.get(id, null)
		if def != null:
			out.append(def)
	var buff := BuffModule.of(self)     # 101：一局里拿到的 buff 在模块里
	if buff != null:
		out.append_array(buff.defs())
	return out


## 一局的规则被 buff 改成了什么样（每次算，便宜）
func buff_context() -> RunContext:
	var ctx := RunBuffs.context(active_buff_defs())
	# 进阶难度的数值修饰、角色的被动技能走同一条路（069 / 072）
	if difficulty != null:
		for e in difficulty.run_effects():
			e.modify(ctx)
	if character != null:
		for e in character.run_effects():
			e.modify(ctx)
	return ctx


## 101 第 0 刀：把这一局的模块接进来（开局与读档各一次；模块必须幂等）。三层叠加：
## 章节列的本体功能（没列就是 [method RunModules.standard]）+ 难度列的机制（069）+ 跑起来之后临时加的。
## 本类不认识任何具体模块，顺序就是清单顺序
func install_modules() -> void:
	var body: Array = chapter.modules if chapter != null and not chapter.modules.is_empty() else RunModules.standard()
	for m in body:
		install_module(m as RunModule)
	if difficulty != null:
		for m in difficulty.mechanics:
			install_module(m as RunModule)


## 装一个模块：有存档就先交给它，再让它自己接进这一局。重复 id 不覆盖（幂等，读档会再调一遍）。返回装没装
func install_module(m: RunModule) -> bool:
	if m == null:
		return false
	var mid := m.id()
	if mid != &"":
		if modules.has(mid):
			modules[mid].install(self)     # 已经装过：再 install 一次（幂等），不换对象
			return false
		var saved: Variant = modules_saved.get(String(mid), null)
		if saved is Dictionary:
			m.restore(saved as Dictionary)
		modules[mid] = m
	m.install(self)
	return true


## 这一局装着的某个模块（没装返回 null）
func module(mid: StringName) -> RunModule:
	return modules.get(mid, null)


## 外面给某个模块的运行时输入（没有就是空字典）
func module_input(mid: StringName) -> Dictionary:
	var d: Variant = module_inputs.get(mid, null)
	return d as Dictionary if d is Dictionary else {}


## 装着的模块各说一句（开局屏的规则卡）
func module_lines() -> Array[String]:
	var out: Array[String] = []
	for mid in modules:
		var line := (modules[mid] as RunModule).describe()
		if line != "":
			out.append(line)
	return out


## 激活的 buff 里有没有带这个标记的（事件选项的条件查它）
func has_buff_tag(tag: StringName) -> bool:
	return RunBuffs.has_tag(active_buff_defs(), tag)


#endregion


#region 背包与战利品
## 开战那一刻编译玩家（4.2 是纯函数；套装的战斗侧效果从 tracker 取，buff 的并进去；
## 082：技能的基线加成盖到基线上，信力的阶传给编译器解锁信仰道具的功能）
func compile_player() -> CombatantSpec:
	var active := active_buff_defs()
	var mods: Array[StatModifier] = tracker.combat_mods() if tracker != null else [] as Array[StatModifier]
	var rules: Array[AbilityRule] = tracker.combat_rules() if tracker != null else [] as Array[AbilityRule]
	mods.append_array(RunBuffs.combat_mods(active))
	rules.append_array(RunBuffs.combat_rules(active))
	if character != null:
		rules.append_array(character.combat_rules())     # 136：角色技能的战斗规则（布鲁图斯「坚韧」）
	var baseline := effective_baseline()
	var input := CompileInput.of(baseline, mods, rules,
		faith_power.tiers() if faith_power != null else {},
		faith_power.points_by_tag() if faith_power != null else {})
	# 129：负重减益（急速给每件参战道具，耐力回复 / 上限按基线折成真值给基线；不碰伤害）
	if encumbrance != null:
		var enc := encumbrance.combat_mods(encumbrance_level(), baseline)
		input.mods.append_array(enc["items"])
		input.baseline_mods.append_array(enc["baseline"])
	# 105：按件随机挑选的种子。一局之内只随步数变，所以拖动预估挑的和真打挑的是同一批
	input.seed = hash("%d:compile:%d" % [run_seed, travel.clock.total if travel != null and travel.clock != null else 0])
	input.scoped.append_array(buff_context().scoped)     # 256：一局被动的按件修饰（操练：武器耐力消耗 −20%）
	var altar := AltarModule.of(self)     # 093：信仰级效果往编译器的入参里放东西（顺序 = 文件里的顺序）
	if altar != null:
		var bonus := altar.axes()     # 祈祷攒的轴层数（105）
		for axis in bonus:
			input.shift_axis(axis, int(bonus[axis]))
		for p in altar.perks():
			(p as FaithPerk).compile_into(input, board, self)
	var spec := BattleCompiler.compile(board, input)
	spec.passives = BattlePassives.of(self)     # 103：常驻加成也进 buff 栏
	return spec


## 093：一场战斗的账（喂给信力的行为）：{won, node_type, dealt: {类型: 量}, taken: {类型: 量}, healed, fired_total, fired_items: [{id, tags, cells, count}]}。
## 量是浮点（定点换回来）。dealt = 敌方受的伤（不管谁打的，反射也算）；taken = 我方受的；healed = 我方战斗内回的血；
## fired = 我方道具**真的出手**的次数（因耐力 / 资源不足跳过的那次不发 ITEM_FIRED，自然不算）
static func battle_summary(result: BattleResult, won: bool, p_board: GridInventory, node_type: StringName = &"") -> Dictionary:
	var out := {"won": won, "node_type": String(node_type), "dealt": {}, "taken": {}, "healed": 0.0, "fired_total": 0, "fired_items": []}
	if result == null:
		return out
	var fired := {}
	for ev in result.log:
		var e := ev as BattleEvent
		if e == null:
			continue
		match e.name:
			BattleEvent.DAMAGE:
				var amt := StatMath.to_float(int(e.payload.get("amount", 0)))
				if amt <= 0.0:
					continue
				var type := String(e.payload.get("type", "physical"))
				var bucket: Dictionary = out["dealt"] if e.side == 1 else out["taken"]
				bucket[type] = float(bucket.get(type, 0.0)) + amt
			BattleEvent.RESOURCE_CHANGED:
				if e.side == 0 and String(e.payload.get("key", "")) == String(BattleStats.RES_HP) and String(e.payload.get("reason", "")) == String(BattleEvent.REASON_HEAL) and int(e.payload.get("delta", 0)) > 0:
					out["healed"] = float(out["healed"]) + StatMath.to_float(int(e.payload["delta"]))
			BattleEvent.ITEM_FIRED:
				if e.side == 0:
					var uid := int(e.payload.get("uid", 0))
					fired[uid] = int(fired.get(uid, 0)) + 1
					out["fired_total"] = int(out["fired_total"]) + 1
	for uid in fired:
		var inst := p_board.get_item(int(uid)) if p_board != null else null
		var tags: Array = []
		if inst != null and inst.def != null:
			for t in inst.def.tags:
				tags.append(String(t))
		(out["fired_items"] as Array).append({"id": String(inst.def.id) if inst != null and inst.def != null else "", "tags": tags,
			"cells": ItemVolume.cells_of(inst.def) if inst != null else 0, "count": int(fired[uid])})
	return out


#region 信仰（093）
## 激活信仰现在第几阶；没激活 -1
func active_faith_tier() -> int:
	var def := active_faith()
	return faith_power.tier_of(def.id) if def != null and faith_power != null else -1
#endregion


## 角色基线 + 技能 / buff 的基线加成。没有加成就是原来那份。
## 149：133 的公式 —— 角色面板 ×（1 + Σ乘算%）+ Σ加算（科技 / 技能的 stat_bonus，再加神坛的）；乘算之间相加不相乘
func effective_baseline() -> CombatantBaseline:
	var ctx := buff_context()
	var altar := AltarModule.of(self)
	var faith_stat_bonus: Dictionary = altar.stat_bonus if altar != null else {}
	if ctx.stat_bonus.is_empty() and ctx.stat_mult.is_empty() and faith_stat_bonus.is_empty():
		return player_baseline
	var base := player_baseline if player_baseline != null else CombatantBaseline.default_baseline()
	var b := CombatantBaseline.new()
	b.base_stats = base.base_stats.duplicate()
	for key in ctx.stat_mult:
		var km := StringName(String(key))
		b.base_stats[km] = float(b.base_stats.get(km, BattleStats.default_value(km))) * (1.0 + float(ctx.stat_mult[key]) / 100.0)
	for key in ctx.stat_bonus:
		var k := StringName(String(key))
		b.base_stats[k] = float(b.base_stats.get(k, 0.0)) + float(ctx.stat_bonus[key])
	for key in faith_stat_bonus:     # 093：神坛特殊操作改的基线（倍率类属性从 1.0 起）
		var k2 := StringName(String(key))
		b.base_stats[k2] = float(b.base_stats.get(k2, BattleStats.default_value(k2))) + float(faith_stat_bonus[key])
	return b


## 按角色来：基线、技能的账（开局与读档各一次；读档回来的账在这里接上定义）
func set_character(ch: CharacterDef) -> void:
	character = ch
	character_id = ch.id if ch != null else &""
	player_baseline = ch.baseline() if ch != null else player_baseline
	_ensure_skills()
	skills.setup(self, ch.skills if ch != null else [] as Array[RunSkill])
	if not skills_saved.is_empty():
		skills.restore(skills_saved)
		skills_saved = {}
	skills.changed.emit()
	refresh_encumbrance()     # 129：上限跟着角色


#region 负重（129）
## 负重：作战棋盘上每件（含包本身）的重量之和。地上、保险箱、仓库不算。派生，不存档
func carry_weight() -> int:
	return ItemWeight.total_scaled(board, buff_context().weight_pct)     # 256：操练的武器减重


## 负重上限 = 角色的 ×（1 + 科技的百分比）+ 加算（[method RunContext.carry_capacity_of]，149）。0 = 不算负重（没角色、角色没配）
func carry_capacity() -> int:
	if character == null or character.weight_capacity <= 0:
		return 0
	return buff_context().carry_capacity_of(character.weight_capacity)


## 现在第几级（0 = 轻装）。这一章没开负重恒为 0
func encumbrance_level() -> int:
	if encumbrance == null:
		return 0
	return encumbrance.level_of(carry_weight(), carry_capacity())


## 「负重 23 / 28　吃力」；这一章不算负重返回空
func encumbrance_line() -> String:
	if encumbrance == null or carry_capacity() <= 0:
		return ""
	var lv := encumbrance_level()
	return UiText.t("log.load_line") % [carry_weight(), carry_capacity(), encumbrance.name_of(lv)]


## 重算级数：写进走路的倍数，级数真变了才发 [signal encumbrance_changed]。棋盘变了、换了角色、开局 / 读档后调
func refresh_encumbrance() -> void:
	var lv := encumbrance_level()
	if travel != null:
		travel.action_cost_mult = encumbrance.travel_mult_of(lv) if encumbrance != null else 1
		travel.free_step_every = buff_context().free_step_every     # 136：熟门熟路（角色定了、读档接上角色都会走这里）
	if lv != _encumbrance_level:
		_encumbrance_level = lv
		encumbrance_changed.emit(lv)
#endregion


func _ensure_skills() -> void:
	if skills != null:
		return
	skills = RunSkills.new()
	skills.setup(self, [] as Array[RunSkill])


## 地图上用一个局内技能（082）。返回空串 = 用了；否则是不能用的原因
func use_skill(id: StringName) -> String:
	if phase != Phase.ON_MAP:
		return UiText.t("log.not_on_map")
	return skills.use(id)


## 现在激活的信仰（8-4）：最后置入棋盘的信仰道具所属的那个；一件都没有 = null（不信者）
func active_faith() -> FaithDef:
	return faith_defs.get(FaithState.active_id(board), null) if board != null else null


## 激活的信仰 id；没有返回空
func active_faith_id() -> StringName:
	return FaithState.active_id(board) if board != null else &""


## 给界面的一句：「信仰：暴力之神」/「信仰：无」；定义表里没有的按 id 写
func faith_line() -> String:
	var id := active_faith_id()
	if id == &"":
		return UiText.t("log.faith_none")
	var def := active_faith()
	return UiText.t("log.faith_line") % (Names.of(def) if def != null else String(id))


## 掉落上下文（6.1）：难度、buff 给的幸运；道具与套装的战利品效果（9.2）、buff 的掉落效果都施加上去
func _loot_context() -> LootContext:
	var ctx := LootContext.new()
	ctx.difficulty = chapter.difficulty if chapter != null else 0
	var active := active_buff_defs()
	ctx.luck = RunBuffs.context(active).luck_bonus
	if tracker != null:
		for e in tracker.effects_in_scope(EffectScope.LOOT):
			(e as LootEffect).modify(ctx)
	RunBuffs.apply_loot(active, ctx)
	if difficulty != null:
		for e in difficulty.loot_effects():
			e.modify(ctx)
	if character != null:
		for e in character.loot_effects():
			e.modify(ctx)
	var here := current_node()
	var altar := AltarModule.of(self)
	if altar != null:
		for p in altar.perks():     # 093（日神 4 级）
			(p as FaithPerk).modify_loot(ctx, NodeEvents.effective_type(here) if here != null else &"")
	return ctx


## 从待拾取的容器里拿一件到地上
func take_loot(uid: int) -> bool:
	if pending_loot == null:
		return false
	var ok := InventoryService.transfer_auto(pending_loot, uid, storage)
	if pending_loot.item_count() == 0:
		discard_loot()
	return ok


## 全拿走，返回拿了几件。123：每件先试背包棋盘，放不下才到地上
func take_all_loot() -> int:
	if pending_loot == null:
		return 0
	var got := InventoryService.transfer_all_prefer(pending_loot, board, storage)
	var n: int = got["board"] + got["storage"]
	discard_loot()
	return n


## 反馈（搜索里遇敌，打赢之后）：尸体的战利品屏关掉、接着搜的时候，没拿的不再和搜索的收获并成一份重新搜 ——
## 道具并进搜索的收获箱（搜索屏里接着拿，亮过的不重亮），包掉在地上（收获箱是自由容器，收不下摆好的一袋；包里的东西先倒进收获箱）。
## 收获箱加高到两倍还放不下的也到地上，一件不丢。没有开着的搜索 / 没有待拾取返回 false
func fold_loot_into_search() -> bool:
	var session: SearchSession = events.current_search if events != null else null
	if pending_loot == null or session == null or not session.active:
		return false
	var loot := pending_loot
	var bags: Array[ItemInstance] = []
	for it in loot.items().duplicate():
		var inst := it as ItemInstance
		if inst.def != null and inst.def.is_bag:
			bags.append(inst)
			continue
		loot.remove(inst.uid)
		if not session.stow(inst):
			storage.admit(inst)
	for bag in bags:
		loot.remove(bag.uid)     # 内容物已经倒出去了，是空包
		storage.admit(bag)
	pending_loot = null
	loot_cleared.emit()
	return true


## 剩下的不要了
func discard_loot() -> void:
	if pending_loot == null:
		return
	pending_loot = null
	loot_cleared.emit()


## 地上 → 棋盘（自动找位）
func equip(uid: int) -> bool:
	return InventoryService.transfer_auto(storage, uid, board)


## 棋盘 → 地上
func unequip(uid: int) -> bool:
	return InventoryService.transfer_auto(board, uid, storage)


## 棋盘 / 地上哪个装着这一件：棋盘有就是棋盘，否则地上有就是地上，都没有 null（神坛 / 保险箱「从棋盘或地上拿一件」用）
func holder_of(uid: int) -> ItemContainer:
	if board.has_item(uid):
		return board
	if storage.has_item(uid):
		return storage
	return null


func _offer_loot(container: GridInventory) -> void:
	if container == null or container.item_count() == 0:
		return
	if pending_loot != null:
		# 上一份还没处理就来了新的（搜索收获 + 遭遇的尸体）：并成一份，一件都不丢。
		# 087：尸体容器可能是棋盘模式（包当背景），两边都往一块够大的自由容器里搬，放不下就加高
		# 反馈：两边高度直接相加会把界面撑出窗口。按搜索规则的收获箱大小起步，装不下一格一格加高；
		# 加到两倍还没装完仍接着加（一件都不丢）
		var haul := node_rules.search.haul_board if node_rules != null and node_rules.search != null else Vector2i(6, 4)
		var w := maxi(maxi(pending_loot.size.x, container.size.x), haul.x)
		var h := maxi(haul.y, 1)
		var merged := GridInventory.new(Vector2i(w, h), 0, false)
		InventoryService.transfer_all(pending_loot, merged)
		InventoryService.transfer_all(container, merged)
		var guard := 0
		while (pending_loot.item_count() > 0 or container.item_count() > 0) and guard < 64:
			guard += 1
			var bigger := GridInventory.new(merged.size + Vector2i(0, 1), 0, false)
			InventoryService.transfer_all(merged, bigger)
			merged = bigger
			InventoryService.transfer_all(pending_loot, merged)
			InventoryService.transfer_all(container, merged)
		container = merged
	pending_loot = container
	loot_pending.emit(container)


## 开局屏摆好的棋盘怎么记：一件一行（定义 id、落点、朝向）。不记实例：一局的 uid 从 1 重编，进来时重造
static func layout_of(board: GridInventory) -> Array:
	var out: Array = []
	if board == null:
		return out
	var rows: Array = []
	for inst in board.items():
		if not (inst as ItemInstance).is_pinned():     # 255：随身之物由角色在开局时自己钉（[method CharacterDef.shape_board]）
			rows.append(inst)
	# 包先摆（普通物品要落在包里），其余按 uid 顺序，稳定
	rows.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if a.def.is_bag != b.def.is_bag:
			return a.def.is_bag
		return a.uid < b.uid)
	for inst in rows:
		var it := inst as ItemInstance
		var row := {"id": String(it.def.id), "origin": [it.origin.x, it.origin.y], "rot": it.rotation}
		if not it.state.is_empty():
			row["state"] = it.state.duplicate(true)     # 148：魔晶石剩几次跟着带进来
		out.append(row)
	return out


## 按 [method layout_of] 的记录摆上棋盘（开局与校准快照 [CalibrationRecorder] 同一条路）：摆不回去的（棋盘换了、定义没了）先自动找位，
## 还放不下的到 [param overflow]（开局是地上；null = 丢掉）
static func place_layout(board: GridInventory, layout: Array, items: ItemDatabase, overflow: ItemContainer = null) -> void:
	if items == null:
		return
	board.begin_batch()
	for row in layout:
		if not (row is Dictionary):
			continue
		var d := items.get_def(StringName(String(row.get("id", ""))))
		if d == null:
			continue
		var at: Array = row.get("origin", [0, 0])
		var inst := ItemInstance.create(d, 0)
		var saved_state: Variant = row.get("state", null)
		if saved_state is Dictionary:
			inst.state = (saved_state as Dictionary).duplicate(true)
		if not board.place(inst, Vector2i(int(at[0]), int(at[1])), int(row.get("rot", 0))) and not board.try_add(inst, true) and overflow != null:
			overflow.admit(inst)
	board.end_batch()


## 按清单发一套道具（开局的 kit 与校准的开局装备 [DummyBuilder] 同一条路）：包先上棋盘，其余按顺序自动找位、
## 放不下的到 [param overflow]（开局是地上；null = 丢掉）
static func give_kit(board: GridInventory, kit: Array[StringName], items: ItemDatabase, overflow: ItemContainer = null) -> void:
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
		if not board.try_add(inst, true) and overflow != null:
			overflow.admit(inst)
	board.end_batch()
#endregion


#region 接线
func _resolve_rules() -> void:
	if enemies != null and chapter.enemy_pool != &"":
		pool = enemies.pool(chapter.enemy_pool)
	drop_rule = _rule_asset("drop_rules", chapter.drop_rule) as DropRule
	carry_rule = _rule_asset("carry_rules", chapter.carry_rule) as CarryRule
	bag_pool = _rule_asset("bag_pools", chapter.bag_pool) as BagPool
	encumbrance = _rule_asset("encumbrance_rules", chapter.encumbrance_rules) as EncumbranceRules
	node_rules = _rule_asset("node_rules", chapter.node_rules) as NodeRules
	economy = _rule_asset("economy_rules", chapter.economy_rules) as EconomyRules


static func _rule_asset(kind: String, id: StringName) -> Resource:
	return ContentPaths.load_asset(kind, String(id)) if id != &"" else null


## 这一章的规模 id（有规模模板的生成器才有）
func scale_id() -> StringName:
	if map_scale != &"":
		return map_scale
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
	events.chest_skin = chapter.chest_skin if chapter != null else &"ruins"     # 154
	events.pool = pool
	events.enemies = enemies
	events.items = items
	events.drop_rule = drop_rule
	events.carry_rule = carry_rule
	events.bag_pool = bag_pool
	events.difficulty_def = difficulty
	events.wallet = wallet
	events.economy = economy
	events.difficulty = chapter.difficulty
	events.scale_id = scale_id()
	events.event_defs = event_defs
	# 8-3：条件看容器，后果传送 / 耗时经这里走（清地上、猎手回合）
	events.board = board
	events.storage = storage
	events.hooks = hooks
	# 骨架接自己的那几条（模块与机制各接自己的，见 RunHooks.NAMES）
	hooks.register(&"player_spec", compile_player)
	hooks.register(&"loot_context", _loot_context)
	hooks.register(&"run_context", buff_context)
	hooks.register(&"has_buff_tag", has_buff_tag)
	hooks.register(&"bracket", func() -> int: return hunters.bracket() if hunters != null else -1)
	hooks.register(&"relocate", relocate)
	hooks.register(&"request_extract", try_extract)     # 085：撤离点的对话里选「撤离」
	hooks.register(&"faith_tier", active_faith_tier)     # 093：事件条件 faith_active
	hooks.register(&"active_faith_id", active_faith_id)
	hooks.register(&"skill_ready", func(id: StringName) -> String: return skills.can_use(id) if skills != null else UiText.t("log.no_skill"))
	events.waited.connect(func(_n: MapNode, _actions: int):
		if hunters != null:
			hunters.on_player_step()
		stepped.emit(travel.current_id, &"wait"))
	events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): _tally_battle(won))
	events.rested.connect(func(_n: MapNode, _got: int): skills.on_rest())     # 256：偷袭在休息点补一次
	events.search_opened.connect(func(n: MapNode, _s: SearchSession): _tally_search(n))
	events.loot_ready.connect(func(_n: MapNode, corpse: GridInventory): _offer_loot(corpse))
	events.search_closed.connect(func(_n: MapNode, haul: GridInventory, _why: StringName): drop_seen_haul(haul))     # 作者 2026-10-16：不再弹战利品屏
	events.shop_opened.connect(func(_n: MapNode, session: ShopSession):
		if session != null:
			# 087：双击 / 按钮买的（inst 由会话交出来）先试着进包、放不下到地上；拖着买的已经在玩家手里了（inst 为 null）
			session.bought.connect(func(_def: ItemDef, _price: int, inst: ItemInstance):
				if inst != null and not board.try_add(inst, true):
					storage.admit(inst)))
	events.event_resolved.connect(func(_n: MapNode, _outcome: StringName, detail: Dictionary):
		# 157：收到地上的那几件 uid 记回 detail —— 事件结果页的「收获」行按它把这几件摆出来
		var uids: Array = []
		for id in detail.get("items", []):
			var d := items.get_def(StringName(String(id)))
			if d != null:
				var inst := ItemInstance.create(d, 0)
				if storage.admit(inst):
					uids.append(inst.uid)
		if not uids.is_empty():
			detail["item_uids"] = uids)
	events.defeated.connect(func(why: StringName): _set_phase(Phase.DEFEATED, why))
	events.boss_defeated.connect(func(_n: MapNode): boss_cleared = true)
	events.bind(travel)
	# 进入的那一次检查插在节点事件前面（bind 把 handle 挂上了，这里再包一层）
	travel.on_node_event = _on_arrive
	travel.arrival_gate = _arrival_gate     # 134：猎手战插在进点的事件队列前面
	# 082：技能与信力
	_ensure_skills()
	hooks.register(&"before_battle", func(me: CombatantSpec, enemy: CombatantSpec, _type: StringName) -> void:
		skills.prepare_battle(me, enemy))     # 开打前：立了旗的技能改双方的战斗单位
	faith_power = FaithPower.new()
	faith_power.setup(self)
	_wire_faith_power()
	board.changed.connect(refresh_encumbrance)     # 129
	_encumbrance_level = encumbrance_level()
	refresh_encumbrance()


## 信力的行为（082）：一局里的事喂给激活信仰的行为构件。哪些事、载荷长什么样见 [FaithDeed]
func _wire_faith_power() -> void:
	board.placed.connect(func(inst: ItemInstance):
		if inst != null and inst.def != null:
			var first := not placed_ids.has(String(inst.def.id))
			placed_ids[String(inst.def.id)] = true
			faith_power.credit(&"place_item", {"value": ItemValue.of(inst.def), "id": String(inst.def.id), "tags": _tag_strings(inst.def),
				"rarity": inst.def.rarity, "first_in_run": first}))
	wallet.changed.connect(func(_b: int, delta: int, _r: StringName):
		if delta > 0:
			faith_power.credit(&"earn_money", {"amount": delta})
		elif delta < 0:
			faith_power.credit(&"spend_money", {"amount": -delta}))
	# 093：打完一场把这一场的账汇总喂进去（造成 / 受到的伤害按类型、回血、每件出手几次）
	# 猎手战不是节点类型，是插进当前点的事件：按 hunter 记，不按脚下那个点的类型
	events.battle_finished.connect(func(n: MapNode, r: BattleResult, won: bool):
		var t := StringName(String(events.last_battle.get("type", "")))
		if t != HunterSystem.TYPE:
			t = NodeEvents.effective_type(n) if n != null else &""
		faith_power.credit(&"battle", battle_summary(r, won, board, t)))
	travel.moved.connect(func(i: MoveIntent, first: bool):
		var n := map.get_node(i.to_id) if map != null and map.has_node(i.to_id) else null
		faith_power.credit(&"travel", {"steps": travel.clock.total, "first_visit": first, "node_type": String(n.type) if n != null else ""}))
	# 134：输给驱逐档、视为没进：步数照算，进点不算（不带 first_visit —— 「进入节点」那条不认）
	travel.arrival_cancelled.connect(func(i: MoveIntent, _first: bool):
		var n := map.get_node(i.to_id) if map != null and map.has_node(i.to_id) else null
		faith_power.credit(&"travel", {"steps": travel.clock.total, "node_type": String(n.type) if n != null else ""}))
	vitality.changed.connect(func(_c: int, _m: int, delta: int, _r: StringName):
		if delta < 0:
			faith_power.credit(&"vitality_change", {"delta": delta}))
	events.search_opened.connect(func(_n: MapNode, session: SearchSession):
		if session != null:
			session.searched.connect(func(_found: Array[StringName], _enc: Dictionary): faith_power.credit(&"explore", {})))
	events.option_chosen.connect(func(_n: MapNode, option: EventOption):
		var tags: Array = []
		for t in option.tags:
			tags.append(String(t))
		faith_power.credit(&"event_choice", {"tags": tags}))


## 104：道具获得的对账 —— 棋盘 + 地上 + 保险箱里没对过账的实例各发一次 `item_acquired`（不逐个容器接信号，一处对账）。
## 离开一个点（走一步 / 被挪走）时调；测试也可以直接调。返回这次新对上的件数
func reconcile_owned() -> int:
	var fresh := 0
	for inst in _owned_now():
		var item := inst as ItemInstance
		if item == null or item.def == null or owned_uids.has(item.uid):
			continue
		owned_uids[item.uid] = true
		fresh += 1
		var first := not acquired_ids.has(String(item.def.id))
		acquired_ids[String(item.def.id)] = true
		if faith_power != null:
			faith_power.credit(&"item_acquired", {"id": String(item.def.id), "tags": _tag_strings(item.def),
				"cells": ItemVolume.cells_of(item.def), "rarity": item.def.rarity, "first_in_run": first})
	return fresh


## 开局（或读一份没有这笔账的老存档）：身上已有的全记成对过账，不给点
func _seed_owned() -> void:
	for inst in _owned_now():
		var item := inst as ItemInstance
		if item != null and item.def != null:
			owned_uids[item.uid] = true
			acquired_ids[String(item.def.id)] = true


func _owned_now() -> Array:
	var out: Array = []
	if board != null:
		out.append_array(board.items())
	if storage != null:
		out.append_array(storage.items())
	var safe := SafeModule.of(self)
	if safe != null and safe.inventory != null:
		out.append_array(safe.inventory.items())
	return out


static func _tag_strings(def: ItemDef) -> Array:
	var out: Array = []
	for t in def.tags:
		out.append(String(t))
	return out


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
		"character": String(character_id),
		"map_scale": String(map_scale),
		"difficulty": String(difficulty_id),
		"hunters": hunters.to_dict() if hunters != null else {},
		"erosion": travel.erosion.to_dict() if travel != null and travel.erosion != null else {},
		"phase": phase,
		"end_reason": String(end_reason),
		"map": map.to_dict(),
		"travel": travel.to_dict(),
		"vitality": vitality.to_dict(),
		"wallet": wallet.to_dict(),
		"board": board.to_dict(),
		"storage": storage.to_dict(),
		"rng": rng.to_dict(),
		"events": {"searches_closed": events.searches_closed, "last_handled": events.last_handled_id, "pending": events.pending.duplicate(), "losses_forgiven": events.losses_forgiven,
			"pending_battle": events.pending_battle.duplicate(true),
			"pending_ransom": events.pending_ransom.duplicate(true),     # 256：读档回来还在天平上
			# 审查 B1：开着的搜索会话不进存档（存档那一刻视为离开），离开时收获本来就交到待拾取 —— 存档这里照做，搜到的不丢
			"search_haul": events.current_search.haul().to_dict() if events.current_search != null and events.current_search.haul() != null and events.current_search.haul().item_count() > 0 else null},
		"skills": skills.to_dict(),
		"faith_power": faith_power.to_dict(),
		"faith_history": faith_power.history_to_array(),     # 104
		"owned_uids": owned_uids.keys(),
		"acquired_ids": acquired_ids.keys(),
		"placed_ids": placed_ids.keys(),
		"pending_loot": pending_loot.to_dict() if pending_loot != null else null,
		"boss_cleared": boss_cleared,
		"tally": tally.duplicate(),
		"searched_nodes": searched_nodes.keys(),     # 224
		"buffs": {"meta": meta_buff_ids()},     # 一局里拿到的在 modules.buff 下（101）
		"modules": _modules_to_dict(),     # 101：每个模块自己的状态；加模块 = 新键、带默认值，不升版
	}


## 173 §3.2.2：读档时原位放不回的一件（形状 / 尺寸改了）—— 先在原容器 [param home] 里找个空位，再落到地上（暂存区 = 当前点的地，159），
## 都不行才按价值折进钱包。每一步都记进 [member repair]
func rehome(inst: ItemInstance, home: GridInventory, from: String) -> void:
	if inst == null or inst.def == null:
		return
	if home != null and home.try_add(inst):
		if repair != null:
			repair.rehome(inst.def.id, from, from)
		return
	if storage != null and storage.insert(inst):
		if repair != null:
			repair.rehome(inst.def.id, from, "storage")
		return
	var value := ItemValue.of_instance(inst)
	if wallet != null:
		wallet.earn(value, &"save_repair")
	if repair != null:
		repair.refund(inst.def.id, value, from)


func _modules_to_dict() -> Dictionary:
	var out := {}
	for mid in modules:
		out[String(mid)] = (modules[mid] as RunModule).to_dict()
	return out


## 局外带进来的 buff id（字符串，存档与校准快照用）
func meta_buff_ids() -> Array:
	var out: Array = []
	for id in meta_buffs:
		out.append(String(id))
	return out


## 读回来。章节、内容库由调用方给（[RunSave] 按 id 取章节）。开着的商店 / 搜索会话不存：
## 存档那一刻视为离开了那个点（随时可以离开，5.4）
## 173：[param report] 给了就记下放不回原位、挪到地上（或折钱）的道具；模块读档时也用它（[member repair]）
static func from_dict(
	d: Dictionary, p_chapter: ChapterDef, p_items: ItemDatabase, p_enemies: EnemyDatabase, p_sets: SetDatabase = null,
	report: SaveReport = null
) -> RunState:
	if int(d.get("version", -1)) != SAVE_VERSION or p_chapter == null:
		return null
	var s := RunState.new()
	s.run_seed = int(d.get("seed", 0))
	s.chapter = p_chapter
	s.character_id = StringName(String(d.get("character", "")))
	s.map_scale = StringName(String(d.get("map_scale", "")))
	s.difficulty_id = StringName(String(d.get("difficulty", "")))
	s.hunters_saved = d.get("hunters", {}) if d.get("hunters", {}) is Dictionary else {}
	s.erosion_saved = d.get("erosion", {}) if d.get("erosion", {}) is Dictionary else {}
	s.items = p_items
	s.enemies = p_enemies
	s.sets = p_sets
	s._resolve_rules()
	s.map = MapGraph.from_dict(d.get("map", {}))
	s.travel = MapTravel.from_dict(d.get("travel", {}), s.map)
	s.vitality = Vitality.from_dict(d.get("vitality", {}))
	s.wallet = Wallet.from_dict(d.get("wallet", {}))
	s.repair = report
	var lost: Array = []     # 173：原位放不回的，等地上读回来再安置
	s.board = GridInventory.from_dict(d.get("board", {}), p_items, Vector2i.ZERO, lost)
	s.storage = ItemStash.from_dict(d.get("storage", {}), p_items)
	for inst in lost:
		s.rehome(inst, s.board, "board")
	var mods_raw: Variant = d.get("modules", {})
	s.modules_saved = (mods_raw as Dictionary).duplicate(true) if mods_raw is Dictionary else {}
	s.rng = RunRNG.from_dict(d.get("rng", {}))
	s._bind_tracker()
	s._wire_events()
	var ev: Dictionary = d.get("events", {})
	s.events.searches_closed = int(ev.get("searches_closed", 0))
	s.events.last_handled_id = int(ev.get("last_handled", -1))
	s.events.losses_forgiven = int(ev.get("losses_forgiven", 0))
	s.skills_saved = d.get("skills", {}) if d.get("skills", {}) is Dictionary else {}
	s.faith_power.restore(d.get("faith_power", {}) if d.get("faith_power", {}) is Dictionary else {})
	var pending = ev.get("pending", {})
	if pending is Dictionary and not (pending as Dictionary).is_empty():
		s.events.pending = {"node": int(pending.get("node", -1)), "event": String(pending.get("event", "")), "type": String(pending.get("type", ""))}
		if pending.has("hunter"):
			s.events.pending["hunter"] = int(pending["hunter"])
		# 审查 B1：搜索循环里的两种待选事件（遇敌 / 再搜或走）的旗子与遭遇内容跟着存档走
		for flag in ["search_stage", "search_encounter"]:
			if bool(pending.get(flag, false)):
				s.events.pending[flag] = true
		if pending.get("encounter", null) is Dictionary and not (pending["encounter"] as Dictionary).is_empty():
			s.events.pending["encounter"] = (pending["encounter"] as Dictionary).duplicate(true)
	# 084：读档回来还停在战前准备屏（开着的搜索会话不存，遭遇那一场打完只标点用过）
	var pb = ev.get("pending_battle", {})
	if pb is Dictionary and not (pb as Dictionary).is_empty() and pb.has("node"):
		var content = pb.get("content", {})
		s.events.pending_battle = {"node": int(pb["node"]), "type": String(pb.get("type", "battle")),
			"content": (content as Dictionary).duplicate(true) if content is Dictionary else {}, "kind": String(pb.get("kind", "node")),
			"loss_cost": int(pb.get("loss_cost", NodeEvents.LOSS_DEFAULT))}     # 审查 B1：搜索遇敌无代价（0）读档后不能变回默认
	var pr = ev.get("pending_ransom", {})
	if pr is Dictionary and not (pr as Dictionary).is_empty() and pr.has("node"):
		var rc = pr.get("content", {})
		s.events.pending_ransom = {"node": int(pr["node"]), "type": String(pr.get("type", "battle")),
			"content": (rc as Dictionary).duplicate(true) if rc is Dictionary else {}, "cost": int(pr.get("cost", 1)), "price": int(pr.get("price", 0))}
		if pr.has("defeat"):
			s.events.pending_ransom["defeat"] = String(pr["defeat"])
		var more = pr.get("more", [])
		if more is Array and not (more as Array).is_empty():
			s.events.pending_ransom["more"] = (more as Array).map(func(m) -> Dictionary: return {"type": String(m.get("type", "")), "cost": int(m.get("cost", 1))})
	for key in d.get("tally", {}):
		s.tally[String(key)] = int((d["tally"] as Dictionary)[key])
	for id in d.get("searched_nodes", []):
		s.searched_nodes[int(id)] = true
	var buffs: Dictionary = d.get("buffs", {})
	for id in buffs.get("meta", []):
		s.meta_buffs.append(StringName(String(id)))
	var loot = d.get("pending_loot", null)
	if loot is Dictionary:
		var lost_loot: Array = []
		s.pending_loot = GridInventory.from_dict(loot, p_items, Vector2i.ZERO, lost_loot)
		for inst in lost_loot:
			s.rehome(inst, s.pending_loot, "pending_loot")
	var haul = ev.get("search_haul", null)
	if haul is Dictionary:
		var lost_haul: Array = []
		var haul_grid := GridInventory.from_dict(haul, p_items, Vector2i.ZERO, lost_haul)
		for inst in lost_haul:
			s.rehome(inst, haul_grid, "search_haul")
		s._offer_loot(haul_grid)     # 审查 B1：存档时开着的搜索的收获 → 待拾取（和离开搜索一样）
	s.phase = int(d.get("phase", Phase.PICK_SPAWN))
	s.end_reason = StringName(String(d.get("end_reason", "")))
	s.boss_cleared = bool(d.get("boss_cleared", false))
	# 101：模块（本体那一层）现在就装上，读回来的一局立刻能用；难度机制要等持有方按 id 找回难度，
	# 它会再调一次 install_modules（模块幂等）
	s.install_modules()
	# 104：获得 / 置入的账；老存档没有就把现在身上的记成对过账（不补点）
	s.faith_power.restore_history(d.get("faith_history", []))
	for k in d.get("acquired_ids", []):
		s.acquired_ids[String(k)] = true
	for k in d.get("placed_ids", []):
		s.placed_ids[String(k)] = true
	if d.has("owned_uids"):
		for k in d.get("owned_uids", []):
			s.owned_uids[int(k)] = true
	else:
		s._seed_owned()
	return s
#endregion


## 打完一场记一笔；224：赢了按这一场的点类型再记其中精英 / 首领（last_battle 在发信号前记好）
func _tally_battle(won: bool) -> void:
	var key := "battles_won" if won else "battles_lost"
	tally[key] = int(tally.get(key, 0)) + 1
	if not won:
		return
	var type := StringName(String(events.last_battle.get("type", "")))
	if type == &"elite":
		tally["elite_won"] = int(tally.get("elite_won", 0)) + 1
	elif type == &"core":
		tally["boss_won"] = int(tally.get("boss_won", 0)) + 1


## 224：翻过的搜索点（宝箱也算），同一个点只算一次
func _tally_search(n: MapNode) -> void:
	if n != null and not searched_nodes.has(n.id):
		searched_nodes[n.id] = true
		tally["searches"] = int(tally.get("searches", 0)) + 1


#region 放掉（236）
## 这一局不要了（[GameFlow] 开新局 / 读档盖掉之后的下一帧调）：只解环，不存档、不发信号。
## 局与模块、系统、hook 表互相抓着，[method _wire_events] 接在旅程 / 节点事件 / 棋盘 / 钱 / 体力上的 lambda 也抓着局 ——
## 引用计数放不掉成环的东西，不解开就每开一局漏一整份（模块、地图、道具实例）。
## 解完之后 `modules` 是空的、hook 全是默认值，这一局不能再玩、也不该再存
func dispose() -> void:
	hooks.clear()
	for m in modules.values():
		(m as RunModule).dispose()
	modules.clear()
	for sys in [faith_power, skills, hunters, travel.erosion if travel != null else null]:
		if sys != null:
			sys.dispose()
	for o in [self, events, travel, travel.clock if travel != null else null, board, storage, wallet, vitality, pending_loot]:
		if o != null:
			_cut_signals(o)
	loot_seen = Callable()


## 把 [param o] 身上所有信号的所有连接断掉
static func _cut_signals(o: Object) -> void:
	for sig in o.get_signal_list():
		for c in o.get_signal_connection_list(sig["name"]):
			o.disconnect(sig["name"], c["callable"])
#endregion

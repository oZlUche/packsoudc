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
## 走出一个点，暂存区里的东西留在了那里（3.4 / 058；087 作者定：**留在那个点、回来能拿**，见 [member node_storages]）
signal storage_dropped(node_id: int, items: Array)
## 087：回到一个留过东西的点，那里的东西回到了暂存区
signal storage_restored(node_id: int, items: Array)
## 地图 buff 变了（给了、到期了）
signal buffs_changed()
## 猎手（071）：玩家进了某个猎手的感知范围；猎手的状态变了（动了、死了、歇了）；玩家被赶回上一个点
signal hunter_sensed(h: Hunter)
signal hunters_changed()
signal player_expelled(to_id: int)
## 侵蚀（075）：预警、推进、结算了、终局
signal erosion_warned(next_band: int, actions_left: int)
signal erosion_advanced(eroded_bands: int)
signal erosion_applied(node: MapNode, detail: Dictionary)
signal erosion_total()
## 局内技能（082）：次数 / 冷却 / 旗子变了；信力变了
signal skills_changed()
signal faith_power_changed(faith_id: StringName, points: int, tier: int)

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
## 087（作者定）：暂存区按点独立 —— 离开时暂存区里的东西留在那个点（`node_id → [ItemInstance]`），回到那个点又回到暂存区。跟存档。
## 撤离仍不带走暂存区里的东西
var node_storages: Dictionary = {}
var rng: RunRNG = null
var events: NodeEvents = null
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
## 猎手（069 / 071）：难度清单里的猎手机制装进来的系统；null = 这一局没有猎手。定义表由持有方给，存档里的状态读档时先放这儿等机制装
var hunters: HunterSystem = null
var hunter_defs: Dictionary = {}
## 信仰定义（8-4）：持有方给，名字与说明用；激活规则只看棋盘上的标签（[FaithState]）
var faith_defs: Dictionary = {}
## 合成配方（084 / 087）：持有方给。**相邻即合**（087 作者定）：棋盘上两件有配方的道具四邻相接，走到下一个点时自动合成，
## 不用拖到一起、没有「配对」这一步；[method craft_pairs] 随时能问现在有哪几对（界面画「合」、提示）
var recipes: Array[RecipeDef] = []
## 到了下一个点，合成发生了（或没成）：detail = {"log": [几句话], "output": 产物 id 或空, "where": "board" / "storage" / ""}
signal craft_done(node_id: int, detail: Dictionary)
## 局内技能的账（082）：定义在角色上，这里记次数、冷却、旗子；没角色也有一份空的
var skills: RunSkills = null
## 读档回来的技能账，等持有方按 id 找回角色（[method set_character]）再接上
var skills_saved: Dictionary = {}
## 信力（082）：每个信仰一个池子，只有激活的信仰收点；行为与阈值在信仰文件里
var faith_power: FaithPower = null
var hunters_saved: Dictionary = {}
## 侵蚀场的存档状态，读档时先放这儿等机制装（075）
var erosion_saved: Dictionary = {}

var pool: EnemyPool = null
var drop_rule: DropRule = null
var node_rules: NodeRules = null
var economy: EconomyRules = null

var phase: int = Phase.PICK_SPAWN
var end_reason: StringName = &""
## 087：核心点的 BOSS 打倒了（作者定：收完战利品直接撤离结算，[method extract_after_boss]）。跟存档
var boss_cleared: bool = false
## 等着拾取的容器（尸体 / 搜索收获）；null = 没有
var pending_loot: GridInventory = null
## 这一局的计数（给结算看）：打赢 / 打输几场。跟着存档走
var tally: Dictionary = {"battles_won": 0, "battles_lost": 0}
## buff（059）：定义表由持有方给（id → RunBuffDef，存档只写 id）；局外的在开局那一刻定下来跟着存档；
## 一局里的每条 {"id", "left"}（left = 还能走几步，-1 = 整局）
var buff_defs: Dictionary = {}
var meta_buffs: Array[StringName] = []
var map_buffs: Array[Dictionary] = []
## 事件层（063）：定义表由持有方给（id → EventDef，存档只写 id）。空表 = 每个点踩上去直接发生
var event_defs: Dictionary = {}:
	set(v):
		event_defs = v
		if events != null:
			events.event_defs = v


#region 开局
## 从一章开一局。生成不出图返回 null。[param kit] 是开局带的道具 id（包放棋盘，其余先放包里、放不下进暂存区）。
## [param p_character] 给了就按角色来（棋盘尺寸、体力上限、基线、初始包）；[param p_layout] 是开局屏摆好的棋盘
## （[method layout_of] 的产物：哪件、放哪、什么朝向），先按它摆，再发 kit
static func start(
	p_chapter: ChapterDef, p_seed: int, p_items: ItemDatabase, p_enemies: EnemyDatabase,
	p_sets: SetDatabase = null, kit: Array[StringName] = [] as Array[StringName],
	p_buff_defs: Dictionary = {}, p_meta_buffs: Array[StringName] = [] as Array[StringName],
	p_character: CharacterDef = null, p_layout: Array = [], p_difficulty: DifficultyDef = null, p_hunter_defs: Dictionary = {},
	p_scale: StringName = &""
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
	s._resolve_rules()
	s.map = p_chapter.map_source.resolve(p_seed, p_scale)
	if s.map == null:
		return null
	ItemInstance.reset_uid_counter()
	if s.pool != null:
		EnemyPlacer.fill(s.map, s.pool, p_enemies, p_items, p_chapter.difficulty, s.scale_id())
	PaidExtracts.mark(s.map, s.economy)
	EventPlacer.fill(s.map, s.node_rules)
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
	s.vitality = Vitality.new(vitality_max + ctx.vitality_max_bonus + p_chapter.vitality_bonus)
	s.wallet = Wallet.new((s.economy.starting_balance if s.economy != null else 0) + ctx.starting_funds_bonus)
	s.board = GridInventory.new(board_size, BOARD_ID, true)
	s.storage = ItemStash.new(STORAGE_ID, 0)
	s._bind_tracker()
	s._place_layout(p_layout)
	s._give_kit(full_kit)
	s.travel = MapTravel.new(s.map, ActionClock.new())
	s.travel.vitality = s.vitality
	s._wire_events()
	s.install_mechanics()     # 机制要接的东西（旅程、节点事件）都造好了才装
	s.phase = Phase.PICK_SPAWN
	# 084：章节说了「默认已经站在出生点上」（序章只有一个出生点，没什么可挑的）就直接站上去
	if p_chapter.auto_spawn and not s.map.entry_ids.is_empty():
		s.pick_spawn(s.map.entry_ids[0])
	return s


## 站到出生点上开局。返回 false = 不是出生点，或不在挑出生点阶段
func pick_spawn(id: int) -> bool:
	if phase != Phase.PICK_SPAWN or map == null or not map.entry_ids.has(id):
		return false
	travel.start_at(id)
	_set_phase(Phase.ON_MAP, &"spawn")
	return true


## 走一步。开着的商店 / 搜索先关掉（随时可以离开）；没拿的战利品、暂存区里的东西都留在这个点上（3.4 / 084：离开就是清的时机）；
## 等着开打的一场没打不能走；不在图上走不了
func step_to(id: int) -> bool:
	if phase != Phase.ON_MAP or not events.pending_battle.is_empty():
		return false
	if not travel.available_moves().has(id):
		return travel.step_to(id)     # 让旅程自己拒绝、发 refused；走不成就不该清东西
	close_sessions()
	_drop_pending_loot()
	_drop_storage_if_leaving()
	var ok := travel.step_to(id)
	if ok:
		_restore_storage(travel.current_id)     # 087：回到走过的点，留着的东西回到暂存区（头一回踩的在 _on_arrive 里已取）
		tick_map_buffs()
		if hunters != null:
			hunters.on_player_step()     # 猎手的回合在这一步的事都发生之后（071）
		skills.on_step()     # 冷却与躲避在猎手的回合之后减：躲 3 步就是 3 个猎手回合够不着（082）
	return ok


## 事件把人挪走（8-3 的传送后果）：不走边，但离开发生过事的点照样清暂存区、猎手照样得一个回合 —— 和走一步一样的壳，只是意图不同
func relocate(intent: MoveIntent) -> bool:
	if phase != Phase.ON_MAP or intent == null:
		return false
	close_sessions()
	_drop_pending_loot()
	_drop_storage_if_leaving()
	var ok := travel.apply(intent)
	if ok:
		_restore_storage(travel.current_id)
		tick_map_buffs()
		if hunters != null:
			hunters.on_player_step()
		skills.on_step()
	return ok


## 玩家空下来了（叠层看完、会话关了）问一声猎手够不够得着；够得着就开打前的事件屏已经排上。返回有没有
func poke_hunters() -> bool:
	return hunters != null and hunters.check_engagement()


## 按 id 取一个敌人池资产（猎手可以指定自己的池）
func pool_by_id(id: StringName) -> EnemyPool:
	return _rule_asset("enemy_pools", id) as EnemyPool


## 走出现在这个点会不会把暂存区留下：暂存区里有东西就留（087 作者定：留在这个点、回来能拿；不再是「清掉」）——
## 暂存区是**节点内的临时区**：任何时候都能开背包把东西挪进去（换信仰道具的置入顺序就靠它），但一旦移动就不在身上了。
## 离开时存进 [member node_storages]，回到那个点时取回（[method _restore_storage]）
func will_clear_storage() -> bool:
	return travel != null and travel.current_id >= 0 and storage != null and storage.item_count() > 0


## 087：某个点上留着的东西（没有就空）
func stored_at(node_id: int) -> Array:
	return (node_storages.get(node_id, []) as Array).duplicate()


## 087：回到一个点：那里留着的东西回到暂存区
func _restore_storage(node_id: int) -> void:
	if storage == null or not node_storages.has(node_id):
		return
	var back: Array = node_storages[node_id]
	node_storages.erase(node_id)
	if back.is_empty():
		return
	for inst in back:
		storage.admit(inst)
	storage_restored.emit(node_id, back)


func _drop_storage_if_leaving() -> void:
	if events == null or travel == null:
		return
	_drop_storage(travel.current_id)
	# 离开了就不再算「发生过事的点」：回头再路过一次不会又清一遍
	if events.last_handled_id == travel.current_id:
		events.last_handled_id = -1


## 头一回踩上一个点：先把这个点留着的东西取回暂存区，再结等着的合成（产物放不下就进暂存区），再让那个点的事发生 ——
## 顺序不能反，不然合成的产物没地方去、事件给的东西看不见
func _on_arrive(node: MapNode) -> void:
	if node != null:
		_restore_storage(node.id)
		resolve_crafts(node.id)
	events.handle(node)


## 离开一个点：暂存区里的东西留在那个点上（087：不是丢掉，回来能拿）
func _drop_storage(at_id: int) -> void:
	if storage == null or storage.item_count() == 0:
		return
	var dropped: Array = storage.items().duplicate()
	storage.clear()
	var kept: Array = node_storages.get(at_id, [])
	kept.append_array(dropped)
	node_storages[at_id] = kept
	storage_dropped.emit(at_id, dropped)


## 084：没拿完的战利品（尸体 / 搜索收获）留在这个点上 —— 收起战利品屏不算丢，走了才算。和暂存区同一个时机
func _drop_pending_loot() -> void:
	if pending_loot != null:
		discard_loot()


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
	_drop_pending_loot()
	_set_phase(Phase.EXTRACTED, &"extract")
	return true


## 087（作者定）：BOSS 倒下之后直接撤离结算 —— 不看站在哪、不付费。没打倒 BOSS / 已经结束返回 false
func extract_after_boss() -> bool:
	if not boss_cleared or is_over():
		return false
	close_sessions()
	_drop_pending_loot()
	_set_phase(Phase.EXTRACTED, &"boss")
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
	for entry in map_buffs:
		var def: RunBuffDef = buff_defs.get(StringName(String(entry["id"])), null)
		if def != null:
			out.append(def)
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


## 把难度清单里的机制接进一局（开局与读档各一次；机制必须幂等）。没有难度 = 什么都不装
func install_mechanics() -> void:
	if difficulty == null:
		return
	for m in difficulty.mechanics:
		var mech := m as RunMechanic
		if mech != null:
			mech.install(self)


## 给一个地图 buff（事件的后果）。不认识的 id、局外的 buff 给不了；已经有的刷新时限
func grant_map_buff(id: StringName) -> bool:
	var def: RunBuffDef = buff_defs.get(id, null)
	if def == null or not def.is_map():
		return false
	var left := def.duration_steps if def.duration_steps > 0 else -1
	for entry in map_buffs:
		if String(entry["id"]) == String(id):
			entry["left"] = left
			buffs_changed.emit()
			return true
	map_buffs.append({"id": String(id), "left": left})
	buffs_changed.emit()
	return true


func remove_map_buff(id: StringName) -> bool:
	for i in map_buffs.size():
		if String(map_buffs[i]["id"]) == String(id):
			map_buffs.remove_at(i)
			buffs_changed.emit()
			return true
	return false


func has_map_buff(id: StringName) -> bool:
	for entry in map_buffs:
		if String(entry["id"]) == String(id):
			return true
	return false


## 激活的 buff 里有没有带这个标记的（事件选项的条件查它）
func has_buff_tag(tag: StringName) -> bool:
	return RunBuffs.has_tag(active_buff_defs(), tag)


## 走了一步：有时限的地图 buff 少一步，到 0 就没了
func tick_map_buffs() -> void:
	var changed := false
	var i := map_buffs.size() - 1
	while i >= 0:
		var left := int(map_buffs[i]["left"])
		if left > 0:
			left -= 1
			if left == 0:
				map_buffs.remove_at(i)
			else:
				map_buffs[i]["left"] = left
			changed = true
		i -= 1
	if changed:
		buffs_changed.emit()
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
	return BattleCompiler.compile(board, effective_baseline(), mods, rules, faith_power.tiers() if faith_power != null else {})


## 角色基线 + 技能 / buff 的基线加成（RunContext.stat_bonus）。没有加成就是原来那份
func effective_baseline() -> CombatantBaseline:
	var ctx := buff_context()
	if ctx.stat_bonus.is_empty():
		return player_baseline
	var base := player_baseline if player_baseline != null else CombatantBaseline.default_baseline()
	var b := CombatantBaseline.new()
	b.base_stats = base.base_stats.duplicate()
	for key in ctx.stat_bonus:
		var k := StringName(String(key))
		b.base_stats[k] = float(b.base_stats.get(k, 0.0)) + float(ctx.stat_bonus[key])
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
	skills_changed.emit()


func _ensure_skills() -> void:
	if skills != null:
		return
	skills = RunSkills.new()
	skills.setup(self, [] as Array[RunSkill])
	skills.changed.connect(func(): skills_changed.emit())


## 地图上用一个局内技能（082）。返回空串 = 用了；否则是不能用的原因
func use_skill(id: StringName) -> String:
	if phase != Phase.ON_MAP:
		return "不在图上"
	return skills.use(id)


## 开打前：立了旗的技能改双方的战斗单位（[NodeEvents.before_battle]）
func _before_battle(me: CombatantSpec, enemy: CombatantSpec, _type: StringName) -> void:
	skills.prepare_battle(me, enemy)


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
		return "信仰：无"
	var def := active_faith()
	return "信仰：%s" % (Names.of(def) if def != null else String(id))


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
	return ctx


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


## 这两件能合成什么：配方里有就返回产物的定义；没有 null
func craft_output(a: ItemDef, b: ItemDef) -> ItemDef:
	if a == null or b == null or items == null:
		return null
	var r := RecipeDef.find(recipes, a.id, b.id)
	return items.get_def(r.output) if r != null else null


## 087：棋盘上现在相邻、有配方的对子，`[[a, b, 产物定义], …]`：a 是 uid 小的那件。每件只进一对（uid 升序先配到的算），
## 顺序稳定 —— 同一个棋盘永远同样的结果。包不参与邻接（[method GridInventory.neighbors_of]）
func craft_pairs() -> Array:
	var out: Array = []
	if board == null or recipes.is_empty():
		return out
	var used := {}
	var uids: Array[int] = []
	for inst in board.items():
		uids.append((inst as ItemInstance).uid)
	uids.sort()
	for uid in uids:
		if used.has(uid):
			continue
		var a := board.get_item(uid)
		if a == null or a.def == null or board.acts_as_bag(a.def):
			continue
		for other in board.neighbors_of(uid):
			if used.has(other):
				continue
			var b := board.get_item(other)
			if b == null or b.def == null:
				continue
			var out_def := craft_output(a.def, b.def)
			if out_def == null:
				continue
			used[uid] = true
			used[b.uid] = true
			out.append([a, b, out_def])
			break
	return out


## 棋盘上这件现在配着谁（界面画「合」）；没有 null
func craft_partner_of(uid: int) -> ItemInstance:
	for pair in craft_pairs():
		if (pair[0] as ItemInstance).uid == uid:
			return pair[1]
		if (pair[1] as ItemInstance).uid == uid:
			return pair[0]
	return null


## 到了下一个点（暂存区已清）：把此刻相邻的每一对合掉 —— 产物落在 a 的位置（a 的朝向），放不下试 b 的位置、再自动找位，
## 再不行进暂存区并提醒。每一桩发一次 craft_done
func resolve_crafts(at_id: int) -> void:
	var pairs := craft_pairs()
	if pairs.is_empty():
		return
	for pair in pairs:
		var a: ItemInstance = pair[0]
		var b: ItemInstance = pair[1]
		var out_def: ItemDef = pair[2]
		var detail := {"log": [] as Array, "output": String(out_def.id), "where": ""}
		var out := ItemInstance.create(out_def, a.rotation)
		var where := ""
		board.begin_batch()
		var home_a := a.origin
		var rot_a := a.rotation
		var home_b := b.origin
		var rot_b := b.rotation
		board.remove(a.uid)
		board.remove(b.uid)
		if board.place(out, home_a, rot_a) or board.place(out, home_b, rot_b) or board.try_add(out, true):
			where = "board"
		elif storage.admit(out):
			where = "storage"
		board.end_batch()
		detail["where"] = where
		(detail["log"] as Array).append("「%s」和「%s」相邻，合成了「%s」。" % [a.def.display_name, b.def.display_name, out_def.display_name])
		if where == "storage":
			(detail["log"] as Array).append("背包里装不下它：放进了暂存区。走之前记得放回包里，暂存区里的东西会留在这个点上。")
		craft_done.emit(at_id, detail)


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
		# 上一份还没处理就来了新的（搜索收获 + 遭遇的尸体）：并成一份，一件都不丢。
		# 087：尸体容器可能是棋盘模式（包当背景），两边都往一块够大的自由容器里搬，放不下就加高
		var w := maxi(pending_loot.size.x, container.size.x)
		var h := pending_loot.size.y + container.size.y
		var merged := GridInventory.new(Vector2i(w, h), 0, false)
		InventoryService.transfer_all(pending_loot, merged)
		InventoryService.transfer_all(container, merged)
		var guard := 0
		while (pending_loot.item_count() > 0 or container.item_count() > 0) and guard < 8:
			guard += 1
			var bigger := GridInventory.new(merged.size + Vector2i(0, 2), 0, false)
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
		rows.append(inst)
	# 包先摆（普通物品要落在包里），其余按 uid 顺序，稳定
	rows.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if a.def.is_bag != b.def.is_bag:
			return a.def.is_bag
		return a.uid < b.uid)
	for inst in rows:
		var it := inst as ItemInstance
		out.append({"id": String(it.def.id), "origin": [it.origin.x, it.origin.y], "rot": it.rotation})
	return out


## 按 [method layout_of] 的记录摆回棋盘；摆不回去的（棋盘换了、定义没了）进暂存区
func _place_layout(layout: Array) -> void:
	if items == null or layout.is_empty():
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
		if not board.place(inst, Vector2i(int(at[0]), int(at[1])), int(row.get("rot", 0))) and not board.try_add(inst, true):
			storage.admit(inst)
	board.end_batch()

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
	events.pool = pool
	events.enemies = enemies
	events.items = items
	events.drop_rule = drop_rule
	events.wallet = wallet
	events.economy = economy
	events.difficulty = chapter.difficulty
	events.scale_id = scale_id()
	events.player_spec = compile_player
	events.loot_context = _loot_context
	events.run_context = buff_context
	events.event_defs = event_defs
	events.grant_map_buff = grant_map_buff
	events.remove_map_buff = remove_map_buff
	events.has_map_buff = has_map_buff
	events.has_buff_tag = has_buff_tag
	# 8-3：条件看容器与段位，后果传送 / 耗时经这里走（清暂存区、猎手回合）
	events.board = board
	events.storage = storage
	events.bracket_of = func() -> int: return hunters.bracket() if hunters != null else -1
	events.relocate = relocate
	events.request_extract = try_extract     # 085：撤离点的对话里选「撤离」
	events.waited.connect(func(_n: MapNode, _actions: int):
		tick_map_buffs()
		if hunters != null:
			hunters.on_player_step())
	events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool):
		var key := "battles_won" if won else "battles_lost"
		tally[key] = int(tally.get(key, 0)) + 1)
	events.loot_ready.connect(func(_n: MapNode, corpse: GridInventory): _offer_loot(corpse))
	events.search_closed.connect(func(_n: MapNode, haul: GridInventory, _why: StringName): _offer_loot(haul))
	events.shop_opened.connect(func(_n: MapNode, session: ShopSession):
		if session != null:
			# 087：双击 / 按钮买的（inst 由会话交出来）先试着进包、放不下进暂存区；拖着买的已经在玩家手里了（inst 为 null）
			session.bought.connect(func(_def: ItemDef, _price: int, inst: ItemInstance):
				if inst != null and not board.try_add(inst, true):
					storage.admit(inst)))
	events.event_resolved.connect(func(_n: MapNode, _outcome: StringName, detail: Dictionary):
		for id in detail.get("items", []):
			var d := items.get_def(StringName(String(id)))
			if d != null:
				storage.admit(ItemInstance.create(d, 0)))
	events.defeated.connect(func(why: StringName): _set_phase(Phase.DEFEATED, why))
	events.boss_defeated.connect(func(_n: MapNode): boss_cleared = true)
	events.bind(travel)
	# 进入的那一次检查插在节点事件前面（bind 把 handle 挂上了，这里再包一层）
	travel.on_node_event = _on_arrive
	# 082：技能与信力
	_ensure_skills()
	events.before_battle = _before_battle
	faith_power = FaithPower.new()
	faith_power.setup(self)
	faith_power.changed.connect(func(id: StringName, p: int, tier: int): faith_power_changed.emit(id, p, tier))
	_wire_faith_power()


## 信力的行为（082）：一局里的事喂给激活信仰的行为构件。哪些事、载荷长什么样见 [FaithDeed]
func _wire_faith_power() -> void:
	board.placed.connect(func(inst: ItemInstance):
		if inst != null and inst.def != null:
			faith_power.credit(&"place_item", {"value": ItemValue.of(inst.def), "id": String(inst.def.id)}))
	wallet.changed.connect(func(_b: int, delta: int, _r: StringName):
		if delta > 0:
			faith_power.credit(&"earn_money", {"amount": delta})
		elif delta < 0:
			faith_power.credit(&"spend_money", {"amount": -delta}))
	events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): faith_power.credit(&"battle", {"won": won}))
	travel.moved.connect(func(_i: MoveIntent, _first: bool): faith_power.credit(&"travel", {"steps": travel.clock.total}))
	events.search_opened.connect(func(_n: MapNode, session: SearchSession):
		if session != null:
			session.searched.connect(func(_found: Array[StringName], _enc: Dictionary): faith_power.credit(&"explore", {})))
	events.option_chosen.connect(func(_n: MapNode, option: EventOption):
		var tags: Array = []
		for t in option.tags:
			tags.append(String(t))
		faith_power.credit(&"event_choice", {"tags": tags}))


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
		"erosion": travel.erosion.to_dict() if travel != null and travel.erosion != null and travel.erosion.has_method("to_dict") else {},
		"phase": phase,
		"end_reason": String(end_reason),
		"map": map.to_dict(),
		"travel": travel.to_dict(),
		"vitality": vitality.to_dict(),
		"wallet": wallet.to_dict(),
		"board": board.to_dict(),
		"storage": storage.to_dict(),
		"node_storages": _node_storages_to_dict(),
		"rng": rng.to_dict(),
		"events": {"searches_closed": events.searches_closed, "last_handled": events.last_handled_id, "pending": events.pending.duplicate(), "losses_forgiven": events.losses_forgiven,
			"pending_battle": events.pending_battle.duplicate(true)},
		"skills": skills.to_dict(),
		"faith_power": faith_power.to_dict(),
		"pending_loot": pending_loot.to_dict() if pending_loot != null else null,
		"boss_cleared": boss_cleared,
		"tally": tally.duplicate(),
		"buffs": {"meta": _meta_buff_ids(), "map": map_buffs.duplicate(true)},
	}


func _node_storages_to_dict() -> Dictionary:
	var out := {}
	for key in node_storages:
		var list: Array = []
		for inst in node_storages[key]:
			list.append((inst as ItemInstance).to_dict())
		out[str(key)] = list
	return out


func _meta_buff_ids() -> Array:
	var out: Array = []
	for id in meta_buffs:
		out.append(String(id))
	return out


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
	s.board = GridInventory.from_dict(d.get("board", {}), p_items)
	s.storage = ItemStash.from_dict(d.get("storage", {}), p_items)
	var ns: Variant = d.get("node_storages", {})
	if ns is Dictionary:
		for key in ns:
			var list: Array = []
			for raw in (ns[key] as Array):
				var inst := ItemInstance.from_dict(raw as Dictionary, p_items)
				if inst != null:
					list.append(inst)
			if not list.is_empty():
				s.node_storages[int(String(key))] = list
	s.rng = RunRNG.from_dict(d.get("rng", {}))
	s.travel.vitality = s.vitality
	s._bind_tracker()
	s._wire_events()
	s.events.searches_closed = int((d.get("events", {}) as Dictionary).get("searches_closed", 0))
	s.events.last_handled_id = int((d.get("events", {}) as Dictionary).get("last_handled", -1))
	s.events.losses_forgiven = int((d.get("events", {}) as Dictionary).get("losses_forgiven", 0))
	s.skills_saved = d.get("skills", {}) if d.get("skills", {}) is Dictionary else {}
	s.faith_power.restore(d.get("faith_power", {}) if d.get("faith_power", {}) is Dictionary else {})
	var pending = (d.get("events", {}) as Dictionary).get("pending", {})
	if pending is Dictionary and not (pending as Dictionary).is_empty():
		s.events.pending = {"node": int(pending.get("node", -1)), "event": String(pending.get("event", "")), "type": String(pending.get("type", ""))}
		if pending.has("hunter"):
			s.events.pending["hunter"] = int(pending["hunter"])
	# 084：读档回来还停在战前准备屏（开着的搜索会话不存，遭遇那一场打完只标点用过）
	var pb = (d.get("events", {}) as Dictionary).get("pending_battle", {})
	if pb is Dictionary and not (pb as Dictionary).is_empty() and pb.has("node"):
		var content = pb.get("content", {})
		s.events.pending_battle = {"node": int(pb["node"]), "type": String(pb.get("type", "battle")),
			"content": (content as Dictionary).duplicate(true) if content is Dictionary else {}, "kind": String(pb.get("kind", "node"))}
	for key in d.get("tally", {}):
		s.tally[String(key)] = int((d["tally"] as Dictionary)[key])
	var buffs: Dictionary = d.get("buffs", {})
	for id in buffs.get("meta", []):
		s.meta_buffs.append(StringName(String(id)))
	for entry in buffs.get("map", []):
		if entry is Dictionary:
			s.map_buffs.append({"id": String(entry.get("id", "")), "left": int(entry.get("left", -1))})
	var loot = d.get("pending_loot", null)
	if loot is Dictionary:
		s.pending_loot = GridInventory.from_dict(loot, p_items)
	s.phase = int(d.get("phase", Phase.PICK_SPAWN))
	s.end_reason = StringName(String(d.get("end_reason", "")))
	s.boss_cleared = bool(d.get("boss_cleared", false))
	return s
#endregion

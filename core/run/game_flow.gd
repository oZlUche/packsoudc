## 场景流的状态机（架构文档 8 节，M6）。**纯逻辑**：它只说「现在该显示哪一屏、给它什么」，不认识任何 Node。
## `GameDirector`（ui/game）听 [signal screen_changed] 换场景；测试直接驱动它，一屏都不用画。
##
## 屏分两层：**底屏**（主菜单、开局、地图、结算、局外）互相替换；**叠层**（战斗回放、战利品、搜索、商店、事件、休息）
## 叠在地图上，地图和镜头都留着 —— 这就是 8 节说的「不用 change_scene_to_file」的原因。
##
## 节点事件是同步发生的：`step_to` 一步之内可能连着来「打了一场 → 掉了东西 → 进账」，各自一个信号。
## 这里把它们**排成队**（`_queue`），走完这一步按顺序一屏一屏给玩家看；叠层看完了调 [method resume] 看下一个，
## 队列空了回地图；一局结束了（战败 / 撤离）最后一定是结算屏。
class_name GameFlow
extends RefCounted

enum Screen { MAIN_MENU, SETUP, MAP, BATTLE, LOOT, SEARCH, SHOP, EVENT, REST, RESULT, META, SETTINGS }

signal screen_changed(screen: int, payload: Dictionary)
signal run_started(state: RunState)
signal run_ended(result: RunResult)

var items: ItemDatabase = null
var enemies: EnemyDatabase = null
var sets: SetDatabase = null
var meta: MetaState = null
var meta_rules: MetaRules = null
## 全部 buff 定义（id → RunBuffDef），开局给 RunState、读档后补上
var buff_defs: Dictionary = {}
## 全部事件定义（id → EventDef，063）。空表 = 没有事件层
var event_defs: Dictionary = {}
var chapters: Array[ChapterDef] = []
var loadouts: Array[LoadoutDef] = []
## 全部角色（067）。开局屏列出来挑；空 = 老路（按开局装备开）
var characters: Array[CharacterDef] = []
## 全部进阶难度（069），按档位排；空 = 只有普通
var difficulties: Array[DifficultyDef] = []
## 全部猎手定义（id → HunterDef，069 / 071）；猎手机制按它造猎手
var hunter_defs: Dictionary = {}
var save_path: String = RunSave.DEFAULT_PATH
var meta_path: String = MetaSave.DEFAULT_PATH
var settings_path: String = GameSettings.DEFAULT_PATH
## 玩家的设置（提醒档位等）。持有方读进来；改了调 save_settings
var settings: GameSettings = GameSettings.new()
## 玩家基线（4.2）。角色系统之前由持有方统一给；null = 编译器默认
var player_baseline: CombatantBaseline = null

var run: RunState = null
var result: RunResult = null
## 最近一次进 meta 的账（absorb 的返回：带回几件、值、钱、新点亮几条）
var last_absorbed: Dictionary = {}
var screen: int = Screen.MAIN_MENU
var last_payload: Dictionary = {}
## 待拾取里已经在搜索屏亮过的 uid（6.2 的揭示只做一次）。拾取完清空
var seen_loot: Dictionary = {}
## 校准记录（073）：装了就每走一步记一份玩家配置，木桩工具吃它；null = 不记
var recorder: CalibrationRecorder = null
var _queue: Array[Dictionary] = []
var _settled: bool = false


func _init(p_items: ItemDatabase = null, p_enemies: EnemyDatabase = null, p_sets: SetDatabase = null, p_meta: MetaState = null) -> void:
	items = p_items
	enemies = p_enemies
	sets = p_sets
	meta = p_meta if p_meta != null else MetaState.new()


static func is_overlay(s: int) -> bool:
	return s in [Screen.BATTLE, Screen.LOOT, Screen.SEARCH, Screen.SHOP, Screen.EVENT, Screen.REST]


#region 底屏之间
func to_main_menu() -> void:
	run = null
	result = null
	_queue.clear()
	save_meta()
	_go(Screen.MAIN_MENU)


func new_run() -> void:
	grant_first_kit()
	save_meta()
	_go(Screen.SETUP)


## 仓库空的第一局发第一套（[MetaRules.first_kit]，058 第六节的占位；正式游戏由教程关发）。发了返回件数，否则 0
func grant_first_kit() -> int:
	if meta == null or meta_rules == null or meta_rules.first_kit == &"" or items == null:
		return 0
	if meta.warehouse.item_count() > 0 or meta.has_pending_board():
		return 0
	var kit := loadout_of(meta_rules.first_kit)
	if kit == null:
		return 0
	var defs: Array = []
	for id in kit.items:
		var def := items.get_def(id)
		if def != null:
			defs.append(def)
	return meta.grant(defs)


func loadout_of(id: StringName) -> LoadoutDef:
	for l in loadouts:
		if l.id == id:
			return l
	return null


func character_of(id: StringName) -> CharacterDef:
	for c in characters:
		if c.id == id:
			return c
	return null


func difficulty_of(id: StringName) -> DifficultyDef:
	for d in difficulties:
		if d.id == id:
			return d
	return null


## 这个玩家现在能选的难度：没有解锁要求的，和已解锁的（作者：局外解锁的特殊选项）
func available_difficulties() -> Array[DifficultyDef]:
	var out: Array[DifficultyDef] = []
	for d in difficulties:
		if d.requires_unlock == &"" or (meta != null and meta.has_unlock(d.requires_unlock)):
			out.append(d)
	return out


## 现在能不能开新局；空串 = 能，否则是原因（带回来的背包还没清空，058 第 7 条）
func can_begin() -> String:
	if meta != null and meta.has_pending_board():
		return "上一局带回来的背包还有 %d 件没清空：先在仓库里置入或不要了，再配置下一局" % meta.board.item_count()
	return ""


func save_meta() -> bool:
	return meta != null and MetaSave.write(meta, meta_path) == OK


## 仓库面板的两个动作：改了就存
func store_all() -> Dictionary:
	var got := meta.store_all()
	save_meta()
	return got


func discard_board() -> void:
	meta.discard_board()
	save_meta()


## 局外 buff 的开关（占位：将来由任务系统、局外科技决定）。改了就存
func toggle_meta_buff(id: StringName) -> bool:
	var on := meta.toggle_buff(id)
	save_meta()
	return on


## 局外解锁的开关（占位：将来由成长系统决定）。改了就存
func toggle_unlock(id: StringName) -> bool:
	var on := meta.toggle_unlock(id)
	save_meta()
	return on


func show_meta() -> void:
	_go(Screen.META)


func show_settings() -> void:
	_go(Screen.SETTINGS)


func save_settings() -> bool:
	return settings != null and settings.save_to(settings_path) == OK


## 从一章、一个种子开一局。两条路：
## - 老路（测试、没有角色）：[param loadout] 的清单 + [param from_warehouse]（仓库里的 uid）当 kit；
## - 角色路（开局屏，067）：[param character] 定棋盘、体力、基线、初始包，[param layout] 是开局屏摆好的棋盘
##   （仓库里的东西拖上去那一刻已经离开仓库）。
## 两条路都在开局那一刻存 meta：带进去的从仓库拿走（一局里是新实例，3.1 存档只写 id），撤离了回来，死了就是真没了。
## 生成不出图返回 null，停在开局屏
func begin(chapter: ChapterDef, loadout: LoadoutDef, seed: int, from_warehouse: Array[int] = [] as Array[int],
		character: CharacterDef = null, layout: Array = [], difficulty: DifficultyDef = null) -> RunState:
	if can_begin() != "":
		return null
	var kit: Array[StringName] = []
	if loadout != null:
		kit = loadout.items.duplicate()
	var taken: Array[ItemInstance] = []
	for uid in from_warehouse:
		var inst := meta.warehouse.get_item(uid)
		if inst != null and inst.def != null:
			kit.append(inst.def.id)
			taken.append(inst)
	if difficulty != null and difficulty.requires_unlock != &"" and not meta.has_unlock(difficulty.requires_unlock):
		return null     # 没解锁的难度开不了（界面本来就不列，这里是兜底）
	var state := RunState.start(chapter, seed, items, enemies, sets, kit, buff_defs, meta.active_buffs, character, layout, difficulty, hunter_defs)
	if state == null:
		return null
	for inst in taken:
		meta.warehouse.remove(inst.uid)
	if not taken.is_empty() or character != null:
		MetaSave.write(meta, meta_path)
	_adopt(state)
	_go(Screen.MAP)
	run_started.emit(state)
	return state


func has_save() -> bool:
	return RunSave.exists(save_path)


## 读上次存的那一局接着玩。没有、读不了返回 false
func continue_run() -> bool:
	var state := RunSave.read(items, enemies, sets, save_path)
	if state == null:
		return false
	_adopt(state)
	_flush()     # 读档回来：等着选的事件还在这一屏；结束了的直接进结算；否则回地图
	run_started.emit(state)
	return true


func save() -> bool:
	return run != null and not run.is_over() and RunSave.write(run, save_path) == OK


## 存档回主菜单（随时可以离开：开着的店 / 搜索视为离开）
func save_and_quit() -> bool:
	var ok := save()
	to_main_menu()
	return ok


## 结算看完了：去局外（账在进结算屏之前就记了，见 _settle_run）
func finish_result() -> void:
	save_meta()
	_go(Screen.META, {"result": result})


## 一局结束了：算账、进 meta（只进一次）、存 meta、删掉这一局的存档。结算屏拿到的已经是记完账的局外
func _settle_run() -> void:
	if result != null:
		return
	result = RunResult.settle(run)
	run_ended.emit(result)
	if not _settled:
		_settled = true
		last_absorbed = meta.absorb(result)
		MetaSave.write(meta, meta_path)
		RunSave.remove(save_path)
#endregion


#region 地图上的动作
func pick_spawn(id: int) -> bool:
	return run != null and run.pick_spawn(id)


## 走一步。这一步引发的事件都排进了队，走完按顺序给玩家看
func step_to(id: int) -> bool:
	if run == null or not run.step_to(id):
		return false
	if recorder != null:
		recorder.record(run)
	_flush()
	return true


## 在撤离点上撤离。付不起、不在撤离点返回 false
func extract() -> bool:
	if run == null or not run.try_extract():
		return false
	_flush()
	return true


## 叠层看完了（战斗回放、事件、休息）：看下一个，没有就回地图
func resume() -> void:
	_flush()


## 事件屏上选了第 i 项（063）。选不了返回 false 留在原地；选了按后果往下走
func choose_event(i: int) -> bool:
	if run == null or not run.events.choose(i):
		return false
	_flush()
	return true


func take_loot(uid: int) -> bool:
	if run == null:
		return false
	var ok := run.take_loot(uid)
	seen_loot.erase(uid)
	if run.pending_loot == null:
		seen_loot.clear()
		_flush()
	return ok


func take_all_loot() -> int:
	if run == null:
		return 0
	var n := run.take_all_loot()
	seen_loot.clear()
	_flush()
	return n


func discard_loot() -> void:
	if run == null:
		return
	run.discard_loot()
	seen_loot.clear()
	_flush()
#endregion


#region 接线
func _adopt(state: RunState) -> void:
	run = state
	result = null
	_settled = false
	_queue.clear()
	state.buff_defs = buff_defs      # 读档回来的只有 id，定义表在这里
	state.event_defs = event_defs
	# 基线：按角色（读档回来只有 id，在这里找回）；没角色用持有方给的
	state.hunter_defs = hunter_defs
	# 难度：读档回来只有 id，在这里找回定义并把机制重新接上（开局那次 RunState.start 已经装过，再装一次是幂等的）
	if state.difficulty == null and state.difficulty_id != &"":
		state.difficulty = difficulty_of(state.difficulty_id)
		state.install_mechanics()
	var ch := character_of(state.character_id)
	if ch != null:
		state.character = ch
		state.player_baseline = ch.baseline()
	elif player_baseline != null:
		state.player_baseline = player_baseline
	var ev := state.events
	ev.battle_finished.connect(func(node: MapNode, r: BattleResult, won: bool):
		_push({"screen": Screen.BATTLE, "node": node, "result": r, "won": won,
			"player": ev.last_battle.get("player", null), "enemy": ev.last_battle.get("enemy", null),
			"enemy_content": ev.last_battle.get("content", {})}))
	state.loot_pending.connect(func(container: GridInventory):
		# 一步之内可能来两份（打赢的尸体 + 搜索收获），RunState 已经并成一份，队里留一个就够
		if _queue.is_empty() or int(_queue[-1]["screen"]) != Screen.LOOT:
			_push({"screen": Screen.LOOT, "container": container}))
	ev.search_opened.connect(func(node: MapNode, session: SearchSession):
		# 会话结束（搜满、遭遇、离开）由这里接着往下走，屏不必管
		session.ended.connect(func(_why: StringName): _flush())
		_push({"screen": Screen.SEARCH, "node": node, "session": session}))
	ev.search_closed.connect(func(_n: MapNode, haul: GridInventory, _why: StringName):
		# 搜索屏里亮过的，到了战利品屏不再重新揭示
		for inst in haul.items():
			seen_loot[(inst as ItemInstance).uid] = true)
	ev.shop_opened.connect(func(node: MapNode, session: ShopSession):
		if session == null:
			return
		session.closed.connect(_flush)
		_push({"screen": Screen.SHOP, "node": node, "session": session}))
	ev.event_pending.connect(func(node: MapNode, def: EventDef):
		_push({"screen": Screen.EVENT, "node": node, "def": def}))
	ev.event_resolved.connect(func(node: MapNode, outcome: StringName, detail: Dictionary):
		# 结果页排在这一步别的事（回放、战利品）前面：先看「你翻出了什么」，再看接下来打的那一场。什么都没发生就不打扰
		if not detail.is_empty():
			_queue.push_front({"screen": Screen.EVENT, "node": node, "outcome": outcome, "detail": detail}))
	ev.rested.connect(func(node: MapNode, restored: int):
		_push({"screen": Screen.REST, "node": node, "restored": restored}))


func _push(entry: Dictionary) -> void:
	_queue.append(entry)


## 队里下一个该看的；队空了回地图；一局结束了进结算（结束之后只有那一场的回放还值得看）
func _flush() -> void:
	while not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		if _skippable(next):
			continue
		_go(int(next["screen"]), next)
		return
	if run != null and run.is_over():
		_settle_run()
		_go(Screen.RESULT, {"result": result})
		return
	if run != null:
		run.poke_hunters()     # 玩家空下来了：猎手够得着就排上开打前的事件屏（071）
	if run != null and run.events.pending_event() != null:
		# 队列空了还有一个等着选的事件（接着放的、或读档回来的）
		_go(Screen.EVENT, {"node": run.events.pending_node(), "def": run.events.pending_event()})
		return
	_go(Screen.MAP)


func _skippable(entry: Dictionary) -> bool:
	var s := int(entry["screen"])
	if run.is_over():
		return s != Screen.BATTLE
	match s:
		Screen.EVENT:
			# 等着选的事件：只有它还是当前待选的才显示（选过了、换了都跳过）；结果页总显示
			if entry.has("def"):
				return run.events.pending_event() != entry.get("def", null)
			return false
		Screen.LOOT:
			return run.pending_loot == null
		Screen.SEARCH:
			return run.events.current_search != entry.get("session", null)
		Screen.SHOP:
			return run.events.current_shop != entry.get("session", null)
	return false


func _go(s: int, payload: Dictionary = {}) -> void:
	screen = s
	last_payload = payload
	screen_changed.emit(s, payload)
#endregion


#region 内容
## 资产目录里的全部章节 / 开局装备，按文件名排序
static func load_chapters() -> Array[ChapterDef]:
	var out: Array[ChapterDef] = []
	for res in _load_dir(ContentPaths.CHAPTERS):
		if res is ChapterDef:
			out.append(res)
	return out


static func load_loadouts() -> Array[LoadoutDef]:
	var out: Array[LoadoutDef] = []
	for res in _load_dir(ContentPaths.LOADOUTS):
		if res is LoadoutDef:
			out.append(res)
	return out


static func load_characters() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for res in _load_dir(ContentPaths.CHARACTERS):
		if res is CharacterDef:
			out.append(res)
	return out


## 按档位排：普通在前
static func load_hunters() -> Dictionary:
	return HunterSystem.load_all()


static func load_difficulties() -> Array[DifficultyDef]:
	var out: Array[DifficultyDef] = []
	for res in _load_dir(ContentPaths.DIFFICULTIES):
		if res is DifficultyDef:
			out.append(res)
	out.sort_custom(func(a: DifficultyDef, b: DifficultyDef) -> bool:
		return a.level < b.level if a.level != b.level else String(a.id) < String(b.id))
	return out


static func load_run_buffs() -> Dictionary:
	return RunBuffs.load_all()


static func load_events() -> Dictionary:
	return EventPlacer.load_all()


## 局外规则（仓库多大）。没导入资产时 null，MetaState 用默认大小
static func load_meta_rules(id: StringName = &"standard") -> MetaRules:
	var path := ContentPaths.asset_file("meta_rules", String(id))
	return load(path) as MetaRules if ResourceLoader.exists(path) else null


static func _load_dir(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var names: Array[String] = []
	for file_name in dir.get_files():
		var name := file_name.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			names.append(name)
	names.sort()
	for name in names:
		var res := ResourceLoader.load(dir_path.path_join(name))
		if res != null:
			out.append(res)
	return out
#endregion

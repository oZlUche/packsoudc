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

enum Screen { MAIN_MENU, SETUP, MAP, BATTLE, LOOT, SEARCH, SHOP, EVENT, REST, RESULT, META }

signal screen_changed(screen: int, payload: Dictionary)
signal run_started(state: RunState)
signal run_ended(result: RunResult)

var items: ItemDatabase = null
var enemies: EnemyDatabase = null
var sets: SetDatabase = null
var meta: MetaState = null
var chapters: Array[ChapterDef] = []
var loadouts: Array[LoadoutDef] = []
var save_path: String = RunSave.DEFAULT_PATH
var meta_path: String = MetaSave.DEFAULT_PATH
## 玩家基线（4.2）。角色系统之前由持有方统一给；null = 编译器默认
var player_baseline: CombatantBaseline = null

var run: RunState = null
var result: RunResult = null
var screen: int = Screen.MAIN_MENU
var last_payload: Dictionary = {}
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
	_go(Screen.MAIN_MENU)


func new_run() -> void:
	_go(Screen.SETUP)


func show_meta() -> void:
	_go(Screen.META)


## 从一章、一套装备、一个种子开一局。生成不出图返回 null，停在开局屏
func begin(chapter: ChapterDef, loadout: LoadoutDef, seed: int) -> RunState:
	var kit: Array[StringName] = []
	if loadout != null:
		kit = loadout.items.duplicate()
	var state := RunState.start(chapter, seed, items, enemies, sets, kit)
	if state == null:
		return null
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
	if state.is_over():
		# 结束了的一局不该还有存档；有就直接进结算
		_flush()
	else:
		_go(Screen.MAP)
	run_started.emit(state)
	return true


func save() -> bool:
	return run != null and not run.is_over() and RunSave.write(run, save_path) == OK


## 存档回主菜单（随时可以离开：开着的店 / 搜索视为离开）
func save_and_quit() -> bool:
	var ok := save()
	to_main_menu()
	return ok


## 结算看完了：进 meta（只进一次）、存 meta、删掉这一局的存档，然后看局外
func finish_result() -> void:
	if result != null and not _settled:
		_settled = true
		meta.absorb(result)
		MetaSave.write(meta, meta_path)
		RunSave.remove(save_path)
	_go(Screen.META, {"result": result})
#endregion


#region 地图上的动作
func pick_spawn(id: int) -> bool:
	return run != null and run.pick_spawn(id)


## 走一步。这一步引发的事件都排进了队，走完按顺序给玩家看
func step_to(id: int) -> bool:
	if run == null or not run.step_to(id):
		return false
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


func take_loot(uid: int) -> bool:
	if run == null:
		return false
	var ok := run.take_loot(uid)
	if run.pending_loot == null:
		_flush()
	return ok


func take_all_loot() -> int:
	if run == null:
		return 0
	var n := run.take_all_loot()
	_flush()
	return n


func discard_loot() -> void:
	if run == null:
		return
	run.discard_loot()
	_flush()
#endregion


#region 接线
func _adopt(state: RunState) -> void:
	run = state
	result = null
	_settled = false
	_queue.clear()
	if player_baseline != null:
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
	ev.shop_opened.connect(func(node: MapNode, session: ShopSession):
		if session == null:
			return
		session.closed.connect(_flush)
		_push({"screen": Screen.SHOP, "node": node, "session": session}))
	ev.event_resolved.connect(func(node: MapNode, outcome: StringName, detail: Dictionary):
		_push({"screen": Screen.EVENT, "node": node, "outcome": outcome, "detail": detail}))
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
		if result == null:
			result = RunResult.settle(run)
			run_ended.emit(result)
		_go(Screen.RESULT, {"result": result})
		return
	_go(Screen.MAP)


func _skippable(entry: Dictionary) -> bool:
	var s := int(entry["screen"])
	if run.is_over():
		return s != Screen.BATTLE
	match s:
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

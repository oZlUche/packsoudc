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

enum Screen { MAIN_MENU, SETUP, MAP, BATTLE, LOOT, SEARCH, SHOP, EVENT, REST, RESULT, META, SETTINGS, PREBATTLE, SLOTS, SAFE, ALTAR, ENCYCLOPEDIA }

signal screen_changed(screen: int, payload: Dictionary)
## 101 第 5 刀：当前的这一局换了（开局 / 读档 / 回主菜单时 `null`）。UI 据此把只属于一局的东西挂上 / 摘掉
## （[ItemTooltip] 的信仰探针就是这么接的 —— core 不认识 ui）
signal run_changed(state: RunState)

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
## 091：成就的定义（按 order 排）。什么时候算见 [method check_achievements]
var achievement_defs: Array[AchievementDef] = []
## 110：局外科技的定义（按 order 排）。等级与上交记录在 [MetaState]，逻辑在 [TechService]
var tech_defs: Array[TechDef] = []
## 114：百科手写的机制页；词条页按内容自动生成（[method encyclopedia]）
var help_pages: Array[HelpPageDef] = []
var _encyclopedia: Encyclopedia = null
## 101 第 4 刀：成就与解锁的逻辑在这个服务里（纯逻辑：看局外与内容算结果，不碰存盘与转屏）。
## 内容与「全部解锁」开关由 [method _sync_achievements] 同步过去
var achievements: Achievements = Achievements.new()
## 全部猎手定义（id → HunterDef，069 / 071）；猎手机制按它造猎手
var hunter_defs: Dictionary = {}
## 信仰定义（8-4）：id → FaithDef，给名字与说明用；机制只看标签（[FaithState]）
var faith_defs: Dictionary = {}
## 合成配方（084）：开局给 RunState、读档后补上
var recipes: Array[RecipeDef] = []
var save_path: String = RunSave.DEFAULT_PATH
var meta_path: String = MetaSave.DEFAULT_PATH
## 098：最近一次「读不出来、已备份」的局外存档文件路径（空 = 没发生过）。读取存档屏与主菜单各显示一句
var meta_backup: String = ""
## 098：同上，进行中的那一局
var run_backup: String = ""
## 当前位是更新版本的游戏存的（它的存档版本号；0 = 不是）。这时这一位只读：不读、不写、不备份、不能接着玩，
## 免得旧版本把新档当坏档备份掉、再存一份空的盖上去
var newer_slot: int = 0
## 089（作者定）：存档位。null = 老的单文件模式（测试、沙盒）；持有方给了就按位存：save_path / meta_path 指向当前位（[method use_slot]）
var slots: SaveSlots = null
var slot: int = 0
var settings_path: String = GameSettings.DEFAULT_PATH
## 玩家的设置（自动关战利品屏、底色、战斗倍速……）。持有方读进来；改了调 save_settings
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
	return s in [Screen.BATTLE, Screen.LOOT, Screen.SEARCH, Screen.SHOP, Screen.EVENT, Screen.REST, Screen.PREBATTLE, Screen.SAFE, Screen.ALTAR]


#region 底屏之间
func to_main_menu() -> void:
	_reset_run()
	run_changed.emit(null)     # 096：局外悬浮窗不按信仰状态上色（UI 摘掉探针）
	save_meta()
	_go(Screen.MAIN_MENU)


#region 存档位（089）
## 切到第 n 位：路径指过去、局外读进来（没有就一份新的，第一次存盘时才落地）、记进设置。当前的局丢掉（调用方先存）
func use_slot(n: int) -> void:
	if slots == null:
		return
	# 101 第 4 刀：建目录、算路径、读局外、读不出来先备份（098）都在 SaveSlots.open 里；这里只管当前位与这一局
	var opened := slots.open(n, items, meta_rules, tech_defs)
	slot = int(opened["slot"])
	newer_slot = int(opened.get("newer", 0))
	save_path = String(opened["run_path"])
	meta_path = String(opened["meta_path"])
	if String(opened["backup"]) != "":
		meta_backup = String(opened["backup"])     # 界面上说一句，玩家知道老档还在
	var loaded := opened["meta"] as MetaState
	meta = loaded if loaded != null else MetaState.new(meta_rules)
	derive_techs()
	_reset_run()
	if settings != null and settings.save_slot != n:
		settings.save_slot = n
		save_settings()


## 当前位有没有存档（局外文件落过地）。单文件模式：有局内存档或教程打到中途才算
func profile_exists() -> bool:
	if slots != null:
		return slots.exists(slot)
	return has_save() or continue_target() != null


## 主菜单「继续」：读当前位接着玩 —— 有局内存档读档；教程打到中途开下一张；都没有就按这份存档开新的一局（教程从头 / 开局屏）
func continue_game() -> bool:
	if newer_slot > 0:
		return false
	if has_save() or continue_target() != null:
		return continue_run()
	if not profile_exists():
		return false
	new_run()
	return true


## 主菜单「新的游戏」：开一份新存档 —— 挑一个空位切过去再开局；三位都满了去读取存档屏（删一个再来）。单文件模式就是 new_run
func start_new_game() -> bool:
	if slots == null:
		new_run()
		return true
	var n := slots.first_empty()
	if n < 0:
		_go(Screen.SLOTS, {"full": true})
		return false
	return new_game_in(n)


## 在第 n 位开新存档（那一位有东西就先删）
func new_game_in(n: int) -> bool:
	if slots == null:
		new_run()
		return true
	save_meta()
	slots.remove(n)
	use_slot(n)
	new_run()
	return true


## 读第 n 位：切过去，然后和「继续」一样。空位返回 false
func load_slot(n: int) -> bool:
	if slots == null or not slots.exists(n):
		return false
	save_meta()
	use_slot(n)
	return continue_game()


## 删第 n 位。删的是当前位就换成一份空的局外
func delete_slot(n: int) -> void:
	if slots == null:
		return
	slots.remove(n)
	if n == slot:
		newer_slot = 0
		meta = MetaState.new(meta_rules)
		_reset_run()


func show_slots() -> void:
	_go(Screen.SLOTS)
#endregion


## 当前的这一局丢掉（回主菜单、换存档位、删当前位）：局、结算、排着没看的屏都清掉
func _reset_run() -> void:
	run = null
	result = null
	_queue.clear()


func new_run() -> void:
	grant_first_kit()
	save_meta()
	# 084（作者：序章不要开局页面）：教程直接开、不经开局屏 —— 角色取它列的第一个、种子随机；教程全通了才是开局屏（随机一局）
	var target := new_run_target()
	if target != null and begin_direct(target) != null:
		return
	_go(Screen.SETUP)


## 「新的一局」会直接开哪一章（不经开局屏）；会走开局屏时返回 null。
## 作者定（085）：**新的一局 = 从头开始**。教程（带 `hidden_by_unlock` 的章）还没全通就从第一张教程开，不管前面几张通没通 ——
## 接着往下打的是「继续」（[method continue_target]）。教程全通了就看还能选的：只剩一章又 skip_setup 才直接开，否则开局屏
func new_run_target() -> ChapterDef:
	var tuts := tutorial_chapters()
	if not tuts.is_empty() and not tutorials_done():
		return tuts[0]
	var chs := available_chapters()
	if chs.size() == 1 and chs[0].skip_setup:
		return chs[0]
	return null


## 「继续」会直接开哪一章：有局内存档时是 null（那是读档，不是开新章）；教程打到中途（有通关的、还有没通关的）
## 就是下一张没通关的教程；别的情况 null。主菜单：有存档或这里非 null 才显示「继续」，和「新的一局」并列
func continue_target() -> ChapterDef:
	if has_save():
		return null
	var tuts := tutorial_chapters()
	if tuts.is_empty() or tutorials_done():
		return null
	var any_done := false
	for c in tuts:
		if meta != null and meta.has_unlock(c.hidden_by_unlock):
			any_done = true
			break
	if not any_done:
		return null
	for c in tuts:
		if not (meta != null and meta.has_unlock(c.hidden_by_unlock)):
			return c
	return null


## 有存档就读档接着玩；没有就接着打下一张教程（[method continue_target]）。两样都没有返回 false
func continue_run() -> bool:
	if newer_slot > 0:
		return false
	var state := RunSave.read(items, enemies, sets, save_path)
	if state == null and RunSave.exists(save_path) and slots != null:
		run_backup = slots.backup(slot, "run")     # 098：读不出来的一局也先备份，否则「继续」每次都撞同一面墙
	if state != null:
		_adopt(state)
		_flush()     # 读档回来：等着选的事件还在这一屏；结束了的直接进结算；否则回地图
		return true
	var target := continue_target()
	if target == null:
		return false
	grant_first_kit()
	save_meta()
	return begin_direct(target) != null


## 教程章（有 `hidden_by_unlock` 的），按顺序
func tutorial_chapters() -> Array[ChapterDef]:
	var out: Array[ChapterDef] = []
	for c in chapters:
		if c.hidden_by_unlock != &"":
			out.append(c)
	out.sort_custom(func(a: ChapterDef, b: ChapterDef) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return out


## 教程是不是全通了（没有教程章也算全通）
func tutorials_done() -> bool:
	for c in tutorial_chapters():
		if not (meta != null and meta.has_unlock(c.hidden_by_unlock)):
			return false
	return true


## 084：不经开局屏直接开一章：角色 = 这一章能选的第一个，种子随机；开了先过 intro 事件（配了的话）。开不了返回 null
func begin_direct(chapter: ChapterDef, seed: int = -1) -> RunState:
	if chapter == null:
		return null
	var chars := characters_for(chapter)
	var ch: CharacterDef = chars[0] if not chars.is_empty() else null
	var s := seed if seed >= 0 else (randi() % 1_000_000) + 1
	var state := begin(chapter, null, s, [] as Array[int], ch, [])
	if state == null:
		return null
	show_intro()
	return state


## 084：章节的开场事件（`ChapterDef.intro_event`）：站在出生点上先弹一屏。没配、没站上去、找不到定义都不弹；返回弹了没有
func show_intro() -> bool:
	if run == null or run.chapter == null or run.chapter.intro_event == &"" or run.travel == null or run.travel.current_id < 0:
		return false
	var def := run.events.def_by_id(run.chapter.intro_event)
	var node := run.current_node()
	if def == null or node == null:
		return false
	run.events.set_pending(node, def, node.type)
	_flush()
	return true


## 084：这一章开了节点浮窗没有（第二章开放的功能，做成章节开关）；设置里的「预览」开了就不看章节
func tooltips_enabled() -> bool:
	if run == null:
		return false
	if settings != null and settings.node_tooltips_preview:
		return true
	if has_ability(&"node_tooltips"):
		return true     # 088：拿到过望远镜（带 node_tooltips 标签的特殊道具）
	return run.chapter != null and run.chapter.node_tooltips


## 088：局外拿到过的特殊道具里有没有带这个标签的（能力由标签说明）
func has_ability(tag: StringName) -> bool:
	if meta == null or items == null:
		return false
	for id in meta.keepsakes:
		var def := items.get_def(id)
		if def != null and def.tags.has(tag):
			return true
	return false


## 088：开局发这一章的特殊道具：记进局外、存盘，攒一句通知给地图屏（[method take_notes]）。返回新拿到的
func _grant_keepsakes(chapter: ChapterDef) -> Array[ItemDef]:
	var got: Array[ItemDef] = []
	if chapter == null or meta == null or items == null:
		return got
	for id in chapter.starting_keepsakes:
		var def := items.get_def(id)
		if def == null or not meta.grant_keepsake(id):
			continue
		got.append(def)
		_notes.append("获得特殊道具【%s】：不占背包，图鉴里点亮%s" % [Names.of(def), "；从现在起把鼠标停在地图的点上能看到它的情报" if def.tags.has(&"node_tooltips") else ""])
	if not got.is_empty():
		save_meta()
	return got


## 攒着的通知（地图屏开的时候取走打进日志）
var _notes: Array[String] = []


func take_notes() -> Array[String]:
	var out := _notes.duplicate()
	_notes.clear()
	return out


#region 成就与解锁（091；101 第 4 刀：逻辑在 Achievements 服务里，这里只管同步、存盘与转屏）
## 把现在的局外、内容与「全部解锁」开关交给服务（它不认识 GameFlow / GameSettings）
func _sync_achievements() -> Achievements:
	achievements.meta = meta
	achievements.defs = achievement_defs
	achievements.items = items
	achievements.chapters = chapters
	achievements.difficulties = difficulties
	achievements.unlock_all = settings != null and settings.unlock_all
	return achievements


## 看有没有新完成的成就（完成了记进局外、给它许诺的解锁、攒一句通知）；改了就存。返回新完成的。
## 「全部解锁」开着不计（作者定 10.2 第 4 条）；一局结算之后与读档之后各算一次
func check_achievements() -> Array[AchievementDef]:
	var got := _sync_achievements().check()
	if not got.is_empty():
		_notes.append_array(achievements.notes)
		achievements.notes.clear()
		save_meta()
	return got


func achievement_of(id: StringName) -> AchievementDef:
	return _sync_achievements().of_id(id)


## 哪一枚成就给这个解锁 id；没有 null
func achievement_granting(unlock_id: StringName) -> AchievementDef:
	return _sync_achievements().granting(unlock_id)


## 这个解锁 id 开的是什么（成就页写「解锁：道具 X、地图 Y、难度 Z」）
func unlock_names(unlock_id: StringName) -> Array[String]:
	return _sync_achievements().unlock_names(unlock_id)


## 现在锁着的道具（requires_unlock 还没解锁）
func locked_item_ids() -> Array:
	return _sync_achievements().locked_item_ids()


## 把锁着的道具设进道具库（搜索 / 掉落 / 商店 / 敌人的池都从 ids() 拿）。开局前调；设置改了也调
func apply_item_locks() -> void:
	_sync_achievements().apply_item_locks()


## 091：老手的「全部解锁」开关。返回现在开没开
func toggle_unlock_all() -> bool:
	if settings == null:
		return false
	settings.unlock_all = not settings.unlock_all
	save_settings()
	apply_item_locks()
	return settings.unlock_all


## 091（10.2 第 3 条）：这一局的章节有「本图规则」卡、而且还没看过 → 地图屏第一次打开时弹
func rules_card_pending() -> bool:
	return run != null and _sync_achievements().rules_card_pending(run.chapter)


func mark_rules_seen() -> void:
	if run != null and _sync_achievements().mark_rules_seen(run.chapter):
		save_meta()
#endregion


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
	return _by_id(loadouts, id) as LoadoutDef


func character_of(id: StringName) -> CharacterDef:
	return _by_id(characters, id) as CharacterDef


func difficulty_of(id: StringName) -> DifficultyDef:
	return _by_id(difficulties, id) as DifficultyDef


## 内容表里按 id 找一份定义（章节、角色、难度、开局装备都是「有 id 的资源」的数组）；没有 null
static func _by_id(list: Array, id: StringName) -> Resource:
	for d in list:
		if d.id == id:
			return d
	return null


## 091：这个解锁 id 现在算不算解锁了 —— 空 = 一直开着；设置里「全部解锁」开着什么都算；否则看局外
func unlocked(id: StringName) -> bool:
	return _sync_achievements().unlocked(id)


## 这个玩家现在能选的难度：没有解锁要求的，和已解锁的（作者：局外解锁的特殊选项）
func available_difficulties() -> Array[DifficultyDef]:
	var out: Array[DifficultyDef] = []
	for d in difficulties:
		if unlocked(d.requires_unlock):
			out.append(d)
	return out


## 开局屏能列的章节（083）：没有解锁要求的和已解锁的，按 order 再按 id 排。一章都列不出来就全列（解锁 id 写错了不该把游戏锁死）
func available_chapters() -> Array[ChapterDef]:
	var out: Array[ChapterDef] = []
	for c in chapters:
		if c.hidden_by_unlock != &"" and meta != null and meta.has_unlock(c.hidden_by_unlock):
			continue     # 084：通关了的教程收起（只看真解锁：「全部解锁」不该把教程藏掉）
		if unlocked(c.requires_unlock):
			out.append(c)
	if out.is_empty():
		out = chapters.duplicate()
	out.sort_custom(func(a: ChapterDef, b: ChapterDef) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return out


## 这一章能选的角色（083）：章节列了就只列那些，没列就全部
func characters_for(chapter: ChapterDef) -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for ch in characters:
		if chapter == null or chapter.allows_character(ch.id):
			out.append(ch)
	return out


## 090（作者定）：带回来的背包没清空**不再拦着开新局**（原 058 第 7 条的门）—— 开局屏把它们收到地上：拖上包 = 带上、拖进仓库 = 置入、
## 留着的出发就没了、回主菜单原样放回。局外屏只提示这一句；没有就空串
func pending_hint() -> String:
	if meta != null and meta.has_pending_board():
		return "上一局带回来的背包还有 %d 件没置入：可以现在置入或不要了；不管的话，开局屏里它们会放到地上，出发就没了" % meta.board.item_count()
	return ""


## 098：读不出来、已经备份下来的那一句（没发生过返回空）。读取存档屏与主菜单各显示一次
func backup_notice() -> String:
	if newer_slot > 0:
		return UiText.t("slots.newer") % [newer_slot, maxi(MetaState.SAVE_VERSION, RunState.SAVE_VERSION)]
	if meta_backup != "":
		return UiText.t("slots.backed_up") % meta_backup.get_file()
	if run_backup != "":
		return UiText.t("slots.run_backed_up") % run_backup.get_file()
	return ""


func save_meta() -> bool:
	return meta != null and writable() and MetaSave.write(meta, meta_path) == OK


## 当前位能不能写（更新版本的存档只读）
func writable() -> bool:
	return newer_slot <= 0


#region 局外科技（110）
## 按 id 找科技定义；没有 null
func tech_of(id: StringName) -> TechDef:
	return TechService.find(tech_defs, id)


## 120：由进度表推算科技派生值（仓库行数、保险箱、局外 buff），见 [method TechService.derive]
func derive_techs() -> void:
	TechService.derive(meta, tech_defs)


## 上交一件（上交即消耗）：成了就存
func submit_tech(id: StringName, uid: int) -> bool:
	var ok := TechService.submit(meta, tech_of(id), uid)
	if ok:
		save_meta()
	return ok


## 升一级：成了就存
func upgrade_tech(id: StringName) -> bool:
	var ok := TechService.upgrade(meta, tech_of(id))
	if ok:
		save_meta()
	return ok
#endregion


## 仓库面板的两个动作：改了就存
func store_all() -> Dictionary:
	var got := meta.store_all()
	save_meta()
	return got


func discard_board() -> void:
	meta.discard_board()
	save_meta()


## 091（作者定）：基地商店。卖掉仓库里的一件 / 按稀有度一键卖；改了就存
func sell_ratio() -> float:
	return meta_rules.sell_ratio if meta_rules != null else 0.5


func sell_item(uid: int) -> int:
	var got := meta.sell_item(uid, sell_ratio())
	if got >= 0:
		save_meta()
	return got


func sell_where(max_rarity: int) -> Dictionary:
	var got := meta.sell_where(max_rarity, sell_ratio())
	if int(got["count"]) > 0:
		save_meta()
	return got


## 局外 buff 的开关（占位：将来由任务系统、局外科技决定）。改了就存
func toggle_meta_buff(id: StringName) -> bool:
	var on := meta.toggle_buff(id)
	save_meta()
	return on


## 119 开发区：直接改进度表（存档的 `tech_levels`）里某个科技的级数，夹在 0 ～ 满级；上交记录清掉，
## 效果按新级数重算（走 [method TechService.derive] 同一条路；仓库缩行只删空行）。改了就存。返回实际的级数
func dev_set_tech_level(id: StringName, level: int) -> int:
	var def := TechService.find(tech_defs, id)
	if def == null:
		return 0
	var lv := clampi(level, 0, def.max_level())
	if lv == 0:
		meta.tech_levels.erase(String(id))
	else:
		meta.tech_levels[String(id)] = lv
	meta.tech_deposits.erase(String(id))
	TechService.derive(meta, tech_defs)
	meta.changed.emit()
	save_meta()
	return lv


## 局外解锁的开关（占位：将来由成长系统决定）。改了就存
func toggle_unlock(id: StringName) -> bool:
	var on := meta.toggle_unlock(id)
	save_meta()
	return on


func show_meta() -> void:
	_go(Screen.META)


func show_settings() -> void:
	_go(Screen.SETTINGS)


## 114：百科（主菜单进是独立一屏；地图的暂停菜单把它嵌进遮罩，不走这里）。[param page] 给了就直接翻到那页
func show_encyclopedia(page: String = "") -> void:
	_go(Screen.ENCYCLOPEDIA, {"page": page} if page != "" else {})


## 114：这本百科（第一次用时按手写页 + 当前内容造；「相关道具」按图鉴遮名字）
func encyclopedia() -> Encyclopedia:
	if _encyclopedia == null:
		_encyclopedia = Encyclopedia.build(help_pages, items)
	_encyclopedia.lit = func(id: StringName) -> bool: return meta == null or meta.codex_lit(id)
	return _encyclopedia


func save_settings() -> bool:
	return settings != null and settings.save_to(settings_path) == OK


## 从一章、一个种子开一局。两条路：
## - 老路（测试、没有角色）：[param loadout] 的清单 + [param from_warehouse]（仓库里的 uid）当 kit；
## - 角色路（开局屏，067）：[param character] 定棋盘、体力、基线、初始包，[param layout] 是开局屏摆好的棋盘
##   （仓库里的东西拖上去那一刻已经离开仓库）。
## 两条路都在开局那一刻存 meta：带进去的从仓库拿走（一局里是新实例，3.1 存档只写 id），撤离了回来，死了就是真没了。
## 生成不出图返回 null，停在开局屏
func begin(chapter: ChapterDef, loadout: LoadoutDef, seed: int, from_warehouse: Array[int] = [] as Array[int],
		character: CharacterDef = null, layout: Array = [], difficulty: DifficultyDef = null, scale: StringName = &"", carry_value: int = 0) -> RunState:
	var kit: Array[StringName] = []
	if loadout != null:
		kit = loadout.items.duplicate()
	var taken: Array[ItemInstance] = []
	for uid in from_warehouse:
		var inst := meta.warehouse.get_item(uid)
		if inst != null and inst.def != null:
			kit.append(inst.def.id)
			taken.append(inst)
	if difficulty != null and not unlocked(difficulty.requires_unlock):
		return null     # 没解锁的难度开不了（界面本来就不列，这里是兜底）
	apply_item_locks()     # 091：成就还没开的道具这一局不出现
	# 094：从仓库带进来的总价值（按 uid 带的直接算；开局屏摆好的棋盘由它算好传进来）
	var value := maxi(0, carry_value)
	for inst in taken:
		value += ItemValue.of(inst.def)
	# 101：模块要的运行时输入（保险箱几格来自局外成长、带入价值来自这一次的选择）
	var inputs := {SafeModule.ID: {"size": safe_size()}, CountdownModule.ID: {"carry_value": value}}
	var state := RunState.start(chapter, seed, items, enemies, sets, kit, buff_defs, meta_buffs(), character, layout, difficulty, hunter_defs, scale, inputs)
	if state == null:
		return null
	for inst in taken:
		meta.warehouse.remove(inst.uid)
	# 090：进了游戏，上一局带回来还没清的就没了（开局屏的地上规则；不经开局屏的路一样）
	var lost := meta.board != null
	if lost:
		meta.discard_board()
	if not taken.is_empty() or character != null or lost:
		save_meta()
	_adopt(state)
	_grant_keepsakes(chapter)
	_go(Screen.MAP)
	return state


func has_save() -> bool:
	return RunSave.exists(save_path)


func save() -> bool:
	return run != null and not run.is_over() and writable() and RunSave.write(run, save_path) == OK


## 存档回主菜单（随时可以离开：开着的店 / 搜索视为离开）
func save_and_quit() -> bool:
	var ok := save()
	to_main_menu()
	return ok


## 092（作者定）：关上保险箱 —— 里面有东西就锁上送回基地（不能再改），屏关掉；空着就只是收起（还能再开）。返回锁没锁
func close_safe() -> bool:
	if run == null:
		return false
	var safe := SafeModule.of(run)     # 101：保险箱的状态在模块里
	var locked := safe != null and safe.lock()
	if locked:
		_go(Screen.MAP, {})
	else:
		hide_overlay()
	return locked


## 093：关掉神坛屏（回地图；站着还能再开，除非用过特殊操作）
func close_altar() -> void:
	if run == null:
		return
	_go(Screen.MAP, {})
	var here := run.current_node()
	if here != null and not here.is_visited() and not run.is_over() and NodeEvents.effective_type(here) != &"rest":
		run.events.handle(here)     # 093：神坛上把这个点改造成别的了：立刻发生（还是没用完的休息点就不算，回地图）
	_flush()


## 093：神坛上献祭 [param uids]（棋盘 / 地上 / 祭品台里的实例 uid）。返回 RunState.offer 的账；卖掉的实例从所在容器移除
func offer(insts: Array, node: MapNode = null) -> Dictionary:
	if run == null:
		return {"points": 0, "count": 0}
	var altar := AltarModule.of(run)
	if altar == null:
		return {"points": 0, "count": 0}
	var got := altar.offer(insts, node)
	if int(got["count"]) > 0:
		for inst in insts:
			var it := inst as ItemInstance
			if it == null:
				continue
			for c in [run.board, run.storage]:
				if (c as ItemContainer).has_item(it.uid):
					(c as ItemContainer).remove(it.uid)
		save()
	return got


## 136：角色带的「脱身」技能（没有 = null）
func slip_skill() -> RunSkill:
	if run == null or run.skills == null:
		return null
	for d in run.skills.defs:
		if d is SlipSkill:
			return d
	return null


## 136：战前准备屏上按「溜走」：这一场不打（点用过、没战利品、不扣体力），然后往下走（回地图或下一屏）。返回空串 = 溜了，否则是原因
func slip_battle() -> String:
	var d := slip_skill()
	if d == null:
		return "没有能溜走的技能"
	var why := run.use_skill(d.id)
	if why != "":
		return why
	_flush()
	return ""


## 093（蛮神 3 级）：战前准备屏上秒杀这一场（效果构件自己查条件、扣体力）
func smite() -> bool:
	if run == null:
		return false
	var altar := AltarModule.of(run)     # 101：信仰级效果在神坛模块里取
	var perk := altar.perk(&"smite") if altar != null else null
	if perk == null or not perk.prebattle_apply(run):
		return false
	_flush()
	return true


## 092（作者定）：保险箱几格（局外规则，初始 3×3）
func safe_size() -> Vector2i:
	var base := meta.rules.safe_size if meta != null and meta.rules != null else Vector2i(3, 3)
	return base + (meta.safe_bonus if meta != null else Vector2i.ZERO)     # 118：科技「保险箱扩格」


## 118：开局带的局外 buff = 开发开关的 + 科技给的（去重，开关在前）
func meta_buffs() -> Array[StringName]:
	var out: Array[StringName] = []
	if meta == null:
		return out
	for id in meta.active_buffs + meta.tech_buffs:
		if not out.has(id):
			out.append(id)
	return out


## 092（作者定）：离开结算屏时，地上没背出来的一键出售（按基地的出售比例），钱进局外。这里只算不卖
func stash_sale_preview() -> Dictionary:
	return MetaState.left_behind_preview(result, sell_ratio())


## 真卖（账在 MetaState 里算，101 第 4 刀）：只卖一次，记进 last_absorbed["stash_sold"] 给局外屏提示
func _sell_left_behind() -> Dictionary:
	if meta == null:
		return {"count": 0, "funds": 0}
	var got := meta.sell_left_behind(result, sell_ratio())
	if int(got["count"]) > 0:
		last_absorbed["stash_sold"] = got
	return got


## 结算看完了：去局外（账在进结算屏之前就记了，见 _settle_run）；地上剩的在这一步一键出售（092）
func finish_result() -> void:
	_sell_left_behind()
	save_meta()
	_go(Screen.META, {"result": result, "stash_sold": last_absorbed.get("stash_sold", {})})


## 085：结算之后该直接进的下一章（撤离成功、这一章配了 next_chapter、它开着）；没有 null
func next_chapter() -> ChapterDef:
	if result == null or not result.is_extracted() or run == null or run.chapter == null or run.chapter.next_chapter == &"":
		return null
	for c in available_chapters():
		if c.id == run.chapter.next_chapter:
			return c
	return null


func chapter_of(id: StringName) -> ChapterDef:
	var c := _by_id(chapters, id)
	return (c if c != null else _by_id(chapters, IdAliases.chapter(id))) as ChapterDef     # 114：老存档里的 chapter_01 = free_mode


## 085：从结算屏直接进下一张教学图：带回来的先全进仓库（教程不从仓库带东西），再按下一章直接开。开不了回局外
func start_next_chapter() -> bool:
	var next := next_chapter()
	if next == null:
		finish_result()
		return false
	_sell_left_behind()     # 092：离开结算屏就卖地上剩的
	meta.store_all()
	if meta.has_pending_board():
		meta.discard_board()
	save_meta()
	if begin_direct(next) == null:
		finish_result()
		return false
	return true


## 一局结束了：算账、进 meta（只进一次）、存 meta、删掉这一局的存档。结算屏拿到的已经是记完账的局外
func _settle_run() -> void:
	if result != null:
		return
	result = RunResult.settle(run)
	if not _settled:
		_settled = true
		last_absorbed = meta.absorb(result)
		# 083：撤离成功给这一章许诺的局外解锁（序章通关开下一张 / 自由模式）
		if result.is_extracted() and run != null and run.chapter != null and run.chapter.grants_unlock != &"":
			meta.grant_unlock(run.chapter.grants_unlock)
		check_achievements()     # 091：这一局的账记完了，看成就
		if writable():
			MetaSave.write(meta, meta_path)
			RunSave.remove(save_path)
#endregion


#region 地图上的动作
## 099（作者定）：把棋盘上的这件信物奉为主信仰（右键 / 在棋盘里重新落下都走这里）。
## 不是信物、不在棋盘上、这一局没开始都返回 false
func reseat_anchor(uid: int) -> bool:
	if run == null or run.board == null:
		return false
	var inst := run.board.get_item(uid)
	if inst == null or inst.def == null or not inst.def.is_anchor():
		return false
	return run.board.reseat(uid)


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


## 084：玩家关闭了搜索屏：回到事件屏（再搜 / 走）。没有开着的搜索返回 false
func close_search() -> bool:
	if run == null or not run.events.pause_search():
		return false
	_flush()
	return true


## 084：战前准备屏上按了「开战」：真打，然后接着看回放、战利品。没有等着的一场返回 false
func start_battle() -> bool:
	if run == null or not run.events.start_pending_battle():
		return false
	_flush()
	return true


## 084：把这个点的叠层**最小化**回地图，**什么都不结束**：搜索 / 商店会话还开着、没拿的战利品还在这个点上、地上还在。
## 作者定：不是关掉再重开，而是那一屏留着（揭示进度、日志都在），只是藏起来；[method reopen_node] 把它原样放回来。
## 载荷里的 `minimized` 告诉导演「别销毁叠层」。等着选的事件与等着开打的一场不能收（那是必须先处理的）。返回收了没有
func hide_overlay() -> bool:
	if run == null or run.is_over() or not is_overlay(screen):
		return false
	if screen == Screen.LOOT and run.events.pending_event() != null and bool(run.events.pending.get("search_stage", false)):
		run.fold_loot_into_search()     # 反馈：没拿的并进搜索的收获箱、包掉在地上 —— 不再和收获并成一份重新搜
		_flush()     # 搜索遭遇打赢的战利品：没拿完也能关，往下走到「再搜 / 走」
		return true
	if run.events.pending_event() != null or not run.events.pending_battle.is_empty():
		return false
	if screen == Screen.LOOT and run.has_pending_arrival():
		# 134：猎手战的战利品收起来了，这个点的事还挂着：接着进点（剩下的战利品留在这个点上），有事就看，没事回地图
		run.poke_hunters()
		if not _queue.is_empty() or run.events.pending_event() != null or not run.events.pending_battle.is_empty():
			_flush()
			return true
	if screen == Screen.LOOT and _boss_extracts():
		# 087：BOSS 的战利品屏「收起」= 不要剩下的，直接撤离结算
		run.discard_loot()
		_flush()
		return true
	_go(Screen.MAP, {"minimized": true})
	return true


## 084：还没走，这个点上有没有能重新打开的界面（等着选的事件 / 等着开打的一场 / 开着的搜索或商店 / 没拿完的战利品）
func can_reopen() -> bool:
	return run != null and not run.is_over() and not _reopen_entry().is_empty()


## 084：重新打开这个点的最后一个界面（最小化的那一屏原样恢复：载荷里的 `restore` 告诉导演先找藏着的那块）。没有可开的返回 false
func reopen_node() -> bool:
	var entry := _reopen_entry()
	if run == null or run.is_over() or entry.is_empty():
		return false
	if bool(entry.get("rest", false)):
		run.events.handle(run.current_node())     # 反馈：没用完的休息点，站着再把选项打开
		_flush()
		return true
	entry["restore"] = true
	_go(int(entry["screen"]), entry)
	return true


func _reopen_entry() -> Dictionary:
	if run == null:
		return {}
	var ev := run.events
	if ev.pending_event() != null:
		return {"screen": Screen.EVENT, "node": ev.pending_node(), "def": ev.pending_event()}
	if not ev.pending_battle.is_empty():
		return _prebattle_payload()
	if ev.current_search != null:
		return {"screen": Screen.SEARCH, "node": ev.current_search.node, "session": ev.current_search}
	if ev.current_shop != null:
		return {"screen": Screen.SHOP, "node": ev.current_shop.node, "session": ev.current_shop}
	if run.pending_loot != null:
		return {"screen": Screen.LOOT, "container": run.pending_loot}
	var here := run.current_node()
	var safe := SafeModule.of(run)
	if here != null and NodeEvents.effective_type(here) == &"safe" and safe != null and safe.is_open():
		return {"screen": Screen.SAFE, "node": here}     # 092：站在没锁的保险箱上随时能再开
	var altar := AltarModule.of(run)
	if here != null and altar != null and altar.is_open():
		return {"screen": Screen.ALTAR, "node": here}     # 093：神坛还开着（这一次没用过）
	if here != null and not here.is_visited() and NodeEvents.effective_type(here) == &"rest":
		return {"screen": Screen.EVENT, "node": here, "rest": true}     # 反馈：休息点还有没用的那一份
	return {}


func _prebattle_payload() -> Dictionary:
	var ev := run.events
	return {"screen": Screen.PREBATTLE, "node": ev.pending_battle_node(), "type": StringName(String(ev.pending_battle.get("type", "battle"))),
		"content": ev.pending_battle.get("content", {})}


## 地图上用一个局内技能（082）。返回空串 = 用了；否则是不能用的原因
func use_skill(id: StringName) -> String:
	if run == null:
		return "没有进行中的一局"
	return run.use_skill(id)


## 事件屏上选了第 i 项（063）。选不了返回 false 留在原地；选了按后果往下走
func choose_event(i: int) -> bool:
	if run != null and bool(run.events.pending.get("search_stage", false)):
		run.fold_loot_into_search()     # 战利品屏没关就到了「再搜 / 走」（读档回来等）：同上
	if run == null or not run.events.choose(i):
		return false
	save_meta()     # 091：选项可能立了局外旗标（set_flag）
	_flush()
	return true


func take_loot(uid: int) -> bool:
	if run == null:
		return false
	var held := _loot_uids()
	var ok := run.take_loot(uid)
	seen_loot.erase(uid)
	if run.pending_loot == null:
		_after_loot(held)
	return ok


func take_all_loot() -> int:
	if run == null:
		return 0
	var held := _loot_uids()
	var n := run.take_all_loot()
	_after_loot(held)
	return n


func discard_loot() -> void:
	if run == null:
		return
	var held := _loot_uids()
	run.discard_loot()
	_after_loot(held)


## 这一份待拾取处理完了（拿完 / 全拿 / 不要了）：忘掉它里面「亮过」的，往下走
func _after_loot(held: Array[int]) -> void:
	_forget_seen(held)
	_flush()


## 待拾取里现在有哪些 uid
func _loot_uids() -> Array[int]:
	var out: Array[int] = []
	if run != null and run.pending_loot != null:
		for inst in run.pending_loot.items():
			out.append((inst as ItemInstance).uid)
	return out


## 战利品收完：只忘掉这一份里的「亮过」—— 反馈：以前整张表清空，搜索收获箱里亮过的也跟着忘了，回到搜索屏得重新搜
func _forget_seen(uids: Array[int]) -> void:
	for uid in uids:
		seen_loot.erase(uid)
#endregion


#region 接线
## 117：按设置给这一局开 / 关战斗的内部日志与回放存档（设置屏切换时也调，当场生效）
func apply_battle_trace() -> void:
	if run == null or run.events == null:
		return
	var on := settings != null and settings.battle_trace
	run.events.trace_info = {"dir": BattleArchive.DIR, "run_seed": run.run_seed,
		"chapter": String(run.chapter.id) if run.chapter != null else ""} if on else {}


func _adopt(state: RunState) -> void:
	run = state
	result = null
	_settled = false
	_queue.clear()
	state.buff_defs = buff_defs      # 读档回来的只有 id，定义表在这里
	apply_battle_trace()     # 117：战斗日志按设置开关
	state.event_defs = event_defs
	state.meta = meta     # 091：事件的条件 / 后果看、立局外旗标
	# 基线：按角色（读档回来只有 id，在这里找回）；没角色用持有方给的
	state.hunter_defs = hunter_defs
	state.faith_defs = faith_defs
	var crafting := CraftingModule.of(state)     # 101：合成是一局的模块（配方表是内容，持有方给）
	if crafting != null:
		crafting.recipes = recipes
	# 难度：读档回来只有 id，在这里找回定义并把机制重新接上（本体模块在 from_dict 里已经装过，再装一次是幂等的）
	if state.difficulty == null and state.difficulty_id != &"":
		state.difficulty = difficulty_of(state.difficulty_id)
		state.install_modules()
	if state.events != null:
		state.events.difficulty_def = state.difficulty     # 127：搜索保底按难度等级
	var ch := character_of(state.character_id)
	if ch != null:
		state.set_character(ch)     # 基线、技能的账（读档回来的状态在这里接上定义）
	elif player_baseline != null:
		state.player_baseline = player_baseline
	var ev := state.events
	ev.pause_before_battle = true     # 084：正式游戏开打前先过战前准备屏
	ev.battle_pending.connect(func(node: MapNode, type: StringName, content: Dictionary):
		_push({"screen": Screen.PREBATTLE, "node": node, "type": type, "content": content}))
	ev.battle_finished.connect(func(node: MapNode, r: BattleResult, won: bool):
		_push({"screen": Screen.BATTLE, "node": node, "result": r, "won": won,
			"player": ev.last_battle.get("player", null), "enemy": ev.last_battle.get("enemy", null),
			"enemy_content": ev.last_battle.get("content", {})}))
	# 114：合成是拖到上面立刻发生的（整理面板里），提示就在面板上，不再排结果屏
	state.loot_pending.connect(func(container: GridInventory):
		# 一步之内可能来两份（打赢的尸体 + 搜索收获），RunState 已经并成一份，队里留一个就够
		if _queue.is_empty() or int(_queue[-1]["screen"]) != Screen.LOOT:
			_push({"screen": Screen.LOOT, "container": container}))
	ev.search_opened.connect(func(_node: MapNode, session: SearchSession):
		# 会话结束（遭遇、离开）由这里接着往下走，屏不必管
		session.ended.connect(func(_why: StringName): _flush()))
	ev.search_shown.connect(func(node: MapNode, session: SearchSession):
		# 084：每搜一次给看一回搜索屏
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
	ev.safe_opened.connect(func(node: MapNode):
		_push({"screen": Screen.SAFE, "node": node}))     # 092：踩上保险箱就开
	ev.altar_opened.connect(func(node: MapNode):
		_push({"screen": Screen.ALTAR, "node": node}))     # 093：休息处的神坛
	ev.event_pending.connect(func(node: MapNode, def: EventDef):
		var entry := {"screen": Screen.EVENT, "node": node, "def": def}
		# 084：战利品已经排在队尾时来的事件（「搜索点被余波摧毁」）说的是刚发生的事：先说，再看战利品（东西还在）。
		# 096（作者反馈）：搜索遭遇**打赢**之后接着搜的那一屏（「再搜 / 走」，pending 带 search_stage）是下一步的选择，
		# 得排在尸体的战利品**后面** —— 否则回放一完就回到事件，玩家以为战利品被跳过了
		var stage := bool(ev.pending.get("search_stage", false))
		if not stage and not _queue.is_empty() and int(_queue[-1]["screen"]) == Screen.LOOT:
			_queue.insert(_queue.size() - 1, entry)
		else:
			_push(entry))
	ev.event_resolved.connect(func(node: MapNode, outcome: StringName, detail: Dictionary):
		# 结果页排在这一步别的事（回放、战利品）前面：先看「你翻出了什么」，再看接下来打的那一场。什么都没发生就不打扰
		if not detail.is_empty():
			_queue.push_front({"screen": Screen.EVENT, "node": node, "outcome": outcome, "detail": detail}))
	ev.rested.connect(func(node: MapNode, restored: int):
		_push({"screen": Screen.REST, "node": node, "restored": restored}))
	run_changed.emit(state)     # 101 第 5 刀：UI 把只属于一局的东西挂上（信仰探针）


## 096：现在的信仰状态 —— 激活的 id、阶、信力。不在局里是空字典。
##
## 101 第 5 刀：这是给 UI（[ItemTooltip] 的探针）问的那一份数据。core 不认识 ui：
## 接线由 [GameDirector] 在 [signal run_changed] 上做
func faith_status() -> Dictionary:
	if run == null or run.faith_power == null:
		return {}
	var id := run.active_faith_id()
	return {"active": id, "tier": run.active_faith_tier(), "points": run.faith_power.points_of(id) if id != &"" else 0}


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
		_show_result()
		return
	# 玩家空下来了：猎手够得着就排上开打前的事件屏（071）；134：猎手那一场了结了就接着进挂起的那个点 ——
	# 那个点的事发生时排进队里的（休息结果、回放……）接着看
	if run != null and run.poke_hunters() and not _queue.is_empty():
		_flush()
		return
	if run != null and run.events.pending_event() != null:
		# 队列空了还有一个等着选的事件（接着放的、或读档回来的）
		_go(Screen.EVENT, {"node": run.events.pending_node(), "def": run.events.pending_event()})
		return
	if run != null and not run.events.pending_battle.is_empty():
		# 084：等着开打的一场（读档回来的）：停在战前准备屏
		_go(Screen.PREBATTLE, _prebattle_payload())
		return
	if run != null and run.pending_loot != null:
		# 084：没拿完的战利品还在这个点上就接着给看（只有「收起」走 hide_overlay 才回地图不看它）
		_go(Screen.LOOT, {"container": run.pending_loot})
		return
	if run != null and _boss_extracts() and run.extract_after_boss():
		# 087（作者定）：BOSS 倒下、战利品收完 → 直接撤离结算
		_show_result()
		return
	_go(Screen.MAP)


## 一局结束了：记账（只一次）然后进结算屏
func _show_result() -> void:
	_settle_run()
	_go(Screen.RESULT, {"result": result})


## 087：这一局现在是不是「BOSS 已倒下、收完就撤」的状态
func _boss_extracts() -> bool:
	return run != null and run.boss_cleared and (run.node_rules == null or run.node_rules.boss_extracts)


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
			var session: SearchSession = entry.get("session", null)
			return run.events.current_search != session or session == null or not session.active
		Screen.SHOP:
			return run.events.current_shop != entry.get("session", null)
		Screen.PREBATTLE:
			var node: MapNode = entry.get("node", null)
			return run.events.pending_battle.is_empty() or node == null or int(run.events.pending_battle["node"]) != node.id
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
	for res in ContentPaths.load_resources(ContentPaths.CHAPTERS):
		if res is ChapterDef:
			out.append(res)
	return out


## 096：开局屏可选的预设套（`LoadoutDef.preset`），按装回的顺序
func presets() -> Array[LoadoutDef]:
	var out: Array[LoadoutDef] = []
	for l in loadouts:
		if l != null and l.preset:
			out.append(l)
	return out


## 老路（没有角色定义）与仓库空的第一套用的整套装备：第一套**非预设**的
func default_loadout() -> LoadoutDef:
	for l in loadouts:
		if l != null and not l.preset:
			return l
	return null


static func load_loadouts() -> Array[LoadoutDef]:
	var out: Array[LoadoutDef] = []
	for res in ContentPaths.load_resources(ContentPaths.LOADOUTS):
		if res is LoadoutDef:
			out.append(res)
	return out


static func load_characters() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for res in ContentPaths.load_resources(ContentPaths.CHARACTERS):
		if res is CharacterDef:
			out.append(res)
	return out


## 按档位排：普通在前
static func load_hunters() -> Dictionary:
	return HunterSystem.load_all()


static func load_faiths() -> Dictionary:
	return FaithDef.load_all()


static func load_recipes() -> Array[RecipeDef]:
	return RecipeDef.load_all()


static func load_difficulties() -> Array[DifficultyDef]:
	var out: Array[DifficultyDef] = []
	for res in ContentPaths.load_resources(ContentPaths.DIFFICULTIES):
		if res is DifficultyDef:
			out.append(res)
	out.sort_custom(func(a: DifficultyDef, b: DifficultyDef) -> bool:
		return a.level < b.level if a.level != b.level else String(a.id) < String(b.id))
	return out


## 114：百科的机制页
static func load_help_pages() -> Array[HelpPageDef]:
	var out: Array[HelpPageDef] = []
	for res in ContentPaths.load_resources(ContentPaths.HELP_PAGES):
		if res is HelpPageDef:
			out.append(res)
	return out


## 110：局外科技，按 order 再按 id 排
static func load_techs() -> Array[TechDef]:
	var out: Array[TechDef] = []
	for res in ContentPaths.load_resources(ContentPaths.TECHS):
		if res is TechDef:
			out.append(res)
	out.sort_custom(func(a: TechDef, b: TechDef) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return out


## 091：成就，按 order 再按 id 排
static func load_achievements() -> Array[AchievementDef]:
	var out: Array[AchievementDef] = []
	for res in ContentPaths.load_resources(ContentPaths.ACHIEVEMENTS):
		if res is AchievementDef:
			out.append(res)
	out.sort_custom(func(a: AchievementDef, b: AchievementDef) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return out


static func load_run_buffs() -> Dictionary:
	return RunBuffs.load_all()


static func load_events() -> Dictionary:
	return EventPlacer.load_all()


## 局外规则（仓库多大）。没导入资产时 null，MetaState 用默认大小
static func load_meta_rules(id: StringName = &"standard") -> MetaRules:
	return ContentPaths.load_asset("meta_rules", String(id)) as MetaRules
#endregion

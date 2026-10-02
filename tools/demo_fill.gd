## 截图用的演示数据（101 第 6 刀；原来长在 `ui/game/game_director.gd` 里）。
##
## `tools/capture_scene.gd` 用环境变量 `DEMO_SCREEN` 指定要截哪一屏（`setup` / `map` / `bag` / `prebattle` /
## `battle` / `loot` / `search` / `event` / `confirm` / `result` / `meta` / `erosion` / `hunter` / `prologue` / `skills`），
## 导演只在那个变量非空时 `load` 这个文件、调一次 [method fill]。所以这段代码**不在正式游戏的任何路径上**：
## 它造代码里的假难度、替玩家点选项、一路走到撤离点，这些都是截图才要干的事，不该留在导演身上。
##
## 要加一屏：在 [method fill] 里加一段 `if want == "<名字>"`，用 flow 的公开方法把流程推过去就行。
class_name DemoFill
extends RefCounted

var director: GameDirector = null
var flow: GameFlow = null


## 按 `DEMO_SCREEN` 把流程推到那一屏。只用导演的 `base()` / `overlay()`（现在显示的底屏 / 叠层）
func fill(p_director: GameDirector, p_flow: GameFlow) -> void:
	director = p_director
	flow = p_flow
	var want := OS.get_environment("DEMO_SCREEN")
	if want == "" or flow == null or flow.chapters.is_empty():
		return
	# 演示不碰玩家真正的存档
	flow.save_path = "user://demo_run.json"
	flow.meta_path = "user://demo_meta.json"
	if want == "setup":
		# 新的局外：开局屏打开时第一套发进仓库（067），带上两件给截图看
		flow.meta = MetaState.new(flow.meta_rules)
		flow.new_run()
		var setup := director.base()
		if setup != null:
			for inst in flow.meta.warehouse.items().slice(0, 2):
				setup.call("carry_in", (inst as ItemInstance).uid)
		return
	if want == "erosion":
		# 075：代码里造一份只开侵蚀的难度，走几步让最外几档被侵蚀、预警亮起来
		var ed := DifficultyDef.new()
		ed.id = &"demo_erosion"
		var em := ErosionMechanic.new()
		em.first_at_action = 1
		em.interval_actions = 2
		em.warn_lead_actions = 1
		var sv := ErodeSpendVitality.new()
		em.effects.append(sv)
		ed.mechanics.append(em)
		var erun := flow.begin(flow.chapters[0], flow.default_loadout(), 3, [] as Array[int], null, [], ed)
		if erun == null:
			return
		flow.pick_spawn(erun.map.entry_ids[0])
		for i in 4:
			var moves := erun.travel.available_moves()
			if moves.is_empty() or erun.is_over():
				break
			flow.step_to(moves[0])
			_settle()
		return
	if want == "hunter":
		# 071：一份代码里造的难度，开一个一直可见的猎手，走两步让它出现
		var hd := DifficultyDef.new()
		hd.id = &"demo_hunters"
		var hm := HunterMechanic.new()
		hm.hunter_ids = [&"hunter_2"] as Array[StringName]
		hm.spawn_min_distance = 2.0
		hd.mechanics.append(hm)
		var hrun := flow.begin(flow.chapters[0], flow.default_loadout(), 3, [] as Array[int], null, [], hd)
		if hrun == null:
			return
		flow.pick_spawn(hrun.map.entry_ids[0])
		for i in 2:
			var moves := hrun.travel.available_moves()
			if moves.is_empty() or GameFlow.is_overlay(flow.screen):
				break
			flow.step_to(moves[0])
			_settle()
		return
	if want == "prologue":
		# 083：序章 —— 只有布鲁图斯、一条路的教程图
		flow.meta = MetaState.new(flow.meta_rules)
		var pro: ChapterDef = null
		for c in flow.chapters:
			if c.id == &"prologue":
				pro = c
		var prun := flow.begin(pro, null, 1, [] as Array[int], flow.character_of(&"brutus"), []) if pro != null else null
		if prun != null:
			flow.pick_spawn(prun.map.entry_ids[0])
		return
	if want == "skills":
		# 082：按马库斯开局（有「突击」按钮），放一件信仰道具上棋盘、记几点信力，HUD 与右栏都有东西看
		flow.meta = MetaState.new(flow.meta_rules)
		var marcus := flow.character_of(&"marcus")
		var srun: RunState = null
		for seed in range(1, 60):
			srun = flow.begin(flow.chapters[0], null, seed, [] as Array[int], marcus, [])
			if srun != null:
				break
		if srun == null:
			return
		flow.pick_spawn(srun.map.entry_ids[0])
		var shield := flow.items.get_def(&"blessed_shield")
		if shield != null:
			var inst := ItemInstance.create(shield, 0)
			srun.storage.admit(inst)
			srun.equip(inst.uid)
			srun.faith_power.credit(&"event_choice", {"tags": ["offering"]})
		return
	flow.new_run()
	var next_type: StringName = &"search" if want in ["search", "event"] else &"battle"
	var found := {}
	for seed in range(1, 60):
		var state := RunState.start(flow.chapters[0], seed, flow.items, flow.enemies, flow.sets)
		if state == null:
			continue
		for entry in state.map.entry_ids:
			for nid in state.map.neighbors(entry):
				if state.map.get_node(nid).type == next_type:
					found = {"seed": seed, "entry": entry, "next": nid}
					break
			if not found.is_empty():
				break
		if not found.is_empty():
			break
	if found.is_empty():
		return
	var run := flow.begin(flow.chapters[0], flow.default_loadout(), int(found["seed"]))
	if run == null:
		return
	flow.pick_spawn(int(found["entry"]))
	if want == "map":
		return
	if want == "bag":
		director.base().call("toggle_bag")
		return
	if want == "confirm":
		_walk_to_extract(run)
		director.base().call("extract")
		return
	flow.step_to(int(found["next"]))
	if want == "prebattle":
		return     # 084：停在战前准备屏
	if want == "battle":
		if flow.screen == GameFlow.Screen.PREBATTLE:
			flow.start_battle()
		return
	if want == "event":
		return
	if want == "search":
		var overlay := director.overlay()
		if overlay != null and overlay.screen == GameFlow.Screen.EVENT:
			overlay.call("choose", 0)     # 搜索点的事件：「搜索」—— 自动搜一次（084）；不快速搜索，截图里看得见进度环
		return
	if want == "loot":
		if flow.screen == GameFlow.Screen.BATTLE:
			flow.resume()
		return
	_settle()
	run.force_extract()     # 101 第 6 刀：原来导演直接写 run.phase / end_reason（仅演示 / 测试用）
	flow.resume()
	if want == "result":
		return
	flow.finish_result()


## 演示：把叠层都看完（战利品全拿、会话离开）
func _settle() -> void:
	var guard := 0
	while GameFlow.is_overlay(flow.screen) and guard < 30:
		guard += 1
		match flow.screen:
			GameFlow.Screen.PREBATTLE:
				flow.start_battle()
			GameFlow.Screen.LOOT:
				flow.take_all_loot()
			GameFlow.Screen.SEARCH:
				flow.run.events.current_search.leave()
			GameFlow.Screen.SHOP:
				flow.run.events.current_shop.leave()
			GameFlow.Screen.EVENT:
				if flow.run.events.pending_event() != null:
					flow.choose_event(_first_open_option())
				else:
					flow.resume()
			_:
				flow.resume()


func _first_open_option() -> int:
	var def := flow.run.events.pending_event()
	# 撤离点的对话（085）：演示要看右栏的确认面板，选「再看看」而不是直接撤
	var node := flow.run.current_node()
	if node != null and NodeEvents.effective_type(node) == &"extract" and def.options.size() > 1:
		return 1
	for i in def.options.size():
		if bool(flow.run.events.option_state(i)["ok"]):
			return i
	return 0


## 演示：一路走到最近的免费撤离点
func _walk_to_extract(run: RunState) -> void:
	var from := run.travel.current_id
	var dist := MapNavigator.distance_map(run.map, from)
	var target := -1
	var best := 999
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if n.type == &"extract" and PaidExtracts.fee_of(n) == 0 and dist.has(id) and int(dist[id]) < best:
			best = int(dist[id])
			target = id
	if target < 0:
		return
	var to_target := MapNavigator.distance_map(run.map, target)
	var guard := 0
	while run.travel.current_id != target and not run.is_over() and guard < 60:
		guard += 1
		var next := -1
		for id in run.travel.available_moves():
			if to_target.has(id) and (next < 0 or int(to_target[id]) < int(to_target[next])):
				next = id
		if next < 0 or not flow.step_to(next):
			return
		_settle()

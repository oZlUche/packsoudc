## 局内界面布局方案 U0：在当前版本走一局自由模式，截各屏「正常」与「信息多」两类画面。
## 参数：<outdir> <lang zh|en> <text small|medium|large> <宽x高> [种子]
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 --script res://_probe/u0_probe.gd -- out zh medium 1600x900
## 日志行以「U0」开头。存档写在 user://u0_*，不碰玩家存档。
extends CliTool

const GAME := "res://ui/game/game.tscn"
const SETTLE := 45
const MAX_FRAMES := 40000

var out := "/tmp/u0"
var lang := "zh"
var text := "medium"
var size := Vector2i(1600, 900)
var seed_ := 780613
var d: GameDirector = null
var flow: GameFlow = null
var f := 0
var sf := 0
var last_screen := -1
var shots: Dictionary = {}
var seen_kinds: Dictionary = {}
var shot_no := 0
var map_done := false
var loot_phase := 0
var battle_mid := false
var verdict_ms := -1
var steps := 0
var want := [&"search", &"shop", &"event", &"battle", &"elite", &"rest", &"random"]


func run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: lang = a[1]
	if a.size() > 2: text = a[2]
	if a.size() > 3:
		var p := a[3].split("x")
		size = Vector2i(int(p[0]), int(p[1]))
	if a.size() > 4 and not a[4].begins_with("--"): seed_ = int(a[4])
	DirAccess.make_dir_recursive_absolute(out)
	for p in ["user://u0_run.json", "user://u0_meta.json", "user://u0_settings.json"]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var s := FileAccess.open("user://u0_settings.json", FileAccess.WRITE)
	s.store_string(JSON.stringify({"version": GameSettings.SAVE_VERSION, "language": lang, "text_size": text, "ui_fades": false,
		"window_mode": "windowed"}))
	s.close()
	GameDirector.fades_allowed = false


func L(t: String) -> void:
	print("U0 " + t)


func shot(tag: String) -> void:
	shot_no += 1
	var path := "%s/%02d_%s.png" % [out, shot_no, tag]
	root.get_texture().get_image().save_png(path)
	shots[tag] = true
	L("截图 %s" % path.get_file())


func tick(_dt: float) -> bool:
	f += 1
	if f == 2:
		d = (load(GAME) as PackedScene).instantiate()
		d.save_path = "user://u0_run.json"
		d.meta_path = "user://u0_meta.json"
		d.settings_path = "user://u0_settings.json"
		root.add_child(d)
		current_scene = d
		flow = d.flow
		return false
	if f < 6:
		return false
	if f == 6:
		DisplayServer.window_set_size(size)
		root.size = size
	if f > MAX_FRAMES:
		L("帧数到上限")
		finish(1)
		return true
	var screen := flow.screen
	if screen != last_screen:
		last_screen = screen
		sf = 0
		L("屏 %s" % GameFlow.Screen.keys()[screen])
	sf += 1
	if screen == GameFlow.Screen.BATTLE and sf == 25 and not shots.has("battle_mid"):
		shot("battle_mid")
	if sf < SETTLE or sf % 15 != 0:
		return false
	return _act(screen)


func _coach() -> bool:
	var cs := root.find_children("*", "CoachOverlay", true, false)
	if cs.is_empty():
		return false
	var c := cs[0] as CoachOverlay
	if not shots.has("coach"):
		shot("coach")
	c.next()
	return true


func _act(screen: int) -> bool:
	if _coach():
		return false
	var run_: RunState = flow.run
	match screen:
		GameFlow.Screen.MAIN_MENU:
			if run_ != null and run_.is_over():
				return _end("一局结束")
			flow.skip_prologue()
			flow.meta.set_flag(GameFlow.TUTORIAL_ASKED)
			flow.meta.set_flag(GameFlow.PROLOGUE_SKIPPED)
			var ch := flow.chapter_of(&"free_mode")
			var st := flow.begin(ch, flow.default_loadout(), seed_, [] as Array[int], flow.characters_for(ch)[0])
			L("开局 %s 种子 %d" % ["成" if st != null else "失败", seed_])
			if st == null: return _end("开不了局")
		GameFlow.Screen.META:
			if run_ != null: return _end("回到基地")
			var st := flow.begin_direct(flow.chapter_of(&"free_mode"), seed_)
			L("基地开局 %s" % ("成" if st != null else "失败"))
		GameFlow.Screen.MAP:
			return _map(run_)
		GameFlow.Screen.EVENT:
			_event(run_)
		GameFlow.Screen.SEARCH:
			if not shots.has("search"): shot("search")
			flow.close_search()
		GameFlow.Screen.LOOT:
			loot_phase += 1
			if loot_phase == 1:
				if not shots.has("loot_before"): shot("loot_before")
				flow.take_all_loot()
			elif loot_phase == 2:
				if not shots.has("loot_after"): shot("loot_after")
			else:
				loot_phase = 0
				flow.resume()
		GameFlow.Screen.PREBATTLE:
			if not shots.has("prebattle"): shot("prebattle")
			var pre = d.overlay()
			if pre != null and pre.has_method("start_battle"): pre.start_battle()
			else: flow.start_battle()
		GameFlow.Screen.BATTLE:
			var bs = d.overlay()
			if bs == null or not bs.has_method("verdict_shown"):
				flow.resume(); return false
			if not bs.verdict_shown():
				if not battle_mid:
					battle_mid = true
					if not shots.has("battle_mid"): shot("battle_mid")
				return false
			if verdict_ms < 0:
				verdict_ms = Time.get_ticks_msec()
				return false
			if Time.get_ticks_msec() - verdict_ms < 1200:
				return false
			if not shots.has("battle_verdict"): shot("battle_verdict")
			verdict_ms = -1
			battle_mid = false
			bs.proceed()
		GameFlow.Screen.SHOP:
			if not shots.has("shop"): shot("shop")
			if run_.events.current_shop != null: run_.events.current_shop.leave()
		GameFlow.Screen.ALTAR:
			if not shots.has("altar"): shot("altar")
			flow.close_altar()
		GameFlow.Screen.SAFE:
			flow.close_safe()
		GameFlow.Screen.CHEST:
			if not shots.has("chest"): shot("chest")
			flow.leave_chest()
		GameFlow.Screen.FORGE:
			if not shots.has("forge"): shot("forge")
			flow.leave_forge()
		GameFlow.Screen.RANSOM:
			flow.refuse_ransom()
		GameFlow.Screen.RESULT:
			if not shots.has("result"): shot("result")
			return _end("结算")
		_:
			return _end("不认得的屏 %s" % GameFlow.Screen.keys()[screen])
	sf = 0
	return false


func _end(why: String) -> bool:
	L("结束：%s；截了 %s" % [why, str(shots.keys())])
	finish(0)
	return true


func _ms() -> GameScreen:
	return d.base()


func _map(run_: RunState) -> bool:
	if run_ == null or run_.is_over():
		flow.resume(); sf = 0; return false
	if run_.phase == RunState.Phase.PICK_SPAWN:
		var sp := -1
		for id in run_.map.node_ids():
			if run_.map.get_node(id).type == &"spawn": sp = id; break
		flow.pick_spawn(sp); sf = 0; return false
	var ms = _ms()
	if not map_done:
		map_done = true
		shot("map")
		var tgt := _nearest(run_, [&"battle", &"elite", &"search"])
		if tgt >= 0 and ms.has_method("_on_node_hovered"):
			var v: MapView = ms._view
			var pos: Vector2 = v.positions().get(tgt, Vector2.ZERO)
			var gp := v.get_global_transform() * v.to_screen(pos)
			Input.warp_mouse(root.get_final_transform() * gp)
			ms._on_node_hovered(tgt)
		sf = SETTLE - 20
		return false
	if not shots.has("map_hover"):
		shot("map_hover")
		ms._on_node_hovered(-1)
		ms.toggle_bag()
		sf = SETTLE - 20
		return false
	if not shots.has("bag"):
		shot("bag")
		var win = ms._bag.get_child(0) if ms._bag != null else null
		if win != null and win.has_method("set_view"):
			for it in run_.board.items():
				if ItemErosion.eligible(it):
					ItemErosion.add(it); ItemErosion.add(it); break     # 截风险查看用：一件 2/3
			win.set_view(&"links")
		sf = SETTLE - 20
		return false
	if not shots.has("bag_links") and ms._bag != null and ms._bag.get_child(0).has_method("set_view"):
		shot("bag_links")
		ms._bag.get_child(0).set_view(&"risk")
		sf = SETTLE - 20
		return false
	if not shots.has("bag_risk") and ms._bag != null and ms._bag.get_child(0).has_method("set_view"):
		shot("bag_risk")
		ms._bag.get_child(0).set_view(&"")
	if ms._bag != null:
		ms.toggle_bag()
		sf = 0
		return false
	steps += 1
	if steps > 40 or _all_done():
		return _end("截够了 / 步数到了")
	var cur := run_.current_node()
	var kinds: Array = want.filter(func(k): return not seen_kinds.has(k))
	var t := _nearest(run_, kinds)
	if t < 0:
		if cur != null and cur.type == &"extract" and flow.extract():
			sf = 0; return false
		t = _nearest(run_, [&"extract"])
	if t < 0:
		return _end("无路可走")
	var path := _path(run_, t)
	if path.is_empty():
		return _end("找不到路")
	var nxt: int = path[0]
	for inst in run_.storage.items().duplicate():
		run_.equip((inst as ItemInstance).uid)
	var nn := run_.map.get_node(nxt)
	if nxt == t: seen_kinds[nn.type] = true
	L("走 %d（%s）→ 目标 %d" % [nxt, nn.type, t])
	if not flow.step_to(nxt):
		return _end("走不到 %d" % nxt)
	sf = 0
	return false


func _all_done() -> bool:
	for k in ["prebattle", "battle_verdict", "loot_before", "shop", "event"]:
		if not shots.has(k): return false
	return true


func _nearest(run_: RunState, kinds: Array) -> int:
	var cur := run_.current_node()
	if cur == null: return -1
	var dist := {cur.id: 0}
	var q: Array[int] = [cur.id]
	while not q.is_empty():
		var id: int = q.pop_front()
		var n := run_.map.get_node(id)
		if id != cur.id and kinds.has(n.type) and not n.is_visited():
			return id
		for nb in run_.map.neighbors(id):
			if not dist.has(nb):
				dist[nb] = int(dist[id]) + 1
				q.append(nb)
	return -1


func _path(run_: RunState, target: int) -> Array[int]:
	var cur := run_.current_node()
	var prev := {cur.id: -1}
	var q: Array[int] = [cur.id]
	while not q.is_empty():
		var id: int = q.pop_front()
		if id == target: break
		for nb in run_.map.neighbors(id):
			if not prev.has(nb):
				prev[nb] = id
				q.append(nb)
	var out_: Array[int] = []
	if not prev.has(target): return out_
	var x := target
	while x != cur.id:
		out_.push_front(x)
		x = prev[x]
	return out_


func _event(run_: RunState) -> void:
	if bool(flow.last_payload.get("briefing", false)):
		flow.close_briefing(); return
	var ev: EventDef = run_.events.pending_event() if run_ != null else null
	if ev == null:
		flow.resume(); return
	var tag := "event_%s" % String(ev.id)
	if not shots.has(tag):
		shot(tag)
		shots["event"] = true
	var ctx = run_.events._event_ctx(run_.events.pending_node())
	var pick := -1
	for i in ev.options.size():
		var o := ev.options[i] as EventOption
		if o.locked_reason(ctx) != "": continue
		var l := String(o.label)
		if pick < 0: pick = i
		if l.contains("迎战") or l.contains("搜") or l.contains("Search") or l.contains("Fight"):
			pick = i; break
	flow.choose_event(maxi(0, pick))

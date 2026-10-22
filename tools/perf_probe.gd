## 性能探针（237）：在真窗口 / Xvfb 下跑正式游戏（`ui/game/game.tscn`，和玩家看到的一样：淡入、过场、回放都开着），
## 自动按序章原路走：搜索点搜两次 → 整理 → 战斗 → 第二个搜索点搜三次遇敌 → 迎战 → 看完回放 → 精英 → 撤离，
## 可以连跑几局。每帧采样 [Performance] 监视器（对象 / 节点 / 孤儿节点 / 资源 / 静态内存 / 纹理显存 / 帧时间 / 绘制调用），
## 按「屏」分段汇总，并给每一次同步调用（选事件选项、开战）计时 —— 主线程被挡多久就是玩家感受到的「无响应」。
##
##     xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 \
##         --script res://tools/perf_probe.gd -- <输出.csv> [局数=1]
##
## 不能 --headless：空渲染驱动不画东西，纹理显存与绘制调用都是 0。
## 输出：每帧一行 CSV（给画图 / 事后分析），结束时在标准输出打一张按屏汇总的表。
extends CliTool

const GAME := "res://ui/game/game.tscn"
const PREFIX := "perf_probe"
## 屏稳定多少帧再动手（给淡入 / 过场留时间，也像人看一眼再点）
const SETTLE_FRAMES := 30
## 一屏超过这么久没换屏就算卡住（秒，真实时间）
const STALL_SEC := 180.0
const MAX_FRAMES := 60000
## 回放看完（继续旗出来了）再等几帧，让结算动效走完
const AFTER_VERDICT_FRAMES := 60

var _game: Node = null
var _flow: GameFlow = null
var _out_path := "user://perf_probe.csv"
var _csv: FileAccess = null
var _runs_wanted := 1
var _runs_done := 0
var _frames := 0
var _screen_frames := 0
var _screen_started_msec := 0
var _last_screen := -1
var _phase := ""
var _phase_no := 0
var _phases: Array[Dictionary] = []
var _cur: Dictionary = {}
## 同步调用的耗时记录：[标签, 毫秒]
var _stalls: Array = []
var _after_fight := false
var _verdict_frames := 0
var _loot_frames := 0
var _booted := false
## 这一帧回放屏套用了哪些战斗事件（名字），写进 csv 的 events 列
var _frame_events: Array[String] = []
var _hooked_views: Dictionary = {}
var _last_delta_ms := 0.0
## -- bench：第一场回放不照常播，逐条计时 _apply，再按帧量各种刷新的成本
var _bench := false
var _bench_done := false
var _bench_step := -1
var _bench_frame := 0
var _bench_deltas: Array = []
const BENCH_FRAMES := 40
const BENCH_STEPS := ["空转", "棋盘 queue_redraw ×2", "面板 queue_redraw ×2", "popup 弹字", "shake 抖动", "set_resource 血量", "set_now 计时环"]


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = args[0]
	if args.size() > 1:
		_runs_wanted = maxi(1, int(args[1]))
	_bench = args.has("bench")
	_csv = FileAccess.open(_out_path, FileAccess.WRITE)
	if _csv == null:
		push_error("写不了 " + _out_path)
		finish(1)
		return
	_csv.store_line("frame,msec,phase,screen,delta_ms,process_ms,objects,nodes,orphans,resources,static_mb,texture_mb,draw_calls,board_conns,storage_conns,n_events,events")
	_cleanup()
	# 不在 _initialize 里加场景：导演的 _ready 要在帧循环里跑
	print("perf_probe：%d 局，输出 %s" % [_runs_wanted, _out_path])


func _cleanup() -> void:
	RunSave.remove("user://%s_run.json" % PREFIX)
	MetaSave.remove("user://%s_meta.json" % PREFIX)
	GameSettings.remove("user://%s_settings.json" % PREFIX)


func tick(delta: float) -> bool:
	_frames += 1
	if not _booted:
		_boot()
		return false
	_sample(delta)
	if _frames > MAX_FRAMES:
		_report("帧数到了上限 %d" % MAX_FRAMES)
		finish(1)
		return true
	var screen := _flow.screen
	if screen == GameFlow.Screen.BATTLE:
		_hook_view()
	if screen != _last_screen:
		_last_screen = screen
		_screen_frames = 0
		_screen_started_msec = Time.get_ticks_msec()
		_begin_phase(GameFlow.Screen.keys()[screen])
	else:
		_screen_frames += 1
	if Time.get_ticks_msec() - _screen_started_msec > STALL_SEC * 1000.0:
		_report("卡住：%s 屏 %.0f 秒没换屏；%s" % [GameFlow.Screen.keys()[screen], STALL_SEC, _battle_state()])
		finish(1)
		return true
	if _screen_frames < SETTLE_FRAMES:
		return false
	return _act(screen)


func _boot() -> void:
	_booted = true
	var packed: PackedScene = load(GAME)
	_game = packed.instantiate()
	_game.save_path = "user://%s_run.json" % PREFIX
	_game.meta_path = "user://%s_meta.json" % PREFIX
	_game.settings_path = "user://%s_settings.json" % PREFIX
	var t0 := Time.get_ticks_usec()
	root.add_child(_game)
	current_scene = _game
	_stall("导演 _ready（装内容）", t0)
	_flow = _game.flow
	_begin_phase("BOOT")


#region 自动走
## 返回 true = 收工
func _act(screen: int) -> bool:
	var run: RunState = _flow.run
	# 教程气泡（地图屏 / 背包窗 / 战斗屏的 CoachOverlay）挡着就先按「下一步」—— 它 hold 着回放
	var coaches := root.find_children("*", "CoachOverlay", true, false)
	if not coaches.is_empty():
		_timed("教程气泡「下一步」", func() -> void: (coaches[0] as CoachOverlay).next())
		_screen_frames = SETTLE_FRAMES - 6     # 气泡一步一步点，别等太久
		return false
	match screen:
		GameFlow.Screen.MAIN_MENU:
			if _runs_done >= _runs_wanted:
				_report("跑完 %d 局" % _runs_done)
				finish(0)
				return true
			_after_fight = false
			var t0 := Time.get_ticks_usec()
			_flow.start_new_game()
			_stall("新的游戏（开局）", t0)
		GameFlow.Screen.EVENT:
			_act_event()
		GameFlow.Screen.SEARCH:
			_timed("关闭搜索屏", func() -> void: _flow.close_search())
		GameFlow.Screen.LOOT:
			_loot_frames += 1
			if _loot_frames == 1:
				_timed("全部拾取", func() -> void: _flow.take_all_loot())
			elif _loot_frames > SETTLE_FRAMES:
				_loot_frames = 0
				_timed("战利品看完（resume）", func() -> void: _flow.resume())
		GameFlow.Screen.PREBATTLE:
			var pre = _game.overlay()
			if pre != null and pre.has_method("start_battle"):
				_timed("开战（模拟 + 写回放 + 建回放屏）", func() -> void: pre.start_battle())
			else:
				_timed("开战（flow.start_battle）", func() -> void: _flow.start_battle())
		GameFlow.Screen.BATTLE:
			_act_battle()
		GameFlow.Screen.MAP:
			_act_map(run)
		GameFlow.Screen.RESULT:
			_runs_done += 1
			_timed("结算看完", func() -> void: _flow.finish_result())
		GameFlow.Screen.META:
			_timed("回主菜单", func() -> void: _flow.to_main_menu())
		GameFlow.Screen.REST:
			_timed("休息屏 resume", func() -> void: _flow.resume())
		GameFlow.Screen.SHOP:
			if run != null and run.events.current_shop != null:
				run.events.current_shop.leave()
		GameFlow.Screen.SAFE:
			_flow.close_safe()
		GameFlow.Screen.CHEST:
			_flow.leave_chest()
		GameFlow.Screen.FORGE:
			_flow.leave_forge()
		GameFlow.Screen.ALTAR:
			_flow.close_altar()
		_:
			_report("不会处理的屏：%s" % GameFlow.Screen.keys()[screen])
			finish(1)
			return true
	_screen_frames = 0     # 动过手之后再等一轮，别每帧重复按
	return false


func _act_event() -> void:
	if bool(_flow.last_payload.get("briefing", false)):
		_timed("交代「知道了」", func() -> void: _flow.close_briefing())
		return
	var run: RunState = _flow.run
	var ev: EventDef = run.events.pending_event() if run != null else null
	if ev == null:
		_timed("事件屏没有等着的事件：resume", func() -> void: _flow.resume())
		return
	var pick := 0
	var label := ""
	for i in ev.options.size():
		var l := String((ev.options[i] as EventOption).label)
		if l.contains("迎战"):
			pick = i
			break
		if _after_fight and l == "离开":
			pick = i
	label = String((ev.options[pick] as EventOption).label)
	var tag := "事件「%s」选「%s」" % [ev.id, label]
	if label.contains("迎战"):
		tag += "  ← 第三次搜索遇敌"
		_after_fight = true
	elif label == "离开":
		_after_fight = false
	_timed(tag, func() -> void: _flow.choose_event(pick))


## 回放屏现在什么状态（卡住时打出来看）
func _battle_state() -> String:
	var screen = _game.overlay()
	if screen == null or not screen.has_method("view"):
		return "叠层不是回放屏"
	var v: BattleView = screen.view()
	return "回放 t=%.1f 播放中=%s 按住=%s 过场中=%s 教程=%s 看完=%s" % [v.now(), v.is_playing(), v.is_held(), screen.intro_running(),
		screen.coach() != null, screen.verdict_shown()]


## 回放屏的事件信号接到 csv 的 events 列（每个 BattleView 只接一次）
func _hook_view() -> void:
	var screen = _game.overlay()
	if screen == null or not screen.has_method("view"):
		return
	var v: BattleView = screen.view()
	if v == null or _hooked_views.has(v.get_instance_id()):
		return
	_hooked_views[v.get_instance_id()] = true
	v.event_applied.connect(func(e: BattleEvent) -> void: _frame_events.append(String(e.name)))


## bench：把这一场剩下的事件一条条 _apply，按事件名计时（弹字、抖动、音效、面板刷新都在里面）
func _bench_apply(v: BattleView) -> void:
	var log: Array = v._result.log
	var stats := {}
	v._playing = false
	var t_all := Time.get_ticks_usec()
	var n := 0
	while v._cursor < log.size():
		var e: BattleEvent = log[v._cursor]
		var t0 := Time.get_ticks_usec()
		v._apply(e)
		var us := Time.get_ticks_usec() - t0
		var key := String(e.name)
		if not stats.has(key):
			stats[key] = [0, 0, 0]
		stats[key][0] += 1
		stats[key][1] += us
		stats[key][2] = maxi(int(stats[key][2]), us)
		v._cursor += 1
		n += 1
		if v.is_held():
			v.release()
	var all_ms := (Time.get_ticks_usec() - t_all) / 1000.0
	print("\nbench：逐条 _apply %d 条事件，共 %.1f ms（平均 %.3f ms/条）" % [n, all_ms, all_ms / maxf(1.0, n)])
	print("  %-22s %6s %9s %9s %9s" % ["事件", "条数", "合计ms", "均ms", "峰ms"])
	var keys := stats.keys()
	keys.sort_custom(func(a, b): return stats[a][1] > stats[b][1])
	for k in keys:
		var st: Array = stats[k]
		print("  %-22s %6d %9.1f %9.3f %9.3f" % [k, st[0], st[1] / 1000.0, st[1] / 1000.0 / st[0], st[2] / 1000.0])
	# 单项微基准（敌方面板）
	var p: CombatantPanel = v.panel(1)
	var micro := {
		"panel.popup ×20": func() -> void:
			for i in 20:
				p.popup(7 + i, &"physical", false, i % 5 == 0),
		"panel.shake ×20": func() -> void:
			for i in 20:
				p.shake(1.0),
		"panel.set_resource ×20": func() -> void:
			for i in 20:
				p.set_resource("hp", 50 + i, 100),
		"panel.set_now ×20": func() -> void:
			for i in 20:
				p.set_now(float(i) * 0.1),
		"view._sync_overlays ×20": func() -> void:
			for i in 20:
				v._sync_overlays(),
		"AudioHub.play 命中 ×20": func() -> void:
			for i in 20:
				AudioHub.play(&"battle.hit.physical"),
		"overlay.flash ×20": func() -> void:
			var o: CooldownOverlay = v.overlay(1)
			for i in 20:
				o.flash(1, float(i)),
	}
	print("  单项（×20 合计）：")
	for k in micro:
		var t0 := Time.get_ticks_usec()
		(micro[k] as Callable).call()
		print("    %-26s %8.2f ms" % [k, (Time.get_ticks_usec() - t0) / 1000.0])


## bench：按帧量——每一步连做 BENCH_FRAMES 帧某一种刷新，记下一帧的帧时；最后把中位数打出来
func _bench_frames(v: BattleView) -> void:
	if _bench_frame > 0:
		_bench_deltas.append(_last_delta_ms)
	_bench_frame += 1
	if _bench_frame > BENCH_FRAMES:
		_bench_deltas.sort()
		var med: float = _bench_deltas[_bench_deltas.size() / 2]
		var p90: float = _bench_deltas[int(_bench_deltas.size() * 0.9)]
		if _bench_step == 0:
			print("  按帧（%d 帧，帧时中位 / p90，含绘制）：" % BENCH_FRAMES)
		print("    %-26s %6.1f / %6.1f ms" % [BENCH_STEPS[_bench_step], med, p90])
		_bench_step += 1
		_bench_frame = 0
		_bench_deltas = []
		if _bench_step >= BENCH_STEPS.size():
			_bench_done = true
			_bench_step = -1
			v._now = v._result.duration_sec()
			v._playing = true     # 下一帧 _process 收尾（_finish）
		return
	var p: CombatantPanel = v.panel(1)
	match _bench_step:
		1:
			v.board_view(0).queue_redraw()
			v.board_view(1).queue_redraw()
		2:
			v.panel(0).queue_redraw()
			p.queue_redraw()
		3:
			p.popup(7 + _bench_frame, &"physical", false, false)
		4:
			p.shake(1.0)
		5:
			p.set_resource("hp", 30 + _bench_frame, 100)
		6:
			p.set_now(float(_bench_frame) * 0.1)


func _act_battle() -> void:
	var screen = _game.overlay()
	if screen == null or not screen.has_method("verdict_shown"):
		_timed("回放屏不是 BattleScreen：resume", func() -> void: _flow.resume())
		return
	if _bench and not _bench_done and not screen.intro_running() and screen.coach() == null:
		var v: BattleView = screen.view()
		if _bench_step < 0 and v.is_playing():
			_bench_apply(v)
			_bench_step = 0
			_bench_frame = 0
			_bench_deltas = []
			return
		if _bench_step >= 0:
			_bench_frames(v)
			return
	if not screen.verdict_shown():
		return
	_verdict_frames += 1
	if _verdict_frames < AFTER_VERDICT_FRAMES:
		return
	_verdict_frames = 0
	_timed("回放看完「继续」", func() -> void: screen.proceed())


func _act_map(run: RunState) -> void:
	if run == null or run.is_over():
		_timed("一局结束：resume", func() -> void: _flow.resume())
		return
	var cur := run.current_node()
	if cur != null and cur.type == &"extract":
		_timed("撤离", func() -> void: _flow.extract())
		return
	var target := _next_node(run)
	if target < 0:
		_report("图上没有下一个点可走（当前 %s）" % (cur.type if cur != null else "?"))
		finish(1)
		return
	var tn := run.map.get_node(target)
	if tn.type == &"battle" or tn.type == &"elite" or tn.type == &"core":
		_equip_all(run)     # 教程的门：开战前东西要在包里
	var t0 := Time.get_ticks_usec()
	if not _flow.step_to(target):
		_report("走不到 %d（%s）" % [target, tn.type])
		finish(1)
		return
	_stall("走到 %d（%s）" % [target, tn.type], t0)


## 下一步：可走的点里按层（tier）最小、没去过的；都去过了就任意一个没去过的最近点
func _next_node(run: RunState) -> int:
	var best := -1
	var best_tier := 1 << 30
	for n in run.travel.available_moves():
		var node := run.map.get_node(n)
		if node == null or node.is_visited():
			continue
		if node.tier < best_tier:
			best_tier = node.tier
			best = n
	if best >= 0:
		return best
	for n in run.travel.available_moves():
		var node := run.map.get_node(n)
		if node != null and node.type == &"extract":
			return n
	var moves := run.travel.available_moves()
	return moves[0] if not moves.is_empty() else -1


func _equip_all(run: RunState) -> void:
	for inst in run.storage.items().duplicate():
		run.equip((inst as ItemInstance).uid)
#endregion


#region 采样
func _timed(tag: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	f.call()
	_stall(tag, t0)


func _stall(tag: String, t0: int) -> void:
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_stalls.append([tag, ms, _phase])
	if ms >= 100.0:
		print("  [同步 %.0f ms] %s" % [ms, tag])


func _begin_phase(name: String) -> void:
	_end_phase()
	_phase_no += 1
	_phase = "%02d %s" % [_phase_no, name]
	_cur = {"phase": _phase, "frames": 0, "delta_sum": 0.0, "delta_max": 0.0, "proc_sum": 0.0, "proc_max": 0.0,
		"objects": 0, "nodes": 0, "orphans": 0, "resources": 0, "static_mb": 0.0, "texture_mb": 0.0, "draw_max": 0,
		"board": 0, "storage": 0, "objects_start": int(Performance.get_monitor(Performance.OBJECT_COUNT))}


func _end_phase() -> void:
	if not _cur.is_empty():
		_phases.append(_cur)
	_cur = {}


func _sample(delta: float) -> void:
	var proc := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var static_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	var tex_mb := float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var board_c := 0
	var storage_c := 0
	if _flow != null and _flow.run != null:
		board_c = _flow.run.board.changed.get_connections().size()
		storage_c = _flow.run.storage.changed.get_connections().size()
	var dms := delta * 1000.0
	_last_delta_ms = dms
	_csv.store_line("%d,%d,%s,%s,%.2f,%.2f,%d,%d,%d,%d,%.1f,%.1f,%d,%d,%d,%d,%s" % [
		_frames, Time.get_ticks_msec(), _phase, GameFlow.Screen.keys()[_flow.screen] if _flow != null else "-",
		dms, proc, objects, nodes, orphans, resources, static_mb, tex_mb, draws, board_c, storage_c,
		_frame_events.size(), "|".join(_frame_events)])
	_frame_events.clear()
	if _cur.is_empty():
		return
	_cur["frames"] = int(_cur["frames"]) + 1
	_cur["delta_sum"] = float(_cur["delta_sum"]) + dms
	_cur["delta_max"] = maxf(float(_cur["delta_max"]), dms)
	_cur["proc_sum"] = float(_cur["proc_sum"]) + proc
	_cur["proc_max"] = maxf(float(_cur["proc_max"]), proc)
	_cur["objects"] = objects
	_cur["nodes"] = nodes
	_cur["orphans"] = orphans
	_cur["resources"] = resources
	_cur["static_mb"] = static_mb
	_cur["texture_mb"] = tex_mb
	_cur["draw_max"] = maxi(int(_cur["draw_max"]), draws)
	_cur["board"] = board_c
	_cur["storage"] = storage_c


func _report(why: String) -> void:
	_end_phase()
	print("")
	print("perf_probe 结束：%s（%d 帧，%.1f 秒）" % [why, _frames, Time.get_ticks_msec() / 1000.0])
	print("")
	print("%-28s %6s %8s %8s %8s %8s %8s %7s %7s %7s %8s %7s %6s %5s %5s" % [
		"屏", "帧", "帧ms均", "帧ms峰", "proc均", "proc峰", "对象", "Δ对象", "节点", "孤儿", "静态MB", "纹理MB", "绘制", "盘连", "地连"])
	for p in _phases:
		var n := maxi(1, int(p["frames"]))
		print("%-28s %6d %8.1f %8.1f %8.1f %8.1f %8d %+7d %7d %7d %8.1f %7.1f %6d %5d %5d" % [
			p["phase"], p["frames"], float(p["delta_sum"]) / n, p["delta_max"], float(p["proc_sum"]) / n, p["proc_max"],
			p["objects"], int(p["objects"]) - int(p["objects_start"]), p["nodes"], p["orphans"], p["static_mb"], p["texture_mb"],
			p["draw_max"], p["board"], p["storage"]])
	print("")
	print("同步调用（主线程被挡）：")
	_stalls.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	for i in mini(25, _stalls.size()):
		var s: Array = _stalls[i]
		print("  %8.1f ms  %-20s %s" % [s[1], s[2], s[0]])
	if _csv != null:
		_csv.close()
	_cleanup()
#endregion

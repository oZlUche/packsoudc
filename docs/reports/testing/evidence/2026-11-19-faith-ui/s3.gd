## 游戏测试 v6.06 切片 S3 走查：参数 <out.csv> 1 <sA|sB|sC> -- --profile=slice。sA = 合成后打守卫从 12 撤；sB = 不打守卫从 9 撤；sC = 卸装备连输到体力用光。
## 每局记：两段引导、商店首访提示（等 6 秒再点一下鼠标）、打输回地图的那句、结算后基地页签、能再出征。由 exp593 改。
## 原注：游戏测试 v5.93（报告 309 §9.2 真实复测）：参数 <out.csv> 1 <prologue|free|fail|reenter>。prologue = 种子 71888 序章；free = 种子 780613 魔法废墟小型普通，安德烈乌斯强攻，先去商店买一件再撤离、入库；fail = 同图卸掉装备打到输，看体力 / 物品，关窗；reenter = 不清存档重开看局外。每 5 帧存一张小图做录像，换屏 / 讲解每步截图。
## 原注：游戏测试 v5.89（报告 309）：perf_probe 的拷贝，固定种子 71888 走序章；每个事件记选项与灰的原因、身上的匕首 / 毒药；守卫门口先像玩家那样把毒药拖到匕首上合成，再看退路藏没藏
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
const PREFIX := "s3"
## 屏稳定多少帧再动手（给淡入 / 过场留时间，也像人看一眼再点）
const SETTLE_FRAMES := 30
## 一屏超过这么久没换屏就算卡住（秒，真实时间）
const STALL_SEC := 180.0
const MAX_FRAMES := 60000
## 回放看完（继续旗出来了）再等一秒（真实时间），让结算动效走完
const AFTER_VERDICT_SEC := 1.0

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
var _verdict_msec := -1
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
	MODE = args[2] if args.size() > 2 else "prologue"
	OUT = _out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(OUT + "/frames")
	if not MODE in ["reenter", "slice", "loadold", "sA", "sB", "sC", "sH", "sF", "sL", "sM", "sE"]:
		_cleanup()
		if FileAccess.file_exists("user://settings.json"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path("user://settings.json"), ProjectSettings.globalize_path("user://%s_settings.json" % PREFIX))
	# 不在 _initialize 里加场景：导演的 _ready 要在帧循环里跑
	print("perf_probe：%d 局，输出 %s" % [_runs_wanted, _out_path])


func _cleanup() -> void:
	RunSave.remove("user://%s_run.json" % PREFIX)
	MetaSave.remove("user://%s_meta.json" % PREFIX)
	GameSettings.remove("user://%s_settings.json" % PREFIX)


var _pending_shot := ""
var MODE := "prologue"
var OUT := ""
var _shot_no := 0
var _bought := false
var _shop_logged := false
var _losses := 0
var _closing := 0


func shot(tag: String) -> void:
	_shot_no += 1
	var path := "%s/%03d_%s.png" % [OUT, _shot_no, tag.replace("/", "_").replace(" ", "_").left(40)]
	root.get_texture().get_image().save_png(path)
	print("E593 截图 ", path.get_file())


func tick(delta: float) -> bool:
	_frames += 1
	if _booted and _frames % 5 == 0:
		var im := root.get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		im.save_jpg("%s/frames/%06d.jpg" % [OUT, _frames / 5], 0.7)
	if _closing > 0:
		_closing += 1
		if _closing == 15 and MODE == "reenter":
			_log_meta("重开后")
		if _closing > 20:
			print("E593 关窗后退出")
			finish(0)
			return true
		return false
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
	if screen != _last_screen and _screen_frames >= 0:
		_pending_shot = GameFlow.Screen.keys()[screen]
	if _pending_shot != "" and _screen_frames == SETTLE_FRAMES - 1:
		shot(_pending_shot); _pending_shot = ""
	if screen == GameFlow.Screen.MAP and (_hb_state == 1 or _loss_pending):
		if _heart_tick():
			return false
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
	if MODE == "sM":
		_fh_poll(GameFlow.Screen.keys()[screen])
	if MODE == "sM" and screen == GameFlow.Screen.MAP and not _coach_done:
		if _coach_tick(): return false
	if _m_on and screen == GameFlow.Screen.MAP:
		_m_tick()
		return false
	if _lg_on and screen == GameFlow.Screen.MAP:
		_long_tick()
		return false
	if screen == GameFlow.Screen.FORGE and _screen_frames >= SETTLE_FRAMES:
		_forge_tick()
		return false
	if _screen_frames < SETTLE_FRAMES:
		return false
	if _bench_step >= 0:     # bench 按帧量：每帧都要走一步，不能等 [method _act] 的节拍（教程提示在时它隔几帧才轮到回放屏）
		if screen == GameFlow.Screen.BATTLE and _game.overlay() != null and _game.overlay().has_method("view"):
			_bench_frames(_game.overlay().view())
			return false
		_bench_step = -1     # 回放屏没了：不量了
		_bench_done = true
	return _act(screen)


func _boot() -> void:
	_booted = true
	var packed: PackedScene = load(GAME)
	_game = packed.instantiate()
	if not _sl() and not MODE.begins_with("tut"):     # slice：用游戏默认存档路径，看切片档案自己分到 user://slice/
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
	var run_: RunState = _flow.run
	# 教程提示（地图屏 / 背包窗 / 战斗屏的 CoachOverlay）挡着就先按「下一步」—— 它 hold 着回放
	var coaches := root.find_children("*", "CoachOverlay", true, false)
	if not coaches.is_empty():
		var c0 := coaches[0] as CoachOverlay
		var tgt := String(c0.steps[c0.index].get("target", "")) if c0.index >= 0 and c0.index < c0.steps.size() else "?"
		print("E593 讲解 [%s] 指向 %s：%s" % [GameFlow.Screen.keys()[screen], tgt, c0.line_text()])
		shot("coach_" + tgt)
		if screen == GameFlow.Screen.META and c0.waiting():
			var sb := _btn_text(UiText.t("wh.store_all"))
			print("F643 基地导览动作步：真点【%s】%s" % [UiText.t("wh.store_all"), "找到" if sb != null else "没找到"])
			if sb != null: _click643(sb)
			else: c0.next()
		else:
			_timed("教程提示「下一步」", func() -> void: (coaches[0] as CoachOverlay).next())
		_screen_frames = SETTLE_FRAMES - 6     # 提示一步一步点，别等太久
		return false
	var base = _game.base()
	if base != null and base.has_method("tutorial_ask_open") and base.tutorial_ask_open():
		if MODE in ["prologue", "blessed", "oldsave"] or MODE.begins_with("tut"):
			_timed("240 开场一问选「需要」", func() -> void: base.accept_tutorial())     # 照旧走序章
		else:
			_timed("240 开场一问选「不要」", func() -> void: base.decline_tutorial())
		return false
	if MODE == "tutP" and _pm == 21 and screen != GameFlow.Screen.MAP:
		print("F644 点【接着学】后屏变成 %s；当前节点 %s；按键位置 %s" % [GameFlow.Screen.keys()[screen], str(run_.current_node().id) if run_ != null and run_.current_node() != null else "?", str(_no_pos)])
		_pm = 0
	match screen:
		GameFlow.Screen.MAIN_MENU:
			if _runs_done >= _runs_wanted:
				_report("跑完 %d 局" % _runs_done)
				finish(0)
				return true
			_after_fight = false
			if MODE == "reenter":
				_reenter(); return false
			if MODE == "loadold":
				print("E593 读旧档：局内存档 %s；继续 %s；屏 %s" % [str(_flow.has_save()), str(_flow.continue_game()), GameFlow.Screen.keys()[_flow.screen]])
				_runs_wanted = 1
				MODE = "blessed"
				_screen_frames = 0
				return false
			if MODE == "tutL":
				if _lmenu: return false
				_lmenu = true
				var cb := _btn_text(UiText.t("menu.continue"))
				print("F644 老档主菜单：「%s」%s" % [UiText.t("menu.continue"), "找到，真点" if cb != null else "没找到，直接 continue_game"])
				if cb != null: _click643(cb)
				else: _flow.continue_game()
				return false
			var t0 := Time.get_ticks_usec()
			if MODE in ["free", "fail"]:
				_flow.next_run_seed = 780613
			_flow.start_new_game()
			if (MODE in ["prologue", "blessed", "oldsave"] or MODE.begins_with("tut")) and _flow.run != null and _flow.run.run_seed != 71888:
				print("P309 开局种子 %d 所在章 %s → 用 begin_direct 换成 71888" % [_flow.run.run_seed, _flow.run.chapter.id])
				_flow.begin_direct(_flow.run.chapter, 71888)
			_stall("新的游戏（开局）", t0)
		GameFlow.Screen.EVENT:
			_act_event()
		GameFlow.Screen.SEARCH:
			_searches += 1
			if _flow.run != null and _flow.run.events.current_search != null:
				var cn2 := _flow.run.current_node()
				print("E619 搜索：节点 %s：收获箱 %s" % [str(cn2.id) if cn2 != null else "?", str(_ids(_flow.run.events.current_search.haul_box))])
			if MODE.begins_with("tut"):
				var cs2 = _game.overlay() if _game.overlay() != null and _game.overlay().has_method("take_all") else _game.base()
				if cs2 != null and cs2.has_method("skip_reveal"):
					cs2.skip_reveal()
					cs2.take_all()     # 教程三：骰子、护符碎片要拿到手才能献祭
			_timed("关闭搜索屏", func() -> void: _flow.close_search())
		GameFlow.Screen.LOOT:
			_loot_frames += 1
			if _loot_frames == 1 and _flow.run != null and _flow.run.pending_loot != null:
				var cn := _flow.run.current_node()
				print("E619 战利品：节点 %s（%s）：%s" % [str(cn.id) if cn != null else "?", String(cn.type) if cn != null else "?", str(_ids(_flow.run.pending_loot))])
				if cn != null and cn.type == &"elite": print("E632 精英战利品屏告示：%s" % str(NoticeLayer.current().lines() if NoticeLayer.current() != null else []))
				if cn != null and cn.type == &"elite": shot("elite_loot_%d" % cn.id)
			if _loot_frames == 1 and MODE == "sM":
				var cs = _game.overlay() if _game.overlay() != null and _game.overlay().has_method("take_all") else _game.base()
				if cs != null and cs.has_method("take_all"):
					_timed("全部拾取（按钮）", func() -> void: cs.take_all())
				else:
					_timed("全部拾取", func() -> void: _flow.take_all_loot())
			elif _loot_frames == 1:
				_timed("全部拾取", func() -> void: _flow.take_all_loot())
			elif _loot_frames > SETTLE_FRAMES:
				_loot_frames = 0
				if MODE == "sM": _flow.take_all_loot()
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
			if MODE == "tutP" and _pause643(run_): return false
			_act_map(run_)
		GameFlow.Screen.SETUP:
			if MODE.begins_with("tut"):
				print("F643 开局屏：能列 %s；切片地图拒绝「%s」" % [str(_flow.available_chapters().map(func(c): return String(c.id))), _flow.start_refusal(_flow.chapter_of(&"slice_ruins"), [], null) if _flow.chapter_of(&"slice_ruins") != null else "无此章"])
				shot("tut_setup")
				_report("F643 走完（开局屏）")
				finish(0)
				return true
			if _again:
				print("E593 再次出征：开局屏开着，章节 %s" % str(_game.base()._chapters.map(func(c): return String(c.id))))
				shot("again_setup")
				_report("S3 走完")
				finish(0)
				return true
			_act_setup()
		GameFlow.Screen.RANSOM:
			var rs = _game.overlay() if _game.overlay() != null else _game.base()
			print("E593 求饶屏：体力 %d/%d，钱 %d" % [run_.vitality.current, run_.vitality.maximum, run_.wallet.balance])
			if MODE == "fail" or _sl() or _tut_lose():
				_loss_pending = true
				_flow.refuse_ransom()
				print("E593 不求饶后体力 %d/%d" % [run_.vitality.current, run_.vitality.maximum])
			elif run_.wallet.balance > 0 and _flow.pay_ransom(run_.wallet.balance) == "":
				print("E593 付钱求饶")
			else:
				_flow.refuse_ransom()
		GameFlow.Screen.RESULT:
			_res_phase += 1
			if _res_phase <= 2:
				_log_result(); _screen_frames = 0; return false
			_runs_done += 1
			_timed("结算看完", func() -> void: _flow.finish_result())
		GameFlow.Screen.META:
			if MODE.begins_with("tut"):
				_tut_meta()
				return false
			if MODE == "fail":
				_log_meta("局外（关窗前）")
				print("E593 关窗")
				root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
				finish(0)
				return true
			_log_meta("局外")
			if _sl():
				print("E593 切片基地：档案 %s；页签键 %s" % [str(_flow.profile), str((load("res://ui/game/meta_screen.gd").get_script_constant_map()["TABS"] as Array).filter(func(p): return SliceProfile.keeps_tab(_flow.profile, p[0])).map(func(p): return p[0]))])
			if _sl() and not _again:
				_again = true
				_flow.new_run()
				print("E593 基地点「出征」：屏 %s" % GameFlow.Screen.keys()[_flow.screen])
				return false
			_runs_done = _runs_wanted
			_timed("回主菜单", func() -> void: _flow.to_main_menu())
		GameFlow.Screen.SHOP:
			if (MODE == "free" or _sl()) and not _bought:
				_act_shop(); return false
			if run_ != null and run_.events.current_shop != null:
				run_.events.current_shop.leave()
		GameFlow.Screen.SAFE:
			_flow.close_safe()
		GameFlow.Screen.CHEST:
			_flow.leave_chest()
		GameFlow.Screen.FORGE:
			_flow.leave_forge()
		GameFlow.Screen.ALTAR:
			if MODE.begins_with("tut") and run_ != null and not _altar_done.has(run_.current_node().id):
				_altar_done[run_.current_node().id] = true
				_altar643(run_)
				return false
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
	var run_: RunState = _flow.run
	var ev: EventDef = run_.events.pending_event() if run_ != null else null
	if ev != null and ev.id == &"search_again" and _sl() and not MODE in ["sC", "sF"] and _searches >= 2:
		print("E593 搜了两次，不贪第三次：选「离开」")
		_flow.choose_event(ev.options.size() - 1)
		return
	if ev == null:
		_timed("事件屏没有等着的事件：resume", func() -> void: _flow.resume())
		return
	var ctx = run_.events._event_ctx(run_.events.pending_node())
	if MODE == "sM" and String(ev.id).contains("weaver") and not _weaver_logged:
		_weaver_logged = true
		var labs: Array[String] = []
		for j in ev.options.size(): labs.append("%d「%s」%s" % [j, String((ev.options[j] as EventOption).label), "" if (ev.options[j] as EventOption).locked_reason(ctx) == "" else "灰（%s）" % (ev.options[j] as EventOption).locked_reason(ctx)])
		var bolts := _own(run_, &"linen_bolt").size()
		print("E617 补衣人 %s：%d 项：%s；身上亚麻布卷 %d" % [ev.id, ev.options.size(), "；".join(labs), bolts])
		shot("weaver")
	if MODE.begins_with("tut") and String(ev.id).begins_with("tut3_"):
		if not _t3_logged.has(ev.id):
			_t3_logged[ev.id] = true
			print("F645 %s 正文：%s" % [ev.id, ev.text.replace("\n", " ").left(260)])
			print("F645 %s 时：选 %s；有效 %s；联系 %s" % [ev.id, String(run_.selected_faith), String(run_.active_faith_id()), String(run_.faith_connection())])
		if (ev.id == &"tut3_battle_1" and run_.active_faith_id() == &"") or (ev.id == &"tut3_battle_2" and run_.active_faith_id() != &"brute"):
			if _faith_ui(run_, &"charm_brute"):
				return
	if _log309(run_, ev, ctx):
		return
	var pick := -1
	var label := ""
	for i in ev.options.size():
		if (ev.options[i] as EventOption).locked_reason(ctx) != "":
			continue     # 选不了的跳过（序章一精英要先合出毒匕首，没有就走「就这么上」）
		if MODE.begins_with("tut") and run_.events.pending_node() != null and _altar_done.has(run_.events.pending_node().id) and (ev.options[i] as EventOption).outcomes.any(func(o) -> bool: return String((o as Resource).get_script().resource_path).ends_with("open_altar.gd")):
			continue     # 这座神坛已经开过一次：别再开
		if pick < 0:
			pick = i
		var l := String((ev.options[i] as EventOption).label)
		if l.contains("迎战"):
			pick = i
			break
		if _after_fight and l == "离开":
			pick = i
	if MODE == "sB" and not _forge_seen and ev.id == &"rest_default":
		for i in ev.options.size():
			var op := ev.options[i] as EventOption
			var is_forge := false
			for o in op.outcomes:
				if o is OpenForge: is_forge = true
			if is_forge:
				_forge_seen = true
				var labs: Array[String] = []
				for j in ev.options.size(): labs.append("%d「%s」%s" % [j, String((ev.options[j] as EventOption).label), "" if (ev.options[j] as EventOption).locked_reason(ctx) == "" else "灰"])
				print("E616 休息点选项：%s；选 %d 进铁炉" % ["；".join(labs), i])
				_flow.choose_event(i)
				return
	if MODE == "sF" and not _fled:
		for i in ev.options.size():
			if String((ev.options[i] as EventOption).label).contains("逃跑") and (ev.options[i] as EventOption).locked_reason(ctx) == "":
				_fled = true
				var hooks: RunHooks = run_.events.hooks
				var orig := hooks._at(&"run_context")
				hooks.register(&"run_context", func() -> RunContext:
					var c: RunContext = orig.call()
					c.flee_bonus = -1.0
					return c)
				print("E593 测试辅助：逃跑成功率压到 0（只为看逃跑失败的劈心），选「%s」；体力 %d/%d" % [String((ev.options[i] as EventOption).label), run_.vitality.current, run_.vitality.maximum])
				_flow.choose_event(i)
				hooks.register(&"run_context", orig)
				var bids: Array[String] = []
				for bd in run_.active_buff_defs(): bids.append(String(bd.id) if bd != null and "id" in bd else str(bd))
				print("E593 逃跑后：屏 %s，体力 %d/%d，身上的效果 %s，欠劈心 %d" % [GameFlow.Screen.keys()[_flow.screen], run_.vitality.current, run_.vitality.maximum, str(bids), HeartBreak.owed])
				return
	if pick < 0:
		pick = 0
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
	var log_: Array = v._result.log
	var stats := {}
	v._playing = false
	var t_all := Time.get_ticks_usec()
	var n := 0
	while v._cursor < log_.size():
		var e: BattleEvent = log_[v._cursor]
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
	print("  %-22s %6s %9s %9s %9s" % ["事件", "条数", "合计ms", "均ms", "最大ms"])
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
		@warning_ignore("integer_division")
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
	if not screen.verdict_shown():
		_verdict_msec = -1
		return
	# 按真实时间等（_act 每隔一轮稳定帧才叫一次、帧率又跟机器走，按调用次数数会等成几分钟）
	if _verdict_msec < 0:
		_verdict_msec = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _verdict_msec < AFTER_VERDICT_SEC * 1000.0:
		return
	_verdict_msec = -1
	_timed("回放看完「继续」", func() -> void: screen.proceed())


func _act_map(p_run: RunState) -> void:
	if MODE == "sL" and not _start_logged and p_run != null:
		_start_logged = true
		print("E617 出发后：棋盘 %s；地上 %s；整备页最后预览 %s；一致 %s" % [str(_ids(p_run.board)), str(_ids(p_run.storage)), str(_preview_ids), str(_sorted_all(p_run) == _preview_ids)])
		shot("start_board")
	if MODE == "sM" and _m_st < 99 and p_run != null and not p_run.is_over() and (_fh_logged or (p_run.current_node() != null and p_run.current_node().id >= 3)):
		_m_on = true
		return
	if MODE == "sL" and _bought and _lg_cycle < LG_CYCLES and p_run != null and not p_run.is_over():
		_lg_on = true
		return
	if p_run == null or p_run.is_over():
		_timed("一局结束：resume", func() -> void: _flow.resume())
		return
	var cur := p_run.current_node()
	if cur != null and cur.type == &"extract" and _extract_ok(p_run, cur):
		_timed("撤离", func() -> void: _flow.extract())
		return
	if MODE in ["sA", "sB", "sH", "sF", "sL", "sM", "sE"]:
		var t2 := _plan_next(p_run)
		if t2 >= 0:
			_prep_battle(p_run, p_run.map.get_node(t2))
			print("E593 按路线走到 %d（%s）" % [t2, p_run.map.get_node(t2).type])
			_flow.step_to(t2)
			return
	var target := _route(p_run) if MODE in ["free", "fail", "slice", "sC"] else _next_node(p_run)
	if target < 0:
		_report("图上没有下一个点可走（当前 %s）" % (String(cur.type) if cur != null else "?"))
		finish(1)
		return
	var tn := p_run.map.get_node(target)
	if MODE == "fail" or MODE == "sC" or _tut_lose():
		_strip(p_run)
		if _tut_lose() and tn.type == &"battle" and p_run.vitality.current > 1:
			p_run.vitality.current = 1     # 测试辅助：真玩第一段输不掉（空手输两仗只扣 2 点、来回走不耗体力），开战前把体力压到 1，输了就用光
			print("F643 失败路径（测试辅助）：去 %d（battle）前体力压到 1/%d，棋盘只剩包" % [tn.id, p_run.vitality.maximum])
	elif tn.type == &"battle" or tn.type == &"elite" or tn.type == &"core":
		_equip_all(p_run)     # 教程的门：开战前东西要在包里
	var t0 := Time.get_ticks_usec()
	if not _flow.step_to(target):
		_report("走不到 %d（%s）" % [target, tn.type])
		finish(1)
		return
	_stall("走到 %d（%s）" % [target, tn.type], t0)


## 下一步：可走的点里按层（tier）最小、没去过的；都去过了就任意一个没去过的最近点
func _next_node(p_run: RunState) -> int:
	var best := -1
	var best_tier := 1 << 30
	for n in p_run.travel.available_moves():
		var node := p_run.map.get_node(n)
		if node == null or node.is_visited():
			continue
		if node.tier < best_tier:
			best_tier = node.tier
			best = n
	if best >= 0:
		return best
	for n in p_run.travel.available_moves():
		var node := p_run.map.get_node(n)
		if node != null and node.type == &"extract":
			return n
	var moves := p_run.travel.available_moves()
	var fwd := -1
	var fwd_tier := -1
	for n in moves:
		var node := p_run.map.get_node(n)
		if node != null and node.tier > fwd_tier:
			fwd_tier = node.tier
			fwd = n
	return fwd


func _equip_all(p_run: RunState) -> void:
	for inst in p_run.storage.items().duplicate():
		p_run.equip((inst as ItemInstance).uid)
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
		"屏", "帧", "帧ms均", "帧ms最大", "proc均", "proc最大", "对象", "对象增减", "节点", "孤儿", "静态MB", "纹理MB", "绘制", "盘连", "地连"])
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


var _crafted309 := false
var _seen309: Dictionary = {}


func _try_adjacent(run_: RunState, cm: CraftingModule, knife: ItemInstance, vial: ItemInstance) -> bool:
	for rot in [0, 1]:
		for y in run_.board.size.y:
			for x in run_.board.size.x:
				if run_.board.place(vial, Vector2i(x, y), rot):
					if not cm.fuse_preview(knife.uid, vial.uid).is_empty(): return true
					run_.board.remove(vial.uid)
	return false


func _carry309(run_: RunState) -> String:
	var ids: Array[String] = []
	for inv in [run_.board, run_.storage]:
		for it in inv.items():
			var id := String((it as ItemInstance).def.id)
			if id.contains("knife") or id.contains("poison") or id.contains("vial"): ids.append(id)
	return str(ids)


func _find309(run_: RunState, id: StringName) -> ItemInstance:
	for inv in [run_.board, run_.storage]:
		for it in inv.items():
			if (it as ItemInstance).def.id == id: return it
	return null


## 记一笔；守卫门口还没合成就先合成（返回 true = 这一轮做了事，下轮再选）
func _log309(run_: RunState, ev: EventDef, ctx) -> bool:
	var key := "%s@%d" % [ev.id, run_.events.pending_node().id if run_.events.pending_node() != null else -1]
	if not _seen309.has(key) or ev.id == &"tut_elite":
		_seen309[key] = true
		var st: Array[String] = []
		for i in ev.options.size():
			var why := (ev.options[i] as EventOption).locked_reason(ctx)
			st.append("%d「%s」%s" % [i, String((ev.options[i] as EventOption).label), "可选" if why == "" else "灰/藏（%s）" % why])
		print("P309 种子 %d 事件 %s：%s；身上 %s" % [run_.run_seed, ev.id, "；".join(st), _carry309(run_)])
	if ev.id == &"tut_elite" and not _crafted309:
		_crafted309 = true
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].get_base_dir() + "/p309_guard_before.png")
		var knife := _find309(run_, &"knife")
		if knife == null: knife = _find309(run_, &"knife_brute")
		var vial := _find309(run_, &"poison_vial")
		if knife != null and knife.def.id == &"knife" and (MODE == "oldsave" or MODE == "blessed"):
			var bdef := _flow.items.get_def(&"knife_brute")
			var holder := run_.holder_of(knife.uid)
			var at := knife.origin
			var rot := knife.rotation
			holder.remove(knife.uid)
			var bk := ItemInstance.create(bdef, 0)
			var ok := run_.board.place(bk, at, rot) if holder == run_.board else run_.storage.insert(bk)
			if not ok: ok = run_.board.try_add(bk) or run_.storage.insert(bk)
			print("P309 换成赐福匕首 %s（%s）：%s" % [bdef.id if bdef != null else "无", Names.of(bdef) if bdef != null else "", str(ok)])
			knife = bk
			_flow._flush()
			var st2: Array[String] = []
			var ctx2 = run_.events._event_ctx(run_.events.pending_node())
			for i in ev.options.size():
				var why := (ev.options[i] as EventOption).locked_reason(ctx2)
				st2.append("%d%s" % [i, "可选" if why == "" else "灰/藏（%s）" % why])
			print("P309 换后守卫门选项：%s" % "；".join(st2))
			if MODE == "oldsave":
				print("P309 存档：%s" % str(_flow.save()))
				shot("oldsave_before_close")
				root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
				finish(0)
				return true
		print("P309 守卫门口：普通匕首 %s，毒药瓶 %s" % [str(knife != null), str(vial != null)])
		if knife == null or vial == null:
			return false
		if not run_.board.has_item(knife.uid):
			run_.equip(knife.uid)
		if run_.storage.has_item(vial.uid): run_.storage.remove(vial.uid)
		else: run_.board.remove(vial.uid)
		var cm := CraftingModule.of(run_)
		print("P309 匕首在棋盘 %s" % str(run_.board.has_item(knife.uid)))
		var placed := _try_adjacent(run_, cm, knife, vial)
		if not placed:
			for it in run_.board.items().duplicate():
				var inst := it as ItemInstance
				if inst.uid == knife.uid or run_.board.acts_as_bag(inst.def): continue
				InventoryService.transfer_auto(run_.board, inst.uid, run_.storage)
			print("P309 腾地方：别的东西挪到地上，匕首在棋盘 %s" % str(run_.board.has_item(knife.uid)))
			placed = _try_adjacent(run_, cm, knife, vial)
		if not placed:
			run_.storage.insert(vial)
		var pv := cm.fuse_preview(knife.uid, vial.uid)
		print("P309 毒药瓶贴着 %s 放：%s；成品 %s；解析 %s" % [knife.def.id, str(placed), pv["output"].id if pv.has("output") else "-", str(pv.get("resolution", {}))])
		var made := cm.fuse(knife.uid, vial.uid) if placed else {}
		print("P309 点锤合成：%s；身上 %s" % [str(made), _carry309(run_)])
		_flow._flush()
		return true
	return false



## ---- 593 ----
func _act_setup() -> void:
	var st = _game.base()
	if not st.has_method("choose_character"):
		st = _game.overlay()
	if MODE == "sL" and _su < 5:
		_setup_sl(st)
		return
	if _sl():
		print("E593 切片：档案 %s；章节 %s；角色 %s" % [str(_flow.profile), str(st._chapters.map(func(c): return String(c.id))), str(st._characters.map(func(c): return String(c.id)))])
		if MODE == "sM":
			var rn := root.find_children("RosterNote", "", true, false)
			print("E617 选人栏纸条：%s" % ("没有" if rn.is_empty() else "「%s」看得见 %s；角色 %d 位" % [(rn[0] as Label).text, str((rn[0] as Control).is_visible_in_tree()), st._characters.size()]))
		if MODE == "sE":
			_flow.meta.insight += 20
			print("E632 点亮精英奖励：%s；首领奖励：%s" % [str(_flow.upgrade_tech(&"elite_bounty")), str(_flow.upgrade_tech(&"boss_bounty"))])
		shot("slice_setup")
		for g in 12:
			if _flow.screen != GameFlow.Screen.SETUP: break
			var t = _game.base()
			if t.next_page(): shot("slice_setup_next"); continue
			if t.needs_spawn():
				t.pick_spawn(int(t.preview().entry_ids()[0])); continue
			t.depart()
		if MODE == "sE" and _flow.run != null:
			_flow.run.events.bounty_given.connect(func(n, id, ty): print("E632 额外奖励：节点 %s 类型 %s 掉 %s" % [str(n.id), String(ty), String(id)]))
		print("E593 出发后屏 %s 章 %s" % [GameFlow.Screen.keys()[_flow.screen], _flow.run.chapter.id if _flow.run != null else "?"])
		return
	if _setup_done == 0:
		for i in st._characters.size():
			if st._characters[i].id == &"andreus": st.choose_character(i)
		var ps: Array = st._preset_list()
		for i in ps.size():
			if ps[i].id == &"preset_offense": print("E593 预设强攻：%s" % str(st.choose_preset(i)))
		_setup_done = 1
		return
	for g in 8:
		if st._chapters.size() > 0 and st.page() == 2: break
		if not st.next_page(): break
	for i in st._chapters.size():
		if st._chapters[i].id == &"free_mode": st.choose_chapter(i)
	st.choose_scale(&"small")
	var lad: Array = _flow.available_difficulties()
	for i in lad.size():
		if String(lad[i].id) == "normal": st.choose_difficulty(i)
	if st.run_seed != 780613: st.set_run_seed(780613)
	print("E593 开局：角色 %s 预设 %s 图 %s 规模 %s 难度 %s 种子 %d 页 %d" % [st._characters[st.character_index].id, st.preset().id if st.preset() != null else "无", st._chapters[st.chapter_index].id, st.scale_id, st.difficulty().id if st.difficulty() != null else "?", st.run_seed, st.page()])
	shot("setup_map_page")
	for g in 12:
		if _flow.screen != GameFlow.Screen.SETUP: break
		var t = _game.base()
		if t.next_page(): continue
		if t.needs_spawn():
			t.pick_spawn(int(t.preview().entry_ids()[0])); continue
		t.depart()
	print("E593 出发后屏 %s 种子 %d" % [GameFlow.Screen.keys()[_flow.screen], _flow.run.run_seed if _flow.run != null else -1])


var _setup_done := 0


func _route(p_run: RunState) -> int:
	var want: Array[StringName] = []
	if MODE == "fail" or MODE == "sC":
		want.append(&"battle"); want.append(&"elite")
	elif (MODE == "free" or _sl()) and not _bought:
		want.append(&"shop")
	else:
		want.append(&"extract")
	var start := p_run.current_node().id if p_run.current_node() != null else -1
	var moves := p_run.travel.available_moves()
	var best := -1
	var best_d := 1 << 30
	for m in moves:
		var dist := {m: 0}
		var q: Array[int] = [m]
		var qi := 0
		while qi < q.size():
			var c: int = q[qi]; qi += 1
			var node := p_run.map.get_node(c)
			if node != null and want.has(NodeEvents.effective_type(node)) and not (node.is_visited() and NodeEvents.effective_type(node) != &"extract") and _extract_ok(p_run, node):
				if dist[c] < best_d or (dist[c] == best_d and NodeEvents.effective_type(node) == &"extract" and node.type == &"extract"):
					best_d = dist[c]; best = m
				break
			for nb in p_run.map.neighbors(c):
				if nb != start and not dist.has(nb):
					dist[nb] = dist[c] + 1; q.append(nb)
	if best < 0:
		return _next_node(p_run)
	print("E593 去 %s：下一步 %d（还 %d 步）" % [str(want), best, best_d])
	return best


func _extract_ok(p_run: RunState, node: MapNode) -> bool:
	if NodeEvents.effective_type(node) != &"extract":
		return true
	var cd := CountdownModule.of(p_run)
	if cd != null and cd.extract_closed(node):
		return false
	return p_run.events.extract_fee(node) <= p_run.wallet.balance


func _strip(p_run: RunState) -> void:
	for it in p_run.board.items().duplicate():
		var inst := it as ItemInstance
		if String(inst.def.id).begins_with("bag"): continue
		InventoryService.transfer_auto(p_run.board, inst.uid, p_run.storage)


func _act_shop() -> void:
	var s = _game.overlay() if _game.overlay() != null and _game.overlay().has_method("pay_gap") else _game.base()
	var sess: ShopSession = s._session
	if not _shop_logged:
		_shop_logged = true
		print("E593 进店提示：%s" % s.line_text())
		shot("shop_first_visit")
		_shop_t = Time.get_ticks_msec()
		return
	if _sl() and _shop_t > 0:
		var el := Time.get_ticks_msec() - _shop_t
		if el < 6000:
			_screen_frames = SETTLE_FRAMES - 3
			return
		if not _shop_clicked:
			_shop_clicked = true
			print("E593 进店约 %.1f 秒（没按鼠标）：%s" % [el / 1000.0, str(s.notice_layer().lines())])
			var p := Vector2(800, 870)
			var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = true; mb.position = p; mb.global_position = p
			Input.parse_input_event(mb)
			var mu := mb.duplicate(); mu.pressed = false
			Input.parse_input_event(mu)
			return
		print("E593 按一下鼠标后：%s" % str(s.notice_layer().lines()))
		shot("shop_after_click")
		_shop_t = 0
		if MODE in ["sA", "sH"]:
			_shop_buy_many(s, [&"round_shield", &"shortsword", &"poison_vial"]); _bought = true
			return
	var budget := _flow.run.wallet.balance
	if budget < 5:
		var mine: ItemInstance = null
		for it in _flow.run.board.items():
			var i := it as ItemInstance
			if String(i.def.id).begins_with("bag") or sess.refuse_reason(i) != "": continue
			if mine == null or sess.sell_price_of(i.def, i) > sess.sell_price_of(mine.def, mine): mine = i
		if mine != null:
			print("E593 钱不够，拿自己的 %s（卖价 %d）上秤换：%s" % [mine.def.id, sess.sell_price_of(mine.def, mine), str(s.offer(mine.uid))])
			budget += sess.sell_price_of(mine.def, mine)
	var ware: ItemInstance = null
	for it in sess.board.items():
		var p := sess.price_of((it as ItemInstance).def)
		if p <= budget and (ware == null or p > sess.price_of(ware.def)): ware = it
	if ware == null:
		for it in sess.board.items():
			if ware == null or sess.price_of((it as ItemInstance).def) < sess.price_of(ware.def): ware = it
	print("E593 钱 %d；挑 %s（价 %d）：%s" % [_flow.run.wallet.balance, ware.def.id, sess.price_of(ware.def), str(s.take(ware.uid))])
	var n: int = s.pay_gap()
	print("E593 点钱袋补差：放上 %d；提示：%s" % [n, s.line_text()])
	shot("shop_pay_gap")
	if sess.can_deal():
		print("E593 成交：%s；钱 %d；买到 %s" % [str(s.deal()), _flow.run.wallet.balance, ware.def.id])
	else:
		print("E593 钱不够成交，收回")
		if n > 0: s.pay_gap()
		if s.pending(ware.uid): s.withdraw(ware.uid)
	shot("shop_after_deal")
	_bought = true


var _res_phase := 0
var _res_logged := false


func _log_result() -> void:
	var r: RunState = _flow.run
	var b = _game.base()
	if _res_phase == 2:
		print("E593 结算第 %d 页" % b.step())
		shot("result_page%d" % b.step())
		if b.step() == 2 and not MODE.begins_with("tut"):
			print("E593 置入仓库：%s" % str(b.store_all()))
			shot("result_stored")
		return
	if r != null and b.continue_button() != null and not b.continue_button().disabled:
		shot("result_page1")
		print("E593 账单：%s" % str(b.numbers()))
		var trw := root.find_children("TutorialReward", "", true, false)
		var tt := ""
		if not trw.is_empty():
			for l in (trw[0] as Node).find_children("*", "Label", true, false): tt += (l as Label).text + " / "
			tt += "图 %d 张" % (trw[0] as Node).find_children("*", "TextureRect", true, false).size()
		print("F643 结算：%s %s；教程奖励小纸 %s" % [String(r.chapter.id), "撤离" if r.phase == RunState.Phase.EXTRACTED else "失败", "没有" if trw.is_empty() else tt])
		var ins := root.find_children("Insight", "", true, false)
		var itxt := ""
		if not ins.is_empty():
			for l in (ins[0] as Node).find_children("*", "Label", true, false): itxt += (l as Label).text + " / "
		print("E620 见识小纸：%s；局外见识 %d；这一局 %d" % ["没有" if ins.is_empty() else "看得见 %s：%s" % [str((ins[0] as Control).is_visible_in_tree()), itxt], _flow.meta.insight, b._r.insight if b.get("_r") != null else -1])
		print("E593 结算时体力 %d/%d，棋盘 %d 件，地上 %d 件，钱 %d" % [r.vitality.current, r.vitality.maximum, r.board.item_count(), r.storage.item_count(), r.wallet.balance])
	var ok: bool = b.confirm_key(false)
	if not ok:
		_res_phase -= 1     # 账单还在走：等它走完再按
		return
	print("E593 第 1 页账单走完，按「继续」")


func _log_meta(tag: String) -> void:
	var m := _flow.meta
	var ids: Array[String] = []
	for it in m.warehouse.items():
		ids.append(String((it as ItemInstance).def.id))
	print("E593 %s：仓库 %d 件 %s；局外钱 %d；局数 %d 撤离 %d 战败 %d；历史 %d" % [tag, ids.size(), str(ids), m.funds, m.runs, m.extractions, m.deaths, m.history.size()])
	shot("meta_" + tag)


func _reenter() -> void:
	print("E593 重开：局内存档 %s；进「继续」%s；屏 %s" % [str(_flow.has_save()), str(_flow.continue_game()), GameFlow.Screen.keys()[_flow.screen]])
	_closing = 1



## ---- S3 ----
var _again := false
var _searches := 0
var _loss_pending := false
var _shop_t := 0
var _shop_clicked := false


func _sl() -> bool:
	return MODE in ["slice", "sA", "sB", "sC", "sH", "sF", "sL", "sM", "sE"]


func _plan() -> Array[int]:
	if MODE == "sE":
		return [1, 2, 3, 6, 7, 8, 10, 11, 12]
	if MODE in ["sA", "sH"]:
		return [1, 2, 3, 4, 5, 8, 10, 11, 12]
	return [1, 2, 3, 4, 5, 8, 9]


func _plan_next(p_run: RunState) -> int:
	var cur := p_run.current_node().id if p_run.current_node() != null else 0
	var pl := _plan()
	var i := pl.find(cur)
	var nxt: int = pl[i + 1] if i + 1 < pl.size() else -1
	if i < 0: nxt = pl[0]
	return nxt if nxt >= 0 and p_run.travel.available_moves().has(nxt) else -1


func _own(p_run: RunState, id: StringName) -> Array:
	var out := []
	for inv in [p_run.board, p_run.storage]:
		for it in inv.items():
			if (it as ItemInstance).def.id == id: out.append(it)
	return out


## 开战前像玩家那样合成：有毒药瓶就合涂毒匕首，有磨刀石就合淬火匕首；然后能放的都放上棋盘
func _prep_battle(p_run: RunState, tn: MapNode) -> void:
	if tn == null or not (tn.type in [&"battle", &"elite"]):
		return
	var cm := CraftingModule.of(p_run)
	var pairs := [[&"knife", &"poison_vial"], [&"knife", &"whetstone"]]
	if MODE in ["sA", "sH"]:
		pairs = [[&"knife", &"knife"]] if tn.id == 3 else [[&"shortsword", &"whetstone"], [&"knife", &"poison_vial"]]
	for pair in pairs:
		var a := _own(p_run, pair[0]); var b := _own(p_run, pair[1])
		if a.is_empty() or b.is_empty() or (pair[0] == pair[1] and a.size() < 2): continue
		var ka := a[0] as ItemInstance; var kb := (a[1] if pair[0] == pair[1] else b[0]) as ItemInstance
		if not p_run.board.has_item(ka.uid): p_run.equip(ka.uid)
		var holder := p_run.holder_of(kb.uid)
		holder.remove(kb.uid)
		var ok := _try_adjacent(p_run, cm, ka, kb)
		if not ok:
			for it in p_run.board.items().duplicate():
				var inst := it as ItemInstance
				if inst.uid == ka.uid or p_run.board.acts_as_bag(inst.def): continue
				InventoryService.transfer_auto(p_run.board, inst.uid, p_run.storage)
			ok = _try_adjacent(p_run, cm, ka, kb)
		if ok:
			print("E593 合成 %s + %s：%s" % [pair[0], pair[1], str(cm.fuse(ka.uid, kb.uid).get("output", "?"))])
		else:
			p_run.storage.insert(kb)
			print("E593 合成 %s + %s：摆不出相邻" % [pair[0], pair[1]])
	if (MODE == "sA" and tn.id == 11) or (MODE == "sE" and tn.type == &"elite"):
		var give: Array[String] = []
		for id in [&"poisoned_knife", &"scimitar", &"round_shield", &"leather_armor"]:
			if _own(p_run, id).is_empty():
				p_run.storage.insert(ItemInstance.create(_flow.items.get_def(id), 0)); give.append(String(id))
		for it in p_run.board.items().duplicate():
			var inst := it as ItemInstance
			if not p_run.board.acts_as_bag(inst.def) and not (inst.def.id in [&"poisoned_knife", &"scimitar", &"round_shield", &"leather_armor"]):
				InventoryService.transfer_auto(p_run.board, inst.uid, p_run.storage)
		print("E593 测试辅助：守卫前补齐报告里的必胜配置（涂毒匕首 + 弯刀 + 圆盾 + 皮甲），补了 %s" % str(give))
		for id in [&"poisoned_knife", &"scimitar", &"round_shield", &"leather_armor"]:
			for it in _own(p_run, id):
				if not p_run.board.has_item((it as ItemInstance).uid): p_run.equip((it as ItemInstance).uid)
	else:
		_equip_all(p_run)
	var ids: Array[String] = []
	for it in p_run.board.items(): ids.append(String((it as ItemInstance).def.id))
	print("E593 打 %d（%s）前棋盘：%s" % [tn.id, tn.type, str(ids)])


func _shop_buy_many(s, wants: Array) -> void:
	var sess: ShopSession = s._session
	for w in wants:
		for it in sess.board.items():
			if (it as ItemInstance).def.id == w and not s.pending((it as ItemInstance).uid):
				print("E593 拿 %s（价 %d）：%s" % [w, sess.price_of((it as ItemInstance).def), str(s.take((it as ItemInstance).uid))])
				break
	for junk in [&"linen_bolt", &"ration", &"bandage", &"salve", &"leather_armor"]:
		if sess.left_total() <= sess.goods_right() + _flow.run.wallet.balance: break
		for it in _flow.run.board.items() + _flow.run.storage.items():
			if (it as ItemInstance).def.id == junk:
				print("E593 拿 %s 上秤抵钱：%s" % [junk, str(s.offer((it as ItemInstance).uid))]); break
	var n: int = s.pay_gap()
	print("E593 补差 %d；提示 %s；能成交 %s" % [n, s.line_text(), str(sess.can_deal())])
	var taken: Array = []
	for it in sess.board.items(): pass
	for w in wants.duplicate():
		if sess.can_deal(): break
		if n > 0: s.pay_gap(); n = 0
		var last = wants.pop_back()
		for it in _flow.run.board.items() + _flow.run.storage.items():
			if (it as ItemInstance).def.id == last and s.pending((it as ItemInstance).uid):
				print("E593 钱不够，放回 %s：%s" % [last, str(s.withdraw((it as ItemInstance).uid))]); break
		n = s.pay_gap()
		print("E593 再补差 %d；能成交 %s" % [n, str(sess.can_deal())])
	if sess.can_deal():
		print("E593 成交：%s；钱 %d" % [str(s.deal()), _flow.run.wallet.balance])
	shot("shop_after_deal")


## ---- v6.09 劈心：打输 / 逃跑失败回到地图 —— 按时间截图、记各段进度；sC 第二次在 0.5 s 点一下看跳过 ----
var _fled := false
var _hb: Control = null
var _hb_widget: Control = null
var _hb_state := 0
var _hb_wait := 0
var _hb_t0 := 0
var _hb_n := 0
var _hb_owed0 := 0
var _hb_skip := false
var _hb_shots: Array = []
var _hb_f0 := 0
var _hb_idx := -1


func _find_hb() -> Control:
	for n in root.find_children("*", "Control", true, false):
		if n is HeartBreak and not n.is_queued_for_deletion(): return n
	return null


func _hbclick(at: Vector2) -> void:
	Input.warp_mouse(at)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at; e.global_position = at
		e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down
		Input.parse_input_event(e)


func _heart_tick() -> bool:
	var run_: RunState = _flow.run
	if _hb_state == 0:
		var h := _find_hb()
		if h == null:
			_hb_wait += 1
			if _hb_wait > 90:
				print("E593 劈心：回地图 90 帧没看到（体力 %d/%d，欠 %d）" % [run_.vitality.current if run_ != null else -1, run_.vitality.maximum if run_ != null else -1, HeartBreak.owed])
				shot("heart_missing")
				_loss_pending = false; _hb_wait = 0
				return false
			return true
		_hb = h; _hb_widget = h.get("_widget"); _hb_state = 1; _hb_t0 = Time.get_ticks_msec(); _hb_n += 1; _loss_pending = false; _hb_wait = 0
		_hb_owed0 = HeartBreak.owed
		_hb_skip = MODE == "sC" and _hb_n == 2
		_hb_shots = ["slash"]
		_hb_f0 = Engine.get_process_frames()
		_hb_idx = int(h.get("_index"))
		print("E593 劈心第 %d 次开始：欠 %d 颗；体力 %d/%d；体力条画 %s；先劈序号 %d；跳过测试 %s" % [_hb_n, _hb_owed0, run_.vitality.current, run_.vitality.maximum, str(_hb_widget.call("hearts")) if _hb_widget != null else "?", int(h.get("_index")), str(_hb_skip)])
		return true
	var el := (Time.get_ticks_msec() - _hb_t0) / 1000.0
	if not is_instance_valid(_hb) or _hb.is_queued_for_deletion():
		print("E593 劈心第 %d 次结束（%d 帧）：%.2f s；欠 %d；体力 %d/%d；体力条画 %s" % [_hb_n, Engine.get_process_frames() - _hb_f0, el, HeartBreak.owed, run_.vitality.current, run_.vitality.maximum, str(_hb_widget.call("hearts")) if is_instance_valid(_hb_widget) else "?"])
		shot("heart_%d_end" % _hb_n)
		_hb_state = 0; _hb = null
		if (MODE == "sH" and _hb_owed0 >= 2) or (MODE == "sF" and _fled):
			_report("劈心看完")
			finish(0)
		return true
	var idx := int(_hb.get("_index"))
	if idx != _hb_idx:
		print("E593 劈心 %.2f s（%d 帧）：换下一颗，序号 %d → %d；欠 %d；体力条画 %s" % [el, Engine.get_process_frames() - _hb_f0, _hb_idx, idx, HeartBreak.owed, str(_hb_widget.call("hearts"))])
		_hb_idx = idx; _hb_shots = ["slash"]
	var want := ""
	if _hb_shots.size() > 0: want = _hb_shots[0]
	var hit: bool = (want == "slash" and _hb.slash() >= 0.5) or (want == "split" and _hb.split() >= 0.9 and _hb.fly() <= 0.0) or (want == "fly" and _hb.fly() >= 0.45)
	if hit:
		_hb_shots.pop_front()
		if want == "slash": _hb_shots = ["split", "fly"]
		print("E593 劈心 %.2f s（%d 帧）[%s]：序号 %d pop %.2f slash %.2f split %.2f fly %.2f；欠 %d；体力条画 %s" % [el, Engine.get_process_frames() - _hb_f0, want, idx, _hb.pop(), _hb.slash(), _hb.split(), _hb.fly(), HeartBreak.owed, str(_hb_widget.call("hearts"))])
		shot("heart_%d_i%d_%s" % [_hb_n, idx, want])
	if _hb_skip and _hb.split() > 0.3:
		_hb_skip = false
		_hbclick(root.get_final_transform() * _hb.get_global_rect().get_center())
		print("E593 劈心 %.2f s：点一下鼠标跳过" % el)
	return true


## ---- v6.15（报告 316）：营地铁炉只剩铸炉；悬浮窗没有「可升为」 ----
var _forge_seen := false
var _fg := 0


func _forge_tick() -> void:
	_fg += 1
	var run_: RunState = _flow.run
	if _fg == 1:
		var scripts: Array[String] = []
		for n in root.find_children("*", "Control", true, false):
			var sc = n.get_script()
			if sc != null and (n as Control).is_visible_in_tree():
				var f := String(sc.resource_path).get_file()
				if not scripts.has(f): scripts.append(f)
		var anv := scripts.filter(func(x): return String(x).contains("anvil") or String(x).contains("upgrade"))
		print("E616 铁炉屏：看得见的脚本 %d 种；带 anvil/upgrade 的 %s" % [scripts.size(), str(anv)])
		print("E616 铁炉屏脚本：%s" % str(scripts))
		shot("camp_forge")
		return
	if _fg == 2:
		var weapon: ItemInstance = null
		for it in run_.board.items():
			if (it as ItemInstance).def.combat != null: weapon = it; break
		var view: InventoryView = null
		for v in root.find_children("*", "InventoryView", true, false):
			if (v as Control).is_visible_in_tree() and v.inventory == run_.board: view = v
		if weapon == null or view == null:
			print("E616 铁炉屏：棋盘上找不到武器 / 棋盘视图（%s / %s）" % [str(weapon), str(view)])
			_fg = 60; return
		var r: Rect2 = view.get_global_transform() * view.item_rect(weapon.uid)
		var at := root.get_final_transform() * r.get_center()
		Input.warp_mouse(at)
		var m := InputEventMouseMotion.new(); m.position = at; m.global_position = at
		Input.parse_input_event(m)
		print("E616 悬停 %s（%s）" % [weapon.def.id, Names.of(weapon.def)])
		return
	if _fg == 50:
		var txt := ""
		for t in root.find_children("*", "HoverTip", true, false):
			if (t as HoverTip)._panel.visible: txt = (t as HoverTip)._panel.text()
		print("E616 悬浮窗字：%s" % txt.replace("\n", " / ").left(400))
		print("E616 悬浮窗有「可升为 / Upgrades」：%s；有「可拼为」：%s" % [str(txt.contains("可升为") or txt.to_lower().contains("upgrade")), str(txt.contains("可拼为") or txt.to_lower().contains("fuse"))])
		shot("camp_forge_tip")
		return
	if _fg == 60:
		var m := InputEventMouseMotion.new(); var at := root.get_final_transform() * Vector2(1500, 860); m.position = at; m.global_position = at
		Input.warp_mouse(at); Input.parse_input_event(m)
	if _fg >= 70:
		print("E616 离开铁炉：%s" % str(_flow.leave_forge()))
		_fg = 0
		_screen_frames = 0


## ---- v6.16（报告 317）：切片整备页（预设 / 补给 / 仓库纸条）+ 方案 §2.3 长序列（B01） ----
var _su := 0
var _start_logged := false
var _preview_ids: Array = []
const LG_CYCLES := 12
var _lg_on := false
var _lg_cycle := 0
var _lg := 0
var _lg_w := 0
var _lg_fused := false
var _lg_from := Vector2.ZERO
var _lg_to := Vector2.ZERO
var _lg_k := 0
var _lg_gi := 0


func _ids(inv) -> Array:
	var out := []
	for it in inv.items(): out.append(String((it as ItemInstance).def.id))
	out.sort()
	return out


func _sorted_all(p_run: RunState) -> Array:
	var a := _ids(p_run.board) + _ids(p_run.storage)
	a.sort()
	return a


func _setup_sl(st) -> void:
	match _su:
		0:
			st.show_page(1)
		1:
			var nl := NoticeLayer.current().lines() if NoticeLayer.current() != null else []
			var names := []
			for pr in st._preset_list(): names.append(String(pr.id))
			var note = st.get("_no_carry_note")
			var note_txt := ""
			if note != null:
				for l in (note as Node).find_children("*", "Label", true, false): note_txt += (l as Label).text
			print("E617 整备页：预设 %s；告示 %s；仓库纸条 看得见 %s：%s" % [str(names), str(nl), str(note != null and (note as Control).is_visible_in_tree()), note_txt])
			_log_board(st, "不选预设")
			shot("setup_kit_none")
			_pick(st, &"slice_offense")
		2:
			_log_board(st, "强攻")
			shot("setup_offense")
			_pick(st, &"slice_defense")
		3:
			_log_board(st, "坚守")
			shot("setup_defense")
			_pick(st, &"slice_offense")
		4:
			_log_board(st, "强攻（A→B→A）")
			_preview_ids = _ids(st.board)
			shot("setup_offense_again")
	_su += 1


func _pick(st, id: StringName) -> void:
	var ps: Array = st._preset_list()
	for i in ps.size():
		if ps[i].id == id:
			print("E617 选预设 %s：%s" % [id, str(st.choose_preset(i))])
			return
	print("E617 !! 没有预设 %s" % id)


func _log_board(st, tag: String) -> void:
	var sup := []
	for it in st.supply_items(): sup.append(String((it as ItemInstance).def.id))
	var pre := []
	for it in st.preset_items(): pre.append(String((it as ItemInstance).def.id))
	var wh_vis := false
	for v in root.find_children("*", "InventoryView", true, false):
		if (v as Control).is_visible_in_tree() and v.inventory != st.board and v.inventory != null and String(v.get_path()).to_lower().contains("ware"): wh_vis = true
	print("E617 整备页 [%s]：棋盘 %s；补给 %s；预设件 %s；仓库框看得见 %s；预设 %s" % [tag, str(_ids(st.board)), str(sup), str(pre), str(wh_vis), str(st.preset().id) if st.preset() != null else "无"])


func _lg_panel() -> Node:
	for n in root.find_children("*", "Control", true, false):
		var s = n.get_script()
		if s != null and String(s.resource_path).ends_with("inventory_panel.gd") and (n as Control).is_visible_in_tree():
			return n
	return null


func _lg_center(p: Node, inst: ItemInstance) -> Vector2:
	var run_: RunState = _flow.run
	var view: Control = null
	if run_.board.has_item(inst.uid): view = p.board_view
	elif p.ground != null and run_.storage.has_item(inst.uid): view = p.ground
	if view == null: return Vector2(-1, -1)
	return root.get_final_transform() * (view.get_global_transform() * view.item_rect(inst.uid)).get_center()


func _lg_mv(at: Vector2, down: bool) -> void:
	Input.warp_mouse(at)
	var e := InputEventMouseMotion.new(); e.position = at; e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)


func _lg_btn(at: Vector2, down: bool, dbl := false) -> void:
	Input.warp_mouse(at)
	var e := InputEventMouseButton.new(); e.position = at; e.global_position = at
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down; e.double_click = dbl and down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)


func _lg_click_ctl(c: Control) -> void:
	var at := root.get_final_transform() * c.get_global_rect().get_center()
	_lg_mv(at, false); _lg_btn(at, true); _lg_btn(at, false)


func _quiet_counts() -> String:
	var out := []
	for t in root.find_children("*", "HoverTip", true, false):
		if t.has_method("quiet_count"): out.append(int(t.call("quiet_count")))
	return str(out)


## 一对能合的（棋盘 / 地上），找不到返回 []
func _lg_pair() -> Array:
	var run_: RunState = _flow.run
	var cm := CraftingModule.of(run_)
	var all := []
	for inv in [run_.board, run_.storage]:
		for it in inv.items():
			if not run_.board.acts_as_bag((it as ItemInstance).def): all.append(it)
	for a in all:
		for b in all:
			if a != b and cm.partner_ok(a, b): return [a, b]
	return []


func _map_screen():
	return _game.base()


func _long_tick() -> void:
	_screen_started_msec = Time.get_ticks_msec()     # 长序列本身就停在地图上
	if _lg_w > 0:
		_lg_w -= 1; return
	var run_: RunState = _flow.run
	var ms = _map_screen()
	var p := _lg_panel()
	var tag := "E617 长序列第 %d 轮" % (_lg_cycle + 1)
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); _lg_w = 10; return
	match _lg:
		0:
			if p == null: ms.toggle_bag()
			_lg = 1; _lg_w = 25
		1:
			if p == null: print("%s !! 背包没开" % tag); _lg = 20; return
			var pair := _lg_pair()
			if pair.is_empty():
				print("%s：没有能合的一对，跳过合成" % tag); _lg = 6; return
			_lg_from = _lg_center(p, pair[0]); _lg_to = _lg_center(p, pair[1])
			print("%s：拖 %s 到 %s 上（%s）；悬浮登记 %s" % [tag, pair[0].def.id, pair[1].def.id, "合成" if not _lg_fused else "取消", _quiet_counts()])
			_lg_mv(_lg_from, false); _lg = 2; _lg_w = 3
		2:
			_lg_btn(_lg_from, true); _lg_k = 0; _lg = 3; _lg_w = 3
		3:
			_lg_k += 1; _lg_mv(_lg_from.lerp(_lg_to, _lg_k / 6.0), true); _lg_w = 2
			if _lg_k >= 6: _lg = 4
		4:
			_lg_btn(_lg_to, false); _lg = 5; _lg_w = 20
		5:
			var n: FuseNote = p.fuse_note
			if n == null or not n.is_open():
				print("%s !! 确认窗没开" % tag); _lg = 6; return
			if not _lg_fused:
				_lg_fused = true
				shot("long_fuse_note")
				_lg_click_ctl(n.go_key)
			else:
				_lg_click_ctl(n.cancel_key)
			_lg = 51; _lg_w = 20
		51:
			print("%s：合成后棋盘 %s 地上 %s" % [tag, str(_ids(run_.board)), str(_ids(run_.storage))])
			_lg = 6
		6:
			# 长物挤出：棋盘上最大的一件压到另一件上（不是能合的那种）
			var big: ItemInstance = null
			var area := 0
			for it in run_.board.items():
				var inst := it as ItemInstance
				if run_.board.acts_as_bag(inst.def): continue
				var a := int(p.board_view.item_rect(inst.uid).get_area())
				if a > area: area = a; big = inst
			var other: ItemInstance = null
			var cm := CraftingModule.of(run_)
			for it in run_.board.items():
				var inst := it as ItemInstance
				if inst != big and not run_.board.acts_as_bag(inst.def) and big != null and not cm.partner_ok(big, inst): other = inst; break
			if _lg_cycle % 3 != 0 or big == null or other == null:
				_lg = 10; return
			_lg_from = _lg_center(p, big); _lg_to = _lg_center(p, other)
			print("%s：挤出 —— 拿 %s 压到 %s 上；挤前地上 %d 件" % [tag, big.def.id, other.def.id, run_.storage.items().size()])
			_lg_mv(_lg_from, false); _lg = 7; _lg_w = 3
		7:
			_lg_btn(_lg_from, true); _lg_k = 0; _lg = 8; _lg_w = 3
		8:
			_lg_k += 1; _lg_mv(_lg_from.lerp(_lg_to, _lg_k / 6.0), true); _lg_w = 2
			if _lg_k >= 6: _lg = 9
		9:
			_lg_btn(_lg_to, false)
			_lg = 91; _lg_w = 15
		91:
			print("%s：挤后棋盘 %d 件，地上 %d 件；确认窗开着 %s" % [tag, run_.board.items().size(), run_.storage.items().size(), str(p.fuse_note != null and p.fuse_note.is_open())])
			if p.fuse_note != null and p.fuse_note.is_open(): p.fuse_note.close()
			if _lg_cycle == 0: shot("long_displaced")
			_lg = 10
		10:
			ms.toggle_bag(); _lg = 11; _lg_w = 15
		11:
			var dr = ms.get("_drawer")
			if dr != null and (dr as Control).is_inside_tree():
				dr.toggle(); print("%s：调试台开 %s" % [tag, str(dr.is_open())])
				if _lg_cycle == 0: _lg_w = 5
			else:
				print("%s：没有调试台" % tag)
			_lg = 12; _lg_w = 15
		12:
			var dr = ms.get("_drawer")
			if dr != null and (dr as Control).is_inside_tree() and dr.is_open():
				if _lg_cycle == 0: shot("long_drawer_open")
				dr.toggle()
			ms.toggle_bag(); _lg = 13; _lg_w = 20; _lg_gi = 0
		13:
			p = _lg_panel()
			var ground := run_.storage.items()
			if p == null or ground.is_empty():
				print("%s：地上没东西 / 背包没开（%s）" % [tag, str(p != null)]); _lg = 16; return
			if _lg_gi >= mini(3, ground.size()):
				_lg = 15; return
			var g := ground[_lg_gi] as ItemInstance
			_lg_mv(_lg_center(p, g), false)
			_lg = 14; _lg_w = 35
		14:
			var vis := false
			for t in root.find_children("*", "HoverTip", true, false):
				if (t as HoverTip)._panel.visible: vis = true
			print("%s：悬停地上第 %d 件 %s：悬浮窗 %s；登记 %s" % [tag, _lg_gi + 1, (run_.storage.items()[_lg_gi] as ItemInstance).def.id if _lg_gi < run_.storage.items().size() else "?", str(vis), _quiet_counts()])
			if _lg_cycle == 0 and _lg_gi == 0: shot("long_ground_hover")
			_lg_gi += 1; _lg = 13
		15:
			# 收回地上一件：双击
			var ground := run_.storage.items()
			if not ground.is_empty():
				var g := ground[0] as ItemInstance
				var at := _lg_center(p, g)
				_lg_btn(at, true); _lg_btn(at, false); _lg_btn(at, true, true); _lg_btn(at, false)
				print("%s：双击收回 %s" % [tag, g.def.id])
			_lg = 151; _lg_w = 15
		151:
			print("%s：收回后棋盘 %d 件，地上 %d 件" % [tag, run_.board.items().size(), run_.storage.items().size()])
			_lg = 16
		16:
			var pp := _lg_panel()
			if pp != null: ms.toggle_bag()
			_lg = 17; _lg_w = 15
		17:
			# 背包关着时也悬停地上（地上那块常驻的窗）
			var ground := run_.storage.items()
			if not ground.is_empty():
				for gl in root.find_children("*", "GroundLayer", true, false):
					if (gl as Control).is_visible_in_tree() and (gl as GroundLayer).stash != null and (gl as GroundLayer).stash.has_item((ground[0] as ItemInstance).uid):
						var at := root.get_final_transform() * ((gl as Control).get_global_transform() * (gl as GroundLayer).item_rect((ground[0] as ItemInstance).uid)).get_center()
						_lg_mv(at, false)
			_lg = 18; _lg_w = 35
		18:
			var vis := false
			for t in root.find_children("*", "HoverTip", true, false):
				if (t as HoverTip)._panel.visible: vis = true
			print("%s：背包关着悬停地上：悬浮窗 %s；登记 %s" % [tag, str(vis), _quiet_counts()])
			_lg_mv(root.get_final_transform() * Vector2(800, 120), false)
			_lg_cycle += 1; _lg = 0; _lg_w = 10
			if _lg_cycle >= LG_CYCLES:
				print("E617 长序列 %d 轮走完；悬浮登记 %s" % [LG_CYCLES, _quiet_counts()])
				shot("long_done")
				_lg_on = false; _screen_frames = 0
		20:
			_lg_cycle += 1; _lg = 0
			if _lg_cycle >= LG_CYCLES: _lg_on = false


# ---- v6.17 sM：首次合成提示、布卷压纱布加别的、补衣人、地图教程看全图键、选人栏纸条
var _m_on := false
var _m_st := 0
var _m_w := 0
var _fh_logged := false
var _weaver_logged := false
var _coach_done := false
var _coach_seen := 0
var _m_bolt: ItemInstance = null
var _m_gauze: ItemInstance = null
var _m_fill: ItemInstance = null
var _m_from := Vector2.ZERO
var _m_to := Vector2.ZERO
var _m_k := 0


var _hint_shot_at := -1
var _hint_scr := ""


func _fh_poll(scr: String) -> void:
	if _frames == _hint_shot_at:
		shot("fuse_first_hint_" + _hint_scr)
	if _fh_logged or _flow.run == null or _flow.run.meta == null:
		return
	if _flow.run.meta.flag(&"fuse_hint_shown") == 0:
		return
	_fh_logged = true
	var info := []
	for n in root.find_children("*", "Control", true, false):
		var sc = n.get_script()
		if sc != null and String(sc.resource_path).ends_with("inventory_panel.gd") and (n as Control).is_visible_in_tree():
			var bm := []
			for u in n.board_view.fuse_marks.keys(): bm.append(String(_flow.run.board.get_item(int(u)).def.id) if _flow.run.board.get_item(int(u)) != null else str(u))
			var gm := []
			if n.ground != null:
				for u in n.ground.fuse_marks.keys(): gm.append(String(_flow.run.storage.get_item(int(u)).def.id) if _flow.run.storage.get_item(int(u)) != null else str(u))
			info.append("面板提示「%s」棋盘小锤 %s 地上小锤 %s" % [n.last_hint, str(bm), str(gm)])
	var nl = NoticeLayer.current().lines() if NoticeLayer.current() != null else []
	print("E617 首次合成提示：%s 屏，节点 %s；%s；告示 %s；棋盘 %s；地上 %s" % [scr, str(_flow.run.current_node().id) if _flow.run.current_node() != null else "?", "；".join(info), str(nl), str(_ids(_flow.run.board)), str(_ids(_flow.run.storage))])
	_hint_shot_at = _frames + 10; _hint_scr = scr




func _coach_tick() -> bool:
	if _m_w > 0:
		_m_w -= 1; return true
	for c in root.find_children("*", "CoachOverlay", true, false):
		var co := c as CoachOverlay
		_coach_seen += 1
		print("E617 地图教程第 %d 步：「%s」" % [_coach_seen, co.line_text()])
		shot("map_coach_%d" % _coach_seen)
		co.next(); _m_w = 15
		return true
	if _coach_seen > 0 or _screen_frames > 90:
		_coach_done = true
	return _coach_seen > 0 and not _coach_done


func _m_key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
		Input.parse_input_event(e)


func _m_panel_view() -> Array:
	var p := _lg_panel()
	return [p, p.board_view if p != null else null]


## 棋盘上横着连三格都能放的地方（放布卷试）
func _m_spot(run_: RunState) -> Vector2i:
	var probe := ItemInstance.create(_flow.items.get_def(&"linen_bolt"), 0)
	for y in run_.board.size.y:
		for x in run_.board.size.x:
			if run_.board.place(probe, Vector2i(x, y), 0):
				run_.board.remove(probe.uid)
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _m_tick() -> void:
	_screen_started_msec = Time.get_ticks_msec()
	if _m_w > 0:
		_m_w -= 1; return
	var run_: RunState = _flow.run
	var ms = _map_screen()
	match _m_st:
		0:
			var v = ms.get("_view")
			v.zoom = 2.0
			print("E617 看全图前：缩放 %.2f" % v.zoom)
			_m_key(KEY_F); _m_st = 1; _m_w = 20
		1:
			var v = ms.get("_view")
			print("E617 按 F 后：缩放 %.2f（%s）" % [v.zoom, "变了" if absf(v.zoom - 2.0) > 0.01 else "没变"])
			shot("map_after_f")
			ms.toggle_bag(); _m_st = 2; _m_w = 25
		2:
			var pv := _m_panel_view()
			if pv[0] == null:
				print("E617 !! 背包没开"); _m_st = 99; _m_on = false; return
			# 测试手段：腾出横三格，纱布在左、口粮在中，布卷放地上
			var spot := _m_spot(run_)
			var moved := 0
			while spot.x < 0 and moved < 8:
				var cand: ItemInstance = null
				for it in run_.board.items():
					if not run_.board.acts_as_bag((it as ItemInstance).def): cand = it
				if cand == null: break
				run_.board.remove(cand.uid); run_.storage.insert(cand); moved += 1
				spot = _m_spot(run_)
			if spot.x < 0:
				print("E617 !! 棋盘上找不到横三格"); _m_st = 99; _m_on = false; return
			_m_gauze = ItemInstance.create(_flow.items.get_def(&"bandage"), 0)
			_m_fill = ItemInstance.create(_flow.items.get_def(&"ration"), 0)
			_m_bolt = ItemInstance.create(_flow.items.get_def(&"linen_bolt"), 0)
			var ok := run_.board.place(_m_gauze, spot, 0) and run_.board.place(_m_fill, spot + Vector2i(1, 0), 0) and run_.storage.insert(_m_bolt)
			print("E617 测试手段：纱布放 %s、口粮放 %s、亚麻布卷放地上（挪开 %d 件）：%s" % [str(spot), str(spot + Vector2i(1, 0)), moved, str(ok)])
			_flow._flush()
			_m_st = 3; _m_w = 20
		3:
			var p := _lg_panel()
			var r: Rect2 = p.ground.item_rect(_m_bolt.uid)
			var g: Rect2 = p.ground.get_global_transform() * r
			_m_from = root.get_final_transform() * Vector2(g.position.x + g.size.x / 6.0, g.get_center().y)
			_m_to = _lg_center(p, _m_gauze)
			print("E617 U01 第一次：拿布卷（左格）对准纱布，布卷会压到口粮")
			_lg_mv(_m_from, false); _m_st = 4; _m_w = 3
		4:
			_lg_btn(_m_from, true); _m_k = 0; _m_st = 5; _m_w = 3
		5:
			_m_k += 1; _lg_mv(_m_from.lerp(_m_to, _m_k / 6.0), true); _m_w = 2
			if _m_k >= 6: _m_st = 6; _m_w = 10
		6:
			var p := _lg_panel()
			var dl = p.get("_drag")
			print("E617 U01 停在纱布上：残影旁的字「%s」；预览可放 %s" % [str(dl.drop_hint) if dl != null else "?", str(p.board_view.preview_ok())])
			shot("u01_hover_overlap")
			_lg_btn(_m_to, false); _m_st = 7; _m_w = 15
		7:
			var p := _lg_panel()
			var nl = NoticeLayer.current().lines() if NoticeLayer.current() != null else []
			print("E617 U01 松手：确认窗开 %s；面板提示「%s」；告示 %s；纱布在 %s 口粮在 %s 布卷在地上 %s；手上空 %s" % [str(p.fuse_note != null and p.fuse_note.is_open()), p.last_hint, str(nl), str(_m_gauze.origin) if run_.board.has_item(_m_gauze.uid) else "不在棋盘", str(_m_fill.origin) if run_.board.has_item(_m_fill.uid) else "不在棋盘", str(run_.storage.has_item(_m_bolt.uid)), str(not p.get("_drag").is_dragging())])
			shot("u01_refused")
			# 第二次：把口粮挪到地上，只压纱布
			run_.board.remove(_m_fill.uid); run_.storage.insert(_m_fill); _flow._flush()
			_m_st = 8; _m_w = 20
		8:
			var p := _lg_panel()
			var g: Rect2 = p.ground.get_global_transform() * p.ground.item_rect(_m_bolt.uid)
			_m_from = root.get_final_transform() * Vector2(g.position.x + g.size.x / 6.0, g.get_center().y)
			_m_to = _lg_center(p, _m_gauze)
			print("E617 U01 第二次：口粮挪开，只压纱布")
			_lg_mv(_m_from, false); _m_st = 9; _m_w = 3
		9:
			_lg_btn(_m_from, true); _m_k = 0; _m_st = 10; _m_w = 3
		10:
			_m_k += 1; _lg_mv(_m_from.lerp(_m_to, _m_k / 6.0), true); _m_w = 2
			if _m_k >= 6: _m_st = 11; _m_w = 10
		11:
			var p := _lg_panel()
			print("E617 U01 第二次停在纱布上：残影旁的字「%s」；预览可放 %s" % [str(p.get("_drag").drop_hint), str(p.board_view.preview_ok())])
			_lg_btn(_m_to, false); _m_st = 12; _m_w = 20
		12:
			var p := _lg_panel()
			var open: bool = p.fuse_note != null and p.fuse_note.is_open()
			print("E617 U01 第二次松手：确认窗开 %s" % str(open))
			shot("u01_single_note")
			if open: _lg_click_ctl(p.fuse_note.cancel_key)
			_m_st = 13; _m_w = 15
		13:
			print("E617 U01 取消后：纱布在棋盘 %s，布卷在地上 %s" % [str(run_.board.has_item(_m_gauze.uid)), str(run_.storage.has_item(_m_bolt.uid))])
			_lg_mv(root.get_final_transform() * Vector2(800, 120), false)
			ms.toggle_bag()
			_m_st = 99; _m_on = false; _screen_frames = 0


#region F643 统一教程 F 批真实界面走查：tutA 正常打完三段；tutB 第一段后跳过；tutC 第一段先输一次再重试
var _tm := 0
var _tseg := 0
var _tfailed := false
var _tidle := 0


func _tut_lose() -> bool:
	return MODE == "tutC" and not _tfailed and _flow.run != null and _flow.run.chapter.id == &"prologue"


func _btn_text(text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).is_visible_in_tree() and (n as Button).text.strip_edges() == text: return n
	return null


func _click643(b: Control) -> void:
	var c := root.get_final_transform() * b.get_global_rect().get_center()
	Input.warp_mouse(c)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)


func _eb643() -> Node:
	for n in root.find_children("*", "", true, false):
		if n is ExpeditionBoard and (n as Control).is_visible_in_tree(): return n
	return null


func _lbl643(n: Node) -> String:
	var t := []
	if n == null: return "没有"
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "": t.append((l as Label).text)
	return " / ".join(t)


func _tut_meta() -> void:
	var m := _flow.meta
	var ms = _game.base()
	var gate := _flow.tutorial_gate()
	var eb := _eb643()
	match _tm:
		0:
			if m.runs > 0 and m.deaths > 0 and not _tfailed: _tfailed = true
			print("F643 基地：档案 %s；下一段 %s；钱 %d；仓库 %d 件；待入库 %s；场次 %d 撤离 %d 战败 %d；解锁 %s；看过 %s；做过 %s；账本 %s" % [String(_flow.profile), String(gate.id) if gate != null else "全通", m.funds, m.warehouse.item_count(), str(m.has_pending_board()), m.runs, m.extractions, m.deaths, str(m.unlocks), str(m.coach_seen), str(m.coach_done), str(m.tutorial_ledger)])
			shot("tut_base_%d" % m.runs)
			_tm = 1
		1, 2, 3, 4:
			var tabs := ["warehouse", "logistics", "shelf", "expedition"]
			var tb := _btn_text(UiText.t("meta.tab_" + tabs[_tm - 1]))
			if tb != null: _click643(tb)
			_tm += 1
		5:
			_tidle += 1
			if _tidle < 6: return     # 挂机：停在基地，不该自己开局
			_tidle = 0
			print("F643 切页、挂机后：屏 %s；木牌「%s」" % [GameFlow.Screen.keys()[_flow.screen], _lbl643(eb)])
			shot("tut_board_%d" % m.runs)
			var tryb := eb.find_child("TryTutorial", true, false) if eb != null else null
			print("F644 「%s」键：%s；legacy_tutorial %s" % [UiText.t("meta.tutorial_try"), "有" if tryb != null and (tryb as Control).is_visible_in_tree() else "没有", String(_flow.legacy_tutorial().id) if _flow.legacy_tutorial() != null else "null"])
			if MODE == "tutL":
				if _ltried or tryb == null:
					_report("F643 走完（老档体验）")
					finish(0)
					return
				_ltried = true
				_res_phase = 0
				_after_fight = false
				_loot_frames = 0
				print("F644 真点「%s」" % (tryb as Button).text)
				_click643(tryb)
				_tm = 0
				return
			if gate == null:
				_report("F643 三段都通了")
				finish(0)
				return
			if MODE == "tutB" and gate.id == &"prologue_2":
				_tm = 10
				return
			_tm = 6
		6:
			if eb == null: return
			_res_phase = 0
			_after_fight = false
			_loot_frames = 0
			print("F643 点【%s】开 %s" % [(eb.start_btn as Button).text, String(gate.id)])
			_click643(eb.start_btn)
			_tm = 0
		10:
			var sb := eb.find_child("SkipTutorial", true, false) if eb != null else null
			print("F643 点「%s」：%s；跳过前清单 %s" % [UiText.t("meta.tutorial_skip"), "找到" if sb != null else "没找到", str(_flow.skip_preview().get("funds", -1))])
			if sb != null: _click643(sb)
			_tm = 11
		11:
			shot("tut_skip_confirm")
			var yes := _btn_text(UiText.t("skip_tut.yes"))
			if yes != null: _click643(yes)
			_tm = 12
		12:
			print("F643 跳过后：屏 %s；钱 %d；仓库 %d 件；解锁 %s；木牌「%s」" % [GameFlow.Screen.keys()[_flow.screen], m.funds, m.warehouse.item_count(), str(m.unlocks), _lbl643(eb)])
			shot("tut_after_skip")
			_tm = 13
		13:
			if eb == null: return
			print("F643 点【%s】" % (eb.start_btn as Button).text)
			_click643(eb.start_btn)
			_tm = 14


var _lmenu := false
var _t3_logged := {}
var _fsel := 0


func _fkey(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)


## 信仰重构 A：按 B 开背包 → 右键棋盘上的信物 → 真点钉住悬浮窗里的「奉为主信仰」→ 再按 B 关。返回 true = 还在做
func _faith_ui(r: RunState, id: StringName) -> bool:
	var inst := _find309(r, id)
	match _fsel:
		0:
			print("F645 %s：战斗选项锁着，开背包奉神（选 %s 有效 %s）" % [String(r.events.pending_event().id) if r.events.pending_event() != null else "?", String(r.selected_faith), String(r.active_faith_id())])
			if inst != null and not r.board.has_item(inst.uid): print("F645 信物在地上，先放上棋盘：%s" % str(r.equip(inst.uid)))
			_fkey(KEY_B)
			_fsel = 1
		1:
			var p: Node = null
			for n in root.find_children("*", "", true, false):
				if n.get("board_view") != null and n.has_method("select_faith") and (n as CanvasItem).is_visible_in_tree(): p = n
			if p == null or inst == null or not r.board.has_item(inst.uid):
				print("F645 背包没开 / 信物不在棋盘（面板 %s）" % str(p != null))
				_fsel = 0
				return false
			var v: Control = p.board_view
			var c: Vector2 = root.get_final_transform() * (v.get_global_transform_with_canvas() * (v.item_rect(inst.uid) as Rect2).get_center())
			Input.warp_mouse(c)
			for down in [true, false]:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_RIGHT
				e.pressed = down
				e.position = c
				e.global_position = c
				Input.parse_input_event(e)
			_fsel = 2
		2:
			var b := _btn_text(UiText.t("act.anchor"))
			shot("faith_tip_%s" % String(id))
			print("F645 右键 %s：悬浮窗「%s」%s" % [String(id), UiText.t("act.anchor"), ("找到" + ("（灰）" if b.disabled else "")) if b != null else "没找到"])
			if b != null: _click643(b)
			_fsel = 3
		3:
			print("F645 点完：选 %s；有效 %s；联系 %s" % [String(r.selected_faith), String(r.active_faith_id()), String(r.faith_connection())])
			shot("faith_selected_%s" % String(id))
			_fkey(KEY_B)
			_fsel = 4
		4:
			_fsel = 0
			return false
	return true
var _altar_done := {}


## 教程三的神坛：骰子和护符碎片放上祭品台（真点不了拖放，直接走屏上的 put_on_table）→ 预览 → 献祭
func _altar643(r: RunState) -> void:
	var sc: Node = null
	for n in root.find_children("*", "", true, false):
		if n.has_method("put_on_table") and n.has_method("offer"): sc = n
	if sc == null:
		print("F643 神坛屏没找到")
		return
	var put := []
	for c in [r.board, r.storage]:
		for inst in c.items().duplicate():
			var id := String((inst as ItemInstance).def.id)
			if id in ["bone_dice", "bone_charm_bits"] and sc.put_on_table((inst as ItemInstance).uid): put.append(id)
	if put.is_empty():
		var acts := []
		var first: Button = null
		for b in sc._action_btns:
			acts.append("%s%s" % [(b as Button).text, "（灰：%s）" % (b as Button).tooltip_text.get_slice("\n", 0) if (b as Button).disabled else ""])
			if first == null and not (b as Button).disabled: first = b
		print("F643 神坛：信仰 %s 阶 %d；没有祭品；特殊操作 %s" % [String(r.active_faith().id) if r.active_faith() != null else "无", r.active_faith_tier(), str(acts)])
		shot("altar_actions")
		if first != null:
			print("F643 真点特殊操作「%s」" % first.text)
			_click643(first)
		return
	var pv: Dictionary = sc.preview()
	print("F643 神坛：信仰 %s 阶 %d；放上 %s；预览 %s；字「%s」" % [String(r.active_faith().id) if r.active_faith() != null else "无", r.active_faith_tier(), str(put), str(pv), sc.head_text() if sc.has_method("head_text") else ""])
	shot("altar_table")
	var got: Dictionary = sc.offer()
	print("F643 献祭：%s；现在 %d 阶，信力 %d" % [str(got.get("log", got)), r.active_faith_tier(), r.faith_power.points_of(r.active_faith().id) if r.active_faith() != null else -1])
	shot("altar_offered")
var _ltried := false
var _pm := 0
var _cancelled := false
var _esc_again := false
var _no_pos := Rect2()


func _esc643() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)


## tutP：第二段一进地图就按 Esc → 暂停菜单「跳过剩余教程」→ 先【接着学】看取消不动 → 再点一次 →【跳过】
func _pause643(r: RunState) -> bool:
	if r == null or r.chapter == null or r.chapter.id != &"prologue_2" or _pm == 6:
		return false
	var ms = _game.base() if _game.base() != null and _game.base().has_method("show_skip_tutorial") else _game.overlay()
	var m := _flow.meta
	match _pm:
		0:
			print("F644 第二段地图：按 Esc；能跳 %s；钱 %d；场次 %d" % [str(ms.can_skip_tutorial()) if ms != null else "?", m.funds, m.runs])
			_esc643()
			_pm = 1
		1, 3:
			shot("pause_menu_%d" % _pm)
			var kb := _btn_text(UiText.t("map.pause_skip_tutorial"))
			print("F644 暂停菜单「%s」：%s" % [UiText.t("map.pause_skip_tutorial"), "找到，真点" if kb != null else "没找到"])
			if kb != null: _click643(kb)
			elif _pm == 3 and not _esc_again:
				_esc_again = true
				print("F644 暂停菜单已经关了，再按一次 Esc")
				_esc643()
				return true
			else:
				_report("F644 暂停菜单没有跳过键")
				finish(1)
				return true
			_pm += 1
		2:
			shot("pause_skip_confirm")
			print("F644 确认页：开着 %s；文字「%s」" % [str(ms.skip_tutorial_open()), _lbl643(ms._skip) if ms._skip != null else ""])
			var no := _btn_text(UiText.t("skip_tut.no"))
			if _cancelled:
				_pm = 4
				return true
			_cancelled = true
			if no != null:
				_no_pos = no.get_global_rect()
				_click643(no)
			print("F644 点【%s】" % UiText.t("skip_tut.no"))
			_pm = 21
		21:
			print("F644 取消后：节点 %s；" % str(r.current_node().id) + "；确认页开着 %s；屏 %s；钱 %d；场次 %d" % [str(ms.skip_tutorial_open()), GameFlow.Screen.keys()[_flow.screen], m.funds, m.runs])
			_pm = 3
		4:
			var yes := _btn_text(UiText.t("skip_tut.yes"))
			print("F644 点【%s】%s" % [UiText.t("skip_tut.yes"), "找到" if yes != null else "没找到"])
			if yes != null: _click643(yes)
			_pm = 5
		5:
			print("F644 跳过后：屏 %s；钱 %d；场次 %d 撤离 %d 战败 %d；仓库 %d 件；下一段 %s；解锁 %s；账本 %s" % [GameFlow.Screen.keys()[_flow.screen], m.funds, m.runs, m.extractions, m.deaths, m.warehouse.item_count(), String(_flow.tutorial_gate().id) if _flow.tutorial_gate() != null else "全通", str(m.unlocks), str(m.tutorial_ledger)])
			_pm = 6
	return true
#endregion

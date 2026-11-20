extends SceneTree
## 游戏测试 v6.62（报告 340 / 339 第四节）：战斗伤害跳字。xvfb + opengl3 有窗口渲染，着色器出画面。参数：<outdir>
## 开局直进常规图 → 走到第一场战斗 → 战斗屏里：
##   A 倍速时长：真点倍速键到 1 / 2 / 4 倍，各飘一个伤害数和一个反应名，量从出现到消失的毫秒
##   B 暂停：飘一个字后真点暂停键，量 30 帧内位置变没变；再点继续，看接着飘
##   C 八种伤害 + 治疗：飘字摆成一排、停住、截图
##   D 火属性暴击：颜色、字号、描边、放大
##   E 十种反应：反应名 + 反应伤害数（两色渐变）摆成两列、停住、截图；再摆一个普通伤害对照（不挂渐变）
var out := ""
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _steps := 0
var bv: BattleView = null
var _lab: Label = null
var _t0 := 0
var _sp_i := 0
var _times := []
var _y0 := 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("P662 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/%02d_%s.png" % [out, _shots, n])


func _mouse_at(p_canvas: Vector2, button: int) -> void:
	var c := root.get_final_transform() * p_canvas
	Input.warp_mouse(c)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)


func _click(b: Control) -> void:
	_mouse_at(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)


func _ms() -> Node:
	return _game.base()


func _push() -> void:
	var scr := _flow.screen
	var r := _flow.run
	match scr:
		GameFlow.Screen.EVENT:
			if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
			elif r.events.pending_event() == null: _flow.resume()
			else:
				var ev: EventDef = r.events.pending_event()
				var ctx = r.events._event_ctx(r.events.pending_node())
				var pick := 0
				for i in ev.options.size():
					if (ev.options[i] as EventOption).locked_reason(ctx) == "": pick = i; break
				_flow.choose_event(pick)
		GameFlow.Screen.SEARCH: _flow.close_search()
		GameFlow.Screen.LOOT: _flow.take_all_loot(); _flow.resume()
		GameFlow.Screen.ALTAR: _flow.close_altar()
		GameFlow.Screen.RANSOM: _flow.refuse_ransom()
		GameFlow.Screen.PREBATTLE:
			var pre = _game.overlay()
			if pre != null and pre.has_method("start_battle"): pre.start_battle()
			else: _flow.start_battle()
		_: _flow.resume()


func _enemy_panel() -> CombatantPanel:
	return bv._panels[1] if bv._panels.size() > 1 else bv._panels[0]


func _clear(p: CombatantPanel) -> void:
	for c in p.get_children():
		if c is Label and c.has_meta(&"tween"): c.queue_free()


## 摆好、停住
func _place(l: Label, pos: Vector2) -> void:
	var tw = l.get_meta(&"tween")
	if tw is Tween: (tw as Tween).pause()
	l.position = pos
	l.modulate.a = 1.0


func _desc(l: Label) -> String:
	var ls := l.label_settings
	var mat := l.material as ShaderMaterial
	var g := ""
	if mat != null:
		g = "；渐变 %s→%s" % [str(mat.get_shader_parameter("color_a")), str(mat.get_shader_parameter("color_b"))]
		if g.contains("<null>"):
			var ps := []
			for pr in mat.shader.get_shader_uniform_list(): ps.append("%s=%s" % [pr["name"], str(mat.get_shader_parameter(pr["name"]))])
			g = "；渐变 " + ", ".join(ps)
	return "「%s」字号 %d 字色 #%s 描边 %d%s" % [l.text, ls.font_size, ls.font_color.to_html(false), ls.outline_size, g]


var _acc := 0.0
var _frames := 0
var _maxs := 1.0
func _process(_d: float) -> bool:
	_f += 1
	_acc += _d; _frames += 1
	if _lab != null and is_instance_valid(_lab): _maxs = maxf(_maxs, _lab.scale.x)
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 20000:
		L("超时 st %d" % _st); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial(); _wait = 30; _st = 2
			elif _f > 240:
				_flow.decline_tutorial(); _wait = 30; _st = 2
		2:
			var ch: ChapterDef = null
			for c in _flow.available_chapters():
				if not (c as ChapterDef).id.begins_with("prologue"): ch = c; break
			_flow.begin_direct(ch, 780613); _st = 3
		3:
			if scr == GameFlow.Screen.BATTLE:
				var bs = _game.overlay()
				if bs != null and bs.has_method("view") and bs.view() != null:
					bv = bs.view()
					L("进战斗：面板 %d 个；倍速 %s" % [bv._panels.size(), str(bv.speed())])
					_wait = 60; _st = 10
				return false
			if scr != GameFlow.Screen.MAP: _push(); _wait = 10; return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			var r := _flow.run
			if r.phase == RunState.Phase.PICK_SPAWN:
				_ms().pick_spawn(r.map.entry_ids[0]); _wait = 20; return false
			if r.board.items().size() < 4:
				for id in [&"knife", &"round_shield", &"bone_greatsword"]:
					var d := _flow.items.get_def(id)
					if d != null: r.board.try_add(ItemInstance.create(d, 0))
				_flow._flush()
			_steps += 1
			if _steps > 60: L("走不到战斗"); quit(1); return true
			var best := -1
			for n in r.travel.available_moves():
				var nd := r.map.get_node(n)
				if nd != null and nd.type == &"battle" and not nd.is_visited(): best = n
			if best < 0:
				for n in r.travel.available_moves():
					var nd := r.map.get_node(n)
					if nd != null and not nd.is_visited() and nd.type != &"elite" and nd.type != &"core": best = n; break
			if best < 0: best = r.travel.available_moves()[0]
			_flow.step_to(best); _wait = 15
		# ---- A 倍速时长 ----
		10:
			if bv.is_playing(): bv.toggle_play()
			_wait = 10; _st = 11
		11:
			var want: float = [1.0, 2.0, 4.0][_sp_i]
			if bv.speed() != want:
				_click(bv._speed_btn); _wait = 10
				if _f % 100 == 0: L("（倍速键：现在 %s，要 %s）" % [str(bv.speed()), str(want)])
				return false
			L("真点倍速键 → %s 倍；飘字系数 %.3f；回放停着 %s" % [str(bv.speed()), bv._popup_scale(), str(not bv.is_playing())])
			var p := _enemy_panel()
			p.pause_popups(false)
			_lab = p.popup(12, &"physical", false, false, bv._popup_scale())
			_t0 = Time.get_ticks_msec(); _acc = 0.0; _frames = 0; _st = 12
		12:
			if is_instance_valid(_lab) and not _lab.is_queued_for_deletion(): return false
			var ms := Time.get_ticks_msec() - _t0
			_times.append("游戏时间 %.2f 秒（%d 帧，墙钟 %d 毫秒）" % [_acc, _frames, ms])
			var p := _enemy_panel()
			_lab = p.popup_text("测试", Color.WHITE, bv._popup_scale())
			_t0 = Time.get_ticks_msec(); _acc = 0.0; _frames = 0
			_st = 13
		13:
			if is_instance_valid(_lab) and not _lab.is_queued_for_deletion(): return false
			var ms := Time.get_ticks_msec() - _t0
			L("　　%s 倍：伤害数 %s；反应名 游戏时间 %.2f 秒（%d 帧，墙钟 %d 毫秒）" % [str(bv.speed()), _times[-1], _acc, _frames, ms])
			_sp_i += 1
			_st = 11 if _sp_i < 3 else 20
			if _st == 20: _click(bv._speed_btn)     # 4 → 1
			_wait = 5
		# ---- B 暂停 ----
		20:
			if bv.speed() != 1.0: _click(bv._speed_btn); _wait = 10; return false
			if not bv.is_playing(): bv.toggle_play()
			_wait = 2; _st = 21
		21:
			var p := _enemy_panel()
			_lab = p.popup(15, &"fire", false, false, bv._popup_scale())
			_wait = 2; _st = 22
		22:
			_click(bv._play_btn)     # 真点暂停
			_wait = 3; _st = 23
		23:
			if not is_instance_valid(_lab): L("暂停前字已经没了"); _st = 30; return false
			_y0 = _lab.position.y
			L("真点暂停：回放在放 %s；面板飘字停着 %s；字 y=%.1f 透明 %.2f" % [str(bv.is_playing()), str(_enemy_panel().popups_paused()), _y0, _lab.modulate.a])
			_wait = 30; _st = 24
		24:
			L("　　30 帧后：y=%.1f（变了 %.1f）透明 %.2f" % [_lab.position.y, _lab.position.y - _y0, _lab.modulate.a])
			shot("paused_popup")
			_click(bv._play_btn)     # 真点继续
			_wait = 1; _st = 25
		25:
			L("真点继续（1 帧后）：回放在放 %s；飘字停着 %s；字 %s" % [str(bv.is_playing()), str(_enemy_panel().popups_paused()), ("y=%.1f（又动了 %.1f）" % [_lab.position.y, _lab.position.y - _y0]) if is_instance_valid(_lab) else "已飘完"])
			if bv.is_playing(): bv.toggle_play()
			_wait = 60; _st = 30
		# ---- C 八种伤害 + 治疗 ----
		30:
			var p := _enemy_panel()
			p.pause_popups(false)
			_clear(p)
			L("敌方面板 %s 大小 %s" % [str(p.get_global_rect().position), str(p.size)])
			var types := ["physical", "fire", "poison", "bleed", "reflect", "drain", "ice", "lightning"]
			for i in types.size():
				var l := p.popup(18 + i, StringName(types[i]), false, false, 1.0)
				_place(l, Vector2(20 + (i % 3) * 90, 30 + (i / 3) * 40))
				L("　　%s：%s" % [types[i], _desc(l)])
			var h := p.popup(12, &"physical", true, false, 1.0)
			_place(h, Vector2(20 + 2 * 90, 30 + 2 * 40))
			L("　　治疗：%s" % _desc(h))
			_wait = 3; _st = 31
		31:
			shot("types")
			var p := _enemy_panel()
			_clear(p)
			var c := p.popup(34, &"fire", false, true, 1.0)
			var n := p.popup(34, &"fire", false, false, 1.0)
			_place(n, Vector2(20, 40))
			c.position = Vector2(120, 40)
			L("暴击：%s；普通对照：%s" % [_desc(c), _desc(n)])
			_lab = c; _maxs = 1.0; _wait = 1; _st = 32
		32:
			shot("crit_punch")
			_wait = 20; _st = 35
		35:
			L("　　暴击飘字期间最大缩放 %.2f（字还在 %s）" % [_maxs, str(is_instance_valid(_lab))])
			_lab = null
			var p := _enemy_panel()
			_clear(p)
			var c := p.popup(34, &"fire", false, true, 1.0)
			_place(c, Vector2(120, 40)); c.scale = Vector2.ONE
			var n := p.popup(34, &"fire", false, false, 1.0)
			_place(n, Vector2(20, 40))
			_wait = 3; _st = 33
		33:
			shot("crit")
			var p := _enemy_panel()
			_clear(p)
			var all := ReactionResolver.all()
			L("反应 %d 种" % all.size())
			var row := 0
			for d in all:
				var cols: Array[Color] = []
				for el in d.elements: cols.append(UiPalette.damage_color(StringName(String(el))))
				var nm := p.popup_text(Names.of(d), cols[0] if not cols.is_empty() else Color.WHITE, 1.0, cols)
				var x := 10.0 + (row % 2) * 260.0
				var y := -40.0 + (row / 2) * 52.0
				_place(nm, Vector2(x, y))
				var dmg := p.popup(40 + row, StringName(String(d.elements[0])) if not d.elements.is_empty() else &"physical", false, false, 1.0, cols)
				_place(dmg, Vector2(x + nm.size.x + 12, y + 6))
				L("　　%s（%s）：名 %s；伤害 %s" % [String(d.id), str(d.elements), _desc(nm), _desc(dmg)])
				row += 1
			var plain := p.popup(21, &"fire", false, false, 1.0)
			_place(plain, Vector2(10, -40 + ((row + 1) / 2) * 52.0))
			L("　　普通伤害对照：%s" % _desc(plain))
			_wait = 3; _st = 34
		34:
			shot("reactions")
			L("走查完")
			quit(0); return true
	return false

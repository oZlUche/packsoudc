## 战斗回放（M6，架构文档 4.8 / 8 节）：叠在地图上。战斗在踩上去那一瞬就算完了，这里只是照日志重演。
## 玩家能做的只有看、倍速、跳过，然后「继续」。日志里只有 uid，名字从双方的战斗单位查（`NodeEvents.last_battle`）。
extends GameScreen

var _view: BattleView
## 作者 2026-10-21 定（战旗 / 纸卷）：「继续」是一条纸卷，回放看完（或拖到头）才出现；回放中这里空着。没看完前是 null
var _next: Button = null
## 纸卷放的那一格（教程「next_button」指它：回放中空着，看完纸卷落在这里）。
## 231：格子比旗矮（[constant SLOT_HEIGHT]），里面的铜章 / 继续旗不进排版、居中摆、上下伸出格子（面板要放进 1000 高）
var _next_slot: Control
const CONTINUE_ART := "res://assets/ui/battle/"
## 回放看完（或跳到底）了没有（作者 2026-10-17：标题不再写胜负，按状态判断）
var _seen_end := false
var _won: bool = false
## 166 补充二：战斗教程（章节 `coaches` 的 `battle`），开着时回放停着
var _coach: CoachOverlay = null
## 220：这一场头一回打出的反应（流程给的）；回放放到第一次弹字时停下解释一句，解释过的划掉
var _fresh_reactions: Array[StringName] = []
## 铜面板：斗技场图从面板内缩（40）处铺起；场地宽
const PANEL_MARGIN := 40
const VIEW_WIDTH := 1100.0
## 继续旗的可点区（同战前「开战」旗）
const FLAG_HIT := Rect2(22, 10, 156, 108)
## 纸卷「继续」的大小（没有图时也按它留位）
const SCROLL_SIZE := Vector2(246, 94)
## 231：双剑铜章（回放中在「继续」那一格里随出手对攻，看完分胜负、让位给继续旗）
var _medal: DuelMedal = null
var _result: BattleResult = null
## 231：动效开着没有（设置 ui_fades、测试开关）
var _motion := false
## 231：开战过场还在演（演完才放回放、才放教程）
var _intro_running := false
## 231：开战过场里还垫在底下的战前屏（演完释放）
var _outgoing: Control = null
## 231 §2.1 开战过场的分镜（秒，一倍速，从按下「开战」算）
const INTRO_OUT := 0.2          # 战前屏：旗收、两列淡掉
const INTRO_ARENA := 0.6        # 框里的斗技场淡进
const INTRO_FRAME := 0.4        # 铜框从战前那块的大小缩到自己的
const INTRO_MEDAL_AT := 0.3     # 铜章开始下移
const INTRO_MEDAL := 0.6
const INTRO_CONTENT_AT := 0.8   # 名牌、条、棋盘淡进
const INTRO_CONTENT := 0.25
## 终局：剑分胜负之后多久继续旗开始展开、铜章淡出多久
const FLAG_AFTER := 0.4
const MEDAL_OUT := 0.25
## 231：「继续」那一格的高（旗 134、铜章 132 上下伸出去；往下多伸一点 —— 旗底有 8 px 留白）。235 补：顶端栏 86 → 100，格子 102 → 88，面板仍放得进 1000 高
const SLOT_HEIGHT := 88.0
const SLOT_DROP := 4.0
## 美术设计 v4.17 补：顶端栏加高后「继续」旗尾尖压进面板内沿；整组旗（旗杆连旗）往上挪到尾尖离内沿 8 px，铜章不动
const FLAG_RAISE := 18.0


func open(payload: Dictionary) -> void:
	# 铜面板三屏（UI替换美术 bronze3，作者 2026-10-21 16:15）：铜面板，斗技场图铺满面板里面；高按内容（103 第 7 条：放得下双方棋盘）
	var panel := _bronze_panel(Vector2(0, 0), PANEL_MARGIN)
	var col := _vbox(8)
	panel.add_child(col)
	var node: MapNode = payload.get("node", null)
	var result: BattleResult = payload.get("result", null)
	_result = result
	_motion = UiMotion.enabled(flow.settings)
	_won = bool(payload.get("won", false))
	for id in payload.get("new_reactions", []):
		_fresh_reactions.append(StringName(String(id)))
	var enemy_name := _enemy_name(payload.get("enemy_content", {}))
	# 作者 2026-10-17：顶端的「战斗　X —— 赢了」和计时行都不给玩家看（胜负看地图日志与结算屏）；看完没看完记在 _seen_end

	_view = BattleView.new()
	_view.bronze = true
	_view.label_font = font
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(VIEW_WIDTH, 0)
	col.add_child(_view)
	_view.set_header_visible(false)
	_view.finished.connect(_on_finished)
	# 109（作者定）：倍速跨局继承 —— 开场按设置里的，切了就写回去
	if flow.settings != null:
		_view.set_speed(flow.settings.battle_speed)
	_view.speed_changed.connect(_on_speed_changed)
	_view.reaction_shown.connect(_on_reaction_shown)

	_next_slot = Control.new()
	_next_slot.custom_minimum_size = Vector2(_continue_size(_won).x, minf(SLOT_HEIGHT, _continue_size(_won).y))     # 先按图留好位置，看完才放按钮（面板不跳）
	_next_slot.resized.connect(_center_slot)
	_view.add_footer(_next_slot)     # UI替换美术 18:16：「继续」纸卷压在场地上，场地图铺满面板里面（没有和铜面的硬边）
	_view.add_coach_target(&"next_button", _next_slot)
	_medal = DuelMedal.new()
	_medal.rate = _view.speed()
	_next_slot.add_child(_medal)
	_view.event_applied.connect(_on_event)
	# 作者 10-22：开打前两把剑先拉开 —— 有开战过场就等它演完再拉（_end_intro），没有就开场拉
	if _motion:
		_spread_unless_intro.call_deferred()
	else:
		_medal.spread(false)

	if result != null:
		_view.play(result, [UiText.t("battle.me"), enemy_name])
		# 157：名牌和战前准备屏同一份控件、同一个位置（面板顶上）
		_view.set_nameplate(0, _player_plate(Nameplate.COMPACT_PORTRAIT))
		_view.set_nameplate(1, _enemy_plate(payload.get("enemy_content", {}), Nameplate.COMPACT_PORTRAIT))
		_view.set_item_names(0, CombatantSpec.item_names(payload.get("player", null), flow.items))
		_view.set_item_names(1, CombatantSpec.item_names(payload.get("enemy", null), flow.items))
		# 087 / 103：双方上过身的 buff（图标 + 悬浮说明）在 result.buffs 里，play 已经接上
		# 103 第 7 条：双方棋盘 + 冷却遮罩（编译时的那张棋盘，uid 和日志一致）
		for side in 2:
			var spec: CombatantSpec = payload.get("player" if side == 0 else "enemy", null)
			if spec != null and spec.board != null:
				_view.set_board(side, spec.board)
	_fit_duel_panel()     # 作者 10-21：和战前那块一样大
	if coach_due():
		_view.hold()     # 166 补充二：教程要放 —— 一开场就停住，一帧都不偷跑
		_maybe_coach.call_deferred()


## 「继续」用哪张图（作者 19:09：沿用战前的旗 —— 赢了一面完整的红旗 `continue_win`，输了一面破口的旧旗 `continue_lose`）；
## 旗图还没到时用原来的纸卷 `continue`。英文有 `_en` 版就换
static func continue_art(won: bool) -> String:
	var flag := "continue_win" if won else "continue_lose"
	var name := flag if ResourceLoader.exists(CONTINUE_ART + flag + ".png") else "continue"
	if UiText.lang != "zh" and ResourceLoader.exists(CONTINUE_ART + name + "_en.png"):
		name += "_en"
	return name


static func _continue_size(won: bool) -> Vector2:
	var path := CONTINUE_ART + continue_art(won) + ".png"
	var tex := EventImage.load_texture(path) if ResourceLoader.exists(path) else null
	return tex.get_size() if tex != null else SCROLL_SIZE


## 看完了（或不想看了）：回到流程
func proceed() -> void:
	HudHost.release_in(get_tree())     # 231 补充二：兜底（没看完就走了）
	flow.resume()


func _on_finished() -> void:
	HudHost.release_in(get_tree())     # 231 补充二：回放看完（或跳到底）顶栏才变，和「继续」旗同一刻
	if _next == null and _next_slot != null:
		var art := continue_art(_won)
		_next = IconButton.make_art(CONTINUE_ART, art, UiText.t("battle.continue"), "", proceed)
		_next.hit_rect = FLAG_HIT if _next.has_art() and art.begins_with("continue_") and not art.begins_with("continue_en") else Rect2()     # 旗：挂绳与旗尾点不着
		_next_slot.add_child(_next)
		_center_slot()
		_settle_medal()
	_seen_end = true     # 157：拖时间轴拖到头会再「看完」一次


## 231：格子里的东西（铜章、继续旗）按自己的大小居中摆、略往下
func _center_slot() -> void:
	for c in _next_slot.get_children():
		if c is Control:
			(c as Control).position = _slot_spot(c)


func _slot_spot(c: Control) -> Vector2:
	var sz := c.get_combined_minimum_size().max(c.size)
	var drop := SLOT_DROP - (FLAG_RAISE if c == _next else 0.0)
	return ((_next_slot.size - sz) * 0.5 + Vector2(0, drop)).floor()


## 231：看完了 —— 铜章里输的剑垂下、赢的剑举起（一倍速 0.4 s），再淡掉，继续旗在同一格展开；跳过 / 拖到头 / 动效关着直接终态
func _settle_medal() -> void:
	var winner := -1 if _result == null or _result.is_draw() else _result.winner
	var animate := _motion and not _view.ended_by_jump and _medal != null and _medal.is_visible_in_tree()
	if _medal != null:
		_medal.set_final(winner, animate)
	if not animate:
		if _medal != null:
			_medal.visible = false
		return
	UiMotion.furl(_next, false)     # 先藏着（裁到 0），点不着
	_next.disabled = true
	var tw := create_tween()
	tw.tween_interval(FLAG_AFTER)
	tw.tween_callback(func():
		_next.disabled = false
		UiMotion.unfurl(_next, true))
	tw.tween_property(_medal, "modulate:a", 0.0, MEDAL_OUT)
	tw.tween_callback(func(): _medal.visible = false)


## 231：回放里一条事件播到了 —— 铜章跟着：出手那方的剑劈一下、挨打那方的剑后仰（大伤迸火星）、反应晕一圈
func _on_event(e: BattleEvent) -> void:
	if _medal == null or not _motion:
		return
	match e.name:
		BattleEvent.ITEM_FIRED:
			_medal.strike(e.side)
		BattleEvent.DAMAGE:
			var amount := StatMath.to_int(e.get_int(&"amount"))
			if amount > 0 and _view.panel(e.side) != null:
				var top := _view.panel(e.side).resource_max("hp")
				_medal.hit(e.side, top > 0 and amount >= top * 0.15)
		BattleEvent.EFFECT_RESOLVED:
			if String(e.payload.get("effect", "")) == ReactionResolver.EFFECT:
				_medal.react(BattleView.reaction_color(e))


## 铜章（测试看）
func _spread_unless_intro() -> void:
	if _medal != null and not _intro_running:
		_medal.spread(true)


func medal() -> DuelMedal:
	return _medal


func intro_running() -> bool:
	return _intro_running


## 231 §2.1 开战一镜到底（导演在战前 → 战斗换屏、动效开着时调；战前屏还垫在底下）：
## 0–0.2 战前屏旗收、两列淡掉 → 0.2 整块换成本屏（铜框先是战前那块的大小，0.4 s 缩到自己的），0.2–0.8 框里斗技场淡进 → 0.3–0.9 铜章从战前中缝正中下移到「继续」那一格 →
## 0.8–1.05 名牌、条、棋盘淡进 → 回放开始。全程不碰回放的结果与时序（回放 hold 着，演完 release）
func intro_from(prev: Control) -> void:
	_outgoing = prev
	_intro_running = true
	var pf = prev.call("overlay_frame") if prev.has_method("overlay_frame") else null
	_fit_duel_panel(pf as Control)     # 两块铜框撑齐：过场里不用缩放
	_view.hold()
	var from := Rect2()
	if prev.has_method("outro"):
		from = prev.call("outro", true, INTRO_OUT)
	# 战前屏的两列先淡掉（铜框留着、是实的）；本屏先藏着，0.2 s 时整块换上来：
	# 铜框先撑成战前那块的大小（看不出换了），再缩到自己的大小；框里的斗技场从素铜面上淡出来（复测 v3.84：框不透明、不跳尺寸）
	_hide_parts(true)
	var swap := create_tween()
	swap.tween_interval(INTRO_OUT)
	swap.tween_callback(_swap_in.bind(prev))
	_view.modulate.a = 0.0
	create_tween().tween_property(_view, "modulate:a", 1.0, INTRO_ARENA).set_delay(INTRO_OUT)
	for c in _view.content().get_children():
		if c is CanvasItem and not (c as Node).is_ancestor_of(_next_slot) and c != _next_slot:
			(c as CanvasItem).modulate.a = 0.0
			create_tween().tween_property(c, "modulate:a", 1.0, INTRO_CONTENT).set_delay(INTRO_CONTENT_AT)
	# 铜章：先摘出来挂在本屏上（不跟着面板一起透明），从战前的位置飞到格子正中，再放回格子
	if from.size != Vector2.ZERO and _medal != null:
		_next_slot.remove_child(_medal)
		add_child(_medal)     # 本屏铺满全屏，放最上面；位置按屏幕坐标给
		_medal.global_position = from.position
		var fly := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		fly.tween_interval(INTRO_MEDAL_AT)
		fly.tween_method(_fly_medal.bind(from.position), 0.0, 1.0, INTRO_MEDAL)
		fly.tween_callback(_land_medal)
	var done := create_tween()
	done.tween_interval(INTRO_CONTENT_AT + INTRO_CONTENT)
	done.tween_callback(_end_intro)


## 本屏除了铜章的东西（压暗底、铜框）藏着 / 亮出来（铜章一直亮着：它就是战前中缝那一枚）
func _hide_parts(hide: bool) -> void:
	for c in get_children():
		if c is CanvasItem and c != _medal:
			(c as CanvasItem).modulate.a = 0.0 if hide else 1.0


## 0.2 s：战前屏藏掉、本屏亮出来；铜框从战前那块的大小缩到自己的（绕中心，[constant INTRO_FRAME] 秒）
func _swap_in(prev: Control) -> void:
	var from_size := Vector2.ZERO
	if is_instance_valid(prev):
		var pf = prev.call("overlay_frame") if prev.has_method("overlay_frame") else null
		if pf is Control:
			from_size = (pf as Control).size
		prev.visible = false
	_hide_parts(false)
	var frame := overlay_frame()
	if frame == null or from_size == Vector2.ZERO or frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return
	frame.pivot_offset = frame.size * 0.5
	frame.scale = from_size / frame.size
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).tween_property(frame, "scale", Vector2.ONE, INTRO_FRAME)


## 铜章飞到一半：目标每一步重算（排版可能还在变）
func _fly_medal(t: float, start: Vector2) -> void:
	_medal.global_position = start.lerp(_next_slot.global_position + _slot_spot(_medal), t)


func _land_medal() -> void:
	if _medal == null or _medal.get_parent() == _next_slot:
		return
	remove_child(_medal)
	_next_slot.add_child(_medal)
	_next_slot.move_child(_medal, 0)
	_center_slot()


func _end_intro() -> void:
	if not _intro_running:
		return
	_intro_running = false
	_land_medal()
	if _medal != null:
		_medal.spread(true)     # 作者 10-22：开打前两把剑先拉开
	if _outgoing != null and is_instance_valid(_outgoing):
		_outgoing.queue_free()
	_outgoing = null
	if _coach != null:
		return
	if coach_due():
		show_coach()     # 166 补充二：教程接着停住回放，一帧都不偷跑
	else:
		_view.release()


func _exit_tree() -> void:
	if _outgoing != null and is_instance_valid(_outgoing):
		_outgoing.queue_free()     # 过场没演完就被换走了：垫着的战前屏也一起走
	_outgoing = null
	UiTheme.release_art(UiTheme.ART_BATTLE_BG)     # 236 第五项：启动预热读进来的斗技场底图，打完放掉（下一场再读）


## 回放看完（或跳到底）了没有 —— 084：胜负（只给调试看的那一行）此后才写
func verdict_shown() -> bool:
	return _seen_end


#region 166 补充二：战斗教程
## 这一章的战斗教程 id（没有 = 空）
func coach_id() -> StringName:
	return flow.run.chapter.coach_for(&"battle") if flow.run != null and flow.run.chapter != null else &""


## 这一场该不该放：章节写了、这个存档位没看过
func coach_due() -> bool:
	var id := coach_id()
	if id == &"" or CoachOverlay.load_steps(id).is_empty():
		return false
	return flow.meta == null or not flow.meta.coach_seen.has(String(id))


## 叠层淡入（157）完了再放；还在淡就稍后再看
func _maybe_coach() -> void:
	if _coach != null or not is_inside_tree():
		return
	if modulate.a < 1.0 or _intro_running:     # 231：开战过场演完再放
		get_tree().create_timer(0.05).timeout.connect(_maybe_coach)
		return
	show_coach()


func show_coach() -> bool:
	var steps := CoachOverlay.load_steps(coach_id())
	if steps.is_empty() or _coach != null:
		_view.release()
		return false
	_view.hold()
	_coach = CoachOverlay.new()
	_coach.font = font
	_coach.target_rect = _view.control_rect
	add_child(_coach)
	_coach.finished.connect(_on_coach_finished)
	_coach.start(steps)
	return true


func _on_coach_finished() -> void:
	_coach = null
	_view.release()
	var id := String(coach_id())
	if flow.meta != null and not flow.meta.coach_seen.has(id):
		flow.meta.coach_seen.append(id)
		flow.save_meta()


func coach() -> CoachOverlay:
	return _coach


## 220：回放弹了一次反应字 —— 这一场头一回见的就停住，一步纸条指着挨反应那一方的状态行，点了接着放
func _on_reaction_shown(id: StringName, side: int) -> void:
	if not _fresh_reactions.has(id) or _coach != null:
		return
	var def := ReactionResolver.by_id(id)
	if def == null:
		return
	_fresh_reactions.erase(id)
	_view.hold()
	_coach = CoachOverlay.new()
	_coach.font = font
	_coach.target_rect = _view.control_rect
	add_child(_coach)
	_coach.finished.connect(func():
		_coach = null
		_view.release())
	_coach.start([{"target": "buffs_mine" if side == 0 else "buffs_enemy", "text": Encyclopedia.reaction_intro(def)}])


func view() -> BattleView:
	return _view
#endregion


## 109：玩家在回放里切了倍速 → 记进设置并存盘（和「拿走最后一件自动关闭」同一个写法）
func _on_speed_changed(speed: float) -> void:
	if _medal != null:
		_medal.rate = speed     # 231：铜章的动作跟着倍速
	if flow.settings == null:
		return
	flow.settings.battle_speed = speed
	flow.save_settings()

## 战斗回放（M6，架构文档 4.8 / 8 节）：叠在地图上。战斗在踩上去那一瞬就算完了，这里只是照日志重演。
## 玩家能做的只有看、倍速、跳过，然后「继续」。日志里只有 uid，名字从双方的战斗单位查（`NodeEvents.last_battle`）。
extends GameScreen

var _view: BattleView
var _next: Button
var _title: Label
var _verdict: String = ""
var _won: bool = false
## 166 补充二：战斗教程（章节的 `coach_battle`），开着时回放停着
var _coach: CoachOverlay = null


func open(payload: Dictionary) -> void:
	var panel := _centered_panel(Vector2(1200, 900))     # 103 第 7 条：要放下双方棋盘
	var col := _vbox(8)
	panel.add_child(col)
	var node: MapNode = payload.get("node", null)
	var result: BattleResult = payload.get("result", null)
	_won = bool(payload.get("won", false))
	var enemy_name := _enemy_name(payload.get("enemy_content", {}))
	# 084（作者定）：不提前显示胜负，看完回放（或跳过）才写
	_title = _frame_title("战斗　%s" % enemy_name)     # 157：标题在石板框的标题条上
	_verdict = "赢了" if _won else ("平局，按输算" if result != null and result.is_draw() else "输了")

	_view = BattleView.new()
	_view.label_font = font
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(1160, 780)
	col.add_child(_view)
	_view.finished.connect(_on_finished)
	# 109（作者定）：倍速跨局继承 —— 开场按设置里的，切了就写回去
	if flow.settings != null:
		_view.set_speed(flow.settings.battle_speed)
	_view.speed_changed.connect(_on_speed_changed)

	_next = _button("跳过并继续", proceed, 14, UiPalette.Tier.PRIMARY)
	col.add_child(_next)
	_view.add_coach_target(&"next_button", _next)

	if result != null:
		_view.play(result, ["我", enemy_name])
		# 157：名牌和战前准备屏同一份控件、同一个位置（面板顶上）
		_view.set_nameplate(0, _player_plate())
		_view.set_nameplate(1, _enemy_plate(payload.get("enemy_content", {})))
		_view.set_item_names(0, CombatantSpec.item_names(payload.get("player", null), flow.items))
		_view.set_item_names(1, CombatantSpec.item_names(payload.get("enemy", null), flow.items))
		# 087 / 103：双方上过身的 buff（图标 + 悬浮说明）在 result.buffs 里，play 已经接上
		# 103 第 7 条：双方棋盘 + 冷却遮罩（编译时的那张棋盘，uid 和日志一致）
		for side in 2:
			var spec: CombatantSpec = payload.get("player" if side == 0 else "enemy", null)
			if spec != null and spec.board != null:
				_view.set_board(side, spec.board)
	if coach_due():
		_view.hold()     # 166 补充二：教程要放 —— 一开场就停住，一帧都不偷跑
		_maybe_coach.call_deferred()


## 看完了（或不想看了）：回到流程
func proceed() -> void:
	flow.resume()


func _on_finished() -> void:
	if _next != null:
		_next.text = "继续"
	if _title != null and not verdict_shown():     # 157：拖时间轴拖到头会再「看完」一次
		_title.text += "　—— " + _verdict


func verdict_shown() -> bool:
	return _title != null and _title.text.contains(_verdict)


#region 166 补充二：战斗教程
## 这一章的战斗教程 id（没有 = 空）
func coach_id() -> StringName:
	return flow.run.chapter.coach_battle if flow.run != null and flow.run.chapter != null else &""


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
	if modulate.a < 1.0:
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


func view() -> BattleView:
	return _view
#endregion


## 109：玩家在回放里切了倍速 → 记进设置并存盘（和「拿走最后一件自动关闭」同一个写法）
func _on_speed_changed(speed: float) -> void:
	if flow.settings == null:
		return
	flow.settings.battle_speed = speed
	flow.save_settings()

## 战斗回放（M6，架构文档 4.8 / 8 节）：叠在地图上。战斗在踩上去那一瞬就算完了，这里只是照日志重演。
## 玩家能做的只有看、倍速、跳过，然后「继续」。日志里只有 uid，名字从双方的战斗单位查（`NodeEvents.last_battle`）。
extends GameScreen

var _view: BattleView
## 作者 2026-10-21 定（战旗 / 纸卷）：「继续」是一条纸卷，回放看完（或拖到头）才出现；回放中这里空着。没看完前是 null
var _next: Button = null
## 纸卷放的那一格（教程「next_button」指它：回放中空着，看完纸卷落在这里）
var _next_slot: CenterContainer
const CONTINUE_ART := "res://assets/ui/battle/"
## 回放看完（或跳到底）了没有（作者 2026-10-17：标题不再写胜负，按状态判断）
var _seen_end := false
var _won: bool = false
## 166 补充二：战斗教程（章节 `coaches` 的 `battle`），开着时回放停着
var _coach: CoachOverlay = null
## 220：这一场头一回打出的反应（流程给的）；回放放到第一次弹字时停下解释一句，解释过的划掉
var _fresh_reactions: Array[StringName] = []


func open(payload: Dictionary) -> void:
	var panel := _centered_panel(Vector2(1200, 900))     # 103 第 7 条：要放下双方棋盘
	var col := _vbox(8)
	panel.add_child(col)
	var node: MapNode = payload.get("node", null)
	var result: BattleResult = payload.get("result", null)
	_won = bool(payload.get("won", false))
	for id in payload.get("new_reactions", []):
		_fresh_reactions.append(StringName(String(id)))
	var enemy_name := _enemy_name(payload.get("enemy_content", {}))
	# 作者 2026-10-17：顶端的「战斗　X —— 赢了」和计时行都不给玩家看（胜负看地图日志与结算屏）；看完没看完记在 _seen_end

	_view = BattleView.new()
	_view.label_font = font
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(1160, 780)
	col.add_child(_view)
	_view.set_header_visible(false)
	_view.finished.connect(_on_finished)
	# 109（作者定）：倍速跨局继承 —— 开场按设置里的，切了就写回去
	if flow.settings != null:
		_view.set_speed(flow.settings.battle_speed)
	_view.speed_changed.connect(_on_speed_changed)
	_view.reaction_shown.connect(_on_reaction_shown)

	_next_slot = CenterContainer.new()
	_next_slot.custom_minimum_size = Vector2(246, 94)
	col.add_child(_next_slot)
	_view.add_coach_target(&"next_button", _next_slot)

	if result != null:
		_view.play(result, [UiText.t("battle.me"), enemy_name])
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
	if _next == null and _next_slot != null:
		_next = IconButton.make_art(CONTINUE_ART, "continue" if UiText.lang == "zh" else "continue_en", UiText.t("battle.continue"), "", proceed)
		_next_slot.add_child(_next)
	_seen_end = true     # 157：拖时间轴拖到头会再「看完」一次


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
	if flow.settings == null:
		return
	flow.settings.battle_speed = speed
	flow.save_settings()

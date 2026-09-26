## 战斗回放（M6，架构文档 4.8 / 8 节）：叠在地图上。战斗在踩上去那一瞬就算完了，这里只是照日志重演。
## 玩家能做的只有看、倍速、跳过，然后「继续」。日志里只有 uid，名字从双方的战斗单位查（`NodeEvents.last_battle`）。
extends GameScreen

var _view: BattleView
var _next: Button
var _title: Label
var _verdict: String = ""
var _won: bool = false


func open(payload: Dictionary) -> void:
	var panel := _centered_panel(Vector2(1000, 640))
	var col := _vbox(8)
	panel.add_child(col)
	var node: MapNode = payload.get("node", null)
	var result: BattleResult = payload.get("result", null)
	_won = bool(payload.get("won", false))
	var enemy_name := _enemy_name(payload.get("enemy_content", {}))
	# 084（作者定）：不提前显示胜负，看完回放（或跳过）才写
	_title = _label("战斗　%s" % enemy_name, 18, UiPalette.FG)
	col.add_child(_title)
	_verdict = "赢了" if _won else ("平局，按输算" if result != null and result.is_draw() else "输了")

	_view = BattleView.new()
	_view.label_font = font
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(960, 500)
	col.add_child(_view)
	_view.finished.connect(_on_finished)

	_next = _button("跳过并继续", proceed, 14)
	col.add_child(_next)

	if result != null:
		_view.play(result, ["我", enemy_name])
		_view.set_item_names(0, _names_of(payload.get("player", null)))
		_view.set_item_names(1, _names_of(payload.get("enemy", null)))
		# 087：双方会出现的 buff（图标 + 悬浮说明）
		var defs := Glossary.buffs_in_spec(payload.get("player", null))
		defs.merge(Glossary.buffs_in_spec(payload.get("enemy", null)))
		_view.set_buff_defs(defs)


## 看完了（或不想看了）：回到流程
func proceed() -> void:
	flow.resume()


func _on_finished() -> void:
	if _next != null:
		_next.text = "继续"
	if _title != null:
		_title.text += "　—— " + _verdict


func verdict_shown() -> bool:
	return _title != null and _title.text.contains(_verdict)


## 对手叫什么：从这一场的敌人内容（点里的，或搜索遭遇现造的）查定义
func _enemy_name(content: Dictionary) -> String:
	var def := flow.enemies.enemy(StringName(String(content.get("enemy", "")))) if not content.is_empty() else null
	if def == null:
		return "敌人"
	return "%s（%d 档）" % [Names.of(def), int(content.get("strength", 0))]


## uid → 显示名，回放把「uid 2 出手」写成「手枪 出手」
func _names_of(spec: CombatantSpec) -> Dictionary:
	var out := {}
	if spec == null:
		return out
	for item in spec.items:
		var def := flow.items.get_def(item.def_id)
		out[item.source_uid] = Names.of(def) if def != null else String(item.def_id)
	return out

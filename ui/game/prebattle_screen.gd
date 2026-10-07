## 战前准备屏（084，作者定）：踩上战斗点（或事件里选了开打、搜索遭遇了）先到这里，不是直接开打。
##
## 左边是对手：从节点内容重建的棋盘（[method EnemyKit.board_of]）与读数（生命 / DPS / 几件）—— 和真打出来的是同一份编译（4.2）；
## 右边是自己的棋盘与地上（[InventoryPanel]），随便拖：拖出棋盘 = 放到地上（不参战，打完还在地上；走了留在这个点、回来能拿）。
## 只有一个按钮「开战」：棋盘上一件会出手的东西都没有时灰掉（打不起来的仗不让开）。这一屏是**必须过的**：不能收起回地图，也走不了。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

var _node: MapNode = null
var _content: Dictionary = {}
var _type: StringName = &"battle"
var _enemy_view: InventoryView
var _enemy_line: Label
var _start_btn: Button
var _why: Label
var _slip_btn: Button = null
var _inv: Control


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	_content = payload.get("content", {})
	_type = StringName(String(payload.get("type", "battle")))
	var panel := _centered_panel(Vector2(0, 0), 20)
	var col := _vbox(12)
	panel.add_child(col)
	col.add_child(_label("战前准备　%s　—— 整理好背包再开战" % _title_of(), 20, UiPalette.FG))
	col.add_child(_wrapped("战斗是自动的：只有棋盘上包里的东西参战，武器自己出手、防具替你挨打，挨着放的互相加成。开战那一瞬胜负就定了，之后只是回放。拖出棋盘 = 弃置到地上（不参战，打完还在）。",
		13, UiPalette.DIM, 1100))

	var row := _hbox(28)
	col.add_child(row)
	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("对手的棋盘　%s" % _enemy_name(), 14, UiPalette.HP))
	_enemy_view = InventoryView.new()
	_enemy_view.label_font = font
	_enemy_view.show_adjacency = true
	_enemy_view.inventory = flow.run.events.pending_battle_board() if not flow.run.events.pending_battle.is_empty() else EnemyKit.board_of(_content, flow.items)
	_enemy_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_enemy_view.mouse_filter = Control.MOUSE_FILTER_STOP     # 只看（没登记进拖拽层，点了没事），停上去有说明
	left.add_child(_enemy_view)
	var tip := HoverTip.new()
	add_child(tip)
	tip.watch(_enemy_view)
	_enemy_line = _wrapped("", 13, UiPalette.FG, 420)
	left.add_child(_enemy_line)

	var right := _vbox(8)
	row.add_child(right)
	right.add_child(_label("我的棋盘与地上", 14, UiPalette.FG))
	_inv = InventoryPanelScript.new()
	_inv.setup(flow.run, font)
	right.add_child(_inv)

	var buttons := _hbox(10)
	_start_btn = _button("开战", start_battle, 16, UiPalette.Tier.PRIMARY)
	buttons.add_child(_start_btn)
	# 093（蛮神 3 级）：信仰级效果给的额外动作（秒杀精英）
	var altar := AltarModule.of(flow.run)     # 101：信仰级效果在神坛模块里取
	for p in (altar.perks() if altar != null else []):
		var perk := p as FaithPerk
		var text := perk.prebattle_label(flow.run, _type)
		if text != "":
			var pb := _button(text, func(): flow.smite(), 14)
			pb.tooltip_text = perk.describe()
			buttons.add_child(pb)
	# 136：脱身（安德烈乌斯）：这一场不打
	var slip := flow.slip_skill()
	if slip != null:
		_slip_btn = _button("", func(): slip_battle(), 14)
		_slip_btn.tooltip_text = slip.describe()
		buttons.add_child(_slip_btn)
	_why = _label("", 13, UiPalette.STAMINA)
	buttons.add_child(_why)
	col.add_child(buttons)
	flow.run.board.changed.connect(_refresh)
	_refresh()


#region 公开动作
## 按「开战」。打不起来（棋盘上没有会出手的东西）返回 false
func start_battle() -> bool:
	if can_start() != "":
		return false
	return flow.start_battle()


## 现在能不能开战：空串 = 能，否则是原因
func can_start() -> String:
	if flow.run == null or flow.run.events.pending_battle.is_empty():
		return "没有等着开打的一场"
	var spec := flow.run.compile_player()
	if spec.active_items().is_empty():
		return "棋盘上一件会出手的东西都没有：先把武器放进包里"
	return ""


## 136：按「溜走」。返回空串 = 溜了
func slip_battle() -> String:
	var why := slip_reason()
	if why != "":
		return why
	return flow.slip_battle()


## 136：现在能不能溜：空串 = 能
func slip_reason() -> String:
	var slip := flow.slip_skill()
	if slip == null:
		return "没有能溜走的技能"
	var why := SlipSkill.blocked_reason(flow.run)
	return why if why != "" else flow.run.skills.can_use(slip.id)


func enemy_view() -> InventoryView:
	return _enemy_view
#endregion


func _refresh() -> void:
	var spec := flow.run.events.pending_battle_spec() if flow.run != null else null
	if spec != null:
		var names: Array[String] = []
		for raw in _content.get("items", []):
			var d := flow.items.get_def(StringName(String((raw as Dictionary).get("id", ""))))
			names.append(Names.of(d) if d != null else String((raw as Dictionary).get("id", "?")))
		_enemy_line.text = "生命 %d　约 %.1f DPS　%d 件：%s" % [spec.max_hp_int(), spec.rough_dps(), names.size(), "、".join(names)]
	var why := can_start()
	_start_btn.disabled = why != ""
	_why.text = why
	if _slip_btn != null:
		var slip := flow.slip_skill()
		var left := flow.run.skills.uses_of(slip.id)
		var sw := slip_reason()
		_slip_btn.text = "%s（%s）" % ["溜走" if sw == "" else ("溜走：" + sw), "不限次" if left < 0 else "剩 %d 次" % left]
		_slip_btn.disabled = sw != ""


func _enemy_name() -> String:
	var def := flow.enemies.enemy(StringName(String(_content.get("enemy", "")))) if not _content.is_empty() else null
	if def == null:
		return "敌人"
	return "%s（%d 档）" % [Names.of(def), int(_content.get("strength", 0))]


func _title_of() -> String:
	match _type:
		&"elite":
			return "精英"
		&"core":
			return "核心"
		&"search":
			return "搜索中遭遇（输了不扣体力）"
	return "战斗"

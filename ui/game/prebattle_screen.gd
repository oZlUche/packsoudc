## 战前准备屏（084，作者定）：踩上战斗点（或事件里选了开打、搜索遭遇了）先到这里，不是直接开打。
##
## 左边是对手：从节点内容重建的棋盘（[method EnemyKit.board_of]）与读数（生命 / DPS；157 作者定：不写几件）—— 和真打出来的是同一份编译（4.2）；
## 右边是自己的棋盘与地上（[InventoryPanel]），随便拖：拖出棋盘 = 放到地上（不参战，打完还在地上；走了留在这个点、回来能拿）。
## 只有一个按钮「开战」：棋盘上一件会出手的东西都没有时灰掉（打不起来的仗不让开）。这一屏是**必须过的**：不能收起回地图，也走不了。
extends GameScreen

var _node: MapNode = null
var _content: Dictionary = {}
var _type: StringName = &"battle"
var _enemy_view: InventoryView
var _enemy_line: Label
var _start_btn: Button
var _why: Label
var _slip_btn: Button = null
## 147：腰带里能在这儿用的（烟雾弹）一件一个按钮
var _belt_row: HBoxContainer = null
var _inv: Control
## 157：两边的名牌、中缝天平
var _enemy_plate_node: Nameplate = null
var _player_plate_node: Nameplate = null
var _seam: BalanceSeam = null


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	_content = payload.get("content", {})
	_type = StringName(String(payload.get("type", "battle")))
	var panel := _centered_panel(Vector2(0, 0), 20)
	var col := _vbox(12)
	panel.add_child(col)
	_frame_title("战前准备　%s　—— 整理好背包再开战" % _title_of())     # 157：标题在石板框的标题条上
	col.add_child(_wrapped("战斗是自动的：只有棋盘上包里的东西参战，武器自己出手、防具替你挨打，挨着放的互相加成。开战那一瞬胜负就定了，之后只是回放。拖出棋盘 = 弃置到地上（不参战，打完还在）。",
		13, UiPalette.DIM, 1100))

	# 157：对阵式 —— 左对手、右自己，两列等宽，中间一道缝，缝顶一杆天平
	var row := _hbox(16)
	col.add_child(row)
	var left := _vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_enemy_plate_node = _enemy_plate(_content)
	left.add_child(_enemy_plate_node)
	_enemy_view = InventoryView.new()
	_enemy_view.label_font = font
	_enemy_view.show_adjacency = true
	_enemy_view.inventory = flow.run.events.pending_battle_board() if not flow.run.events.pending_battle.is_empty() else EnemyKit.board_of(_content, flow.items)
	_enemy_view.elements = InventoryView.elements_of_board(_enemy_view.inventory)     # 175：敌人武器上标元素
	_enemy_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_enemy_view.mouse_filter = Control.MOUSE_FILTER_STOP     # 只看（没登记进拖拽层，点了没事），停上去有说明
	left.add_child(_enemy_view)
	var tip := HoverTip.new()
	add_child(tip)
	tip.watch(_enemy_view)
	_enemy_line = _wrapped("", 13, UiPalette.FG, 420)
	left.add_child(_enemy_line)

	_seam = BalanceSeam.new()
	row.add_child(_seam)

	var right := _vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_player_plate_node = _player_plate()
	right.add_child(_player_plate_node)
	_inv = InventoryPanelScript.new()
	_inv.setup(flow.run, font)
	right.add_child(_inv)

	# 「开战」居中、主档；腰带件在左，信仰 / 技能给的动作在右，原因写在下面一行
	var buttons := _hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_belt_row = _hbox(10)     # 147：腰带里能在战前用的（160：名字后面带数量）
	buttons.add_child(_belt_row)
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
	# 136：脱身（安德烈乌斯）：这一场不打。166 补充一：主动技能藏着时不建
	var slip := flow.slip_skill()
	if slip != null and not RunSkills.ACTIVE_HIDDEN:
		_slip_btn = _button("", func(): slip_battle(), 14)
		_slip_btn.tooltip_text = slip.describe()
		buttons.add_child(_slip_btn)
	col.add_child(buttons)
	_why = _label("", 13, UiPalette.STAMINA)
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_why)
	flow.run.board.changed.connect(_refresh)
	var belt := BeltModule.of(flow.run)
	if belt != null:
		belt.changed.connect(_refresh_belt)
	_refresh_belt()
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


## 147：用腰带里的一个（按钮；160 补一：按随身技能 id）。返回空串 = 用了
func use_belt(skill_id: StringName) -> String:
	return flow.use_belt(skill_id)


## 147：腰带里能在战前准备屏上用的那几种（按腰带里的顺序）
func belt_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var belt := BeltModule.of(flow.run) if flow != null else null
	if belt == null:
		return out
	for sid in belt.ids():
		var def := BeltSkillDef.find(sid)
		if def != null and def.on_prebattle():
			out.append(sid)
	return out
#endregion


func _refresh_belt() -> void:
	if _belt_row == null or not is_instance_valid(_belt_row):
		return
	for c in _belt_row.get_children():
		c.queue_free()
	var belt := BeltModule.of(flow.run)
	for sid in belt_ids():
		var def := BeltSkillDef.find(sid)
		var name := "%s ×%d" % [def.display_name, belt.count_of(sid)]
		var why := belt.can_use(sid)
		var b := _button(("用%s" % name) if why == "" else ("%s：%s" % [name, why]), func(): use_belt(sid), 14)
		b.tooltip_text = def.describe()
		b.disabled = why != ""
		_belt_row.add_child(b)


func _refresh() -> void:
	var spec := flow.run.events.pending_battle_spec() if flow.run != null else null
	if spec != null:
		# 157（作者定）：读数只剩生命与 DPS，出手几件道具不写
		_enemy_line.text = "生命 %d　约 %.1f DPS" % [spec.max_hp_int(), spec.rough_dps()]
	if _seam != null and flow.run != null:
		var mine := flow.run.compile_player()
		_seam.set_strength(strength_of(spec), strength_of(mine))
	var why := can_start()
	_start_btn.disabled = why != ""
	_why.text = why
	if _slip_btn != null:
		var slip := flow.slip_skill()
		var left := flow.run.skills.uses_of(slip.id)
		var sw := slip_reason()
		_slip_btn.text = "%s（%s）" % ["溜走" if sw == "" else ("溜走：" + sw), "不限次" if left < 0 else "剩 %d 次" % left]
		_slip_btn.disabled = sw != ""


## 157：天平用的强弱 = 生命上限 × 粗算 DPS（没编出来 0）
static func strength_of(spec: CombatantSpec) -> float:
	return float(spec.max_hp_int()) * spec.rough_dps() if spec != null else 0.0


## 157：天平（测试看）
func seam() -> BalanceSeam:
	return _seam


func enemy_line() -> String:
	return _enemy_line.text if _enemy_line != null else ""


func _title_of() -> String:
	match _type:
		&"elite":
			return "精英"
		&"core":
			return "核心"
		&"search":
			return "搜索中遭遇（输了不扣体力）"
	return "战斗"

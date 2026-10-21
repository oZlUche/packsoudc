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
## 218 补充一（217 批三）：战前屏的教程（章节 `coaches` 的 `prebattle`），名牌与天平刷出来之后放
var _coach: CoachOverlay = null
## 218 补充一：战前屏教程能指的地方（[method control_rect]）
const COACH_TARGETS: Array[StringName] = [&"enemy_board", &"scale", &"my_board", &"fight_button"]


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	_content = payload.get("content", {})
	_type = StringName(String(payload.get("type", "battle")))
	var panel := _centered_panel(Vector2(0, 0), 20)
	var col := _vbox(12)
	panel.add_child(col)
	_frame_title(UiText.t("pre.title") % _title_of())     # 157：标题在石板框的标题条上
	col.add_child(_wrapped(UiText.t("pre.intro"),
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
	_start_btn = _button(UiText.t("pre.fight"), start_battle, 16, UiPalette.Tier.PRIMARY)
	buttons.add_child(_start_btn)
	# 093（蛮神 3 级）：信仰级效果给的额外动作。188 补充一：一条效果可以给几个（耗体力 / 耗信力立即击败），不够的灰着、写原因
	var altar := AltarModule.of(flow.run)     # 101：信仰级效果在神坛模块里取
	for p in (altar.perks() if altar != null else []):
		var perk := p as FaithPerk
		for a in perk.prebattle_actions(flow.run, _type):
			var option: StringName = a["option"]
			var pb := _button(String(a["label"]), func(): flow.smite(option), 14)
			pb.disabled = String(a["why"]) != ""
			pb.tooltip_text = String(a["why"]) if pb.disabled else perk.describe()
			pb.set_meta("perk_option", option)
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
	_maybe_coach.call_deferred()


#region 公开动作
## 按「开战」。没有待打的仗返回 false。222（作者定）：棋盘上一件会出手的都没有也能开战，照常打、照常按打输结算
func start_battle() -> bool:
	if can_start() != "":
		return false
	return flow.start_battle()


## 现在能不能开战：空串 = 能，否则是原因
func can_start() -> String:
	if flow.run == null or flow.run.events.pending_battle.is_empty():
		return UiText.t("pre.no_battle")
	return ""


## 222：棋盘上一件会出手的东西都没有 —— 只提醒一句，不拦「开战」
func unarmed() -> bool:
	return flow.run != null and flow.run.compile_player().active_items().is_empty()


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
		return UiText.t("pre.no_slip")
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
		var name := "%s ×%d" % [Names.of(def), belt.count_of(sid)]
		var why := belt.can_use(sid)
		var b := _button((UiText.t("pre.use_belt") % name) if why == "" else (UiText.t("pre.belt_blocked") % [name, why]), func(): use_belt(sid), 14)
		b.tooltip_text = def.describe()
		b.disabled = why != ""
		_belt_row.add_child(b)


## 210：「免疫：流血、中毒」—— 机关不吃的状态；没有就空
static func immune_text(spec: CombatantSpec) -> String:
	if spec == null or spec.immune_buffs.is_empty():
		return ""
	var names: PackedStringArray = []
	var lib := ContentLibrary.buffs()
	for id in spec.immune_buffs:
		var b: BuffDef = lib.get(id, null)
		names.append(Names.of(b) if b != null and b.display_name != "" else String(id))
	return UiText.t("pre.immune") % UiText.t("pre.list_sep").join(names)


func _refresh() -> void:
	var spec := flow.run.events.pending_battle_spec() if flow.run != null else null
	if spec != null:
		# 157（作者定）：读数只剩生命与 DPS，出手几件道具不写
		_enemy_line.text = UiText.t("pre.enemy_line") % [spec.max_hp_int(), spec.rough_dps()]
		var immune := immune_text(spec)
		if immune != "":
			_enemy_line.text += "\n" + immune
	if _seam != null and flow.run != null:
		var mine := flow.run.compile_player()
		_seam.set_strength(strength_of(spec), strength_of(mine))
	var why := can_start()
	_start_btn.disabled = why != ""
	_why.text = why if why != "" else (UiText.t("pre.no_attacker") if unarmed() else "")
	if _slip_btn != null:
		var slip := flow.slip_skill()
		var left := flow.run.skills.uses_of(slip.id)
		var sw := slip_reason()
		_slip_btn.text = UiText.t("pre.slip_btn") % [UiText.t("pre.slip") if sw == "" else (UiText.t("pre.slip_blocked") % sw), UiText.t("pre.slip_unlimited") if left < 0 else UiText.t("pre.slip_left") % left]
		_slip_btn.disabled = sw != ""


## 157：天平用的强弱 = 生命上限 × 粗算 DPS（没编出来 0）
static func strength_of(spec: CombatantSpec) -> float:
	return float(spec.max_hp_int()) * spec.rough_dps() if spec != null else 0.0


## 157：天平（测试看）
func seam() -> BalanceSeam:
	return _seam


#region 218 补充一：战前屏教程
func coach_id() -> StringName:
	return flow.run.chapter.coach_for(&"prebattle") if flow.run != null and flow.run.chapter != null else &""


func coach() -> CoachOverlay:
	return _coach


## 第一次进战前屏（这个存档没看过）放一次：等一帧，名牌、天平、两块棋盘都摆好了再挖洞
func _maybe_coach() -> void:
	if not CoachOverlay.due(flow, coach_id()) or not is_inside_tree():
		return
	get_tree().process_frame.connect(show_coach, CONNECT_ONE_SHOT)     # 屏关了连接跟着断


func show_coach() -> bool:
	if _coach != null or not is_inside_tree():
		return false
	_coach = CoachOverlay.run_on(self, coach_id(), flow, font, control_rect)
	if _coach == null:
		return false
	_coach.finished.connect(func(): _coach = null)
	return true


## 教程目标的全局包围盒（[constant COACH_TARGETS]）：对手 = 名牌 + 棋盘，自己 = 名牌 + 棋盘；没有 / 不在屏上 = 空矩形
func control_rect(id: StringName) -> Rect2:
	match id:
		&"enemy_board": return _union([_enemy_plate_node, _enemy_view])
		&"scale": return _union([_seam])
		&"my_board": return _union([_player_plate_node, _inv.get("board_view") if _inv != null else null])
		&"fight_button": return _union([_start_btn])
	return Rect2()


static func _union(parts: Array) -> Rect2:
	var out := Rect2()
	for c in parts:
		if c == null or not is_instance_valid(c) or not (c as Control).is_visible_in_tree():
			continue
		var r := (c as Control).get_global_rect()
		out = r if out.size == Vector2.ZERO else out.merge(r)
	return out
#endregion


func enemy_line() -> String:
	return _enemy_line.text if _enemy_line != null else ""


func _title_of() -> String:
	match _type:
		&"elite":
			return UiText.t("pre.kind_elite")
		&"core":
			return UiText.t("pre.kind_core")
		&"search":
			return UiText.t("pre.kind_search")
	return UiText.t("pre.kind_battle")

## 战前准备屏（084，作者定）：踩上战斗点（或事件里选了开打、搜索遭遇了）先到这里，不是直接开打。
##
## 右边是对手（作者 2026-10-21 18:19：和回放统一，自己在左）：从节点内容重建的棋盘（[method EnemyKit.board_of]）与一排属性签（生命 / 耐力 / 耗气 / DPS / 特殊能力）—— 和真打出来的是同一份编译（4.2）；
## 左边是自己的棋盘与地上（[InventoryPanel]），棋盘里随便挪；249（作者 2026-10-24）：开战前不丢东西 —— 棋盘上的出不去（拖出去弹回、
## 右键「放到地上」灰着、双击不搬），不想让它打就右键「不参战」；地上的照样能拾进棋盘。
## 只有一个按钮「开战」：棋盘上一件会出手的东西都没有时灰掉（打不起来的仗不让开）。这一屏是**必须过的**：不能收起回地图，也走不了 ——
## 248：地图上看得见的战斗 / 精英点可以「退回」（退回上一个点、照走一步，这一场留着）
extends GameScreen

var _node: MapNode = null
var _content: Dictionary = {}
var _type: StringName = &"battle"
var _enemy_view: InventoryView
## 铜面板三屏：两列、中缝、两排属性签（敌人那排自己建；自己那排是背包面板摘出来的）
var _left: VBoxContainer = null
var _right: VBoxContainer = null
var _lane: PrebattleLane = null
var _enemy_strip: StatsStrip = null
var _player_strip: StatsStrip = null
## 内容离铜面板外沿（含面板自己的 40 内缩）；作者 15:44：右列离右沿再远一点 —— 两边一起放宽，中缝仍在正中
const PANEL_MARGIN := 50
## 属性签上沿离较低那块棋盘的外框下沿（battle_stats v2 `prebattle_row`：+18；竖排本身隔 10）
const STRIP_GAP := 18
const ENEMY_FRAME := "corpse"
const PLAYER_FRAME := "player"
var _start_btn: Button
## 231：面板里的整列（开战过场时淡掉，铜面板本身留着）
var _col: VBoxContainer = null
## 作者 2026-10-21 定（战旗 / 纸卷）：「开战」是一面战旗，四态，字画在图里；可点的是旗面
const FIGHT_ART := "res://assets/ui/battle/"
const FIGHT_HIT := Rect2(22, 10, 156, 108)
var _why: Label
## 256 补（架构 2026-10-26 17:05）：「为什么开不了 / 空棋盘」那句写在旗旁边的一张便条上 —— 不另起一行（铜面板不超出顶端栏下面），226 落在纸上
var _why_note: PanelContainer = null
const WHY_W := 200.0
var _slip_btn: Button = null
## 256：偷袭（安德烈乌斯）的平石键（作者 15:49 定稿：和「退回」同一种四态整图 `battle/ambush_key*`，字由代码写）
var _ambush_btn: IconButton = null
const AMBUSH_ART := "battle/ambush_key"
## 248：「退回」（作者 2026-10-24 14:44 选丙「回头脚印」：平的白灰石键，左头两只脚印，四态 `battle/retreat_key*`）。
## 图里不带字：字由代码写在 json 的 `text_rect` 里（中英文同一张图）。退不了的场合不建
var _retreat_btn: IconButton = null
const RETREAT_ART := "battle/retreat_key"
const RETREAT_W := 112.0
## 147：腰带里能在这儿用的（烟雾弹）一件一个按钮
var _belt_row: HBoxContainer = null
var _inv: Control
## 157：两边的名牌
var _enemy_plate_node: Nameplate = null
var _player_plate_node: Nameplate = null
## 218 补充一（217 批三）：战前屏的教程（章节 `coaches` 的 `prebattle`），名牌与两排签刷出来之后放
var _coach: CoachOverlay = null
## 218 补充一：战前屏教程能指的地方（[method control_rect]）
const COACH_TARGETS: Array[StringName] = [&"enemy_board", &"stats", &"my_board", &"fight_button"]


func open(payload: Dictionary) -> void:
	_node = payload.get("node", null)
	_content = payload.get("content", {})
	_type = StringName(String(payload.get("type", "battle")))
	# 铜面板三屏（UI替换美术 bronze3，作者 2026-10-21 16:15）：铜面板、没有标题条和玩法说明；两列中间一条刻线中缝，正中一枚双剑铜章
	var panel := _bronze_panel(Vector2(0, 0), PANEL_MARGIN)
	# 256 补（架构 17:05）：铜面板不超出顶端栏下面（1000 − 16 − 顶端栏 = 884）—— 对手六行的棋盘时两排之间只留 4（旗图上沿自带 10 的透明边，看着仍是 14）
	var col := _vbox(4)
	panel.add_child(col)
	_col = col

	# 157：对阵式，两列等宽；作者 2026-10-21 18:19：和战斗回放统一 —— 自己在左、对手在右。属性签在两块棋盘下面同一条线上（battle_stats v2 `prebattle_row`）
	var row := _hbox(0)
	col.add_child(row)
	_left = _vbox(10)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_left)
	_enemy_plate_node = _enemy_plate(_content, Nameplate.COMPACT_PORTRAIT)
	_left.add_child(_enemy_plate_node)
	_enemy_view = InventoryView.new()
	_enemy_view.label_font = font
	_enemy_view.show_adjacency = true
	_enemy_view.inventory = flow.run.events.pending_battle_board() if not flow.run.events.pending_battle.is_empty() else EnemyKit.board_of(_content, flow.items)
	_enemy_view.mouse_filter = Control.MOUSE_FILTER_STOP     # 只看（没登记进拖拽层，点了没事），停上去有说明
	_left.add_child(_enemy_view)
	BoardFrame.around(_enemy_view, ENEMY_FRAME)
	var tip := HoverTip.new()
	add_child(tip)
	tip.watch(_enemy_view)
	_left.add_child(_strip_gap())
	_enemy_strip = StatsStrip.new()
	_enemy_strip.use_inlay(true, StatsStrip.ORDER_ENEMY)
	_enemy_strip.tip = tip
	_left.add_child(_enemy_strip)

	_lane = PrebattleLane.new()
	_lane.center_on = _overlay_frame
	_lane.pressed.connect(_on_lane_pressed)     # 2026-10-22：点正中那枚双剑铜章 = 按「开战」
	row.add_child(_lane)

	_right = _vbox(10)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_right)
	_player_plate_node = _player_plate(Nameplate.COMPACT_PORTRAIT)
	_right.add_child(_player_plate_node)
	_inv = InventoryPanelScript.new()
	_inv.setup(flow.run, font)
	_inv.ground_exit_notice = UiText.t("pre.no_drop")     # 249：开战前不丢东西（「不参战」照旧）
	_right.add_child(_inv)
	BoardFrame.around(_inv.board_view, PLAYER_FRAME)
	_inv.hold_nine()     # 255 补充一：面板按九格定宽，窄的棋盘居中
	_right.add_child(_strip_gap())
	_player_strip = _inv.detach_strip()
	_player_strip.use_inlay(true, StatsStrip.ORDER_PLAYER)
	_right.add_child(_player_strip)
	row.move_child(_right, 0)     # 自己那列放最左，中缝其次，对手那列在右
	row.move_child(_lane, 1)

	# 「开战」居中、主档；腰带件在左，信仰 / 技能给的动作在右，开不了的原因写在旗右边的便条上
	var buttons := _hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_belt_row = _hbox(10)     # 147：腰带里能在战前用的（160：名字后面带数量）
	buttons.add_child(_belt_row)
	var flag := IconButton.make_art(FIGHT_ART, "fight" if UiText.lang == "zh" else "fight_en", UiText.t("pre.fight"), "", start_battle)
	flag.hit_rect = FIGHT_HIT if flag.has_art() else Rect2()
	_start_btn = flag
	buttons.add_child(_start_btn)
	_why_note = UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_SUMMARY_NOTE, 12, 18, 12, 8)     # 上边给图钉留地方（同熔炉的便条）
	UiTheme.apply_tone(_why_note, UiTheme.PANEL_SUMMARY_NOTE)
	_why_note.name = "WhyNote"
	_why_note.visible = false
	_why = _wrapped("", 13, UiTheme.INK_WARN, WHY_W)
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_why_note.add_child(_why)
	buttons.add_child(_why_note)
	# 093（蛮神 3 级）：信仰级效果给的额外动作。188 补充一：一条效果可以给几个（耗体力 / 耗信力立即击败），不够的灰着、写原因
	var altar := AltarModule.of(flow.run)     # 101：信仰级效果在神坛模块里取
	for p in (altar.perks() if altar != null else []):
		var perk := p as FaithPerk
		for a in perk.prebattle_actions(flow.run, _type):
			var option: StringName = a["option"]
			var pb := _button(String(a["label"]), func(): smite(option), 14)
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
	# 256：偷袭 —— 战前屏的平石键，按下 = 用掉一次 + 开战
	var amb := flow.prebattle_skill()
	if amb != null:
		_ambush_btn = _make_art_key(AMBUSH_ART, UiText.t("pre.ambush"), amb.describe(), func(): ambush())
		buttons.add_child(_ambush_btn)
	for c in buttons.get_children():
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER     # 旗比按钮高：别的按钮不跟着拉长
	# 248：「退回」放在左下角（战旗居中，右边垫一块同宽的空位让它不偏）；地图上看得见的战斗 / 精英点才有
	var foot := _hbox(0)
	var corner := VBoxContainer.new()
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.custom_minimum_size = Vector2(RETREAT_W, 0)
	if flow.retreat_reason() == "":
		_retreat_btn = _make_retreat_key()
		corner.add_child(_retreat_btn)
	foot.add_child(corner)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(buttons)
	var mirror := Control.new()
	mirror.custom_minimum_size = Vector2(RETREAT_W, 0)
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(mirror)
	col.add_child(foot)
	flow.run.board.changed.connect(_refresh)
	var belt := BeltModule.of(flow.run)
	if belt != null:
		belt.changed.connect(_refresh_belt)
	_refresh_belt()
	_refresh()
	_fit_duel_panel()
	_maybe_coach.call_deferred()
	_unfurl_flag.call_deferred()


## 231：进场时「开战」战旗从挂杆往下展开（排版定了再展；灰着的旗不摆）
func _unfurl_flag() -> void:
	if _start_btn != null and is_instance_valid(_start_btn):
		UiMotion.unfurl(_start_btn, UiMotion.enabled(flow.settings), UiMotion.UNFURL_SEC, not _start_btn.disabled)


## 231：开战过场的前半（战斗屏 [method BattleScreen.intro_from] 调）：战旗收起、两列内容淡掉，铜章交出去。返回铜章的屏幕框
func outro(on: bool, sec: float = 0.2) -> Rect2:
	if _start_btn != null:
		UiMotion.furl(_start_btn, on, sec)
	if _col != null:
		UiMotion.fade(_col, on, 1.0, 0.0, sec)
	if _lane != null:
		_lane.medal_hidden = true     # 铜章交给战斗屏（它从同一个位置接着画）
	return _lane.medal_rect() if _lane != null else Rect2()


#region 公开动作
## 按「开战」。没有待打的仗返回 false。222（作者定）：棋盘上一件会出手的都没有也能开战，照常打、照常按打输结算
func start_battle() -> bool:
	if can_start() != "":
		return false
	HudHost.hold_in(get_tree())     # 231 补充二：结算是同步算完的，顶栏等回放看完再变
	return flow.start_battle()


## 2026-10-22（作者）：战前屏正中那枚双剑铜章看着像能按，就让它真是按键 —— 点它等于按「开战」。
## 走和「开战」战旗同一条路（[method start_battle]），声音也是那个按钮音（ui.press）
func _on_lane_pressed() -> void:
	if can_start() != "":
		return
	Audio.play(&"ui.press")
	start_battle()


## 093：蛮神秒杀（按钮）。顶栏同样按住到回放看完（231 补充二）
func smite(option: StringName) -> bool:
	HudHost.hold_in(get_tree())
	var ok := flow.smite(option)
	if not ok:
		HudHost.release_in(get_tree(), false)
	return ok


## 现在能不能开战：空串 = 能，否则是原因
func can_start() -> String:
	if flow.run == null or flow.run.events.pending_battle.is_empty():
		return UiText.t("pre.no_battle")
	return ""


## 222：棋盘上一件会出手的东西都没有 —— 只提醒一句，不拦「开战」
func unarmed() -> bool:
	return flow.run != null and flow.run.compile_player().active_items().is_empty()


## 248：按「退回」：这一场先不打、退回上一个点（照走一步）。返回空串 = 退了
func retreat() -> String:
	return flow.retreat_battle()


## 248：这一屏有没有「退回」键
func retreat_button() -> IconButton:
	return _retreat_btn


## 248：「退回」石键 —— 整图四态（[method IconButton.make_art]），字照 `retreat_key.json` 写（墨色、灰态色、按下下移 1）；缺图退回写字的按钮
func _make_retreat_key() -> IconButton:
	return _make_art_key(RETREAT_ART, UiText.t("pre.retreat"), UiText.t("pre.retreat_tip"), func(): retreat())


## 248 / 256：一颗四态整图的平石键（退回、偷袭），字照 `<art>.json` 的 `text_rect` 写
func _make_art_key(art: String, label: String, tip: String, handler: Callable) -> IconButton:
	var b := IconButton.make_art(UiTheme.asset_root + art.get_base_dir() + "/", art.get_file(), label, tip, handler)
	var meta := UiTheme.art_meta(art)
	var r: Array = meta.get("text_rect", [36, 0, 108, 40])     # 左上、右下（图的像素）
	b.art_label = label
	b.art_label_rect = Rect2(Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))
	b.art_label_size = int(meta.get("font_size", 18))
	var ink: Dictionary = meta.get("ink", {})
	b.art_label_color = Color(String(ink.get("normal", "#2e2219")))
	b.art_label_disabled_color = Color(String(ink.get("disabled", "#605a50")))
	b.art_label_drop = 1.0
	if not b.has_art():
		b.custom_minimum_size = Vector2(RETREAT_W, 40)
	return b


## 256：按「偷袭」：用掉一次，敌人开战就先失去几成生命。返回空串 = 打了
func ambush() -> String:
	var why := ambush_reason()
	if why != "":
		return why
	HudHost.hold_in(get_tree())     # 同「开战」：顶栏等回放看完再变
	why = flow.ambush_battle()
	if why != "":
		HudHost.release_in(get_tree(), false)
	return why


## 256：现在能不能偷袭：空串 = 能
func ambush_reason() -> String:
	var amb := flow.prebattle_skill()
	if amb == null:
		return UiText.t("log.no_skill")
	var why := can_start()
	return why if why != "" else flow.run.skills.can_use(amb.id)


## 256：战前屏的「偷袭」键（测试看）
func ambush_button() -> Button:
	return _ambush_btn


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


func _refresh() -> void:
	var spec := flow.run.events.pending_battle_spec() if flow.run != null else null
	if spec != null:
		_enemy_strip.refresh(spec, null)     # battle_stats v2：原来那行「生命 / DPS」和「免疫」都归进敌人那排签（免疫在特殊能力签的悬浮窗里）
	_even_columns()
	var why := can_start()
	_start_btn.disabled = why != ""
	if _lane != null:
		_lane.set_enabled(why == "")     # 2026-10-22：铜章跟着「开战」一起灰、一起亮
	(_start_btn as IconButton).sync_art()
	_why.text = why if why != "" else (UiText.t("pre.no_attacker") if unarmed() else "")
	_why_note.visible = _why.text != ""     # 空着不占地方
	if _slip_btn != null:
		var slip := flow.slip_skill()
		var left := flow.run.skills.uses_of(slip.id)
		var sw := slip_reason()
		_slip_btn.text = UiText.t("pre.slip_btn") % [UiText.t("pre.slip") if sw == "" else (UiText.t("pre.slip_blocked") % sw), UiText.t("pre.slip_unlimited") if left < 0 else UiText.t("pre.slip_left") % left]
		_slip_btn.disabled = sw != ""
	if _ambush_btn != null:
		var amb := flow.prebattle_skill()
		var aw := ambush_reason()
		_ambush_btn.art_label = UiText.t("pre.ambush_btn") % [UiText.t("pre.ambush"), flow.run.skills.uses_of(amb.id)]     # 「偷袭 ×3」
		if not _ambush_btn.has_art():
			_ambush_btn.text = _ambush_btn.art_label
		_ambush_btn.disabled = aw != ""
		_ambush_btn.queue_redraw()
		_ambush_btn.tooltip_text = amb.describe() if aw == "" else aw


## 两列一样宽（中缝和铜章都在面板正中）：各列按两列里较宽的那份内容撑
func _even_columns() -> void:
	if _left == null or _right == null:
		return
	var w := maxf(_content_width(_left), _content_width(_right))
	for c in [_left, _right]:
		if (c as Control).custom_minimum_size.x != w:
			(c as Control).custom_minimum_size.x = w


static func _content_width(box: Container) -> float:
	var w := 0.0
	for c in box.get_children():
		if c is Control and (c as Control).visible:
			w = maxf(w, (c as Control).get_combined_minimum_size().x)
	return w


## 属性签上面那段空：把两排签压到两列底下同一条线（两块棋盘一高一矮时矮的那边撑开）
func _strip_gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, STRIP_GAP - 10)
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## 两排属性签（测试看）
func enemy_strip() -> StatsStrip:
	return _enemy_strip


func player_strip() -> StatsStrip:
	return _player_strip


## 中缝（测试看）
func lane() -> PrebattleLane:
	return _lane


#region 218 补充一：战前屏教程
func coach_id() -> StringName:
	return flow.run.chapter.coach_for(&"prebattle") if flow.run != null and flow.run.chapter != null else &""


func coach() -> CoachOverlay:
	return _coach


## 第一次进战前屏（这个存档没看过）放一次：等一帧，名牌、两块棋盘、两排签都摆好了再挖洞
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
		&"stats": return _union([_enemy_strip, _player_strip])
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

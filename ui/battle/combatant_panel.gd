## 一方战斗单位的面板：资源条 + 增益层数 + 飘字。
## 087（作者定）：增益 / 减益画成一排**图标**（现在暂时用名字的第一个字），鼠标停上去发 [signal buff_hovered]，回放层开悬浮窗写具体效果。
##
## [b]它只认日志喂进来的数值，不认识 [CombatantRuntime]。[/b]
## 回放是「照着一串事件重演」，不是「盯着一个活的模拟对象」——
## 这样同一套面板既能放回放，也能将来放录像、放别人的战斗。
class_name CombatantPanel
extends Control

const BAR_H := 18
const BAR_GAP := 6
const CHIP_H := 20
const PAD := 12
## 103：系统效果（鏖战、衰竭）的配色
const SYSTEM_COLOR := Color("e0b45c")

## 资源条的显示顺序。没列出的排在后面，按字典序 —— 顺序稳定，界面才不会乱跳。
##
## 106（作者定）：**护盾不在这里** —— 它不画成独立的一条，而是生命条外侧的一圈粗白框
## （长度 = 护盾 / 生命上限，护盾顶得住几成血一眼看得出），见 [method shield_frame_ratio]
const ORDER := ["hp", "stamina", "mana"]
## 护盾的资源键：不画条，画框
const SHIELD_KEY := "shield"
## 那圈框的粗细（px）
const FRAME_W := 3.0

signal buff_hovered(buff_id: String, at: Vector2)
signal buff_unhovered

var display_name: String = ""
var label_font: Font
## buff id → 定义（画图标用名字的第一个字、悬浮窗写效果）。103：来自 [member BattleResult.buffs] —— 上过身的都在
var buff_defs: Dictionary = {}
## 103：这一方的常驻加成（[PassiveNote]）：灰底、不随事件变，排在最后。图标 id 是 `passive:<下标>`
var passives: Array = []
const PASSIVE_PREFIX := "passive:"
## 103：标准轴的格（4.3）：`axis:<轴>`，值是内容层的带符号层数；加时的「鏖战 ×n」格是 OVERTIME_CHIP
const AXIS_PREFIX := "axis:"
const OVERTIME_CHIP := "system:overtime"
## 现在画着的图标：[Rect2, id]
var _chips: Array = []
var _hover_id: String = ""

## key -> [current, max]。
##
## [b]单位是取整后的显示值，不是定点。[/b] 两个来源的单位本来不一致 ——
## 快照（ResourcePool.snapshot）已经取过整，而事件载荷是定点 ——
## 换算统一在 [BattleView] 那一层做完，面板这里只管画。
## 混着用的后果是血条显示 0 / 0 却画成满格，而且只在其中一条路径上出现。
var _resources: Dictionary = {}
## buff id -> 层数
var _stacks: Dictionary = {}
## buff id -> 第几个上身的（103：各组内按上身先后排）
var _arrival: Dictionary = {}
var _arrivals: int = 0
var _dead: bool = false
## 最近一次出手的物品名，给一点「谁在动」的反馈
var _last_fired: String = ""
var _fired_at: float = -99.0

## uid -> 显示名。日志里只有 uid，名字是表现层的事。
var item_names: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(320, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	var over := chip_at(mm.position)
	if over == _hover_id:
		return
	_hover_id = over
	if over == "":
		buff_unhovered.emit()
	else:
		buff_hovered.emit(over, global_position + mm.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover_id != "":
		_hover_id = ""
		buff_unhovered.emit()


## 这个位置（面板内坐标）压着哪个 buff 的图标；没有空串
func chip_at(local: Vector2) -> String:
	for c in _chips:
		if (c[0] as Rect2).has_point(local):
			return String(c[1])
	return ""


## 图标上写的字：名字的第一个字（暂时；正式美术换成图）
func icon_of(id: String) -> String:
	if id == OVERTIME_CHIP:
		return "鏖"
	if id.begins_with(AXIS_PREFIX):
		return StatAxes.name_of(axis_of(id), int(_stacks.get(id, 0))).substr(0, 1)
	var note := passive_of(id)
	if note != null:
		return note.name.substr(0, 1)
	var def: BuffDef = buff_defs.get(StringName(id), null)
	var name := Names.of(def) if def != null and Names.of(def) != "" else id
	return name.substr(0, 1)


func stacks() -> Dictionary:
	return _stacks


## 轴格的轴 id；不是轴格空
static func axis_of(id: String) -> StringName:
	return StringName(id.substr(AXIS_PREFIX.length())) if id.begins_with(AXIS_PREFIX) else &""


## 图标 id 是常驻格的话给那条 [PassiveNote]，否则 null
func passive_of(id: String) -> PassiveNote:
	if not id.begins_with(PASSIVE_PREFIX):
		return null
	var i := int(id.substr(PASSIVE_PREFIX.length()))
	return passives[i] as PassiveNote if i >= 0 and i < passives.size() else null


## 103：栏里的顺序 —— 系统 → 减益 → 增益（各组内按上身先后），最后是常驻
func ordered_ids() -> Array:
	var ids: Array = _stacks.keys()
	ids.sort_custom(func(a, b):
		var ga := _group_of(String(a))
		var gb := _group_of(String(b))
		if ga != gb:
			return ga < gb
		return int(_arrival.get(a, 0)) < int(_arrival.get(b, 0)))
	for i in passives.size():
		ids.append(PASSIVE_PREFIX + str(i))
	return ids


func _group_of(id: String) -> int:
	if id == OVERTIME_CHIP:
		return 0
	if id.begins_with(AXIS_PREFIX):
		return 1 if is_bad_axis(id) else 2
	var def: BuffDef = buff_defs.get(StringName(id), null)
	if def == null:
		return 2
	if def.system:
		return 0
	return 1 if def.is_debuff else 2


## 轴格是不是减益：受到伤害轴正层是坏事（易伤），别的轴负层是坏事
func is_bad_axis(id: String) -> bool:
	var v := int(_stacks.get(id, 0))
	return v > 0 if axis_of(id) == StatAxes.DAMAGE_TAKEN else v < 0


## 图标上的字 + 层数。不可叠层的不画 ×1（103）；常驻格的层数是阶 / 档位，一律画；轴格画 ×|层数|
func chip_text(id: String) -> String:
	if id.begins_with(AXIS_PREFIX):
		return "%s ×%d" % [icon_of(id), absi(int(_stacks.get(id, 0)))]
	if passive_of(id) != null:
		return "%s ×%d" % [icon_of(id), passive_of(id).stacks]
	var def: BuffDef = buff_defs.get(StringName(id), null)
	if def != null and not def.is_stackable():
		return icon_of(id)
	return "%s ×%d" % [icon_of(id), int(_stacks.get(id, 0))]


#region 由回放驱动
func reset(snapshot: Dictionary) -> void:
	_resources.clear()
	_stacks.clear()
	_arrival.clear()
	_arrivals = 0
	_dead = false
	_last_fired = ""
	var res: Dictionary = snapshot.get("resources", {})
	for key in res:
		var pair: Array = res[key]
		_resources[String(key)] = [int(pair[0]), int(pair[1])]
	queue_redraw()


func set_resource(key: String, current: int, maximum: int) -> void:
	_resources[key] = [current, maximum]
	queue_redraw()


func set_stacks(buff: String, stacks: int) -> void:
	if stacks <= 0:
		_stacks.erase(buff)
		_arrival.erase(buff)
	else:
		if not _stacks.has(buff):
			_arrivals += 1
			_arrival[buff] = _arrivals
		_stacks[buff] = stacks
	queue_redraw()


## 103：标准轴的内容层（带符号）。0 就收起这一格
func set_axis(axis: String, stacks: int) -> void:
	var id := AXIS_PREFIX + axis
	if stacks == 0:
		_stacks.erase(id)
		_arrival.erase(id)
	else:
		if not _stacks.has(id):
			_arrivals += 1
			_arrival[id] = _arrivals
		_stacks[id] = stacks
	queue_redraw()


## 103：加时叠了几次（「鏖战 ×n」格，说明受到伤害轴系统层的来源）
func set_overtime(count: int) -> void:
	set_stacks(OVERTIME_CHIP, count)


func axis_value(axis: StringName) -> int:
	return int(_stacks.get(AXIS_PREFIX + String(axis), 0))


func mark_dead() -> void:
	_dead = true
	queue_redraw()


func note_fired(uid: int, now: float) -> void:
	_last_fired = String(item_names.get(uid, "uid %d" % uid))
	_fired_at = now
	queue_redraw()


## 飘字。伤害为正、治疗为负，颜色按伤害类型。
func popup(amount: int, type: StringName, heal: bool = false, crit: bool = false) -> void:
	var l := Label.new()
	l.text = ("+%d" % amount) if heal else (("-%d!" if crit else "-%d") % amount)
	# 104：暴击的飘字大一号、换色
	l.add_theme_font_size_override("font_size", (28 if crit else 20) if amount >= 10 else (22 if crit else 16))
	# 121 特例：飘字（字号按数大小、颜色按伤害类型 / 暴击 / 治疗），画布那一类，不进主题
	l.add_theme_color_override("font_color", UiPalette.HEAL if heal else (UiPalette.CRIT if crit else UiPalette.damage_color(type)))
	l.position = Vector2(
		PAD + randf_range(0.0, size.x - PAD * 2 - 40), size.y * 0.45 + randf_range(-8.0, 8.0)
	)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 42.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
#endregion


func _ordered_keys() -> Array:
	var known: Array = []
	var rest: Array = []
	for key in _resources:
		if ORDER.has(key):
			known.append(key)
		else:
			rest.append(key)
	known.sort_custom(func(a, b): return ORDER.find(a) < ORDER.find(b))
	rest.sort()
	known.append_array(rest)
	return known


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.PANEL)
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.LINE, false, 1.0)
	if label_font == null:
		return

	var y := float(PAD)
	var title := display_name + ("　【倒下】" if _dead else "")
	draw_string(
		label_font, Vector2(PAD, y + 14), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		UiPalette.DIM if _dead else UiPalette.FG
	)
	y += 26

	for key in _ordered_keys():
		if key == SHIELD_KEY:
			continue     # 106：护盾画在生命条外面，不占一条
		var pair: Array = _resources[key]
		var cur: int = pair[0]
		var cap: int = pair[1]
		if cap <= 0:
			continue
		_draw_bar(key, cur, cap, y)
		if key == "hp":
			_draw_shield_frame(y)
		y += BAR_H + BAR_GAP

	_chips.clear()
	if not _stacks.is_empty() or not passives.is_empty():
		y += 4
		var x := float(PAD)
		for id in ordered_ids():
			var def: BuffDef = buff_defs.get(StringName(String(id)), null)
			var text := chip_text(String(id))
			var w := label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14
			if x + w > size.x - PAD:
				x = PAD
				y += CHIP_H + 4
			var rect := Rect2(x, y, w, CHIP_H)
			# 103：四种配色 —— 系统（琥珀）、减益（红）、增益（蓝）、常驻（灰）
			var line := UiPalette.SHIELD
			var group := _group_of(String(id))
			if passive_of(String(id)) != null:
				line = UiPalette.DIM
			elif group == 0:
				line = SYSTEM_COLOR
			elif group == 1:
				line = UiPalette.HP
			draw_rect(rect, Color(line, 0.3))
			draw_rect(rect, line, false, 1.0 if String(id) != _hover_id else 2.0)
			draw_string(
				label_font, Vector2(x + 7, y + 14), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.FG
			)
			_chips.append([rect, String(id)])
			x += w + 6

	if _last_fired != "":
		draw_string(
			label_font, Vector2(PAD, size.y - PAD), "▸ " + _last_fired,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.DIM
		)


## 现在的护盾值（显示值；没有就 0）
func shield_value() -> int:
	var pair: Array = _resources.get(SHIELD_KEY, [0, 0])
	return int(pair[0])


## 106：护盾框占生命条的几成 —— `护盾 / 生命上限`，护盾 ≥ 上限时 1（整条框满）。
## 生命上限为 0 的假人返回 0，不画框
func shield_frame_ratio() -> float:
	var hp: Array = _resources.get("hp", [0, 0])
	var cap := int(hp[1])
	if cap <= 0 or shield_value() <= 0:
		return 0.0
	return clampf(float(shield_value()) / float(cap), 0.0, 1.0)


## 106（作者定）：生命条外侧的一圈粗白框，长度 = [method shield_frame_ratio] × 条宽。
## 只盖一部分时画成开口的框：上、下、左三边到那个长度为止，右端一道竖边收口
func _draw_shield_frame(y: float) -> void:
	var ratio := shield_frame_ratio()
	if ratio <= 0.0:
		return
	var w := size.x - PAD * 2
	var half := FRAME_W * 0.5
	var left := PAD - half
	var top := y - half
	var bottom := y + BAR_H + half
	var right := left + (w + FRAME_W) * ratio
	var c := UiPalette.SHIELD_FRAME
	draw_line(Vector2(left, top), Vector2(right, top), c, FRAME_W)
	draw_line(Vector2(left, bottom), Vector2(right, bottom), c, FRAME_W)
	draw_line(Vector2(left, top), Vector2(left, bottom), c, FRAME_W)
	draw_line(Vector2(right, top), Vector2(right, bottom), c, FRAME_W)


func _draw_bar(key: String, current: int, maximum: int, y: float) -> void:
	var w := size.x - PAD * 2
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)

	draw_rect(Rect2(PAD, y, w, BAR_H), UiPalette.BG)
	if ratio > 0.0:
		draw_rect(Rect2(PAD, y, w * ratio, BAR_H), UiPalette.resource_color(key))
	draw_rect(Rect2(PAD, y, w, BAR_H), UiPalette.LINE, false, 1.0)

	var text := "%s  %d / %d" % [key, current, maximum]
	if key == "hp" and shield_value() > 0:
		text += "　盾 %d" % shield_value()     # 106：护盾的数写在生命条上，框只说明它顶得住几成
	draw_string(
		label_font, Vector2(PAD + 6, y + BAR_H - 4), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.FG
	)

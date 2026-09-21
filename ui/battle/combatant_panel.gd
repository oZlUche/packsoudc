## 一方战斗单位的面板：资源条 + 增益层数 + 飘字。
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

## 资源条的显示顺序。没列出的排在后面，按字典序 —— 顺序稳定，界面才不会乱跳。
const ORDER := ["hp", "shield", "stamina", "mana", "power"]

var display_name: String = ""
var label_font: Font

## key -> [current, max]。
##
## [b]单位是取整后的显示值，不是定点。[/b] 两个来源的单位本来不一致 ——
## 快照（ResourcePool.snapshot）已经取过整，而事件载荷是定点 ——
## 换算统一在 [BattleView] 那一层做完，面板这里只管画。
## 混着用的后果是血条显示 0 / 0 却画成满格，而且只在其中一条路径上出现。
var _resources: Dictionary = {}
## buff id -> 层数
var _stacks: Dictionary = {}
var _dead: bool = false
## 最近一次出手的物品名，给一点「谁在动」的反馈
var _last_fired: String = ""
var _fired_at: float = -99.0

## uid -> 显示名。日志里只有 uid，名字是表现层的事。
var item_names: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(320, 190)
	set_process(true)


#region 由回放驱动
func reset(snapshot: Dictionary) -> void:
	_resources.clear()
	_stacks.clear()
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
	else:
		_stacks[buff] = stacks
	queue_redraw()


func mark_dead() -> void:
	_dead = true
	queue_redraw()


func note_fired(uid: int, now: float) -> void:
	_last_fired = String(item_names.get(uid, "uid %d" % uid))
	_fired_at = now
	queue_redraw()


## 飘字。伤害为正、治疗为负，颜色按伤害类型。
func popup(amount: int, type: StringName, heal: bool = false) -> void:
	var l := Label.new()
	l.text = ("+%d" % amount) if heal else ("-%d" % amount)
	if label_font != null:
		l.add_theme_font_override("font", label_font)
	l.add_theme_font_size_override("font_size", 20 if amount >= 10 else 16)
	l.add_theme_color_override("font_color", UiPalette.HEAL if heal else UiPalette.damage_color(type))
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
		var pair: Array = _resources[key]
		var cur: int = pair[0]
		var cap: int = pair[1]
		if cap <= 0:
			continue
		_draw_bar(key, cur, cap, y)
		y += BAR_H + BAR_GAP

	if not _stacks.is_empty():
		y += 4
		var x := float(PAD)
		var ids := _stacks.keys()
		ids.sort()  # 顺序稳定，免得每帧重排
		for id in ids:
			var text := "%s ×%d" % [id, _stacks[id]]
			var w := label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14
			if x + w > size.x - PAD:
				x = PAD
				y += CHIP_H + 4
			draw_rect(Rect2(x, y, w, CHIP_H), UiPalette.LINE)
			draw_string(
				label_font, Vector2(x + 7, y + 14), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.FG
			)
			x += w + 6

	if _last_fired != "":
		draw_string(
			label_font, Vector2(PAD, size.y - PAD), "▸ " + _last_fired,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.DIM
		)


func _draw_bar(key: String, current: int, maximum: int, y: float) -> void:
	var w := size.x - PAD * 2
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)

	draw_rect(Rect2(PAD, y, w, BAR_H), UiPalette.BG)
	if ratio > 0.0:
		draw_rect(Rect2(PAD, y, w * ratio, BAR_H), UiPalette.resource_color(key))
	draw_rect(Rect2(PAD, y, w, BAR_H), UiPalette.LINE, false, 1.0)

	var text := "%s  %d / %d" % [key, current, maximum]
	draw_string(
		label_font, Vector2(PAD + 6, y + BAR_H - 4), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.FG
	)

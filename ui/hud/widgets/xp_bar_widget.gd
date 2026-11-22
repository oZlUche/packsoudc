## 381 / 382（作者定）：顶端栏下沿一根全屏宽的透明经验值条 —— 高 10，烟色透明底、顶上一道亮线、下沿一道淡墨线，
## 琥珀色按这一级的进度从左往右灌。条上不写字；停上去和等级格同一个悬浮窗。欠着选牌时整条慢慢发亮。
## 宿主（[HudHost]）贴着栏下沿摆它、宽度铺满，排在栏底下一层，日晷压在它上面
extends HudWidget

const HEIGHT := 10.0
const GLASS := Color(0.16, 0.12, 0.09, 0.32)
const SHINE := Color(1, 1, 1, 0.55)
const INK := Color(0.18, 0.13, 0.1, 0.6)
const AMBER := Color("e0a43a")
## 待选时发亮的周期（秒）
const PULSE := 2.4

var _t := 0.0
## 条画在这块子控件上（本件的 self_modulate 压掉了通用凹槽，也会压掉本件自己画的）
var _glass: Control


func _init() -> void:
	super()
	custom_minimum_size = Vector2(0, HEIGHT)
	self_modulate.a = 0.0     # 不画通用凹槽：条自己画
	_text.visible = false
	_glass = Control.new()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.draw.connect(_draw_glass)
	add_child(_glass)


func title() -> String:
	return "经验值"


func _module() -> LevelModule:
	return LevelModule.of(run) if run != null else null


func watch() -> Array[Signal]:
	var lv := _module()
	return ([lv.level_changed] if lv != null else []) as Array[Signal]


## 不写字；返回非空只为让这件显示（没有局内成长模块时藏起来）
func text_of() -> String:
	return " " if _module() != null else ""


func fill() -> float:
	var lv := _module()
	if lv == null:
		return 0.0
	var p := lv.progress()
	return 1.0 if p.y <= 0 else clampf(float(p.x) / float(p.y), 0.0, 1.0)


func set_tier(t: Tier) -> void:
	super(t)
	custom_minimum_size.y = HEIGHT


func refresh() -> void:
	super()
	var lv := _module()
	set_process(lv != null and lv.pending() > 0)
	_glass.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_glass.queue_redraw()


## 现在发亮几成（0..1；不欠选牌 0）
func glow() -> float:
	var lv := _module()
	if lv == null or lv.pending() <= 0:
		return 0.0
	return 0.5 + 0.5 * sin(_t * TAU / PULSE)


## 条贴着本件的上沿画，高 [constant HEIGHT]（本件的凹槽内边距可能比它高，下面那截是空的）
func _draw_glass() -> void:
	var r := Rect2(-_glass.position, Vector2(size.x, HEIGHT))     # 子控件被凹槽的内边距挪开了：画回本件的左上
	_glass.draw_rect(r, GLASS)
	var f := fill()
	if f > 0.0:
		_glass.draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), AMBER.lightened(0.25 * glow()))
	_glass.draw_line(r.position + Vector2(0, 0.5), Vector2(r.end.x, r.position.y + 0.5), SHINE, 1.0)
	_glass.draw_line(Vector2(r.position.x, r.end.y - 0.5), r.end - Vector2(0, 0.5), INK, 1.0)


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_entered.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		var lw: Node = host.widgets.get(&"level", null) if host != null else null
		if tip != null and lw != null and not editing:
			tip.show_text(lw.call("tip_text"), get_global_mouse_position() + Vector2(0, 14)))
	mouse_exited.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.release())

## 150：信仰 + 信力 + 阶（087 / 082）；停上去开悬浮窗（具体效果、信力怎么涨），用所在屏的那个悬浮窗
extends HudWidget


func title() -> String:
	return "信仰"


func watch() -> Array[Signal]:
	return ([run.faith_power.changed] if run.faith_power != null else []) as Array[Signal]


func text_of() -> String:
	var line := run.faith_power.line() if run.faith_power != null else ""
	return run.faith_line() + ("　" + line if line != "" else "")


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_entered.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null and run != null and not editing:
			var items: ItemDatabase = screen.flow.items if screen.get("flow") != null else null
			tip.show_text(FaithTooltip.describe(run.active_faith(), run.faith_power, items), global_position + Vector2(0, size.y)))
	mouse_exited.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.hide_tip())

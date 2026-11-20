## 340：火、冰、雷暴击与一次反应暴击的飘字截图（xvfb-run godot --path . --script res://docs/reports/340-shots/crit_shot.gd）
extends SceneTree

var _frames := 0
var _panel: CombatantPanel


func _initialize() -> void:
	root.size = Vector2i(720, 260)
	var bg := ColorRect.new()
	bg.color = UiPalette.PANEL
	bg.size = Vector2(720, 260)
	root.add_child(bg)
	_panel = CombatantPanel.new()
	_panel.size = Vector2(720, 260)
	root.add_child(_panel)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		seed(7)
		var xs := [40.0, 200.0, 360.0, 520.0]
		var rows := [[&"fire", []], [&"ice", []], [&"lightning", []], [&"fire", [UiPalette.damage_color(&"fire"), UiPalette.damage_color(&"ice")]]]
		for i in rows.size():
			var l := _panel.popup(28, rows[i][0], false, true, 1.0, rows[i][1])
			l.position = Vector2(xs[i], 120.0)
			var tw := l.get_meta(&"tween") as Tween
			tw.kill()
			l.scale = Vector2.ONE
			l.modulate.a = 1.0
			var h := _panel.popup(7, rows[i][0], false, false, 1.0, rows[i][1])
			h.position = Vector2(xs[i] + 10.0, 190.0)
			(h.get_meta(&"tween") as Tween).kill()
		var r := _panel.popup_text("冰火", UiPalette.damage_color(&"fire"), 1.0, [UiPalette.damage_color(&"fire"), UiPalette.damage_color(&"ice")])
		r.position = Vector2(520.0, 40.0)
		(r.get_meta(&"tween") as Tween).kill()
	if _frames == 8:
		var img := root.get_texture().get_image().get_region(Rect2i(0, 0, 720, 260))
		img.save_png(OS.get_environment("SHOT_OUT") if OS.has_environment("SHOT_OUT") else "user://crit_shot.png")
		quit()
	return false

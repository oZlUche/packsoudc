## 342 B1 探针：基地六个页签在各语言 / 字号 / 分辨率下的样子；每个页签截一张，量页签列、科技页有没有出屏。
## 参数：<outdir> <lang zh|en> <text small|medium|large> <宽x高>
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 --script res://docs/reports/testing/evidence/2026-11-20-base-nav-b1/b1_probe.gd -- out zh large 1600x1000
## 日志行以「B1」开头。存档写在 user://b1_*，不碰玩家存档。
extends CliTool

const GAME := "res://ui/game/game.tscn"

var out := "/tmp/b1"
var lang := "zh"
var text := "medium"
var size := Vector2i(1600, 1000)
var d: GameDirector = null
var flow: GameFlow = null
var f := 0
var tabs: Array = []
var bad := 0


func run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: lang = a[1]
	if a.size() > 2: text = a[2]
	if a.size() > 3:
		var p := a[3].split("x")
		size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out)
	for p in ["user://b1_run.json", "user://b1_meta.json", "user://b1_settings.json"]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var s := FileAccess.open("user://b1_settings.json", FileAccess.WRITE)
	s.store_string(JSON.stringify({"version": GameSettings.SAVE_VERSION, "language": lang, "text_size": text, "ui_fades": false, "window_mode": "windowed"}))
	s.close()
	GameDirector.fades_allowed = false


func L(t: String) -> void:
	print("B1 " + t)


func tick(_dt: float) -> bool:
	f += 1
	if f == 2:
		d = (load(GAME) as PackedScene).instantiate()
		d.save_path = "user://b1_run.json"
		d.meta_path = "user://b1_meta.json"
		d.settings_path = "user://b1_settings.json"
		root.add_child(d)
		current_scene = d
		flow = d.flow
		return false
	if f == 6:
		DisplayServer.window_set_size(size)
		root.size = size
	if f == 10:
		for c in flow.tutorial_chapters():
			flow.meta.grant_unlock(c.hidden_by_unlock)
		flow.meta.funds = 900
		flow.show_meta()
		return false
	if f == 20:
		var screen: Control = d.base()
		tabs = (screen.get("_tab_btns") as Dictionary).keys()
		L("页签 %s" % [tabs])
		var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		for k in tabs:
			var b := (screen.get("_tab_btns") as Dictionary)[k] as Button
			if not vp.encloses(b.get_global_rect()):
				bad += 1
				L("出屏 页签 %s %s" % [k, b.get_global_rect()])
	if f >= 30 and (f - 30) % 15 == 0:
		var i := (f - 30) / 15
		var screen: Control = d.base()
		if i > 0:
			var prev: String = tabs[i - 1]
			var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
			var page: Control = (screen.get("_pages") as Dictionary).get(prev, null)
			if prev == "tech" and page != null:
				var tp: Control = screen.call("tech_panel")
				var r := tp.get_global_rect()
				L("科技页 %s 视口 %s 最小 %s" % [r, vp.size, tp.get_combined_minimum_size()])
				if not vp.grow(1.0).encloses(r):
					bad += 1
					L("出屏 科技页")
			var img := root.get_texture().get_image()
			img.save_jpg("%s/%d_%s.jpg" % [out, i, prev], 0.85)
		if i >= tabs.size():
			L("结束 出屏 %d" % bad)
			finish(0)
			return true
		screen.call("show_tab", tabs[i])
	return false

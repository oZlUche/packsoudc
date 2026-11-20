## 委托页 A 告示板探针：新档教程走完进基地，截剧情 / 声望 / 常规三个子页和没开放的集市说明板；再办完后勤许可单看告示栏。
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 --script res://docs/reports/testing/evidence/2026-11-20-commission-board/board_probe.gd -- out zh
## 存档写在 user://cb_*，不碰玩家存档。
extends CliTool

const GAME := "res://ui/game/game.tscn"

var out := "/tmp/cb"
var lang := "zh"
var d: GameDirector = null
var flow: GameFlow = null
var f := 0
var shots := ["story", "reputation", "regular", "market", "board"]


func run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: lang = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	for p in ["user://cb_run.json", "user://cb_meta.json", "user://cb_settings.json"]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var s := FileAccess.open("user://cb_settings.json", FileAccess.WRITE)
	s.store_string(JSON.stringify({"version": GameSettings.SAVE_VERSION, "language": lang, "text_size": "medium", "ui_fades": false, "window_mode": "windowed"}))
	s.close()
	GameDirector.fades_allowed = false


func tick(_dt: float) -> bool:
	f += 1
	if f == 2:
		d = (load(GAME) as PackedScene).instantiate()
		d.save_path = "user://cb_run.json"
		d.meta_path = "user://cb_meta.json"
		d.settings_path = "user://cb_settings.json"
		root.add_child(d)
		current_scene = d
		flow = d.flow
		return false
	if f == 6:
		DisplayServer.window_set_size(Vector2i(1600, 1000))
		root.size = Vector2i(1600, 1000)
	if f == 10:
		for c in flow.tutorial_chapters():
			flow.meta.grant_unlock(c.hidden_by_unlock)
		flow.meta.commissions.gated = true
		flow.show_meta()
		return false
	if f >= 20 and (f - 20) % 15 == 0:
		var i := (f - 20) / 15
		var screen: Control = d.base()
		if i > 0:
			root.get_texture().get_image().save_jpg("%s/%d_%s.jpg" % [out, i, shots[i - 1]], 0.85)
		if i >= shots.size():
			print("CB 结束")
			finish(0)
			return true
		var key: String = shots[i]
		if key == "market":
			screen.call("show_tab", "market")
		elif key == "board":
			var book := flow.meta.commissions
			for id in [&"legion_forge_token", &"legion_check_materials", &"legion_clear_road", &"legion_permit"]:
				book.entries[String(id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}
			book.rep["legion"] = 25
			flow.sync_commissions()
			screen.call("show_tab", "commissions")
			var p: Control = screen.call("commission_panel")
			var ids := NoticeBoard.posted(book)
			if not ids.is_empty():
				p.call("take", StringName(ids[0]))
			p.call("show_sub", "regular")
		else:
			screen.call("show_tab", "commissions")
			(screen.call("commission_panel") as Control).call("show_sub", key)
	return false

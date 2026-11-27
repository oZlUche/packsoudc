extends SceneTree
## 交货自选（作者 2026-11-27）：营地委托页 → 《查验材料》【交货】→ 交货窗截图（没选 / 选了两件）。参数 <outdir>
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const T110 := preload("res://tests/meta/test_tech.gd")
var out := ""
var _s: Control
var _f := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var f := W178._flow()
	var book := f.meta.commissions
	book.entries["legion_forge_token"] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}
	book.rep["legion"] = 10
	f.sync_commissions()
	for id in [&"iron_ore", &"iron_ore", &"copper_ingot", &"nail_keg", &"mithril_ingot", &"copper_ore"]:
		T110._add(f.meta, f.items, id)
	_s = W178._screen(f, root)
	_s.show_tab("commissions")
	_s.commission_panel().show_faction(&"legion")
	(_s.commission_panel().find_child("Report_legion_check_materials", true, false) as Button).pressed.emit()


func _process(_d: float) -> bool:
	_f += 1
	if _f == 20:
		root.get_texture().get_image().save_png(out + "/hand_in_empty.png")
		var ch := Commissions.hand_in_choices(_s.flow.meta, Commissions.def(&"legion_check_materials"), 0)
		_s.toggle_hand_in(ch[ch.size() - 1].uid)
		_s.fill_hand_in()
	if _f == 40:
		root.get_texture().get_image().save_png(out + "/hand_in_filled.png")
		W178._cleanup()
		return true
	return false

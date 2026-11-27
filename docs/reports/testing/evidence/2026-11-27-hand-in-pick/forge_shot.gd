extends SceneTree
## 打造自选料（作者 11-27 答 77）：铁匠铺《短剑》【打造】→ 选料窗截图（没挑 / 填满）。参数 <outdir>
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
	f.meta.tech_levels = {"bargain": 1, "warehouse": 1, "safe_box": 1, "pack": 1, "market": 0, "smithy": 0}
	f.derive_techs()
	f.smith_recipes = SmithRecipeDef.load_all()
	f.meta.funds = 1000
	for id in [&"hardwood_plank", &"hardwood_plank", &"iron_ore", &"iron_ore", &"iron_ore", &"iron_ore", &"iron_ore", &"iron_ore"]:
		T110._add(f.meta, f.items, id)
	_s = W178._screen(f, root)
	_s.show_tab("smithy")
	(_s.smithy_panel().forge_button(&"smith_shortsword") as Button).pressed.emit()


func _process(_d: float) -> bool:
	_f += 1
	if _f == 20:
		root.get_texture().get_image().save_png(out + "/forge_pick_empty.png")
		_s.fill_forge_pick()
	if _f == 40:
		root.get_texture().get_image().save_png(out + "/forge_pick_filled.png")
		W178._cleanup()
		return true
	return false

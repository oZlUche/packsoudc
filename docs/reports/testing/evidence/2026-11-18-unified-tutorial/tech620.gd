## 游戏测试 v6.20（报告 319 A+B 双科技树）：参数 <outdir> <fresh|old>
##   fresh：新档，给 6 点见识，开书架科技窗：数值 / 机制两枚页签，机制树升行囊（花见识），选数值树节点自动换页签
##   old  ：把 tests/fixtures/meta_v4.json 放进第 1 位再开游戏，记钱、讨价 / 幸运级数、迁移记录、.v4.bak，再看科技窗
extends CliTool

var out := "/tmp/claude-0/tech620"
var mode := "fresh"
var d: GameDirector = null
var f := 0
var step := 0
var lines: Array[String] = []
var tp = null


func run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	if mode == "old":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://slots/1"))
		var txt := FileAccess.get_file_as_string("res://tests/fixtures/meta_v4.json")
		var fw := FileAccess.open("user://slots/1/meta.json", FileAccess.WRITE)
		fw.store_string(txt)
		fw = null
		L("放进旧档 v4（%d 字节）" % txt.length())
	GameDirector.fades_allowed = false
	d = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(d)
	current_scene = d


func L(s: String) -> void:
	print("TK " + s)
	lines.append(s)


func shot(n: String) -> void:
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("%s/%s_%s.png" % [out, mode, n])


func top():
	return d.overlay() if d.overlay() != null else d.base()


func _tabs_text() -> String:
	var t := []
	for id in TechDef.TREES:
		var b: Button = tp.tree_tab(id)
		t.append("%s「%s」%s" % [id, b.text if b != null else "?", "按下" if b != null and b.button_pressed else ""])
	return "；".join(t)


func _tree_ids() -> Array:
	var out_ := []
	for def in tp.tree().defs: out_.append(String(def.id))
	return out_


func click(b: Control) -> void:
	var c := root.get_final_transform() * (b.get_global_rect().get_center())
	Input.warp_mouse(c)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)


func _trk() -> String:
	var b: Button = tp.track_button()
	return "按钮 %s；存档追踪「%s」；小纸那行「%s」" % ["不摆" if b == null else "「%s」" % b.text, String(d.flow.meta.tracked_tech), d.flow.tech_target_line()]


func tick_track() -> bool:
	var flow: GameFlow = d.flow
	match step:
		0: flow.show_meta()
		1:
			flow.meta.insight = 6
			top().show_tab("tech")
		2:
			tp = top().tech_panel()
			L("选仓库扩建 %s：%s" % [str(tp.select(&"warehouse")), _trk()])
			shot("01_warehouse_before")
			click(tp.track_button())
		3:
			L("点追踪后：%s" % _trk())
			shot("02_warehouse_tracked")
			click(tp.track_button())
		4:
			L("再点一次：%s" % _trk())
			tp.show_tree(TechDef.TREE_MECHANISM)
			L("选讨价 %s：%s" % [str(tp.select(&"bargain")), _trk()])
			click(tp.track_button())
		5:
			L("追踪讨价：%s" % _trk())
			shot("03_bargain_tracked")
			flow.meta.insight = 20
			L("见识给到 20：%s" % flow.tech_target_line())
			var m = flow.meta
			for id in [&"pack"]:
				while flow.upgrade_tech(id): pass
			L("行囊升满 %s；选行囊 %s：%s" % [str(m.tech_levels), str(tp.select(&"pack")), _trk()])
			shot("04_pack_maxed")
		_:
			return _end()
	step += 1
	return false


func tick(_dt: float) -> bool:
	f += 1
	if f < 60 or f % 25 != 0:
		return false
	if mode == "track":
		return tick_track()
	var flow: GameFlow = d.flow
	var m = flow.meta
	match step:
		0:
			flow.show_meta()
		1:
			L("局外：钱 %d；见识 %d（得 %d 花 %d）；科技 %s；修复提示「%s」" % [m.funds, m.insight, m.insight_earned, m.insight_spent, str(m.tech_levels), flow.repair_notice()])
			if mode == "old":
				L("迁移记录：%s" % str(m.migration_log))
				L("备份 slots/1/meta.json.v4.bak 在：%s" % str(FileAccess.file_exists("user://slots/1/meta.json.v4.bak")))
				var counts := {}
				for it in m.warehouse.items():
					var k := String((it as ItemInstance).def.id)
					counts[k] = int(counts.get(k, 0)) + 1
				L("仓库里所有东西：%s" % str(counts))
			else:
				m.insight = 6
				L("测试手段：见识设成 6")
			top().show_tab("tech")
		2:
			tp = top().tech_panel()
			L("科技窗：当前树 %s；页签 %s；树里 %s" % [tp.current_tree(), _tabs_text(), str(_tree_ids())])
			shot("01_stat_tree")
			tp.show_tree(TechDef.TREE_MECHANISM)
		3:
			L("机制树：当前树 %s；页签 %s；树里 %s" % [tp.current_tree(), _tabs_text(), str(_tree_ids())])
			var ok: bool = tp.select(&"pack")
			L("选行囊 %s：账目「%s」" % [str(ok), str(tp.panel_texts()).replace("\n", " / ").left(500)])
			shot("02_mech_tree_pack")
		4:
			var before: int = m.insight
			var lv0 := int(m.tech_levels.get("pack", m.tech_levels.get(&"pack", 0)))
			var ok: bool = tp.upgrade(&"pack")
			L("升行囊：%s；见识 %d → %d；行囊 %d → %s；钱 %d；一句「%s」" % [str(ok), before, m.insight, lv0, str(m.tech_levels.get("pack", m.tech_levels.get(&"pack", 0))), m.funds, tp.line_text()])
			shot("03_mech_after_upgrade")
		5:
			var ok: bool = tp.select(&"warehouse")
			L("在机制树选仓库扩建 %s：当前树 %s；页签 %s" % [str(ok), tp.current_tree(), _tabs_text()])
			shot("04_back_to_stat")
		6:
			tp.show_tree(TechDef.TREE_MECHANISM)
			var ok: bool = tp.select(&"bargain")
			L("讨价：%s；账目「%s」" % [str(ok), str(tp.panel_texts()).replace("\n", " / ").left(400)])
			shot("05_mech_bargain")
			var sv: Variant = flow.save_meta()
			L("存局外：%s" % str(sv))
		_:
			return _end()
	step += 1
	return false


func _end() -> bool:
	var fl := FileAccess.open("%s/%s_log.txt" % [out, mode], FileAccess.WRITE)
	fl.store_string("\n".join(lines) + "\n")
	fl = null
	finish(0)
	return false

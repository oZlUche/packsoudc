## 119（作者定）：科技树写成配置表 `docs/techs.xlsx` —— 表读得出十节点二十六级、按表生成的和仓库里的 JSON 一致、
## 坏表每种都进问题清单且一份都不生成（全有或全无）；镜像 `docs/techs.md` 是最新的；开发区数字框直接改进度表（存档的 tech_levels）
extends RefCounted

const META := "user://test_119_meta.json"
const SETTINGS := "user://test_119_settings.json"


static func _sheets() -> Dictionary:
	return XlsxReader.read(TechsTable.PATH)


## 改一格：[param sheet] 里第一列是 [param id]（等级表再加「级」= [param level]）的那一行，[param header] 那一列改成 [param value]
static func _put_cell(sheets: Dictionary, sheet: String, id: String, header: String, value: Variant, level: int = 0) -> bool:
	var rows: Array = sheets[sheet]
	var head: Array = rows[0]
	var col := head.find(header)
	var lv_col := head.find("级")
	for r in range(1, rows.size()):
		var row: Array = rows[r]
		if row.is_empty() or XlsxReader.cell_text(row[0]) != id:
			continue
		if level > 0 and (lv_col >= row.size() or TechsTable._int(row[lv_col]) != level):
			continue
		while row.size() <= col:
			row.append(null)
		row[col] = value
		return true
	return false


static func run(t: TestCase) -> void:
	t.begin("119 · 科技表读得出十节点二十六级；按表生成的和仓库里的一致（含 18 份 tech_* run_buff）；镜像最新；check 无问题")
	var problems: Array[String] = []
	var f := TechsTable.fields(_sheets(), problems)
	t.eq(problems.size(), 0, "表里没问题：%s" % "；".join(PackedStringArray(problems)))
	t.eq(f.size(), 11, "十一个节点（129 加了扛重）")
	var levels := 0
	for id in f:
		levels += (f[id]["tiers"] as Array).size()
	t.eq(levels, 29, "二十九级")
	t.eq(f["scouting"]["requires"], ["luck", "bargain"], "侦察的前置：幸运、讨价")
	t.eq(f["safe_box"]["tiers"][1]["items"], {"nail_keg": 1, "steel_ingot": 1}, "材料按「；」拆成道具 → 件数（122 改成铁钉桶）")
	var out := TechsTable.build(_sheets(), problems)
	t.eq(out.size(), 32, "生成 11 份科技 + 21 份 run_buff")
	var same := 0
	for path in out:
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and ContentCheck._diff_path(json.data, out[path], "") == "":
			same += 1
		else:
			t.check(false, "%s 和表生成的不一致" % path)
	t.eq(same, out.size(), "每份都和仓库里的一致")
	var luck: Dictionary = out[ContentPaths.authoring_file("run_buffs", "tech_luck_3")]
	t.eq(luck["effects"][0]["type"], "luck_bonus", "tech_luck_3：效果类型取节点的 effect")
	t.eq(luck["scope"], "META", "tech_luck_3：局外")
	t.eq(out[ContentPaths.authoring_file("techs", "luck")]["effect"]["buffs"], ["tech_luck_1", "tech_luck_2", "tech_luck_3"], "节点的 effect.buffs 由工具填")
	t.eq(TechsTable.markdown(f), FileAccess.get_file_as_string(TechsTable.MIRROR), "docs/techs.md 是按表生成的最新镜像")
	t.check(TechsTable.markdown(f).contains("源是 `docs/techs.xlsx`"), "镜像头一段写明源是 xlsx")
	var left := TechsTable.check()
	t.eq(left.size(), 0, "check：表与 JSON 一致：%s" % "；".join(PackedStringArray(left)))


static func run_bad_tables(t: TestCase) -> void:
	t.begin("119 · 坏表：级号断档、前置不存在、前置成环、构件未注册、材料不是道具、JSON 格解析不了、同 id 两行 —— 每种都进问题清单，一份都不生成")
	var cases := [
		["级号断档", func(s): return _put_cell(s, "等级", "warehouse", "级", 7.0, 3), "连续"],
		["前置不存在", func(s): return _put_cell(s, "节点", "pack", "前置", "nope"), "nope"],
		["前置成环", func(s): return _put_cell(s, "节点", "warehouse", "前置", "pack"), "成环"],
		["构件未注册", func(s): return _put_cell(s, "节点", "warehouse", "效果构件", "fly_rows"), "fly_rows"],
		["材料不是道具", func(s): return _put_cell(s, "等级", "safe_box", "材料", "unobtainium: 2", 2), "unobtainium"],
		["材料件数不对", func(s): return _put_cell(s, "等级", "safe_box", "材料", "steel_ingot: 0", 2), "steel_ingot: 0"],
		["JSON 格解析不了", func(s): return _put_cell(s, "等级", "pack", "效果参数（JSON）", "{amount: 50", 1), "不是 JSON"],
		["run_buff 效果没注册", func(s): return _put_cell(s, "节点", "luck", "构件参数（JSON）", "{\"effect\": \"luckier\"}"), "luckier"],
		["钱是负的", func(s): return _put_cell(s, "等级", "bargain", "钱", -5.0, 1), "钱"],
		["模板写死数字", func(s): return _put_cell(s, "节点", "pack", "每级说明模板", "开局钱 +50"), "写死"],
	]
	for c in cases:
		var sheets := _sheets()
		t.check((c[1] as Callable).call(sheets), "%s：改到了那一格" % c[0])
		_expect_bad(t, sheets, c[0], c[2])
	var dup := _sheets()
	(dup["节点"] as Array).append(((dup["节点"] as Array)[1] as Array).duplicate())
	_expect_bad(t, dup, "同 id 两行", "两行")


static func _expect_bad(t: TestCase, sheets: Dictionary, label: String, needle: String) -> void:
	var problems: Array[String] = []
	var out := TechsTable.build(sheets, problems)
	var text := "；".join(PackedStringArray(problems))
	t.check(text.contains(needle), "%s：问题清单里有「%s」：%s" % [label, needle, text])
	t.eq(out.size(), 0, "%s：一份都不生成" % label)


static func frame_dev_levels(t: TestCase, root: Window) -> void:
	t.begin("119 · 开发区「科技等级」：每个科技一个数字框；改了直接写存档的 tech_levels，局外 buff / 保险箱跟着重算，夹在 0 ～ 满级")
	var db := ItemDatabase.new()
	db.load_dir()
	var m := MetaState.new(GameFlow.load_meta_rules())
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), m)
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	f.buff_defs = RunBuffs.load_all()
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	var spin: SpinBox = screen.tech_level_spin(&"sinew")
	t.not_null(spin, "筋骨有数字框")
	t.eq(int(spin.max_value), 3, "上限 = 满级")
	spin.value = 2
	t.eq(TechService.level(m, &"sinew"), 2, "数字框改成 2：存档里筋骨 2 级")
	t.check(m.tech_buffs.has(&"tech_sinew_2") and not m.tech_buffs.has(&"tech_sinew_1"), "局外 buff 换成第 2 级的")
	t.eq(screen.set_tech_level(&"sinew", 0), 0, "改回 0")
	t.check(not m.tech_levels.has("sinew") and not m.tech_buffs.has(&"tech_sinew_2"), "0 级：进度表里没这项、buff 也撤了")
	t.eq(screen.set_tech_level(&"safe_box", 99), 2, "超过满级夹到 2")
	var per := f.tech_of(&"safe_box").effect as TechSafeSize
	t.eq(m.safe_bonus, Vector2i(per.cols, per.rows) * 2, "保险箱扩格 2 级：每级的格子 × 2")
	t.eq(int(screen.tech_level_spin(&"safe_box").value), 2, "数字框跟着显示 2")
	screen.set_tech_level(&"safe_box", 1)
	t.eq(m.safe_bonus, Vector2i(per.cols, per.rows), "降到 1 级：保险箱跟着缩回一级的格子")
	t.check(FileAccess.file_exists(META), "改了就存档")
	screen.queue_free()
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)

extends SceneTree
## 游戏测试 v9.30（PR #1006）：36 件新图 —— 清单、道具库、1x/@2x 尺寸 = 形状包围盒 × 60 / 160、有不透明像素；全库还缺图的道具
const IDS := ["beast_haunch", "beast_king_pact", "beast_king_pact_spent", "beast_ribs", "big_pumpkin", "bitter_endive", "black_bean", "cabbage", "coarse_wheat_bundle", "fat_fowl", "fat_fowl_leg", "fowl_leg", "fowl_wing", "fragrant_root", "game_meat", "golden_wheat", "honey_pomelo", "honeydew", "jade_yam", "long_scallion", "meat_scrap", "mountain_pear", "mountain_yam", "prime_beast_leg", "prime_game_meat", "rally_horn", "rally_horn_spent", "red_berry_cluster", "rice_sack", "sour_wheat", "spare_mainspring", "spare_mainspring_spent", "turnip", "whole_fowl", "wild_berry", "wild_scallion"]


func _opaque(img: Image) -> float:
	var n := 0
	var tot := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			tot += 1
			if img.get_pixel(x, y).a > 0.5: n += 1
	return float(n) / maxf(1.0, float(tot))


func _initialize() -> void:
	var db := ItemDatabase.new()
	db.load_dir()
	var bad := 0
	var listed := ItemPainter.art_ids()
	print("HC 清单 %d 件，道具库 %d 件" % [listed.size(), db.all_ids().size()])
	for id in IDS:
		var d := db.get_def(StringName(id))
		if d == null: print("HC BAD %s 道具库没有" % id); bad += 1; continue
		var sz: Vector2i = d.shape.size_rotated(0)
		var t1 := ItemPainter.art_of(d, 60.0)
		var t2 := ItemPainter.art_of(d, 100.0)
		var ok := listed.has(StringName(id)) and t1 != null and t2 != null
		var s1 := t1.get_size() if t1 != null else Vector2.ZERO
		var s2 := t2.get_size() if t2 != null else Vector2.ZERO
		if s1 != Vector2(sz) * 60.0 or s2 != Vector2(sz) * 160.0: ok = false
		var o1 := _opaque(t1.get_image()) if t1 != null else 0.0
		var o2 := _opaque(t2.get_image()) if t2 != null else 0.0
		if o1 < 0.1 or o2 < 0.1: ok = false
		if not ok: bad += 1
		var tags := ",".join(PackedStringArray(Array(d.tags).map(func(x): return String(x))))
		print("HC %s %s（%s / %s）形状 %s 稀有 %d 价值 %d 标签 [%s] | 1x %s 不透明 %.0f%% | 2x %s 不透明 %.0f%% | 说明「%s」" % ["ok " if ok else "BAD", id, d.display_name, String(d.display_names.get("en", "")), str(sz), d.rarity, d.value, tags, str(s1), o1 * 100, str(s2), o2 * 100, d.description])
	# 失效版和原版：图不同
	for base in ["beast_king_pact", "rally_horn", "spare_mainspring"]:
		var a := ItemPainter.art_of(db.get_def(StringName(base)), 100.0).get_image()
		var b := ItemPainter.art_of(db.get_def(StringName(base + "_spent")), 100.0).get_image()
		var same := a.get_size() == b.get_size() and a.get_data() == b.get_data()
		var da := db.get_def(StringName(base)); var dbb := db.get_def(StringName(base + "_spent"))
		print("HC 失效对照 %s：形状 %s / %s，图%s" % [base, str(da.shape.size_rotated(0)), str(dbb.shape.size_rotated(0)), "一样（BAD）" if same else "不同"])
		if same: bad += 1
	# 全库缺图
	var miss := []
	for id in db.all_ids():
		var d := db.get_def(id)
		if ItemPainter.art_id_of(d) == &"": miss.append(String(id))
	print("HC 全库没图的 %d 件：%s" % [miss.size(), str(miss)])
	# v9.31：键名
	InputKeys.ensure()
	print("HC 键：逆时针 %s 顺时针 %s；旧 rotate_item 还在 InputMap：%s" % [KeyNames.of(InputKeys.ROTATE_CCW), KeyNames.of(InputKeys.ROTATE_CW), str(InputMap.has_action(&"rotate_item"))])
	for f in ["res://data/authoring/npcs/common.json", "res://data/authoring/coach/prologue_bag.json", "res://data/authoring/coach/prologue_map.json"]:
		var raw := FileAccess.get_file_as_string(f)
		var rx := RegEx.create_from_string("\"(text|en)\": \"([^\"]*(rotate|拖动地图|drag the map)[^\"]*)\"")
		for m in rx.search_all(raw):
			var t := KeyNames.expand(m.get_string(2))
			print("HC 台词 %s：%s" % [f.get_file(), t])
			if t.contains("[key=") or t.contains("未绑定") or t.contains("Unbound"): bad += 1; print("HC BAD 没换成键名")
	print("HC 完 bad=%d" % bad)
	quit(0)

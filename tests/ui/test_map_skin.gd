## 作者定：每章一张手绘地图当底，风格各不同（ChapterDef.map_skin → assets/maps/<id>.png + json 的 tone）；地图屏铺满画在路网底下，浅纸上字换墨水版
extends RefCounted


static func run(t: TestCase) -> void:
	t.begin("地图底图 · 四章各配一张、图与 json 都在、深浅按 json；铺满裁边的取图区域")
	var want := {"prologue": "ruins", "prologue_2": "north_woods", "prologue_3": "cursed_depths", "free_mode": "imperial_camp"}
	for cid in want:
		var ch := ContentPaths.load_asset("chapters", cid) as ChapterDef
		t.check(ch != null and String(ch.map_skin) == want[cid], "%s 配 %s（%s）" % [cid, want[cid], ch.map_skin if ch != null else "?"])
		t.not_null(MapSkin.texture(StringName(want[cid])), "%s 的图在" % want[cid])
	t.eq(ChapterDef.new().map_skin, MapSkin.DEFAULT, "默认遗迹")
	t.eq(MapSkin.tone(&"cursed_depths"), UiTheme.TONE_DARK, "诅咒之地：深")
	for id in [&"ruins", &"north_woods", &"imperial_camp"]:
		t.eq(MapSkin.tone(id), UiTheme.TONE_LIGHT, "%s：浅" % id)
	t.eq(MapSkin.texture(&"no_such_map"), null, "没这张图：null（照旧石板底）")
	var wide := MapSkin.cover_region(Vector2(1920, 1200), Vector2(1600, 600))
	t.check(is_equal_approx(wide.size.x, 1920.0) and wide.size.y < 1200.0 and is_equal_approx(wide.position.y, (1200.0 - wide.size.y) * 0.5), "扁的区域：宽度用满、上下居中裁")
	var tall := MapSkin.cover_region(Vector2(1920, 1200), Vector2(600, 900))
	t.check(is_equal_approx(tall.size.y, 1200.0) and tall.size.x < 1920.0, "高的区域：高度用满、左右裁")
	t.check(is_equal_approx(wide.size.x / wide.size.y, 1600.0 / 600.0), "取图比例和区域一样（不拉伸）")


static func frame_map_view_skin(t: TestCase, root: Window) -> void:
	t.begin("地图底图 · 地图视图设了底图：浅纸上前景 / 暗色字换墨水版，深底照旧；不设照旧")
	var view := MapView.new()
	root.add_child(view)
	t.check(not view.skin_is_light() and view._ink(UiPalette.FG) == UiPalette.FG, "没底图：字色照旧")
	view.skin = &"ruins"
	t.check(view.skin_is_light(), "遗迹是浅纸")
	t.eq(view._ink(UiPalette.FG), UiTheme.INK, "前景换成墨")
	t.check(UiTheme.contrast(view._ink(UiPalette.HP), UiTheme.PAPER) >= UiTheme.MIN_CONTRAST, "生命红压暗到看得清")
	view.skin = &"cursed_depths"
	t.check(not view.skin_is_light() and view._ink(UiPalette.FG) == UiPalette.FG, "诅咒之地深底：字色照旧")
	view.free()

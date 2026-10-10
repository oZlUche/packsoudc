## 150（作者定，四项待定按推荐）：地图屏的读数拆成组件（[HudWidget]），按布局（[HudLayout]）摆在读数层（[HudHost]）上；
## 没有布局文件 = 150 之前的样子（倒计时顶上居中、读数一排在下面）；调试台里「摆读数」：拖、右键切显隐、滚轮切档、保存 / 重置
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_hud150_run.json"
const META := "user://test_hud150_meta.json"
const SETTINGS := "user://test_hud150_settings.json"
## 测试用的屏名（不碰真的 map 布局文件）
const PROBE := "test_hud150"
const HOST_SIZE := Vector2(1200, 700)


static func run_layout(t: TestCase) -> void:
	t.begin("150 · 布局：默认就是 150 之前的样子；字典往返一致；坏 id / 锚点 / 档位 / 偏移 / 重复都报；文件存取与重置")
	var d := HudLayout.default_for("map")
	t.eq(d.entries.size(), HudWidgets.KINDS.size(), "默认布局把十种都摆上了")
	t.eq(String(d.entry_of(&"countdown")["tier"]), "large", "倒计时是大档")
	t.eq(int(d.entry_of(&"countdown")["line"]), 0, "倒计时在第 0 行")
	for id in [&"action_points", &"vitality", &"wallet", &"faith"]:
		t.eq(int(d.entry_of(id)["line"]), 1, "%s 在倒计时下面那一行" % id)
	for id in HudWidgets.KINDS:
		t.not_null(HudWidgets.create(id), "%s 造得出来" % id)
	t.check(HudWidgets.create(&"nope") == null, "不认识的 id：null")

	var back := HudLayout.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	t.not_null(back, "JSON 往返读得回来")
	if back != null:
		t.eq(back.to_dict(), d.to_dict(), "往返一致")
	var problems: Array[String] = []
	var bad := HudLayout.from_dict({"widgets": [
		{"id": "nope", "anchor": "top"},
		{"id": "vitality", "anchor": "upper_left"},
		{"id": "wallet", "tier": "huge"},
		{"id": "faith", "offset": [1]},
		{"id": "faith"}]}, problems)
	t.check(bad == null, "有错整份不用")
	var text := "\n".join(problems)
	for frag in ["没有这种读数 'nope'", "没有这个锚点 'upper_left'", "档位只有 large / small", "offset 得是两个数", "'faith' 写了两次"]:
		t.check(text.contains(frag), "报：" + frag)
	var none: Array[String] = []
	t.check(HudLayout.from_dict({"widgets": "x"}, none) == null and not none.is_empty(), "widgets 不是列表：报")

	HudLayout.reset(PROBE)
	t.eq(HudLayout.load_for(PROBE).to_dict(), HudLayout.default_for(PROBE).to_dict(), "没有文件：默认")
	var mine := HudLayout.default_for("map")
	mine.screen = PROBE
	mine.entry_of(&"vitality")["anchor"] = "bottom_left"
	mine.entry_of(&"vitality")["offset"] = Vector2(16, -16)
	t.check(mine.save(HudLayout.user_path(PROBE)), "存到 user")
	var loaded := HudLayout.load_for(PROBE)
	t.eq(String(loaded.entry_of(&"vitality")["anchor"]), "bottom_left", "读回 user 那份")
	t.eq(loaded.entry_of(&"vitality")["offset"], Vector2(16, -16), "偏移也在")
	var f := FileAccess.open(HudLayout.user_path(PROBE), FileAccess.WRITE)
	f.store_string("{\"widgets\": [{\"id\": \"nope\"}]}")
	f.close()
	var why: Array[String] = []
	t.eq(HudLayout.load_for(PROBE, why).to_dict(), HudLayout.default_for(PROBE).to_dict(), "坏文件：回默认")
	t.check(not why.is_empty(), "并说一句为什么")
	HudLayout.reset(PROBE)
	t.check(not FileAccess.file_exists(HudLayout.user_path(PROBE)), "重置：删掉了")


static func _host(root: Window, run: RunState, layout: HudLayout) -> HudHost:
	var host := HudHost.new()
	host.size = HOST_SIZE
	root.add_child(host)
	host.setup(run, null, layout)
	host.arrange()
	return host


static func frame_host(t: TestCase, root: Window) -> void:
	t.begin("150 · 读数层：组件写对的字、自己跟着信号变；默认一排在倒计时下面居中；改锚点 / 偏移跟着挪；藏起来的不显示；窗口变大锚点保持")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var host := _host(root, run, HudLayout.default_for("map"))
	var vit := host.widget(&"vitality")
	t.eq(vit.text(), "体力 %d/%d" % [run.vitality.current, run.vitality.maximum], "体力：%s" % vit.text())
	t.eq(host.widget(&"wallet").text(), "货币 %d" % run.wallet.balance, "货币")
	t.eq(host.widget(&"action_points").text(), "行动点 %d" % run.travel.clock.total, "行动点")
	t.eq(host.widget(&"ground_count").text(), "地上 %d 件" % run.storage.item_count(), "地上")
	t.check(host.widget(&"distances").text().contains("距最近撤离点"), "距离一组")
	t.check(host.widget(&"faith").text().begins_with("信仰"), "信仰")
	run.vitality.spend(1, &"test")
	t.eq(vit.text(), "体力 %d/%d" % [run.vitality.current, run.vitality.maximum], "体力变了组件自己跟着变（没叫宿主刷）")
	t.check(not host.widget(&"encumbrance").visible or run.encumbrance_level() > 0, "轻装：负重那件藏着")

	# 默认：读数一行同高、整行水平居中、在倒计时下面
	var row_y := vit.position.y
	for id in [&"action_points", &"wallet", &"ground_count"]:
		t.eq(host.widget(id).position.y, row_y, "%s 和体力同一行" % id)
	var left := INF
	var right := -INF
	for id in [&"action_points", &"distances", &"vitality", &"wallet", &"ground_count", &"faith"]:
		var w := host.widget(id)
		if w.visible:
			left = minf(left, w.position.x)
			right = maxf(right, w.position.x + w.size.x)
	t.check(absf((left + right) / 2.0 - HOST_SIZE.x / 2.0) <= 1.0 or left <= 0.0, "整行水平居中（%s ～ %s）" % [left, right])
	var cd := host.widget(&"countdown")
	if cd.visible:
		t.check(cd.position.y + cd.size.y <= row_y, "倒计时在读数上面")
		t.eq(cd.tier, HudWidget.Tier.LARGE, "倒计时大档")
		t.eq(cd.get("_text").get_theme_color("font_color"), cd.color(), "倒计时的颜色跟着剩余")
	t.eq(host.top_inset(), vit.position.y + vit.size.y, "顶上让出到读数那一行的底")

	# 改布局：体力放到右下角、货币藏起来
	var layout := HudLayout.default_for("map")
	layout.entry_of(&"vitality")["anchor"] = "bottom_right"
	layout.entry_of(&"vitality")["offset"] = Vector2(-16, -12)
	layout.entry_of(&"wallet")["visible"] = false
	host.setup(run, null, layout)
	vit = host.widget(&"vitality")
	t.eq(vit.position + vit.size, HOST_SIZE - Vector2(16, 12), "体力贴右下角（偏移 −16, −12）")
	t.check(not host.widget(&"wallet").visible, "货币藏起来了")
	host.size = Vector2(1500, 800)
	host.arrange()
	t.eq(vit.position + vit.size, Vector2(1500, 800) - Vector2(16, 12), "窗口变大：还贴着右下角")

	# 摆读数：藏着的也露出来（半透明）；拖到右上那一片松手 → 归右上角、偏移吸附网格；滚轮切大档；右键切显隐
	host.set_editing(true)
	var wal := host.widget(&"wallet")
	t.check(wal.visible and wal.modulate.a < 1.0, "摆读数：藏着的半透明露出来")
	wal.position = Vector2(1500 - wal.size.x - 37, 21)
	host.drop(wal)
	var e := host.layout.entry_of(&"wallet")
	t.eq(String(e["anchor"]), "top_right", "松手：归最近的右上角")
	var off: Vector2 = e["offset"]
	t.check(int(off.x) % HudLayout.GRID == 0 and int(off.y) % HudLayout.GRID == 0, "偏移吸附 %d 像素网格：%s" % [HudLayout.GRID, off])
	host.toggle_tier(wal)
	t.eq(String(e["tier"]), "large", "滚轮：切到大档")
	host.toggle_shown(wal)
	t.check(bool(e["visible"]), "右键：切回显示")
	var path := HudLayout.user_path(PROBE)
	t.check(host.save(path), "保存")
	var again := HudLayout.load_for(PROBE)
	t.eq(again.to_dict()["widgets"], host.layout.to_dict()["widgets"], "存了再读：一样")
	HudLayout.reset(PROBE)
	host.set_editing(false)
	t.check(not host.widget(&"wallet").editing, "关掉摆读数")
	host.queue_free()


static func frame_map_screen(t: TestCase, root: Window) -> void:
	t.begin("150 · 地图屏：读数层接上了这一局；调试台里能开关摆读数；读数让出顶上的地方")
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
	HudLayout.reset(PROBE)
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.check(setup.depart(), "出发")
	var map = game.base()
	var run: RunState = flow.run
	map.pick_spawn(run.map.entry_ids[0])
	var host: HudHost = map.hud()
	t.not_null(host, "地图屏有读数层")
	if host != null:
		t.eq(host.widget(&"action_points").text(), "行动点 %d" % run.travel.clock.total, "行动点接上了这一局")
		t.eq(host.widget(&"vitality").text(), "体力 %d/%d" % [run.vitality.current, run.vitality.maximum], "体力接上了")
		var drawer: DevDrawer = map.dev_drawer()
		t.check(drawer != null and not drawer.is_open(), "调试台默认收着")
		map.set_hud_editing(true)
		t.check(host.editing, "摆读数：开")
		map.set_hud_editing(false)
		t.check(not host.editing, "摆读数：关")
		t.check(map.save_hud_layout(HudLayout.user_path(PROBE)), "保存到指定的地方")
		HudLayout.reset(PROBE)
	game.queue_free()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)

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
	# 补 1 / 补 2：原来右栏的东西也在默认布局里，竖排在右上；日志贴右下、只在调试模式
	for id in HudLayout.COLUMN:
		t.eq(String(d.entry_of(id)["anchor"]), "top_right", "%s 在右上那一列" % id)
	t.eq(int(d.entry_of(&"bag_button")["line"]) + 2, int(d.entry_of(&"extract_button")["line"]), "背包、回到这个点、撤离按原来的顺序")
	t.check(bool(d.entry_of(&"log")["debug_only"]), "日志只在调试模式")
	t.check(not bool(d.entry_of(&"bag_button")["debug_only"]), "背包按钮不是")
	var old := HudLayout.from_dict({"widgets": [{"id": "log", "anchor": "left"}, {"id": "wallet", "anchor": "left"}]})
	t.check(bool(old.entry_of(&"log")["debug_only"]), "文件里没写 debug_only：按默认（日志是）")
	t.check(not bool(old.entry_of(&"wallet")["debug_only"]), "文件里没写 debug_only：按默认（货币不是）")
	t.check(GameSettings.new().debug_mode, "调试模式：默认开")
	var gs := GameSettings.new()
	gs.debug_mode = false
	t.check(not GameSettings.from_dict(gs.to_dict()).debug_mode, "调试模式：存了读回还是关")
	t.check(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION}).debug_mode, "旧设置文件没这个键：开")
	var mark := HudLayout.from_dict({"widgets": [{"id": "wallet", "debug_only": true}]})
	t.check(bool(mark.entry_of(&"wallet")["debug_only"]), "写了就按写的")
	t.check(bool(HudLayout.from_dict(mark.to_dict()).entry_of(&"wallet")["debug_only"]), "debug_only 也往返")

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
	t.eq(vit.tooltip_text, vit.text(), "体力：停上去的提示是「体力 当前/上限」")
	t.eq(host.widget(&"wallet").text(), "货币 %d" % run.wallet.balance, "货币")
	t.eq(host.widget(&"action_points").text(), "行动点 %d" % run.travel.clock.total, "行动点")
	t.eq(host.widget(&"ground_count").text(), "地上 %d 件" % run.storage.item_count(), "地上")
	t.check(host.widget(&"distances").text().contains("距最近撤离点"), "距离一组")
	t.check(host.widget(&"faith").text().begins_with("信仰"), "信仰")
	run.vitality.spend(1, &"test")
	t.eq(vit.text(), "体力 %d/%d" % [run.vitality.current, run.vitality.maximum], "体力变了组件自己跟着变（没叫宿主刷）")
	# 补 4：画成心 —— 上限几点几颗、前「当前」颗红；上限变了颗数跟着变；一行放不下折行；大档大心
	t.eq(vit.call("hearts"), Vector2i(run.vitality.maximum, run.vitality.current), "心：%s 颗，红 %s 颗" % [run.vitality.maximum, run.vitality.current])
	var max0 := run.vitality.maximum
	run.vitality.set_max(11)
	t.eq(vit.call("hearts").x, 11, "上限变成 11：11 颗")
	t.eq(vit.call("grid"), Vector2i(10, 2), "十一颗：折成两行")
	var small: Vector2 = vit.get_combined_minimum_size()
	vit.set_tier(HudWidget.Tier.LARGE)
	vit.refresh()
	t.check(vit.get_combined_minimum_size().x > small.x, "大档的心更大")
	vit.set_tier(HudWidget.Tier.SMALL)
	run.vitality.set_max(max0)
	vit.refresh()
	t.eq(vit.call("grid").y, 1, "回到 %d 颗：一行" % max0)
	# 屏幕的部件：没有屏幕（这里）就空着、藏着，不报错
	for id in [&"bag_button", &"log", &"routes"]:
		t.check(host.widget(id) != null and not host.widget(id).visible, "%s：没有屏幕给部件，藏着" % id)
	var no_belt := HudWidgets.create(&"belt")
	root.add_child(no_belt)
	no_belt.setup(null, null)
	t.check(not no_belt.visible and not no_belt.has_content(), "腰带：这一局没有腰带就空着，不报错")
	no_belt.queue_free()
	var belt_w := host.widget(&"belt")
	t.eq(belt_w.has_content(), BeltModule.of(run) != null, "腰带：有腰带模块才有格子")
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
	var room := HOST_SIZE.x - host.right_inset()
	t.check(absf((left + right) / 2.0 - room / 2.0) <= 1.0 or left <= 0.0, "整行在让出右边那一条之后的地方水平居中（%s ～ %s，宽 %s）" % [left, right, room])
	if belt_w.visible:
		t.eq(host.right_inset(), HOST_SIZE.x - belt_w.position.x, "右边那一条量出来了（只有腰带）")
		t.eq(belt_w.position.x + belt_w.size.x, HOST_SIZE.x + HudLayout.COLUMN_OFFSET.x, "腰带贴右上（偏移 %s）" % HudLayout.COLUMN_OFFSET)
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
		_map_parts(t, map, host, flow, run)
	game.queue_free()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


## 补 1 ～ 补 3：右栏的东西都成了组件、地图往左让；背包按钮 = 按 B；调试模式关掉日志就不造，开回来之前写的都在
static func _map_parts(t: TestCase, map: Control, host: HudHost, flow: GameFlow, run: RunState) -> void:
	host.arrange()
	for id in [&"dev_drawer", &"status", &"bag_button", &"reopen_button", &"extract_button", &"menu_button", &"log"]:
		var w := host.widget(id) as HudPartWidget
		t.check(w != null and w.part == map.hud_part(id) and w.part.get_parent() == w, "%s：部件装进了组件" % id)
	t.check(host.widget(&"status").visible and host.widget(&"status").has_content(), "提示行有字、看得见")
	t.check(not host.widget(&"routes").visible, "挑完出生点：路线收起来，那件也藏了")
	t.check(host.right_inset() >= map.PART_WIDTH, "地图往左让出右边那一列（%s）" % host.right_inset())
	t.eq(map.get("_mid").offset_right, -host.right_inset(), "地图那一竖排右边让这么多")
	var bag := host.widget(&"bag_button") as HudPartWidget
	var ext := host.widget(&"extract_button") as HudPartWidget
	t.check(bag.position.y < ext.position.y, "背包按钮在撤离上面（原来的顺序）")
	t.eq(bag.position.x + bag.size.x, host.size.x + HudLayout.COLUMN_OFFSET.x, "背包按钮贴右边")
	if map.rules_open():
		map.close_rules()     # 091：第一次进这一章弹的规则卡开着时 B 不管用
	(bag.part as Button).pressed.emit()
	t.check(map.bag_open(), "点背包按钮：开背包")
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	map._unhandled_key_input(key)
	t.check(not map.bag_open(), "按 B：收起（和按钮是同一个开关）")
	(bag.part as Button).pressed.emit()
	t.check(map.bag_open(), "再点按钮：又开了")
	map.toggle_bag()
	# 腰带：有腰带模块就是格子，双击用（这里只看接上了）
	var belt_w := host.widget(&"belt")
	t.eq(belt_w.has_content(), BeltModule.of(run) != null, "腰带组件：跟着腰带模块")
	# 调试模式：默认开；关掉 → 日志那件不造、日志照写；开回来 → 之前写的都在
	t.check(flow.settings.debug_mode, "调试模式默认开")
	t.not_null(host.widget(&"log"), "开着：日志那件在")
	map._note("关之前写的一行")
	flow.settings.debug_mode = false
	map.apply_debug_mode()
	t.check(host.widget(&"log") == null, "关掉：日志那件不造")
	var log: RichTextLabel = map.hud_part(&"log")
	t.check(is_instance_valid(log) and not log.is_visible_in_tree(), "日志挂回藏着的架子上，看不见")
	map._note("关着时写的一行")
	t.check(host.widget(&"bag_button") != null, "别的组件照旧")
	flow.settings.debug_mode = true
	map.apply_debug_mode()
	var lw := host.widget(&"log") as HudPartWidget
	t.check(lw != null and lw.part == log, "开回来：日志那件又在了，还是那块")
	var said := log.get_parsed_text()
	t.check(said.contains("关之前写的一行") and said.contains("关着时写的一行"), "开回来：之前写的都在")
	t.check(map.dev_drawer().content.get_child(0).text.contains("调试模式：开"), "调试台头部写着调试模式")

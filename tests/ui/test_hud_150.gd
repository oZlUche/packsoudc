## 150（作者定，四项待定按推荐）：地图屏的读数拆成组件（[HudWidget]），按布局（[HudLayout]）摆在读数层（[HudHost]）上；
## 没有布局文件 = 默认布局（166：顶端栏三个槽、左下路线与图例、右下腰带）；调试台里「摆读数」：拖、右键切显隐、滚轮切档、保存 / 重置
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
	t.begin("150 / 166 · 布局：默认是顶端栏三个槽；字典往返一致；坏 id / 锚点 / 档位 / 偏移 / 重复都报；文件存取与重置")
	var d := HudLayout.default_for("map")
	t.eq(d.entries.size(), HudWidgets.KINDS.size(), "默认布局把每一种都摆上了")
	t.eq(HudLayout.VERSION, 7, "186：布局版本 7（旧的回默认）")
	t.eq(String(d.entry_of(&"hud_bar")["anchor"]), "top", "顶端栏横在顶上")
	t.eq(String(d.entry_of(&"countdown")["anchor"]), "bar_center", "倒计时在栏中间")
	t.eq(String(d.entry_of(&"countdown")["tier"]), "large", "倒计时是大档")
	for id in [&"vitality", &"wallet", &"faith"]:
		t.eq(String(d.entry_of(id)["anchor"]), "bar_left", "%s 在栏左槽" % id)
		t.eq(int(d.entry_of(id)["line"]), 0, "%s 在左槽第一行" % id)
		t.eq(String(d.entry_of(id)["tier"]), "double", "%s 是 200%% 档（作者 2026-10-12）" % id)
	for id in [&"encumbrance", &"buffs", &"erosion"]:
		t.eq(int(d.entry_of(id)["line"]), 1, "%s 在左槽第二行（小字）" % id)
	t.check(not bool(d.entry_of(&"distances")["visible"]), "距离默认藏着（作者 2026-10-12：没有意义）")
	t.check(not bool(d.entry_of(&"encumbrance")["visible"]), "负重默认不在顶端栏（作者 2026-10-17：看背包界面）")
	t.check(d.entry_of(&"action_points").is_empty() and not HudWidgets.KINDS.has(&"action_points"), "179：「行动点」读数删了（登记表与默认布局都没有）")
	var right_ids: Array[StringName] = []
	for e in d.entries:
		if String(e["anchor"]) == "bar_right":
			right_ids.append(StringName(e["id"]))
	t.eq(right_ids, [&"bag_button", &"reopen_button", &"skills", &"dev_drawer"] as Array[StringName], "栏右槽：背包、放大镜、技能、调试台箭头")
	# 166 补充一：主动技能对玩家藏着 —— 技能按钮的条目在（摆读数右键放得出来），默认不显示；其余右槽照常
	t.eq(bool(d.entry_of(&"skills")["visible"]), not RunSkills.ACTIVE_HIDDEN, "技能按钮默认%s（ACTIVE_HIDDEN = %s）" % ["藏着" if RunSkills.ACTIVE_HIDDEN else "显示", RunSkills.ACTIVE_HIDDEN])
	for id in [&"bag_button", &"reopen_button", &"dev_drawer"]:
		t.check(bool(d.entry_of(id)["visible"]), "%s 默认显示" % id)
	t.eq(String(d.entry_of(&"legend")["anchor"]), "bottom_left", "图例在左下角")
	t.check(int(d.entry_of(&"routes")["line"]) < int(d.entry_of(&"legend")["line"]), "路线在图例上面")
	for id in [&"extract_button", &"menu_button", &"log", &"ground_count", &"status"]:
		t.check(not HudWidgets.has(id) and d.entry_of(id).is_empty(), "%s 不再是部件（删了 / 进了调试台）" % id)
	t.eq(int(d.to_dict()["version"]), HudLayout.VERSION, "存的布局带版本")
	t.not_null(HudLayout.from_dict({"widgets": [{"id": "wallet", "anchor": "top", "tier": "double"}]}), "double 档认得")
	for id in HudWidgets.KINDS:
		t.not_null(HudWidgets.create(id), "%s 造得出来" % id)
	t.check(HudWidgets.create(&"nope") == null, "不认识的 id：null")
	t.check(not bool(d.entry_of(&"bag_button")["debug_only"]), "背包按钮不是只在调试模式")
	var old := HudLayout.from_dict({"widgets": [{"id": "wallet", "anchor": "left"}, {"id": "bag_button", "anchor": "bar_right"}]})
	t.not_null(old, "栏槽锚点认得")
	if old != null:
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
	f.store_string("{\"version\": %d, \"widgets\": [{\"id\": \"nope\"}]}" % HudLayout.VERSION)
	f.close()
	var why: Array[String] = []
	t.eq(HudLayout.load_for(PROBE, why).to_dict(), HudLayout.default_for(PROBE).to_dict(), "坏文件：回默认")
	t.check(not why.is_empty(), "并说一句为什么")
	# 作者 2026-10-12：默认布局改过（VERSION），旧版本存的那份不用，回默认
	f = FileAccess.open(HudLayout.user_path(PROBE), FileAccess.WRITE)
	f.store_string("{\"widgets\": [{\"id\": \"wallet\", \"anchor\": \"bottom_left\"}]}")
	f.close()
	t.eq(HudLayout.load_for(PROBE).to_dict(), HudLayout.default_for(PROBE).to_dict(), "没写版本（旧的）：回默认")
	f = FileAccess.open(HudLayout.user_path(PROBE), FileAccess.WRITE)
	f.store_string("{\"version\": 5, \"widgets\": [{\"id\": \"action_points\", \"anchor\": \"bar_left\"}]}")
	f.close()
	t.eq(HudLayout.load_for(PROBE).to_dict(), HudLayout.default_for(PROBE).to_dict(), "179：版本 5 那份（还摆着行动点）：回默认")
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
	t.begin("150 / 166 · 读数层：组件写对的字、自己跟着信号变；默认排进顶端栏的三个槽；改锚点 / 偏移跟着挪；藏起来的不显示；窗口变大锚点保持")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var host := _host(root, run, HudLayout.default_for("map"))
	var vit := host.widget(&"vitality")
	t.eq(vit.text(), "体力 %d/%d" % [run.vitality.current, run.vitality.maximum], "体力：%s" % vit.text())
	t.eq(vit.tooltip_text, vit.text(), "体力：停上去的提示是「体力 当前/上限」")
	var wallet := host.widget(&"wallet")
	t.eq(wallet.text(), "%d" % run.wallet.balance, "166：货币只写数字")
	t.eq(wallet.tooltip_text, "货币", "悬浮窗写「货币」")
	t.not_null(wallet.get("coin"), "左边一枚金币（缺图画描边圆）")
	t.check(host.widget(&"distances").text().contains("距最近撤离点"), "距离一组")
	var faith := host.widget(&"faith")
	if run.active_faith_id() == &"":
		t.eq(faith.text(), "", "166：没信仰不写字")
		t.check(faith.visible and faith.size.x >= 32.0, "没信仰也留一个空槽")
	run.vitality.spend(1, &"test")
	t.eq(vit.text(), "体力 %d/%d" % [run.vitality.current, run.vitality.maximum], "体力变了组件自己跟着变（没叫宿主刷）")
	# 补 4：画成心 —— 上限几点几颗、前「当前」颗红；上限变了颗数跟着变；一行放不下折行；大档大心
	t.eq(vit.call("hearts"), Vector2i(run.vitality.maximum, run.vitality.current), "心：%s 颗，红 %s 颗" % [run.vitality.maximum, run.vitality.current])
	var max0 := run.vitality.maximum
	run.vitality.set_max(11)
	t.eq(vit.call("hearts").x, 11, "上限变成 11：11 颗")
	t.eq(vit.call("grid"), Vector2i(10, 2), "十一颗：折成两行")
	vit.set_tier(HudWidget.Tier.SMALL)
	vit.refresh()
	var small: Vector2 = vit.get_combined_minimum_size()
	vit.set_tier(HudWidget.Tier.LARGE)
	vit.refresh()
	t.check(vit.get_combined_minimum_size().x > small.x, "大档的心更大")
	vit.set_tier(HudWidget.Tier.SMALL)
	run.vitality.set_max(max0)
	vit.refresh()
	t.eq(vit.call("grid").y, 1, "回到 %d 颗：一行" % max0)
	# 屏幕的部件：没有屏幕（这里）就空着、藏着，不报错
	for id in [&"bag_button", &"routes"]:
		t.check(host.widget(id) != null and not host.widget(id).visible, "%s：没有屏幕给部件，藏着" % id)
	var no_belt := HudWidgets.create(&"belt")
	root.add_child(no_belt)
	no_belt.setup(null, null)
	t.check(not no_belt.visible and not no_belt.has_content(), "腰带：这一局没有腰带就空着，不报错")
	no_belt.queue_free()
	var belt_w := host.widget(&"belt")
	t.eq(belt_w.has_content(), BeltModule.of(run) != null, "腰带：有腰带模块才有格子")
	t.check(not host.widget(&"encumbrance").visible or run.encumbrance_level() > 0, "轻装：负重那件藏着")

	# 166：顶端栏横贯顶部；左槽贴左、第一行体力 / 货币 / 信仰同高；倒计时在栏正中；栏下面才是别的锚点
	host.arrange()    # 上面改过档位，排一次（宿主自己是下一帧才排）
	var bar := host.widget(&"hud_bar")
	var bar_h := host.bar_height()
	t.check(bar.visible and bar_h >= HudHost.BAR_HEIGHT, "顶端栏在，高 %s" % bar_h)
	t.eq(bar.position, Vector2.ZERO, "栏贴着左上")
	t.eq(bar.size, Vector2(HOST_SIZE.x, bar_h), "栏横贯整屏宽")
	t.eq(bar.theme_type_variation, UiTheme.PANEL_HUD_BAR, "栏的底是顶端栏变体")
	var row_y := vit.position.y
	t.eq(wallet.position.y + wallet.size.y * 0.5, row_y + vit.size.y * 0.5, "货币和体力同一行（竖向居中对齐）")
	t.eq(vit.position.x, host.bar_side(), "作者 2026-10-17：体力往中间收（左边留 %s）" % host.bar_side())
	t.check(host.bar_side() > HudHost.BAR_SIDE, "比原来的 %s 更靠里" % HudHost.BAR_SIDE)
	t.check(vit.position.y >= 0.0 and vit.position.y + vit.size.y <= bar_h, "体力在栏里")
	# 作者 2026-10-13：凹槽对齐石板 —— 栏里的东西在板边上下内边距之间（底下的投影不算板面）
	var bar_box := bar.get_theme_stylebox("panel")
	var face := Rect2(0.0, bar_box.content_margin_top, HOST_SIZE.x, bar_h - bar_box.content_margin_top - bar_box.content_margin_bottom)
	t.check(vit.position.y >= face.position.y - 0.01 and vit.position.y + vit.size.y <= face.end.y + 0.01, "体力落在板面上（%s，板面 %s）" % [vit.get_rect(), face])
	if belt_w.visible:
		t.eq(belt_w.position + belt_w.size, HOST_SIZE + HudLayout.BELT_OFFSET, "160：腰带贴右下（偏移 %s）" % HudLayout.BELT_OFFSET)
	var cd := host.widget(&"countdown")
	if cd.visible:
		t.check(absf(cd.position.x + cd.size.x * 0.5 - HOST_SIZE.x * 0.5) <= 1.0, "倒计时在栏正中")
		t.eq(cd.tier, HudWidget.Tier.LARGE, "倒计时大档")
		t.check(cd.stage() == &"calm" and cd.color() == UiPalette.FG and not cd.get("_text").visible, "190：倒计时是一枚日晷、栏上不写字；刚开局在 calm 阶（颜色跟着阶段）")
	t.eq(host.top_inset(), bar_h, "顶上让出栏高")
	var inset := host.content_inset()
	t.eq(inset.position.y, bar_h, "地图上边躲开顶端栏")
	t.check(inset.size.y >= (belt_w.size.y + 8.0 if belt_w.visible else 0.0), "地图下边躲开左下 / 右下（%s）" % inset.size.y)
	t.eq(host.rect_of(&"vitality"), vit.get_global_rect(), "rect_of：部件在屏幕上的包围盒")
	t.eq(host.rect_of(&"nope"), Rect2(), "没有的部件：空矩形")

	# 改布局：体力放到右下角、货币藏起来
	var layout := HudLayout.default_for("map")
	layout.entry_of(&"vitality")["anchor"] = "bottom_right"
	layout.entry_of(&"vitality")["offset"] = Vector2(-16, -12)
	layout.entry_of(&"wallet")["visible"] = false
	host.setup(run, null, layout)
	vit = host.widget(&"vitality")
	t.eq(vit.position + vit.size, HOST_SIZE - Vector2(16, 12), "体力贴右下角（偏移 −16, −12）")
	t.eq(String(layout.entry_of(&"wallet")["anchor"]), "bar_left", "货币原来在栏左槽")
	t.check(not host.widget(&"wallet").visible, "货币藏起来了")
	host.size = Vector2(1500, 800)
	host.arrange()
	t.eq(vit.position + vit.size, Vector2(1500, 800) - Vector2(16, 12), "窗口变大：还贴着右下角")

	# 摆读数：藏着的也露出来（半透明）；拖到栏下面右上那一片松手 → 归右上角、偏移吸附网格；拖回栏里 → 按横向三等分进槽；滚轮切大档；右键切显隐
	host.set_editing(true)
	var wal := host.widget(&"wallet")
	t.check(wal.visible and wal.modulate.a < 1.0, "摆读数：藏着的半透明露出来")
	var bh := host.bar_height()
	wal.position = Vector2(1500 - wal.size.x - 37, bh + 21)
	host.drop(wal)
	var e := host.layout.entry_of(&"wallet")
	t.eq(String(e["anchor"]), "top_right", "松手：归最近的右上角")
	t.check(wal.position.y >= bh, "栏下面的锚点在栏下面摆")
	wal.position = Vector2(750 - wal.size.x * 0.5, 4)
	host.drop(wal)
	t.eq(String(host.layout.entry_of(&"wallet")["anchor"]), "bar_center", "松在栏的中间三分之一：进中槽")
	wal.position = Vector2(1500 - wal.size.x - 37, bh + 21)
	host.drop(wal)
	e = host.layout.entry_of(&"wallet")
	var off: Vector2 = e["offset"]
	t.check(int(off.x) % HudLayout.GRID == 0 and int(off.y) % HudLayout.GRID == 0, "偏移吸附 %d 像素网格：%s" % [HudLayout.GRID, off])
	host.toggle_tier(wal)
	t.eq(String(e["tier"]), "large", "滚轮：200% 档切到大档（小 → 200% → 大 → 小）")
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
	t.begin("150 / 166 · 地图屏：读数层接上了这一局；地图铺满整屏、躲开顶端栏；调试台悬浮在栏下面、盖着地图；日志与地上件数在调试台里")
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
		t.check(host.widget(&"countdown") != null, "倒计时接上了这一局")
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


## 补 1 ～ 补 3 / 166：按钮与列表是部件（装进栏里的组件）；地图铺满、按读数层占着的边躲开；调试台悬浮；背包图标按钮 = 按 B；
## 日志、地上件数、提示行在调试台里（调试模式关了也照写）；暂停菜单没有「存档并回主菜单」
static func _map_parts(t: TestCase, map: Control, host: HudHost, flow: GameFlow, run: RunState) -> void:
	host.arrange()
	for id in [&"dev_drawer", &"bag_button", &"reopen_button"]:
		var w := host.widget(id) as HudPartWidget
		t.check(w != null and w.part == map.hud_part(id) and w.part.get_parent() == w, "%s：部件装进了组件" % id)
		t.check(w.position.y + w.size.y <= host.bar_height(), "%s 在顶端栏里" % id)
	t.check(map.hud_part(&"bag_button") is IconButton and map.hud_part(&"reopen_button") is IconButton, "背包 / 放大镜是图标按钮")
	# 166 补充一：技能按钮默认藏着；摆读数时右键放出来，有主动技能的角色就画出按钮（验技能用）
	var sk := host.widget(&"skills")
	if sk != null and RunSkills.ACTIVE_HIDDEN:
		t.check(not sk.visible, "技能按钮默认不在栏里")
		host.toggle_shown(sk)
		map.call("_refresh_skills")
		var box: HBoxContainer = map.hud_part(&"skills")
		t.eq(box.get_child_count() > 0, run.skills != null and run.skills.defs.any(func(d: RunSkill) -> bool: return d != null and d.is_active()), "右键放出来：有主动技能就有按钮（%d 个）" % box.get_child_count())
		t.check(sk.visible == (box.get_child_count() > 0), "有按钮才显示")
		host.toggle_shown(sk)
		t.check(not sk.visible, "再右键：藏回去")
	for id in [&"extract_button", &"menu_button", &"log", &"ground_count"]:
		t.is_null(host.widget(id), "%s 不在读数层里" % id)
		t.is_null(map.hud_part(id), "%s 也不是这一屏的部件了" % id)
	var view: MapView = map.get("_view")
	t.eq(view.size, map.size, "地图铺满整屏")
	t.eq(view.content_inset.position.y, host.bar_height(), "地图上边躲开顶端栏")
	t.check(view.safe_rect().position.y >= host.bar_height(), "安全区从栏下面开始")
	var drawer: DevDrawer = map.dev_drawer()
	var status: Label = map.get("_status")
	t.check(status.get_parent() == drawer.content and status.text != "", "提示行在调试台里、有字")
	var log: RichTextLabel = map.get("_log")
	t.check(log.get_parent() == drawer.content, "日志在调试台里")
	var ground: Label = map.get("_ground_line")
	t.eq(ground.text, "地上 %d 件" % run.storage.item_count(), "地上件数在调试台里")
	t.check(drawer.offset_top >= host.bar_height(), "调试台顶缘在顶端栏下面（%s）" % drawer.offset_top)
	var size0 := view.size
	var arrow_w := host.widget(&"dev_drawer")
	var arrow_at := arrow_w.position
	drawer.set_open(true)
	host.arrange()
	t.eq(view.size, size0, "调试台开着：地图不让")
	t.eq(arrow_w.position, arrow_at, "箭头按钮不挪（调试台在它下面，不盖它）")
	drawer.set_open(false)
	t.check(not host.widget(&"routes").visible, "挑完出生点：路线收起来，那件也藏了")
	var bag := host.widget(&"bag_button") as HudPartWidget
	if map.rules_open():
		map.close_rules()     # 091：第一次进这一章弹的规则卡开着时 B 不管用
	if map.coach() != null:
		map.coach().queue_free()
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
	# 调试模式：关掉照旧，日志照写；开回来之前写的都在
	t.check(flow.settings.debug_mode, "调试模式默认开")
	map._note("关之前写的一行")
	flow.settings.debug_mode = false
	map.apply_debug_mode()
	map._note("关着时写的一行")
	t.check(host.widget(&"bag_button") != null, "别的组件照旧")
	flow.settings.debug_mode = true
	map.apply_debug_mode()
	var said := log.get_parsed_text()
	t.check(said.contains("关之前写的一行") and said.contains("关着时写的一行"), "开回来：之前写的都在")
	t.check(map.dev_drawer().content.get_child(0).text.contains("调试模式：开"), "调试台头部写着调试模式")
	# 166：暂停菜单只剩继续 / 设置 / 百科 /（规则）/ 回主菜单
	map.toggle_pause()
	var texts: Array[String] = []
	for b in map.get("_pause").find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	t.check(not texts.has("存档并回主菜单") and texts.has("回主菜单"), "暂停菜单：「存档并回主菜单」换成「回主菜单」（%s）" % "、".join(texts))
	var frames: Array = map.get("_pause").find_children("*", "OverlayFrame", true, false)
	t.check(frames.size() == 1 and (frames[0] as OverlayFrame).title() == "暂停", "作者 2026-10-13：暂停窗是一整块石板（有不透明的底），标题在标题条上")
	map.toggle_pause()

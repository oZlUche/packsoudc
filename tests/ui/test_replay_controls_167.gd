## 167（作者定 D 版）：战斗回放控件换图 —— 播放 / 倍速 / 跳过是符石键（三态图），倍速是罗马数字；
## 时间轴是铜章凹槽（两端符石留空）；底下那行常驻说明挪进播放键的悬浮窗
extends RefCounted

const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "replay167"


static func _result() -> BattleResult:
	var c := GF._content()
	var f := Support.flow(c, PREFIX)
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	var result: BattleResult = null
	if not found.is_empty():
		f.new_run()
		f.begin(c.chapter, kit, int(found["seed"]))
		f.pick_spawn(int(found["entry"]))
		f.step_to(int(found["next"]))
		f.start_battle()
		result = f.last_payload.get("result", null)
	Support.cleanup(PREFIX)
	return result


static func frame_art_buttons(t: TestCase, root: Window) -> void:
	t.begin("167 · 回放三键是符石图：播放 / 暂停 / 重播随状态换图，倍速 Ⅰ → Ⅱ → Ⅳ 循环，悬停与按下换那一态；说明进了播放键悬浮窗")
	var result := _result()
	if result == null:
		t.check(false, "没有一场战斗结果")
		return
	var view := BattleView.new()
	root.add_child(view)
	view.play(result)
	var play: IconButton = view._play_btn
	var speed: IconButton = view._speed_btn
	var skip: IconButton = view._skip_btn
	for b in [play, speed, skip]:
		t.check(b.has_art() and b.theme_type_variation == UiTheme.BUTTON_ART and b.text == "", "%s：有图、整图变体、不写字" % b.icon_id)
		t.eq(b.custom_minimum_size, Vector2(44, 44), "%s：按图的大小 44" % b.icon_id)
	t.eq(play.icon_id, "pause", "在放：暂停键")
	t.check(play.tooltip_text.begins_with("暂停") and play.tooltip_text.contains(BattleView.PLAY_HINT), "悬浮窗写名字和「结果已定」那句")
	view.toggle_play()
	t.eq(play.icon_id, "play", "暂停了：播放键")
	play._set_hover(true)
	t.eq(play.icon, play._states["_hover"], "悬停：换悬停那张")
	play._set_down(true)
	t.eq(play.icon, play._states["_pressed"], "按下：换按下那张")
	play._set_down(false)
	play._set_hover(false)
	t.eq(play.icon, play._states[""], "松开移走：常态")
	view.skip_to_end()
	t.eq(play.icon_id, "replay", "播完了：重播键（逆时针箭头）")
	view.set_speed(1.0)
	var seen: Array = []
	for i in BattleView.SPEEDS.size():
		seen.append([speed.icon_id, speed.tooltip_text.substr(0, 4)])
		view.cycle_speed()
	t.eq(seen, [["speed_1", "倍速 Ⅰ"], ["speed_2", "倍速 Ⅱ"], ["speed_4", "倍速 Ⅳ"]], "倍速一圈：图与悬浮窗都是罗马数字")
	t.eq(speed.icon_id, "speed_1", "转回一倍")
	var labels: Array = view.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text.contains("开打那一瞬"))
	t.eq(labels.size(), 0, "那行常驻说明不在了")
	view.queue_free()


static func run_timeline(t: TestCase) -> void:
	t.begin("167 · 时间轴：铜章凹槽（两端符石留 16 像素）；时刻 ↔ 横坐标对得上")
	var art := ReplayTimeline.new()
	t.eq(art.pad(), 16.0, "两端留符石的宽")
	for tl in [art]:
		tl.size = Vector2(400, ReplayTimeline.HEIGHT)
		tl.duration = 10.0
		t.check(is_equal_approx(tl.x_of(0.0), tl.pad()) and is_equal_approx(tl.x_of(10.0), 400.0 - tl.pad()), "两头对着杆的两端")
		t.check(is_equal_approx(tl.time_at(tl.x_of(3.0)), 3.0), "来回换算一致")
		tl.free()

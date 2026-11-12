## 作者 11-12：打输扣体力回到地图 —— 中央红心斜劈变黑、缩小飞回体力条最右边那颗；点一下跳过；扣两点连劈两颗；
## 没落下的那几颗体力条照旧画红（HeartBreak.owed）
extends RefCounted

const VITALITY := "res://ui/hud/widgets/vitality_widget.gd"


static func frame_heart_break(t: TestCase, root: Window) -> void:
	t.begin("劈心：没落下的心画红；从右往左一颗颗落下变黑；各段顺序；点一下跳到结尾")
	HeartBreak.owed = 0
	var run := RunState.new()
	run.vitality = Vitality.new(5)
	var stage := Control.new()
	stage.size = Vector2(1280, 800)
	root.add_child(stage)
	var w: Control = load(VITALITY).new()
	w.run = run
	stage.add_child(w)
	w.refresh()
	t.eq(w.hearts(), Vector2i(5, 5), "满的：五颗红")
	t.is_null(HeartBreak.play_on(stage, w), "没欠的：不放")
	run.vitality.spend(2, &"battle_lost")
	HeartBreak.owed = 2
	w.refresh()
	t.eq(w.hearts(), Vector2i(5, 5), "扣了两点、动画还没落：仍画五颗红")
	var hb := HeartBreak.play_on(stage, w)
	t.not_null(hb, "欠着：放")
	if hb != null:
		t.eq(hb._index, 4, "先劈最右边那颗")
		t.check(HeartBreak.REASONS.has(&"battle_lost") and HeartBreak.REASONS.has(&"flee"), "打输与逃跑失败都放")
		hb._set_t(HeartBreak.POP_SEC + HeartBreak.SLASH_SEC * 0.5)
		t.check(hb.pop() == 1.0 and hb.slash() > 0.0 and hb.split() == 0.0, "先弹出，再一刀划过（还没裂开）")
		hb._set_t(HeartBreak.POP_SEC + HeartBreak.SLASH_SEC + HeartBreak.SPLIT_SEC)
		t.check(hb.split() == 1.0 and hb.fly() == 0.0, "裂开变黑，还没飞")
		t.check(HeartBreak.total_sec() <= 2.0, "一颗不超过 2 s")
		hb._tween.custom_step(HeartBreak.total_sec() + 0.01)
		t.eq(HeartBreak.owed, 1, "落下一颗")
		t.eq(w.hearts(), Vector2i(5, 4), "最右那颗变黑")
		t.eq(hb._index, 3, "接着劈左边那颗")
		var r: Rect2 = w.heart_rect(3)
		t.check(r.size.x > 0.0, "落点是体力条第 4 颗心的框")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		hb._gui_input(click)
		t.eq(HeartBreak.owed, 0, "点一下：欠的全落下")
		t.eq(w.hearts(), Vector2i(5, 3), "两颗都黑了")
		t.check(hb.is_queued_for_deletion(), "自己摘掉")
	HeartBreak.owed = 0
	stage.queue_free()

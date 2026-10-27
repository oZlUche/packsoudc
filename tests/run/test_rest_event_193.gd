## 193 §2（作者「扎营回了三点」）：扎营回 rest_restore + 1（对的）；选项文字改写这一下一共回几点 —— {rest_restore} {rest_total}
extends RefCounted

const EC := preload("res://tests/run/test_event_constructs.gd")
const CountdownWidget := preload("res://ui/hud/widgets/countdown_widget.gd")


static func run_rest_labels(t: TestCase) -> void:
	t.begin("193 §2 / 作者 10-27 · 休息点：篝火写「倒计时 −1，回 N 点」、帐篷写「倒计时 −2，回 N+1 点」（196 起只写效果）；扎营真的回 N+1 点")
	var c := EC._content()
	var rest: EventDef = c.events.get(&"rest_default", null)
	t.not_null(rest, "有默认休息事件")
	if rest == null:
		return
	var fr := EC._run_with(c, {}, &"rest_default", &"rest")
	t.check(not fr.is_empty(), "找得到出生点旁边是休息点的种子")
	if fr.is_empty():
		return
	var s: RunState = fr["run"]
	var n := int(fr["next"])
	var restore := s.node_rules.rest_restore + s.hooks.run_context().rest_bonus
	var ctx := TextTemplate.context_for(s, s.map.get_node(n))
	t.eq(int(ctx["rest_restore"]), restore, "{rest_restore} = 规则 + 休息多回")
	var labels: Array[String] = []
	for opt in rest.options:
		labels.append(TextTemplate.plain((opt as EventOption).label_for(), TextTemplate.option_context(ctx, opt)))
	t.check(labels.has("倒计时 −1，回 %d 点体力" % restore), "篝火（%s）" % str(labels))
	t.check(labels.has("倒计时 −2，回 %d 点体力" % (restore + 1)), "帐篷写总数")
	t.check(not labels.any(func(l): return l.contains("多回")), "不再写「多回」")
	s.vitality.spend(s.vitality.current - 1, &"test")
	var vit := s.vitality.current
	s.step_to(n)
	var camp := labels.find("倒计时 −2，回 %d 点体力" % (restore + 1))
	s.events.choose(camp)
	t.eq(s.vitality.current, mini(vit + restore + 1, s.vitality.maximum), "扎营真的回 %d 点" % (restore + 1))


static func frame_countdown_words(t: TestCase, root: Window) -> void:
	t.begin("193 补充一 · 倒计时这口钟的消耗与剩余说「倒计时」不说「步」：日规悬浮窗、PassTime、扎营选项、负重、开局规模")
	var c := EC._content()
	var fr := EC._run_with(c, {}, &"rest_default", &"rest")
	if fr.is_empty():
		t.check(false, "找得到出生点旁边是休息点的种子")
		return
	var s: RunState = fr["run"]
	var cd := CountdownModule.of(s)
	t.check(cd != null and cd.has_countdown(), "这一局有倒计时")
	var w = CountdownWidget.new()
	root.add_child(w)
	w.run = s
	var tip: String = w.tip_plain()
	t.check(tip.contains(Glossary.COUNTDOWN_WORD + "还剩") and not tip.contains("步"), "日规悬浮窗：%s" % tip.replace("\n", " / "))
	t.check(not w.text_of().contains("步"), "栏上的字：%s" % w.text_of())
	w.queue_free()
	var pt := PassTime.new()
	pt.actions = 2
	t.eq(pt.describe(), "倒计时 −2", "PassTime.describe")
	var rest: EventDef = c.events.get(&"rest_default", null)
	var ctx := TextTemplate.context_for(s, s.map.get_node(int(fr["next"])))
	var camp := ""
	for opt in rest.options:
		var l := TextTemplate.plain((opt as EventOption).label_for(), TextTemplate.option_context(ctx, opt))
		if l.begins_with(Glossary.COUNTDOWN_WORD):
			camp = l
	t.check(camp.contains(Glossary.COUNTDOWN_WORD) and not camp.contains("步"), "扎营：%s" % camp)
	t.check(not EventCostIcons.describe(["time"] as Array[String]).contains("步"), "代价提示：%s" % EventCostIcons.describe(["time"] as Array[String]))
	t.check(not UiText.t("notice.countdown").contains("步"), "快没了的提醒：%s" % UiText.t("notice.countdown"))

## 301（作者 2026-11-11 13:32 / 13:33）：元素反应打的伤害记进战记（反应那一行下面缩进「造成了 N 某伤害」，不再写成「使用天生」），
## 伤害事件带 `reaction`、算引发方，平衡导出单列反应名；结算页的信力记录默认藏，开发设置开了才摆
extends RefCounted

const R := preload("res://tests/battle/test_reactions_175.gd")
const RS := preload("res://ui/game/result_screen.gd")


static func _result(ctx: BattleContext) -> BattleResult:
	var r := BattleResult.new()
	r.log = ctx.log
	return r


static func run_reaction_damage(t: TestCase) -> void:
	t.begin("301 · 反应伤害事件带反应 id、来源是引发方；战记写在反应行下面；战报总数算进去；导出单列")
	var ctx := R._react("poison", 1, "scorch", 1)
	var hit: BattleEvent = null
	for e in ctx.log:
		if (e as BattleEvent).name == BattleEvent.DAMAGE and (e as BattleEvent).payload.has("reaction"):
			hit = e
	t.check(hit != null, "爆燃那一下带 reaction")
	if hit == null:
		return
	t.eq(String(hit.payload["reaction"]), "fire_poison", "反应 id")
	t.eq(hit.get_int(&"source_side"), 0, "来源 = 引发方")
	t.eq(ctx.reaction, &"", "结算完清掉")
	var res := _result(ctx)
	var lines := BattleNarrator.lines(res, ["A", "B"])
	var texts: Array[String] = []
	for l in lines:
		texts.append(BattleNarrator.plain(l))
	var at := -1
	for i in texts.size():
		if texts[i].contains(Names.of(ReactionResolver.by_id(&"fire_poison"))):
			at = i
	t.check(at >= 0 and at + 1 < texts.size(), "有反应那一行（%s）" % " | ".join(PackedStringArray(texts)))
	if at < 0 or at + 1 >= texts.size():
		return
	var under := texts[at + 1]
	t.check(under.contains(UiText.t("log.indent")) and under.contains(UiText.t("log.reaction_hit").split("%")[0]), "下一行缩进写「造成了」（%s）" % under)
	t.eq(int(lines[at + 1]["group"]), int(lines[at]["group"]), "和反应行同一组")
	for s in texts:
		t.check(not s.contains(UiText.t("battle.innate")), "不再写成「使用天生」（%s）" % s)
	var dealt := BattleSim.damage_dealt(ctx.log)
	t.check(dealt[0] >= StatMath.to_int(hit.get_int(&"amount")), "战报总数算进引发方")
	var m := BattleMetrics.of(res, 60.0)
	t.check(float((m["damage_by_reaction"] as Array)[0].get("fire_poison", 0.0)) > 0.0, "导出：引发方单列爆燃")
	t.check((m["damage_by_item"] as Array)[0].is_empty(), "不记到哪件道具")


static func run_faith_pace_hidden(t: TestCase) -> void:
	t.begin("301 · 结算页信力记录：默认不摆；开发设置开了才摆；存读带着")
	var s := GameSettings.new()
	t.check(not s.faith_pace_shown, "默认关")
	t.check(not RS.faith_pace_shown(s), "关着：不摆")
	s.faith_pace_shown = true
	t.eq(RS.faith_pace_shown(s), GameSettings.dev_build(), "开了：开发包里摆")
	t.check(GameSettings.from_dict(s.to_dict()).faith_pace_shown, "存读带着")
	DevGate.force_player = true
	t.check(not RS.faith_pace_shown(s), "玩家包：开着也不摆")
	DevGate.force_player = false

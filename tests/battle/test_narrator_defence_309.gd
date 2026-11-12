## 309（v5.85 体验 E02，对齐 305）：战记里格挡、护甲各写各的，生命只写真扣的；完全挡住、穿透、英文
extends RefCounted

const N := preload("res://tests/battle/test_battle_narrator_272.gd")
const ONE := StatMath.ONE


static func _plain(events: Array[BattleEvent]) -> Array[String]:
	var r := BattleResult.new()
	r.winner = 0
	r.duration = StatMath.from_float(5.0)
	r.log = events
	var out: Array[String] = []
	for l in BattleNarrator.lines(r, ["阿丽", "守卫"], [{3: "短剑"}, {9: "短剑"}], [{}, {}]):
		out.append(BattleNarrator.plain(l))
	return out


static func _log() -> Array[BattleEvent]:
	return [
		N._ev(BattleEvent.BATTLE_START, 0.0, -1),
		N._ev(BattleEvent.ITEM_FIRED, 1.0, 0, {"uid": 3}),
		N._hit(1.0, 1, 0, 3, 8, 5, {"block": 3 * ONE}),     # 只有格挡
		N._ev(BattleEvent.ITEM_FIRED, 2.0, 0, {"uid": 3}),
		N._hit(2.0, 1, 0, 3, 8, 0, {"block": 3 * ONE, "absorbed": 5 * ONE}),     # 格挡 + 护甲吃光，没掉血
		N._ev(BattleEvent.ITEM_FIRED, 3.0, 0, {"uid": 3}),
		N._hit(3.0, 1, 0, 3, 8, 8, {"penetration": true}),     # 穿透
		N._ev(BattleEvent.BATTLE_END, 4.0, -1, {"winner": 0}),
	] as Array[BattleEvent]


static func run_defence_wording(t: TestCase) -> void:
	t.begin("309 · 战记的防御说法：格挡抵消 / 护甲吸收分开写，没掉血写「未受损」，穿透单写；英文同口径")
	UiText.lang = "zh"
	var p := _plain(_log())
	t.check(p.size() >= 3, "行数：%s" % "\n".join(p))
	if p.size() < 3:
		return
	t.eq(p[0], "1.0s  阿丽使用短剑造成了 8 物理伤害（格挡抵消 3，生命 −5）", "只有格挡")
	t.eq(p[1], "2.0s  阿丽使用短剑造成了 8 物理伤害（格挡抵消 3，护甲吸收 5，生命未受损）", "完全挡住")
	t.eq(p[2], "3.0s  阿丽使用短剑造成了 8 物理伤害（穿透护甲，生命 −8）", "穿透")
	UiText.lang = "en"
	var e := _plain(_log())
	t.check(e.size() >= 2 and e[0].contains("block stopped 3; 5 HP lost") and e[1].contains("armor absorbed 5; no HP lost"), "英文：%s" % "\n".join(e))
	UiText.lang = "zh"

## 日神 2 级（093 / 105）：在神坛祈祷，获得局内永久的火焰伤害加成。
##
## 105（作者定）：加成是一条**普通增益** —— 标准轴 `fire_damage`（每层 +3%，和伤害 / 攻速加成同一体系），
## 攒的层数记在 [member AltarModule.axis_bonus]，开战时由编译器种进系统层（常驻，对手净化洗不掉）。
## 放大的是所有火焰来源，不再只有附魔那一下。
##
## 每次祈祷给几层由 [member gains] 定：**空 = 斐波那契 1, 1, 2, 3, 5, 8…**（作者暂定：越祈越快），
## 超出表长按最后一项。要改回「越来越慢」就把 gains 填成 `[3, 2, 2, 1, 1]` 之类 —— 曲线是内容，不是代码
class_name AltarPrayFirePerk
extends FaithPerk

const KEY := "pray_fire"
## 第 n 次祈祷给几层；空 = 斐波那契
@export var gains: Array[int] = []
@export var axis: StringName = &"fire_damage"
@export var max_times: int = 0


## 第 [param n] 次（从 1 起）祈祷给几层
func gain_at(n: int) -> int:
	if n <= 0:
		return 0
	if not gains.is_empty():
		return gains[mini(n, gains.size()) - 1]
	# 斐波那契 1, 1, 2, 3, 5, 8…
	var a := 1
	var b := 1
	for _i in maxi(0, n - 1):
		var next := a + b
		a = b
		b = next
	return a


func altar_label() -> String:
	return UiText.t("perk.pray_label") % (UiText.t("perk.pray_by_table") if not gains.is_empty() else UiText.t("perk.pray_growing"))


func altar_available(run: RunState, _node: MapNode) -> String:
	var rituals := AltarModule.rituals_of(run)
	return "" if max_times <= 0 or int(rituals.get(KEY, 0)) < max_times else UiText.t("perk.pray_capped")


func altar_apply(run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	var altar := AltarModule.of(run)
	if altar == null:
		return ""
	var n := int(altar.rituals.get(KEY, 0)) + 1
	altar.rituals[KEY] = n
	var gain := gain_at(n)
	var total := altar.shift_axis(axis, gain)
	return UiText.t("perk.pray_done") % [
		n, StatAxes.name_of(axis, gain), gain, total, roundi(total * StatAxes.step_of(axis))]


func _summary() -> String:
	return UiText.t("perk.pray_summary") % [
		StatAxes.name_of(axis, 1), roundi(StatAxes.step_of(axis))]

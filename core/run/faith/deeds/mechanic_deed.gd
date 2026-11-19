## 信仰重构 C / D（交接方案 §3.2「有限特色奖励」）：一场战斗里这位神的战斗机制真的发生了几次 —— 战斗账 `mechanic`
## （[method RunState.battle_summary]：本方开战之后叠上的 buff 层数、`faith_mechanic` 的那几下，按 id 计）。
## 到了 [member at_least] 次给 [member amount]，一场只给一次；输赢都算（失败也保留已经真完成的特色行为）
class_name MechanicDeed
extends FaithDeed

## 数哪一样：buff id（`skill_momentum`）或机制事件的 key（`skill_combo`）
@export var key: StringName = &""
@export var at_least: int = 1
## 按次给（每次 [member amount]，一场合计不超过 [member cap]，0 = 不封顶）；不填就是「到了 [member at_least] 次给一次」
@export var per_count: bool = false
@export var cap: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle" or key == &"":
		return 0
	var counts: Dictionary = payload.get("mechanic", {})
	var n := int(counts.get(String(key), 0))
	if per_count:
		var got := n * amount
		return mini(got, cap) if cap > 0 else got
	return amount if n >= maxi(1, at_least) else 0


func describe() -> String:
	if per_count:
		return UiText.t("deed.mechanic_each") % [UiText.t("deed.mech_" + String(key)), amount, cap]
	return UiText.t("deed.mechanic") % [UiText.t("deed.mech_" + String(key)), at_least, amount]

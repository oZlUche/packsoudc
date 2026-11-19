## 信仰重构 C / D（交接方案 §3.2「有限特色奖励」）：一场战斗里这位神的战斗机制真的发生了几次 —— 战斗账 `mechanic`
## （[method RunState.battle_summary]：本方开战之后叠上的 buff 层数、`faith_mechanic` 的那几下，按 id 计）。
## 到了 [member at_least] 次给 [member amount]，一场只给一次；输赢都算（失败也保留已经真完成的特色行为）
class_name MechanicDeed
extends FaithDeed

## 数哪一样：buff id（`skill_momentum`）或机制事件的 key（`skill_combo`）
@export var key: StringName = &""
@export var at_least: int = 1


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle" or key == &"":
		return 0
	var counts: Dictionary = payload.get("mechanic", {})
	return amount if int(counts.get(String(key), 0)) >= maxi(1, at_least) else 0


func describe() -> String:
	return UiText.t("deed.mechanic") % [UiText.t("deed.mech_" + String(key)), at_least, amount]

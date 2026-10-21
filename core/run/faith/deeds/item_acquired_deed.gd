## 获得道具（104，技巧之神「获得新的金属标签道具，格子 × 3」）：一件道具**头一回**出现在玩家的容器里（棋盘 / 地上 / 保险箱），
## 来源不限（拖进来、买、赐物、事件给、合成产出）。带 [member tag]（空 = 不限）的每件给 amount 点，[member per_cell] = 再乘格子数。
## 「头一回」由 [RunState] 按实例对账（`owned_uids`），本构件不记状态；[member first_kind_only] = 同一种道具一局只给一次（看载荷的 first_in_run）
class_name ItemAcquiredDeed
extends FaithDeed

@export var tag: StringName = &""
@export var per_cell: bool = false
@export var first_kind_only: bool = false


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"item_acquired":
		return 0
	if tag != &"" and not (payload.get("tags", []) as Array).has(String(tag)):
		return 0
	if first_kind_only and not bool(payload.get("first_in_run", false)):
		return 0
	return amount * (maxi(1, int(payload.get("cells", 1))) if per_cell else 1)


func describe() -> String:
	var per := UiText.t("deed.per_cell") if per_cell else ""
	if tag != &"":
		return UiText.t("deed.acquired_tagged") % [Glossary.tag_name(tag), amount, per]
	return UiText.t("deed.acquired") % [amount, per]

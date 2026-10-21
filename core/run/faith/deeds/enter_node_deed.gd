## 进入空白节点（093 表：大地「首次进入 +20，非首次进入 +1」）。作者定：空白节点 = 岔路 + 用过的点 ——
## 头一回踩上岔路给 first_amount；再踩任何用过的点（含岔路）给 again_amount
class_name EnterNodeDeed
extends FaithDeed

@export var first_amount: int = 20
@export var again_amount: int = 1


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"travel" or not payload.has("first_visit"):
		return 0     # 没说头一回还是再踩（老的喂法）：不认
	if bool(payload.get("first_visit", false)):
		return first_amount if String(payload.get("node_type", "")) == "junction" else 0
	return again_amount


func describe() -> String:
	return UiText.t("deed.enter_node") % [first_amount, again_amount]

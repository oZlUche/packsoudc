## 进行探索：每搜一次给 amount 点
class_name ExploreDeed
extends FaithDeed


func gain(event: StringName, _payload: Dictionary) -> int:
	return amount if event == &"explore" else 0


func describe() -> String:
	return "搜一次 +%d" % amount

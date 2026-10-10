## 150：地上几件
extends HudWidget


func title() -> String:
	return "地上"


func watch() -> Array[Signal]:
	return [run.storage.changed] as Array[Signal]


func text_of() -> String:
	return "地上 %d 件" % run.storage.item_count()

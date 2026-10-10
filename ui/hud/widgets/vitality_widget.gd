## 150：体力 当前 / 上限（先写字，画成格点等美术样稿；待定 4 按推荐）
extends HudWidget


func title() -> String:
	return "体力"


func watch() -> Array[Signal]:
	return [run.vitality.changed] as Array[Signal]


func text_of() -> String:
	return "体力 %d/%d" % [run.vitality.current, run.vitality.maximum]

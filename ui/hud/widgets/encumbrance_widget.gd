## 150：负重档（129）：轻装不显示；走路翻倍的那一级再注一句
extends HudWidget


func title() -> String:
	return "负重"


func watch() -> Array[Signal]:
	return [run.encumbrance_changed] as Array[Signal]


func text_of() -> String:
	var lv := run.encumbrance_level()
	if lv <= 0 or run.encumbrance == null:
		return ""
	var tag := "负重：" + run.encumbrance.name_of(lv)
	var mult := run.encumbrance.travel_mult_of(lv)
	if mult > 1:
		tag += "（走一步花 %d 倍）" % mult
	return tag

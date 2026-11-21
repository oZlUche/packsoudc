## 355：这一局吃的那一锅还剩几点饱腹（灰灯食堂，[MealModule]）。没吃饭不显示；饿了写「已饿」（加成失效）。
## 占位：等 UI设计 的饱腹度图标
extends HudWidget


func title() -> String:
	return "饱腹"


func watch() -> Array[Signal]:
	var mod := MealModule.of(run)
	return [mod.satiety_changed] as Array[Signal] if mod != null else [] as Array[Signal]


func text_of() -> String:
	var mod := MealModule.of(run)
	if mod == null or not mod.has_meal():
		return ""
	return UiText.t("hud.meal") % mod.satiety if mod.is_fed() else UiText.t("hud.meal_hungry")

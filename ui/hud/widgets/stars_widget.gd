## 作者 11-26 日神专属牌【众星】：这一局点亮了几颗【星辰】（[member SunCyclePerk.STARS_KEY]）。没拿这张牌不显示。
## 占位：等美术的星辰小图标（有了放到 [constant STAR_ART]，就换成图标 + 数字）
extends HudWidget

const STAR := 36.0
const STAR_ART := "res://assets/ui/hud/star.png"

var star: HudIcon


func _init() -> void:
	super()
	var tex := HudIcon.load_art(STAR_ART)
	if tex != null:
		star = HudIcon.make(STAR)
		star.texture = tex
		_prepend_icon(star)
	tooltip_text = UiText.t("hud.stars_tip")


func title() -> String:
	return "星辰"


func watch() -> Array[Signal]:
	var lv := LevelModule.of(run)
	return [lv.picked, lv.god_state_changed] as Array[Signal] if lv != null else [] as Array[Signal]


func text_of() -> String:
	var lv := LevelModule.of(run)
	if lv == null or not lv.has_card(SunCyclePerk.STARS):
		return ""
	var n := int(lv.god_state.get(SunCyclePerk.STARS_KEY, 0))
	return "%d" % n if star != null else UiText.t("hud.stars") % n


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP

## 150：货币。166（作者定）：左边一枚金币（`assets/ui/hud/coin.png`，36 px，和顶端栏数字同高（美术 2026-10-13 放大）；缺图画一个描边金圆）+ 数字，不再写「货币」两个字；悬浮窗写「货币」
extends HudWidget

const COIN := 36.0
const COIN_ART := "res://assets/ui/hud/coin.png"

var coin: HudIcon


func _init() -> void:
	super()
	coin = HudIcon.make(COIN, &"coin")
	coin.texture = HudIcon.load_art(COIN_ART)
	_prepend_icon(coin)
	tooltip_text = UiText.t("hud.wallet")


func title() -> String:
	return "货币"


func watch() -> Array[Signal]:
	return [run.wallet.changed] as Array[Signal]


func text_of() -> String:
	return text_at(run.wallet.balance)


func roll_value() -> int:
	return run.wallet.balance


func text_at(v: int) -> String:
	return "%d" % v


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP     # 停上去看「货币」

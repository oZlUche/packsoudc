## 388：神的牌（质变牌、基础牌）带的数 —— 自己不往一局里加东西，由那位神的机制（[BruteRagePerk] 这类）编译时按拿了几张读。
## [member values] 是这张牌的数（作者表里的那些，可调）；牌面的字是 `UiText` 里的 `gcard.<牌 id>`，`{名字}` 换成这里的数。
## 基础牌拿几张算几份（[method LevelModule.god_value]）；升级版写自己那一份完整的数，拿了升级就按升级的算
class_name GodCard
extends RunEffect

@export var values: Dictionary = {}


func modify(_ctx: RunContext) -> void:
	pass


## 牌面那一句：[param template] 里的 `{名字}` 换成数（[param times] 份，基础牌拿几张乘几）
func fill(template: String, times: int = 1) -> String:
	var s := template
	for k in values:
		s = s.replace("{%s}" % k, TextTemplate.num(float(values[k]) * maxi(1, times)))
	return s

## 「金币不够」不写字（项目规则：钱用金币图标，「图像能说明的不加文字」；2026-10-31 17:27 转来）：
## 原因串里只放一个记号 `[coin_short]`（带数的写 `[coin_short=N]`），显示它的地方画一枚**红色、斜划一道的金币**（带数就跟着红字的数）：
## 告示卷（[NoticeScroll]）、道具操作按钮（[TipButton]，价钱那枚金币变红、不挂悬停字）、铁匠铺铸牌（工钱变红）。
## 只能写字的地方（调试台的提示行）用 [method strip] 去掉记号
class_name CoinShort
extends RefCounted

const TAG := "[coin_short"
const _RX := "\\[coin_short(?:=(\\d+))?\\]"


## 记号本身：[param n] < 0 不带数
static func tag(n: int = -1) -> String:
	return "[coin_short]" if n < 0 else "[coin_short=%d]" % n


static func has(text: String) -> bool:
	return text.contains(TAG)


## 记号里的数（没数或没记号 = -1）
static func amount(text: String) -> int:
	var m := TextTemplate.cached_regex(_RX).search(text)
	return int(m.get_string(1)) if m != null and m.get_string(1) != "" else -1


## 11-04（游戏测试转：买卖告示写「花了 5 币」）：告示里的钱也画金币 —— 句末放 `[coin=N]`，告示卷把它画成一枚金币跟着数（不是红的）
const COIN_TAG := "[coin="
const _COIN_RX := "\\[coin=(\\d+)\\]"


static func coin(n: int) -> String:
	return "[coin=%d]" % n


static func has_coin(text: String) -> bool:
	return text.contains(COIN_TAG)


## `[coin=N]` 里的数（没有 = -1）
static func coin_amount(text: String) -> int:
	var m := TextTemplate.cached_regex(_COIN_RX).search(text)
	return int(m.get_string(1)) if m != null else -1


## 去掉记号后剩下的字（连带它前面的「：」「:」和空白）
static func strip(text: String) -> String:
	return TextTemplate.cached_regex("[：:]?\\s*(?:" + _RX + "|" + _COIN_RX + ")").sub(text, "", true).strip_edges()


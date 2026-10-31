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


## 去掉记号后剩下的字（连带它前面的「：」「:」和空白）
static func strip(text: String) -> String:
	return TextTemplate.cached_regex("[：:]?\\s*" + _RX).sub(text, "", true).strip_edges()


## 284 §3.5（作者 2026-11-07 14:57：「将这些文本设置成引用而非写死，以应对玩家未来想要改键的情况」）：
## 字里写 `[key=<动作>]`，显示时换成这个动作现在绑的键名（[InputKeys]，改过键就跟着变）。和 [CoinShort] 一样是一个小工具，
## NPC 纸条（[NpcBadge]）先过它。键名走 `OS.get_keycode_string`（Ctrl / Alt / R 这类不分语言）；mac 上整包那个动作写 Cmd；没绑键写「未绑定」
class_name KeyNames
extends RefCounted

const _RX := "\\[key=([a-z_]+)\\]"


static func has(text: String) -> bool:
	return text.contains("[key=")


## 动作 [param action] 现在绑的第一个键的名字；没绑写「未绑定」
static func of(action: StringName) -> String:
	var keys := InputKeys.keys_of(action)
	if keys.is_empty():
		return UiText.t("key.unbound")
	var code: Key = keys[0]
	if OS.get_name() == "macOS" and code == KEY_CTRL and keys.has(KEY_META):
		code = KEY_META     # 待定 8：mac 的 Ctrl 显示 Cmd
	return OS.get_keycode_string(code)


## 把 [param text] 里的每个 `[key=动作]` 换成键名
static func expand(text: String) -> String:
	if not has(text):
		return text
	var rx := TextTemplate.cached_regex(_RX)
	var out := ""
	var at := 0
	for m in rx.search_all(text):
		out += text.substr(at, m.get_start() - at) + of(StringName(m.get_string(1)))
		at = m.get_end()
	return out + text.substr(at)

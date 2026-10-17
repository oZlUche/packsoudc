## 186（作者 2026-10-17：内部说明不给玩家看）：开发包还是玩家包 —— 调试台、设置里的调试节、调试模式的效果只在开发包里有。
##
## 开发包 = 非导出（编辑器、命令行跑的都算）；导出包带 `template` 特性。测试里把 [member force_player] 打开就是玩家包
class_name DevGate
extends RefCounted

## 测试用：当成玩家包
static var force_player := false


static func on() -> bool:
	return not force_player and not OS.has_feature("template")

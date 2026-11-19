## 信仰重构 A（交接方案 §2.3）：一次查询的信仰快照 —— 选的、有效的、联系状态、阶、点数。
## UI、事件条件、神坛、预估读同一份（[method RunState.faith_context]）；编译器只拿其中的有效信仰（[member CompileInput.faith]）
class_name FaithContext
extends RefCounted

## 玩家选的神 id（空 = 不奉神）
var selected: StringName = &""
## 有效的神 id（选了且联系正常；否则空）
var effective: StringName = &""
## [constant FaithState.NONE] / [constant FaithState.OK] / [constant FaithState.BENCHED] / [constant FaithState.MISSING]
var connection: StringName = FaithState.NONE
## 有效信仰现在第几阶；没有有效信仰 = -1
var tier: int = -1
## 选的那位神现在多少信力（联系中断时也照写，界面要看）
var points: int = 0
## 信仰重构 B：选的那位神现在多少祈愿（可花的余额）
var prayer: int = 0


## 联系中断：选了神，但棋盘上没有它的有效信物
func is_broken() -> bool:
	return selected != &"" and connection != FaithState.OK

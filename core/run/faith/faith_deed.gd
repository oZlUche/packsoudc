## 信仰指定的行为（作者定，报告 082）：做了它就攒**信力**。一个信仰在自己的文件里列它认哪些行为、各给几点：
## 置入一定价值的道具、进行战斗、移动一定距离、获得金币、花费金币、进行探索、在事件中选特定的选项。
##
## 构件：[FaithPower] 把一局里发生的事以「事件名 + 载荷」的形式喂给激活信仰的每个行为，行为自己说给几点（0 = 不认）。
## 事件名与载荷（都由 [RunState] 接线时发）：
## - `place_item` {value, id, tags, rarity, first_in_run}：一件道具从别的容器置入棋盘；first_in_run = 这一局头一回置入这种道具（按定义 id）
## - `battle` {won, node_type, dealt, taken, healed, fired_total, fired_items: [{id, tags, cells, count}]}：打了一场（节点敌人、猎手都算），见 [method RunState.battle_summary]
## - `item_acquired` {id, tags, cells, rarity, first_in_run}（104）：一件道具头一回出现在玩家的容器里（棋盘 / 地上 / 保险箱），离开一个点时对账
## - `travel` {steps}：走了一步，steps = 到现在为止的总步数
## - `earn_money` {amount} / `spend_money` {amount}
## - `explore` {}：搜了一次
## - `event_choice` {tags}：事件里选了一个选项，tags 是那个选项的标签
## 加一种行为 = 一个子类 + 注册表一行（RunRegistry.FAITH_DEEDS）。数都是字段。
## 行为是共享的 Resource，**不能自己记状态**：「首次」之类由 [RunState] 算好放进载荷（104）。
@abstract
class_name FaithDeed
extends Resource

## 认的那件事每发生一次给几点
@export var amount: int = 1


## 这件事给几点；不认返回 0
@abstract func gain(event: StringName, payload: Dictionary) -> int


func describe() -> String:
	return ""


## 257：信仰窗「信力来源」的两列 —— `[[事, 所得], …]`（一件事通常一行；所得空 = 只写事）。默认把 [method describe] 在第一个冒号、
## 或第一个「 +N / ×N」前切开；句子不合这个样子的子类自己给（伤害按百分数写、岔路分两行）
func parts() -> Array:
	var text := describe()
	return [split_text(text)] if text != "" else []


static var _sign_re: RegEx = null


static func split_text(text: String) -> Array[String]:
	for colon in ["：", ": "]:
		var at := text.find(colon)
		if at > 0:
			return [text.substr(0, at), text.substr(at + colon.length()).strip_edges()] as Array[String]
	if _sign_re == null:
		_sign_re = RegEx.create_from_string(" (?=[+×]\\s?\\d)")
	var m := _sign_re.search(text)
	if m != null and m.get_start() > 0:
		return [text.substr(0, m.get_start()), text.substr(m.get_end())] as Array[String]
	return [text, ""] as Array[String]


## 一枚「常驻」格（103 第 6 条，作者定：影响战斗的就显示）。
##
## 信仰阶、套装档位、局外 / 一局 buff、角色技能的被动 —— 它们在编译期就并进了属性或规则，**不是 buff**：
## 不走净化、不进 [member BattleContext.seen_buffs]、全场不变，只是让 buff 栏把「这场还吃着哪些加成」画出来。
## 包体加成与邻接增益不进栏：它们是棋盘摆法本身，画在格子上（4.8）。纯数据，回放层只读
class_name PassiveNote
extends RefCounted

var id: StringName = &""
## 显示名（已按当前语言取好）
var name: String = ""
## 层数：信仰 = 达到的阶，套装 = 件数档位，其余 1
var stacks: int = 1
## 它带来的属性加成（悬浮窗用 [method Glossary.mods_text] 写）
var mods: Array[StatModifier] = []
## 补一句（规则类加成没有 mods，写在这里）
var note: String = ""


static func make(p_id: StringName, p_name: String, p_stacks: int = 1, p_mods: Array = [], p_note: String = "") -> PassiveNote:
	var n := PassiveNote.new()
	n.id = p_id
	n.name = p_name
	n.stacks = maxi(1, p_stacks)
	for m in p_mods:
		if m is StatModifier:
			n.mods.append(m)
	n.note = p_note
	return n


## 悬浮窗正文
func describe() -> String:
	var lines: Array[String] = [UiText.t("battle.passive_whole")]
	if not mods.is_empty():
		lines.append(Glossary.mods_text(mods))
	if note != "":
		lines.append(note)
	return "\n".join(lines)

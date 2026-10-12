## 150：读数组件的登记表 —— id → 脚本。新加一种读数 = 一个 [HudWidget] 子类 + 这里一行（布局文件按 id 引用）。
## 150 补 1：屏幕自己的按钮、列表、日志也是组件 —— 都用 [HudPartWidget]，内容由所在屏的 `hud_part(id)` 给（名字在 [constant PART_TITLES]）
class_name HudWidgets
extends RefCounted

const KINDS := {
	&"countdown": "res://ui/hud/widgets/countdown_widget.gd",
	&"action_points": "res://ui/hud/widgets/action_points_widget.gd",
	&"distances": "res://ui/hud/widgets/distances_widget.gd",
	&"vitality": "res://ui/hud/widgets/vitality_widget.gd",
	&"wallet": "res://ui/hud/widgets/wallet_widget.gd",
	&"ground_count": "res://ui/hud/widgets/ground_count_widget.gd",
	&"encumbrance": "res://ui/hud/widgets/encumbrance_widget.gd",
	&"faith": "res://ui/hud/widgets/faith_widget.gd",
	&"buffs": "res://ui/hud/widgets/buffs_widget.gd",
	&"erosion": "res://ui/hud/widgets/erosion_widget.gd",
	&"belt": "res://ui/hud/widgets/belt_widget.gd",
	&"dev_drawer": PART,
	&"bag_button": PART,
	&"reopen_button": PART,
	&"extract_button": PART,
	&"skills": PART,
	&"menu_button": PART,
	&"routes": PART,
	&"log": PART,
}
const PART := "res://ui/hud/hud_part_widget.gd"
## 屏幕那几块的中文名（摆读数时没内容的露这个名字）
const PART_TITLES := {
	&"dev_drawer": "调试台", &"bag_button": "背包按钮", &"reopen_button": "回到这个点",
	&"extract_button": "撤离按钮", &"skills": "技能", &"menu_button": "回主菜单", &"routes": "路线", &"log": "日志",
}


static func has(id: StringName) -> bool:
	return KINDS.has(id)


## 造一件。不认识的 id 返回 null
static func create(id: StringName) -> HudWidget:
	if not KINDS.has(id):
		return null
	var w := (load(KINDS[id]) as GDScript).new() as HudWidget
	w.id = id
	w.name = "Hud_" + String(id)
	return w

## 150：读数组件的登记表 —— id → 脚本。新加一种读数 = 一个 [HudWidget] 子类 + 这里一行（布局文件按 id 引用）。
## 150 补 1：屏幕自己的按钮、列表也是组件 —— 都用 [HudPartWidget]，内容由所在屏的 `hud_part(id)` 给（名字在 [constant PART_TITLES]）
class_name HudWidgets
extends RefCounted

const KINDS := {
	&"countdown": "res://ui/hud/widgets/countdown_widget.gd",
	&"distances": "res://ui/hud/widgets/distances_widget.gd",
	&"vitality": "res://ui/hud/widgets/vitality_widget.gd",
	&"wallet": "res://ui/hud/widgets/wallet_widget.gd",
	&"encumbrance": "res://ui/hud/widgets/encumbrance_widget.gd",
	&"faith": "res://ui/hud/widgets/faith_widget.gd",
	&"buffs": "res://ui/hud/widgets/buffs_widget.gd",
	&"erosion": "res://ui/hud/widgets/erosion_widget.gd",
	&"belt": "res://ui/hud/widgets/belt_widget.gd",
	&"hud_bar": "res://ui/hud/widgets/hud_bar.gd",
	&"legend": "res://ui/hud/widgets/legend_widget.gd",
	&"dev_drawer": PART,
	&"bag_button": PART,
	&"reopen_button": PART,
	&"skills": PART,
	&"routes": PART,
}
const PART := "res://ui/hud/hud_part_widget.gd"
## 186：只在开发包里造的（[DevGate]）—— 玩家包里宿主跳过，不是藏起来
const DEV_ONLY: Array[StringName] = [&"dev_drawer"]
## 屏幕那几块的中文名（摆读数时没内容的露这个名字）
const PART_TITLES := {
	&"dev_drawer": "调试台", &"bag_button": "背包", &"reopen_button": "放大镜", &"skills": "技能", &"routes": "路线",
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

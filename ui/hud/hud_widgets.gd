## 150：读数组件的登记表 —— id → 脚本。新加一种读数 = 一个 [HudWidget] 子类 + 这里一行（布局文件按 id 引用）
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

## 道具的附魔（175 第三批 §3.4，作者定：**所有附魔都视为铸牌附魔**）。字段与铸牌的 `state.enchant` 同构 ——
## 记的是三张映射表（[ForgeTable]）里各落到哪一行，规则在编译时由 [method Forge.rule_of] 现拼。
## 内容作者给一件道具**预置附魔**（`ItemDef.enchant`、敌人的武器）用它；实例的 `state.enchant` 覆盖它
class_name EnchantDef
extends Resource

## 时机：材质行 key（出手时 / 受伤时……）
@export var trigger: StringName = &""
## 时机：用途行 key（方向）
@export var direction: StringName = &"default"
## 时机：稀有度（多久一次，0–4）
@export var rate: int = 0
## 效果：材质行 key
@export var effect: StringName = &""
## 效果：用途行 key（给谁）
@export var target: StringName = &"default"
## 效果：稀有度（几阶，0–4）
@export var tier: int = 0
## 数值（铸的那一刻算定）
@export var magnitude: int = 1
## 晶石这类按元素盖印时是哪种元素；空 = 不按元素
@export var element: StringName = &""


func to_dict() -> Dictionary:
	return {"trigger": String(trigger), "direction": String(direction), "rate": rate, "effect": String(effect),
		"target": String(target), "tier": tier, "magnitude": magnitude, "element": String(element)}

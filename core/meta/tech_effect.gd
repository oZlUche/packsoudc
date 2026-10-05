## 局外科技每升一级做的事（110，构件，登记在 [RunRegistry.TECH_EFFECTS]）。
## 仓库加行（110）、给一局的局外 buff 与保险箱加格（118）；再加一种是一个子类、登记一行，框架不动
@abstract
class_name TechEffect
extends Resource

## 120：已到 [param level] 级时局外该是什么样，就把它变成那样（幂等）。升级后、读档时（仓库还空着、物品装进去之前）
## 与开发区改级数后都走它 —— 局外存档里不存任何科技算出来的数
@abstract func derive(meta: MetaState, level: int) -> void


## 卡片上「下一级：……」那句
func describe() -> String:
	return ""


## 118：说明面板「现在 / 下一级」那两行 —— 到第 [param level] 级（≥ 1）时这项科技给的效果。
## [param buff_defs]：局外 buff id → [RunBuffDef]（按 buff 给效果的科技要查名字与说明）。默认就是 [method describe]
func describe_level(_level: int, _buff_defs: Dictionary = {}) -> String:
	return describe()

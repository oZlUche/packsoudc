## 侵蚀的一种效果（构件，登记在 [EffectRegistry.EROSION_EFFECTS]；5.7，报告 075）。
##
## 作者：侵蚀的各种效果都要能开关、能调 —— 是否启用、在哪个阶段启用、触发概率都不写死。
## 所以每个效果自带四个门：[member enabled]、[member from_depth]（这个点被侵蚀了至少几层才生效）、[member only_total]（只在全图侵蚀的终局生效）、
## [member chance]（每次结算的触发概率）。门在基类里，子类只写「做什么」。加一种 = 一个子类、登记一行。
@abstract
class_name ErosionEffect
extends Resource

@export var enabled: bool = true
## 这个点被侵蚀了至少几层才生效（0 = 刚被侵蚀就生效）
@export var from_depth: int = 0
## 只在全图都被侵蚀之后（终局）生效
@export var only_total: bool = false
## 每次结算的触发概率（0～1）
@export var chance: float = 1.0


## 四道门都过了才做
func applies(ctx: ErosionContext) -> bool:
	if not enabled or ctx.depth < from_depth or (only_total and not ctx.total):
		return false
	if chance >= 1.0:
		return true
	if chance <= 0.0:
		return false
	return ctx.rng.randf() < chance


@abstract func apply(ctx: ErosionContext) -> void

func describe() -> String:
	return ""


## 门的一句话，子类的 describe 拼在后面
func gate_text() -> String:
	var parts: Array[String] = []
	if not enabled:
		parts.append("关")
	if from_depth > 0:
		parts.append("第 %d 层起" % from_depth)
	if only_total:
		parts.append("仅终局")
	if chance < 1.0:
		parts.append("%.0f%%" % (chance * 100.0))
	return "（" + "、".join(parts) + "）" if not parts.is_empty() else ""

## 局外科技每升一级做的事（110，构件，登记在 [RunRegistry.TECH_EFFECTS]）。
## 现在只有「仓库加行」；将来「保险箱加格」「出发多带钱」各是一个子类、登记一行，框架不动
@abstract
class_name TechEffect
extends Resource

## 升一级时施加一次
@abstract func apply(meta: MetaState) -> void

## 读档后的自检：已到 [param level] 级时局外该是什么样，不够就补（只补不缩）。默认什么也不做
func heal(_meta: MetaState, _level: int) -> void:
	pass


## 卡片上「下一级：……」那句
func describe() -> String:
	return ""

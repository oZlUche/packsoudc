## 147：随身道具的「用了做什么」（[BeltUse] 里的效果）。点一下就生效，**不依赖扳机** —— 和 [RunEffect] 同一层，作用对象是这一局。
##
## 先问 [method blocked_reason]（空串 = 现在能用；否则是原因，界面灰字显示），都能用才逐个 [method apply]，道具随即用掉。
## 新加一种 = 一个子类 + [RunRegistry.BELT_EFFECTS] 一行
@abstract
class_name BeltEffect
extends Effect

func scope() -> StringName:
	return EffectScope.BELT


## 现在能不能用：空串 = 能
func blocked_reason(_run: RunState) -> String:
	return ""


@abstract func apply(run: RunState) -> void
